
public void initializeConVars() {
    cv_muteAmbient = CreateConVar(
        "sve_mute_ambient_sounds",
        "1",
        "Whether ambient sounds should be muted",
        FCVAR_NOTIFY,
        true,
        0.0,
        true,
        1.0
    );

    cv_fogLevel = CreateConVar(
        "sve_fog_level",
        "0",
        "Level of fog on map (0 for none, 1 for default, 2 for thicc)",
        FCVAR_NOTIFY,
        true,
        0.0,
        true,
        2.0
    );

    cv_deleteProps = CreateConVar(
        "sve_delete_props",
        "1",
        "Whether physics props, car windows, sprinklers, and fires should be deleted",
        FCVAR_NOTIFY,
        true,
        0.0,
        true,
        1.0
    );

    cv_execOnce = CreateConVar("sve_exec_once", "", "Executes the given command on the first map load only");

    HookEvent("round_start", onPreRound, EventHookMode_PostNoCopy);

    cv_muteAmbient.AddChangeHook(muteAmbientHook);
    AddAmbientSoundHook(blockAmbientSound);
    isAmbientBlocked = true;

    cv_execOnce.AddChangeHook(execOnceHook);
}

public void execOnceHook(ConVar convar, const char[] oldValue, const char[] newValue) {
    ServerCommand(newValue);
}

public void muteAmbientHook(ConVar convar, const char[] oldValue, const char[] newValue) {
    int value = StrEqual(newValue, "0") ? 0 : (StrEqual(newValue, "1") ? 1 : -1);

    if (value < 0) {
        cv_muteAmbient.BoolValue = isAmbientBlocked;
    }
    else if (isAmbientBlocked) {
        if (value == 0) {
            RemoveAmbientSoundHook(blockAmbientSound);
            isAmbientBlocked = false;
        }
    }
    else if (value == 1) {
        AddAmbientSoundHook(blockAmbientSound);
        isAmbientBlocked = true;
    }
}

public Action blockAmbientSound(char sample[ML_PATH], int &entity, float &volume, int &level, int &pitch, float pos[3], int &flags, float &delay) {
    return Plugin_Stop;
}

public void initializeFog() {
    if (cv_fogLevel.IntValue != FOG_DEFAULT) {
        if (cv_fogLevel.IntValue == FOG_THICC) {
            ServerCommand("sv_skyname mino_sky01");
        }

        for (int i = MaxClients + 1; i < GetEntityCount(); i++) {
            if (IsValidEdict(i)) {
                char classname[20];
                if (GetEntityClassname(i, classname, sizeof(classname))) {
                    if (StrEqual(classname, "env_fog_controller")) {
                        if (cv_fogLevel.IntValue == FOG_THICC) {
                            SetEntPropFloat(i, Prop_Data, "m_fog.start", -200.0);
                            SetEntPropFloat(i, Prop_Data, "m_fog.end", 1400.0);
                            SetEntProp(i, Prop_Data, "m_fog.colorPrimary", FOG_COLOR);
                            SetEntProp(i, Prop_Data, "m_fog.colorSecondary", FOG_COLOR);
                        }
                        else {
                            SetEntPropFloat(i, Prop_Data, "m_fog.start", 2000.0);
                        }

                        SetEntPropFloat(i, Prop_Data, "m_fog.maxdensity", 0.95);
                    }
                }
            }
        }
    }
}

public void deleteProps() {
    for (int i = MaxClients + 1; i < GetEntityCount(); i++) {
        if (doKillEntity(i)) { AcceptEntityInput(i, "kill"); }
    }
}

public bool doKillEntity(int entity) {
    if (!IsValidEntity(entity)) { return false; }

    char classname[24];
    if (!GetEntityClassname(entity, classname, sizeof(classname))) { return false; }

    if (StrEqual(classname, "prop_dynamic")) {
        char model[ML_PATH];
        GetEntPropString(entity, Prop_Data, "m_ModelName", model, ML_PATH);
        return StrContains(model, "window") != -1;
    }

    return (StrEqual(classname, "prop_physics") ||
        StrEqual(classname, "prop_sprinkler") ||
        StrEqual(classname, "info_particle_system") ||
        StrEqual(classname, "trigger_hurt")
    );
}