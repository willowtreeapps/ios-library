/* Copyright 2017 Urban Airship and Contributors */

#import <StoreKit/StoreKit.h>

#import "UARateAppAction.h"
#import "UAirship.h"
#import "UAConfig.h"
#import "UAPreferenceDataStore+Internal.h"
#import "UARateAppPromptViewController+Internal.h"

@interface UARateAppAction ()

@property (assign) BOOL showDialog;

@property (strong, nonatomic) NSString *linkPromptTitle;
@property (strong, nonatomic) NSString *linkPromptBody;

@end

@implementation UARateAppAction

BOOL legacy;

int const kMaxHeaderChars = 24;
int const kMaxDescriptionChars = 50;

NSTimeInterval const kSecondsInYear = 31536000;

// External
NSString *const UARateAppShowDialogKey = @"show_dialog";
NSString *const UARateAppLinkPromptTitleKey = @"link_prompt_header";
NSString *const UARateAppLinkPromptBodyKey = @"link_prompt_description";

// Internal
NSString *const UARateAppNibName = @"UARateAppPromptView";
NSString *const UARateAppItunesURLFormat = @"itms-apps://itunes.apple.com/app/id%@?action=write-review";
NSString *const UARateAppPromptTimestampsKey = @"RateAppActionPromptCount";
NSString *const UARateAppLinkPromptTimestampsKey = @"RateAppActionLinkPromptCount";
NSString *const UARateAppGenericDisplayName = @"This App";

- (void)performWithArguments:(UAActionArguments *)arguments
           completionHandler:(UAActionCompletionHandler)completionHandler {

    if (![self parseArguments:arguments]) {
        return;
    }

    // Display SKStoreReviewController
    if (!legacy && self.showDialog) {
        [self displaySystemDialog];
        completionHandler([UAActionResult emptyResult]);
        return;
    }

    NSString *linkString = [NSString stringWithFormat:UARateAppItunesURLFormat, [[UAirship shared].config itunesID]];

    // If the user doesn't want to show a dialog just open link to store
    if (!self.showDialog) {
        [self linkToStore:linkString];
        completionHandler([UAActionResult emptyResult]);
        return;
    }

    [self displayLinkDialog:linkString completionHandler:^(BOOL dismissed) {
        completionHandler([UAActionResult emptyResult]);
    }];
}

-(BOOL)parseArguments:(UAActionArguments *)arguments {

    legacy = ![[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion){10, 3, 0}];

    id showDialog;
    id linkPromptTitle;
    id linkPromptBody;

    if (arguments.value != nil && ![arguments.value isKindOfClass:[NSDictionary class]]) {
        UA_LWARN(@"Unable to parse arguments: %@", arguments);
        return NO;
    }

    showDialog = [arguments.value objectForKey:UARateAppShowDialogKey];
    linkPromptTitle = [arguments.value objectForKey:UARateAppLinkPromptTitleKey];
    linkPromptBody = [arguments.value objectForKey:UARateAppLinkPromptBodyKey];

    if (showDialog && ![showDialog isKindOfClass:[NSNumber class]]) {
        UA_LWARN(@"Parsed an invalid Show Dialog flag from arguments: %@. Show Dialog flag must be an NSNumber or BOOL.", arguments);
        return NO;
    }

    if (![[UAirship shared].config itunesID]) {
        UA_LWARN(@"iTunes ID is required.");
        return NO;
    }

    if (linkPromptTitle) {
        if (!showDialog) {
            UA_LWARN(@"Link prompt header should only be set when showDialog is set to true.");
            return NO;
        }

        if (![linkPromptTitle isKindOfClass:[NSString class]]) {
            UA_LWARN(@"Parsed an invalid link prompt header from arguments: %@. Link prompt header must be an NSString.", arguments);
            return NO;
        }

        if ([linkPromptTitle length] > 24) {
            UA_LWARN(@"Parsed an invalid link prompt header from arguments: %@. Link prompt header must be shorter than 24 characters in length.", arguments);
            return NO;
        }
    }

    if (linkPromptBody) {
        if (!showDialog) {
            UA_LWARN(@"Link prompt description should only be set when showDialog is set to true.");
            return NO;
        }

        if (![linkPromptBody isKindOfClass:[NSString class]]) {
            UA_LWARN(@"Parsed an invalid link prompt description from arguments: %@. Link prompt description must be an NSString.", arguments);
            return NO;
        }

        if ([linkPromptBody length] > 50) {
            UA_LWARN(@"Parsed an invalid link prompt description from arguments: %@. Link prompt description must be shorter than 50 characters in length.", arguments);
            return NO;
        }
    }

    self.showDialog = [showDialog boolValue];
    self.linkPromptTitle = linkPromptTitle;
    self.linkPromptBody = linkPromptBody;

    return YES;
}

-(void)displaySystemDialog {
    [SKStoreReviewController requestReview];

    [self storeTimestamp:UARateAppPromptTimestampsKey];

    if ([self getTimestampsForKey:UARateAppPromptTimestampsKey].count >= 3) {
        UA_LWARN(@"System rating prompt has attempted to display %lu times this year.", (unsigned long)[self getTimestampsForKey:UARateAppPromptTimestampsKey].count);
    }
}

-(NSArray *)getTimestampsForKey:(NSString *)key {
    UAPreferenceDataStore *dataStore = [UAPreferenceDataStore preferenceDataStoreWithKeyPrefix:[UAirship shared].config.appKey];

    return [dataStore objectForKey:key] ?: @[];
}

-(void)storeTimestamp:(NSString *)key {

    UAPreferenceDataStore *dataStore = [UAPreferenceDataStore preferenceDataStoreWithKeyPrefix:[UAirship shared].config.appKey];
    NSNumber *todayTimestamp = [NSNumber numberWithDouble:[[NSDate date] timeIntervalSince1970]];

    NSMutableArray *timestamps = [NSMutableArray arrayWithArray:[[NSUserDefaults standardUserDefaults]  arrayForKey:key]];

    // Remove timestamps more than a year old
    for (NSNumber *timestamp in timestamps) {
        if ((todayTimestamp.doubleValue - timestamp.doubleValue) > kSecondsInYear) {
            [timestamps removeObject:timestamp];
        }
    }



    // Store timestamp for this call
    [timestamps addObject:todayTimestamp];
    [dataStore setObject:timestamps forKey:key];
}

-(NSArray *)rateAppLinkPromptTimestamps {
    return [self getTimestampsForKey:UARateAppLinkPromptTimestampsKey];
}

-(NSArray *)rateAppPromptTimestamps {
    return [self getTimestampsForKey:UARateAppPromptTimestampsKey];
}

- (BOOL)canLinkToStore:(NSString *)linkString {
    // If the URL can't be opened, bail before displaying
    if (![[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:linkString]]) {
        UA_LWARN(@"Unable to open iTunes URL: %@", linkString);
        return NO;
    }
    return YES;
}

// Opens link to iTunes store rating section
-(void)linkToStore:(NSString *)linkString {
    if (![self canLinkToStore:linkString]) {
        return;
    }

    if (![[NSProcessInfo processInfo]
         isOperatingSystemAtLeastVersion:(NSOperatingSystemVersion){10, 0, 0}]) {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:linkString]];
        return;
    }

    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:linkString] options:@{} completionHandler:nil];
}

// Rate app action for iOS 8+ with applications track ID using a store URL link
-(void)displayLinkDialog:(NSString *)linkString completionHandler:(void (^)(BOOL dismissed))completionHandler {
    NSString *displayName;

    if (![self canLinkToStore:linkString]) {
        return;
    }

    // Prioritize the optional display name and fall back to short name
    if (NSBundle.mainBundle.infoDictionary[@"CFBundleDisplayName"]) {
        displayName = NSBundle.mainBundle.infoDictionary[@"CFBundleDisplayName"];
    } else {
        displayName = UARateAppGenericDisplayName;
        UA_LWARN(@"CFBundleDisplayName unavailable, falling back to generic display name: %@", UARateAppGenericDisplayName);
    }

    UARateAppPromptViewController *linkPrompt = [[UARateAppPromptViewController alloc] initWithNibName:UARateAppNibName bundle:[UAirship resources]];

    [linkPrompt displayWithHeader:self.linkPromptTitle description:self.linkPromptBody completionHandler:^(BOOL dismissed) {
        if (!dismissed) {
            [self linkToStore:linkString];
        }
#if RELEASE
        [self storeTimestamp:UARateAppLinkPromptTimestampsKey];

        if ([self getTimestampsForKey:UARateAppLinkPromptTimestampsKey].count >= 3) {
            UA_LWARN(@"System rating link prompt has attempted to display 3 or more times this year.");
        }
#endif
        completionHandler(dismissed);
    }];
}

- (BOOL)acceptsArguments:(UAActionArguments *)arguments {
    switch (arguments.situation) {
        case UASituationManualInvocation:
        case UASituationAutomation:
        case UASituationLaunchedFromPush:
        case UASituationForegroundInteractiveButton:
        case UASituationWebViewInvocation:
            return [self parseArguments:arguments];
        case UASituationForegroundPush:
        case UASituationBackgroundPush:
        case UASituationBackgroundInteractiveButton:
        default:
            return NO;
    }
}

@end
