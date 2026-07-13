#import <AppKit/AppKit.h>
#import <WebKit/WebKit.h>

@interface ClaudeUsageApp : NSObject <NSApplicationDelegate, WKNavigationDelegate, NSWindowDelegate>
@property(nonatomic, strong) NSStatusItem *statusItem;
@property(nonatomic, strong) NSMenu *menu;
@property(nonatomic, strong) WKWebView *webView;
@property(nonatomic, strong) NSWindow *loginWindow;
@property(nonatomic, strong) NSTimer *timer;
@property(nonatomic, copy) NSArray<NSDictionary *> *limits;
@property(nonatomic, copy) NSString *statusMessage;
@property(nonatomic) BOOL loading;
@property(nonatomic) BOOL hasPresentedUsageMenu;
@end

@implementation ClaudeUsageApp

- (NSImage *)robotIcon {
    NSImage *image = [NSImage imageWithSize:NSMakeSize(18, 18)
                                    flipped:NO
                             drawingHandler:^BOOL(NSRect destinationRect) {
        [NSColor.blackColor setStroke];
        [NSColor.blackColor setFill];

        NSBezierPath *antenna = [NSBezierPath bezierPath];
        antenna.lineWidth = 1.4;
        antenna.lineCapStyle = NSLineCapStyleRound;
        [antenna moveToPoint:NSMakePoint(9, 12.4)];
        [antenna lineToPoint:NSMakePoint(9, 15.2)];
        [antenna stroke];
        [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(8.1, 15.0, 1.8, 1.8)] fill];

        NSBezierPath *head = [NSBezierPath bezierPathWithRoundedRect:NSMakeRect(2.5, 2.5, 13, 10)
                                                             xRadius:3
                                                             yRadius:3];
        head.lineWidth = 1.5;
        [head stroke];

        NSBezierPath *ears = [NSBezierPath bezierPath];
        ears.lineWidth = 1.5;
        ears.lineCapStyle = NSLineCapStyleRound;
        [ears moveToPoint:NSMakePoint(1.2, 7.5)];
        [ears lineToPoint:NSMakePoint(2.5, 7.5)];
        [ears moveToPoint:NSMakePoint(15.5, 7.5)];
        [ears lineToPoint:NSMakePoint(16.8, 7.5)];
        [ears stroke];

        [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(5.0, 7.1, 2.0, 2.0)] fill];
        [[NSBezierPath bezierPathWithOvalInRect:NSMakeRect(11.0, 7.1, 2.0, 2.0)] fill];

        NSBezierPath *mouth = [NSBezierPath bezierPath];
        mouth.lineWidth = 1.3;
        mouth.lineCapStyle = NSLineCapStyleRound;
        [mouth moveToPoint:NSMakePoint(6.2, 5.1)];
        [mouth lineToPoint:NSMakePoint(11.8, 5.1)];
        [mouth stroke];
        return YES;
    }];
    image.template = YES;
    image.accessibilityDescription = @"Claude usage robot";
    return image;
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    self.limits = @[];
    self.statusMessage = @"Starting…";
    self.menu = [[NSMenu alloc] initWithTitle:@"Claude Usage"];
    self.statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSVariableStatusItemLength];

    NSStatusBarButton *button = self.statusItem.button;
    button.image = [self robotIcon];
    button.imagePosition = NSImageLeading;
    button.title = @" --";
    self.statusItem.menu = self.menu;

    WKWebViewConfiguration *configuration = [WKWebViewConfiguration new];
    configuration.websiteDataStore = [WKWebsiteDataStore defaultDataStore];
    configuration.defaultWebpagePreferences.allowsContentJavaScript = YES;
    self.webView = [[WKWebView alloc] initWithFrame:NSMakeRect(0, 0, 980, 720)
                                      configuration:configuration];
    self.webView.navigationDelegate = self;

    [self rebuildMenu];
    [self.webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"https://claude.ai"]]];
    self.timer = [NSTimer scheduledTimerWithTimeInterval:60
                                                  target:self
                                                selector:@selector(refreshUsage)
                                                userInfo:nil
                                                 repeats:YES];
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    [self.timer invalidate];
}

- (void)webView:(WKWebView *)webView didFinishNavigation:(WKNavigation *)navigation {
    [self refreshUsage];
}

- (void)webView:(WKWebView *)webView
decidePolicyForNavigationAction:(WKNavigationAction *)navigationAction
decisionHandler:(void (^)(WKNavigationActionPolicy))decisionHandler {
    NSString *scheme = navigationAction.request.URL.scheme.lowercaseString;
    if ([scheme isEqualToString:@"https"] || [scheme isEqualToString:@"about"]) {
        decisionHandler(WKNavigationActionPolicyAllow);
    } else {
        decisionHandler(WKNavigationActionPolicyCancel);
    }
}

- (void)refreshUsage {
    if (self.loading) return;
    if (self.webView.URL == nil) {
        self.statusMessage = @"Waiting for Claude…";
        [self rebuildMenu];
        return;
    }

    self.loading = YES;
    self.statusMessage = @"Refreshing…";
    [self rebuildMenu];

    NSString *script =
    @"try {"
     "  const row = document.cookie.split('; ').find(v => v.startsWith('lastActiveOrg='));"
     "  if (!row) return JSON.stringify({status:'signin'});"
     "  const orgId = decodeURIComponent(row.slice('lastActiveOrg='.length));"
     "  const options = {method:'GET', credentials:'include', headers:{Accept:'application/json'}};"
     "  const [usageResponse, overageResponse] = await Promise.all(["
     "    fetch('/api/organizations/' + encodeURIComponent(orgId) + '/usage', options),"
     "    fetch('/api/organizations/' + encodeURIComponent(orgId) + '/overage_spend_limit', options)"
     "  ]);"
     "  if (!usageResponse.ok) return JSON.stringify({status:'error', message:'HTTP ' + usageResponse.status});"
     "  const overage = overageResponse.ok ? await overageResponse.json() : null;"
     "  return JSON.stringify({status:'ok', payload:await usageResponse.json(), overage});"
     "} catch (error) { return JSON.stringify({status:'error', message:String(error)}); }";

    __weak typeof(self) weakSelf = self;
    [self.webView callAsyncJavaScript:script
                            arguments:@{}
                              inFrame:nil
                       inContentWorld:WKContentWorld.pageWorld
                    completionHandler:^(id result, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            typeof(self) self = weakSelf;
            if (!self) return;
            self.loading = NO;

            if (error || ![result isKindOfClass:[NSString class]]) {
                self.limits = @[];
                self.statusMessage = @"Open Sign In to connect";
                [self rebuildMenu];
                if (error) NSLog(@"Claude Usage JavaScript error: %@", error.localizedDescription);
                return;
            }

            NSData *data = [(NSString *)result dataUsingEncoding:NSUTF8StringEncoding];
            NSDictionary *response = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
            NSString *status = [response[@"status"] isKindOfClass:[NSString class]] ? response[@"status"] : nil;
            BOOL presentMenuAfterLogin = NO;
            if (!status) {
                self.limits = @[];
                self.statusMessage = @"Unexpected Claude response";
            } else if ([status isEqualToString:@"ok"]) {
                NSDictionary *payload = [response[@"payload"] isKindOfClass:[NSDictionary class]] ? response[@"payload"] : @{};
                NSDictionary *overage = [response[@"overage"] isKindOfClass:[NSDictionary class]] ? response[@"overage"] : nil;
                self.limits = [self parseLimits:payload overage:overage];
                self.statusMessage = self.limits.count ? @"" : @"No limits available";
                presentMenuAfterLogin = self.limits.count && !self.hasPresentedUsageMenu;
                if (presentMenuAfterLogin) self.hasPresentedUsageMenu = YES;
            } else if ([status isEqualToString:@"signin"]) {
                self.limits = @[];
                self.statusMessage = @"Sign in required";
            } else {
                self.limits = @[];
                self.statusMessage = [response[@"message"] isKindOfClass:[NSString class]] ? response[@"message"] : @"Usage unavailable";
            }
            [self rebuildMenu];
            if (presentMenuAfterLogin) {
                if (self.loginWindow.isVisible) [self.loginWindow orderOut:nil];
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.statusItem.button performClick:nil];
                });
            }
        });
    }];
}

- (NSArray<NSDictionary *> *)parseLimits:(NSDictionary *)payload overage:(NSDictionary *)overage {
    NSMutableArray *parsed = [NSMutableArray array];
    NSArray *rawLimits = [payload[@"limits"] isKindOfClass:[NSArray class]] ? payload[@"limits"] : nil;
    if (rawLimits.count) {
        for (id value in rawLimits) {
            if (![value isKindOfClass:[NSDictionary class]]) continue;
            NSDictionary *raw = value;
            NSString *kind = [raw[@"kind"] isKindOfClass:[NSString class]] ? raw[@"kind"] : nil;
            if (!kind) continue;
            NSString *label;
            if ([kind isEqualToString:@"session"]) label = @"5-hour";
            else if ([kind isEqualToString:@"weekly_all"]) label = @"Weekly";
            else if ([kind isEqualToString:@"weekly_scoped"]) {
                NSDictionary *scope = [raw[@"scope"] isKindOfClass:[NSDictionary class]] ? raw[@"scope"] : nil;
                NSDictionary *model = [scope[@"model"] isKindOfClass:[NSDictionary class]] ? scope[@"model"] : nil;
                NSString *name = [model[@"display_name"] isKindOfClass:[NSString class]] ? model[@"display_name"] : @"Model";
                label = [NSString stringWithFormat:@"%@ weekly", name];
            } else {
                label = [[kind stringByReplacingOccurrencesOfString:@"_" withString:@" "] capitalizedString];
            }
            [parsed addObject:@{
                @"label": label,
                @"percent": @([self numberFromValue:raw[@"percent"]]),
                @"reset": [self dateFromValue:raw[@"resets_at"]] ?: [NSNull null]
            }];
        }
    } else {
        NSArray *legacy = @[
            @[@"5-hour", @"five_hour"],
            @[@"Weekly", @"seven_day"],
            @[@"Sonnet weekly", @"seven_day_sonnet"],
            @[@"Opus weekly", @"seven_day_opus"],
            @[@"OAuth apps weekly", @"seven_day_oauth_apps"],
            @[@"Design weekly", @"seven_day_omelette"],
            @[@"Cowork weekly", @"seven_day_cowork"]
        ];
        for (NSArray *pair in legacy) {
            NSDictionary *raw = [payload[pair[1]] isKindOfClass:[NSDictionary class]] ? payload[pair[1]] : nil;
            if (!raw) continue;
            [parsed addObject:@{
                @"label": pair[0],
                @"percent": @([self numberFromValue:raw[@"utilization"]]),
                @"reset": [self dateFromValue:raw[@"resets_at"]] ?: [NSNull null]
            }];
        }
    }

    NSDictionary *embedded = [payload[@"extra_usage"] isKindOfClass:[NSDictionary class]] ? payload[@"extra_usage"] : nil;
    NSDictionary *meter = overage.count ? overage : embedded;
    id usedValue = meter[@"used_credits"];
    id capValue = meter[@"monthly_credit_limit"] ?: meter[@"monthly_limit"];
    BOOL enabled = [meter[@"is_enabled"] respondsToSelector:@selector(boolValue)] && [meter[@"is_enabled"] boolValue];
    if (meter && (enabled || usedValue != nil || capValue != nil)) {
        double usedCents = [self numberFromValue:usedValue];
        double capCents = [self numberFromValue:capValue];
        double percent = capCents > 0 ? (usedCents / capCents) * 100.0 : 0;
        NSString *currency = [meter[@"currency"] isKindOfClass:[NSString class]] ? [meter[@"currency"] uppercaseString] : @"USD";
        NSDictionary *symbols = @{@"USD": @"$", @"EUR": @"€", @"GBP": @"£", @"INR": @"₹", @"AUD": @"A$", @"CAD": @"C$"};
        NSString *symbol = symbols[currency] ?: [currency stringByAppendingString:@" "];
        NSString *valueText = capCents > 0
            ? [NSString stringWithFormat:@"%@%.2f / %@%.2f (%ld%%)", symbol, usedCents / 100.0, symbol, capCents / 100.0, (long)llround(percent)]
            : [NSString stringWithFormat:@"%@%.2f used", symbol, usedCents / 100.0];
        BOOL blocked = [meter[@"out_of_credits"] respondsToSelector:@selector(boolValue)] && [meter[@"out_of_credits"] boolValue];
        [parsed addObject:@{
            @"label": blocked ? @"Monthly spend — BLOCKED" : @"Monthly spend",
            @"percent": @(percent),
            @"value": valueText,
            @"reset": [self dateFromValue:meter[@"disabled_until"]] ?: [NSNull null]
        }];
    }
    return parsed;
}

- (double)numberFromValue:(id)value {
    if ([value respondsToSelector:@selector(doubleValue)]) return [value doubleValue];
    return 0;
}

- (NSDate *)dateFromValue:(id)value {
    if ([value isKindOfClass:[NSNumber class]]) {
        double timestamp = [value doubleValue];
        if (timestamp > 100000000000.0) timestamp /= 1000.0;
        return [NSDate dateWithTimeIntervalSince1970:timestamp];
    }
    if (![value isKindOfClass:[NSString class]]) return nil;
    static NSISO8601DateFormatter *fractional;
    static NSISO8601DateFormatter *standard;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        fractional = [NSISO8601DateFormatter new];
        fractional.formatOptions = NSISO8601DateFormatWithInternetDateTime | NSISO8601DateFormatWithFractionalSeconds;
        standard = [NSISO8601DateFormatter new];
        standard.formatOptions = NSISO8601DateFormatWithInternetDateTime;
    });
    return [fractional dateFromString:value] ?: [standard dateFromString:value];
}

- (void)rebuildMenu {
    [self.menu removeAllItems];

    if (!self.limits.count) {
        NSMenuItem *status = [[NSMenuItem alloc] initWithTitle:self.statusMessage action:nil keyEquivalent:@""];
        status.enabled = NO;
        [self.menu addItem:status];
        self.statusItem.button.title = @" --";
    } else {
        NSMutableArray *summary = [NSMutableArray array];
        for (NSDictionary *limit in self.limits) {
            NSInteger percent = (NSInteger)llround([limit[@"percent"] doubleValue]);
            NSString *value = [limit[@"value"] isKindOfClass:[NSString class]] ? limit[@"value"] : nil;
            NSString *title = value.length
                ? [NSString stringWithFormat:@"%@: %@", limit[@"label"], value]
                : [NSString stringWithFormat:@"%@: %ld%%", limit[@"label"], (long)percent];
            NSDate *reset = [limit[@"reset"] isKindOfClass:[NSDate class]] ? limit[@"reset"] : nil;
            NSString *countdown = [self resetCountdown:reset];
            if (countdown.length) title = [NSString stringWithFormat:@"%@ · %@", title, countdown];
            NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title action:nil keyEquivalent:@""];
            item.enabled = NO;
            item.toolTip = [self resetDescription:reset];
            [self.menu addItem:item];
            if (summary.count < 2) [summary addObject:[NSString stringWithFormat:@"%ld%%", (long)percent]];
        }
        self.statusItem.button.title = [NSString stringWithFormat:@" %@", [summary componentsJoinedByString:@" · "]];
    }

    [self.menu addItem:[NSMenuItem separatorItem]];
    [self addMenuItem:@"Refresh" action:@selector(refreshUsage) key:@"r" enabled:!self.loading];
    [self addMenuItem:(self.limits.count ? @"Manage Claude Session…" : @"Sign In with Email…")
                action:@selector(showLoginWindow) key:@"l" enabled:YES];
    if (!self.limits.count) {
        [self addMenuItem:@"Open Login Link from Clipboard"
                    action:@selector(openLoginLinkFromClipboard) key:@"v" enabled:YES];
    }
    [self addMenuItem:@"Clear Companion Login" action:@selector(clearLogin) key:@"" enabled:YES];
    [self.menu addItem:[NSMenuItem separatorItem]];
    [self addMenuItem:@"Quit Claude Usage" action:@selector(quitApp) key:@"q" enabled:YES];
}

- (void)addMenuItem:(NSString *)title action:(SEL)action key:(NSString *)key enabled:(BOOL)enabled {
    NSMenuItem *item = [[NSMenuItem alloc] initWithTitle:title action:action keyEquivalent:key];
    item.target = self;
    item.enabled = enabled;
    [self.menu addItem:item];
}

- (NSString *)resetDescription:(NSDate *)date {
    if (!date) return nil;
    NSDateFormatter *formatter = [NSDateFormatter new];
    formatter.dateStyle = NSDateFormatterMediumStyle;
    formatter.timeStyle = NSDateFormatterShortStyle;
    return [NSString stringWithFormat:@"Resets %@", [formatter stringFromDate:date]];
}

- (NSString *)resetCountdown:(NSDate *)date {
    if (!date) return nil;
    NSTimeInterval seconds = date.timeIntervalSinceNow;
    if (seconds <= 0) return @"reset pending";

    NSInteger minutes = MAX(1, (NSInteger)ceil(seconds / 60.0));
    NSInteger days = minutes / (24 * 60);
    NSInteger hours = (minutes % (24 * 60)) / 60;
    NSInteger remainingMinutes = minutes % 60;

    if (days > 0) {
        return hours > 0
            ? [NSString stringWithFormat:@"resets in %ldd %ldh", (long)days, (long)hours]
            : [NSString stringWithFormat:@"resets in %ldd", (long)days];
    }
    if (hours > 0) {
        return remainingMinutes > 0
            ? [NSString stringWithFormat:@"resets in %ldh %ldm", (long)hours, (long)remainingMinutes]
            : [NSString stringWithFormat:@"resets in %ldh", (long)hours];
    }
    return [NSString stringWithFormat:@"resets in %ldm", (long)remainingMinutes];
}

- (void)showLoginWindow {
    if (!self.loginWindow) {
        self.loginWindow = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 980, 720)
                                                       styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                                                                 NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable
                                                         backing:NSBackingStoreBuffered
                                                           defer:NO];
        self.loginWindow.title = @"Claude Usage – Sign In with Email";

        NSView *container = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 980, 720)];
        NSTextField *hint = [NSTextField labelWithString:
            @"Personal: use email. Enterprise: complete SSO, then select the organization to monitor."];
        hint.frame = NSMakeRect(20, 681, 940, 24);
        hint.alignment = NSTextAlignmentCenter;
        hint.textColor = NSColor.secondaryLabelColor;
        hint.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;

        NSBox *separator = [[NSBox alloc] initWithFrame:NSMakeRect(0, 675, 980, 1)];
        separator.boxType = NSBoxSeparator;
        separator.autoresizingMask = NSViewWidthSizable | NSViewMinYMargin;

        self.webView.frame = NSMakeRect(0, 0, 980, 675);
        self.webView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        [container addSubview:self.webView];
        [container addSubview:separator];
        [container addSubview:hint];
        self.loginWindow.contentView = container;
        self.loginWindow.releasedWhenClosed = NO;
        self.loginWindow.delegate = self;
        [self.loginWindow center];
    }
    [self.loginWindow makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];
    if (!self.webView.URL) {
        [self.webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"https://claude.ai"]]];
    }
}

- (void)openLoginLinkFromClipboard {
    NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
    NSString *value = [pasteboard stringForType:NSPasteboardTypeURL];
    if (!value.length) value = [pasteboard stringForType:NSPasteboardTypeString];
    value = [value stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    NSURL *url = value.length ? [NSURL URLWithString:value] : nil;

    if (!url || ![url.scheme.lowercaseString isEqualToString:@"https"]) {
        NSAlert *alert = [NSAlert new];
        alert.messageText = @"No secure login link found";
        alert.informativeText = @"In your Claude login email, copy the link address, then choose this menu item again.";
        [alert runModal];
        return;
    }

    [self showLoginWindow];
    self.statusMessage = @"Opening copied login link…";
    [self rebuildMenu];
    [self.webView loadRequest:[NSURLRequest requestWithURL:url]];
}

- (void)clearLogin {
    WKWebsiteDataStore *store = [WKWebsiteDataStore defaultDataStore];
    NSSet *types = [WKWebsiteDataStore allWebsiteDataTypes];
    __weak typeof(self) weakSelf = self;
    [store fetchDataRecordsOfTypes:types completionHandler:^(NSArray<WKWebsiteDataRecord *> *records) {
        NSPredicate *predicate = [NSPredicate predicateWithBlock:^BOOL(WKWebsiteDataRecord *record, NSDictionary *bindings) {
            return [record.displayName containsString:@"claude.ai"] || [record.displayName containsString:@"anthropic.com"];
        }];
        [store removeDataOfTypes:types forDataRecords:[records filteredArrayUsingPredicate:predicate] completionHandler:^{
            dispatch_async(dispatch_get_main_queue(), ^{
                typeof(self) self = weakSelf;
                if (!self) return;
                self.limits = @[];
                self.statusMessage = @"Sign in required";
                [self rebuildMenu];
                [self.webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"https://claude.ai"]]];
            });
        }];
    }];
}

- (void)windowWillClose:(NSNotification *)notification {
    [self refreshUsage];
}

- (void)quitApp {
    [NSApp terminate:nil];
}

@end

int main(int argc, const char *argv[]) {
    @autoreleasepool {
        NSApplication *application = [NSApplication sharedApplication];
        ClaudeUsageApp *delegate = [ClaudeUsageApp new];
        application.delegate = delegate;
        [application setActivationPolicy:NSApplicationActivationPolicyAccessory];
        [application run];
    }
    return 0;
}
