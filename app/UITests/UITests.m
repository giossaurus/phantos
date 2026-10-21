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
    XCTAssertTrue([self waitForElement:viewport valueContaining:@"#" timeout:30], @"no shell prompt");

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
    XCTAssertTrue([self waitForElement:viewport valueContaining:@"#" timeout:30], @"no shell prompt");

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
    // The motd is printed at login, while the surface is still settling its size.
    NSString *motd = @"You can install packages with: apk add <package>";
    XCTAssertTrue([self waitForElement:viewport valueContaining:@"#" timeout:30], @"no shell prompt");
    [NSThread sleepForTimeInterval:2];

    int columns = [[viewport.label componentsSeparatedByString:@" "].lastObject intValue];
    XCTAssertGreaterThan(columns, 0);
    NSString *text = viewport.value;
    for (NSString *line in [text componentsSeparatedByString:@"\n"]) {
        if (![line hasPrefix:@"You can install"])
            continue;
        // Either the whole sentence fits, or it breaks at the last column.
        NSString *trimmed = [line stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceCharacterSet];
        if ([trimmed isEqualToString:motd])
            return;
        XCTAssertEqual((int) line.length, columns, @"wrapped early:\n%@", text);
        return;
    }
    XCTFail(@"no motd on screen:\n%@", text);
}

@end
