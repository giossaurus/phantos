//
//  SessionTabsView.m
//  PhantOS
//

#import "SessionTabsView.h"

@interface SessionTabsView ()
@property UIVisualEffectView *container;
@property UIScrollView *scrollView;
@property UIStackView *tabs;
@property UIButton *addButton;
@property NSArray<NSString *> *titles;
@property NSUInteger selectedIndex;
@end

@implementation SessionTabsView

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        _accentColor = [UIColor colorWithRed:80/255. green:250/255. blue:160/255. alpha:1];

        // Glass shapes inside one container blend into each other as tabs come and go, like
        // SwiftUI's GlassEffectContainer.
        UIGlassContainerEffect *containerEffect = [UIGlassContainerEffect new];
        // Shapes closer than this melt together; tabs sit further apart than that, so each stays a pill.
        containerEffect.spacing = 4;
        self.container = [[UIVisualEffectView alloc] initWithEffect:containerEffect];
        self.container.accessibilityIdentifier = @"tabs.glass";
        self.container.isAccessibilityElement = NO;
        self.container.translatesAutoresizingMaskIntoConstraints = NO;
        [self addSubview:self.container];

        self.scrollView = [UIScrollView new];
        self.scrollView.showsHorizontalScrollIndicator = NO;
        self.scrollView.alwaysBounceHorizontal = YES;
        self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
        [self.container.contentView addSubview:self.scrollView];

        self.tabs = [UIStackView new];
        self.tabs.axis = UILayoutConstraintAxisHorizontal;
        self.tabs.spacing = 8;
        self.tabs.translatesAutoresizingMaskIntoConstraints = NO;
        [self.scrollView addSubview:self.tabs];

        UIButtonConfiguration *add = [UIButtonConfiguration glassButtonConfiguration];
        add.image = [UIImage systemImageNamed:@"plus"];
        add.preferredSymbolConfigurationForImage = [UIImageSymbolConfiguration configurationWithWeight:UIImageSymbolWeightSemibold];
        add.baseForegroundColor = UIColor.labelColor;
        add.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
        self.addButton = [UIButton buttonWithConfiguration:add primaryAction:[UIAction actionWithHandler:^(UIAction *action) {
            [self.delegate sessionTabsViewDidAskForNewTab:self];
        }]];
        self.addButton.accessibilityLabel = @"New Tab";
        self.addButton.translatesAutoresizingMaskIntoConstraints = NO;
        [self.container.contentView addSubview:self.addButton];

        [NSLayoutConstraint activateConstraints:@[
            [self.container.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
            [self.container.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
            [self.container.topAnchor constraintEqualToAnchor:self.topAnchor],
            [self.container.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],

            [self.scrollView.leadingAnchor constraintEqualToAnchor:self.container.contentView.leadingAnchor constant:12],
            [self.scrollView.topAnchor constraintEqualToAnchor:self.container.contentView.topAnchor],
            [self.scrollView.bottomAnchor constraintEqualToAnchor:self.container.contentView.bottomAnchor],
            [self.scrollView.trailingAnchor constraintEqualToAnchor:self.addButton.leadingAnchor constant:-12],

            [self.tabs.leadingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.leadingAnchor],
            [self.tabs.trailingAnchor constraintEqualToAnchor:self.scrollView.contentLayoutGuide.trailingAnchor],
            [self.tabs.centerYAnchor constraintEqualToAnchor:self.scrollView.centerYAnchor],
            [self.tabs.heightAnchor constraintEqualToConstant:36],

            [self.addButton.trailingAnchor constraintEqualToAnchor:self.container.contentView.trailingAnchor constant:-12],
            [self.addButton.centerYAnchor constraintEqualToAnchor:self.container.contentView.centerYAnchor],
            [self.addButton.widthAnchor constraintEqualToConstant:44],
            [self.addButton.heightAnchor constraintEqualToConstant:44],
        ]];
    }
    return self;
}

- (void)setAccentColor:(UIColor *)accentColor {
    _accentColor = accentColor;
    [self rebuildTabs];
}

- (void)setTitles:(NSArray<NSString *> *)titles selectedIndex:(NSUInteger)selectedIndex {
    self.titles = titles;
    self.selectedIndex = selectedIndex;
    [self rebuildTabs];
}

- (void)rebuildTabs {
    // A title change only restyles the tabs in place: replacing a button under a finger that's
    // holding it would cancel its menu.
    if (self.tabs.arrangedSubviews.count != self.titles.count) {
        for (UIView *tab in self.tabs.arrangedSubviews) {
            [self.tabs removeArrangedSubview:tab];
            [tab removeFromSuperview];
        }
        for (NSUInteger index = 0; index < self.titles.count; index++)
            [self.tabs addArrangedSubview:[self makeTabAtIndex:index]];
    }
    [self.tabs.arrangedSubviews enumerateObjectsUsingBlock:^(UIView *view, NSUInteger index, BOOL *stop) {
        [self styleTab:(UIButton *) view atIndex:index];
    }];
    [self layoutIfNeeded];
    UIView *selected = self.selectedIndex < self.tabs.arrangedSubviews.count ? self.tabs.arrangedSubviews[self.selectedIndex] : nil;
    if (selected)
        [self.scrollView scrollRectToVisible:selected.frame animated:YES];
}

- (UIButton *)makeTabAtIndex:(NSUInteger)index {
    UIButton *tab = [UIButton buttonWithConfiguration:[UIButtonConfiguration glassButtonConfiguration] primaryAction:[UIAction actionWithHandler:^(UIAction *action) {
        [self.delegate sessionTabsView:self didSelectTabAtIndex:index];
    }]];
    tab.accessibilityIdentifier = @"tab";
    [tab.widthAnchor constraintLessThanOrEqualToConstant:180].active = YES;
    // Holding a tab offers to rename it, or to close it in red, as iOS marks destructive actions.
    UIAction *close = [UIAction actionWithTitle:@"Close Tab" image:[UIImage systemImageNamed:@"xmark"] identifier:nil handler:^(UIAction *action) {
        [self.delegate sessionTabsView:self didCloseTabAtIndex:index];
    }];
    close.attributes = UIMenuElementAttributesDestructive;
    tab.menu = [UIMenu menuWithChildren:@[
        [UIAction actionWithTitle:@"Rename Tab" image:[UIImage systemImageNamed:@"pencil"] identifier:nil handler:^(UIAction *action) {
            [self.delegate sessionTabsView:self didAskToRenameTabAtIndex:index];
        }],
        close,
    ]];
    return tab;
}

- (void)styleTab:(UIButton *)tab atIndex:(NSUInteger)index {
    NSString *title = self.titles[index];
    BOOL selected = index == self.selectedIndex;
    UIButtonConfiguration *configuration = selected ? [UIButtonConfiguration prominentGlassButtonConfiguration]
                                                    : [UIButtonConfiguration glassButtonConfiguration];
    configuration.title = title;
    configuration.cornerStyle = UIButtonConfigurationCornerStyleCapsule;
    configuration.titleLineBreakMode = NSLineBreakByTruncatingHead;
    configuration.contentInsets = NSDirectionalEdgeInsetsMake(6, 14, 6, 14);
    if (selected) {
        configuration.baseBackgroundColor = self.accentColor;
        configuration.baseForegroundColor = UIColor.blackColor;
    } else {
        configuration.baseForegroundColor = UIColor.secondaryLabelColor;
    }
    configuration.titleTextAttributesTransformer = ^NSDictionary *(NSDictionary *attributes) {
        NSMutableDictionary *result = attributes.mutableCopy;
        UIFont *font = [UIFont preferredFontForTextStyle:UIFontTextStyleSubheadline];
        result[NSFontAttributeName] = selected ? [UIFont systemFontOfSize:font.pointSize weight:UIFontWeightSemibold] : font;
        return result;
    };
    tab.configuration = configuration;
    tab.accessibilityLabel = [NSString stringWithFormat:@"Tab %lu, %@", (unsigned long) index + 1, title];
    tab.accessibilityTraits = selected ? tab.accessibilityTraits | UIAccessibilityTraitSelected
                                       : tab.accessibilityTraits & ~UIAccessibilityTraitSelected;
}

@end
