//
//  Terminal.h
//  iSH
//
//  Created by Theodore Dubois on 10/18/17.
//

#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>

struct tty;
@class GhosttyTerminalHost;

@interface Terminal : NSObject

// Ghostty draws the terminal unless the UseHterm default is set.
@property (class, readonly) BOOL usesGhostty;
@property (readonly) GhosttyTerminalHost *ghostty;
// The grid the last Ghostty surface settled at, kept across launches, so a new session's tty can
// start at the screen's size instead of 80 columns. 0 when nothing has been measured yet.
@property (class, readonly) int lastColumns;
@property (class, readonly) int lastRows;
// What the program running in it calls itself (OSC 0/2). TerminalTitleDidChangeNotification follows changes.
@property (readonly, nullable) NSString *title;

+ (Terminal *)terminalWithType:(int)type number:(int)number;
#if !ISH_LINUX
// Returns a strong struct tty and a Terminal that has a weak reference to the same tty
+ (Terminal *)createPseudoTerminal:(struct tty **)tty;
#endif

+ (Terminal *)terminalWithUUID:(NSUUID *)uuid;
@property (readonly) NSUUID *uuid;

+ (void)convertCommand:(NSArray<NSString *> *)command toArgs:(char *)argv limitSize:(size_t)maxSize;

- (int)sendOutput:(const void *)buf length:(int)len;
- (void)sendInput:(NSData *)input;

- (NSString *)arrow:(char)direction;

// Make this terminal no longer be the singleton terminal with its type and number. Will happen eventually if all references go away, but sometimes you want it to happen now.
- (void)destroy;

@property (readonly) WKWebView *webView;
@property (nonatomic) BOOL enableVoiceOverAnnounce;
// Use KVO on this
@property (readonly) BOOL loaded;

@end

extern struct tty_driver ios_console_driver;
extern NSString *const TerminalTitleDidChangeNotification;
