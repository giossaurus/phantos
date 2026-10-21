//
//  AccessoryButton.m
//  iSH
//
//  Created by Theodore Dubois on 9/22/18.
//

#import "BarButton.h"

@interface BarButton ()
@property BOOL usesGlass;
@end

extern UIAccessibilityTraits UIAccessibilityTraitToggle;

@implementation BarButton

- (void)awakeFromNib {
    [super awakeFromNib];
    self.layer.cornerRadius = 5;
    self.layer.shadowOffset = CGSizeMake(0, 1);
    self.layer.shadowOpacity = 0.4;
    self.layer.shadowRadius = 0;
    self.backgroundColor = self.defaultColor;
    self.keyAppearance = UIKeyboardAppearanceLight;
    self.accessibilityTraits |= UIAccessibilityTraitKeyboardKey;
    if (self.toggleable) {
        self.accessibilityTraits |= 0x20000000000000;
    }
}

- (UIColor *)primaryColor {
    if (self.keyAppearance == UIKeyboardAppearanceLight)
        return UIColor.whiteColor;
    else
        return [UIColor colorWithRed:1 green:1 blue:1 alpha:77/255.];
}
- (UIColor *)secondaryColor {
    if (self.keyAppearance == UIKeyboardAppearanceLight)
        return [UIColor colorWithRed:172/255. green:180/255. blue:190/255. alpha:1];
    else
        return [UIColor colorWithRed:147/255. green:147/255. blue:147/255. alpha:66/255.];
}
- (UIColor *)defaultColor {
    if (self.secondary)
        return self.secondaryColor;
    return self.primaryColor;
}
- (UIColor *)highlightedColor {
    if (!self.secondary)
        return self.secondaryColor;
    return self.primaryColor;
}

- (void)useGlass {
    // The system's glass button, so the key reads like any other iOS 26 control: an SF Symbol in
    // the label colour on regular glass, and a held control key on prominent glass in the theme's
    // green.
    self.usesGlass = YES;
    self.backgroundColor = UIColor.clearColor;
    self.layer.shadowOpacity = 0;
    UIImage *image = [self imageForState:UIControlStateNormal];
    NSString *title = [self titleForState:UIControlStateNormal];
    UIColor *green = [UIColor colorWithRed:80/255. green:250/255. blue:160/255. alpha:1];
    self.configurationUpdateHandler = ^(UIButton *button) {
        UIButtonConfiguration *configuration = button.isSelected ? [UIButtonConfiguration prominentGlassButtonConfiguration]
                                                                 : [UIButtonConfiguration glassButtonConfiguration];
        configuration.image = image;
        configuration.title = image ? nil : title;
        configuration.preferredSymbolConfigurationForImage =
            [UIImageSymbolConfiguration configurationWithTextStyle:UIFontTextStyleBody scale:UIImageSymbolScaleMedium];
        configuration.preferredSymbolConfigurationForImage = [configuration.preferredSymbolConfigurationForImage
            configurationByApplyingConfiguration:[UIImageSymbolConfiguration configurationWithWeight:UIImageSymbolWeightSemibold]];
        configuration.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        configuration.baseForegroundColor = button.isSelected ? UIColor.blackColor : UIColor.labelColor;
        if (button.isSelected)
            configuration.baseBackgroundColor = green;
        button.configuration = configuration;
    };
    [self setNeedsUpdateConfiguration];
}

- (void)chooseBackground {
    if (self.usesGlass) {
        [self setNeedsUpdateConfiguration];
        return;
    }
    if (self.selected || self.highlighted) {
        self.backgroundColor = self.highlightedColor;
    } else {
        [UIView animateWithDuration:0 delay:0.1 options:UIViewAnimationOptionAllowUserInteraction animations:^{
            self.backgroundColor = self.defaultColor;
        } completion:nil];
    }
    if (self.keyAppearance == UIKeyboardAppearanceLight) {
        self.tintColor = UIColor.blackColor;
    } else {
        self.tintColor = UIColor.whiteColor;
    }
    [self setTitleColor:self.tintColor forState:UIControlStateNormal];
}

- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    [self chooseBackground];
}
- (void)setSelected:(BOOL)selected {
    [super setSelected:selected];
    [self chooseBackground];
}

- (void)setKeyAppearance:(UIKeyboardAppearance)keyAppearance {
    _keyAppearance = keyAppearance;
    [self chooseBackground];
}

- (NSString *)accessibilityValue {
    if (self.toggleable) {
        return self.selected ? @"1" : @"0";
    }
    return nil;
}

@end
