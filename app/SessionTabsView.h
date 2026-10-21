//
//  SessionTabsView.h
//  PhantOS
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class SessionTabsView;

@protocol SessionTabsViewDelegate <NSObject>
- (void)sessionTabsViewDidAskForNewTab:(SessionTabsView *)view;
- (void)sessionTabsView:(SessionTabsView *)view didSelectTabAtIndex:(NSUInteger)index;
- (void)sessionTabsView:(SessionTabsView *)view didCloseTabAtIndex:(NSUInteger)index;
- (void)sessionTabsView:(SessionTabsView *)view didAskToRenameTabAtIndex:(NSUInteger)index;
@end

// A floating row of Liquid Glass tabs, one per session, with a + button, like Ghostty's tab bar.
@interface SessionTabsView : UIView

@property (weak, nullable) id<SessionTabsViewDelegate> delegate;
// The green the selected tab is tinted with.
@property (nonatomic) UIColor *accentColor;

- (void)setTitles:(NSArray<NSString *> *)titles selectedIndex:(NSUInteger)selectedIndex;

@end

NS_ASSUME_NONNULL_END
