//
//  LicensesViewController.m
//  PhantOS
//

#import "LicensesViewController.h"

@interface LicensesViewController ()
@property NSArray<NSDictionary<NSString *, NSString *> *> *licenses;
@end

@implementation LicensesViewController

- (instancetype)init {
    if (self = [super initWithStyle:UITableViewStyleInsetGrouped]) {
        self.title = @"Licenses & Credits";
        NSURL *index = [NSBundle.mainBundle URLForResource:@"Licenses" withExtension:@"plist" subdirectory:@"Licenses"];
        self.licenses = [NSArray arrayWithContentsOfURL:index] ?: @[];
    }
    return self;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.licenses.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"License"];
    if (cell == nil)
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"License"];
    NSDictionary<NSString *, NSString *> *license = self.licenses[indexPath.row];
    cell.textLabel.text = license[@"Name"];
    cell.detailTextLabel.text = license[@"Detail"];
    cell.detailTextLabel.textColor = UIColor.secondaryLabelColor;
    cell.detailTextLabel.numberOfLines = 0;
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
    return @"PhantOS is free software under the GNU General Public License, version 3. "
           @"Its source code is at github.com/giossaurus/ish-gio.";
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    NSDictionary<NSString *, NSString *> *license = self.licenses[indexPath.row];
    NSURL *file = [NSBundle.mainBundle URLForResource:license[@"File"] withExtension:nil subdirectory:@"Licenses"];
    NSString *text = file ? [NSString stringWithContentsOfURL:file encoding:NSUTF8StringEncoding error:nil] : nil;

    UITextView *textView = [UITextView new];
    textView.text = text ?: @"";
    textView.editable = NO;
    textView.dataDetectorTypes = UIDataDetectorTypeLink;
    textView.font = [UIFont preferredFontForTextStyle:UIFontTextStyleFootnote];
    textView.adjustsFontForContentSizeCategory = YES;
    textView.textContainerInset = UIEdgeInsetsMake(16, 12, 16, 12);
    textView.accessibilityIdentifier = @"license.text";

    UIViewController *page = [UIViewController new];
    page.title = license[@"Name"];
    page.view = textView;
    [self.navigationController pushViewController:page animated:YES];
}

@end
