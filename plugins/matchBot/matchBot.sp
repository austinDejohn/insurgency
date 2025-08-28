
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <chatCmds>
#include <matchBot>

#pragma newdecls required
#pragma semicolon 1

////////////////////////////////////////////////////////////////

#include "include/constants.sp"
#include "include/objects/server/config.sp"
#include "include/objects/server/server.sp"
#include "include/objects/match/player.sp"
#include "include/objects/match/team.sp"
#include "include/objects/server/objective.sp"
#include "include/objects/server/timeline.sp"
#include "include/objects/match/match.sp"
#include "include/objects/server/damageLog.sp"
#include "include/cmds/chatCmds.sp"
#include "include/cmds/voteCmds.sp"
#include "include/util.sp"
#include "include/natives.sp"

////////////////////////////////////////////////////////////////

public Plugin myinfo = {
    name = PLUGIN_NAME,
    author = PLUGIN_AUTHOR,
    description = "Automated match admin for competitive Insurgency",
    version = PLUGIN_VERSION,
    url = "https://esgl.pro/discord"
};


public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
    CreateNative("MatchBot.state.get", native_MatchBot_state_get);
    RegPluginLibrary(LIB_MATCH_BOT);
    return APLRes_Success;
}

public void OnPluginStart() {
    server.onPluginStart();
    config.onPluginStart();

    HookUserMessage(GetUserMessageId("SayText2"), onSayText2, true);

    AddCommandListener(onSuicideByConsole, "kill");

    HookEvent("round_start", onPreRound, EventHookMode_PostNoCopy);
    HookEvent("round_freeze_end", onRoundStart, EventHookMode_Pre);
    HookEvent("round_end", onRoundEnd, EventHookMode_Post);

    HookEvent("player_spawn", onSpawn, EventHookMode_Post);
    HookEvent("player_team", onJoinTeam, EventHookMode_Pre);
    HookEvent("player_changename", onChangeName, EventHookMode_Pre);

    HookEvent("player_hurt", onDamage, EventHookMode_Post);
    HookEvent("player_death", onKill, EventHookMode_Post);

    HookEvent("controlpoint_captured", onObjectiveCap, EventHookMode_Post);
    HookEvent("controlpoint_starttouch", onObjectiveEnter, EventHookMode_Post);
    HookEvent("controlpoint_endtouch", onObjectiveExit, EventHookMode_Post);

    HookEvent("weapon_fire", onFire, EventHookMode_Post);
    HookEvent("grenade_thrown", onThrow, EventHookMode_Post);
    HookEvent("missile_launched", onThrow, EventHookMode_Post);
    HookEvent("grenade_detonate", onDetonate, EventHookMode_Post);
}

public void OnLibraryAdded(const char[] name) {
    if (StrEqual(name, LIB_CHAT_CMDS)) {
        createChatCmds();
        createVoteCmds();
    }
}

public void OnConfigsExecuted() {
    server.initialize();
    match.initialize();
    timeline.initialize();
}

public void OnMapStart() { server.isChangingMap = false; }
public void OnMapEnd() { server.isChangingMap = true; }

public void OnClientPostAdminCheck(int client) {
    Player player = Player(client);
    if (player.isValid) { player.initialize(); }

    SDKHook(client, SDKHook_OnTakeDamage, onPreDamage);
}

public void OnClientDisconnect(int client) {
    Player player = Player(client);

    if (player.isValid) {
        Team team = Team(player.side);
        if (team.isValid) { match.onTeamChanged(player, match.invalidTeam, team); }
        if (match.isLive && server.isMidRound && player.isAlive) { timeline.onDespawn(player); }
    }

    if (!server.isChangingMap && !server.isPreGame && match.alpha.size == 0 && match.bravo.size == 0) {
        server.reloadMap();
    }

    SDKUnhook(client, SDKHook_OnTakeDamage, onPreDamage);
}

public Action OnClientSayCommand(int client, const char[] command, const char[] sArgs) {
    Player player = Player(client);

    if (player.isValid) {
        if (!player.isAlive && sArgs[0] != '.' && StrEqual(command, "say", false)) {
            player.say(sArgs);
            return Plugin_Stop;
        }
    }

    return Plugin_Continue;
}

////////////////////////////////////////////////////////////////

public void onPreRound(Event event, const char[] name, bool dontBroadcast) {
    if (match.isLive) {
        match.onPreRound();
    }
    else if (match.isLor) {
        if (match.isWarmup) {
            for (int i = 1; i <= MaxClients; i++) {
                SDKUnhook(i, SDKHook_OnTakeDamage, onPreDamage);
            }
        }

        match.live();
        match.onPreRound();
    }
}

public Action onRoundStart(Event event, const char[] name, bool dontBroadcast) {
    if (match.isLive) {
        match.onRoundStart();
    }
    else {
        if (match.isPaused) {
            match.onRoundStartPause();
        }

        return Plugin_Handled;
    }

    return Plugin_Continue;
}

public void onRoundEnd(Event event, const char[] name, bool dontBroadcast) {
    server.setPostRound();
    Team roundWinner = Team(event.GetInt("winner"));

    if (match.isLive) { match.onRoundEnd(roundWinner); }
}

////////////////////////////////////////////////////////////////

public void onSpawn(Event event, const char[] name, bool dontBroadcast) {
    RequestFrame(onSpawnPost, Player(GetClientOfUserId(event.GetInt("userid"))));
}

public void onSpawnPost(Player player) {
    if (match.isLive) {
        player.onSpawn();

        if (server.isMidRound) { timeline.onSpawn(player); }
        else if (server.isPreRound) { match.displayRoundCount(player); }
    }
}

public Action onJoinTeam(Event event, const char[] name, bool dontBroadcast) {
    if (server.isSwitchingSides) { return Plugin_Handled; }
    Player player = Player(GetClientOfUserId(event.GetInt("userid")));

    if (player.isValid) { match.onTeamChanged(player, Team(event.GetInt("team")), Team(event.GetInt("oldteam"))); }
    return Plugin_Continue;
}

public Action onSuicideByConsole(int client, const char[] command, int argc) {
    return server.isPreGame ? Plugin_Continue : Plugin_Handled;
}

////////////////////////////////////////////////////////////////

public Action onPreDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype) {
    if (match.isWarmup) {
        Player pVictim = Player(victim);
        Player pAttacker = Player(attacker);
        int dmg = damage >= 1.0 ? RoundToFloor(damage) : 1;

        if (pVictim.isValid) {
            pAttacker = pAttacker.isValid ? pAttacker : pVictim;

            if (damagetype == DMG_FALL) {
                damageLog.onFallDamageWarmup(pVictim, dmg);
            }
            else {
                damageLog.onDamageWarmup(pAttacker, pVictim, dmg);
            }

            if (pVictim.isGod || pAttacker.isGod || pAttacker.isNoclip) {
                return Plugin_Handled;
            }
        }
    }

    return Plugin_Continue;
}

public void onDamage(Event event, const char[] name, bool dontBroadcast) {
    Player victim = Player(GetClientOfUserId(event.GetInt("userid")));
    Player attacker = Player(GetClientOfUserId(event.GetInt("attacker")));
    int damage = event.GetInt("dmg_health");

    if (match.isLive) {
        if (victim.isValid) {
            attacker = attacker.isValid ? attacker : victim;

            timeline.onDamage(attacker, victim, damage);
            damageLog.onDamage(attacker, victim, damage);

            if (event.GetInt("health") <= 0) {
                char weapon[ML_NAME];
                event.GetString("weapon", weapon, ML_NAME);

                if (victim == attacker && strlen(weapon) == 0) {
                    timeline.onKill(attacker, victim, "gravity", 0);
                }
                else {
                    timeline.onKill(attacker, victim, weapon, event.GetInt("hitgroup"));
                }

                damageLog.onKill(attacker, victim);
            }
        }
    }
}

public void onKill(Event event, const char[] name, bool dontBroadcast) {
    if (match.isLive) {
        Player victim = Player(GetClientOfUserId(event.GetInt("userid")));

        if (victim.isValid) {
            if (event.GetBool("customkill")) {
                timeline.onKill(victim, victim, "console", 0);
                damageLog.onKill(victim, victim);
            }
        }
    }
}

public void onObjectiveCap(Event event, const char[] name, bool dontBroadcast) {
    if (match.isLive) {
        Team team = Team(event.GetInt("team"));

        if (team.isValid) {
            timeline.onObjectiveCap(team, view_as<Objective>(event.GetInt("cp")));
        }
    }
}

public void onObjectiveEnter(Event event, const char[] name, bool dontBroadcast) {
    if (match.isLive) {
        Player player = Player(event.GetInt("player"));
        Objective obj = view_as<Objective>(event.GetInt("area"));

        if (player.isValid && !obj.isLocked(player.side)) { timeline.onObjectiveEnter(player, obj); }
    }
}

public void onObjectiveExit(Event event, const char[] name, bool dontBroadcast) {
    if (match.isLive) {
        Player player = Player(event.GetInt("player"));
        Objective obj = view_as<Objective>(event.GetInt("area"));

        if (player.isValid && !obj.isLocked(player.side)) { timeline.onObjectiveExit(player, obj); }
    }
}

public void onFire(Event event, const char[] name, bool dontBroadcast) {
    if (match.isLive) {
        Player player = Player(GetClientOfUserId(event.GetInt("userid")));
        if (player.isValid) { player.shotsFired++; }
    }
}

public void onThrow(Event event, const char[] name, bool dontBroadcast) {
    if (match.isLive) {
        Player player = Player(GetClientOfUserId(event.GetInt("userid")));
        if (player.isValid) { timeline.onThrow(player, event.GetInt("entityid")); }
    }
}

public void onDetonate(Event event, const char[] name, bool dontBroadcast) {
    if (match.isLive) {
        Player player = Player(GetClientOfUserId(event.GetInt("userid")));
        if (player.isValid) { timeline.onDetonate(player, event.GetInt("entityid")); }
    }
}

////////////////////////////////////////////////////////////////

public Action onSayText2(UserMsg msg_id, BfRead bf, const int[] players, int playersNum, bool reliable, bool init) {
    char msg[24];

    bf.ReadShort();
    bf.ReadString(msg, sizeof(msg), true);

    if (StrEqual(msg, "#ins_name_change_limit", true)) { return Plugin_Handled; }
    return Plugin_Continue;
}

public Action onChangeName(Event event, const char[] name, bool dontBroadcast) {
    Player player = Player(GetClientOfUserId(event.GetInt("userid")));
    if (player.isValid && !player.allowNameChange) { RequestFrame(resetPlayerName, player); }
    return Plugin_Handled;
}

public void resetPlayerName(Player player) {
    player.resetName();
}