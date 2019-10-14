// Created by Michael Simms on 7/15/12.
// Copyright (c) 2012 Michael J. Simms. All rights reserved.

// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import <UIKit/UIKit.h>
#import <MapKit/MapKit.h>
#import <WatchConnectivity/WatchConnectivity.h>

#import "ActivityAttributeType.h"
#import "ActivityLevel.h"
#import "ActivityPreferences.h"
#import "BroadcastManager.h"
#import "CloudMgr.h"
#import "Feature.h"
#import "FileFormat.h"
#import "Gender.h"
#import "HealthManager.h"
#import "LeDiscovery.h"
#import "SensorMgr.h"
#import "SensorType.h"
#import "WiFiDiscovery.h"

#define EXPORT_TO_EMAIL_STR "Email"
#define IMPORT_VIA_URL_STR  "URL"

@interface AppDelegate : UIResponder <UIApplicationDelegate, WCSessionDelegate>
{
	SensorMgr*           sensorMgr; // For managing sensors, whether they are built into the phone (location, accelerometer) or external (cycling power).
	LeDiscovery*         leSensorFinder; // For discovering Bluetooth devices, such as heart rate monitors and power meters.
	WiFiDiscovery*       wifiSensorFinder; // For discovering Wifi devices, such as cameras.
	CloudMgr*            cloudMgr;
	ActivityPreferences* activityPrefs; // For managing activity-related preferences.
	BroadcastManager*    broadcastMgr; // For sending data to the cloud service.
	HealthManager*       healthMgr; // Interfaces with Apple HealthKit.
	NSTimer*             intervalTimer;
	WCSession*           watchSession; // Interfaces with the watch app.
	BOOL                 badGps;
}

- (NSString*)getDeviceId;

// feature management; some features may be optionally disabled

- (BOOL)isFeaturePresent:(Feature)feature;
- (BOOL)isFeatureEnabled:(Feature)feature;

// describes the phone; only used for determining if we're on a really old phone or not

- (NSString*)getPlatformString;

// unit management methods

- (void)setUnits;

// user profile methods

- (void)setUserProfile;

- (ActivityLevel)userActivityLevel;
- (Gender)userGender;
- (struct tm)userBirthDate;
- (double)userHeight;
- (double)userWeight;
- (double)userFtp;

- (void)setUserActivityLevel:(ActivityLevel)activityLevel;
- (void)setUserGender:(Gender)gender;
- (void)setUserBirthDate:(NSDate*)birthday;
- (void)setUserHeight:(double)height;
- (void)setUserWeight:(double)weight;
- (void)setUserFtp:(double)ftp;

// watch methods

- (void)configureWatchSession;

// broadcast methods

- (void)configureBroadcasting;

// healthkit methods

- (void)startHealthMgr;

// bluetooth methods

- (BOOL)hasLeBluetooth;
- (BOOL)hasLeBluetoothSensor:(SensorType)sensorType;
- (NSMutableArray*)listDiscoveredBluetoothSensorsOfType:(BluetoothService)type;

// sensor management methods

- (void)startSensorDiscovery;
- (void)stopSensorDiscovery;
- (void)addSensorDiscoveryDelegate:(id<DiscoveryDelegate>)delegate;
- (void)removeSensorDiscoveryDelegate:(id<DiscoveryDelegate>)delegate;
- (void)stopSensors;
- (void)startSensors;

// sensor update methods

- (void)weightHistoryUpdated:(NSNotification*)notification;
- (void)accelerometerUpdated:(NSNotification*)notification;
- (void)locationUpdated:(NSNotification*)notification;
- (void)heartRateUpdated:(NSNotification*)notification;
- (void)cadenceUpdated:(NSNotification*)notification;
- (void)wheelSpeedUpdated:(NSNotification*)notification;
- (void)powerUpdated:(NSNotification*)notification;
- (void)strideLengthUpdated:(NSNotification*)notification;
- (void)runDistanceUpdated:(NSNotification*)notification;

// methods for starting and stopping activities, etc.

- (BOOL)startActivity;
- (BOOL)startActivityWithBikeName:(NSString*)bikeName;
- (BOOL)stopActivity;
- (BOOL)pauseActivity;
- (BOOL)startNewLap;
- (void)recreateOrphanedActivity:(NSInteger)activityIndex;
- (ActivityAttributeType)queryLiveActivityAttribute:(NSString*)attributeName;

// methods for loading and editing historical activities

- (NSInteger)initializeHistoricalActivityList;
- (NSInteger)getNumHistoricalActivities;
- (void)createHistoricalActivityObject:(NSString*)activityId;
- (BOOL)loadHistoricalActivityByIndex:(NSInteger)activityIndex;
- (BOOL)loadHistoricalActivity:(NSString*)activityId;
- (ActivityAttributeType)queryHistoricalActivityAttribute:(const char* const)attributeName forActivityIndex:(NSInteger)activityIndex;
- (ActivityAttributeType)queryHistoricalActivityAttribute:(const char* const)attributeName forActivityId:(NSString*)activityId;
- (BOOL)loadHistoricalActivitySensorData:(SensorType)sensorType forActivityId:(NSString*)activityId withCallback:(void*)callback withContext:(void*)context;
- (BOOL)trimActivityData:(NSString*)activityId withNewTime:(uint64_t)newTime fromStart:(BOOL)fromStart;
- (void)deleteActivity:(NSString*)activityId;

// hash methods

- (NSString*)hashActivityWithId:(NSString*)activityId;
- (NSString*)hashCurrentActivity;

// sound methods

- (void)playSound:(NSString*)soundPath;
- (void)playBeepSound;
- (void)playPingSound;

// methods for downloading an activity via a URL

- (BOOL)downloadActivity:(NSString*)urlStr withActivityType:(NSString*)activityType;

// methods for exporting activities

- (BOOL)deleteFile:(NSString*)fileName;

- (NSString*)exportActivity:(NSString*)activityId withFileFormat:(FileFormat)format to:selectedExportLocation;
- (NSString*)exportActivitySummary:(NSString*)activityType;
- (void)clearExportDir;

// methods for managing bikes

- (void)setBikeForCurrentActivity:(NSString*)bikeName;
- (void)setBikeForActivityId:(NSString*)bikeName withActivityId:(NSString*)activityId;
- (uint64_t)getBikeIdFromName:(NSString*)bikeName;
- (BOOL)deleteBikeProfile:(uint64_t)bikeId;

// methods for managing the activity name

- (NSString*)getActivityName:(NSString*)activityId;

// accessor methods

- (NSMutableArray*)getTagsForActivity:(NSString*)activityId;
- (NSMutableArray*)getBikeNames;
- (NSMutableArray*)getIntervalWorkoutNames;
- (NSMutableArray*)getEnabledFileImportCloudServices;
- (NSMutableArray*)getEnabledFileImportServices;
- (NSMutableArray*)getEnabledFileExportCloudServices;
- (NSMutableArray*)getEnabledFileExportServices;
- (NSMutableArray*)getActivityTypes;
- (NSMutableArray*)getCurrentActivityAttributes;
- (NSMutableArray*)getHistoricalActivityAttributes:(NSInteger)activityIndex;

- (NSString*)getCurrentActivityType;
- (NSString*)getHistoricalActivityType:(NSInteger)activityIndex;

// utility methods

- (void)setScreenLocking;
- (BOOL)hasBadGps;

// cloud methods

- (NSMutableArray*)listFileClouds;
- (NSMutableArray*)listDataClouds;
- (BOOL)isCloudServiceLinked:(CloudServiceType)service;
- (NSString*)nameOfCloudService:(CloudServiceType)service;
- (void)requestCloudServiceAcctNames:(CloudServiceType)service;

// These methods are used to interact with the server. The app should still function, in all but the obvious ways,
// if server communications are disabled (which should be the default).

- (BOOL)serverLoginAsync:(NSString*)username withPassword:(NSString*)password;
- (BOOL)serverCreateLoginAsync:(NSString*)username withPassword:(NSString*)password1 withConfirmation:(NSString*)password2 withRealName:(NSString*)realname;
- (BOOL)serverIsLoggedInAsync;
- (BOOL)serverLogoutAsync;
- (BOOL)serverListFollowingAsync;
- (BOOL)serverListFollowedByAsync;
- (BOOL)serverRequestToFollowAsync:(NSString*)targetUsername;
- (BOOL)serverDeleteActivityAsync:(NSString*)activityId;
- (BOOL)serverCreateTagAsync:(NSString*)tag forActivity:(NSString*)activityId;
- (BOOL)serverDeleteTagAsync:(NSString*)tag forActivity:(NSString*)activityId;

// reset methods

- (void)resetDatabase;
- (void)resetPreferences;

@property (strong, nonatomic) UIWindow* window;

@end
