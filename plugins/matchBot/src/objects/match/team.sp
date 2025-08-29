
static bool _hasJoined[2];
static int _size[2];
static int _timeouts[2];

////////////////////////////////////////////////////////////////

methodmap Team {
    public Team(int side) {
        if (side < SEC) { return view_as<Team>(-1); }

        if (server.sidesSwitched) {
            if (side == SEC) { side = INS; }
            else if (side == INS) { side = SEC; }
        }

        return view_as<Team>(side - SEC);
    }

    property int index {
        public get() { return view_as<int>(this); }
    }

    property bool isValid {
        public get() { return (this.index == 0 || this.index == 1); }
    }

    property bool hasJoined {
        public get() { return _hasJoined[this.index]; }
        public set(bool value) { _hasJoined[this.index] = value; }
    }

    property int size {
        public get() { return _size[this.index]; }
    }

    property bool isEmpty {
        public get() { return this.size == 0; }
    }

    property int timeouts {
        public get() { return _timeouts[this.index]; }
        public set(int value) { _timeouts[this.index] = value; }
    }

    property bool isAlpha {
        public get() { return this.index == ALPHA; }
    }

    property bool isBravo {
        public get() { return this.index == BRAVO; }
    }

    property int side {
        public get() {
            if (server.sidesSwitched) {
                if (this.index == 0) { return INS; }
                if (this.index == 1) { return SEC; }
            }

            return (this.index + SEC);
        }
    }

    property int score {
        public get() { return server.getSideScore(this.side); }
        public set(int value) { server.setSideScore(this.side, value); }
    }

    property Team other {
        public get() { return view_as<Team>(1 - this.index); }
    }

    public void getName(char[] buffer, int maxLength) {
        if (this.isAlpha) { config.getAlphaName(buffer, maxLength); }
        else if (this.isBravo) { config.getBravoName(buffer, maxLength); }
    }

    public void setName(const char[] name) {
        if (this.isAlpha) { config.setAlphaName(name); }
        else if (this.isBravo) { config.setBravoName(name); }
    }

    public void onTimeoutCalled() {
        this.timeouts--;

        char teamName[ML_TEAM];
        this.getName(teamName, ML_TEAM);

        server.chat("%s used a timeout (%i remaining)", teamName, this.timeouts);
    }

    public bool hasMinPlayers() { return this.size >= config.minTeamSize; }

    public bool contains(Player player) { return player.isValid && player.side == this.side; }

    public void unready() {
        for (int i = 1; i <= MaxClients; i++) {
            Player player = Player(i);

            if (this.contains(player) && player.isReady) {
                player.unready();
                player.chat("One of your teammates left, so you have been unreadied");
            }
        }
    }

    public bool isReady() {
        for (int i = 1; i <= MaxClients; i++) {
            Player player = Player(i);
            if (this.contains(player) && !player.isReady) { return false; }
        }

        return true;
    }

    public int getChatSource() { return server.getChatSource(this.side); }

    public void printScore() {
        for (int i = 1; i <= MaxClients; i++) {
            Player player = Player(i);

            if (player.isValid) {
                char scoreText[8], name[ML_NAME];
                Format(scoreText, 8, "%s%i |", this.score < 10 && this.other.score >= 10 ? "0" : "", this.score);
                this.getName(name, ML_NAME);

                player.chatFromSource(
                    this.getChatSource(),
                    "\x01%s \x03%s\x01 (%s)",
                    scoreText,
                    name,
                    this.side == SEC ? "sec" : "ins"
                );
            }
        }
    }

    public void chat(const char[] msg, any ...) {
        char formattedMsg[ML_MSG];
        VFormat(formattedMsg, ML_MSG, msg, 3);

        for (int i = 1; i <= MaxClients; i++) {
            Player player = Player(i);
            if (this.contains(player)) { player.chat(formattedMsg); }
        }
    }

    public void onPlayerJoining() {
        _size[this.index]++;
        if (server.isPreGame && !this.hasJoined && this.size >= config.teamSize) {
            this.hasJoined = true;
        }
    }

    public void onPlayerLeaving() {
        _size[this.index]--;
        if (server.isPreGame && this.hasJoined && !this.other.hasJoined && this.size < config.teamSize) {
            this.hasJoined = false;
        }
    }

    public void initialize() {
        if (this.isValid) {
            this.hasJoined = false;
            _size[this.index] = 0;
            this.timeouts = config.timeouts;
        }
    }
}