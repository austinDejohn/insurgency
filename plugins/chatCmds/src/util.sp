
public void stringToLower(char[] str) {
    for (int n = 0; n < strlen(str); n++) { str[n] = CharToLower(str[n]); }
}

public bool isSpectator(int client) {
    return GetClientTeam(client) == 1;
}

public bool isAdmin(int client) {
    return GetUserAdmin(client).HasFlag(Admin_Generic, Access_Effective);
}

public CmdAccess getClientAccess(int client) {
    CmdAccess flags = isSpectator(client) ? CmdAccess_Spectator : CmdAccess_Player;
    if (isAdmin(client)) { flags &= CmdAccess_Admin; }
    return flags;
}

public bool canBypassVote(int client, VoteCmd cmd) {
    if (cmd.quorumRatio <= 0.0) { return true; }

    int team = GetClientTeam(client);

    for (int i = 1; i <= MaxClients; i++) {
        if (i != client && IsClientInGame(i)) {
            int iTeam = GetClientTeam(i);

            if (cmd.isTeamOnly) {
                if (iTeam == team) { return false; }
            }
            else {
                if (iTeam >= SEC) { return false; }
            }
        }
    }

    return true;
}

public ChatCmd getCmd(const char[] name) {
    int index = -1;
    m_index.GetValue(name, index);
    return view_as<ChatCmd>(index);
}

public int getVoteIndex(ChatCmd cmd) {
    return l_voteIndex.Get(cmd.index);
}

public Function getCmdHandler(ChatCmd cmd) {
    DataPack data = view_as<DataPack>(l_handler.Get(cmd.index));
    data.Reset();
    return data.ReadFunction();
}

public Function getVoteValidator(VoteCmd cmd) {
    DataPack data = view_as<DataPack>(l_validator.Get(getVoteIndex(cmd)));
    data.Reset();
    return data.ReadFunction();
}

static int pushCmd(int voteIndex, const char[] name, const char[] pluginName, const char[] params, const char[] desc, DataPack handlerData, CmdAccess access, bool doPrint, bool isEnabled) {
    int id = l_enabled.Length;

    if (m_index.SetValue(name, id, false)) {
        l_voteIndex.Push(voteIndex);
        l_name.PushString(name);
        l_plugin.PushString(pluginName);
        l_access.Push(access);
        l_doPrint.Push(doPrint);
        l_enabled.Push(isEnabled);
        l_aliases.PushString("");
        l_handler.Push(handlerData);

        if (strlen(desc) > 0) {
            char helpStr[ML_DESC];
            Format(helpStr, ML_DESC, ".%s%s%s - %s", name, strlen(params) > 0 ? " " : "", params, desc);
            l_help_text.PushString(helpStr);
        }

        return id;
    }

    return -1;
}

public int pushVoteCmd(const char[] name, const char[] pluginName, const char[] params, const char[] desc, const char[] action, DataPack validatorData, DataPack handlerData, bool isTeamOnly, float quorumRatio, bool isEnabled) {
    int id = pushCmd(l_isTeamOnlyVote.Length, name, pluginName, params, desc, handlerData, CmdAccess_Player, false, isEnabled);

    l_isTeamOnlyVote.Push(isTeamOnly);
    l_quorumRatio.Push(quorumRatio);
    l_validator.Push(validatorData);
    l_actionText.PushString(action);

    return id;
}

public int pushChatCmd(const char[] name, const char[] pluginName, const char[] params, const char[] desc, DataPack handlerData, CmdAccess access, bool doPrint, bool isEnabled) {
    return pushCmd(-1, name, pluginName, params, desc, handlerData, access, doPrint, isEnabled);
}

public void fakeMsg(int client, const char[] msg, any ...) {
    char formattedMsg[ML_MSG];
    VFormat(formattedMsg, ML_MSG, msg, 3);

    BfWrite bf = view_as<BfWrite>(StartMessageAll("SayText2"));

    if (bf != null) {
        int side = GetClientTeam(client);
        char name[MAX_NAME_LENGTH];
        GetClientName(client, name, MAX_NAME_LENGTH);

        bf.WriteShort(client);
        bf.WriteString("INS_Chat_All");
        bf.WriteString(name);
        bf.WriteString(formattedMsg);
        bf.WriteByte(0);

        if (side == SEC) { bf.WriteString("#Team_Security"); }
        else if (side == INS) { bf.WriteString("#Team_Insurgent"); }

        EndMessage();
    }
}