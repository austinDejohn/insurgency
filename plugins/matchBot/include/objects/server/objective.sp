
static int _resource = -1;

enum Objective {
    objA = view_as<Objective>(0),
    objB = view_as<Objective>(1),
    objC = view_as<Objective>(2),
};

methodmap Objective {
    property int index {
        public get() { return view_as<int>(this); }
    }

    property bool isValid {
        public get() { return this.index > -1 && this.index < 4; }
    }

    property int resource {
        public get() {
            if (!isResourceValid()) { _resource = FindEntityByClassname(-1, OBJ_RESOURCE); }
            return _resource;
        }
    }

    property Team owner {
        public get() { return Team(GetEntProp(this.resource, Prop_Send, "m_iOwningTeam", 1, this.index)); }
    }

    public bool isLocked(int side) {
        if (!isValidSide(side)) { return true; }

        return view_as<bool>(
            GetEntProp(this.resource, Prop_Send, (side == SEC) ? "m_bSecurityLocked" : "m_bInsurgentsLocked", 1, this.index)
        );
    }
}

static bool isResourceValid() {
    if (!IsValidEntity(_resource)) { return false; }

    char classname[24];
    GetEntityClassname(_resource, classname, 24);

    return StrEqual(classname, OBJ_RESOURCE);
}