
public void createChatCmds() {
    VoteCmd(
        "mode",
        onVoteMode,
        onVoteModeSuccess,
        "<name>",
        "Starts a vote to switch the server to the specified custom firefight mode (or 'firefight' for standard)",
        "change the mode to",
        false,
        0.51,
        true
    );
}

public bool onVoteMode(int client, VoteCmd cmd, char[] args, int argsLength) {
    if (strlen(args) > 0) {
        if (CanChangeMode()) {
            if (IsModeSupported(args)) { return true; }
            PrintToChat(client, "%s is not a valid Custom Firefight mode", args);
        }
        else {
            PrintToChat(client, "You may only change the mode during warm up");
        }
    }
    else {
        PrintToChat(client, "You must provide the name of the mode you'd like to change the server to");
    }

    return false;
}

public void onVoteModeSuccess(int client, VoteCmd cmd, const char[] args) {
    cfg_name.SetString(args);

}
