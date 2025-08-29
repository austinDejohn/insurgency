
static ChatCmd cmd_yes;

public void initializeCmds() {
    ChatCmd("help", onCmdHelp, _, "Prints all available commands and their descriptions")
        .alias("h");

    ChatCmd("plugins", onCmdPlugins, _, "Prints info about all currently running SourceMod plugins");

    ChatCmd("aliases", onCmdAlias, "<command>", "Prints the specified command's aliases");

    cmd_yes = ChatCmd("yes", onCmdVote, _, "Records YEA on the current vote", CmdAccess_Player, false)
        .alias("yea")
        .alias("y");

    ChatCmd("no", onCmdVote, _, "Records NAY on the current vote", CmdAccess_Player, false)
        .alias("nay")
        .alias("n");
}

public void onCmdHelp(int client, ChatCmd cmd, const char[] args) {
    PrintToChat(client, "Check your console for output");

    PrintToConsole(client, "----------------------------------------------------------------");
    PrintToConsole(client, "%s v%s", PLUGIN_NAME, PLUGIN_VERSION);
    PrintToConsole(client, " ");

    char desc[ML_DESC];

    for (int i = 0; i < l_help_text.Length; i++) {
        if (l_help_text.GetString(i, desc, ML_DESC) > 0) { PrintToConsole(client, desc); }
    }

    PrintToConsole(client, "----------------------------------------------------------------");
}

public void onCmdPlugins(int client, ChatCmd cmd, const char[] args) {
    PrintToChat(client, "Check your console for output");

    PrintToConsole(client, "----------------------------------------------------------------");

    Handle iter = GetPluginIterator();

    while (MorePlugins(iter)) {
        Handle plugin = ReadPlugin(iter);
        if (GetPluginStatus(plugin) == Plugin_Running) { printPluginInfo(client, plugin); }
        CloseHandle(plugin);
    }

    PrintToConsole(client, "----------------------------------------------------------------");
}

public void onCmdAlias(int client, ChatCmd cmd, const char[] args) {
    if (strlen(args) > 0) {
        char cmdName[ML_CMD], aliases[ML_DESC];
        int index;

        strcopy(cmdName, ML_CMD, args);
        stringToLower(cmdName);

        if (m_index.GetValue(cmdName, index)) {
            l_aliases.GetString(index, aliases, ML_DESC);
            PrintToChat(client, "Aliases: %s", aliases);
        }
        else { PrintToChat(client, "Unable to find a command by that name"); }
    }
    else { PrintToChat(client, "You must specify the command you want to view the aliases of"); }
}

public void onCmdVote(int client, ChatCmd cmd, const char[] args) {
    Vote vote = voteManager.getClientVote(client);

    if (vote.isValid) {
        if (!vote.alreadyVoted(client)) {
            if (cmd == cmd_yes) {
                fakeMsg(client, ".yes (%i/%i)", vote.yeas + 1, vote.quorum);
            }
            else {
                fakeMsg(client, ".no (%i/%i)", vote.yeas, vote.quorum);
            }

            vote.cast(client, cmd == cmd_yes);
        }
        else {
            PrintToChat(client, "You've already cast a vote");
        }
    }
    else {
        PrintToChat(client, "You are not currently part of a vote");
    }
}

////////////////////////////////////////////////////////////////

static void printPluginInfo(int client, Handle plugin) {
    char name[ML_PLUGIN], author[ML_PLUGIN], desc[ML_DESC], version[32], url[PLATFORM_MAX_PATH];

    GetPluginInfo(plugin, PlInfo_Name, name, ML_PLUGIN);
    GetPluginInfo(plugin, PlInfo_Author, author, ML_PLUGIN);
    GetPluginInfo(plugin, PlInfo_Description, desc, ML_DESC);
    GetPluginInfo(plugin, PlInfo_Version, version, 32);
    GetPluginInfo(plugin, PlInfo_URL, url, PLATFORM_MAX_PATH);

    if (strlen(name) == 0) { GetPluginFilename(plugin, name, ML_PLUGIN); }

    PrintToConsole(client, "%s: {", name);
    if (strlen(author) > 0) { PrintToConsole(client, "    Author: %s", author); }
    if (strlen(desc) > 0) { PrintToConsole(client, "    Description: %s", desc); }
    if (strlen(version) > 0) { PrintToConsole(client, "    Version: %s", version); }
    if (strlen(url) > 0) { PrintToConsole(client, "    URL: %s", url); }
    PrintToConsole(client, "}");
}