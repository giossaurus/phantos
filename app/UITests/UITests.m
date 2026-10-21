//
//  UITests.m
//  UITests
//
//  Created by Theodore Dubois on 11/13/20.
//

#import <XCTest/XCTest.h>

@interface UITests : XCTestCase
@end

@implementation UITests

- (void)setUp {
    self.continueAfterFailure = NO;
}

- (void)testAppIsNamedPhantOS {
    XCUIApplication *app = [XCUIApplication new];
    [app launch];
    XCTAssertEqualObjects(app.label, @"PhantOS");
}

- (void)attachScreenshotOf:(XCUIApplication *)app named:(NSString *)name {
    XCTAttachment *attachment = [XCTAttachment attachmentWithScreenshot:app.screenshot];
    attachment.name = name;
    attachment.lifetime = XCTAttachmentLifetimeKeepAlways;
    [self addAttachment:attachment];
}

- (XCUIApplication *)launchIntoSettings {
    XCUIApplication *app = [XCUIApplication new];
    [app launch];
    XCUIElement *settings = app.buttons[@"Settings"];
    XCTAssertTrue([settings waitForExistenceWithTimeout:20]);
    // The keyboard slides in at launch, and a tap during it can be lost.
    [NSThread sleepForTimeInterval:2];
    [settings tap];
    XCTAssertTrue([app.navigationBars[@"Settings"] waitForExistenceWithTimeout:10]);
    return app;
}

// Every text in Settings, top to bottom; a static table only exposes the rows on screen.
- (NSSet<NSString *> *)settingsTextsIn:(XCUIApplication *)app {
    NSMutableSet<NSString *> *texts = [NSMutableSet set];
    for (int page = 0; page < 6; page++) {
        for (XCUIElement *text in app.tables.firstMatch.staticTexts.allElementsBoundByIndex)
            [texts addObject:text.label];
        for (XCUIElement *text in app.tables.firstMatch.otherElements.allElementsBoundByIndex)
            if (text.label.length > 0)
                [texts addObject:text.label];
        [app.tables.firstMatch swipeUp];
    }
    return texts;
}

- (void)testSettingsAreNamedPhantOSAndCreditISH {
    XCUIApplication *app = [self launchIntoSettings];
    [self attachScreenshotOf:app named:@"settings-top"];
    NSSet<NSString *> *texts = [self settingsTextsIn:app];
    XCTAssertTrue([[texts filteredSetUsingPredicate:[NSPredicate predicateWithFormat:@"SELF BEGINSWITH 'PhantOS '"]] count] > 0,
                  @"no PhantOS version in %@", texts);
    XCTAssertTrue([texts containsObject:@"Based on iSH"], @"%@", texts);
    XCTAssertTrue([texts containsObject:@"Licenses & Credits"], @"%@", texts);
    NSSet *mentions = [texts filteredSetUsingPredicate:[NSPredicate predicateWithFormat:@"SELF CONTAINS 'iSH' AND SELF != 'Based on iSH'"]];
    XCTAssertEqual(mentions.count, 0, @"still named iSH: %@", mentions);
}

- (void)testNewSessionOpensWithThePhantOSBanner {
    XCUIApplication *app = [XCUIApplication new];
    app.launchArguments = @[@"--ui-testing"];
    [app launch];
    XCUIElement *viewport = [[app descendantsMatchingType:XCUIElementTypeAny] matchingIdentifier:@"terminal.viewport"].firstMatch;
    XCTAssertTrue([viewport waitForExistenceWithTimeout:20], @"no Ghostty viewport");
    // A small ghost and the name, readable on an iPhone; block letters were not.
    XCTAssertTrue([self waitForElement:viewport valueContaining:@"▄███▄  PhantOS" timeout:30], @"%@", viewport.value);
    XCTAssertFalse([viewport.value containsString:@"██████╗"], @"%@", viewport.value);
    XCTAssertFalse([viewport.value containsString:@"Welcome to Alpine"], @"%@", viewport.value);
}

- (void)testDraculaCatppuccinAndCursorDarkThemesRecolorTheTerminal {
    XCUIApplication *app = [XCUIApplication new];
    app.launchArguments = @[@"--ui-testing"];
    [app launch];
    XCUIElement *settings = app.buttons[@"Settings"];
    XCTAssertTrue([settings waitForExistenceWithTimeout:20]);
    [NSThread sleepForTimeInterval:2];
    [settings tap];
    [app.tables.staticTexts[@"Appearance"] tap];
    [app.tables.staticTexts[@"Theme"] tap];
    XCTAssertTrue([app.navigationBars[@"Themes"] waitForExistenceWithTimeout:5]);
    for (NSString *name in @[@"Dracula", @"Catppuccin", @"Cursor Dark"])
        XCTAssertTrue(app.tables.staticTexts[name].exists, @"no %@ theme", name);
    [self attachScreenshotOf:app named:@"themes"];

    [app.tables.staticTexts[@"Dracula"] tap];
    [app.navigationBars[@"Themes"].buttons[@"Appearance"] tap];
    [app.navigationBars[@"Appearance"].buttons[@"Settings"] tap];
    [app.navigationBars[@"Settings"].buttons[@"Done"] tap];

    // In UI testing mode the Ghostty surface reports the colours it was given.
    XCUIElement *style = [[app descendantsMatchingType:XCUIElementTypeAny] matchingIdentifier:@"terminal.style"].firstMatch;
    XCTAssertTrue([style waitForExistenceWithTimeout:10]);
    NSPredicate *dracula = [NSPredicate predicateWithFormat:@"value CONTAINS 'background=#282a36' AND value CONTAINS 'foreground=#f8f8f2' AND value CONTAINS 'palette=1=#ff5555'"];
    XCTNSPredicateExpectation *expectation = [[XCTNSPredicateExpectation alloc] initWithPredicate:dracula object:style];
    XCTAssertEqual([XCTWaiter waitForExpectations:@[expectation] timeout:10], XCTWaiterResultCompleted, @"%@", style.value);
}

- (void)testPhantOSThemeIsTheDefault {
    XCUIApplication *app = [XCUIApplication new];
    // Other tests pick themes, and preferences outlive a launch.
    app.launchArguments = @[@"--ui-testing", @"--ui-testing-fresh-preferences"];
    [app launch];
    // The tests run in dark mode, where the theme is the icon's graphite with its green cursor.
    XCUIElement *style = [[app descendantsMatchingType:XCUIElementTypeAny] matchingIdentifier:@"terminal.style"].firstMatch;
    XCTAssertTrue([style waitForExistenceWithTimeout:20]);
    NSPredicate *phantos = [NSPredicate predicateWithFormat:@"value CONTAINS 'background=#13131a' AND value CONTAINS 'cursor-color=#50faa0' AND value CONTAINS 'palette=2=#50faa0'"];
    XCTNSPredicateExpectation *expectation = [[XCTNSPredicateExpectation alloc] initWithPredicate:phantos object:style];
    XCTAssertEqual([XCTWaiter waitForExpectations:@[expectation] timeout:10], XCTWaiterResultCompleted, @"%@", style.value);
    [self attachScreenshotOf:app named:@"phantos-theme"];
}

- (XCUIElement *)viewportIn:(XCUIApplication *)app {
    XCUIElement *viewport = [[app descendantsMatchingType:XCUIElementTypeAny] matchingIdentifier:@"terminal.viewport"].firstMatch;
    XCTAssertTrue([viewport waitForExistenceWithTimeout:20], @"no Ghostty viewport");
    return viewport;
}

- (XCUIElementQuery *)tabsIn:(XCUIApplication *)app {
    return [app.buttons matchingIdentifier:@"tab"];
}

- (void)testTabsRunSeparateSessions {
    XCUIApplication *app = [XCUIApplication new];
    app.launchArguments = @[@"--ui-testing", @"--ui-testing-fresh-preferences"];
    [app launch];
    XCUIElement *viewport = [self viewportIn:app];
    XCTAssertTrue([self waitForElement:viewport valueContaining:@"PhantOS" timeout:30]);
    XCTAssertEqual([self tabsIn:app].count, 1);
    // A tab is named after where its shell is, not powerlevel10k's whole "user@host:~".
    NSPredicate *home = [NSPredicate predicateWithFormat:@"label == 'Tab 1, ~'"];
    XCTNSPredicateExpectation *named = [[XCTNSPredicateExpectation alloc] initWithPredicate:home object:[[self tabsIn:app] elementBoundByIndex:0]];
    XCTAssertEqual([XCTWaiter waitForExpectations:@[named] timeout:10], XCTWaiterResultCompleted, @"%@", [[self tabsIn:app] elementBoundByIndex:0].label);

    [app.buttons[@"New Tab"] tap];
    XCTAssertEqual([self tabsIn:app].count, 2);
    XCTAssertTrue([self waitForElement:[self viewportIn:app] valueContaining:@"PhantOS" timeout:30], @"the new tab has no fresh session");
    [[app.windows.firstMatch coordinateWithNormalizedOffset:CGVectorMake(0.5, 0.5)] tap];
    [app typeText:@"echo tab-$((1+1))\n"];
    XCTAssertTrue([self waitForElement:[self viewportIn:app] valueContaining:@"tab-2" timeout:30]);

    // The first tab's session never saw that command.
    [[self tabsIn:app] elementBoundByIndex:0].tap;
    XCTAssertTrue([self waitForElement:[self viewportIn:app] valueContaining:@"PhantOS" timeout:10]);
    XCTAssertFalse([[self viewportIn:app].value containsString:@"tab-2"], @"%@", [self viewportIn:app].value);
    [self attachScreenshotOf:app named:@"tabs"];
}

- (void)testExitingAShellClosesItsTab {
    XCUIApplication *app = [XCUIApplication new];
    app.launchArguments = @[@"--ui-testing", @"--ui-testing-fresh-preferences"];
    [app launch];
    XCTAssertTrue([self waitForElement:[self viewportIn:app] valueContaining:@"PhantOS" timeout:30]);
    [app.buttons[@"New Tab"] tap];
    XCTAssertEqual([self tabsIn:app].count, 2);
    XCTAssertTrue([self waitForElement:[self viewportIn:app] valueContaining:@"PhantOS" timeout:30]);
    [[app.windows.firstMatch coordinateWithNormalizedOffset:CGVectorMake(0.5, 0.5)] tap];
    [app typeText:@"exit\n"];
    NSPredicate *one = [NSPredicate predicateWithFormat:@"count == 1"];
    XCTNSPredicateExpectation *expectation = [[XCTNSPredicateExpectation alloc] initWithPredicate:one object:[self tabsIn:app]];
    XCTAssertEqual([XCTWaiter waitForExpectations:@[expectation] timeout:15], XCTWaiterResultCompleted);
}

- (void)testTabsAndExtraKeysAreLiquidGlass {
    XCUIApplication *app = [XCUIApplication new];
    app.launchArguments = @[@"--ui-testing"];
    [app launch];
    XCTAssertTrue([[app.otherElements matchingIdentifier:@"tabs.glass"].firstMatch waitForExistenceWithTimeout:20]);
    [[app.windows.firstMatch coordinateWithNormalizedOffset:CGVectorMake(0.5, 0.5)] tap];
    XCTAssertTrue([[app.otherElements matchingIdentifier:@"keys.glass"].firstMatch waitForExistenceWithTimeout:10]);
    [self attachScreenshotOf:app named:@"glass"];
}

- (void)testNoStrayPromptMarksAtStart {
    XCUIApplication *app = [XCUIApplication new];
    app.launchArguments = @[@"--ui-testing"];
    [app launch];
    XCUIElement *viewport = [self viewportIn:app];
    XCTAssertTrue([self waitForElement:viewport valueContaining:@"❯" timeout:30], @"no shell prompt");
    [NSThread sleepForTimeInterval:2];
    // zsh marks a line left without a newline with "#" for root, then pads to the width it
    // believes the screen has; a shell started at 80 columns on a 41-column iPhone left them behind.
    XCTAssertFalse([viewport.value containsString:@"#"], @"%@", viewport.value);

    // A new tab starts at the size of the screen it's on, too.
    [app.buttons[@"New Tab"] tap];
    XCTAssertTrue([self waitForElement:[self viewportIn:app] valueContaining:@"❯" timeout:30]);
    [NSThread sleepForTimeInterval:2];
    XCTAssertFalse([[self viewportIn:app].value containsString:@"#"], @"%@", [self viewportIn:app].value);
}

- (void)testHoldingATabRenamesOrClosesIt {
    XCUIApplication *app = [XCUIApplication new];
    app.launchArguments = @[@"--ui-testing", @"--ui-testing-fresh-preferences"];
    [app launch];
    XCTAssertTrue([self waitForElement:[self viewportIn:app] valueContaining:@"❯" timeout:30]);

    [[[self tabsIn:app] elementBoundByIndex:0] pressForDuration:1.2];
    XCTAssertTrue([app.buttons[@"Rename Tab"] waitForExistenceWithTimeout:5]);
    XCTAssertTrue(app.buttons[@"Close Tab"].exists);
    [self attachScreenshotOf:app named:@"tab-menu"];
    [app.buttons[@"Rename Tab"] tap];
    XCUIElement *field = app.alerts.textFields.firstMatch;
    XCTAssertTrue([field waitForExistenceWithTimeout:5]);
    [field typeText:@"build"];
    [app.alerts.buttons[@"Rename"] tap];
    // The name sticks even when the shell moves elsewhere.
    [[app.windows.firstMatch coordinateWithNormalizedOffset:CGVectorMake(0.5, 0.5)] tap];
    [app typeText:@"cd /tmp\n"];
    [NSThread sleepForTimeInterval:2];
    XCTAssertEqualObjects([[self tabsIn:app] elementBoundByIndex:0].label, @"Tab 1, build");

    [app.buttons[@"New Tab"] tap];
    XCTAssertEqual([self tabsIn:app].count, 2);
    [[[self tabsIn:app] elementBoundByIndex:1] pressForDuration:1.2];
    XCTAssertTrue([app.buttons[@"Close Tab"] waitForExistenceWithTimeout:5]);
    [app.buttons[@"Close Tab"] tap];
    NSPredicate *one = [NSPredicate predicateWithFormat:@"count == 1"];
    XCTNSPredicateExpectation *expectation = [[XCTNSPredicateExpectation alloc] initWithPredicate:one object:[self tabsIn:app]];
    XCTAssertEqual([XCTWaiter waitForExpectations:@[expectation] timeout:15], XCTWaiterResultCompleted);
}

- (void)testSettingsHaveNoAlternateIcons {
    // The alternate icons were iSH's community art; PhantOS has the one icon.
    XCUIApplication *app = [self launchIntoSettings];
    NSSet<NSString *> *texts = [self settingsTextsIn:app];
    XCTAssertTrue([texts containsObject:@"Appearance"], @"%@", texts);
    XCTAssertFalse([texts containsObject:@"App Icon"], @"%@", texts);
}

- (void)testLicensesCreditISHUnderTheGPL {
    XCUIApplication *app = [self launchIntoSettings];
    XCUIElement *licenses = app.tables.firstMatch.staticTexts[@"Licenses & Credits"];
    for (int page = 0; page < 6 && !licenses.isHittable; page++)
        [app.tables.firstMatch swipeUp];
    [licenses tap];
    XCTAssertTrue([app.navigationBars[@"Licenses & Credits"] waitForExistenceWithTimeout:5]);
    [self attachScreenshotOf:app named:@"licenses"];

    [app.tables.firstMatch.staticTexts[@"iSH"] tap];
    // The terminal underneath is a text input too, so find the license by its identifier.
    XCUIElement *text = app.textViews[@"license.text"];
    XCTAssertTrue([text waitForExistenceWithTimeout:5]);
    NSString *license = text.value;
    XCTAssertTrue([license containsString:@"GNU GENERAL PUBLIC LICENSE"], @"%@", license);
    XCTAssertTrue([license containsString:@"Version 3, 29 June 2007"], @"%@", license);
    // The App Store exception the iSH authors grant derived apps.
    XCTAssertTrue([license containsString:@"we will not object to your distribution"], @"%@", license);
}

- (void)testAppLaunchesUnderThePhantOSBundleIdentifier {
    XCUIApplication *app = [[XCUIApplication alloc] initWithBundleIdentifier:@"com.giossaurus.phantos"];
    [app launch];
    // Without the app group the app dies at launch, so staying up means the group resolved too.
    XCTAssertTrue([app waitForState:XCUIApplicationStateRunningForeground timeout:10]);
    [NSThread sleepForTimeInterval:3];
    XCTAssertEqual(app.state, XCUIApplicationStateRunningForeground);
}

- (BOOL)waitForElement:(XCUIElement *)element valueContaining:(NSString *)text timeout:(NSTimeInterval)timeout {
    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"value CONTAINS %@", text];
    XCTNSPredicateExpectation *expectation = [[XCTNSPredicateExpectation alloc] initWithPredicate:predicate object:element];
    return [XCTWaiter waitForExpectations:@[expectation] timeout:timeout] == XCTWaiterResultCompleted;
}

- (void)testShellOutputIsRenderedByGhostty {
    XCUIApplication *app = [XCUIApplication new];
    app.launchArguments = @[@"--ui-testing"];
    [app launch];

    // In UI testing mode the Ghostty surface exposes its visible rows here.
    XCUIElement *viewport = [[app descendantsMatchingType:XCUIElementTypeAny] matchingIdentifier:@"terminal.viewport"].firstMatch;
    XCTAssertTrue([viewport waitForExistenceWithTimeout:20], @"no Ghostty viewport");
    XCTAssertTrue([self waitForElement:viewport valueContaining:@"❯" timeout:30], @"no shell prompt");

    [[app.windows.firstMatch coordinateWithNormalizedOffset:CGVectorMake(0.5, 0.3)] tap];
    // The command line shows the unexpanded text, so only the shell's output contains ghostty-42.
    [app typeText:@"echo ghostty-$((6*7))\n"];
    XCTAssertTrue([self waitForElement:viewport valueContaining:@"ghostty-42" timeout:30], @"%@", viewport.value);
}

- (void)testTtySizeMatchesGhosttyGrid {
    XCUIApplication *app = [XCUIApplication new];
    app.launchArguments = @[@"--ui-testing"];
    [app launch];

    XCUIElement *viewport = [[app descendantsMatchingType:XCUIElementTypeAny] matchingIdentifier:@"terminal.viewport"].firstMatch;
    XCTAssertTrue([viewport waitForExistenceWithTimeout:20], @"no Ghostty viewport");
    XCTAssertTrue([self waitForElement:viewport valueContaining:@"❯" timeout:30], @"no shell prompt");

    [[app.windows.firstMatch coordinateWithNormalizedOffset:CGVectorMake(0.5, 0.3)] tap];
    // Let the keyboard settle the final grid before asking the tty.
    [NSThread sleepForTimeInterval:2];
    [app typeText:@"stty size\n"];
    // The value holds one line per visible row; the label ends with the column count.
    // Both are read from the same snapshot, since the grid shrinks while the keyboard slides in.
    NSString *columns = [viewport.label componentsSeparatedByString:@" "].lastObject;
    NSPredicate *matchesGrid = [NSPredicate predicateWithBlock:^BOOL(XCUIElement *element, NSDictionary *bindings) {
        NSString *text = element.value;
        NSUInteger rows = [text componentsSeparatedByString:@"\n"].count;
        return [text containsString:[NSString stringWithFormat:@"\n%lu %@", (unsigned long) rows, columns]];
    }];
    XCTNSPredicateExpectation *expectation = [[XCTNSPredicateExpectation alloc] initWithPredicate:matchesGrid object:viewport];
    XCTAssertEqual([XCTWaiter waitForExpectations:@[expectation] timeout:30], XCTWaiterResultCompleted,
                   @"columns %@, viewport:\n%@", columns, viewport.value);
}

- (void)testLongLinesWrapAtTheGridEdge {
    XCUIApplication *app = [XCUIApplication new];
    app.launchArguments = @[@"--ui-testing"];
    [app launch];

    XCUIElement *viewport = [[app descendantsMatchingType:XCUIElementTypeAny] matchingIdentifier:@"terminal.viewport"].firstMatch;
    XCTAssertTrue([viewport waitForExistenceWithTimeout:20], @"no Ghostty viewport");
    XCTAssertTrue([self waitForElement:viewport valueContaining:@"❯" timeout:30], @"no shell prompt");
    [[app.windows.firstMatch coordinateWithNormalizedOffset:CGVectorMake(0.5, 0.3)] tap];
    [NSThread sleepForTimeInterval:2];
    // Wider than any iPhone grid, so it has to wrap.
    [app typeText:@"printf '%080d\\n' 0\n"];
    XCTAssertTrue([self waitForElement:viewport valueContaining:@"00000000000000000000\n" timeout:30], @"%@", viewport.value);

    int columns = [[viewport.label componentsSeparatedByString:@" "].lastObject intValue];
    XCTAssertGreaterThan(columns, 0);
    NSString *text = viewport.value;
    for (NSString *line in [text componentsSeparatedByString:@"\n"]) {
        if ([line hasPrefix:@"0000000000"]) {
            XCTAssertEqual((int) line.length, columns, @"wrapped away from the edge:\n%@", text);
            return;
        }
    }
    XCTFail(@"no output on screen:\n%@", text);
}

@end
