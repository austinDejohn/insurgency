
methodmap Player {
	public Player(int client) {
		if (client > 0 && client <= MaxClients && IsClientInGame(client) && IsClientAuthorized(client)) { return view_as<Player>(client); }
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
		public set(bool value) {
			SetEntProp(GetPlayerResourceEntity(), Prop_Send, "m_bAlive", view_as<int>(value), 1, this.index);
		}
	}

	property bool isGod {
		public get() { GetEntProp(this.index, Prop_Data, "m_takedamage"); }
		public set(bool value) { SetEntProp(this.index, Prop_Data, "m_takedamage", value); }
	}

	property int deaths {
		public get() { GetEntProp(this.index, Prop_Data, "m_iDeaths"); }
		public set(int value) { SetEntProp(this.index, Prop_Data, "m_iDeaths", value); }
	}

	property int side {
		public get() { return GetClientTeam(this.index); }
	}

	public int getTargetSide() {
		int side = this.side;
		if (side >= SEC) { return side; }

		Player target = Player(GetEntPropEnt(this.index, Prop_Send, "m_hObserverTarget"));
		if (target.isValid) { return target.side; }

		return 0;
	}

	public void teleport(float pos[3], float rot[3]) { TeleportEntity(this.index, pos, rot, NULL_VECTOR); }

	public void onSpawn() {
		float pos[3];
		float rot[3];

		Spawn spawn = GetNextSpawn(this.side);

		if (spawn.isValid) {
			spawn.getPosition(pos);
			spawn.getRotation(rot);

			this.teleport(pos, rot);
		}
	}

	public void onDeath() {
		this.isAlive = false;
		if (IsMidRound()) { EndRoundIfTeamEliminated(); }
	}

	public void playSound(const char[] path) { ClientCommand(this.index, "playgamesound \"%s\"", path); }

	public int getId() { return GetClientUserId(this.index); }

	public void getPos(float pos[3]) { GetEntPropVector(this.index, Prop_Data, "m_vecOrigin", pos); }
	public void getDir(float dir[3]) { GetEntPropVector(this.index, Prop_Data, "m_angEyeAngles", dir); }

	property bool isSecurity {
		public get() { return (this.side == SEC); }
	}

	property bool isInsurgent {
		public get() { return (this.side == INS); }
	}

	property bool isSpectator {
		public get() {
			if (this.side >= SEC || GetEntProp(this.index, Prop_Data, "m_iPendingTeamNum") >= SEC) { return false; }
			return true;
		}
	}
}
