
static ArrayList _list;

static ConVar _winLimitReg;
static ConVar _winLimitOt;

static ConVar _minOt;
static ConVar _maxOt;

static ConVar _teamSize;
static ConVar _minTeamSize;

static ConVar _timeouts;
static ConVar _timeoutGrace;
static ConVar _timeoutDuration;
static ConVar _intermissionDuration;

static ConVar _warmupTime;
static ConVar _doRandomizeSides;

static ConVar _alphaName;
static ConVar _bravoName;

static ConVar _matchName;
static ConVar _fileLimit;

////////////////////////////////////////////////////////////////

enum Config { config, };

methodmap Config {
    property int winLimit {
        public get() { return _winLimitReg.IntValue; }
        public set(int value) { _winLimitReg.IntValue = value; }
    }

    property int winLimitOt {
        public get() { return _winLimitOt.IntValue; }
        public set(int value) { _winLimitOt.IntValue = value; }
    }

    property int minOt {
        public get() { return _minOt.IntValue; }
        public set(int value) { _minOt.IntValue = value; }
    }

    property int maxOt {
        public get() { return _maxOt.IntValue >= this.minOt ? _maxOt.IntValue : this.minOt; }
        public set(int value) { _maxOt.IntValue = value; }
    }

    property int teamSize {
        public get() { return _teamSize.IntValue; }
        public set(int value) { _teamSize.IntValue = value; }
    }

    property int minTeamSize {
        public get() { return _minTeamSize.IntValue; }
        public set(int value) { _minTeamSize.IntValue = value; }
    }

    property int timeouts {
        public get() { return _timeouts.IntValue; }
        public set(int value) { _timeouts.IntValue = value; }
    }

    property float timeoutGrace {
        public get() { return _timeoutGrace.FloatValue; }
        public set(float value) { _timeoutGrace.FloatValue = value; }
    }

    property float timeoutDuration {
        public get() { return _timeoutDuration.FloatValue; }
        public set(float value) { _timeoutDuration.FloatValue = value; }
    }

    property float intermissionDuration {
        public get() { return _intermissionDuration.FloatValue; }
        public set(float value) { _intermissionDuration.FloatValue = value; }
    }

    property float warmupTime {
        public get() { return _warmupTime.FloatValue; }
        public set(float value) { _warmupTime.FloatValue = value; }
    }

    property bool doRandomizeSides {
        public get() { return _doRandomizeSides.BoolValue; }
        public set(bool value) { _doRandomizeSides.BoolValue = value; }
    }

    property int fileLimit {
        public get() { return _fileLimit.IntValue; }
        public set(int value) { _fileLimit.IntValue = value; }
    }

    public void getAlphaName(char[] buffer, int maxLength) {
        _alphaName.GetString(buffer, maxLength);
    }

    public void getBravoName(char[] buffer, int maxLength) {
        _bravoName.GetString(buffer, maxLength);
    }

    public void setAlphaName(const char[] name) {
        _alphaName.SetString(name);
    }

    public void setBravoName(const char[] name) {
        _bravoName.SetString(name);
    }

    public void getMatchName(char[] buffer, int maxLength) {
        _matchName.GetString(buffer, maxLength);
    }

    public void print(int client) {
        char name[32], value[32];

        for (int i = 0; i < _list.Length; i++) {
            ConVar convar = view_as<ConVar>(_list.Get(i));
            convar.GetName(name, 32);
            convar.GetString(value, 32);
            PrintToConsole(client, "%s %s", name, value);
        }
    }

    public void onPluginStart() {
        _list = new ArrayList();

        _winLimitReg = addCfgVar("mb_win_limit", "11", "Number of round wins needed in order to win a map in regulation", _, true, 1.0, true, 99.0);
        _winLimitOt = addCfgVar("mb_win_limit_ot", "4", "Number of round wins needed in order to win a map in overtime", _, true, 1.0, true, 99.0);

        _minOt = addCfgVar("mb_min_ot", "0", "Minimum number of OT periods that must be played before a draw is allowed", _, true, 0.0, true, 99.0);
        _maxOt = addCfgVar("mb_max_ot", "99", "Maximum number of OT periods that can be played before a draw is forced", _, true, 0.0, true, 99.0);

        _teamSize = addCfgVar("mb_team_size", "5", "Once both teams have this many players, the ready up process will begin", _, true, 1.0, true, 16.0);
        _minTeamSize = addCfgVar("mb_min_team_size", "4", "Minimum number of players needed for a team to start the match", _, true, 1.0, true, 16.0);

        _timeouts = addCfgVar("mb_timeouts", "3", "Number of timeouts each team can use during regulation", _, true, 0.0, true, 100.0);
        _timeoutGrace = addCfgVar("mb_timeout_grace", "5", "Duration, in seconds, after the start of the round in which a timeout can be called", _, true, 0.0, true, 120.0);
        _timeoutDuration = addCfgVar("mb_timeout_duration", "60", "Duration, in seconds, of a timeout", _, true, 10.0, true, 1800.0);
        _intermissionDuration = addCfgVar("mb_intermission_duration", "30", "Duration, in seconds, of the intermission between halves", _, true, 10.0, true, 1800.0);

        _warmupTime = addCfgVar("mb_warmup_time", "-1", "Duration, in seconds, before the match is canceled/forfeit (-1 for infinite)", _, true, 0.0, true, 5400.0);
        _doRandomizeSides = addCfgVar("mb_do_randomize_sides", "1", "Whether the starting sides should be randomized", _, true, 0.0, true, 1.0);

        _alphaName = addCfgVar("mb_alpha_name", "Alpha", "Name of the team that starts on Security", 0);
        _bravoName = addCfgVar("mb_bravo_name", "Bravo", "Name of the team that starts on Insurgency", 0);

        _matchName = addCfgVar("mb_match_name", "", "Demo/timeline filename (defaults to YY-MM-dd-hh-mm-ss_map)");
        _fileLimit = addCfgVar("mb_file_limit", "10", "Maximum number of timeline files to store", _, true, 1.0, true, 10000.0);
    }
}

static ConVar addCfgVar(const char[] name, const char[] defValue, const char[] desc, int flags = FCVAR_NOTIFY, bool hasMin = false, float min = 0.0, bool hasMax = false, float max = 1.0) {
    ConVar convar = CreateConVar(name, defValue, desc, flags, hasMin, min, hasMax, max);
    _list.Push(convar);
    return convar;
}
