
static bool _voters[2][MAXPLAYERS + 1];
static int _votes[2][MAXPLAYERS + 1];
static int _maxVotes[2];
static int _yeas[2];
static int _nays[2];
static Handle _timer[2];
static Handle _reminder[2];
static int _caller[2];
static VoteCmd _cmd[2];
static char _args[2][ML_MSG];
static int _quorum[2];

enum VoteManager { voteManager, };

enum Vote {
    vote_invalid = -1,
    vote_a = 0,
    vote_b = 1
}

methodmap Vote {
    property int index {
        public get() { return view_as<int>(this); }
    }

    property bool isValid {
        public get() { return (this.index != -1); }
    }

    property VoteCmd cmd {
        public get() { return _cmd[this.index]; }
    }

    property bool isActive {
        public get() { return this.cmd.isValid; }
    }

    property bool isTeamOnly {
        public get() { return this.cmd.isTeamOnly; }
    }

    property int quorum {
        public get() { return _quorum[this.index]; }
    }

    property int caller {
        public get() { return _caller[this.index]; }
    }

    property int team {
        public get() {
            if (this.caller > 0 && IsClientInGame(this.caller)) {
                return GetClientTeam(this.caller);
            }

            return -1;
        }
    }

    property int maxVotes {
        public get() { return _maxVotes[this.index]; }
    }

    property int yeas {
        public get() { return _yeas[this.index]; }
    }

    property int nays {
        public get() { return _nays[this.index]; }
    }

    public bool contains(int client) {
        return _voters[this.index][client];
    }

    public int get(int client) {
        return _votes[this.index][client];
    }

    public bool alreadyVoted(int client) {
        return this.get(client) != -1;
    }

    public void getArgs(char[] buffer, int maxLength) {
        strcopy(buffer, maxLength, _args[this.index]);
    }

    public void getFullActionText(char[] buffer, int maxLength) {
        char action[ML_ACTION], args[ML_MSG];
        this.cmd.getActionText(action, ML_ACTION);
        this.getArgs(args, ML_MSG);

        Format(buffer, maxLength, "%s%s%s", action, strlen(args) > 0 ? " " : "", args);
    }

    public void announce() {
        char msg[ML_MSG], action[ML_MSG];
        this.getFullActionText(action, ML_MSG);

        Format(msg, ML_MSG, "%N has started a vote to %s", this.caller, action);

        for (int i = 1; i <= MaxClients; i++) {
            if (IsClientInGame(i) && this.contains(i)) {
                if (this.caller == i) {
                    PrintToChat(i, msg);
                }
                else {
                    PrintToChat(i, "%s, type .yes or .no", msg);
                }
            }
        }
    }

    public void remind() {
        char msg[ML_MSG], action[ML_MSG];
        this.getFullActionText(action, ML_MSG);

        Format(msg, ML_MSG, "%s is voting to %s", this.isTeamOnly ? "Your team" : "The server", action);

        for (int i = 1; i <= MaxClients; i++) {
            if (IsClientInGame(i) && this.contains(i)) {
                if (this.alreadyVoted(i)) {
                    PrintToChat(i, "%s (%i/%i)", msg, this.yeas, this.quorum);
                }
                else {
                    PrintToChat(i, "%s, type .yes or .no", msg);
                }
            }
        }
    }

    public void fail(const char[] reason) {
        stopTimers(this);

        char action[ML_MSG];
        this.getFullActionText(action, ML_MSG);

        for (int i = 1; i <= MaxClients; i++) {
            if (IsClientInGame(i) && this.contains(i)) {
                PrintToChat(i, "The vote to %s %s", action, reason);
            }
        }

        reset(this);
    }

    public void succeed() {
        char args[ML_MSG];
        this.getArgs(args, ML_MSG);

        this.cmd.exec(this.caller, args);
        reset(this);
    }

    public void cancel() {
        this.fail("was canceled!");
    }

    public void cast(int client, bool isYea) {
        if (isYea) {
            _yeas[this.index]++;
            _votes[this.index][client] = 1;
        }
        else {
            _nays[this.index]++;
            _votes[this.index][client] = 0;
        }

        if (this.yeas == this.quorum) { this.succeed(); }
        else if (this.nays == this.maxVotes - this.quorum + 1) { this.fail("failed!"); }
    }
}

methodmap VoteManager {
    public bool canStartVote(int client, VoteCmd cmd) {
        if ((vote_a.isActive && !vote_a.isTeamOnly) || (vote_b.isActive && !vote_b.isTeamOnly)) {
            return false;
        }

        if (cmd.isTeamOnly) {
            return !vote_a.contains(client) && !vote_b.contains(client);
        }

        return !vote_a.isActive && !vote_b.isActive;
    }

    public Vote start(int client, VoteCmd cmd, const char[] args) {
        Vote vote = nextVote();

        if (vote.isValid) {
            init(vote, client, cmd, args);
            startTimers(vote);
            RequestFrame(onVoteStartPost, vote);
        }

        return vote;
    }

    public Vote getClientVote(int client) {
        if (client < 1 || !IsClientInGame(client)) { return vote_invalid; }
        if (vote_a.contains(client)) { return vote_a; }
        if (vote_b.contains(client)) { return vote_b; }
        return vote_invalid;
    }

    public Vote getTeamVote(int team) {
        if (team < SEC || team > INS) { return vote_invalid; }
        if (vote_a.team == team) { return vote_a; }
        if (vote_b.team == team) { return vote_b; }
        return vote_invalid;
    }

    public void onTeamJoin(int client, int team) {
        Vote vote = this.getClientVote(client);
        if (vote.isValid) { vote.cancel(); }

        vote = this.getTeamVote(team);
        if (vote.isValid) { vote.cancel(); }
    }

    public void initialize() {
        reset(vote_a);
        reset(vote_b);
    }
}

////////////////////////////////////////////////////////////////

static Vote nextVote() {
    if (!vote_a.isActive) { return vote_a; }
    if (!vote_b.isActive) { return vote_b; }
    return vote_invalid;
}

static bool isEligibleToVote(int client, int voteTeam) {
    if (!IsClientInGame(client)) { return false; }

    int clientTeam = GetClientTeam(client);
    if (voteTeam != -1) { return voteTeam == clientTeam; }
    return clientTeam > 1;
}

static void init(Vote vote, int client, VoteCmd cmd, const char[] args) {
    int teamIndex = cmd.isTeamOnly ? GetClientTeam(client) : -1;
    int maxVotes = 0;

    for (int i = 1; i <= MaxClients; i++) {
        if (isEligibleToVote(i, teamIndex)) {
            _voters[vote.index][i] = true;
            _votes[vote.index][i] = i == client ? 1 : -1;
            maxVotes++;
        }
        else {
            _voters[vote.index][i] = false;
            _votes[vote.index][i] = -1;
        }
    }

    _maxVotes[vote.index] = maxVotes;
    _yeas[vote.index] = 1;
    _nays[vote.index] = 0;
    _caller[vote.index] = client;
    _cmd[vote.index] = cmd;

    strcopy(_args[vote.index], ML_MSG, args);

    int quorum = RoundToCeil(maxVotes * cmd.quorumRatio);

    if (quorum == maxVotes && cmd.quorumRatio < 1.0) { quorum = maxVotes - 1; }
    _quorum[vote.index] = quorum < 2 ? 2 : quorum;
}

static void reset(Vote vote) {
    for (int i = 1; i <= MaxClients; i++) {
        _voters[vote.index][i] = false;
        _votes[vote.index][i] = -1;
    }

    _caller[vote.index] = -1;
    _cmd[vote.index] = view_as<VoteCmd>(-1);

    stopTimers(vote);
}

static void stopTimers(Vote vote) {
    if (_timer[vote.index] != null) { delete _timer[vote.index]; }
    if (_reminder[vote.index] != null) { delete _reminder[vote.index]; }
}

static void startTimers(Vote vote) {
    stopTimers(vote);
    _timer[vote.index] = CreateTimer(60.0, onVoteTimerExpired, vote);
    _reminder[vote.index] = CreateTimer(17.0, onVoteReminder, vote, TIMER_FLAG_NO_MAPCHANGE | TIMER_REPEAT);
}

static Action onVoteTimerExpired(Handle timer, Vote vote) {
    _timer[vote.index] = null;
    vote.fail("expired!");
    return Plugin_Stop;
}

static Action onVoteReminder(Handle Timer, Vote vote) {
    vote.remind();
    return Plugin_Continue;
}

public void onVoteStartPost(Vote vote) {
    vote.announce();
}