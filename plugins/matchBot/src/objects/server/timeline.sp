
static char _hitgroup[8][ML_HITGROUP] = {"none", "head", "chest", "stomach", "l_arm", "r_arm", "l_leg", "r_leg"};

static char _dataDir[ML_PATH];
static char _matchBotDir[ML_PATH];
static char _timelineDir[ML_PATH];
static char _tempDir[ML_PATH];

static char _timelinePath[ML_PATH];
static char _tempPath[ML_PATH];

static ArrayList _events;

static bool _isSpawned[MAXPLAYERS];

////////////////////////////////////////////////////////////////

enum Timeline { timeline, };

methodmap Timeline {
    public void clear() { _events.Clear(); }

    public void push(const char[] name, const char[] fmt, any ...) {
        char event[ML_EVENT];
        VFormat(event, ML_EVENT, fmt, 4);
        Format(event, ML_EVENT, "%s %.2f %s", name, GetGameTime(), event);
        _events.PushString(event);
    }

    public void write() {
        File file = OpenFile(_tempPath, "a");

        for (int i = 0; i < _events.Length; i++) {
            char event[ML_EVENT];
            _events.GetString(i, event, ML_EVENT);
            file.WriteLine(event);
        }

        file.Close();
        this.clear();
    }

    public void onSpawn(Player player) {
        _isSpawned[player.index] = true;

        char sid[ML_NAME];
        player.getSid64(sid, ML_NAME);
        this.push(EVENT_SPAWN, "%s %i", sid, player.teamIndex);
    }

    public void onDespawn(Player player) {
        _isSpawned[player.index] = false;

        char sid[ML_NAME];
        player.getSid64(sid, ML_NAME);
        this.push(EVENT_DESPAWN, "%s %.2f %i", sid, player.distance, player.shotsFired);
    }

    public void onDamage(Player attacker, Player victim, int damage) {
        char aSid[ML_NAME], vSid[ML_NAME];
        attacker.getSid64(aSid, ML_NAME);
        victim.getSid64(vSid, ML_NAME);

        this.push(EVENT_DAMAGE, "%s %s %i", aSid, vSid, clamp(damage, 0, 100));
    }

    public void onKill(Player attacker, Player victim, char[] weapon, int hitgroup) {
        char aSid[ML_NAME], vSid[ML_NAME];
        attacker.getSid64(aSid, ML_NAME);
        victim.getSid64(vSid, ML_NAME);

        float aPos[3], vPos[3];
        attacker.getPos(aPos);
        victim.getPos(vPos);

        if (weapon[0] == 'w') { ReplaceString(weapon, ML_NAME, "weapon_", "", true); }
        else if (weapon[0] == 'g') { ReplaceString(weapon, ML_NAME, "grenade_", "", true); }

        this.push(
            EVENT_KILL,
            "%s %.1f,%.1f,%.1f %s %.1f,%.1f,%.1f %s %s",
            aSid, aPos[0], aPos[1], aPos[2], vSid, vPos[0], vPos[1], vPos[2], weapon, _hitgroup[hitgroup]
        );

        this.onDespawn(victim);
    }

    public void onObjectiveCap(Team team, Objective obj) { this.push(EVENT_OBJ_CAP, "%i %i", team.index, obj.index); }

    public void onObjectiveEnter(Player player, Objective obj) {
        char sid[ML_NAME];
        player.getSid64(sid, ML_NAME);
        this.push(EVENT_OBJ_ENTER, "%s %i", sid, obj.index);
    }

    public void onObjectiveExit(Player player, Objective obj) {
        char sid[ML_NAME];
        player.getSid64(sid, ML_NAME);
        this.push(EVENT_OBJ_EXIT, "%s %i", sid, obj.index);
    }

    public void onThrow(Player player, int entity) {
        char sid[ML_NAME];
        player.getSid64(sid, ML_NAME);

        float pos[3];
        player.getPos(pos);

        char classname[ML_NAME];
        GetEntityClassname(entity, classname, ML_NAME);
        ReplaceString(classname, ML_NAME, "grenade_", "", false);

        this.push(EVENT_THROW, "%s %s %i %.1f,%.1f,%.1f", sid, classname, entity, pos[0], pos[1], pos[2]);
    }

    public void onDetonate(Player player, int entity) {
        char sid[ML_NAME];
        player.getSid64(sid, ML_NAME);

        float pos[3];
        GetEntPropVector(entity, Prop_Data, "m_vecOrigin", pos);

        char classname[ML_NAME];
        GetEntityClassname(entity, classname, ML_NAME);
        ReplaceString(classname, ML_NAME, "grenade_", "", false);

        this.push(EVENT_DETONATE, "%s %s %i %.1f,%.1f,%.1f", sid, classname, entity, pos[0], pos[1], pos[2]);
    }

    public void onRoundStart(Team secTeam) {
        this.clear();
        this.push(EVENT_ROUND_START, "%i %i %i %i", secTeam.index, objA.owner.index, objB.owner.index, objC.owner.index);

        for (int i = 1; i <= MaxClients; i++) {
            Player player = Player(i);
            if (player.isValid && player.isAlive) { this.onSpawn(player); }
        }
    }

    public void onRoundEnd(Team winner) {
        this.push(EVENT_ROUND_END, "%i", winner.index);

        for (int i = 1; i <= MaxClients; i++) {
            Player player = Player(i);
            if (player.isValid && _isSpawned[player.index]) { this.onDespawn(player); }
        }

        this.write();
    }

    public void finalize() {
        if (FileExists(_tempPath)) {
            if (FileExists(_timelinePath)) { DeleteFile(_timelinePath); }
            else { cleanUpDirectory(_timelineDir, config.fileLimit - 1); }

            char map[ML_MAP];
            GetCurrentMap(map, ML_MAP);

            File file = OpenFile(_timelinePath, "a");

            file.WriteLine("%i %i %i %i %i %f %i",
                config.winLimit,
                config.winLimitOt,
                server.roundTime,
                server.capTime,
                server.capSpeedupMax,
                server.capSpeedupRate,
                config.teamSize
            );

            file.WriteLine(PLUGIN_VERSION);
            file.WriteLine(map);

            for (int i = ALPHA; i <= BRAVO; i++) {
                Team team = view_as<Team>(i);
                char teamName[ML_TEAM];
                team.getName(teamName, ML_TEAM);
                file.WriteLine("%i %s", team.score, teamName);
            }

            file.WriteLine("// start");
            File temp = OpenFile(_tempPath, "r");

            while (!temp.EndOfFile()) {
                char event[ML_EVENT];
                temp.ReadLine(event, ML_EVENT);
                file.WriteString(event, false);
            }

            file.WriteLine("// end");

            temp.Close();
            file.Close();

            DeleteFile(_tempPath);
        }
    }

    public void initialize() {
        if (_events == null) { _events = new ArrayList(ML_EVENT); }
        else { _events.Clear(); }

        if (strlen(_timelineDir) < 1 || !DirExists(_timelineDir)) {
            BuildPath(Path_SM, _dataDir, ML_PATH, "data");
            Format(_matchBotDir, ML_PATH, "%s/matchBot", _dataDir);
            Format(_timelineDir, ML_PATH, "%s/timelines", _matchBotDir);
            Format(_tempDir, ML_PATH, "%s/inProgress", _matchBotDir);

            CreateDirectory(_dataDir, 511);
            CreateDirectory(_matchBotDir, 511);
            CreateDirectory(_timelineDir, 511);
            CreateDirectory(_tempDir, 511);
        }

        cleanUpDirectory(_tempDir, 5);

        char matchName[ML_MATCH];
        server.getMatchName(matchName, ML_MATCH);

        Format(_timelinePath, ML_PATH, "%s/%s.rep", _timelineDir, matchName);
        Format(_tempPath, ML_PATH, "%s/%s.temp", _tempDir, matchName);

        if (FileExists(_tempPath)) { DeleteFile(_tempPath); }
    }
}