//  Created by Michael Simms on 6/12/19.
//  Copyright © 2019 Michael J Simms Software. All rights reserved.

#import "InterfaceController.h"
#import "ActivityMgr.h"
#import "ExtensionDelegate.h"

#define MSG_SELECT_NEW NSLocalizedString(@"Select the workout to perform.", nil)

@interface InterfaceController ()

@end


@implementation InterfaceController

- (void)awakeWithContext:(id)context
{
	[super awakeWithContext:context];
}

- (void)willActivate
{
	// This method is called when watch view controller is about to be visible to user
	[super willActivate];
}

- (void)didDeactivate
{
	// This method is called when watch view controller is no longer visible
	[super didDeactivate];
}

- (IBAction)onStartWorkout
{
	ExtensionDelegate* extDelegate = [WKExtension sharedExtension].delegate;
	NSMutableArray* activityTypes = [extDelegate getActivityTypes];

	NSMutableArray* actions = [[NSMutableArray alloc] init];

	for (NSString* name in activityTypes)
	{
		WKAlertAction* action = [WKAlertAction actionWithTitle:name style:WKAlertActionStyleCancel handler:^(void){
			[self startActivity:name];
		}];	
		[actions addObject:action];
	}

	[self presentAlertControllerWithTitle:nil
								  message:MSG_SELECT_NEW
						   preferredStyle:WKAlertControllerStyleAlert
								  actions:actions];
}

#pragma method to switch to the activity view

- (void)createActivity:(NSString*)activityType
{
	const char* pActivityType = [activityType cStringUsingEncoding:NSASCIIStringEncoding];
	if (pActivityType)
	{
		CreateActivity(pActivityType);
		
		ExtensionDelegate* extDelegate = [WKExtension sharedExtension].delegate;
		[extDelegate startSensors];
		
		//[self showActivityView:activityType];
	}
}

- (void)startActivity:(NSString*)activityType
{
	bool isInProgress = IsActivityInProgress();

	if (isInProgress)
	{
	}
	else if (IsActivityCreated())
	{
		DestroyCurrentActivity();
		[self createActivity:activityType];
	}
	else
	{
		[self createActivity:activityType];
	}
}

@end