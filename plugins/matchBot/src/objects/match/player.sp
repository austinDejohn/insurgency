
static bool _isReady[MAXPLAYERS];
static bool _isGod[MAXPLAYERS];
static char _name[MAXPLAYERS][ML_NAME];
static bool _allowNameChange[MAXPLAYERS];
static float _distance[MAXPLAYERS];
static float _lastPos[MAXPLAYERS][3];
static int _shotsFired[MAXPLAYERS];

methodmap Player {
    public Player(int client) {
        if (client > 0 && client <= MaxClients && IsClientInGame(client)) { return view_as<Player>(client); }
        return view_as<Player>(-1);
    }

    property int index {
        public get() { return view_as<int>(this); }
    }

    property bool isValid {
        public get() { return (this.index != -1); }
    }

    property bool isBot {
        public get() { return IsFakeClient(this.index); }
    }

    property bool isAlive {
        public get() { return view_as<bool>(GetEntProp(GetPlayerResourceEntity(), Prop_Send, "m_bAlive", 1, this.index)); }
    }

    property bool isNoclip {
        public get() { return GetEntityMoveType(this.index) == MOVETYPE_NOCLIP; }
        public set(bool value) { SetEntityMoveType(this.index, value ? MOVETYPE_NOCLIP : MOVETYPE_WALK); }
    }

    property bool isGod {
        public get() { return _isGod[this.index]; }
        public set(bool value) { _isGod[this.index] = value; }
    }

    property int currentWeapon {
        public get() { return GetEntPropEnt(this.index, Prop_Data, "m_hActiveWeapon"); }
        public set(int value) { SetEntPropEnt(this.index, Prop_Send, "m_hActiveWeapon", value); }
    }

    property int side {
        public get() { return getClientSide(this.index); }
    }

    property bool isSpectator {
        public get() {
            if (isValidSide(this.side) || isValidSide(GetEntProp(this.index, Prop_Data, "m_iPendingTeamNum"))) { return false; }
            return true;
        }
    }

    property int teamIndex {
        public get() {
            if (this.isSpectator) { return -1; }
            if (server.sidesSwitched) { return (INS - this.side); }
            return (this.side - SEC);
        }
    }

    property bool isReady {
        public get() { return _isReady[this.index]; }
    }

    property bool allowNameChange {
        public get() { return _allowNameChange[this.index]; }
        public set(bool value) { _allowNameChange[this.index] = value; }
    }

    property float distance {
        public get() { return _distance[this.index]; }
        public set(float value) { _distance[this.index] = value; }
    }

    property int shotsFired {
        public get() { return _shotsFired[this.index]; }
        public set(int value) { _shotsFired[this.index] = value; }
    }

    public void getPos(float pos[3]) {
        GetEntPropVector(this.index, Prop_Data, "m_vecOrigin", pos);
    }

    public float updateDistance() {
        float cPos[3];
        this.getPos(cPos);

        float dis = GetVectorDistance(cPos, _lastPos[this.index], false);

        if (dis >= MIN_DISTANCE) {
            _lastPos[this.index] = cPos;
            this.distance += dis;
        }
    }

    public int getWeaponSlot(int slot) { return GetPlayerWeaponSlot(this.index, slot); }

    public int getPrimary() { return this.getWeaponSlot(SLOT_PRIMARY); }
    public int getSecondary() { return this.getWeaponSlot(SLOT_SECONDARY); }
    public int getMelee() { return this.getWeaponSlot(SLOT_MELEE); }
    public int getExplosive() { return this.getWeaponSlot(SLOT_EXPLOSIVE); }

    public int getId() { return GetClientUserId(this.index); }

    public void getSid(char[] buffer, int maxLength) {
        if (!this.isBot) { GetClientAuthId(this.index, AuthId_Steam2, buffer, maxLength); }
        else { Format(buffer, maxLength, "BOT_%i", this.getId()); }
    }

    public void getSid64(char[] buffer, int maxLength) {
        if (!this.isBot) { GetClientAuthId(this.index, AuthId_SteamID64, buffer, maxLength); }
        else { Format(buffer, maxLength, "BOT_%i", this.getId()); }
    }

    public void cacheName() {
        char name[ML_NAME];
        GetClientName(this.index, name, ML_NAME);
        strcopy(_name[this.index], ML_NAME, name);

        if (StrContains(_name[this.index], PREFIX_NOT_READY, true) == 0) {
            ReplaceStringEx(_name[this.index], ML_NAME, PREFIX_NOT_READY, "", -1, 0, true);
        }
    }

    public void getName(char[] buffer, int maxLength) {
        if (strlen(_name[this.index]) == 0) { this.cacheName(); }
        strcopy(buffer, maxLength, _name[this.index]);
    }

    public void setDisplayName(const char[] name, any ...) {
        char formattedName[ML_NAME];
        VFormat(formattedName, ML_NAME, name, 3);

        this.allowNameChange = true;

        SetClientName(this.index, formattedName);
        SetEntPropString(this.index, Prop_Data, "m_szNetname", formattedName);

        this.allowNameChange = false;
    }

    public void setName(const char[] name) {
        this.setDisplayName(name);
        strcopy(_name[this.index], ML_NAME, name);
    }

    public void resetName() {
        char name[ML_NAME];
        this.getName(name, ML_NAME);
        this.setDisplayName("%s%s", this.isReady ? "" : PREFIX_NOT_READY, name);
    }

    public void playSound(const char[] path) { ClientCommand(this.index, "playgamesound \"%s\"", path); }

    public void chat(const char[] msg, any ...) {
        char formattedMsg[ML_MSG];
        VFormat(formattedMsg, ML_MSG, msg, 3);
        PrintToChat(this.index, formattedMsg);
    }

    public void hint(const char[] msg, any ...) {
        char formattedMsg[ML_MSG];
        VFormat(formattedMsg, ML_MSG, msg, 3);
        PrintHintText(this.index, formattedMsg);
    }

    public void chatFromSource(int source, char[] msg, any ...) {
        char formattedMsg[ML_MSG];
        VFormat(formattedMsg, ML_MSG, msg, 4);

        BfWrite bf = view_as<BfWrite>(StartMessageOne("SayText2", this.index));

        if (bf != null) {
            bf.WriteByte(source);
            bf.WriteByte(false);
            bf.WriteString(formattedMsg);
            EndMessage();
        }
    }

    public void say(const char[] msg, any ...) {
        char formattedMsg[ML_MSG];
        VFormat(formattedMsg, ML_MSG, msg, 3);

        BfWrite bf = view_as<BfWrite>(StartMessageAll("SayText2"));

        if (bf != null) {
            int side = this.side;
            char name[ML_NAME];
            this.getName(name, ML_NAME);

            bf.WriteShort(256 + this.index);
            bf.WriteString("INS_Chat_All");
            bf.WriteString(name);
            bf.WriteString(formattedMsg);
            bf.WriteByte(0);

            if (side == SEC) { bf.WriteString("#Team_Security"); }
            else if (side == INS) { bf.WriteString("#Team_Insurgent"); }

            EndMessage();
        }
    }

    public void ready() {
        _isReady[this.index] = true;
        this.resetName();
    }

    public void unready() {
        _isReady[this.index] = false;
        this.resetName();
    }

    public void resetLoadout() {
        FakeClientCommand(this.index, "inventory_reset");
        RequestFrame(confirmDelay, this);
    }

    public void clearLoadout() {
        FakeClientCommand(this.index, "inventory_sell_all");
        RequestFrame(confirmDelay, this);
    }

    public void confirmLoadout() { FakeClientCommand(this.index, "inventory_confirm"); }

    public void strip() {
        if (IsValidEntity(this.getPrimary()) || IsValidEntity(this.getExplosive())) { this.clearLoadout(); }
    }

    public void onSpawn() {
        this.distance = 0.0;
        this.shotsFired = 0;

        float pos[3];
        this.getPos(pos);
        _lastPos[this.index] = pos;
    }

    public void initialize() {
        this.cacheName();
        this.allowNameChange = false;
        _isReady[this.index] = true;
        _isGod[this.index] = false;
    }
}

////////////////////////////////////////////////////////////////

static void confirmDelay(Player player) { player.confirmLoadout(); }