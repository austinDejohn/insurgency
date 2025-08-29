
static Team voteTeamCache[MAXPLAYERS];

public void createVoteCmds() {
    VoteCmd(
        "forfeit",
        onVoteForfeit,
        onVoteForfeitSuccess,
        _,
        "Starts a team vote to forfeit the match (must be unanimous)",
        "forfeit",
        true,
        1.0,
        true
    )
    .alias("ff");

    VoteCmd(
        "map",
        onVoteMap,
        onVoteMapSuccess,
        "<name>",
        "Starts a vote to switch the server to the specified map (warmup only)",
        "change the map to",
        false,
        0.51,
        true
    );

    VoteCmd(
        "teamname",
        onVoteTeamName,
        onVoteTeamNameSuccess,
        "<name>",
        "Starts a vote to set the caller's teamname",
        "change the team name to",
        true,
        0.51,
        true
    );
}

////////////////////////////////////////////////////////////////

public bool onVoteForfeit(int client, VoteCmd cmd, char[] args, int argsLength) {
    Player player = Player(client);
    Team team = match.getTeam(player);

    if (team.isValid) {
        if (!server.isPreGame && !match.isFinished) {
            voteTeamCache[client] = team;
            return true;
        }

        player.chat("The match must be in-progress to start a forfeit vote");
    }
    else {
        player.chat("You must be on a team to start a forfeit vote");
    }

    return false;
}

public void onVoteForfeitSuccess(int client, VoteCmd cmd, const char[] args) {
    match.onForfeit(voteTeamCache[client], "vote");
}

public bool onVoteMap(int client, VoteCmd cmd, char[] args, int argsLength) {
    Player player = Player(client);

    if (strlen(args) > 0) {
        if (server.isPreGame || match.isFinished) {
            if (IsMapValid(args)) { return true; }
            player.chat("%s is not a valid map", args);
        }
        else {
            player.chat("You may only change the map during warm up");
        }
    }
    else {
        player.chat("You must provide the name of the map you'd like to change the server to");
    }

    return false;
}

public void onVoteMapSuccess(int client, VoteCmd cmd, const char[] args) {
    server.setMap(args);
}

public bool onVoteTeamName(int client, VoteCmd cmd, char[] args, int argsLength) {
    Player player = Player(client);
    Team team = match.getTeam(player);

    if (team.isValid) {
        if (strlen(args) > 0) {
            voteTeamCache[client] = team;
            return true;
        }
        else {
            char name[ML_NAME];
            team.getName(name, ML_NAME);
            player.chat("Your team name is %s, to change it, type .teamname <name>", name);
        }
    }

    return false;
}

public void onVoteTeamNameSuccess(int client, VoteCmd cmd, const char[] args) {
    Team team = voteTeamCache[client];

    char oldName[ML_NAME];
    team.getName(oldName, ML_NAME);

    team.setName(args);

    server.chatFromSource(
        team.getChatSource(),
        "\x03%s\x01 has changed its name to \x03%s\x01",
        oldName,
        args
    );
}