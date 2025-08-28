
#include <sourcemod>
#include <chatCmds>

#pragma newdecls required
#pragma semicolon 1

////////////////////////////////

#define PLUGIN_NAME "ChatCmds"
#define PLUGIN_AUTHOR "Outlawled"
#define PLUGIN_VERSION "2.0.0"

#define CMD_SYMBOL '.'

#define ML_CMD 32
#define ML_PLUGIN 64
#define ML_DESC 256
#define ML_MSG 128
#define ML_ACTION 64

#define SEC 2
#define INS 3

////////////////////////////////

StringMap m_index;
ArrayList l_voteIndex;
ArrayList l_name;
ArrayList l_plugin;
ArrayList l_enabled;
ArrayList l_access;
ArrayList l_doPrint;
ArrayList l_aliases;
ArrayList l_handler;

ArrayList l_isTeamOnlyVote;
ArrayList l_quorumRatio;
ArrayList l_actionText;
ArrayList l_validator;

ArrayList l_help_text;

ConVar cv_enableCmd;
ConVar cv_disableCmd;
ConVar cv_setVoteQuorumRatio;

////////////////////////////////

#include "include/util.sp"
#include "include/vote.sp"
#include "include/cmds.sp"
#include "include/chatNatives.sp"
#include "include/voteNatives.sp"

////////////////////////////////

public Plugin myinfo = {
    name = PLUGIN_NAME,
    author = PLUGIN_AUTHOR,
    description = "Adds natives for creating and managing chat commands and votes",
    version = PLUGIN_VERSION,
    url = "https://esgl.pro/discord"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
    CreateNative("ChatCmd.ChatCmd", native_ChatCmd);
    CreateNative("ChatCmd.alias", native_ChatCmd_alias);
    CreateNative("ChatCmd.isValid.get", native_ChatCmd_isValid_get);
    CreateNative("ChatCmd.isVote.get", native_ChatCmd_isVote_get);
    CreateNative("ChatCmd.access.get", native_ChatCmd_access_get);
    CreateNative("ChatCmd.doPrint.get", native_ChatCmd_doPrint_get);
    CreateNative("ChatCmd.isEnabled.get", native_ChatCmd_isEnabled_get);
    CreateNative("ChatCmd.isEnabled.set", native_ChatCmd_isEnabled_set);
    CreateNative("ChatCmd.getName", native_ChatCmd_getName);
    CreateNative("ChatCmd.getPlugin", native_ChatCmd_getPlugin);
    CreateNative("ChatCmd.exec", native_ChatCmd_exec);

    CreateNative("VoteCmd.VoteCmd", native_VoteCmd);
    CreateNative("VoteCmd.alias", native_VoteCmd_alias);
    CreateNative("VoteCmd.isTeamOnly.get", native_VoteCmd_isTeamOnly_get);
    CreateNative("VoteCmd.quorumRatio.get", native_VoteCmd_quorumRatio_get);
    CreateNative("VoteCmd.quorumRatio.set", native_VoteCmd_quorumRatio_set);
    CreateNative("VoteCmd.getActionText", native_VoteCmd_getActionText);
    CreateNative("VoteCmd.validate", native_VoteCmd_validate);

    m_index = new StringMap();
    l_voteIndex = new ArrayList();
    l_name = new ArrayList(ML_CMD);
    l_plugin = new ArrayList(ML_PLUGIN);
    l_enabled = new ArrayList();
    l_access = new ArrayList();
    l_doPrint = new ArrayList();
    l_aliases = new ArrayList(ML_DESC);
    l_handler = new ArrayList();

    l_isTeamOnlyVote = new ArrayList();
    l_quorumRatio = new ArrayList();
    l_actionText = new ArrayList(ML_ACTION);
    l_validator = new ArrayList();

    l_help_text = new ArrayList(ML_DESC);

    return APLRes_Success;
}

public void OnPluginStart() {
    initializeCmds();
    RegPluginLibrary(LIB_CHAT_CMDS);

    cv_enableCmd = CreateConVar("cc_enable_cmd", "", "Enables the specified chat command");
    cv_disableCmd = CreateConVar("cc_disable_cmd", "", "Enables the specified chat command");

    cv_setVoteQuorumRatio = CreateConVar(
        "cc_set_vote_quorum",
        "",
        "Sets the specified VoteCmd's quorum ratio to the specified value (0.0 - 1.0)"
    );

    cv_enableCmd.AddChangeHook(enableCmdHook);
    cv_disableCmd.AddChangeHook(disableCmdHook);
    cv_setVoteQuorumRatio.AddChangeHook(setVoteQuorumHook);

    HookEvent("player_team", onJoinTeam);
}

public void OnConfigsExecuted() {
    voteManager.initialize();
}

////////////////////////////////////////////////////////////////

public Action OnClientSayCommand(int client, const char[] command, const char[] sArgs) {
    if (sArgs[0] != CMD_SYMBOL) { return Plugin_Continue; }

    char msg[2][ML_MSG];
    ExplodeString(sArgs[1], " ", msg, 2, ML_MSG, true);
    TrimString(msg[1]);
    stringToLower(msg[0]);

    ChatCmd cmd = getCmd(msg[0]);

    if (cmd.isValid) {
        if (cmd.access & getClientAccess(client)) {
            if (cmd.isEnabled) {
                DataPack data = new DataPack();

                data.WriteCell(cmd);
                data.WriteCell(client);
                data.WriteString(msg[1]);

                RequestFrame(onClientSayPost, data);
                LogToGame("[%s v%s] - %L - %s", PLUGIN_NAME, PLUGIN_VERSION, client, sArgs);

                if (cmd.doPrint) {
                    return Plugin_Continue;
                }
            }
            else {
                PrintToChat(client, "That command has been disabled by the server");
            }
        }
        else {
            PrintToChat(client, "You do not have access to that command");
        }
    }
    else {
        PrintToChat(client, "\"%s\" is not a valid command", msg[0]);
    }

    return Plugin_Handled;
}

public void onClientSayPost(DataPack data) {
    data.Reset();

    char args[ML_MSG];
    ChatCmd cmd = view_as<ChatCmd>(data.ReadCell());

    int client = data.ReadCell();
    data.ReadString(args, ML_MSG);

    delete data;

    if (cmd.isVote) {
        VoteCmd voteCmd = view_as<VoteCmd>(cmd);

        if (voteManager.canStartVote(client, voteCmd)) {
            if (voteCmd.validate(client, args, ML_MSG)) {
                if (canBypassVote(client, voteCmd)) {
                    cmd.exec(client, args);
                }
                else {
                    Vote vote = voteManager.start(client, voteCmd, args);

                    char cmdName[ML_CMD];
                    voteCmd.getName(cmdName, ML_CMD);

                    fakeMsg(client, ".%s%s%s (1/%i)", cmdName, strlen(args) > 0 ? " " : "", args, vote.quorum);
                }
            }
        }
        else {
            PrintToChat(client, "You must wait for the current vote to finish");
        }
    }
    else {
        cmd.exec(client, args);
    }
}

public void onJoinTeam(Event event, const char[] name, bool dontBroadcast) {
    voteManager.onTeamJoin(GetClientOfUserId(event.GetInt("userid")), event.GetInt("team"));
}

public void enableCmdHook(ConVar convar, const char[] oldValue, const char[] newValue) {
    ChatCmd cmd = getCmd(newValue);
    if (cmd.isValid) { cmd.isEnabled = true; }
}

public void disableCmdHook(ConVar convar, const char[] oldValue, const char[] newValue) {
    ChatCmd cmd = getCmd(newValue);
    if (cmd.isValid) { cmd.isEnabled = false; }
}

public void setVoteQuorumHook(ConVar convar, const char[] oldValue, const char[] newValue) {
    char msg[2][32];
    ExplodeString(newValue, " ", msg, 2, 32, true);

    ChatCmd cmd = getCmd(msg[0]);
    float ratio = StringToFloat(msg[1]);

    if (cmd.isValid && cmd.isVote) {
        view_as<VoteCmd>(cmd).quorumRatio = ratio;
    }
}