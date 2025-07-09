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

/// Protocol messages for master-client - dsubs backend interactions.

module dsubs_common.api.messages;

public import std.uuid;

public import dsubs_common.api.constants;
public import dsubs_common.api.entities;
public import dsubs_common.api.deventities;
public import dsubs_common.api.utils;


// WARNING: all structs in this module are automatically registeded as
// complete protocol messages. Move all utility struct declarations to
// other modules. Do not alter or rearrange structures here without bumping
// apVersion value in ServerStatusRes.

/// Sent by client to check server status when opening main menu
struct ServerStatusReq
{
	__gshared const int g_marshIdx;
}

struct ServerStatusRes
{
	__gshared const int g_marshIdx;
	/// Total number of authorized players currently online.
	int playersOnline;
	/// Client and server values must match exactly.
	int apiVersion = 25;
}

/** This message requests authorization from the server.
After authorization succeeded, client must not send any more of these.
Authorization is done only once for TCP connection. */
struct LoginReq
{
	__gshared const int g_marshIdx;
	@MaxLenAttr(1024) ubyte[] username;		/// encrypted
	@MaxLenAttr(1024) ubyte[] password;		/// encrypted
}

/// Sent in response to LoginReq if everything is OK. Immediately followed by
/// AvailableScenariosRes.
struct LoginSuccessRes
{
	__gshared const int g_marshIdx;
	/// Entity database hash (SHA256). Cannot change without server restart,
	/// hence it is constant throughout TCP session.
	@MaxLenAttr(32) immutable(ubyte)[] dbHash;
	/// true when the player already has a submarine to reconnect to.
	bool alreadySpawned;
	/// Name of the scenario that is loaded to the simulator that contains the
	/// existing submarine.
	string simulatorScenarioName;
	/// and it's scenario type.
	ScenarioType simulatorScenarioType;
	/// Secret to use when logging in as the secondary connection.
	@MaxLenAttr(64) string secondaryConnectionSecret;
	/// When true, the user is granted developer privileges.
	bool developerMode;
}

/** This message requests to register this connection as secondary connection,
that will be used by the server for non-critical volumnous data, such as
sound streaming. Only one such connection can be registered per player. */
struct LoginSecondaryReq
{
	__gshared const int g_marshIdx;
	// secret from LoginSuccessRes
	@MaxLenAttr(64) string secondaryConnectionSecret;
}

/// LoginReq rejection.
struct LoginFailureRes
{
	__gshared const int g_marshIdx;
	string reason;
}

/// Explicit request to query AvailableScenariosRes. Should be sent after death
/// when the user has read the de-brief and wishes to return to main spawn menu again.
struct AvailableScenariosReq
{
	__gshared const int g_marshIdx;
}

/// If the user is not spawned, right after LoginSuccessRes the server sends this message.
/// Should be used to render main menu. Different content for each user.
@Compressed
struct AvailableScenariosRes
{
	__gshared const int g_marshIdx;
	AvailableCampaign[] campaigns;
	// does not include campaign scenarios
	AvailableScenario[] scenarios;
}

/// Sent by client when he wants to download full entity database. Is constant for all users.
struct EntityDbReq
{
	__gshared const int g_marshIdx;
}

/// Entity database, available to the client
@Compressed
struct EntityDbRes
{
	__gshared const int g_marshIdx;
	EntityDb entityDb;
}

/// If the player is not already spawned, he can request to spawn with chosen loadout.
/// If spawn succeeds, ReconnectStateRes is sent in response by the server.
struct SpawnReq
{
	__gshared const int g_marshIdx;
	@MaxLenAttr(64) string submarineName;
	@MaxLenAttr(64) string propulsorName;
	@MaxLenAttr(16) AmmoRoomFullState[] ammoRoomLoadouts;
	/// Only the tubes with loadedOnSpawn==true must be specified here.
	@MaxLenAttr(16) TubeSpawnState[] loadableTubeLoadouts;
	/// You either request to spawn in a new simulator or in existing one.
	SpawnRequestType type;
	/// The simulator to spawn in or the scenario name to create new simulator from.
	@MaxLenAttr(256) string simulatorIdOrScenarioName;
}

/// Spawn failure.
struct SpawnFailureRes
{
	__gshared const int g_marshIdx;
	string reason;
}

/// Request to abandon an existing submarine and simulator. Will not be accepted for persistent
/// simulators like the main_arena. If accepted, will result in SimulatorKilledRes
/// after unspecified delay.
struct AbandonReq
{
	__gshared const int g_marshIdx;
}

/// Request to reconnect to existing submarine. Should be issued
/// instead of SpawnReq when 'alreadySpawned' from LoginRes was true.
/// Server will reply with ReconnectStateRes and resume normal
/// simulator flow message streaming.
struct ReconnectReq
{
	__gshared const int g_marshIdx;
}

/// Right after successfull spawn or reconnection, the server flushes the submarine
/// configuration and state to the client using this message. It is sufficient to
/// get the full observable state of all controllable parts of the sub, it's
/// weapons and systems, as well as scenario goal and communication state.
@Compressed
struct ReconnectStateRes
{
	__gshared const int g_marshIdx;
	/// Globally-unique submarine identifier. Can be used to restore CIC state
	/// from backup after client crash.
	string subId;
	/// Simulator identifier. Useful for watching replays later.
	string simulatorId;
	string submarineName;
	string propulsorName;
	KinematicSnapshot subSnap;
	WireSnapshot[] wireSnaps;
	float targetCourse;
	float targetThrottle;
	float[] listenDirs;
	float[] desiredWireLenghts;
	TubeFullState[] tubeStates;
	WireGuidanceFullState[] wireGuidanceStates;
	AmmoRoomFullState[] ammoRoomStates;
	/// Current list of all scenario map elements that must be rendered
	MapElement[] mapElements;
	/// List of all scenario goals
	ScenarioGoal[] goals;
	/// Tail of the chat log. Length is server-defined.
	ChatMessage[] lastChatLogs;
	/// True when the player can abandon the simulator.
	bool canAbandon;
	/// Is simulator paused.
	bool isPaused;
	/// Can the simulator be paused.
	bool canBePaused;
	/// Time acceleration factor of the simulator. 10 means normal speed.
	/// 5 means 0.5x, and everything is slowmo.
	/// 80 means the simlator runs 8x normal speed.
	/// Server currently accepts values from 5 to 80.
	short timeAccelerationFactor;
}

/*
SIMULATOR FLOW MESSAGES:

following messages are sent and received when client and backend both enter
normal simulation state by either successfully spawning submarine or
reconnecting to it.
*/

/// Server periodically sends the player updates with his submarine position.
struct SubKinematicRes
{
	__gshared const int g_marshIdx;
	KinematicSnapshot snap;
	// all the wires that are attached to the sub are reported.
	WireSnapshot[] wireSnaps;
}

/// Sent by client in order to update desired throttle on his submarine
struct ThrottleReq
{
	__gshared const int g_marshIdx;
	float target;
}

/// Sent by client in order to update desired course of his submarine
struct CourseReq
{
	__gshared const int g_marshIdx;
	float target;
}

/// Sent by client in order to specify listening/beamforming direction for a hydrophone.
/// Contents of HydrophoneAudioStreamRes will correspond to this direction.
struct ListenDirReq
{
	__gshared const int g_marshIdx;
	int hydrophoneIdx;
	float dir;		/// world-space listen direction
}

/// Server streams hydrophone broadband data to the player.
/// All hydrophones that were active are represented here.
/// If some hydrophone is absent, it is inactive.
struct HydrophoneDataStreamRes
{
	__gshared const int g_marshIdx;
	usecs_t atTime;
	HydrophoneData[] data;
}

/// Server streams hydrophone audio to the player via the separate
/// "secondary" connection (to prevent severe lag on slow or remote links).
/// All hydrophones that were active are represented here.
/// If some hydrophone is absent, it is either
/// inactive, or it's beamforming rotation was in the antennae deadzone.
struct HydrophoneAudioStreamRes
{
	__gshared const int g_marshIdx;
	usecs_t atTime;
	HydrophoneAudio[] audio;
}

/// Active sonar data is streamed to the player after the ping.
struct SonarStreamRes
{
	__gshared const int g_marshIdx;
	usecs_t atTime;
	SonarSliceData[] data;
}

/// Client sends when he wants to emit a ping via active sonar.
/// Server may ignore this request for optimization purposes (cooldown)
struct EmitPingReq
{
	__gshared const int g_marshIdx;
	int sonarIdx;
	float ilevel;	/// intensity level
}

/// Server sends when client's submarine is no longer alive or victory/loss
/// condition is reached. May be followed by SimulatorTerminatingRes if generated
/// by non-persistent scenario.
/// To return to main menu, client should send AvailableScenariosReq.
struct SimFlowEndRes
{
	__gshared const int g_marshIdx;
	SimFlowEndReason reason;
	string shortReport;
	// kill records are here
	string longReport;
}

/// Server sends when the simulator instance is abandoned or killed. Sent as an answer to
/// AbandonReq, or right after SimFlowEndRes in non-peristent scenario.
/// To return to main menu, client should send AvailableScenariosReq.
struct SimulatorTerminatingRes
{
	__gshared const int g_marshIdx;
}

/// Client requests to change desired loaded weapon.
/// If the tube is in incorrect state, message is ignored.
/// To unload the weapon from the tube completely, set
/// 'weaponName' to empty string/null.
struct LoadTubeReq
{
	__gshared const int g_marshIdx;
	int tubeId;
	string weaponName;
}

/// Client requests to change the desired tube state. Only the correct
/// state machine evolutions are accepted, otherwise the message
/// is ignored.
struct SetTubeStateReq
{
	__gshared const int g_marshIdx;
	int tubeId;
	/// Server will walk through the state machine until the tube reaches
	/// desired state. Only one of 3 stable states can be specified here.
	TubeState desiredState;
}

/// Client requests to launch the weapon in the tube.
/// Weapon parameters MUST be correct (contained in param constraints).
struct LaunchTubeReq
{
	__gshared const int g_marshIdx;
	int tubeId;
	/// If this weapon does not match the actual loaded weapon,
	/// the request is ignored.
	string weaponName;
	@MaxLenAttr(32) WeaponParamValue[] weaponParams;
}


/// Client sends commands to update parameters of a wire-guided torpedo
struct WireGuidanceUpdateParamsReq
{
	__gshared const int g_marshIdx;
	@MaxLenAttr(64) string wireGuidanceId;
	@MaxLenAttr(32) WeaponParamValue[] weaponParams;
}


/// Client sends commands to (de)activate torpedo
struct WireGuidanceActivateReq
{
	__gshared const int g_marshIdx;
	@MaxLenAttr(64) string wireGuidanceId;
	bool shouldBeActive;
}


/// Periodic update from a wire-guided weapon
struct WireGuidanceStateRes
{
	__gshared const int g_marshIdx;
	// weaponParams are set only in the very first such message, right
	// after torpedo's launch.
	WireGuidanceFullState wireGuidanceState;
}


/// Sent on guided torp detonation, wire cut or fuel exhaustion
struct WireGuidanceLostRes
{
	__gshared const int g_marshIdx;
	int tubeId;
	string wireGuidanceId;
}


/// Server reports tube state change.
struct TubeStateUpdateRes
{
	__gshared const int g_marshIdx;
	TubeFullState tube;
	bool launchOccured;
	/// null when launchOccured is false
	string launchedWeaponName;
}

/// Server reports ammo room state change.
struct AmmoRoomStateUpdateRes
{
	__gshared const int g_marshIdx;
	AmmoRoomFullState room;
}

/// Map overlay state is always updated as a whole.
@Compressed
struct MapOverlayUpdateRes
{
	__gshared const int g_marshIdx;
	MapElement[] mapElements;
}

/// Backend sends a chat message to client.
@Compressed
struct ChatMessageRes
{
	__gshared const int g_marshIdx;
	ChatMessage message;
}

/// Client sends when it wants to set desired wire length.
struct WireDesiredLengthReq
{
	__gshared const int g_marshIdx;
	int wireIdx;
	float desiredLength = 0.0f;
}

/// Goal set state is always updated as a whole.
@Compressed
struct ScenarioGoalUpdateRes
{
	__gshared const int g_marshIdx;
	ScenarioGoal[] goals;
}

/// Non-persistent simulators can be paused by the player
struct PauseSimulatorReq
{
	__gshared const int g_marshIdx;
	bool shouldBePaused;
}

/// Simulator broadcasts it's pause state after PauseSimulatorReq.
struct SimulatorPausedRes
{
	__gshared const int g_marshIdx;
	bool isPaused;
}

/// Non-persistent simulators can change their time acceleration factor
struct TimeAccelerationReq
{
	__gshared const int g_marshIdx;
	// 10 is normal, 5 is 0.5x (slow), 80 is 8x (fast).
	// Server currently accepts values from 5 to 80.
	short timeAccelerationFactor;
}

/// Simulator broadcasts it's time acceleration after TimeAccelerationReq.
struct TimeAccelerationRes
{
	__gshared const int g_marshIdx;
	// 10 is normal, 5 is 0.5x (slow), 80 is 8x (fast).
	short timeAccelerationFactor;
}


//
// Replay-related messages
//

/// Request to get replay data from the server for a given day. Does not require authorization.
struct ReplayGetDataReq
{
	__gshared const int g_marshIdx;
	/// "main_arena" for default pvp scenario. Otherwise, simulatorId.
	@MaxLenAttr(256) string simulatorInstance;
	/// Some scenarios run for days or weeks. We do not give more than 1 day
	/// worth of data. YYYY-MM-DD format.
	@MaxLenAttr(256) string metricsDate;
}

/// server's response to ReplayGetDataReq.
@Compressed
struct ReplayDataRes
{
	__gshared const int g_marshIdx;
	/// Slices are generated for this date. YYYY-MM-DD format.
	string metricsDate;
	ReplaySlice[] replaySlices;
}


//
// Dev-mode messages
//

/// When in developer mode, list simulators that can be observed
struct DevSimulatorsListReq
{
	__gshared const int g_marshIdx;
}

struct DevSimulatorsListRes
{
	__gshared const int g_marshIdx;
	SimulatorRecord[] simulators;
}

/// Enter simulator observation mode
struct DevObserveSimulatorReq
{
	__gshared const int g_marshIdx;
	string uniqId;
}

@Compressed
struct DevObserveSimulatorRes
{
	__gshared const int g_marshIdx;
	bool success;	// may be false for some reason
	SimulatorRecord simRecord;
	// full entity state sync
	ObservableEntityUpdate[] allEntities;
}

/// Periodically streamed on each simulator update to the observer's client.
struct DevObserverSimulatorUpdateRes
{
	__gshared const int g_marshIdx;
	usecs_t atTime;
	/// Full entity state sync.
	/// If some entity is missing from the list, it was destroyed.
	ObservableEntityUpdate[] existingEntities;
	/// Special messages that are of note to the developers.
	SimulatorLogRecord[] logRecords;
}

/// Stop observing simulator request. Always succeeds.
struct DevStopObservingReq
{
	__gshared const int g_marshIdx;
}

/// Unconditional simulator termination request
struct DevTerminateSimulatorReq
{
	__gshared const int g_marshIdx;
	string simulatorUniqId;
}

/// Request to create simulator without spawning in it and make it run without
/// a player.
struct DevCreateSimulatorReq
{
	__gshared const int g_marshIdx;
	/// Scenario name to create new simulator from. Can be chosen from
	/// 'developer'-type scenarios.
	@MaxLenAttr(256) string scenarioName;
}