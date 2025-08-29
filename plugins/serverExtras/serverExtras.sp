#include <sourcemod>
#include <sdktools>
#include <chatCmds>

#pragma newdecls required
#pragma semicolon 1

////////////////////////////////////////////////////////////////

#define PLUGIN_NAME "ServerExtras"
#define PLUGIN_AUTHOR "Outlawled"
#define PLUGIN_VERSION "1.0.0"

#define ML_PATH PLATFORM_MAX_PATH
#define ML_CMD 32
#define ML_PLUGIN 64
#define ML_DESC 256
#define ML_MSG 128
#define ML_ACTION 64
#define ML_WEAPON 64

#define FOG_NONE 0
#define FOG_DEFAULT 1
#define FOG_THICC 2
#define FOG_COLOR 9868950

#define SEC 2
#define INS 3

////////////////////////////////////////////////////////////////

ConVar cv_muteAmbient;
ConVar cv_fogLevel;
ConVar cv_deleteProps;
ConVar cv_execOnce;

bool isAmbientBlocked;
bool isFirstMapLoad = true;

////////////////////////////////////////////////////////////////

#include "src/conVars.sp"
#include "src/whisper.sp"
#include "src/chatCmds.sp"
#include "src/theaterParser.sp"

////////////////////////////////////////////////////////////////

public Plugin myinfo = {
    name = PLUGIN_NAME,
    author = PLUGIN_AUTHOR,
    description = "Miscellaneous server utilities",
    version = PLUGIN_VERSION,
    url = "https://github.com/austinDejohn/insurgency"
};

public void OnPluginStart() {
    initializeConVars();
    theaterParser.initialize();

    HookEvent("round_start", onPreRound, EventHookMode_PostNoCopy);
    HookEvent("player_team", onJoinTeam, EventHookMode_Post);
}

public void OnLibraryAdded(const char[] name) {
    if (StrEqual(name, LIB_CHAT_CMDS)) {
        createChatCmds();
    }
}

public void OnConfigsExecuted() {
    if (isFirstMapLoad) {
        cv_execOnce.RemoveChangeHook(execOnceHook);
        isFirstMapLoad = false;
    }

    initializeFog();
    theaterParser.run();

    deleteProps();
}

public void onPreRound(Event event, const char[] name, bool dontBroadcast) {
    if (cv_deleteProps.BoolValue) {
        deleteProps();
    }
}

public void onJoinTeam(Event event, const char[] name, bool dontBroadcast) {
    int client = GetClientOfUserId(event.GetInt("userid"));

    if (!IsFakeClient(client)) {
        if (cv_fogLevel.IntValue == FOG_THICC) {
            SetEntProp(client, Prop_Send, "m_skybox3d.fog.colorPrimary", FOG_COLOR);
            SetEntProp(client, Prop_Send, "m_skybox3d.fog.colorSecondary", FOG_COLOR);
            SetEntPropFloat(client, Prop_Send, "m_skybox3d.fog.start", 0.0);
            SetEntPropFloat(client, Prop_Send, "m_skybox3d.fog.end", 100.0);
        }
		else if (cv_fogLevel.IntValue == FOG_NONE) {
            SetEntPropFloat(client, Prop_Send, "m_skybox3d.fog.start", 15000.0);
            SetEntPropFloat(client, Prop_Send, "m_skybox3d.fog.end", 20000.0);
        }
	}
}

public void reloadMap() {
    char map[48];
    GetCurrentMap(map, 48);
    ServerCommand("map %s firefight", map);
}