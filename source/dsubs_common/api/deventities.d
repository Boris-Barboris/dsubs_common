/*
DSubs
Copyright (C) 2017-2025 Baranin Alexander

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Affero General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU Affero General Public License for more details.

You should have received a copy of the GNU Affero General Public License
along with this program.  If not, see <http://www.gnu.org/licenses/>.
*/
module dsubs_common.api.deventities;

import gfm.math.vector;

import dsubs_common.api.constants;
import dsubs_common.api.entities;
import dsubs_common.api.utils;


// devmode-related entities

struct SimulatorRecord
{
	string id;
	string uniqId;
	string scenarioName;
	int connectedPlayers;
	string creatorPlayerName;
}

struct ObservableEntityUpdate
{
	string id;
	string entityType;
	KinematicSnapshot transformSnapshot;
	// arbitrary entityType-specific json-encoded data
	string stateUpdateJson;
}

struct SimulatorLogRecord
{
	string entityType;
	string entityId;
	string message;
}