/**
 * Ti.Urbanairship Module
 * Copyright (c) 2010-2013 by Appcelerator, Inc. All Rights Reserved.
 * Please see the LICENSE included with this distribution for details.
 */

#import "TiUrbanairshipModule.h"
#import "TiApp.h"
#import "TiBase.h"
#import "TiHost.h"
#import "TiUtils.h"
#import "TiBlob.h"
#import "TiUIButtonBarProxy.h"

#import "UAirship.h"
#import "UAConfig.h"
#import "UAPush.h"
#import "UAPushNotificationHandler.h"

@interface TiUrbanairshipModule()
@property (nonatomic, strong) UAPushNotificationHandler *pushHandler;
@end

@implementation TiUrbanairshipModule

@synthesize autoResetBadge, notificationsEnabled;

-(NSString*) EVENT_URBAN_AIRSHIP_CALLBACK { return @"push_notification_callback"; }
-(NSString*) EVENT_URBAN_AIRSHIP_SUCCESS { return @"push_registration_success"; }
-(NSString*) EVENT_URBAN_AIRSHIP_ERROR { return @"push_registration_error"; }

#pragma mark Internal

// this is generated for your module, please do not change it
-(id)moduleGUID
{
	return @"d00fbe22-e01d-4ca5-b11b-133155320625";
}

// this is generated for your module, please do not change it
-(NSString*)moduleId
{
	return @"ti.urbanairship";
}

#pragma mark Lifecycle

-(void)startup
{
	// this method is called when the module is first loaded
	// you *must* call the superclass
	[super startup];
	
	// Default is automatically reset badge
	autoResetBadge = YES;
    self.pushHandler = nil;
	
	NSLog(@"[INFO] %@ loaded",self);

    dispatch_async(dispatch_get_main_queue(), ^{
        [self startUrbanAirship];
    });
}

-(void)shutdown:(id)sender
{
    // you *must* call the superclass
    [super shutdown:sender];
}

#pragma mark Internal Memory Management

-(void)didReceiveMemoryWarning:(NSNotification*)notification
{
    // optionally release any resources that can be dynamically
    // reloaded once memory is available - such as caches
    [super didReceiveMemoryWarning:notification];
}

#pragma mark Listener Notifications

-(void)_listenerAdded:(NSString *)type count:(int)count
{
    if (count == 1 && [type isEqualToString:@"my_event"])
    {
        // the first (of potentially many) listener is being added
        // for event named 'my_event'
    }
}

-(void)_listenerRemoved:(NSString *)type count:(int)count
{
    if (count == 0 && [type isEqualToString:@"my_event"])
    {
        // the last listener called for event named 'my_event' has
        // been removed, we can optionally clean up any resources
        // since no body is listening at this point for that event
    }
}


// This is called when the application receives the applicationWillResignActive message
-(void)suspend:(id)sender
{
	NSLog(@"[DEBUG] Urban Airship received suspend notification");

	// See MOD-165
	if (!initialized) {
		NSLog(@"[DEBUG] Ignoring notification -- not initialized yet");
		return;
	}
}

// This is called when the application receives the applicationDidBecomeActive message
-(void)resumed:(id)sender
{
	// See MOD-165
	if (!initialized) {
		NSLog(@"[DEBUG] Ignoring notification -- not initialized yet");
		return;
	}
	
	// [MOD-238] Automatically reset badge count on resume
    [self handleAutoBadgeReset];
}

- (void)checkIfSimulator {
    if ([[[UIDevice currentDevice] model] rangeOfString:@"Simulator"].location != NSNotFound) {
		NSLog(@"[ERROR] You can see UAInbox in the simulator, but you will not be able to receive push notifications");
    }
}

-(void)startUrbanAirship
{
	// SUPER WARNING!!!!!!
	// This initialization method MUST be run on the UI thread. The setup of UAInboxUI and UAInboxNavUI must occur
	// on the UI thread or else it will not draw properly. A perfect symptom of this is that the navigation bar in
	// the navigation controller draws transparent and the leftbarbutton doesn't render on first display. I spent
	// a good amount of time trying to figure out why this was occurring until I realized that this method was being
	// called by a newly added method that was not being run on the UI thread.
	// The following ENSURE_CONSISTENCY macro verifies that any calls in the future will be caught immediately!
	ENSURE_CONSISTENCY([NSThread isMainThread]);

	NSLog(@"[DEBUG] Urban Airship taking off");

    // Set log level for debugging config loading (optional)
    // It will be set to the value in the loaded config upon takeOff
    [UAirship setLogLevel:UALogLevelTrace];

    // Create Airship singleton that's used to talk to Urban Airship servers.
	UAConfig *config = [UAConfig defaultConfig];

	// Disable the automatic integration support in UA for backward compatibility
	// config.automaticSetupEnabled = YES;

	// Call takeOff (which creates the UAirship singleton)
	[UAirship takeOff:config];
}

#pragma Public APIs

-(NSArray*)getUserNotificationTypes
{
    NSMutableArray *retval = [[NSMutableArray alloc] init];
    UIUserNotificationType types = [UAirship push].userNotificationTypes;
    
    if (types & UIUserNotificationTypeAlert);
        [retval addObject:NUMINT(UIUserNotificationTypeAlert)];
    if (types & UIUserNotificationTypeBadge);
        [retval addObject:NUMINT(UIUserNotificationTypeBadge)];
    if (types & UIUserNotificationTypeSound);
        [retval addObject:NUMINT(UIUserNotificationTypeSound)];
    
    return retval;
}

-(void)setUserNotificationTypes:(id)args
{
    ENSURE_ARRAY(args);
    UIUserNotificationType types = UIUserNotificationTypeNone;
    
    UA_LDEBUG(@"Setting Push Notification Types...");
    for (int i=0; i<[args count]; ++i) {
        types |= (UIUserNotificationType)[args objectAtIndex: i];
    }
    
    [UAirship push].userNotificationTypes = types;
}

-(void)handleNotification:(id)arg
{
	// The only argument to this method is the userInfo dictionary received from
	// the remote notification
	
	ENSURE_UI_THREAD_1_ARG(arg);	
	
	//[self initializeIfNeeded];
	
	id userInfo = [arg objectAtIndex:0];
    NSNumber* inForeground = [arg objectAtIndex:1];
    NSNumber* wasLaunched = [arg objectAtIndex:2];
    
	ENSURE_DICT(userInfo);
    
    NSMutableDictionary* data = [NSMutableDictionary dictionaryWithDictionary:userInfo];
    [data setValue:inForeground forKey:@"inForeground"];
    [data setValue:wasLaunched forKey:@"wasLaunched"];
	
	NSLog(@"[DEBUG] Urban Airship received notification");
    [self fireEvent:[self EVENT_URBAN_AIRSHIP_CALLBACK] withObject:data];
	
    [self handleAutoBadgeReset];
}

-(BOOL)pushEnabled
{
    return [[UIApplication sharedApplication] enabledRemoteNotificationTypes] != UIRemoteNotificationTypeNone;
}

-(BOOL)isFlying
{
    // We are "flying" if we are initialized AND notifications are currently enabled on the application
    return initialized && [self notificationsEnabled];
}

-(void)updateUAServer
{
    if (initialized) {
        [[UAirship push] updateRegistration];
    }
}

-(void)handleAutoBadgeReset
{
    if (autoResetBadge) {
        [[UAirship push] resetBadge];
        [self updateUAServer];
    }
}

#pragma mark Badge

// [MOD-208] and [MOD-228] -- support badge management

-(void)setAutoBadge:(id)value
{
	NSInteger autoBadge = [TiUtils boolValue:value def:NO];
	
    [UAirship push].autobadgeEnabled = autoBadge;
    
    [self updateUAServer];
}

-(BOOL)getAutoBadge
{
    return [UAirship push].autobadgeEnabled;
}

-(void)setBadgeNumber:(id)value
{
	NSInteger badgeNumber = [TiUtils intValue:value def:0];
	
	[[UAirship push] setBadgeNumber:badgeNumber];
    
    [self updateUAServer]; 
}

-(void)resetBadge:(id)args
{
	[[UAirship push] resetBadge];
    
    [self updateUAServer];
}

-(void)setTags:(id)value
{
    ENSURE_ARRAY(value);

    [UAirship push].tags = value;

    [self updateUAServer];
}

-(NSArray*)getTags
{
    return [UAirship push].tags;
}

-(NSString*)getPushId
{
    return [[UAirship push] channelID];
}

-(BOOL)getUserNotificationsEnabled
{
    return NUMBOOL([UAirship push].userPushNotificationsEnabled);
}

-(void)setUserNotificationsEnabled:(id)value
{
    ENSURE_SINGLE_ARG(value, NSNumber);
    
    BOOL val = NO;
    if ([value intValue] != 0)
        val = YES;
    
    if ((val == YES) && (self.pushHandler == nil)) {
        UA_LDEBUG(@"Setting up the notification handlers...");
        [UAirship push].pushNotificationDelegate = self;
        
        // Set a delegate to handle incoming push notifications. Useful for displaying
        // notification when they are recieved in the foreground.
        // self.pushHandler = [[UAPushNotificationHandler alloc] init];
        // [UAirship push].pushNotificationDelegate = self.pushHandler;
        [UAirship push].registrationDelegate = self;
    }
    
    UA_LDEBUG(@"Setting userNotificationEnabled....");
    [UAirship push].userPushNotificationsEnabled = val;
    
    [self updateUAServer];
}

#pragma UAPushNotificationDelegate

- (void)receivedForegroundNotification:(NSDictionary *)notification
                fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
    
    UA_LDEBUG(@"Received a notification while the app was already in the foreground");
    
    // Do something with your customData JSON, then entire notification is also available
    NSMutableArray* data = [NSMutableArray arrayWithObject:notification];
    [data addObject:[NSNumber numberWithBool:YES]];
    [data addObject:[NSNumber numberWithBool:NO]];
    [self handleNotification:data];
    
    // Be sure to call the completion handler with a UIBackgroundFetchResult
    completionHandler(UIBackgroundFetchResultNoData);
}

- (void)launchedFromNotification:(NSDictionary *)notification
          fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler{
    
    UA_LDEBUG(@"The application was launched or resumed from a notification");
    
    // Do something when launched via a notification
    NSMutableArray* data = [NSMutableArray arrayWithObject:notification];
    [data addObject:[NSNumber numberWithBool:NO]];
    [data addObject:[NSNumber numberWithBool:YES]];
    [self handleNotification:data];
    
    // Be sure to call the completion handler with a UIBackgroundFetchResult
    completionHandler(UIBackgroundFetchResultNoData);
}

- (void)receivedBackgroundNotification:(NSDictionary *)notification
                fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
    
    // Do something with the notification in the background
    NSMutableArray* data = [NSMutableArray arrayWithObject:notification];
    [data addObject:[NSNumber numberWithBool:NO]];
    [data addObject:[NSNumber numberWithBool:NO]];
    [self handleNotification:data];
    
    // Be sure to call the completion handler with a UIBackgroundFetchResult
    completionHandler(UIBackgroundFetchResultNoData);
}

#pragma UARegistrationDelegate
- (void)registrationSucceededForChannelID:(NSString *)channelID deviceToken:(NSString *)deviceToken
{
    NSString* channelId = [self getPushId];
    
    //Don't let the device token be null on a simulator...
    if (deviceToken == nil)
    {
        CFUUIDRef uuid = CFUUIDCreate(NULL);
        CFStringRef uuidString = CFUUIDCreateString(NULL, uuid);
        CFRelease(uuid);
        deviceToken = (__bridge NSString*)uuidString;
        if (channelId == nil)
            channelId = [deviceToken copy];
    }
    
    NSMutableDictionary *data = [[NSMutableDictionary alloc] init];
    [data setObject:deviceToken forKey:@"iOSToken"];
    [data setObject:channelId forKey:@"deviceToken"];
    [self fireEvent:[self EVENT_URBAN_AIRSHIP_SUCCESS] withObject:data];
}

- (void)registrationFailed
{
    NSMutableDictionary *data = [[NSMutableDictionary alloc] init];
    [self fireEvent: [self EVENT_URBAN_AIRSHIP_ERROR] withObject:data];
}

@end

