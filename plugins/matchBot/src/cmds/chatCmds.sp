static ChatCmd _cmdReady;

public void createChatCmds() {
    ChatCmd("config", onCmdConfig, _, "Prints the current MatchBot config settings to console");

    ChatCmd("start", onCmdStart, _, "Allows the player's team to start shorthanded", CmdAccess_Player);

    _cmdReady = ChatCmd("ready", onCmdReady, _, "Marks the player as ready", CmdAccess_Player, false)
        .alias("r");

    ChatCmd("notready", onCmdReady, _, "Marks the player as not ready", CmdAccess_Player, false)
        .alias("nr");

    ChatCmd("timeout", onCmdTimeout, _, "Calls a timeout if available", CmdAccess_Player, false)
        .alias("pause");

    ChatCmd("draw", onCmdDraw, _, "Ends the match in a draw (can only be used before an optional OT period)", CmdAccess_Player, false)
        .alias("tie");

    ChatCmd("impacts", onCmdImpacts, _, "Toggles the sv_impacts server command (warmup only)", CmdAccess_Player);
    ChatCmd("noclip", onCmdNoclip, _, "Toggles the player's noclip state (warmup only)", CmdAccess_Player);
    ChatCmd("god", onCmdGod, _, "Toggles the player's godmode state (warmup only)", CmdAccess_Player);

    SecretCmd("shrug", onCmdShrug);
}

////////////////////////////////////////////////////////////////

public void onCmdShrug(int client, ChatCmd cmd, const char[] args) { Player(client).say("¯\\_(ツ)_/¯"); }

////////////////////////////////////////////////////////////////

public void onCmdConfig(int client, ChatCmd cmd, const char[] args) {
    PrintToChat(client, "Check your console for output");

    PrintToConsole(client, "----------------------------------------------------------------");
    PrintToConsole(client, "%s v%s", PLUGIN_NAME, PLUGIN_VERSION);
    PrintToConsole(client, " ");

    config.print(client);

    PrintToConsole(client, "----------------------------------------------------------------");
}

public void onCmdStart(int client, ChatCmd cmd, const char[] args) {
    Player player = Player(client);

    if (server.isPreGame) {
        Team team = match.getTeam(player);

        if (team.isValid) {
            if (!team.hasJoined) {
                if (team.hasMinPlayers()) {
                    team.hasJoined = true;

                    if (team.other.hasJoined) { match.wait(); }
                    else {
                        char teamName[ML_TEAM];
                        team.getName(teamName, ML_TEAM);
                        server.chat("%s want to start the match shorthanded", teamName);
                    }
                }
                else {
                    player.chat("Your team must have at least %i players to start the match", config.minTeamSize);
                }
            }
            else if (team.other.hasJoined) {
                player.chat("The match will start once both teams ready up");
            }
            else {
                player.chat("Waiting for the other team to join...");
            }
        }
    }
    else { player.chat("The match has already started"); }
}

public void onCmdTimeout(int client, ChatCmd cmd, const char[] args) {
    Player player = Player(client);

    if (match.isLive || match.isPaused) {
        if (server.isPreRound || server.isMidRound && GetGameTime() - server.roundStart <= config.timeoutGrace) {
            Team team = match.getTeam(player);

            if (team.isValid) {
                if (team.timeouts > 0) {
                    if (!match.justCalledTimeout()) {
                        player.say(".timeout");

                        match.onTimeoutCalled(config.timeoutDuration);
                        team.onTimeoutCalled();
                    }
                    else {
                        player.chat("Please wait a moment before trying to call another timeout");
                    }
                }
                else {
                    player.chat("Your team is out of timeouts");
                }
            }
        }
        else if (config.timeoutGrace < 1.0) {
            player.chat("You may only call a timeout during freeze time");
        }
        else {
            player.chat(
                "You may only call a timeout in the first %.0f second%s of a round",
                config.timeoutGrace,
                config.timeoutGrace >= 2.0 ? "s" : ""
            );
        }
    }
    else {
        player.chat("The match must be live for you to call a timeout");
    }
}

public void onCmdDraw(int client, ChatCmd cmd, const char[] args) {
    Player player = Player(client);

    if (match.canDraw) {
        char cmdName[ML_CMD];
        cmd.getName(cmdName, ML_CMD);

        player.say(".%s", cmdName);
        match.forceDraw();
    }
    else {
        player.chat("That command cannot be used right now");
    }
}

public void onCmdReady(int client, ChatCmd cmd, const char[] args) {
    Player player = Player(client);
    Team team = match.getTeam(player);

    if (team.isValid) {
        if (cmd == _cmdReady) {
            if (match.isWaiting()) {
                if (!player.isReady) {
                    if (team.hasMinPlayers()) {
                        player.ready();
                        player.say(".ready");
                        match.refreshReadyDisplay();

                        if (team.isReady() && team.other.isReady()) { match.lor(); }
                    }
                    else {
                        player.chat("Your team must have at least %i players before you can ready up", config.minTeamSize);
                    }
                }
                else {
                    player.chat("You are ready");
                }
            }
            else if (server.isPreGame) {
                if (!team.hasJoined) {
                    if (team.hasMinPlayers()) {
                        player.chat("To ready up while shorthanded, you must first type .start in chat");
                    }
                    else {
                        player.chat("Your team must have at least %i players before you can ready up", config.minTeamSize);
                    }
                }
                else {
                    player.chat("Waiting for the other team to join...");
                }
            }
            else {
                player.chat("The match is not currently waiting for players to ready up");
            }
        }
        else if (match.isWaiting()) {
            if (player.isReady) {
                player.unready();
                player.say(".notready");
                match.refreshReadyDisplay();
            }
            else {
                player.chat("You are not ready");
            }
        }
        else {
            player.chat("The match is not currently waiting for players to ready up");
        }
    }
}

public void onCmdImpacts(int client, ChatCmd cmd, const char[] args) {
    Player player = Player(client);

    if (server.isPreGame) {
        server.impacts = !server.impacts;
        server.chat("Impacts have been %s!", server.impacts ? "enabled" : "disabled");
    }
    else {
        player.chat("That command is only available during warmup");
    }
}

public void onCmdGod(int client, ChatCmd cmd, const char[] args) {
    Player player = Player(client);

    if (server.isPreGame) {
        player.isGod = !player.isGod;
        player.chat("Godmode %s!", player.isGod ? "enabled" : "disabled");
    }
    else {
        player.chat("That command is only available during warmup");
    }
}

public void onCmdNoclip(int client, ChatCmd cmd, const char[] args) {
    Player player = Player(client);

    if (server.isPreGame) {
        player.isNoclip = !player.isNoclip;
    }
    else {
        player.chat("That command is only available during warmup");
    }
}
