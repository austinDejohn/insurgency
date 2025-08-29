
public void createChatCmds() {
    initializeWhisper();

    VoteCmd(
        "fog",
        onVoteFog,
        onVoteFogSuccess,
        "<none | default | thicc>",
        "Starts a vote to set the server's fog level (will cause map restart)",
        "set the fog level to",
        false,
        0.51,
        true
    );
}

static int getFogLevelFromText(const char[] text) {
    if (StrEqual(text, "none", false)) { return 0; }
    if (StrEqual(text, "default", false)) { return 1; }
    if (StrEqual(text, "thicc", false)) { return 2; }
    return -1;
}

public bool onVoteFog(int client, VoteCmd cmd, char[] args, int argsLength) {
    int level = getFogLevelFromText(args);

    if (level != -1) {
        if (level != cv_fogLevel.IntValue) {
            return true;
        }
        else {
            PrintToChat(client, "The server's fog level is already set to %s", args);
        }
    }
    else {
        PrintToChat(client, "You must specify the level of fog: none, default, or thicc");
    }

    return false;
}

public void onVoteFogSuccess(int client, VoteCmd cmd, const char[] args) {
    int level = getFogLevelFromText(args);

    if (level != -1) {
        cv_fogLevel.IntValue = level;
        reloadMap();
    }
}