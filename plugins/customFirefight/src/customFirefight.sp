
#include <sourcemod>
#include <sdktools>
#include <chatCmds>
#undef REQUIRE_PLUGIN
#include <matchBot>

#pragma newdecls required
#pragma semicolon 1

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#define VERSION "0.3.5"

#define FIREFIGHT "firefight"

#define SEC 2
#define INS 3

#define OBJ_A 0
#define OBJ_B 1
#define OBJ_C 2

#define ML_CFG_NAME 32
#define ML_ARGS 64
#define ML_MAP 20
#define ML_VEC 32
#define ML_SIDE 16
#define ML_MODEL 128
#define ML_TRANSFORM 80
#define ML_PROP_NAME 32
#define ML_VOICE_OVER 32

#define VO_MAX_INDEX 3

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

bool usingMatchBot = false;

int objRscEnt = -1;
int defenders = -1;

bool isRegulation = false;
bool isExtraTime = false;
Handle roundTimeHandle;

float startTime = 0.0;
float roundTimerValue = -1.0;

ConVar cv_roundTime;
ConVar cv_capTime;
ConVar cv_ignoreTimer;
ConVar cv_ignoreWin;

ConVar cfg_name;
ConVar cfg_defenders;
ConVar cfg_objsToWin;
ConVar cfg_objsToWinEt;
ConVar cfg_concurrentCaps;
ConVar cfg_extraTimeOverride;

bool mapLoaded;
bool hasCustomSpawns = false;
bool doInitializeMap = false;
bool hooksEnabled;

char vo_attacking_et[INS + 1][ML_VOICE_OVER] = {"", "", "hq/security/theyhave9.ogg", "hq/insurgent/theyhave1.ogg"};
char vo_defending_et[INS + 1][ML_VOICE_OVER] = {"", "", "hq/security/wehave5.ogg", "hq/insurgent/wehave10.ogg"};

char vo_attacking_list[INS + 1][VO_MAX_INDEX][ML_VOICE_OVER] = {
	{"", "", ""},
	{"", "", ""},
	{"hq/security/theyhave1.ogg", "hq/security/theyhave3.ogg", "hq/security/theyhave6.ogg"},
	{"hq/insurgent/theyhave2.ogg", "hq/insurgent/theyhave3.ogg", "hq/insurgent/theyhave7.ogg"}
};

char vo_defending_list[INS + 1][VO_MAX_INDEX][ML_VOICE_OVER] = {
	{"", "", ""},
	{"", "", ""},
	{"hq/security/wehave1.ogg", "hq/security/wehave2.ogg", "hq/security/wehave4.ogg"},
	{"hq/insurgent/wehave2.ogg", "hq/insurgent/wehave5.ogg", "hq/insurgent/wehave6.ogg"}
};

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

#include "include/spawn.sp"
#include "include/player.sp"
#include "include/object.sp"
#include "include/objective.sp"
#include "include/chatCmds.sp"
#include "include/util.sp"

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

public Plugin myinfo = {
	name = "Custom Firefight",
	author = "Outlawled",
	description = "A framework for custom Firefight gamemodes",
	version = VERSION,
	url = "https://esgl.pro"
};

public void OnPluginStart() {
	mapLoaded = false;
	hooksEnabled = false;

	cv_roundTime = FindConVar("mp_roundtime");
	cv_capTime = FindConVar("mp_cp_capture_time");
	cv_ignoreTimer = FindConVar("mp_ignore_timer_conditions");
	cv_ignoreWin = FindConVar("mp_ignore_win_conditions");

	cfg_name = CreateConVar("ff_cfg", FIREFIGHT, "The name of the custom Firefight cfg to use or 'firefight' for NWI Firefight", FCVAR_NOTIFY);
	cfg_defenders = CreateConVar("ff_defenders", "none", "The defending side <security|insurgents|none>", FCVAR_NOTIFY);
	cfg_objsToWin = CreateConVar("ff_objectives_to_win", "3", "How many uncontested objectives a team needs control of to win early", FCVAR_NOTIFY, true, 0.0, true, 3.0);
	cfg_objsToWinEt = CreateConVar("ff_objectives_to_win_extra_time", "2", "How many uncontested objectives a team needs control of to win during extra time", FCVAR_NOTIFY, true, 0.0, true, 3.0);
	cfg_concurrentCaps = CreateConVar("ff_allow_concurrent_caps", "1", "Whether or not a team is able to capture multiple objectives simultaneously", FCVAR_NOTIFY);
	cfg_extraTimeOverride = CreateConVar("ff_extra_time_override", "-1", "Amount of extra time added or -1 for it to equal the cap time", FCVAR_NOTIFY);

	cfg_name.AddChangeHook(OnCfgSet);
	cfg_defenders.AddChangeHook(OnDefendersSet);
}

public void OnLibraryAdded(const char[] name) {
    if (StrEqual(name, LIB_CHAT_CMDS)) {
        createChatCmds();
    }
	else if (StrEqual(name, LIB_MATCH_BOT)) {
		usingMatchBot = true;
	}
}

public void OnCfgSet(ConVar convar, const char[] oldValue, const char[] newValue) {
	if (mapLoaded && !StrEqual(oldValue, newValue, false)) {
		if (LoadCfg()) { InitializeMap(); }
		else { convar.RestoreDefault(); }
	}
}

public void OnDefendersSet(ConVar convar, const char[] oldValue, const char[] newValue) {
	if (!StrEqual(oldValue, newValue, false)) {
		if (StrEqual(newValue, "security", false)) { defenders = SEC; }
		else if (StrEqual(newValue, "insurgents", false)) { defenders = INS; }
		else if (StrEqual(newValue, "none", false)) { defenders = -1; }
		else { cfg_defenders.SetString("none"); }
	}
}

public void OnConfigsExecuted() {
	mapLoaded = true;

	if (LoadCfg()) { doInitializeMap = true; }
	else {
		cfg_name.RestoreDefault();
		doInitializeMap = false;
	}
}

public void OnMapEnd() {
	ClearObjects();
	mapLoaded = false;
}

public void OnClientPostAdminCheck(int client) {
	if (Player(client).isValid && doInitializeMap) {
		InitializeMap();
		doInitializeMap = false;
	}
}

public bool LoadCfg() {
	ClearTimers();

	ClearObjects();
	ClearSpawns();
	objRscEnt = -1;

	char cfg[ML_CFG_NAME];
	cfg_name.GetString(cfg, ML_CFG_NAME);

	if (IsModeSupported(cfg)) {
		char mapCfg[PLATFORM_MAX_PATH];
		GetMap(mapCfg);
		BuildPath(Path_SM, mapCfg, PLATFORM_MAX_PATH, "configs/customFirefight/%s/%s.cfg", cfg, mapCfg);

		if (FileExists(mapCfg)) {
			ServerCommand("exec sourcemod/customFirefight/%s", cfg);

			KeyValues kv = new KeyValues("cfg");
			kv.ImportFromFile(mapCfg);

			if (kv.JumpToKey("objectives", false)) {
				char side[ML_SIDE];
				kv.GetString("a", side, ML_SIDE, "neutral");
				Objective(OBJ_A).initialSide = GetSideIndex(side);

				kv.GetString("b", side, ML_SIDE, "neutral");
				Objective(OBJ_B).initialSide = GetSideIndex(side);

				kv.GetString("c", side, ML_SIDE, "neutral");
				Objective(OBJ_C).initialSide = GetSideIndex(side);

				kv.Rewind();
			}

			if (kv.JumpToKey("spawns", false)) {
				if (kv.JumpToKey("security", false)) { CreateSpawnsForSide(kv, SEC); }
				if (kv.JumpToKey("insurgents", false)) { CreateSpawnsForSide(kv, INS); }

				FinalizeSpawnAreas();
				kv.Rewind();
			}

			if (kv.JumpToKey("objects", false) && kv.GotoFirstSubKey()) {
				char model[ML_MODEL];

				do {
					kv.GetSectionName(model, ML_MODEL);
					ReplaceString(model, ML_MODEL, " ", "/");
					PrecacheModel(model);

					if (kv.GotoFirstSubKey(false)) {
						char transform[ML_TRANSFORM];
						float pos[3];
						float rot[3];

						do {
							kv.GetSectionName(transform, ML_TRANSFORM);
							ParseTransform(transform, pos, rot);
							Object(model, pos, rot, kv.GetNum(NULL_STRING) == 1);
						}
						while(kv.GotoNextKey(false));
					}

					kv.GoBack();
				}
				while(kv.GotoNextKey());
			}

			delete kv;

			if (!hooksEnabled) {
				hooksEnabled = true;

				HookEvent("player_spawn", OnSpawn, EventHookMode_Post);
				HookEvent("player_death", OnDeath, EventHookMode_Post);
				HookEvent("controlpoint_starttouch", OnEntered, EventHookMode_Post);
				HookEvent("controlpoint_endtouch", OnExited, EventHookMode_Post);
				HookEvent("controlpoint_captured", OnCaptured, EventHookMode_Post);
				HookEvent("round_start", OnPreRoundStart, EventHookMode_Pre);
				HookEvent("round_freeze_end", OnRoundStart, EventHookMode_Pre);
				HookEvent("round_end", OnRoundEnd, EventHookMode_Pre);
			}

			return true;
		}
	}

	if (hooksEnabled) {
		hooksEnabled = false;

		UnhookEvent("player_spawn", OnSpawn, EventHookMode_Post);
		UnhookEvent("player_death", OnDeath, EventHookMode_Post);
		UnhookEvent("controlpoint_starttouch", OnEntered, EventHookMode_Post);
		UnhookEvent("controlpoint_endtouch", OnExited, EventHookMode_Post);
		UnhookEvent("controlpoint_captured", OnCaptured, EventHookMode_Post);
		UnhookEvent("round_start", OnPreRoundStart, EventHookMode_Pre);
		UnhookEvent("round_freeze_end", OnRoundStart, EventHookMode_Pre);
		UnhookEvent("round_end", OnRoundEnd, EventHookMode_Pre);
	}

	ServerCommand("exec sourcemod/customFirefight/firefight");
	return false;
}

public void CreateSpawnsForSide(KeyValues kv, int side) {
	if (kv.GotoFirstSubKey(false)) {
		char transform[ML_TRANSFORM];
		float pos[3];
		float rot[3];

		do {
			kv.GetString(NULL_STRING, transform, ML_TRANSFORM);
			ParseTransform(transform, pos, rot);
			pos[2]++;

			Spawn(side, pos, rot);
		}
		while(kv.GotoNextKey(false));

		kv.GoBack();
	}

	kv.GoBack();
}

public void ClearTimers() {
	if (roundTimeHandle != null) { delete roundTimeHandle; }
}

public bool IsModeSupported(const char[] mode) {
	if (strlen(mode) == 0 || StrEqual(mode, FIREFIGHT, false)) { return false; }
	char modeDir[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, modeDir, PLATFORM_MAX_PATH, "configs/customFirefight/%s", mode);
	return DirExists(modeDir);
}

public void InitializeMap() {
	SpawnAllObjects();
	InitializeObjectives();
	InitializeZones();
}

public int GetOpponent(int side) {
	if (side == SEC) { return INS; }
	if (side == INS) { return SEC; }
	return -1;
}

public int GetSideIndex(const char[] sideName) {
	if (StrEqual(sideName, "security", false)) { return SEC; }
	if (StrEqual(sideName, "insurgents", false)) { return INS; }
	if (StrEqual(sideName, "neutral", false)) { return 0; }
	return -1;
}

public bool EndRound(int winner) {
	SetVariantInt(winner);
	AcceptEntityInput(FindEntityByClassname(-1, "ins_rulesproxy"), "EndRound");
	return true;
}

public void OnEntered(Event event, const char[] name, bool dontBroadcast) {
	Player player = Player(event.GetInt("player"));
	Objective obj = Objective(event.GetInt("area"));

	if (player.isValid && obj.isValid) { obj.onEntered(player); }
}

public void OnExited(Event event, const char[] name, bool dontBroadcast) {
	Player player = Player(event.GetInt("player"));
	Objective obj = Objective(event.GetInt("area"));

	if (player.isValid && obj.isValid) { obj.onExited(player); }
}

public void OnCaptured(Event event, const char[] name, bool dontBroadcast) {
	int side = event.GetInt("team");
	Objective obj = Objective(event.GetInt("cp"));

	if (!IsNeutral(side) && obj.isValid) { obj.onCapped(side); }
}

public void OnPreRoundStart(Event event, const char[] name, bool dontBroadcast) {
	for (int i = OBJ_A; i <= OBJ_C; i++) { Objective(i).reset(); }

	ClearTimers();
	ClearPause();
	SpawnAllObjects();
	InitializeObjectives();
	InitializeZones();
}

public Action OnRoundStart(Event event, const char[] name, bool dontBroadcast) {
	ClearTimers();
	isRegulation = true;
	isExtraTime = false;

	if (IsMatchLive()) {
		if (!EndRoundIfTeamEliminated()) {
			ClearPause();
			roundTimeHandle = CreateTimer(cv_roundTime.FloatValue, OnTimeExpired);
			cv_ignoreTimer.BoolValue = true;
			cv_ignoreWin.BoolValue = true;

			int controllingSide = SideWithControl();

			if (controllingSide != -1) {
				int voIndex = GetRandomInt(0, VO_MAX_INDEX - 1);

				for (int i = 1; i <= MaxClients; i++) {
					Player player = Player(i);

					if (player.isValid) {
						int side = player.getTargetSide();

						if (side == controllingSide) { player.playSound(vo_defending_list[side][voIndex]); }
						else { player.playSound(vo_attacking_list[side][voIndex]); }
					}
				}
			}
		}

		return Plugin_Handled;
	}

	return Plugin_Continue;
}

public void OnRoundEnd(Event event, const char[] name, bool dontBroadcast) {
	ClearTimers();
}

public bool IsNeutral(int side) {
	if (side == SEC || side == INS) { return false; }
	return true;
}

public int SideWithControl() {
	int objsOwned[INS + 1] = {0, 0, 0, 0};
	for (int i = OBJ_A; i <= OBJ_C; i++) { objsOwned[Objective(i).side]++; }

	if (objsOwned[SEC] > objsOwned[INS]) { return SEC; }
	if (objsOwned[INS] > objsOwned[SEC]) { return INS; }
	return -1;
}

public void ClearPause() {
	roundTimerValue = -1.0;
	GameRules_SetProp("m_bTimerPaused", 0);
}

public void PauseRoundTimer() {
	if (roundTimeHandle != null) { delete roundTimeHandle; }

	float time = GetGameTime();

	GameRules_SetProp("m_bTimerPaused", 1);
	GameRules_SetPropFloat("m_flLastPauseTime", time);

	roundTimerValue = startTime + GameRules_GetPropFloat("m_flRoundLength") - time;
}

public void SetRoundTimer(float time) {
	if (roundTimeHandle != null) { delete roundTimeHandle; }

	ClearPause();
	startTime = GetGameTime();

	GameRules_SetPropFloat("m_flRoundLength", time);
	GameRules_SetPropFloat("m_flRoundStartTime", startTime);

	roundTimeHandle = CreateTimer(time, OnTimeExpired);
}

public bool IsTimerPaused() { return roundTimerValue >= 0.0; }

public bool DoPauseRoundTimer() {
	int objsOwned[INS + 1] = {0, 0, 0, 0};
	int objsCapping[INS + 1] = {0, 0, 0, 0};

	for (int i = OBJ_A; i <= OBJ_C; i++) {
		Objective obj = Objective(i);
		int side = obj.side;

		if (obj.isActivelyCapping()) {
			if (IsNeutral(side)) {
				if (obj.countSec > obj.countIns) { objsCapping[SEC]++; }
				else { objsCapping[INS]++; }
			}
			else { objsCapping[GetOpponent(side)]++; }
		}

		objsOwned[side]++;
	}

	if (objsOwned[SEC] < objsOwned[INS]) { return objsCapping[SEC] > 0; }
	if (objsOwned[SEC] > objsOwned[INS]) { return objsCapping[INS] > 0; }

	return false;
}

public void ResetRoundTimer() {
	float timeExtension = cfg_extraTimeOverride.FloatValue;
	if (timeExtension < 0) { timeExtension = cv_capTime.FloatValue; }
	roundTimerValue = timeExtension;
}

public void UpdateRoundPauseState() {
	if (isExtraTime) {
		if (DoPauseRoundTimer()) {
			if (!IsTimerPaused()) { PauseRoundTimer(); }
		}
		else if (IsTimerPaused()) { SetRoundTimer(roundTimerValue); }
	}
}

public bool EndRoundIfTeamEliminated() {
	int aliveCount[INS + 1] = {0, 0, 0, 0};

	for (int i = 1; i <= MaxClients; i++) {
		Player player = Player(i);
		if (player.isValid && player.isAlive) { aliveCount[player.side]++; }
	}

	if (aliveCount[SEC] == 0) { return EndRound(INS); }
	if (aliveCount[INS] == 0) { return EndRound(SEC); }

	return false;
}

public bool EndRoundIfTeamHasControl() {
	int total[INS + 1] = {0, 0, 0, 0};
	int uncontested[INS + 1] = {0, 0, 0, 0};

	for (int i = OBJ_A; i <= OBJ_C; i++) {
		Objective obj = Objective(i);
		if (!obj.isContested()) { uncontested[obj.side]++; }
		total[obj.side]++;
	}

	int objsToWin = cfg_objsToWin.IntValue;

	if (IsAsym()) {
		if (!isRegulation && !isExtraTime) { return EndRound(defenders); }

		int attackers = GetOpponent(defenders);

		if (uncontested[attackers] >= objsToWin) { return EndRound(attackers); }
		else if (!isRegulation) {
			if (total[defenders] - uncontested[defenders] < objsToWin) { return EndRound(defenders); }
		}
	}
	else {
		if (!isRegulation && !isExtraTime) {
			if (total[SEC] > total[INS]) { return EndRound(SEC); }
			if (total[INS] > total[SEC]) { return EndRound(INS); }
			return EndRound(0);
		}

		int reqObjs = isExtraTime ? cfg_objsToWinEt.IntValue : objsToWin;

		if (uncontested[SEC] > uncontested[INS]) {
			if (uncontested[SEC] >= reqObjs) { return EndRound(SEC); }
		}

		if (uncontested[INS] > uncontested[SEC]) {
			if (uncontested[INS] >= reqObjs) { return EndRound(INS); }
		}
	}

	return false;
}

public bool IsAsym() { return defenders != -1; }

public bool IsMidRound() {
	return IsMatchLive() && GameRules_GetProp("m_iGameState") == 4;
}

public Action OnRoundExtended(Handle timer, any timeAdded) {
	//PrintHintTextToAll("[%.0f seconds added]", timeAdded);
	PrintToChatAll("Extra time added!");

	for (int i = 1; i <= MaxClients; i++) {
		Player player = Player(i);

		if (player.isValid) {
			int side = player.getTargetSide();
			if (side == SideWithControl()) { player.playSound(vo_defending_et[side]); }
			else { player.playSound(vo_attacking_et[side]); }
		}
	}

	return Plugin_Handled;
}

public Action OnTimeExpired(Handle timer) {
	roundTimeHandle = null;

	if (IsMidRound()) {
		if (isRegulation) {
			isRegulation = false;
			if (cfg_extraTimeOverride.IntValue != 0) { isExtraTime = true; }
		}
		else { isExtraTime = false; }

		if (!EndRoundIfTeamHasControl()) {
			ResetRoundTimer();
			SetRoundTimer(roundTimerValue);
			UpdateRoundPauseState();
			CreateTimer(0.1, OnRoundExtended, roundTimerValue);
		}
	}

	return Plugin_Handled;
}

public void OnSpawn(Event event, const char[] name, bool dontBroadcast) {
	Player player = Player(GetClientOfUserId(event.GetInt("userid")));
	if (player.isValid) { player.onSpawn(); }
}

public void OnDeath(Event event, const char[] name, bool dontBroadcast) {
	Player player = Player(GetClientOfUserId(event.GetInt("userid")));
	if (player.isValid && player.isAlive) { player.onDeath(); }
}

public void OnClientDisconnect(int client) {
	Player player = Player(client);
	if (player.isValid && player.isAlive) { player.onDeath(); }
}

public bool IsMatchLive() {
	if (!usingMatchBot) { return true; }
	return matchBot.isLive;
}

public bool CanChangeMode() {
	if (!usingMatchBot) { return true; }
	return matchBot.isWarmup;
}
