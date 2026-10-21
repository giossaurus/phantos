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

@end
