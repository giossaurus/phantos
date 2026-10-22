# PhantOS

A Linux shell for iPhone and iPad. PhantOS runs Alpine Linux through usermode x86 emulation, draws the terminal with Ghostty, and wraps it in a Liquid Glass interface.

PhantOS is a fork of [iSH](https://github.com/ish-app/ish). The emulator and the Linux layer come from iSH; the terminal, the interface and the shell setup are new.

## What PhantOS adds

**Ghostty terminal.** The terminal is drawn by Ghostty's engine (libghostty, through [GhosttyKit](https://github.com/Lakr233/libghostty-spm)) instead of hterm in a web view. Text is sharp at any size, and colors follow Ghostty's themes. Drag to scroll back through output, double tap a word or triple tap a line to select and copy it, and pinch to zoom. VoiceOver reads the screen and speaks new output.

**Tabs.** Each tab is its own shell session. Tap + to open one. Hold a tab to rename it or close it. Exiting a shell closes its tab. A tab is named after the directory its shell is in, unless you rename it.

**Liquid Glass.** The tab row and the extra keys above the keyboard are glass buttons, sized to Apple's 44 point minimum, with SF Symbols that stay readable in light and dark mode.

**Hardware keyboard shortcuts, as in Ghostty.**

| Shortcut | Action |
| --- | --- |
| ⌘T | New tab |
| ⌘W | Close tab |
| ⌘1 to ⌘9 | Go to tab |
| ⌘⇧[ and ⌘⇧] | Previous and next tab |

**Themes.** PhantOS (the default, in light and dark), Dracula, Catppuccin (Latte in light mode, Mocha in dark mode) and Cursor Dark, alongside the themes iSH had. A theme sets the background, text, cursor and all 16 ANSI colors.

**zsh by default.** The shell is zsh with Oh My Zsh and Powerlevel10k, set up to start quickly under emulation. In the emulator, the first start takes about 0.85 seconds and later ones about 0.75 seconds.

**Session banner.** Every new session opens with a small PhantOS ghost and a summary of the system: user and host, Alpine and zsh versions, uptime and installed packages. It fits a 40 column iPhone screen.

**Neovim.** Neovim is the editor, with a small config and no plugin manager, so it opens in about 0.3 seconds. `vim`, `$EDITOR` and `$VISUAL` all open it, and yanks go to the iOS clipboard.

**Licenses & Credits.** Settings lists every component PhantOS ships, with its authors and full license text.

## Requirements

- iOS 26 or later
- Xcode 26 or later to build (developed with Xcode 27.1)

## Building

Clone with submodules:

```sh
git clone --recurse-submodules https://github.com/giossaurus/phantos.git
```

Install the build tools:

```sh
brew install meson ninja lld libarchive
```

Open `PhantOS.xcodeproj` and run the `PhantOS` scheme. To build under your own Apple account, change `ROOT_BUNDLE_IDENTIFIER` and `DEVELOPMENT_TEAM` in `app/iSH.xcconfig`.

### The Linux filesystem

The app bundles an Alpine root filesystem, built by [phantos-roots](https://github.com/giossaurus/phantos-roots). That repository adds zsh, the banner and Neovim to Alpine.

The build downloads the root from the phantos-roots release named by `ROOTFS_URL` in `app/iSH.xcconfig`. To try a root you built yourself, run `./build.sh` in phantos-roots, then copy `app/Local.xcconfig.example` to `app/Local.xcconfig` and point `ROOTFS_FILE` at `out/appstore-apk.tar.gz`. `app/Local.xcconfig` stays out of git.

The app imports the root the first time it opens. An installed copy keeps its filesystem, so delete and reinstall the app to try a new root.

## Command line tool

The emulator also builds as a command line program, which is handy for testing without a device:

```sh
meson setup build
ninja -C build
```

Turn an Alpine root into a filesystem the emulator can use, and run a shell in it:

```sh
./build/tools/fakefsify appstore-apk.tar.gz alpine
./build/ish -f alpine /bin/sh
```

`tools/fakefsify` is only built when meson finds libarchive.

## Tests

- **App:** the `PhantOSUITests` target, run from the `PhantOS` scheme. The tests cover the Ghostty terminal, tabs, themes, the banner, Settings and the licenses screen.
- **Filesystem import:** `meson test -C build fakefsify-utf8` checks that file names that aren't ASCII import correctly.
- **Root:** `./test.sh out/appstore-apk.tar.gz <ish build dir>` in phantos-roots boots the root in the emulator and checks the shell, the banner, Neovim and start-up time.
- **App Store readiness:** `tests/app-store-readiness.bash <path to PhantOS.app>` checks a built app for privacy manifests, the version, the bundled root, and the privacy and support pages.

## Privacy and support

PhantOS collects no data. See [PRIVACY.md](PRIVACY.md) and [SUPPORT.md](SUPPORT.md).

## Logging

Log channels are off by default. Enable them at build time:

- In Xcode, set `ISH_LOG` in `app/iSH.xcconfig` to a space separated list of channels.
- With meson, run `meson configure -Dlog="<channels>"`.

Channels:

- `strace`: the parameters and return value of almost every system call.
- `instr`: every instruction the emulator runs. This slows things down a lot.
- `verbose`: debug logs that fit no other channel.

Grep for `DEFAULT_CHANNEL` to find channels added since this list.

## The interpreter

The emulator comes from iSH, and its author describes it best: it isn't quite a JIT, since it doesn't produce machine code. It builds an array of pointers to small functions called gadgets, each ending with a tail call to the next, like the threaded code some Forth interpreters use. That runs roughly 3 to 5 times faster than a plain switch dispatch. Nearly all gadgets are written in assembly, with terse names and few comments, so read that part of the code with patience.

## Not done yet

- Split panes on iPad
- Moving the root to Alpine 3.22, which also packages fastfetch

## Credits and license

PhantOS is based on iSH by Theodore Dubois, Saagar Jha and the iSH contributors. Like iSH, it is licensed under the [GPLv3](https://www.gnu.org/licenses/gpl-3.0.html), with the additional terms in [LICENSE.IOS](LICENSE.IOS) that allow distribution through the App Store. See [LICENSE.md](LICENSE.md) for the details.

PhantOS also includes:

- [Ghostty](https://github.com/ghostty-org/ghostty) by Mitchell Hashimoto and contributors, MIT
- [GhosttyKit](https://github.com/Lakr233/libghostty-spm) by Lakr233, MIT
- [hterm](https://chromium.googlesource.com/apps/libapps) by the Chromium OS Authors, BSD 3-Clause
- [libarchive](https://github.com/libarchive/libarchive) by Tim Kientzle and contributors, BSD 2-Clause
- [zsh](https://www.zsh.org), [Oh My Zsh](https://github.com/ohmyzsh/ohmyzsh), [Powerlevel10k](https://github.com/romkatv/powerlevel10k) and [Neovim](https://neovim.io), in the Linux filesystem
- Color schemes from [iTerm2-Color-Schemes](https://github.com/mbadolato/iTerm2-Color-Schemes), [Dracula](https://draculatheme.com) and [Catppuccin](https://catppuccin.com), MIT
- [Alpine Linux](https://alpinelinux.org) packages, each under its own license

The full texts are in `app/Licenses` and in the app under Settings, Licenses & Credits.
