// Created by Michael Simms on 12/10/19.
// Copyright (c) 2019 Michael J. Simms. All rights reserved.

// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

#include "TrainingPaceCalculator.h"
#include "VO2MaxCalculator.h"

TrainingPaceCalculator::TrainingPaceCalculator()
{
}

TrainingPaceCalculator::~TrainingPaceCalculator()
{
}

double TrainingPaceCalculator::ConvertToSpeed(double vo2)
{
	return 29.54 + 5.000663 * vo2 - 0.007546 * vo2 * vo2;
}

// Give the athlete's VO2Max, returns the suggested long run, easy run, tempo run, and speed run paces.
std::map<TrainingPaceType, double> TrainingPaceCalculator::CalcFromVO2Max(double vo2max)
{
	double longRunPace = vo2max * 0.6;
	double easyPace = vo2max * 0.7;
	double tempoPace = vo2max * 0.88;
	double speedPace = vo2max * 1.1;
	longRunPace = this->ConvertToSpeed(longRunPace);
	easyPace = this->ConvertToSpeed(easyPace);
	tempoPace = this->ConvertToSpeed(tempoPace);
	speedPace = this->ConvertToSpeed(speedPace);
	
	std::map<TrainingPaceType, double> paces;
	paces.insert(std::pair<TrainingPaceType, double>(LONG_RUN_PACE, longRunPace));
	paces.insert(std::pair<TrainingPaceType, double>(EASY_RUN_PACE, easyPace));
	paces.insert(std::pair<TrainingPaceType, double>(TEMPO_RUN_PACE, tempoPace));
	paces.insert(std::pair<TrainingPaceType, double>(SPEED_RUN_PACE, speedPace));
	return paces;
}

// Give the athlete's maximum and resting heart rates, returns the suggested long run, easy run, tempo run, and speed run paces.
std::map<TrainingPaceType, double> TrainingPaceCalculator::CalcFromHR(double maxHR, double restingHR)
{
	VO2MaxCalculator v02MaxCalc;
	double vo2max = v02MaxCalc.EstimateVO2MaxFromHeartRate(maxHR, restingHR);
	return this->CalcFromVO2Max(vo2max);
}

// Give the an athlete's recent race result, returns the suggested long run, easy run, tempo run, and speed run paces.
std::map<TrainingPaceType, double> TrainingPaceCalculator::CalcFromRaceDistanceInMeters(double raceDistanceMeters, double raceTimeMinutes)
{
	VO2MaxCalculator v02MaxCalc;
	double vo2max = v02MaxCalc.EstimateVO2MaxFromRaceDistanceInMeters(raceDistanceMeters, raceTimeMinutes);
	return this->CalcFromVO2Max(vo2max);
}