
#define PRIMARY 0
#define SECONDARY 1
#define MELEE 2
#define EXPLOSIVE 3

static ConVar cv_theater;

static StringMap _weaponID;
static StringMap _weaponType;
static StringMap _weaponUpgrades;
static StringMap _gearID;

static StringMap _upgradeType;

static StringMap _aliases;

enum TheaterParser { theaterParser, };

methodmap TheaterParser {
    public void addAlias(const char[] alias, const char[] item) {
        _aliases.SetString(alias, item, true);
    }

    public bool getFormattedName(const char[] item, int side, char[] buffer) {
        int n;

        if (!_weaponID.GetValue(item, n)) {
            char weaponPrefix[ML_WEAPON] = "weapon_";
            StrCat(weaponPrefix, ML_WEAPON, item);

            if (_weaponID.GetValue(weaponPrefix, n)) {
                strcopy(buffer, ML_WEAPON, weaponPrefix);
                return true;
            }
            else if (!_gearID.GetValue(item, n)) {
                char gearPrefix[ML_WEAPON] = "sec_";
                if (side == INS) { gearPrefix = "ins_"; }
                StrCat(gearPrefix, ML_WEAPON, item);

                if (_gearID.GetValue(gearPrefix, n)) {
                    strcopy(buffer, ML_WEAPON, gearPrefix);
                    return true;
                }
                else if (!_upgradeType.GetValue(item, n)) {
                    if (_aliases.GetString(item, buffer, ML_WEAPON)) {
                        return true;
                    }
                }
            }
        }

        strcopy(buffer, ML_WEAPON, item);
        return false;
    }

    public bool getWeaponName(int id, char[] buffer) {
        StringMapSnapshot snapshot = _weaponID.Snapshot();

        for (int i = 0; i < snapshot.Length; i++) {
            char key[ML_WEAPON];
            snapshot.GetKey(i, key, ML_WEAPON);

            int weaponID;
            _weaponID.GetValue(key, weaponID);

            if (weaponID == id) {
                strcopy(buffer, ML_WEAPON, key);
                snapshot.Close();
                return true;
            }
        }

        snapshot.Close();
        return false;
    }

    public int getWeaponID(const char[] weapon) {
        int id = -1;
        _weaponID.GetValue(weapon, id);
        return id;
    }

    public int getWeaponType(const char[] weapon) {
        int type = -1;
        _weaponType.GetValue(weapon, type);
        return type;
    }

    public int getUpgradeIndex(const char[] upgrade) {
        int index = -1;
        _upgradeType.GetValue(upgrade, index);
        return index;
    }

    public int getUpgradeID(const char[] weapon, const char[] upgrade) {
        int[] upgrades = new int[_upgradeType.Size];
        _weaponUpgrades.GetArray(weapon, upgrades, _upgradeType.Size);
        return upgrades[this.getUpgradeIndex(upgrade)];
    }

    public int getGearID(const char[] gear) {
        int id = -1;
        _gearID.GetValue(gear, id);
        return id;
    }

    public void addWeaponUpgrade(const char[] weapon, int index, int id) {
        int[] upgrades = new int[_upgradeType.Size];
        _weaponUpgrades.GetArray(weapon, upgrades, _upgradeType.Size);

        upgrades[index] = id;
        _weaponUpgrades.SetArray(weapon, upgrades, _upgradeType.Size, true);
    }

    public void addWeapon(const char[] weapon, int id, int type) {
        _weaponID.SetValue(weapon, id, false);
        _weaponType.SetValue(weapon, type, false);
    }

    public void addUpgrade(const char[] upgrade) { _upgradeType.SetValue(upgrade, _upgradeType.Size); }
    public void addGear(const char[] gear, int id) { _gearID.SetValue(gear, id, false); }

    public StringMapSnapshot getWeaponTypeSnapshot() { return _weaponType.Snapshot(); }
    public StringMapSnapshot getGearSnapshot() { return _gearID.Snapshot(); }

    public int getRandomUpgradeID(const char[] weapon) {
        int[] upgrades = new int[_upgradeType.Size];
        _weaponUpgrades.GetArray(weapon, upgrades, _upgradeType.Size);

        ArrayList unrestricted = new ArrayList();

        for (int i = 0; i < _upgradeType.Size; i++) {
            if (upgrades[i] > 0) { unrestricted.Push(upgrades[i]); }
        }

        int randomID = unrestricted.Get(GetRandomInt(0, unrestricted.Length - 1));
        unrestricted.Close();

        return randomID;
    }

    public bool isMelee(const char[] item) { return (this.getWeaponType(item) == MELEE); }
    public bool isPrimary(const char[] item) { return (this.getWeaponType(item) == PRIMARY); }
    public bool isSecondary(const char[] item) { return (this.getWeaponType(item) == SECONDARY); }
    public bool isUpgradable(const char[] item) { return (this.isPrimary(item) || this.isSecondary(item)); }
    public bool isGrenade(const char[] item) { return (this.getWeaponType(item) == EXPLOSIVE); }
    public bool isGear(const char[] item) { return (this.getGearID(item) != -1); }

    public bool isUpgrade(const char[] item) {
        int upgradeIndex;
        return _upgradeType.GetValue(item, upgradeIndex);
    }

    public void populateWeapons(KeyValues kv) {
        kv.Rewind();

        if (kv.JumpToKey("weapons", false)) {
            char weaponName[ML_WEAPON];
            int weaponID = 1;

            kv.GotoFirstSubKey(true);

            do {
                char importedFrom[ML_WEAPON];
                kv.GetString("import", importedFrom, ML_WEAPON, "n/a");

                if (!StrEqual(importedFrom, "n/a")) {
                    kv.GetSectionName(weaponName, ML_WEAPON);

                    if (StrEqual(importedFrom, "ballistic_base", false)) { this.addWeapon(weaponName, weaponID, PRIMARY); }
                    else if (StrEqual(importedFrom, "pistol_base", false)) { this.addWeapon(weaponName, weaponID, SECONDARY); }
                    else if (StrEqual(importedFrom, "weapon_grenade_base", false)) { this.addWeapon(weaponName, weaponID, EXPLOSIVE); }
                    else if (kv.JumpToKey("melee", false)) {
                        this.addWeapon(weaponName, weaponID, MELEE);
                        kv.GoBack();
                    }
                }

                weaponID++;
            }
            while (kv.GotoNextKey(true));
        }
    }

    public void populateUpgrades(KeyValues kv) {
        kv.Rewind();

        if (kv.JumpToKey("weapon_upgrades", false)) {
            char upgradeName[ML_WEAPON];
            int upgradeID = 1;

            kv.GotoFirstSubKey(true);

            do {
                kv.GetSectionName(upgradeName, ML_WEAPON);
                bool isValidUpgrade = true;
                bool isImported = false;

                while (!kv.JumpToKey("allowed_weapons", false) && isValidUpgrade) {
                    isImported = true;
                    char importedFrom[ML_WEAPON];
                    kv.GetString("import", importedFrom, ML_WEAPON, "none");
                    kv.GoBack();

                    if (!kv.JumpToKey(importedFrom, false)) { isValidUpgrade = false; }
                }

                if (isValidUpgrade) {
                    int index = -1;
                    StringMapSnapshot snapshot = _upgradeType.Snapshot();

                    for (int i = 0; i < snapshot.Length; i++) {
                        char key[ML_WEAPON];
                        snapshot.GetKey(i, key, ML_WEAPON);

                        if (StrContains(upgradeName, key, false) != -1) {
                            index = this.getUpgradeIndex(key);
                            break;
                        }
                    }

                    snapshot.Close();

                    if (index != -1) {
                        kv.GotoFirstSubKey(false);

                        do {
                            char weaponName[ML_WEAPON];
                            kv.GetString(NULL_STRING, weaponName, ML_WEAPON, "none");
                            this.addWeaponUpgrade(weaponName, index, upgradeID);
                        }
                        while (kv.GotoNextKey(false));

                        kv.GoBack();
                    }

                    kv.GoBack();

                    if (isImported) {
                        kv.GoBack();
                        kv.JumpToKey(upgradeName);
                    }
                }

                upgradeID++;
            }
            while (kv.GotoNextKey(true));
        }
    }

    public void populateGear(KeyValues kv) {
        kv.Rewind();

        if (kv.JumpToKey("player_gear", false)) {
            char gearName[ML_WEAPON];
            int gearID = 1;

            kv.GotoFirstSubKey(true);

            do {
                kv.GetSectionName(gearName, ML_WEAPON);

                if (StrEqual(gearName, "?nightmap")) {
                    kv.GotoFirstSubKey(true);

                    do {
                        gearID++;
                        kv.GetSectionName(gearName, ML_WEAPON);
                        this.addGear(gearName, gearID);
                    }
                    while (kv.GotoNextKey(true));

                    kv.GoBack();
                }
                else { this.addGear(gearName, gearID); }

                gearID++;
            }
            while (kv.GotoNextKey(true));
        }
    }

    public void setCVars(KeyValues kv) {
        kv.Rewind();

        if (kv.JumpToKey("cvars", false)) {
            kv.GotoFirstSubKey(false);

            do {
                char cvar[ML_MSG];
                kv.GetSectionName(cvar, ML_MSG);

                switch (kv.GetDataType(NULL_STRING)) {
                    case (KvData_Int): { FindConVar(cvar).IntValue = kv.GetNum(NULL_STRING); }
                    case (KvData_Float): { FindConVar(cvar).FloatValue = kv.GetFloat(NULL_STRING); }
                    case (KvData_String): {
                        char stringValue[ML_MSG];
                        kv.GetString(NULL_STRING, stringValue, ML_MSG);

                        FindConVar(cvar).SetString(stringValue);
                    }
                }
            }
            while (kv.GotoNextKey(false));
        }
    }

    public void run() {
        char theaterName[ML_WEAPON];
        cv_theater.GetString(theaterName, ML_WEAPON);

        _weaponID.Clear();
        _weaponType.Clear();
        _weaponUpgrades.Clear();
        _gearID.Clear();

        if (strlen(theaterName) > 0) {
            char theaterPath[PLATFORM_MAX_PATH];
            Format(theaterPath, PLATFORM_MAX_PATH, "Scripts/Theaters/%s.theater", theaterName);

            KeyValues loadedTheater = new KeyValues("LoadedTheater");
            loadedTheater.ImportFromFile(theaterPath);

            this.setCVars(loadedTheater);
            this.populateWeapons(loadedTheater);
            this.populateUpgrades(loadedTheater);
            this.populateGear(loadedTheater);

            loadedTheater.Close();
        }
    }

    public void initialize() {
        cv_theater = FindConVar("mp_theater_override");

        _weaponID = new StringMap();
        _weaponType = new StringMap();
        _weaponUpgrades = new StringMap();
        _gearID = new StringMap();

        _upgradeType = new StringMap();
        _aliases = new StringMap();

        this.addUpgrade("flashlight");
        this.addUpgrade("laser");
        this.addUpgrade("silencer");
        this.addUpgrade("magazine");
        this.addUpgrade("ammo_hp");
        this.addUpgrade("ammo_ap");
        this.addUpgrade("ammo_tracer");
        this.addUpgrade("heavybarrel");
        this.addUpgrade("grip");
        this.addUpgrade("eotech");
        this.addUpgrade("aimpoint");
        this.addUpgrade("2xaimpoint");
        this.addUpgrade("elcan");
        this.addUpgrade("scope_mk4");
        this.addUpgrade("kobra");
        this.addUpgrade("po4x24");
        this.addUpgrade("scope_7x");
        this.addUpgrade("smoke");

        this.addAlias("suppressor", "silencer");
        this.addAlias("extended_mag", "magazine");
        this.addAlias("speed_loader", "magazine");
        this.addAlias("hp", "ammo_hp");
        this.addAlias("ap", "ammo_ap");
        this.addAlias("tracer", "ammo_tracer");
        this.addAlias("heavy_barrel", "heavybarrel");
        this.addAlias("foregrip", "grip");
        this.addAlias("holo", "eotech");
        this.addAlias("c79", "elcan");
        this.addAlias("red_dot", "aimpoint");
        this.addAlias("2x_red_dot", "2xaimpoint");
        this.addAlias("mk4_scope", "scope_mk4");
        this.addAlias("7x_scope", "scope_7x");
        this.addAlias("smoke_launcher", "smoke");
        this.addAlias("smoke_gl", "smoke");
        this.addAlias("m203", "smoke");
        this.addAlias("gp25", "smoke");

        this.addAlias("m16", "weapon_m16a4");
        this.addAlias("ac556", "weapon_mini14");
        this.addAlias("khukuri", "weapon_gurkha");
    }
}