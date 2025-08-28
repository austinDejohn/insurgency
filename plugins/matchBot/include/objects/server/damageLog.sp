
#define DLOG_DMG_STR_LEN 24
#define DLOG_KILL_STR_LEN 17
#define DLOG_FORMAT "\x01%s ---- \x03%N\x01%s"
#define DLOG_FORMAT_TEAMKILL "\x01%s ---- %N%s"
#define DLOG_FORMAT_SUICIDE "\x01[\x03%i\x01/\x03%i\x01] ---- %N%s"

static int _damage[MAXPLAYERS][MAXPLAYERS];
static int _hits[MAXPLAYERS][MAXPLAYERS];
static int _kills[MAXPLAYERS][MAXPLAYERS];
static float _lastDamageTime[MAXPLAYERS][MAXPLAYERS];

enum DamageLog { damageLog, };

methodmap DamageLog {
    public void onFallDamageWarmup(Player victim, int damage) {
        victim.chatFromSource(
            Team(victim.side).other.getChatSource(),
            "\x01[\x03%i\x01/\x031\x01] ---- Gravity",
            damage
        );
    }

    public void onDamageWarmup(Player attacker, Player victim, int damage) {
        float time = GetTickedTime();

        if (time - 0.5 > _lastDamageTime[attacker.index][victim.index]) {
            _lastDamageTime[attacker.index][victim.index] = time;

            if (attacker != victim) {
                float aPos[3], vPos[3];
                attacker.getPos(aPos);
                victim.getPos(vPos);

                float distance = (GetVectorDistance(aPos, vPos, false) * 19.05) / 1000;

                char aName[ML_NAME + 2], vName[ML_NAME + 2];
                attacker.getName(aName, ML_NAME + 2);
                victim.getName(vName, ML_NAME + 2);

                if (attacker.side != victim.side) {
                    Format(aName, ML_NAME + 2, "\x03%s\x01", aName);
                    Format(vName, ML_NAME + 2, "\x03%s\x01", vName);
                }

                attacker.chatFromSource(
                    victim.index,
                    "\x01[%i/1] ---- %s ---- (%.1fm)",
                    damage, vName, distance
                );

                victim.chatFromSource(
                    attacker.index,
                    "\x01[\x03%i\x01/\x031\x01] ---- %s ---- (%.1fm)",
                    damage, aName, distance
                );
            }
            else {
                int src = Team(victim.side).other.getChatSource();
                victim.chatFromSource(src, "\x01[\x03%i\x01/\x031\x01] ---- %N", damage, victim);
            }
        }
    }

    public void onDamage(Player attacker, Player victim, int damage) {
        _damage[attacker.index][victim.index] += damage;
        _hits[attacker.index][victim.index]++;
    }

    public void onKill(Player attacker, Player victim) {
        _kills[attacker.index][victim.index]++;
    }

    public void print() {
        for (int i = 1; i <= MaxClients; i++) {
            Player player = Player(i);

            if (player.isValid) {
                for (int n = i + 1; n <= MaxClients; n++) {
                    Player other = Player(n);

                    if (other.isValid) {
                        if (_hits[i][n] > 0 || _hits[n][i] > 0) {
                            printLineForEach(
                                player,
                                other,
                                _damage[i][n],
                                _hits[i][n],
                                _kills[i][n],
                                _damage[n][i],
                                _hits[n][i],
                                _kills[n][i]
                            )
                        }
                    }
                }

                if (_hits[i][i] > 0 || _kills[i][i] > 0) {
                    char deathStr[14];
                    if (_kills[i][i] > 0) { Format(deathStr, 14, " ---- (%i)", _kills[i][i]); }

                    player.chatFromSource(
                        match.getTeam(player).other.getChatSource(),
                        DLOG_FORMAT_SUICIDE,
                        _damage[i][i],
                        _hits[i][i],
                        i,
                        deathStr
                    );
                }
            }
        }
    }

    public void initialize() {
        for (int i = 1; i <= MaxClients; i++) {
            _damage[i][i] = 0;
            _hits[i][i] = 0;
            _kills[i][i] = 0;

            for (int n = i + 1; n <= MaxClients; n++) {
                _damage[i][n] = 0;
                _damage[n][i] = 0;
                _hits[i][n] = 0;
                _hits[n][i] = 0;
                _kills[i][n] = 0;
                _kills[n][i] = 0;
            }
        }
    }
}

////////////////////////////////////////////////////////////////

static void printLineForEach(Player a, Player b, int aDmg, int aHits, int aKills, int bDmg, int bHits, int bKills) {
    char aDmgStr[DLOG_DMG_STR_LEN], bDmgStr[DLOG_DMG_STR_LEN];
    char aKillStr[DLOG_KILL_STR_LEN], bKillStr[DLOG_KILL_STR_LEN];

    if (aHits > 0) {
        Format(aDmgStr, DLOG_DMG_STR_LEN, "[%i/%i]", aDmg, aHits);
        Format(bDmgStr, DLOG_DMG_STR_LEN, "[\x03%i\x01/\x03%i\x01]", aDmg, aHits);
    }

    if (bHits > 0) {
        Format(aDmgStr, DLOG_DMG_STR_LEN, "%s[\x03%i\x01/\x03%i\x01]", aDmgStr, bDmg, bHits);
        Format(bDmgStr, DLOG_DMG_STR_LEN, "[%i/%i]%s", bDmg, bHits, bDmgStr);
    }

    if (aKills > 0 || bKills > 0) {
        Format(aKillStr, DLOG_KILL_STR_LEN, " ---- (%i - %i)", aKills, bKills);
        Format(bKillStr, DLOG_KILL_STR_LEN, " ---- (%i - %i)", bKills, aKills);
    }

    if (a.side != b.side) {
        a.chatFromSource(b.index, DLOG_FORMAT, aDmgStr, b.index, aKillStr);
        b.chatFromSource(a.index, DLOG_FORMAT, bDmgStr, a.index, bKillStr);
    }
    else {
        int src = Team(a.side).other.getChatSource();
        a.chatFromSource(src, DLOG_FORMAT_TEAMKILL, aDmgStr, b.index, aKillStr);
        b.chatFromSource(src, DLOG_FORMAT_TEAMKILL, bDmgStr, a.index, bKillStr);
    }
}