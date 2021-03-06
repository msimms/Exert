// Created by Michael Simms on 8/5/20.
// Copyright (c) 2020 Michael J. Simms. All rights reserved.

#import <Foundation/Foundation.h>

#import "BluetoothServices.h"
#import "BtleSensor.h"

#define NOTIFICATION_NAME_RADAR       "RadarUpdated"

#define KEY_NAME_RADAR                "Power"
#define KEY_NAME_RADAR_TIMESTAMP_MS   "Time"
#define KEY_NAME_RADAR_PERIPHERAL_OBJ "Peripheral"

@interface BtleRadar : BtleSensor
{
}

- (SensorType)sensorType;

- (void)enteredBackground;
- (void)enteredForeground;

- (void)startUpdates;
- (void)stopUpdates;
- (void)update;

@end
