
#define PRE_ROUND 3
#define MID_ROUND 4
#define POST_ROUND 5

#define PRE_GAME_MIN_PLAYERS 99

////////////////////////////////////////////////////////////////

static char _defaultMatchName[ML_MATCH];
static StringMap _cvLockValue;

static ConVar _winLimit;
static ConVar _maxRounds;
static ConVar _switchEach;

static ConVar _minPlayers;

static ConVar _ignoreTime;
static ConVar _ignoreWin;

static ConVar _preGameTime;
static ConVar _preRoundTime;
static ConVar _preRoundTimeFirst;
static ConVar _preRoundTimeSwitch;
static ConVar _postRoundTime;

static ConVar _cheats;
static ConVar _impacts;

static ConVar _restartGame;
static ConVar _restartRound;

static ConVar _roundTime;
static ConVar _capTime;
static ConVar _capSpeedupMax;
static ConVar _capSpeedupRate;

static ConVar _tags;

////////////////////////////////////////////////////////////////

static bool _isChangingMap;
static bool _isSwitchingSides;
static bool _sidesSwitched;

////////////////////////////////////////////////////////////////

static int _aClientOnSide[INS + 1];

enum Server { server, };

methodmap Server {
    property bool isChangingMap {
        public get() { return _isChangingMap; }
        public set(bool value) { _isChangingMap = value; }
    }

    property bool isSwitchingSides {
        public get() { return _isSwitchingSides; }
        public set(bool value) { _isSwitchingSides = value; }
    }

    property bool sidesSwitched {
        public get() { return _sidesSwitched; }
        public set(bool value) { _sidesSwitched = value; }
    }

    property int preRoundTimeFirst {
        public get() { return _preRoundTimeFirst.IntValue; }
        public set(int value) { _preRoundTimeFirst.IntValue = value; }
    }

    property int preRoundTime {
        public get() { return _preRoundTime.IntValue; }
        public set(int value) { _preRoundTime.IntValue = value; }
    }

    property int postRoundTime {
        public get() { return _postRoundTime.IntValue; }
        public set(int value) { _postRoundTime.IntValue = value; }
    }

    property int roundTime {
        public get() { return _roundTime.IntValue; }
        public set(int value) { _roundTime.IntValue = value; }
    }

    property int capTime {
        public get() { return _capTime.IntValue; }
        public set(int value) { _capTime.IntValue = value; }
    }

    property int capSpeedupMax {
        public get() { return _capSpeedupMax.IntValue; }
        public set(int value) { _capSpeedupMax.IntValue = value; }
    }

    property float capSpeedupRate {
        public get() { return _capSpeedupRate.FloatValue; }
        public set(float value) { _capSpeedupRate.FloatValue = value; }
    }

    property RoundState state {
        public get() { return view_as<RoundState>(GameRules_GetProp("m_iGameState")); }
        public set(RoundState value) { GameRules_SetProp("m_iGameState", view_as<int>(value)); }
    }

    property bool isPreRound {
        public get() { return this.state == RoundState_Preround; }
    }

    property bool isMidRound {
        public get() { return this.state == RoundState_RoundRunning; }
    }

    property bool isPostRound {
        public get() { return this.state == RoundState_TeamWin; }
    }

    property int roundsPlayed {
        public get() { return GameRules_GetProp("m_iRoundPlayedCount"); }
        public set(int value) { GameRules_SetProp("m_iRoundPlayedCount", value); }
    }

    property bool isPreGame {
        public get() { return _minPlayers.IntValue == PRE_GAME_MIN_PLAYERS; }
    }

    property bool isPostGame {
        public get() { return this.roundsPlayed >= _maxRounds.IntValue; }
    }

    property int round {
        public get() {
            int rp = this.roundsPlayed;
            return this.isPostRound ? rp : rp + 1;
        }
    }

    property float roundLength {
        public get() { return GameRules_GetPropFloat("m_flRoundLength"); }
        public set(float value) { GameRules_SetPropFloat("m_flRoundLength", value); }
    }

    property float roundStart {
        public get() { return GameRules_GetPropFloat("m_flRoundStartTime"); }
        public set(float value) { GameRules_SetPropFloat("m_flRoundStartTime", value); }
    }

    property float time {
        public get() { return maxFloat(0.0, (this.roundStart + this.roundLength - GetGameTime())); }

        public set(float value) {
            this.roundLength = value;
            this.roundStart = GetGameTime();
        }
    }

    property bool impacts {
        public get() { return _impacts.BoolValue; }
        public set(bool value) { _impacts.BoolValue = value; }
    }

    public void setPreRound() { this.state = RoundState_Preround; }
    public void setMidRound() { this.state = RoundState_RoundRunning; }
    public void setPostRound() { this.state = RoundState_TeamWin; }

    public void setPreGame() { _minPlayers.IntValue = PRE_GAME_MIN_PLAYERS; }

    public void endRound(int side = 0) {
        SetVariantInt(side);
        AcceptEntityInput(FindEntityByClassname(-1, "ins_rulesproxy"), "EndRound");
    }

    public void start() { _minPlayers.IntValue = 0; }

    public void finish() {
        unlockConVar(_maxRounds);
        _maxRounds.IntValue = max(1, this.roundsPlayed);
    }

    public void enableRoundEnd() {
        _ignoreTime.BoolValue = false;
        _ignoreWin.BoolValue = false;
    }

    public void disableRoundEnd() {
        _ignoreTime.BoolValue = true;
        _ignoreWin.BoolValue = true;
    }

    public void disableCheats() { _cheats.BoolValue = false; }

    public void restartGame() { _restartGame.IntValue = 1; }
    public void restartRound() { _restartRound.IntValue = 1; }

    public void setMap(const char[] map) { ServerCommand("map %s firefight", map); }

    public void reloadMap() {
        char map[ML_MAP];
        GetCurrentMap(map, ML_MAP);
        this.setMap(map);
    }

    public int getSideScore(int side) { return GetEntProp(GetTeamEntity(side), Prop_Send, "m_iRoundsWon"); }
    public void setSideScore(int side, int score) { SetEntProp(GetTeamEntity(side), Prop_Send, "m_iRoundsWon", score); }

    public void setScore(int secScore, int insScore) {
        this.setSideScore(SEC, secScore);
        this.setSideScore(INS, insScore);
    }

    public void switchSides() {
        this.isSwitchingSides = true;

        for (int i = 1; i <= MaxClients; i++) {
            if (IsClientInGame(i)) {
                int side = getClientSide(i);

                if (side == SEC) { ChangeClientTeam(i, INS); }
                else if (side == INS) { ChangeClientTeam(i, SEC); }
            }
        }

        this.setScore(this.getSideScore(INS), this.getSideScore(SEC));

        this.sidesSwitched = !this.sidesSwitched;
        this.isSwitchingSides = false;
    }

    public int getChatSource(int side) {
        int client = _aClientOnSide[side];

        if (client > 0 && IsClientInGame(client) && GetClientTeam(client) == side) {
            return client;
        }

        for (int i = 1; i <= MaxClients; i++) {
            if (IsClientInGame(i) && GetClientTeam(i) == side) {
                _aClientOnSide[side] = i;
                return i;
            }
        }

        return 0;
    }

    public void chatEmpty(int lines) {
        for (int i = 0; i < lines; i++) { PrintToChatAll(" "); }
    }

    public void clearChat() { this.chatEmpty(6); }

    public void chat(const char[] msg, any ...) {
        char formattedMsg[ML_MSG];
        VFormat(formattedMsg, ML_MSG, msg, 3);
        PrintToChatAll(formattedMsg);
    }

    public void chatFromSource(int source, char[] msg, any ...) {
        char formattedMsg[ML_MSG];
        VFormat(formattedMsg, ML_MSG, msg, 4);

        BfWrite bf = view_as<BfWrite>(StartMessageAll("SayText2"));

        if (bf != null) {
            bf.WriteByte(source);
            bf.WriteByte(false);
            bf.WriteString(formattedMsg);
            EndMessage();
        }
    }

    public void addTag() {
        char tags[ML_MSG];
        _tags.GetString(tags, ML_MSG);

        if (StrContains(tags, "matchBot") == -1) {
            Format(tags, ML_MSG, "%s, matchBot_v%s", tags, PLUGIN_VERSION);
            _tags.SetString(tags);
        }
    }

    public void setDefaultMatchName() {
        char map[ML_MAP];
        GetCurrentMap(map, ML_MAP);

        FormatTime(_defaultMatchName, ML_MATCH, "%y-%m-%d-%H-%M-%S");
        Format(_defaultMatchName, ML_MATCH, "%s_%s", _defaultMatchName, map);
    }

    public void getMatchName(char[] buffer, int maxLength) {
        config.getMatchName(buffer, maxLength);
        if (strlen(buffer) == 0) { strcopy(buffer, maxLength, _defaultMatchName); }
    }

    public void initialize() {
        this.setDefaultMatchName();
        this.setPreGame();

        this.isChangingMap = false;
        this.isSwitchingSides = false;
        this.sidesSwitched = false;

        _preRoundTimeFirst.IntValue = _preRoundTime.IntValue;

        lockConVar(_winLimit, 999);
        lockConVar(_maxRounds, 999);
        lockConVar(_switchEach, 0);
        lockConVar(_preRoundTimeSwitch, _preRoundTime.IntValue);
        lockConVar(_preGameTime, 1);

        this.addTag();
        this.impacts = true;

        LogToGame("%s v%s initialized", PLUGIN_NAME, PLUGIN_VERSION);
    }

    public void onPluginStart() {
        _cvLockValue = new StringMap();

        _winLimit = FindConVar("mp_winlimit");
        _maxRounds = FindConVar("mp_maxrounds");
        _switchEach = FindConVar("mp_switchteams_each_round");

        _minPlayers = FindConVar("mp_minteamplayers");

        _ignoreTime = FindConVar("mp_ignore_timer_conditions");
        _ignoreWin = FindConVar("mp_ignore_win_conditions");

        _preGameTime = FindConVar("mp_timer_pregame");
        _preRoundTime = FindConVar("mp_timer_preround");

        _preRoundTimeFirst = FindConVar("mp_timer_preround_first");
        _preRoundTimeSwitch = FindConVar("mp_timer_preround_switch");
        _postRoundTime = FindConVar("mp_timer_postround");

        _cheats = FindConVar("sv_cheats");
        _impacts = FindConVar("sv_showimpacts");

        _restartGame = FindConVar("mp_restartgame");
        _restartRound = FindConVar("mp_restartround");

        _roundTime = FindConVar("mp_roundtime");
        _capTime = FindConVar("mp_cp_capture_time");
        _capSpeedupMax = FindConVar("mp_cp_speedup_max");
        _capSpeedupRate  = FindConVar("mp_cp_speedup_rate");

        _tags = FindConVar("sv_tags");

        removeNotifyFlag(_maxRounds);
        removeNotifyFlag(_minPlayers);
        removeNotifyFlag(_ignoreTime);
        removeNotifyFlag(_ignoreWin);
        removeNotifyFlag(_preRoundTimeFirst);

        this.addTag();
    }
}

////////////////////////////////////////////////////////////////

static void removeNotifyFlag(ConVar convar) {
    int flags = convar.Flags;
    flags &= ~(FCVAR_NOTIFY);
    convar.Flags = flags;
}

static void lockConVar(ConVar convar, int value) {
    char name[ML_CMD];
    convar.GetName(name, ML_CMD);

    char lockValue[8];
    IntToString(value, lockValue, sizeof(lockValue));

    if (_cvLockValue.SetString(name, lockValue, false)) {
        convar.AddChangeHook(blockConVarChanges);
    }
    else {
        _cvLockValue.SetString(name, lockValue, true);
    }

    convar.IntValue = value;
}

static void unlockConVar(ConVar convar) {
    char name[ML_CMD];
    convar.GetName(name, ML_CMD);

    if (_cvLockValue.Remove(name)) { convar.RemoveChangeHook(blockConVarChanges); }
}

static void blockConVarChanges(ConVar convar, char[] oldValue, char[] newValue) {
	char name[ML_CMD];
	convar.GetName(name, ML_CMD);

	char lockValue[8];
	_cvLockValue.GetString(name, lockValue, 8);

	if (!StrEqual(lockValue, newValue)) { convar.SetString(lockValue); }
}