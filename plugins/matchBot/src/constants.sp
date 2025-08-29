
#define PLUGIN_NAME "MatchBot"
#define PLUGIN_AUTHOR "Outlawled"
#define PLUGIN_VERSION "1.0.1"

#define ML_NAME MAX_NAME_LENGTH
#define ML_PATH PLATFORM_MAX_PATH
#define ML_TEAM 30
#define ML_CMD 32
#define ML_ACTION 64
#define ML_DESC 256
#define ML_MSG 128
#define ML_EVENT 128
#define ML_MAP 48
#define ML_MATCH 64
#define ML_HITGROUP 12

#define CMD_PLAYERS_ONLY 0
#define CMD_SPEC_ONLY 1
#define CMD_ANY 2

#define REMINDER_VOTE "Your team is voting to forfeit, type .yes or .no to cast your vote"
#define REMINDER_READY_UP "Type .ready to ready up"
#define PREFIX_NOT_READY "... "

#define SEC 2
#define INS 3

#define ALPHA (SEC - SEC)
#define BRAVO (INS - SEC)

#define SLOT_PRIMARY 0
#define SLOT_SECONDARY 1
#define SLOT_MELEE 2
#define SLOT_EXPLOSIVE 3

#define MIN_DISTANCE 157.48
#define DISTANCE_CHECK_FREQUENCY 1.0

#define EVENT_ROUND_START "round_start"
#define EVENT_ROUND_END "round_end"
#define EVENT_SPAWN "spawn"
#define EVENT_DESPAWN "despawn"
#define EVENT_DAMAGE "damage"
#define EVENT_KILL "kill"
#define EVENT_OBJ_CAP "obj_cap"
#define EVENT_OBJ_ENTER "obj_enter"
#define EVENT_OBJ_EXIT "obj_exit"
#define EVENT_THROW "throw"
#define EVENT_DETONATE "detonate"

#define OBJ_RESOURCE "ins_objective_resource"

//char sideName[][] = {"????", "Spectators", "Security", "Insurgents"};
