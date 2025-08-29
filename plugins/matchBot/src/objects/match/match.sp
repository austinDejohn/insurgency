
static MatchState _state;
static bool _isWaiting;
static bool _isLor;
static int _lastIntermission;
static float _pauseStartTime;
static float _pauseDuration;
static bool _canDraw;
static float _lastPause;
static Handle _readyDisplayTimer;
static Handle _warmupTimer;
static Handle _pauseTimer;
static Handle _distanceTimer;
static bool _randomizationStarted;

enum Match { match, };

methodmap Match {
    property MatchState state {
        public get() { return _state; }
        public set(MatchState value) { _state = value; }
    }

    property bool isWarmup {
        public get() { return _state == MatchState_Warmup; }
    }

    property bool isPaused {
        public get() { return _state == MatchState_Paused; }
    }

    property bool isLive {
        public get() { return _state == MatchState_Live; }
    }

    property bool isFinished {
        public get() { return _state == MatchState_Finished; }
    }

    property bool isLor {
        public get() { return _isLor; }
    }

    property Team invalidTeam {
        public get() { return view_as<Team>(-1); }
    }

    property Team alpha {
        public get() { return view_as<Team>(ALPHA); }
    }

    property Team bravo {
        public get() { return view_as<Team>(BRAVO); }
    }

    public Team getTeam(Player player) { return view_as<Team>(player.teamIndex); }

    property bool canDraw {
        public get() { return _canDraw; }
    }

    property int maxRoundsReg {
        public get() { return max(1, (config.winLimit - 1) * 2); }
    }

    property int maxRoundsOt {
        public get() { return max(1, (config.winLimitOt - 1) * 2); }
    }

    public bool isRegulation() { return server.round <= this.maxRoundsReg; }

    public int winLimit() { return this.isRegulation() ? config.winLimit : config.winLimitOt; }
    public int halfLength() { return this.winLimit() - 1; }
    public int maxRounds() { return max(1, this.halfLength() * 2); }

    public int period() {
        int rp = server.round - this.maxRoundsReg;
        if (rp <= 0) { return 0; }

        return 1 + ((rp - 1) / this.maxRoundsOt);
    }

    public int roundsRemaining() {
        return (this.maxRoundsReg + (this.maxRoundsOt * this.period())) - server.roundsPlayed;
    }

    public bool doStartOvertime() { return this.roundsRemaining() == this.maxRounds(); }
    public bool doStartHalftime() { return this.roundsRemaining() == this.halfLength(); }

    public Team getWinner() {
        if (abs(this.alpha.score - this.bravo.score) > this.roundsRemaining()) {
            return (this.alpha.score > this.bravo.score) ? this.alpha : this.bravo;
        }

        return Team(-1);
    }

    public int countReady() {
        int count = 0;

        for (int i = 1; i <= MaxClients; i++) {
            Player player = Player(i);
            if (player.isValid && !player.isSpectator && player.isReady) { count++; }
        }

        return count;
    }

    public bool isWaiting() { return _isWaiting; }

    public void refreshReadyDisplay() {
        if (this.isWaiting()) {
            char readyMsg[16];
            Format(readyMsg, 16, "%i/%i ready", this.countReady(), this.alpha.size + this.bravo.size);

            for (int i = 1; i <= MaxClients; i++) {
                Player player = Player(i);

                if (player.isValid && !player.isBot) {
                    if (player.isReady || player.isSpectator) { player.hint(readyMsg); }
                    else { player.hint(REMINDER_READY_UP); }
                }
            }
        }
    }

    public bool isReadyDisplayShown() { return _readyDisplayTimer != null; }

    public void stopReadyDisplay() {
        if (this.isReadyDisplayShown()) { delete _readyDisplayTimer; }
    }

    public void startReadyDisplay() {
        this.stopReadyDisplay();
        _readyDisplayTimer = CreateTimer(3.0, onRefreshReadyDisplay, _, TIMER_REPEAT);
    }

    public void unreadyAll() {
        for (int i = 1; i <= MaxClients; i++) {
            Player player = Player(i);
            if (player.isValid && !player.isSpectator) { player.unready(); }
        }
    }

    public void readyAll() {
        for (int i = 1; i <= MaxClients; i++) {
            Player player = Player(i);
            if (player.isValid && !player.isSpectator) { player.ready(); }
        }
    }

    public void wait() {
        _isWaiting = true;
        this.unreadyAll();
        this.startReadyDisplay();
        this.refreshReadyDisplay();
    }

    public bool isWarmupTimerActive() { return _warmupTimer != null; }

    public void stopWarmupTimer() {
        if (this.isWarmupTimerActive()) {
            delete _warmupTimer;
            server.time = 0.0;
        }
    }

    public void startWarmupTimer() {
        this.stopWarmupTimer();

        if (config.warmupTime > 0) {
            server.time = config.warmupTime;
            _warmupTimer = CreateTimer(config.warmupTime, onWarmupTimerExpired);
        }
    }

    public void displayRoundCount(Player player) {
        int maxRounds = match.maxRounds();

        if (maxRounds == 1) {
            player.hint("Sudden Death");
        }
        else {
            int period = match.period();
            int round = maxRounds - match.roundsRemaining() + 1;

            if (period == 0) { player.hint("Round %i/%i", round, maxRounds); }
            else if (period == 1) { player.hint("Round %i/%i (OT)", round, maxRounds); }
            else { player.hint("Round %i/%i (%iOT)", round, maxRounds, period); }
        }
    }

    public void printScore() {
        this.alpha.printScore();
        this.bravo.printScore();
    }

    public void announce(const char[] msg) {
        PrintToChatAll(" ");
        PrintToChatAll("------------------------------------------------------------------------------------------------");
        PrintToChatAll("\x04---------------- %s", msg);
        PrintToChatAll("\x04---------------- %s", msg);
        PrintToChatAll("\x04---------------- %s", msg);
        PrintToChatAll("------------------------------------------------------------------------------------------------");
    }

    public void lor() {
        _isLor = true;
        _isWaiting = false;

        this.readyAll();
        this.stopReadyDisplay();
        this.stopWarmupTimer();

        if (server.isPreGame) {
            server.chat("The match will be live on restart");

            if (server.isPreGame) { server.start(); }
            else { server.restartGame(); }
        }
        else {
            server.restartRound();
        }

        server.time = 5.0;
    }

    public void live() {
        server.enableRoundEnd();
        _canDraw = false;
        _isLor = false;
        this.state = MatchState_Live;
        this.announce("Match is LIVE");

        if (server.impacts) { server.impacts = false; }
    }

    public void notLive() {
        _isLor = false;

        if (this.isLive) {
            this.state = MatchState_Paused;
            server.disableRoundEnd();
            this.wait();
        }
    }

    public void stopDistanceTimer() {
        if (_distanceTimer != null) { delete _distanceTimer; }
    }

    public void startDistanceTimer() {
        this.stopDistanceTimer();
        _distanceTimer = CreateTimer(DISTANCE_CHECK_FREQUENCY, onDistanceCheck, _, TIMER_REPEAT);
    }

    public void stopPauseTimer() {
        if (_pauseTimer != null) { delete _pauseTimer; }
    }

    public void startPauseTimer(float duration) {
        this.stopPauseTimer();
        _pauseTimer = CreateTimer(duration, onPauseFinished);
    }

    public float getRemainingPause() { return _pauseStartTime - GetGameTime() + _pauseDuration; }

    public void pause(float duration) {
        if (this.isPaused) {
            _pauseDuration += duration;
            server.time = this.getRemainingPause();
            this.startPauseTimer(server.time);
        }
        else {
            this.notLive();
            _pauseStartTime = GetGameTime();
            _pauseDuration = duration;

            server.setPreRound();
            server.time = duration;
            this.startPauseTimer(duration);
            timeline.clear();
        }
    }

    public bool unpause() {
        this.stopPauseTimer();

        if (this.isPaused) {
            this.lor();

            _pauseStartTime = -1.0;
            _pauseDuration = -1.0;

            return true;
        }

        return false;
    }

    public bool justCalledTimeout() { return GetGameTime() - _lastPause < 5.0; }

    public bool alreadyDidIntermission() { return _lastIntermission == server.roundsPlayed; }

    public void finish() {
        this.state = MatchState_Finished;
        server.finish();
        timeline.finalize();
    }

    public void onWin(Team winner) {
        this.finish();
        server.clearChat();

        if (winner.isValid) {
            char teamName[ML_TEAM];
            winner.getName(teamName, ML_TEAM);
            server.chat("%s won the match, %i - %i", teamName, winner.score, winner.other.score);
        }
        else { server.chat("The match ended in a draw!"); }
    }

    public void onDraw() { this.onWin(this.invalidTeam); }

    public void forceDraw() {
        this.onDraw();
        if (!server.isPostRound) { server.endRound(); }
    }

    public void onForfeit(Team team, const char[] reason) {
        if (this.isFinished) { return; }

        team.other.score += ((team.score - team.other.score + this.roundsRemaining()) / 2) + 1;
        this.finish();

        if (!server.isPreGame && !server.isPostRound) {
            server.endRound(team.other.side);
            team.other.score--;
        }

        server.clearChat();

        char teamName[ML_TEAM];
        team.getName(teamName, ML_TEAM);

        server.chat("%s forfeit the match (%s)", teamName, reason);
    }

    public void onCanceled() {
        this.finish();
        server.clearChat();
        server.chat("The match has been canceled because not enough players joined");
    }

    public bool onTimeoutCalled(float duration) {
        _lastPause = GetGameTime();
        this.pause(duration);
    }

    public bool onIntermission() {
        _lastIntermission = server.roundsPlayed;
        this.pause(config.intermissionDuration);
    }

    public void startHalftime() {
        server.chat("The second half will be live on restart");
        server.switchSides();
        this.onIntermission();
    }

    public void startOvertime() {
        int period = this.period();

        char msg[ML_MSG];

        if (this.maxRoundsOt == 1) { Format(msg, ML_MSG, "OT (Sudden Death) will be live on restart"); }
        else { Format(msg, ML_MSG, "OT (best %i of %i) will be live on restart", config.winLimitOt, this.maxRoundsOt); }

        if (period > 1) { Format(msg, ML_MSG, "%i%s", period, msg); }

        if (period > config.minOt) {
            _canDraw = true;
            Format(msg, ML_MSG, "%s, or you can type .draw to end the match in a draw", msg);
        }

        server.chat(msg);
        this.onIntermission();
    }

    public void onRoundStartPause() {
        server.setPreRound();
        server.time = this.getRemainingPause();
    }

    public void onPreRound() {
        if (!this.alreadyDidIntermission()) {
            if (this.doStartOvertime()) {
                this.startOvertime();
                return;
            }
            else if (this.doStartHalftime()) {
                this.startHalftime();
                return;
            }
        }

        damageLog.initialize();
    }

    public void onRoundStart() {
        timeline.onRoundStart(Team(SEC));
        this.startDistanceTimer();

        server.chatEmpty(4);
        this.printScore();
    }

    public void onRoundEnd(Team winner) {
        timeline.onRoundEnd(winner);
        Team matchWinner = this.getWinner();

        if (matchWinner.isValid) {
            this.onWin(winner);
        }
        else if (this.roundsRemaining() == 0 && this.period() + 1 > config.maxOt) {
            this.onDraw();
        }
        else {
            server.chatEmpty(1);
            damageLog.print();
        }

        this.stopDistanceTimer();
    }

    public void onTeamChanged(Player player, Team newTeam, Team oldTeam) {
        if (oldTeam.isValid) {
            oldTeam.onPlayerLeaving();

            if (!server.isPreGame && oldTeam.size == 0) { this.onForfeit(oldTeam, "left the server"); }
            else if (this.isWaiting()) { oldTeam.unready(); }
        }

        if (newTeam.isValid) {
            newTeam.onPlayerJoining();
            if (this.isWaiting()) { player.unready(); }
        }
        else if (!player.isReady) { player.ready(); }

        if (server.isPreGame) {
            if (!this.isWaiting() && this.alpha.hasJoined && this.bravo.hasJoined) {
                if (config.doRandomizeSides) {
                    if (!_randomizationStarted) {
                        _randomizationStarted = true;
                        float delay = 10.0;

                        server.time = delay;
                        CreateTimer(delay, randomizeSidesAndWait);

                        server.chat("The starting sides will be randomly selected in %.0f seconds", delay);
                    }
                }
                else {
                    this.wait();
                }
            }
        }
    }

    public void initialize() {
        this.state = MatchState_Warmup;

        _isWaiting = false;
        _isLor = false;
        _lastIntermission = 0;
        _pauseStartTime = -1.0;
        _pauseDuration = -1.0;
        _canDraw = false;
        _lastPause = 0.0;
        _randomizationStarted = false;

        this.alpha.initialize();
        this.bravo.initialize();

        this.stopReadyDisplay();
        this.stopWarmupTimer();
        this.stopPauseTimer();
        this.stopDistanceTimer();

        this.startWarmupTimer();
    }
}

////////////////////////////////////////////////////////////////

public Action randomizeSidesAndWait(Handle timer) {
	if (GetRandomInt(0, 1) == 1) { server.switchSides(); }
	match.wait();

	return Plugin_Handled;
}

static Action onPauseFinished(Handle timer) {
    _pauseTimer = null;
    match.unpause();
    return Plugin_Stop;
}

static Action onRefreshReadyDisplay(Handle timer) {
    match.refreshReadyDisplay();
    return Plugin_Continue;
}

static Action onWarmupTimerExpired(Handle timer) {
    _warmupTimer = null;

    if (server.isPreGame) {
        int aSize = match.alpha.size;
        int bSize = match.bravo.size;

        if (aSize < config.minTeamSize || bSize < config.minTeamSize) {
            if (aSize == bSize) { match.onCanceled(); }
            else { match.onForfeit(aSize < bSize ? match.alpha : match.bravo, "not enough players"); }
        }
        else { match.lor(); }
    }

    return Plugin_Stop;
}

static Action onDistanceCheck(Handle timer) {
    if (match.isLive) {
        for (int i = 1; i <= MaxClients; i++) {
            Player player = Player(i);
            if (player.isValid && player.isAlive) { player.updateDistance(); }
        }
    }

    return Plugin_Continue;
}