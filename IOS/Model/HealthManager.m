// Created by Michael Simms on 10/5/14.
// Copyright (c) 2014 Michael J. Simms. All rights reserved.

// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import <CoreLocation/CoreLocation.h>
#import "HealthManager.h"
#import "ActivityAttribute.h"
#import "ActivityType.h"
#import "BtleHeartRateMonitor.h"
#import "BtleScale.h"
#import "Notifications.h"
#import "Preferences.h"
#import "UserProfile.h"

@implementation HKUnit (HKManager)

+ (HKUnit*)heartBeatsPerMinuteUnit
{
	return [[HKUnit countUnit] unitDividedByUnit:[HKUnit minuteUnit]];
}

@end

@implementation HealthManager

- (id)init
{
	if (self = [super init])
	{
		self->healthStore = [[HKHealthStore alloc] init];
		self->heartRates = [[NSMutableArray alloc] init];
		self->workouts = [[NSMutableDictionary alloc] init];
		self->locations = [[NSMutableDictionary alloc] init];
		self->distances = [[NSMutableDictionary alloc] init];
		self->speeds = [[NSMutableDictionary alloc] init];
		self->queryGroup = dispatch_group_create();

		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(activityStopped:) name:@NOTIFICATION_NAME_ACTIVITY_STOPPED object:nil];
	}
	return self;
}

- (void)dealloc
{
}

#pragma mark HealthKit permissions

// Returns the types of data that the app wishes to write to HealthKit.
- (NSSet*)dataTypesToWrite
{
#if TARGET_OS_WATCH
	HKQuantityType* hrType = [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierHeartRate];
	HKQuantityType* activeEnergyBurnType = [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierActiveEnergyBurned];
	return [NSSet setWithObjects: hrType, activeEnergyBurnType, nil];
#else
	HKQuantityType* heightType = [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierHeight];
	HKQuantityType* weightType = [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierBodyMass];
	HKQuantityType* hrType = [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierHeartRate];
	HKQuantityType* bikeType = [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierDistanceCycling];
	HKQuantityType* runType = [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierDistanceWalkingRunning];
	HKQuantityType* activeEnergyBurnType = [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierActiveEnergyBurned];
	return [NSSet setWithObjects: heightType, weightType, hrType, bikeType, runType, activeEnergyBurnType, nil];
#endif
}

// Returns the types of data that the app wishes to read from HealthKit.
- (NSSet*)dataTypesToRead
{
#if TARGET_OS_WATCH
	HKQuantityType* hrType = [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierHeartRate];
	HKQuantityType* heightType = [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierHeight];
	HKQuantityType* weightType = [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierBodyMass];
	HKCharacteristicType* birthdayType = [HKObjectType characteristicTypeForIdentifier:HKCharacteristicTypeIdentifierDateOfBirth];
	HKCharacteristicType* biologicalSexType = [HKObjectType characteristicTypeForIdentifier:HKCharacteristicTypeIdentifierBiologicalSex];
	return [NSSet setWithObjects: heightType, weightType, hrType, birthdayType, biologicalSexType, nil];
#else
	HKQuantityType* heightType = [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierHeight];
	HKQuantityType* weightType = [HKObjectType quantityTypeForIdentifier:HKQuantityTypeIdentifierBodyMass];
	HKCharacteristicType* birthdayType = [HKObjectType characteristicTypeForIdentifier:HKCharacteristicTypeIdentifierDateOfBirth];
	HKCharacteristicType* biologicalSexType = [HKObjectType characteristicTypeForIdentifier:HKCharacteristicTypeIdentifierBiologicalSex];
	HKSeriesType* routeType = [HKObjectType seriesTypeForIdentifier:HKWorkoutRouteTypeIdentifier];
	HKWorkoutType* workoutType = [HKObjectType workoutType];
	return [NSSet setWithObjects: heightType, weightType, birthdayType, biologicalSexType, routeType, workoutType, nil];
#endif
}

#pragma mark methods for managing authorization.

- (void)requestAuthorization
{
	if ([HKHealthStore isHealthDataAvailable])
	{
		NSSet* writeDataTypes = [self dataTypesToWrite];
		NSSet* readDataTypes = [self dataTypesToRead];

		// Request authorization. If granted update the user's metrics.
		[self->healthStore requestAuthorizationToShareTypes:writeDataTypes readTypes:readDataTypes completion:^(BOOL success, NSError* error)
		{
			if (success)
			{
				dispatch_async(dispatch_get_main_queue(), ^{
					[self updateUsersAge];
					[self updateUsersHeight];
					[self updateUsersWeight];
				});
			}
		}];
	}
}

#pragma mark methods for reading quantity samples (height, weight, etc.) from HealthKit.

- (void)subscribeToQuantitySamplesOfType:(HKQuantityType*)quantityType completion:(void (^)(HKQuantity*, NSDate*, NSError*))completion
{
	// It's invalid to call this without a completion handler.
	if (!completion)
	{
		return;
	}

	NSPredicate* datePredicate = [HKQuery predicateForSamplesWithStartDate:[NSDate date] endDate:nil options:HKQueryOptionStrictStartDate];
	HKAnchoredObjectQuery* query = [[HKAnchoredObjectQuery alloc] initWithType:quantityType
																	 predicate:datePredicate
																		anchor:nil
																		 limit:HKObjectQueryNoLimit
																resultsHandler:^(HKAnchoredObjectQuery* query, NSArray<HKSample*>* addedObjects, NSArray<HKDeletedObject*>* deletedObjects, HKQueryAnchor* newAnchor, NSError* error)
	{
		if (addedObjects)
		{
			for (HKQuantitySample* sample in addedObjects)
			{
				completion(sample.quantity, sample.endDate, error);
			}
		}
	}];

	query.updateHandler = ^(HKAnchoredObjectQuery* query, NSArray<HKSample*>* addedObjects, NSArray<HKDeletedObject*>* deletedObjects, HKQueryAnchor* newAnchor, NSError* error)
	{
		if (addedObjects)
		{
			for (HKQuantitySample* sample in addedObjects)
			{
				completion(sample.quantity, sample.endDate, error);
			}
		}
	};

	// Execute asynchronously.
	[self->healthStore executeQuery:query];
}

- (void)mostRecentQuantitySampleOfType:(HKQuantityType*)quantityType completion:(void (^)(HKQuantity*, NSDate*, NSError*))completion
{
	// It's invalid to call this without a completion handler.
	if (!completion)
	{
		return;
	}

	// Since we are interested in retrieving the user's latest sample, we sort the samples in descending
	// order, and set the limit to 1. We are not filtering the data, and so the predicate is set to nil.
	NSSortDescriptor* timeSortDescriptor = [[NSSortDescriptor alloc] initWithKey:HKSampleSortIdentifierEndDate ascending:NO];
	HKSampleQuery* query = [[HKSampleQuery alloc] initWithSampleType:quantityType
														   predicate:nil
															   limit:1
													 sortDescriptors:@[timeSortDescriptor]
													  resultsHandler:^(HKSampleQuery* query, NSArray* results, NSError* error)
	{
		// Error case: Call the completion handler, passing nil for the results.
		if (!results)
		{
			completion(nil, nil, error);
		}

		// Normal case: Call the completion handler with the results.
		else
		{
			HKQuantitySample* quantitySample = results.firstObject;
			completion(quantitySample.quantity, quantitySample.startDate, error);
		}
	}];

	// Execute asynchronously.
	[self->healthStore executeQuery:query];
}

- (void)quantitySamplesOfType:(HKQuantityType*)quantityType completion:(void (^)(HKQuantity*, NSDate*, NSError*))completion
{
	// It's invalid to call this without a completion handler.
	if (!completion)
	{
		return;
	}

	// We are not filtering the data, and so the predicate is set to nil.
	HKSampleQuery* query = [[HKSampleQuery alloc] initWithSampleType:quantityType
														   predicate:nil
															   limit:HKObjectQueryNoLimit
													 sortDescriptors:nil
													  resultsHandler:^(HKSampleQuery* query, NSArray* results, NSError* error)
	{
		// Error case: Call the completion handler, passing nil for the results.
		if (!results)
		{
			completion(nil, nil, error);
		}

		// Normal case: Call the completion handler with the results.
		else
		{
			for (HKQuantitySample* quantitySample in results)
			{
				completion(quantitySample.quantity, quantitySample.startDate, error);
			}
		}
	}];

	// Execute asynchronously.
	[self->healthStore executeQuery:query];
}

#pragma mark methods for reading HealthKit data pertaining to the user's height, weight, etc. and storing it in our database.

- (void)updateUsersAge
{
	NSError* error;
	NSDateComponents* dateOfBirth = [self->healthStore dateOfBirthComponentsWithError:&error];

	if (dateOfBirth)
	{
		NSCalendar* gregorianCalendar = [[NSCalendar alloc] initWithCalendarIdentifier:NSCalendarIdentifierGregorian];
		NSDate* tempDate = [gregorianCalendar dateFromComponents:dateOfBirth];

		[UserProfile setBirthDate:tempDate];
	}
}

- (void)updateUsersHeight
{
	HKQuantityType* heightType = [HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierHeight];
	
	[self mostRecentQuantitySampleOfType:heightType
							  completion:^(HKQuantity* mostRecentQuantity, NSDate* startDate, NSError* error)
	 {
		 if (mostRecentQuantity)
		 {
			 HKUnit* heightUnit = [HKUnit inchUnit];
			 double usersHeight = [mostRecentQuantity doubleValueForUnit:heightUnit];

			 [UserProfile setHeightInInches:usersHeight];
		 }
	 }];
}

- (void)updateUsersWeight
{
	HKQuantityType* weightType = [HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierBodyMass];

	[self mostRecentQuantitySampleOfType:weightType
							  completion:^(HKQuantity* mostRecentQuantity, NSDate* startDate, NSError* error)
	 {
		if (mostRecentQuantity)
		{
			HKUnit* weightUnit = [HKUnit gramUnit];
			double usersWeight = [mostRecentQuantity doubleValueForUnit:weightUnit] / 1000.0; // Convert to kilograms

			[UserProfile setWeightInKg:usersWeight];

			ActivityAttributeType tempWeight = InitializeActivityAttribute(TYPE_DOUBLE, MEASURE_WEIGHT, UNIT_SYSTEM_US_CUSTOMARY);
			tempWeight.value.doubleVal = usersWeight;
			ConvertToMetric(&tempWeight);

			NSDictionary* weightData = [[NSDictionary alloc] initWithObjectsAndKeys:
										[NSNumber numberWithDouble:usersWeight],@KEY_NAME_WEIGHT_KG,
										[NSNumber numberWithLongLong:time(NULL)],@KEY_NAME_TIME,
										nil];
			[[NSNotificationCenter defaultCenter] postNotificationName:@NOTIFICATION_NAME_HISTORICAL_WEIGHT_READING object:weightData];
		}
	 }];
}

// methods for returning HealthKit data.

- (void)readWeightHistory:(void (^)(HKQuantity*, NSDate*, NSError*))completion
{
	HKQuantityType* weightType = [HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierBodyMass];

	[self quantitySamplesOfType:weightType completion:completion];
}

#pragma mark methods for managing workouts

- (NSInteger)getNumWorkouts
{
	if (self->workouts)
	{
		return [self->workouts count];
	}
	return 0;
}

- (void)clearWorkoutsList
{
	@synchronized(self->workouts)
	{
		[self->workouts removeAllObjects];
	}
	@synchronized(self->locations)
	{
		[self->locations removeAllObjects];
	}
	@synchronized(self->distances)
	{
		[self->distances removeAllObjects];
	}
	@synchronized(self->speeds)
	{
		[self->speeds removeAllObjects];
	}
}

- (void)readWorkoutsFromHealthStoreOfType:(HKWorkoutActivityType)activityType
{
	NSPredicate* predicate = [HKQuery predicateForWorkoutsWithWorkoutActivityType:activityType];
	NSSortDescriptor* sortDescriptor = [[NSSortDescriptor alloc] initWithKey:HKSampleSortIdentifierStartDate ascending:false];
	HKSampleQuery* sampleQuery = [[HKSampleQuery alloc] initWithSampleType:[HKWorkoutType workoutType]
																 predicate:predicate
																	 limit:HKObjectQueryNoLimit
														   sortDescriptors:@[sortDescriptor]
															resultsHandler:^(HKSampleQuery* query, NSArray* samples, NSError* error)
	{
		@synchronized(self->workouts)
		{
			for (HKQuantitySample* workout in samples)
			{
				[self->workouts setObject:(HKWorkout*)workout forKey:[[NSUUID UUID] UUIDString]];
			}
		}
		dispatch_group_leave(self->queryGroup);
	}];

	// Execute and wait.
	dispatch_group_enter(self->queryGroup);
	[self->healthStore executeQuery:sampleQuery];
}

- (void)readRunningWorkoutsFromHealthStore
{
	[self readWorkoutsFromHealthStoreOfType:HKWorkoutActivityTypeRunning];
}

- (void)readWalkingWorkoutsFromHealthStore
{
	[self readWorkoutsFromHealthStoreOfType:HKWorkoutActivityTypeWalking];
}

- (void)readCyclingWorkoutsFromHealthStore
{
	[self readWorkoutsFromHealthStoreOfType:HKWorkoutActivityTypeCycling];
}

- (void)calculateSpeedsFromDistances:(NSMutableArray<NSNumber*>*)activityDistances withActivityId:(NSString*)activityId
{
	@synchronized(self->speeds)
	{
		NSMutableArray* activitySpeeds = [[NSMutableArray alloc] init];
		[activitySpeeds addObject:@(0)];

		for (size_t i = 1; i < [activityDistances count]; ++i)
		{
			NSNumber* distance1 = [activityDistances objectAtIndex:i - 1];
			NSNumber* distance2 = [activityDistances objectAtIndex:i];

			double speed = [distance2 doubleValue] - [distance1 doubleValue];
			[activitySpeeds addObject:@(speed)];
		}

		[self->speeds setObject:activitySpeeds forKey:activityId];
	}
}

- (void)calculateDistancesFromLocations:(NSMutableArray<CLLocation*>*)activityLocations withActivityId:(NSString*)activityId
{
	@synchronized(self->distances)
	{
		NSMutableArray<NSNumber*>* activityDistances = [[NSMutableArray alloc] init];
		[activityDistances addObject:@(0)];

		for (size_t i = 1; i < [activityLocations count]; ++i)
		{
			CLLocation* loc1 = [activityLocations objectAtIndex:i - 1];
			CLLocation* loc2 = [activityLocations objectAtIndex:i];
			Coordinate c1;
			Coordinate c2;
			
			c1.latitude = loc1.coordinate.latitude;
			c1.longitude = loc1.coordinate.longitude;
			c1.altitude = 0.0;
			c2.latitude = loc2.coordinate.latitude;
			c2.longitude = loc2.coordinate.longitude;
			c2.altitude = 0.0;

			double distance = DistanceBetweenCoordinates(c1, c2);
			[activityDistances addObject:@(distance)];
		}

		[self->distances setObject:activityDistances forKey:activityId];

		// Now update the speed calculations.
		[self calculateSpeedsFromDistances:activityDistances withActivityId:activityId];
	}
}

- (void)readLocationPointsFromHealthStoreForWorkoutRoute:(HKWorkoutRoute*)route withActivityId:(NSString*)activityId
{
	@synchronized(self->locations)
	{
		HKWorkoutRouteQuery* query = [[HKWorkoutRouteQuery alloc] initWithRoute:route
																	dataHandler:^(HKWorkoutRouteQuery* query, NSArray<CLLocation*>* routeData, BOOL done, NSError* error)
		{
			NSMutableArray* newArray = [[NSMutableArray alloc] initWithArray:routeData copyItems:YES];
			NSMutableArray<CLLocation*>* activityLocations = [self->locations objectForKey:activityId];

			if (activityLocations)
			{
				// Append to existing location array.
				[activityLocations addObjectsFromArray:newArray];
			}
			else
			{
				// Create a new array.
				[self->locations setObject:newArray forKey:activityId];
			}

			if (done)
			{
				// Now update the distance calculations.
				[self calculateDistancesFromLocations:activityLocations withActivityId:activityId];

				dispatch_group_leave(self->queryGroup);
			}
		}];

		// Remove any existing data.
		[self->locations removeObjectForKey:activityId];

		// Execute and wait.
		dispatch_group_enter(self->queryGroup);
		[self->healthStore executeQuery:query];
	}
}

- (void)readLocationPointsFromHealthStoreForWorkout:(HKWorkout*)workout withActivityId:(NSString*)activityId
{
	NSPredicate* workoutPredicate = [HKQuery predicateForObjectsFromWorkout:workout];
	HKSampleType* type = [HKSeriesType workoutRouteType];
	HKQuery* query = [[HKAnchoredObjectQuery alloc] initWithType:type
													   predicate:workoutPredicate
														  anchor:nil
												   limit:HKObjectQueryNoLimit
												  resultsHandler:^(HKAnchoredObjectQuery* query,
																   NSArray<HKSample*>* sampleObjects,
																   NSArray<HKDeletedObject*>* deletedObjects,
																   HKQueryAnchor* newAnchor,
																   NSError* error)
	{
		for (HKWorkoutRoute* route in sampleObjects)
		{
			[self readLocationPointsFromHealthStoreForWorkoutRoute:route withActivityId:activityId];
		}
		dispatch_group_leave(self->queryGroup);
	}];

	// Execute and wait.
	dispatch_group_enter(self->queryGroup);
	[self->healthStore executeQuery:query];
}

- (void)readLocationPointsFromHealthStoreForActivityId:(NSString*)activityId
{
	@synchronized(self->workouts)
	{
		HKWorkout* workout = [self->workouts objectForKey:activityId];

		if (workout)
		{
			[self readLocationPointsFromHealthStoreForWorkout:workout withActivityId:activityId];
		}
	}
}

// Blocks until all HealthKit queries have completed.
- (void)waitForHealthKitQueries
{
	dispatch_group_wait(self->queryGroup, DISPATCH_TIME_FOREVER);
}

// Used for de-duplicating the HealthKit activity list, so we don't see activities recorded with this app twice.
- (void)removeOverlappingActivityWithStartTime:(time_t)startTime withEndTime:(time_t)endTime
{
	@synchronized(self->workouts)
	{
		NSMutableArray* itemsToRemove = [NSMutableArray array];

		for (NSString* activityId in self->workouts)
		{
			HKWorkout* workout = [self->workouts objectForKey:activityId];

			time_t workoutStartTime = [workout.startDate timeIntervalSince1970];
			time_t workoutEndTime = [workout.endDate timeIntervalSince1970];

			if ((startTime >= workoutStartTime && startTime < workoutEndTime) ||
				(endTime < workoutEndTime && endTime >= workoutStartTime))
			{
				[itemsToRemove addObject:activityId];
			}
		}

		[self->workouts removeObjectsForKeys:itemsToRemove];
	}
}

#pragma mark methods for querying workout data.

- (NSString*)convertIndexToActivityId:(size_t)index
{
	@synchronized(self->workouts)
	{
		NSArray* keys = [self->workouts allKeys];
		return [keys objectAtIndex:index];
	}
}

- (NSString*)getHistoricalActivityType:(NSString*)activityId
{
	@synchronized(self->workouts)
	{
		HKWorkout* workout = [self->workouts objectForKey:activityId];

		if (workout)
		{
			HKWorkoutActivityType type = [workout workoutActivityType];

			switch (type)
			{
				case HKWorkoutActivityTypeCycling:
					return @"Cycling";
				case HKWorkoutActivityTypeRunning:
					return @"Running";
				case HKWorkoutActivityTypeWalking:
					return @"Walking";
				default:
					break;
			}
		}
	}
	return nil;
}

- (void)getWorkoutStartAndEndTime:(NSString*)activityId withStartTime:(time_t*)startTime withEndTime:(time_t*)endTime
{
	@synchronized(self->workouts)
	{
		HKWorkout* workout = [self->workouts objectForKey:activityId];

		if (workout)
		{
			(*startTime) = [workout.startDate timeIntervalSince1970];
			(*endTime) = [workout.endDate timeIntervalSince1970];
		}
	}
}

- (NSInteger)getNumLocationPoints:(NSString*)activityId
{
	@synchronized(self->locations)
	{
		NSArray<CLLocation*>* activityLocations = [self->locations objectForKey:activityId];

		if (activityLocations)
		{
			return [activityLocations count];
		}
	}
	return 0;
}

- (BOOL)getHistoricalActivityLocationPoint:(NSString*)activityId withPointIndex:(size_t)pointIndex withLatitude:(double*)latitude withLongitude:(double*)longitude withAltitude:(double*)altitude withTimestamp:(time_t*)timestamp
{
	@synchronized(self->locations)
	{
		NSArray<CLLocation*>* activityLocations = [self->locations objectForKey:activityId];

		if (activityLocations)
		{
			if (pointIndex < [activityLocations count])
			{
				CLLocation* loc = [activityLocations objectAtIndex:pointIndex];

				if (loc)
				{
					if (latitude)
						(*latitude) = loc.coordinate.latitude;
					if (longitude)
						(*longitude) = loc.coordinate.longitude;
					if (altitude)
						(*altitude) = loc.altitude;
					if (timestamp)
						(*timestamp) = [loc.timestamp timeIntervalSince1970];
					return TRUE;
				}
			}
		}
	}
	return FALSE;
}

- (double)quantityInUserPreferredUnits:(HKQuantity*)qty
{
	if ([Preferences preferredUnitSystem] == UNIT_SYSTEM_METRIC)
		return [qty doubleValueForUnit:[HKUnit meterUnitWithMetricPrefix:HKMetricPrefixKilo]];
	return [qty doubleValueForUnit:[HKUnit mileUnit]];
}

- (ActivityAttributeType)getWorkoutAttribute:(const char* const)attributeName forActivityId:(NSString*)activityId
{
	ActivityAttributeType attr;
	attr.valid = false;

	@synchronized(self->workouts)
	{
		HKWorkout* workout = [self->workouts objectForKey:activityId];
		if (workout)
		{
			if (strncmp(attributeName, ACTIVITY_ATTRIBUTE_DISTANCE_TRAVELED, strlen(ACTIVITY_ATTRIBUTE_DISTANCE_TRAVELED)) == 0)
			{
				HKQuantity* qty = [workout totalDistance];
				attr.value.doubleVal = [self quantityInUserPreferredUnits:qty];
				attr.valueType = TYPE_DOUBLE;
				attr.measureType = MEASURE_DISTANCE;
				attr.valid = true;
			}
			else if (strncmp(attributeName, ACTIVITY_ATTRIBUTE_ELAPSED_TIME, strlen(ACTIVITY_ATTRIBUTE_ELAPSED_TIME)) == 0)
			{
				NSTimeInterval qty = [workout duration];
				attr.value.timeVal = (time_t)qty;
				attr.valueType = TYPE_TIME;
				attr.measureType = MEASURE_TIME;
				attr.valid = true;
			}
			else if (strncmp(attributeName, ACTIVITY_ATTRIBUTE_MAX_CADENCE, strlen(ACTIVITY_ATTRIBUTE_MAX_CADENCE)) == 0)
			{
				attr.value.doubleVal = (double)0.0;
				attr.valueType = TYPE_DOUBLE;
				attr.measureType = MEASURE_RPM;
				attr.valid = false;
			}
			else if (strncmp(attributeName, ACTIVITY_ATTRIBUTE_HEART_RATE, strlen(ACTIVITY_ATTRIBUTE_HEART_RATE)) == 0)
			{
				attr.value.doubleVal = (double)0.0;
				attr.valueType = TYPE_DOUBLE;
				attr.measureType = MEASURE_BPM;
				attr.valid = false;
			}
			else if (strncmp(attributeName, ACTIVITY_ATTRIBUTE_STARTING_LATITUDE, strlen(ACTIVITY_ATTRIBUTE_STARTING_LATITUDE)) == 0)
			{
				attr.value.doubleVal = (double)0.0;
				attr.valueType = TYPE_DOUBLE;
				attr.measureType = MEASURE_DEGREES;
				attr.valid = [self getHistoricalActivityLocationPoint:activityId withPointIndex:0 withLatitude:&attr.value.doubleVal withLongitude:NULL withAltitude:NULL withTimestamp:NULL];
			}
			else if (strncmp(attributeName, ACTIVITY_ATTRIBUTE_STARTING_LONGITUDE, strlen(ACTIVITY_ATTRIBUTE_STARTING_LONGITUDE)) == 0)
			{
				attr.value.doubleVal = (double)0.0;
				attr.valueType = TYPE_DOUBLE;
				attr.measureType = MEASURE_DEGREES;
				attr.valid = [self getHistoricalActivityLocationPoint:activityId withPointIndex:0 withLatitude:NULL withLongitude:&attr.value.doubleVal withAltitude:NULL withTimestamp:NULL];
			}
			else if (strncmp(attributeName, ACTIVITY_ATTRIBUTE_CALORIES_BURNED, strlen(ACTIVITY_ATTRIBUTE_CALORIES_BURNED)) == 0)
			{
				HKQuantity* qty = [workout totalEnergyBurned];
				attr.value.doubleVal = [self quantityInUserPreferredUnits:qty];
				attr.valueType = TYPE_DOUBLE;
				attr.measureType = MEASURE_CALORIES;
				attr.valid = true;
			}
			else if (strncmp(attributeName, ACTIVITY_ATTRIBUTE_CURRENT_SPEED, strlen(ACTIVITY_ATTRIBUTE_CURRENT_SPEED)) == 0)
			{
				@synchronized(self->speeds)
				{
					NSArray<NSNumber*>* activitySpeeds = [self->speeds objectForKey:activityId];
					attr.value.doubleVal = [[activitySpeeds objectAtIndex:self->tempPointIndex] doubleValue];
					attr.valueType = TYPE_DOUBLE;
					attr.measureType = MEASURE_SPEED;
					attr.valid = true;
				}
			}
		}
	}
	return attr;
}

- (BOOL)loadHistoricalActivitySensorData:(SensorType)sensor forActivityId:(NSString*)activityId withCallback:(SensorDataCallback)callback withContext:(void*)context
{
	if (sensor == SENSOR_TYPE_LOCATION)
	{
		const char* activityIdStr = [activityId UTF8String];
		NSInteger numLocationPoints = [self getNumLocationPoints:activityId];

		for (self->tempPointIndex = 0; self->tempPointIndex < numLocationPoints; ++self->tempPointIndex)
		{
			if (callback)
				callback(activityIdStr, context);
		}
		return TRUE;
	}
	return FALSE;
}

#pragma mark methods for writing HealthKit data

- (void)saveHeightIntoHealthStore:(double)heightInInches
{
	HKUnit* inchUnit = [HKUnit inchUnit];
	HKQuantity* heightQuantity = [HKQuantity quantityWithUnit:inchUnit doubleValue:heightInInches];
	HKQuantityType* heightType = [HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierHeight];
	NSDate* now = [NSDate date];
	HKQuantitySample* heightSample = [HKQuantitySample quantitySampleWithType:heightType quantity:heightQuantity startDate:now endDate:now];

	[self->healthStore saveObject:heightSample withCompletion:^(BOOL success, NSError *error) {}];
}

- (void)saveWeightIntoHealthStore:(double)weightInPounds
{
	HKUnit* poundUnit = [HKUnit poundUnit];
	HKQuantity* weightQuantity = [HKQuantity quantityWithUnit:poundUnit doubleValue:weightInPounds];
	HKQuantityType* weightType = [HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierBodyMass];
	NSDate* now = [NSDate date];
	HKQuantitySample* weightSample = [HKQuantitySample quantitySampleWithType:weightType quantity:weightQuantity startDate:now endDate:now];

	[self->healthStore saveObject:weightSample withCompletion:^(BOOL success, NSError *error) {}];
}

- (void)saveHeartRateIntoHealthStore:(double)beats
{
	if (self->firstHeartRateSample)
	{
		self->lastHeartRateSample = [NSDate date];
	}
	else
	{
		self->firstHeartRateSample = self->lastHeartRateSample = [NSDate date];
	}

	[self->heartRates addObject:[[NSNumber alloc] initWithDouble:beats]];

	if ([self->lastHeartRateSample timeIntervalSinceDate:self->firstHeartRateSample] > 60)
	{
		double averageRate = (double)0.0;

		if ([self->heartRates count] > 0)
		{
			for (NSNumber* sample in self->heartRates)
			{
				averageRate += [sample doubleValue];
			}
			averageRate /= [self->heartRates count];
		}

		HKQuantityType* rateType = [HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierHeartRate];
		HKQuantity* rateQuantity = [HKQuantity quantityWithUnit:[HKUnit heartBeatsPerMinuteUnit] doubleValue:averageRate];
		HKQuantitySample* rateSample = [HKQuantitySample quantitySampleWithType:rateType
																	   quantity:rateQuantity
																	  startDate:self->firstHeartRateSample
																		endDate:self->lastHeartRateSample];

		[self->heartRates removeAllObjects];

		self->firstHeartRateSample = NULL;
		self->lastHeartRateSample = NULL;

		[self->healthStore saveObject:rateSample withCompletion:^(BOOL success, NSError *error) {}];
	}
}

- (void)saveRunningWorkoutIntoHealthStore:(double)miles withStartDate:(NSDate*)startDate withEndDate:(NSDate*)endDate
{
	HKUnit* mileUnit = [HKUnit mileUnit];
	HKQuantity* distanceQuantity = [HKQuantity quantityWithUnit:mileUnit doubleValue:miles];
	HKQuantityType* distanceType = [HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierDistanceWalkingRunning];
	HKQuantitySample* distanceSample = [HKQuantitySample quantitySampleWithType:distanceType quantity:distanceQuantity startDate:startDate endDate:endDate];

	[self->healthStore saveObject:distanceSample withCompletion:^(BOOL success, NSError *error) {}];
}

- (void)saveCyclingWorkoutIntoHealthStore:(double)miles withStartDate:(NSDate*)startDate withEndDate:(NSDate*)endDate
{
	HKUnit* mileUnit = [HKUnit mileUnit];
	HKQuantity* distanceQuantity = [HKQuantity quantityWithUnit:mileUnit doubleValue:miles];
	HKQuantityType* distanceType = [HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierDistanceCycling];
	HKQuantitySample* distanceSample = [HKQuantitySample quantitySampleWithType:distanceType quantity:distanceQuantity startDate:startDate endDate:endDate];

	[self->healthStore saveObject:distanceSample withCompletion:^(BOOL success, NSError *error) {}];
}

- (void)saveCaloriesBurnedIntoHealthStore:(double)calories withStartDate:(NSDate*)startDate withEndDate:(NSDate*)endDate
{
	HKUnit* calorieUnit = [HKUnit largeCalorieUnit];
	HKQuantity* calorieQuantity = [HKQuantity quantityWithUnit:calorieUnit doubleValue:calories];
	HKQuantityType* calorieType = [HKQuantityType quantityTypeForIdentifier:HKQuantityTypeIdentifierActiveEnergyBurned];
	HKQuantitySample* calorieSample = [HKQuantitySample quantitySampleWithType:calorieType quantity:calorieQuantity startDate:startDate endDate:endDate];

	[self->healthStore saveObject:calorieSample withCompletion:^(BOOL success, NSError *error) {}];
}

#pragma mark methods for exporting HealthKit data.

bool NextCoordinate(const char* const activityId, Coordinate* coordinate, void* context)
{
	// The context pointer is the pointer to ourselves.
	if (!(context && coordinate))
	{
		return false;
	}

	HealthManager* healthMgr = (__bridge HealthManager*)context;
	NSString* tempActivityId = [[NSString alloc] initWithUTF8String:activityId]; 
	time_t timestamp = 0;

	if ([healthMgr getHistoricalActivityLocationPoint:tempActivityId
									   withPointIndex:healthMgr->tempPointIndex
										 withLatitude:&coordinate->latitude
										withLongitude:&coordinate->longitude
										 withAltitude:&coordinate->altitude
										withTimestamp:&timestamp])
	{
		coordinate->time = timestamp * 1000; // Convert to milliseconds
		++healthMgr->tempPointIndex;
		return true;
	}
	return false;
}

- (NSString*)exportActivityToFile:(NSString*)activityId withFileFormat:(FileFormat)format toDir:(NSString*)dir
{
	NSString* newFileName;

	// The file name starts with the directory and will include the start time and the sport type.
	NSString* sportType = [self getHistoricalActivityType:activityId];
	time_t startTime = 0;
	time_t endTime = 0;
	[self getWorkoutStartAndEndTime:activityId withStartTime:&startTime withEndTime:&endTime];

	// Export in the desired format.
	self->tempPointIndex = 0;
	char* tempFileName = ExportActivityUsingCallbackData([activityId UTF8String], format, [dir UTF8String], startTime, [sportType UTF8String], NextCoordinate, (__bridge void*)self);

	// Cleanup.
	if (tempFileName)
	{
		newFileName = [[NSString alloc] initWithUTF8String:tempFileName]; 
		free((void*)tempFileName);
	}
	return newFileName;
}

#pragma mark notification handlers

- (void)activityStopped:(NSNotification*)notification
{
	NSDictionary* activityData = [notification object];

	if (activityData)
	{
		NSString* activityType = [activityData objectForKey:@KEY_NAME_ACTIVITY_TYPE];
		NSNumber* startTime = [activityData objectForKey:@KEY_NAME_START_TIME];
		NSNumber* endTime = [activityData objectForKey:@KEY_NAME_END_TIME];
		NSNumber* distance = [activityData objectForKey:@KEY_NAME_DISTANCE];
		NSNumber* calories = [activityData objectForKey:@KEY_NAME_CALORIES];
		NSDate* startDate = [NSDate dateWithTimeIntervalSince1970:[startTime longLongValue]];
		NSDate* endDate = [NSDate dateWithTimeIntervalSince1970:[endTime longLongValue]];

		if ([activityType isEqualToString:@ACTIVITY_TYPE_CYCLING] ||
			[activityType isEqualToString:@ACTIVITY_TYPE_MOUNTAIN_BIKING])
		{
			[self saveCyclingWorkoutIntoHealthStore:[distance doubleValue] withStartDate:startDate withEndDate:endDate];
		}
		else if ([activityType isEqualToString:@ACTIVITY_TYPE_RUNNING] ||
				 [activityType isEqualToString:@ACTIVITY_TYPE_WALKING])
		{
			[self saveRunningWorkoutIntoHealthStore:[distance doubleValue] withStartDate:startDate withEndDate:endDate];
		}
		
		[self saveCaloriesBurnedIntoHealthStore:[calories doubleValue] withStartDate:startDate withEndDate:endDate];
	}
}

#pragma mark methods for converting between our activity type strings and HealthKit's workout enum

- (HKWorkoutActivityType)activityTypeToHKWorkoutType:(NSString*)activityType
{
	if ([activityType isEqualToString:@ACTIVITY_TYPE_CHINUP])
	{
		return HKWorkoutActivityTypeTraditionalStrengthTraining;
	}
	else if ([activityType isEqualToString:@ACTIVITY_TYPE_CYCLING])
	{
		return HKWorkoutActivityTypeCycling;
	}
	else if ([activityType isEqualToString:@ACTIVITY_TYPE_HIKING])
	{
		return HKWorkoutActivityTypeHiking;
	}
	else if ([activityType isEqualToString:@ACTIVITY_TYPE_MOUNTAIN_BIKING])
	{
		return HKWorkoutActivityTypeCycling;
	}
	else if ([activityType isEqualToString:@ACTIVITY_TYPE_RUNNING])
	{
		return HKWorkoutActivityTypeRunning;
	}
	else if ([activityType isEqualToString:@ACTIVITY_TYPE_SQUAT])
	{
		return HKWorkoutActivityTypeTraditionalStrengthTraining;
	}
	else if ([activityType isEqualToString:@ACTIVITY_TYPE_STATIONARY_BIKE])
	{
		return HKWorkoutActivityTypeCycling;
	}
	else if ([activityType isEqualToString:@ACTIVITY_TYPE_TREADMILL])
	{
		return HKWorkoutActivityTypeRunning;
	}
	else if ([activityType isEqualToString:@ACTIVITY_TYPE_PULLUP])
	{
		return HKWorkoutActivityTypeTraditionalStrengthTraining;
	}
	else if ([activityType isEqualToString:@ACTIVITY_TYPE_PUSHUP])
	{
		return HKWorkoutActivityTypeTraditionalStrengthTraining;
	}
	else if ([activityType isEqualToString:@ACTIVITY_TYPE_WALKING])
	{
		return HKWorkoutActivityTypeWalking;
	}
	else if ([activityType isEqualToString:@ACTIVITY_TYPE_OPEN_WATER_SWIMMING])
	{
		return HKWorkoutActivityTypeSwimming;
	}
	else if ([activityType isEqualToString:@ACTIVITY_TYPE_POOL_SWIMMING])
	{
		return HKWorkoutActivityTypeSwimming;
	}
	return HKWorkoutActivityTypeFencing; // Shouldn't get here, so return something funny to make it easier to debug if we do.
}

- (HKWorkoutSessionLocationType)activityTypeToHKWorkoutSessionLocationType:(NSString*)activityType
{
	if ([activityType isEqualToString:@ACTIVITY_TYPE_CHINUP])
	{
		return HKWorkoutSessionLocationTypeIndoor;
	}
	else if ([activityType isEqualToString:@ACTIVITY_TYPE_CYCLING])
	{
		return HKWorkoutSessionLocationTypeOutdoor;
	}
	else if ([activityType isEqualToString:@ACTIVITY_TYPE_HIKING])
	{
		return HKWorkoutSessionLocationTypeOutdoor;
	}
	else if ([activityType isEqualToString:@ACTIVITY_TYPE_MOUNTAIN_BIKING])
	{
		return HKWorkoutSessionLocationTypeOutdoor;
	}
	else if ([activityType isEqualToString:@ACTIVITY_TYPE_RUNNING])
	{
		return HKWorkoutSessionLocationTypeOutdoor;
	}
	else if ([activityType isEqualToString:@ACTIVITY_TYPE_SQUAT])
	{
		return HKWorkoutSessionLocationTypeIndoor;
	}
	else if ([activityType isEqualToString:@ACTIVITY_TYPE_STATIONARY_BIKE])
	{
		return HKWorkoutSessionLocationTypeIndoor;
	}
	else if ([activityType isEqualToString:@ACTIVITY_TYPE_TREADMILL])
	{
		return HKWorkoutSessionLocationTypeIndoor;
	}
	else if ([activityType isEqualToString:@ACTIVITY_TYPE_PULLUP])
	{
		return HKWorkoutSessionLocationTypeIndoor;
	}
	else if ([activityType isEqualToString:@ACTIVITY_TYPE_PUSHUP])
	{
		return HKWorkoutSessionLocationTypeIndoor;
	}
	else if ([activityType isEqualToString:@ACTIVITY_TYPE_WALKING])
	{
		return HKWorkoutSessionLocationTypeOutdoor;
	}
	else if ([activityType isEqualToString:@ACTIVITY_TYPE_OPEN_WATER_SWIMMING])
	{
		return HKWorkoutSessionLocationTypeOutdoor;
	}
	else if ([activityType isEqualToString:@ACTIVITY_TYPE_POOL_SWIMMING])
	{
		return HKWorkoutSessionLocationTypeIndoor;
	}
	return HKWorkoutSessionLocationTypeUnknown; // Shouldn't get here
}

@end
