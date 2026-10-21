//
//  ViewController.m
//  iSH
//
//  Created by Theodore Dubois on 10/17/17.
//

#import "TerminalViewController.h"
#import "AppDelegate.h"
#import "TerminalView.h"
#import "BarButton.h"
#import "ArrowBarButton.h"
#import "UserPreferences.h"
#import "AboutViewController.h"
#import "CurrentRoot.h"
#import "NSObject+SaneKVO.h"
#import "LinuxInterop.h"
#import "SessionTabsView.h"
#import "Theme.h"
#include "kernel/init.h"
#include "kernel/task.h"
#include "kernel/calls.h"
#include "fs/devices.h"
#include "fs/tty.h"

// One shell, in one tab.
@interface TerminalSession : NSObject
@property Terminal *terminal;
@property int pid;
// A name the user gave the tab; nil follows the shell's title.
@property (nullable) NSString *name;
@end
@implementation TerminalSession
@end

@interface TerminalViewController () <UIGestureRecognizerDelegate, SessionTabsViewDelegate>

@property UITapGestureRecognizer *tapRecognizer;
@property (weak, nonatomic) IBOutlet TerminalView *termView;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *bottomConstraint;

@property (weak, nonatomic) IBOutlet UIButton *tabKey;
@property (weak, nonatomic) IBOutlet UIButton *controlKey;
@property (weak, nonatomic) IBOutlet UIButton *escapeKey;
@property (strong, nonatomic) IBOutletCollection(id) NSArray *barButtons;
@property (strong, nonatomic) IBOutletCollection(id) NSArray *barControls;

@property (weak, nonatomic) IBOutlet UIInputView *barView;
@property (weak, nonatomic) IBOutlet UIStackView *bar;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *barTop;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *barBottom;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *barLeading;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *barTrailing;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *barButtonWidth;
@property (weak, nonatomic) IBOutlet NSLayoutConstraint *barHeight;
@property (weak, nonatomic) IBOutlet UIView *settingsBadge;

@property (weak, nonatomic) IBOutlet UIButton *infoButton;
@property (weak, nonatomic) IBOutlet UIButton *pasteButton;
@property (weak, nonatomic) IBOutlet UIButton *hideKeyboardButton;

@property int sessionPid;
@property (nonatomic) Terminal *sessionTerminal;
// Every tab's session, in tab order; sessionTerminal is the one on screen.
@property NSMutableArray<TerminalSession *> *sessions;
@property SessionTabsView *tabsView;

@property BOOL ignoreKeyboardMotion;
@property (nonatomic) BOOL hasExternalKeyboard;

@end

@implementation TerminalViewController

- (void)viewDidLoad {
    [super viewDidLoad];

#if !ISH_LINUX
    int bootError = [AppDelegate bootError];
    if (bootError < 0) {
        NSString *message = [NSString stringWithFormat:@"could not boot"];
        NSString *subtitle = [NSString stringWithFormat:@"error code %d", bootError];
        if (bootError == _EINVAL)
            subtitle = [subtitle stringByAppendingString:@"\n(try reinstalling the app, see release notes for details)"];
        [self showMessage:message subtitle:subtitle];
        NSLog(@"boot failed with code %d", bootError);
    }
#endif

    self.terminal = self.terminal;
    [self.termView becomeFirstResponder];

    NSNotificationCenter *center = [NSNotificationCenter defaultCenter];
    [center addObserver:self
               selector:@selector(keyboardDidSomething:)
                   name:UIKeyboardWillChangeFrameNotification
                 object:nil];
    [center addObserver:self
               selector:@selector(keyboardDidSomething:)
                   name:UIKeyboardDidChangeFrameNotification
                 object:nil];
    [center addObserver:self
               selector:@selector(_updateBadge)
                   name:FsUpdatedNotification
                 object:nil];


    [self _updateStyleFromPreferences:NO];
    
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad) {
        [self.bar removeArrangedSubview:self.hideKeyboardButton];
        [self.hideKeyboardButton removeFromSuperview];
    }
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPhone) {
        self.barHeight.constant = 36;
    } else {
        self.barHeight.constant = 43;
    }
    
    // SF Symbols is cool
    if (@available(iOS 13, *)) {
        [self.infoButton setImage:[UIImage systemImageNamed:@"gear"] forState:UIControlStateNormal];
        [self.pasteButton setImage:[UIImage systemImageNamed:@"doc.on.clipboard"] forState:UIControlStateNormal];
        [self.hideKeyboardButton setImage:[UIImage systemImageNamed:@"keyboard.chevron.compact.down"] forState:UIControlStateNormal];
        
        [self.tabKey setTitle:nil forState:UIControlStateNormal];
        [self.tabKey setImage:[UIImage systemImageNamed:@"arrow.right.to.line.alt"] forState:UIControlStateNormal];
        [self.controlKey setTitle:nil forState:UIControlStateNormal];
        [self.controlKey setImage:[UIImage systemImageNamed:@"control"] forState:UIControlStateNormal];
        [self.escapeKey setTitle:nil forState:UIControlStateNormal];
        [self.escapeKey setImage:[UIImage systemImageNamed:@"escape"] forState:UIControlStateNormal];
    }
    [self useGlassForBar];
    [self setUpTabs];
    
    [UserPreferences.shared observe:@[@"hideStatusBar"] options:0 owner:self usingBlock:^(typeof(self) self) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self setNeedsStatusBarAppearanceUpdate];
        });
    }];
    [UserPreferences.shared observe:@[@"colorScheme", @"theme", @"hideExtraKeysWithExternalKeyboard"]
                            options:0 owner:self usingBlock:^(typeof(self) self) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self _updateStyleFromPreferences:YES];
        });
    }];
    [self _updateBadge];
}

- (void)awakeFromNib {
    [super awakeFromNib];
#if !ISH_LINUX
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(processExited:)
                                               name:ProcessExitedNotification
                                             object:nil];
#else
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(kernelPanicked:)
                                               name:KernelPanicNotification
                                             object:nil];
#endif
}

- (void)viewDidAppear:(BOOL)animated {
    [AppDelegate maybePresentStartupMessageOnViewController:self];
    [super viewDidAppear:animated];
}

- (void)startNewSession {
    int err = [self startSession];
    if (err < 0) {
        [self showMessage:@"could not start session"
                 subtitle:[NSString stringWithFormat:@"error code %d", err]];
        return;
    }
    TerminalSession *session = [TerminalSession new];
    session.terminal = self.sessionTerminal;
    session.pid = self.sessionPid;
    if (self.sessions == nil)
        self.sessions = [NSMutableArray new];
    [self.sessions addObject:session];
    [self updateTabs];
}

- (void)reconnectSessionFromTerminalUUID:(NSUUID *)uuid {
    self.sessionTerminal = [Terminal terminalWithUUID:uuid];
    if (self.sessionTerminal == nil) {
        [self startNewSession];
        return;
    }
    TerminalSession *session = [TerminalSession new];
    session.terminal = self.sessionTerminal;
    if (self.sessions == nil)
        self.sessions = [NSMutableArray new];
    [self.sessions addObject:session];
    [self updateTabs];
}

- (NSUUID *)sessionTerminalUUID {
    return self.terminal.uuid;
}

- (int)startSession {
    NSArray<NSString *> *command = UserPreferences.shared.launchCommand;

#if !ISH_LINUX
    int err = become_new_init_child();
    if (err < 0)
        return err;
    struct tty *tty;
    self.sessionTerminal = nil;
    Terminal *terminal = [Terminal createPseudoTerminal:&tty];
    if (terminal == nil) {
        NSAssert(IS_ERR(tty), @"tty should be error");
        return (int) PTR_ERR(tty);
    }
    self.sessionTerminal = terminal;
    // Start the shell at the screen's size: at the default 80 columns, zsh pads its prompt for a
    // wider screen than an iPhone's and leaves "#" marks behind once the real size arrives.
    if (Terminal.lastColumns > 0) {
        lock(&tty->lock);
        tty_set_winsize(tty, (struct winsize_) {.col = Terminal.lastColumns, .row = Terminal.lastRows});
        unlock(&tty->lock);
    }
    NSString *stdioFile = [NSString stringWithFormat:@"/dev/pts/%d", tty->num];
    err = create_stdio(stdioFile.fileSystemRepresentation, TTY_PSEUDO_SLAVE_MAJOR, tty->num);
    if (err < 0)
        return err;
    tty_release(tty);

    char argv[4096];
    [Terminal convertCommand:command toArgs:argv limitSize:sizeof(argv)];
    const char *envp = "TERM=xterm-256color\0";
    err = do_execve(command[0].UTF8String, command.count, argv, envp);
    if (err < 0)
        return err;
    self.sessionPid = current->pid;
    task_start(current);
#else
    const char *argv_arr[command.count + 1];
    for (NSUInteger i = 0; i < command.count; i++)
        argv_arr[i] = command[i].UTF8String;
    argv_arr[command.count] = NULL;
    const char *envp_arr[] = {
        "TERM=xterm-256color",
        NULL,
    };
    const char *const *argv = argv_arr;
    const char *const *envp = envp_arr;
    __block Terminal *terminal = nil;
    __block int sessionPid = 0;
    __block int err = 1;
    sync_do_in_workqueue(^(void (^done)(void)) {
        linux_start_session(argv[0], argv, envp, ^(int retval, int pid, nsobj_t term) {
            err = retval;
            if (term)
                terminal = CFBridgingRelease(term);
            sessionPid = pid;
            done();
        });
    });
    NSAssert(err <= 0, @"session start did not finish??");
    if (err < 0)
        return err;
    self.sessionTerminal = terminal;
    self.sessionPid = sessionPid;
#endif
    return 0;
}

#if !ISH_LINUX
- (void)processExited:(NSNotification *)notif {
    int pid = [notif.userInfo[@"pid"] intValue];
    TerminalSession *exited = nil;
    for (TerminalSession *session in self.sessions) {
        if (session.pid == pid)
            exited = session;
    }
    if (exited == nil)
        return;

    [exited.terminal destroy];
    NSUInteger index = [self.sessions indexOfObject:exited];
    [self.sessions removeObject:exited];
    if (self.sessions.count > 0) {
        // Other tabs remain: show a neighbour if the closed tab was on screen.
        if (exited.terminal == self.sessionTerminal)
            [self selectSessionAtIndex:MIN(index, self.sessions.count - 1)];
        else
            [self updateTabs];
        return;
    }
    // On iOS 13, there are multiple windows, so just close this one.
    if (@available(iOS 13, *)) {
        // On iPhone, destroying scenes will fail, but the error doesn't actually go to the error handler, which is really stupid. Apple doesn't fix bugs, so I'm forced to just add a check here.
        if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad && self.sceneSession != nil) {
            [UIApplication.sharedApplication requestSceneSessionDestruction:self.sceneSession options:nil errorHandler:^(NSError *error) {
                NSLog(@"scene destruction error %@", error);
                self.sceneSession = nil;
                [self processExited:notif];
            }];
            return;
        }
    }
    current = NULL; // it's been freed
    [self startNewSession];
}
#endif

#if ISH_LINUX
- (void)kernelPanicked:(NSNotification *)notif {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"panik" message:notif.userInfo[@"message"] preferredStyle:UIAlertControllerStyleAlert];
    [alert addAction:[UIAlertAction actionWithTitle:@"k" style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}
#endif

- (void)showMessage:(NSString *)message subtitle:(NSString *)subtitle {
    dispatch_async(dispatch_get_main_queue(), ^{
        UIAlertController *alert = [UIAlertController alertControllerWithTitle:message message:subtitle preferredStyle:UIAlertControllerStyleAlert];
        [alert addAction:[UIAlertAction actionWithTitle:@"k"
                                                  style:UIAlertActionStyleDefault
                                                handler:nil]];
        [self presentViewController:alert animated:YES completion:nil];
    });
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (object == [UserPreferences shared]) {
        [self _updateStyleFromPreferences:YES];
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)_updateStyleFromPreferences:(BOOL)animated {
    NSAssert(NSThread.isMainThread, @"This method needs to be called on the main thread");
    NSTimeInterval duration = animated ? 0.1 : 0;
    [UIView animateWithDuration:duration animations:^{
        self.view.backgroundColor = [[UIColor alloc] ish_initWithHexString:UserPreferences.shared.palette.backgroundColor];
        UIKeyboardAppearance keyAppearance = UserPreferences.shared.keyboardAppearance;
        self.termView.keyboardAppearance = keyAppearance;
        for (BarButton *button in self.barButtons) {
            button.keyAppearance = keyAppearance;
        }
        NSString *cursor = UserPreferences.shared.palette.cursorColor;
        UIColor *accent = cursor ? [[UIColor alloc] ish_initWithHexString:cursor] : nil;
        if (accent)
            self.tabsView.accentColor = accent;
        UIColor *tintColor = keyAppearance == UIKeyboardAppearanceLight ? UIColor.blackColor : UIColor.whiteColor;
        for (UIControl *control in self.barControls) {
            control.tintColor = tintColor;
        }
    }];
    UIView *oldBarView = self.termView.inputAccessoryView;
    if (UserPreferences.shared.hideExtraKeysWithExternalKeyboard && self.hasExternalKeyboard) {
        self.termView.inputAccessoryView = nil;
    } else {
        self.termView.inputAccessoryView = self.barView;
    }
    if (self.termView.inputAccessoryView != oldBarView && self.termView.isFirstResponder) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.ignoreKeyboardMotion = YES; // avoid infinite recursion
            [self.termView reloadInputViews];
            self.ignoreKeyboardMotion = NO;
        });
    }
}
- (void)_updateStyleAnimated {
    [self _updateStyleFromPreferences:YES];
}

- (void)_updateBadge {
    self.settingsBadge.hidden = !FsNeedsRepositoryUpdate();
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UserPreferences.shared.statusBarStyle;
}

- (BOOL)prefersStatusBarHidden {
    return UserPreferences.shared.hideStatusBar;
}

- (void)keyboardDidSomething:(NSNotification *)notification {
    if (self.ignoreKeyboardMotion)
        return;

    CGRect screenKeyboardFrame = [notification.userInfo[UIKeyboardFrameEndUserInfoKey] CGRectValue];
    UIScreen *screen = UIScreen.mainScreen;
    // notification.object is nil before iOS 16.1 and the correct UIScreen after iOS 16.1
    if (notification.object != nil)
        screen = notification.object;
    CGRect keyboardFrame = [self.view convertRect:screenKeyboardFrame fromCoordinateSpace:screen.coordinateSpace];
    if (CGRectEqualToRect(keyboardFrame, CGRectZero))
        return;
    CGRect intersection = CGRectIntersection(keyboardFrame, self.view.bounds);
    keyboardFrame = intersection;
    NSLog(@"%@ %@", notification.name, @(keyboardFrame));
    self.hasExternalKeyboard = keyboardFrame.size.height < 100;
    CGFloat pad = CGRectGetMaxY(self.view.bounds) - CGRectGetMinY(keyboardFrame);
    // The keyboard appears to be undocked. This means it can either be split or
    // truly floating. In the former case we want to keep the pad, but in the
    // latter we should fall back to the input accessory view instead of the
    // keyboard.
    if (pad != keyboardFrame.size.height && keyboardFrame.size.width != UIScreen.mainScreen.bounds.size.width) {
        pad = MAX(self.view.safeAreaInsets.bottom, self.termView.inputAccessoryView.frame.size.height);
    }
    // NSLog(@"pad %f", pad);
    self.bottomConstraint.constant = pad;

    BOOL initialLayout = self.termView.needsUpdateConstraints;
    [self.view setNeedsUpdateConstraints];
    if (!initialLayout) {
        // if initial layout hasn't happened yet, the terminal view is going to be at a really weird place, so animating it is going to look really bad
        NSNumber *interval = notification.userInfo[UIKeyboardAnimationDurationUserInfoKey];
        NSNumber *curve = notification.userInfo[UIKeyboardAnimationCurveUserInfoKey];
        [UIView animateWithDuration:interval.doubleValue
                              delay:0
                            options:curve.integerValue << 16
                         animations:^{
                             [self.view layoutIfNeeded];
                         }
                         completion:nil];
    }
}

- (void)setHasExternalKeyboard:(BOOL)hasExternalKeyboard {
    _hasExternalKeyboard = hasExternalKeyboard;
    [self _updateStyleFromPreferences:YES];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier isEqualToString:@"embed"]) {
        // You might want to check if this is your embed segue here
        // in case there are other segues triggered from this view controller.
        segue.destinationViewController.view.translatesAutoresizingMaskIntoConstraints = NO;
    }
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    // Hack to resolve a layering mismatch between the UI and preferences.
    if (@available(iOS 12.0, *)) {
        if (previousTraitCollection.userInterfaceStyle != self.traitCollection.userInterfaceStyle) {
            // Ensure that the relevant things listening for this will update.
            UserPreferences.shared.colorScheme = UserPreferences.shared.colorScheme;
        }
    }
}

#pragma mark Bar

- (IBAction)showAbout:(id)sender {
    UINavigationController *navigationController = [[UIStoryboard storyboardWithName:@"About" bundle:nil] instantiateInitialViewController];
    if ([sender isKindOfClass:[UIGestureRecognizer class]]) {
        UIGestureRecognizer *recognizer = sender;
        if (recognizer.state == UIGestureRecognizerStateBegan) {
            AboutViewController *aboutViewController = (AboutViewController *) navigationController.topViewController;
            aboutViewController.includeDebugPanel = YES;
        } else {
            return;
        }
    }
    [self presentViewController:navigationController animated:YES completion:nil];
    [self.termView resignFirstResponder];
}

- (void)resizeBar {
    CGSize bar = self.barView.bounds.size;
    // set sizing parameters on bar
    // numbers stolen from iVim and modified somewhat
    if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPhone) {
        // phone
        [self setBarHorizontalPadding:6 verticalPadding:6 buttonWidth:32];
    } else if (bar.width >= 450) {
        // wide ipad
        [self setBarHorizontalPadding:15 verticalPadding:8 buttonWidth:43];
    } else {
        // narrow ipad (slide over)
        [self setBarHorizontalPadding:10 verticalPadding:8 buttonWidth:36];
    }
    [UIView performWithoutAnimation:^{
        [self.barView layoutIfNeeded];
    }];
}

- (void)setBarHorizontalPadding:(CGFloat)horizontal verticalPadding:(CGFloat)vertical buttonWidth:(CGFloat)buttonWidth {
    self.barLeading.constant = self.barTrailing.constant = horizontal;
    self.barTop.constant = self.barBottom.constant = vertical;
    self.barButtonWidth.constant = buttonWidth;
}

- (IBAction)pressEscape:(id)sender {
    [self pressKey:@"\x1b"];
}
- (IBAction)pressTab:(id)sender {
    [self pressKey:@"\t"];
}
- (void)pressKey:(NSString *)key {
    [self.termView insertText:key];
}

- (IBAction)pressControl:(id)sender {
    self.controlKey.selected = !self.controlKey.selected;
}
    
- (IBAction)pressArrow:(ArrowBarButton *)sender {
    switch (sender.direction) {
        case ArrowUp: [self pressKey:[self.terminal arrow:'A']]; break;
        case ArrowDown: [self pressKey:[self.terminal arrow:'B']]; break;
        case ArrowLeft: [self pressKey:[self.terminal arrow:'D']]; break;
        case ArrowRight: [self pressKey:[self.terminal arrow:'C']]; break;
        case ArrowNone: break;
    }
}

- (void)switchTerminal:(UIKeyCommand *)sender {
    unsigned i = (unsigned) sender.input.integerValue;
    if (i == 7)
        self.terminal = self.sessionTerminal;
    else
        self.terminal = [Terminal terminalWithType:TTY_CONSOLE_MAJOR number:i];
}

- (void)increaseFontSize:(UIKeyCommand *)command {
    self.termView.overrideFontSize = self.termView.effectiveFontSize + 1;
}
- (void)decreaseFontSize:(UIKeyCommand *)command {
    self.termView.overrideFontSize = self.termView.effectiveFontSize - 1;
}
- (void)resetFontSize:(UIKeyCommand *)command {
    self.termView.overrideFontSize = 0;
}

- (NSArray<UIKeyCommand *> *)keyCommands {
    static NSMutableArray<UIKeyCommand *> *commands = nil;
    if (commands == nil) {
        commands = [NSMutableArray new];
        for (unsigned i = 1; i <= 7; i++) {
            [commands addObject:
             [UIKeyCommand keyCommandWithInput:[NSString stringWithFormat:@"%d", i]
                                 modifierFlags:UIKeyModifierCommand|UIKeyModifierAlternate|UIKeyModifierShift
                                        action:@selector(switchTerminal:)]];
        }
        // Ghostty's tab shortcuts.
        [commands addObject:[UIKeyCommand commandWithTitle:@"New Tab" image:nil action:@selector(newTab:)
                                                     input:@"t" modifierFlags:UIKeyModifierCommand propertyList:nil]];
        [commands addObject:[UIKeyCommand commandWithTitle:@"Close Tab" image:nil action:@selector(closeTab:)
                                                     input:@"w" modifierFlags:UIKeyModifierCommand propertyList:nil]];
        [commands addObject:[UIKeyCommand commandWithTitle:@"Previous Tab" image:nil action:@selector(previousTab:)
                                                     input:@"[" modifierFlags:UIKeyModifierCommand | UIKeyModifierShift propertyList:nil]];
        [commands addObject:[UIKeyCommand commandWithTitle:@"Next Tab" image:nil action:@selector(nextTab:)
                                                     input:@"]" modifierFlags:UIKeyModifierCommand | UIKeyModifierShift propertyList:nil]];
        for (unsigned i = 1; i <= 9; i++) {
            [commands addObject:[UIKeyCommand commandWithTitle:[NSString stringWithFormat:@"Tab %u", i] image:nil action:@selector(selectTab:)
                                                         input:[NSString stringWithFormat:@"%u", i] modifierFlags:UIKeyModifierCommand propertyList:nil]];
        }
        [commands addObject:
         [UIKeyCommand keyCommandWithInput:@"+"
                             modifierFlags:UIKeyModifierCommand
                                    action:@selector(increaseFontSize:)
                      discoverabilityTitle:@"Increase Font Size"]];
        [commands addObject:
         [UIKeyCommand keyCommandWithInput:@"="
                             modifierFlags:UIKeyModifierCommand
                                    action:@selector(increaseFontSize:)]];
        [commands addObject:
         [UIKeyCommand keyCommandWithInput:@"-"
                             modifierFlags:UIKeyModifierCommand
                                    action:@selector(decreaseFontSize:)
                      discoverabilityTitle:@"Decrease Font Size"]];
        [commands addObject:
         [UIKeyCommand keyCommandWithInput:@"0"
                             modifierFlags:UIKeyModifierCommand
                                    action:@selector(resetFontSize:)
                      discoverabilityTitle:@"Reset Font Size"]];
        [commands addObject:
         [UIKeyCommand keyCommandWithInput:@","
                             modifierFlags:UIKeyModifierCommand
                                    action:@selector(showAbout:)
                      discoverabilityTitle:@"Settings"]];
    }
    return commands;
}

#pragma mark Liquid Glass

- (void)useGlassForBar {
    // The keys float as glass capsules over whatever is behind the keyboard, instead of sitting on
    // a keyboard-grey strip.
    self.barView.backgroundColor = UIColor.clearColor;
    self.barView.accessibilityIdentifier = @"keys.glass";
    for (id control in [self.barButtons arrayByAddingObjectsFromArray:self.barControls]) {
        if ([control respondsToSelector:@selector(useGlass)])
            [control useGlass];
    }
    UIImageSymbolConfiguration *symbol = [[UIImageSymbolConfiguration configurationWithTextStyle:UIFontTextStyleBody scale:UIImageSymbolScaleMedium]
        configurationByApplyingConfiguration:[UIImageSymbolConfiguration configurationWithWeight:UIImageSymbolWeightSemibold]];
    for (UIButton *button in @[self.infoButton, self.pasteButton, self.hideKeyboardButton]) {
        UIButtonConfiguration *configuration = [UIButtonConfiguration glassButtonConfiguration];
        configuration.image = [button imageForState:UIControlStateNormal];
        configuration.preferredSymbolConfigurationForImage = symbol;
        configuration.baseForegroundColor = UIColor.labelColor;
        configuration.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        button.configuration = configuration;
    }
    // 44 points, Apple's minimum for something you tap.
    self.barHeight.constant = 44;
    self.barButtonWidth.constant = 44;
}

#pragma mark Tabs

- (void)setUpTabs {
    self.tabsView = [SessionTabsView new];
    self.tabsView.delegate = self;
    self.tabsView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.tabsView];
    // The terminal is pinned to the safe area; growing it at the top makes room for the tabs.
    self.additionalSafeAreaInsets = UIEdgeInsetsMake(50, 0, 0, 0);
    [NSLayoutConstraint activateConstraints:@[
        [self.tabsView.leadingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.leadingAnchor constant:8],
        [self.tabsView.trailingAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.trailingAnchor constant:-8],
        [self.tabsView.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:-4],
        [self.tabsView.heightAnchor constraintEqualToConstant:44],
    ]];
    [NSNotificationCenter.defaultCenter addObserver:self
                                           selector:@selector(terminalTitleDidChange:)
                                               name:TerminalTitleDidChangeNotification
                                             object:nil];
    [self updateTabs];
}

- (void)terminalTitleDidChange:(NSNotification *)notification {
    dispatch_async(dispatch_get_main_queue(), ^{
        [self updateTabs];
    });
}

// powerlevel10k titles a shell "user@host:~"; the tab shows where it is.
+ (NSString *)tabTitleForTerminal:(Terminal *)terminal {
    NSString *title = terminal.title;
    if (title.length == 0)
        return @"shell";
    NSRange separator = [title rangeOfString:@":" options:NSBackwardsSearch];
    if (separator.location != NSNotFound && NSMaxRange(separator) < title.length)
        title = [title substringFromIndex:NSMaxRange(separator)];
    return [title stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
}

- (void)updateTabs {
    if (self.tabsView == nil)
        return;
    NSMutableArray<NSString *> *titles = [NSMutableArray new];
    NSUInteger selected = 0;
    for (NSUInteger i = 0; i < self.sessions.count; i++) {
        [titles addObject:self.sessions[i].name ?: [self.class tabTitleForTerminal:self.sessions[i].terminal]];
        if (self.sessions[i].terminal == self.sessionTerminal)
            selected = i;
    }
    [self.tabsView setTitles:titles selectedIndex:selected];
}

- (void)selectSessionAtIndex:(NSUInteger)index {
    if (index >= self.sessions.count)
        return;
    TerminalSession *session = self.sessions[index];
    _sessionTerminal = session.terminal;
    self.sessionPid = session.pid;
    self.terminal = session.terminal;
    [self updateTabs];
}

- (void)closeSessionAtIndex:(NSUInteger)index {
    if (index >= self.sessions.count)
        return;
    // Hanging up the tty ends the shell; processExited: then removes the tab.
    [self.sessions[index].terminal destroy];
}

- (NSUInteger)selectedSessionIndex {
    for (NSUInteger i = 0; i < self.sessions.count; i++) {
        if (self.sessions[i].terminal == self.sessionTerminal)
            return i;
    }
    return 0;
}

- (void)sessionTabsViewDidAskForNewTab:(SessionTabsView *)view {
    [self startNewSession];
}

- (void)sessionTabsView:(SessionTabsView *)view didSelectTabAtIndex:(NSUInteger)index {
    [self selectSessionAtIndex:index];
}

- (void)sessionTabsView:(SessionTabsView *)view didCloseTabAtIndex:(NSUInteger)index {
    [self closeSessionAtIndex:index];
}

- (void)sessionTabsView:(SessionTabsView *)view didAskToRenameTabAtIndex:(NSUInteger)index {
    if (index >= self.sessions.count)
        return;
    TerminalSession *session = self.sessions[index];
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Rename Tab"
                                                                   message:@"Leave it empty to name the tab after where its shell is."
                                                            preferredStyle:UIAlertControllerStyleAlert];
    [alert addTextFieldWithConfigurationHandler:^(UITextField *field) {
        field.text = session.name;
        field.placeholder = [self.class tabTitleForTerminal:session.terminal];
        field.clearButtonMode = UITextFieldViewModeWhileEditing;
        field.autocapitalizationType = UITextAutocapitalizationTypeNone;
        field.returnKeyType = UIReturnKeyDone;
    }];
    [alert addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
    UIAlertAction *rename = [UIAlertAction actionWithTitle:@"Rename" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        NSString *name = [alert.textFields.firstObject.text stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        session.name = name.length > 0 ? name : nil;
        [self updateTabs];
    }];
    [alert addAction:rename];
    alert.preferredAction = rename;
    [self presentViewController:alert animated:YES completion:nil];
}

- (void)newTab:(UIKeyCommand *)command {
    [self startNewSession];
}

- (void)closeTab:(UIKeyCommand *)command {
    [self closeSessionAtIndex:self.selectedSessionIndex];
}

- (void)selectTab:(UIKeyCommand *)command {
    [self selectSessionAtIndex:(NSUInteger) command.input.integerValue - 1];
}

- (void)previousTab:(UIKeyCommand *)command {
    NSUInteger count = self.sessions.count;
    if (count > 0)
        [self selectSessionAtIndex:(self.selectedSessionIndex + count - 1) % count];
}

- (void)nextTab:(UIKeyCommand *)command {
    NSUInteger count = self.sessions.count;
    if (count > 0)
        [self selectSessionAtIndex:(self.selectedSessionIndex + 1) % count];
}

- (void)setTerminal:(Terminal *)terminal {
    _terminal = terminal;
    self.termView.terminal = self.terminal;
}

- (void)setSessionTerminal:(Terminal *)sessionTerminal {
    if (_terminal == _sessionTerminal)
        self.terminal = sessionTerminal;
    _sessionTerminal = sessionTerminal;
}

@end

@interface BarView : UIInputView
@property (weak) IBOutlet TerminalViewController *terminalViewController;
@property (nonatomic) IBInspectable BOOL allowsSelfSizing;
@end
@implementation BarView
@dynamic allowsSelfSizing;

- (void)layoutSubviews {
    [self.terminalViewController resizeBar];
}

@end
