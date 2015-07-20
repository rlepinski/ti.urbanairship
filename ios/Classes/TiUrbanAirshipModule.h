/**
 * Ti.Urbanairship Module
 * Copyright (c) 2010-2013 by Appcelerator, Inc. All Rights Reserved.
 * Please see the LICENSE included with this distribution for details.
 */

#import "TiModule.h"
#import "UAPush.h"

@interface TiUrbanairshipModule : TiModule <UAPushNotificationDelegate, UARegistrationDelegate>
{
	BOOL initialized;
	BOOL autoResetBadge;
    
}

@property (readonly, nonatomic) BOOL notificationsEnabled;
@property (readwrite, nonatomic) BOOL autoResetBadge;

@property(nonatomic,readonly) NSString *EVENT_URBAN_AIRSHIP_CALLBACK;
@property(nonatomic,readonly) NSString *EVENT_URBAN_AIRSHIP_SUCCESS;
@property(nonatomic,readonly) NSString *EVENT_URBAN_AIRSHIP_ERROR;

@end
