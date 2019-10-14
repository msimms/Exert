// Created by Michael Simms on 7/15/12.
// Copyright (c) 2012 Michael J. Simms. All rights reserved.

// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#import "ViewController.h"
#import "ActivityMgr.h"
#import "ActivityPreferences.h"
#import "AppDelegate.h"
#import "AppStrings.h"
#import "MapOverviewViewController.h"
#import "Preferences.h"
#import "Segues.h"

#define BUTTON_TITLE_START           NSLocalizedString(@"Start a Workout", nil)
#define BUTTON_TITLE_VIEW            NSLocalizedString(@"View", nil)
#define BUTTON_TITLE_EDIT            NSLocalizedString(@"Edit", nil)
#define BUTTON_TITLE_RESET           NSLocalizedString(@"Reset", nil)
#define BUTTON_TITLE_VIEW_HISTORY    NSLocalizedString(@"History", nil)
#define BUTTON_TITLE_VIEW_STATISTICS NSLocalizedString(@"Statistics", nil)
#define BUTTON_TITLE_VIEW_HEATMAP    NSLocalizedString(@"Heatmap", nil)
#define BUTTON_TITLE_EDIT_PROFILE    NSLocalizedString(@"Profile", nil)
#define BUTTON_TITLE_EDIT_SETTINGS   NSLocalizedString(@"Settings", nil)
#define BUTTON_TITLE_EDIT_SENSORS    NSLocalizedString(@"Sensors", nil)
#define BUTTON_TITLE_EDIT_INTERVALS  NSLocalizedString(@"Intervals", nil)

#define MSG_RESET                    NSLocalizedString(@"This will delete all of your data. Do you wish to continue? This cannot be undone.", nil)
#define MSG_SELECT_NEW               NSLocalizedString(@"Select the workout to perform.", nil)
#define MSG_SELECT_VIEW              NSLocalizedString(@"What would you like to view?", nil)
#define MSG_SELECT_EDIT              NSLocalizedString(@"What would you like to edit?", nil)

#define TITLE_IN_PROGRESS            NSLocalizedString(@"Workout In Progress", nil)
#define MSG_FIRST_TIME_USING         NSLocalizedString(@"There are risks with exercise. Do not start an exercise program without consulting your doctor.", nil)

@interface ViewController ()

@end

@implementation ViewController

@synthesize startWorkoutButton;
@synthesize viewButton;
@synthesize editButton;
@synthesize resetButton;

- (void)viewDidLoad
{
	[super viewDidLoad];

	AppDelegate* appDelegate = (AppDelegate*)[[UIApplication sharedApplication] delegate];
	self->activityTypes = [appDelegate getActivityTypes];

	[self.startWorkoutButton setTitle:BUTTON_TITLE_START forState:UIControlStateNormal];
	[self.viewButton setTitle:BUTTON_TITLE_VIEW forState:UIControlStateNormal];
	[self.editButton setTitle:BUTTON_TITLE_EDIT forState:UIControlStateNormal];
	[self.resetButton setTitle:BUTTON_TITLE_RESET forState:UIControlStateNormal];
}

- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
	[self.navigationController.navigationBar setTintColor:[UIColor blackColor]];

	// Display the first time warning message.
	if (![Preferences hasShownFirstTimeUseMessage])
	{
		[super showOneButtonAlert:STR_CAUTION withMsg:MSG_FIRST_TIME_USING];
		[Preferences setHashShownFirstTimeUseMessage:TRUE];
	}
}

- (void)viewDidDisappear:(BOOL)animated
{
	[super viewDidDisappear:animated];
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	self.navigationController.navigationBarHidden = TRUE;
	
	FreeHistoricalActivityList();
	DestroyCurrentActivity();
}

- (void)viewWillDisappear:(BOOL)animated
{
	self.navigationController.navigationBarHidden = FALSE;
	[super viewWillDisappear:animated];
}

- (BOOL)shouldAutorotate
{
	return NO;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations
{
	return UIInterfaceOrientationMaskPortrait;
}

- (void)prepareForSegue:(UIStoryboardSegue*)segue sender:(id)sender
{
	if ([[segue identifier] isEqualToString:@SEGUE_TO_MAP_OVERVIEW])
	{
		MapOverviewViewController* mapVC = (MapOverviewViewController*)[segue destinationViewController];
		if (mapVC)
		{
			[mapVC setMode:MAP_OVERVIEW_HEAT];
		}
	}
}

- (void)showActivityView:(NSString*)activityType
{
	ActivityViewType viewType = [[[ActivityPreferences alloc] init] getViewType:activityType];
	switch (viewType)
	{
		case ACTIVITY_VIEW_COMPLEX:
			[self performSegueWithIdentifier:@SEQUE_TO_COMPLEX_VIEW sender:self];
			break;
		case ACTIVITY_VIEW_MAPPED:
			[self performSegueWithIdentifier:@SEQUE_TO_MAPPED_VIEW sender:self];
			break;
		case ACTIVITY_VIEW_SIMPLE:
			[self performSegueWithIdentifier:@SEQUE_TO_SIMPLE_VIEW sender:self];
			break;
		default:
			break;
	}
}

#pragma mark button handlers

- (IBAction)onNewActivity:(id)sender
{
	// Display the list of activities from which the user may choose.
	UIAlertController* alertController = [UIAlertController alertControllerWithTitle:nil
																			 message:MSG_SELECT_NEW
																	  preferredStyle:UIAlertControllerStyleActionSheet];
	[alertController addAction:[UIAlertAction actionWithTitle:STR_CANCEL style:UIAlertActionStyleCancel handler:^(UIAlertAction* action) {}]];
	for (NSString* name in self->activityTypes)
	{
		[alertController addAction:[UIAlertAction actionWithTitle:name style:UIAlertActionStyleDefault handler:^(UIAlertAction* action) {
			[self startActivity:name];
		}]];
	}
	[self presentViewController:alertController animated:YES completion:nil];
}

- (IBAction)onView:(id)sender
{
	UIAlertController* alertController = [UIAlertController alertControllerWithTitle:nil
																			 message:MSG_SELECT_VIEW
																	  preferredStyle:UIAlertControllerStyleActionSheet];
	[alertController addAction:[UIAlertAction actionWithTitle:STR_CANCEL style:UIAlertActionStyleCancel handler:^(UIAlertAction* action) {}]];
	[alertController addAction:[UIAlertAction actionWithTitle:BUTTON_TITLE_VIEW_HISTORY style:UIAlertActionStyleDefault handler:^(UIAlertAction* action) {
		[self performSegueWithIdentifier:@SEQUE_TO_HISTORY_VIEW sender:self];
	}]];
	[alertController addAction:[UIAlertAction actionWithTitle:BUTTON_TITLE_VIEW_STATISTICS style:UIAlertActionStyleDefault handler:^(UIAlertAction* action) {
		[self performSegueWithIdentifier:@SEQUE_TO_STATISTICS_VIEW sender:self];
	}]];
	[self presentViewController:alertController animated:YES completion:nil];
}

- (IBAction)onEdit:(id)sender
{
	UIAlertController* alertController = [UIAlertController alertControllerWithTitle:nil
																			 message:MSG_SELECT_EDIT
																	  preferredStyle:UIAlertControllerStyleActionSheet];
	[alertController addAction:[UIAlertAction actionWithTitle:STR_CANCEL style:UIAlertActionStyleCancel handler:^(UIAlertAction* action) {}]];
	[alertController addAction:[UIAlertAction actionWithTitle:BUTTON_TITLE_EDIT_PROFILE style:UIAlertActionStyleDefault handler:^(UIAlertAction* action) {
		[self performSegueWithIdentifier:@SEQUE_TO_PROFILE_VIEW sender:self];
	}]];
	[alertController addAction:[UIAlertAction actionWithTitle:BUTTON_TITLE_EDIT_SETTINGS style:UIAlertActionStyleDefault handler:^(UIAlertAction* action) {
		[self performSegueWithIdentifier:@SEQUE_TO_SETTINGS_VIEW sender:self];
	}]];
	[alertController addAction:[UIAlertAction actionWithTitle:BUTTON_TITLE_EDIT_SENSORS style:UIAlertActionStyleDefault handler:^(UIAlertAction* action) {
		[self performSegueWithIdentifier:@SEQUE_TO_SENSORS_VIEW sender:self];
	}]];
	[alertController addAction:[UIAlertAction actionWithTitle:BUTTON_TITLE_EDIT_INTERVALS style:UIAlertActionStyleDefault handler:^(UIAlertAction* action) {
		[self performSegueWithIdentifier:@SEQUE_TO_INTERVALS_VIEW sender:self];
	}]];
	[self presentViewController:alertController animated:YES completion:nil];
}
	
- (IBAction)onReset:(id)sender
{
	UIAlertController* alertController = [UIAlertController alertControllerWithTitle:nil
																			 message:MSG_RESET
																	  preferredStyle:UIAlertControllerStyleActionSheet];
	[alertController addAction:[UIAlertAction actionWithTitle:STR_CANCEL style:UIAlertActionStyleCancel handler:^(UIAlertAction* action) {}]];
	[alertController addAction:[UIAlertAction actionWithTitle:STR_RESET_DATA style:UIAlertActionStyleDefault handler:^(UIAlertAction* action) {
		AppDelegate* appDelegate = (AppDelegate*)[[UIApplication sharedApplication] delegate];
		[appDelegate resetDatabase];
	}]];
	[alertController addAction:[UIAlertAction actionWithTitle:STR_RESET_PREFS style:UIAlertActionStyleDefault handler:^(UIAlertAction* action) {
		AppDelegate* appDelegate = (AppDelegate*)[[UIApplication sharedApplication] delegate];
		[appDelegate resetPreferences];
	}]];
	[self presentViewController:alertController animated:YES completion:nil];
}

#pragma method to switch to the activity view

- (void)createActivity:(NSString*)activityType
{
	const char* pActivityType = [activityType cStringUsingEncoding:NSASCIIStringEncoding];
	if (pActivityType)
	{
		// Create the data structures and database entries needed to start an activity.
		CreateActivity(pActivityType);

		// Initialize any sensors that we are going to use.
		AppDelegate* appDelegate = (AppDelegate*)[[UIApplication sharedApplication] delegate];
		[appDelegate startSensors];

		// Switch to the activity view.
		[self showActivityView:activityType];
	}
}

- (void)startActivity:(NSString*)activityType
{
	bool isOrphaned = IsActivityOrphaned(&self->orphanedActivityIndex);
	bool isInProgress = IsActivityInProgress();

	if (isOrphaned || isInProgress)
	{
		char* orphanedType = GetHistoricalActivityType(self->orphanedActivityIndex);
		self->orphanedActivityType = [NSString stringWithFormat:@"%s", orphanedType];
		free((void*)orphanedType);

		self->newActivityType = activityType;

		UIAlertController* alertController = [UIAlertController alertControllerWithTitle:TITLE_IN_PROGRESS
																				 message:MSG_IN_PROGRESS
																		  preferredStyle:UIAlertControllerStyleAlert];

		// Add the "re-connect to the orphaned activity" option.
		[alertController addAction:[UIAlertAction actionWithTitle:STR_YES style:UIAlertActionStyleDefault handler:^(UIAlertAction* action) {
			AppDelegate* appDelegate = (AppDelegate*)[[UIApplication sharedApplication] delegate];
			[appDelegate recreateOrphanedActivity:self->orphanedActivityIndex];
			[self showActivityView:self->orphanedActivityType];
		}]];

		// Add the "throw it away and start over" option
		[alertController addAction:[UIAlertAction actionWithTitle:STR_NO style:UIAlertActionStyleDefault handler:^(UIAlertAction* action) {
			AppDelegate* appDelegate = (AppDelegate*)[[UIApplication sharedApplication] delegate];
			[appDelegate loadHistoricalActivityByIndex:self->orphanedActivityIndex];
			[self createActivity:self->newActivityType];
		}]];
		[self presentViewController:alertController animated:YES completion:nil];
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
