//
//  GhosttyTerminalHost.swift
//  iSH
//

import GhosttyTerminal
import UIKit

/// Draws a terminal's output with Ghostty instead of hterm.
///
/// The keyboard stays with TerminalView: this surface only renders. Bytes from the tty go in
/// through `receive`, and Ghostty's own replies (device attributes, cursor reports) come back
/// through `onInput`, the way hterm's sendInput messages did.
@MainActor
@objc(GhosttyTerminalHost)
public final class GhosttyTerminalHost: NSObject {
    /// Bytes the terminal sends back to the program. Called on the main thread.
    @objc public var onInput: ((Data) -> Void)?
    /// The grid size, in columns and rows, whenever it changes. Called on the main thread.
    @objc public var onResize: ((Int, Int) -> Void)?
    /// The title the program set (OSC 0/2), e.g. powerlevel10k's "user@host: ~". Called on the main thread.
    @objc public var onTitle: ((String) -> Void)?
    /// A clean tap on the surface, where Ghostty would toggle the keyboard that TerminalView owns.
    @objc public var onToggleKeyboard: (() -> Void)?
    @objc public private(set) var columns = 0
    @objc public private(set) var rows = 0

    private nonisolated let session: InMemoryTerminalSession

    override public init() {
        // The session's callbacks come from Ghostty's threads; they reach the host on the main thread.
        let relay = Relay()
        session = InMemoryTerminalSession(
            write: { data in
                DispatchQueue.main.async {
                    MainActor.assumeIsolated { relay.host?.onInput?(data) }
                }
            },
            resize: { viewport in
                DispatchQueue.main.async {
                    MainActor.assumeIsolated { relay.host?.resized(viewport) }
                }
            }
        )
        super.init()
        relay.host = self
    }

    private var pendingResize: DispatchWorkItem?

    /// A surface reports passing sizes while it settles (a font change, the keyboard sliding in).
    /// Only the size it rests at reaches the tty, so programs don't redraw for a grid nobody sees.
    private func resized(_ viewport: InMemoryTerminalViewport) {
        pendingResize?.cancel()
        let apply = DispatchWorkItem { [weak self] in
            guard let self else { return }
            columns = Int(viewport.columns)
            rows = Int(viewport.rows)
            onResize?(columns, rows)
        }
        pendingResize = apply
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: apply)
    }

    private let controller = TerminalController { $0.withBackgroundOpacity(0) }

    private lazy var surfaceView: SurfaceView = {
        // The surface takes touches, for scrolling, selection and pinch to zoom; the keyboard
        // stays with TerminalView.
        let view = SurfaceView(frame: .zero)
        view.toggleKeyboard = { [weak self] in self?.onToggleKeyboard?() }
        view.backgroundColor = .clear
        view.isOpaque = false
        view.configuration = TerminalSurfaceOptions(backend: .inMemory(session))
        view.controller = controller
        view.delegate = self
        return view
    }()

    @objc public var view: UIView { surfaceView }

    /// Safe to call from any thread: the session parses on its own queue.
    @objc public nonisolated func receive(_ data: Data) {
        session.receive(data)
    }

    /// What the surface was last styled with, as Ghostty config lines; UI tests read it.
    @objc public private(set) var styleDescription = ""

    /// Updates the one controller in place: a new controller means a new surface, which starts small.
    /// `palette` holds a theme's 16 ANSI colours, or is nil to keep Ghostty's.
    @objc public func setFontFamily(_ family: String, size: Double, foreground: String, background: String,
                                    cursor: String?, palette: [String]?) {
        var lines = ["background=\(Self.longHex(background))", "foreground=\(Self.longHex(foreground))"]
        if let cursor {
            lines.append("cursor-color=\(Self.longHex(cursor))")
        }
        for (index, color) in (palette ?? []).enumerated() {
            lines.append("palette=\(index)=\(Self.longHex(color))")
        }
        styleDescription = lines.joined(separator: "\n")
        controller.setTerminalConfiguration(TerminalConfiguration {
            $0.withFontFamily(family)
            $0.withFontSize(Float(size))
            $0.withCustom("foreground", Self.longHex(foreground))
            $0.withCustom("background", Self.longHex(background))
            if let cursor {
                $0.withCursorColor(Self.longHex(cursor))
            }
            for (index, color) in (palette ?? []).enumerated() {
                $0.withPalette(index, color: Self.longHex(color))
            }
        })
    }

    /// iSH themes may use #rgb; Ghostty wants #rrggbb.
    nonisolated static func longHex(_ color: String) -> String {
        guard color.count == 4, color.hasPrefix("#") else { return color }
        return "#" + color.dropFirst().map { "\($0)\($0)" }.joined()
    }

    /// In UI tests, an element whose value is the visible rows, since the surface is drawn with Metal.
    @objc public func makeViewportAccessibilityView() -> UIView? {
        guard ProcessInfo.processInfo.arguments.contains("--ui-testing") else { return nil }
        return ViewportAccessibilityView(session: session) { [weak self] in
            "Terminal \(self?.rows ?? 0) \(self?.columns ?? 0)"
        }
    }

    /// In UI tests, an element whose value is the colours the surface was given.
    @objc public func makeStyleAccessibilityView() -> UIView? {
        guard ProcessInfo.processInfo.arguments.contains("--ui-testing") else { return nil }
        return StyleAccessibilityView { [weak self] in self?.styleDescription ?? "" }
    }
}

/// Read only on the main thread.
private final class Relay: @unchecked Sendable {
    weak var host: GhosttyTerminalHost?
}

/// Never takes the keyboard from TerminalView; a tap hands the keyboard toggle back to it.
private final class SurfaceView: UITerminalView {
    var toggleKeyboard: (() -> Void)?

    override var canBecomeFirstResponder: Bool { false }

    override func toggleSoftwareKeyboard() {
        toggleKeyboard?()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        fitToSize()
    }
}

private final class ViewportAccessibilityView: UIView {
    private let session: InMemoryTerminalSession
    private let grid: () -> String

    init(session: InMemoryTerminalSession, grid: @escaping () -> String) {
        self.session = session
        self.grid = grid
        super.init(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
        isAccessibilityElement = true
        accessibilityIdentifier = "terminal.viewport"
        isUserInteractionEnabled = false
        alpha = 0.01
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var accessibilityValue: String? {
        get { session.readViewportText() }
        set {}
    }

    override var accessibilityLabel: String? {
        get { grid() }
        set {}
    }
}

private final class StyleAccessibilityView: UIView {
    private let style: () -> String

    init(style: @escaping () -> String) {
        self.style = style
        super.init(frame: CGRect(x: 0, y: 0, width: 1, height: 1))
        isAccessibilityElement = true
        accessibilityIdentifier = "terminal.style"
        accessibilityLabel = "Terminal Style"
        isUserInteractionEnabled = false
        alpha = 0.01
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var accessibilityValue: String? {
        get { style() }
        set {}
    }
}

extension GhosttyTerminalHost: TerminalSurfaceTitleDelegate {
    public func terminalDidChangeTitle(_ title: String) {
        onTitle?(title)
    }
}
