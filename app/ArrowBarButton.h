//
//  ArrowBarButton.h
//  iSH
//
//  Created by Theodore Dubois on 9/23/18.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef enum : NSUInteger {
    ArrowNone = 0,
    ArrowUp,
    ArrowDown,
    ArrowLeft,
    ArrowRight,
} ArrowDirection;

@interface ArrowBarButton : UIControl

@property (nonatomic, readonly) ArrowDirection direction;
@property (nonatomic) UIKeyboardAppearance keyAppearance;

// Draws the key as a Liquid Glass capsule instead of a keyboard key.
- (void)useGlass;

@end

NS_ASSUME_NONNULL_END
