
static int objInitialSide[OBJ_C + 1] = {0, 0, 0};
static int objPlayerCount[OBJ_C + 1][INS + 1] = {{0, 0, 0, 0}, {0, 0, 0, 0}, {0, 0, 0, 0}};
static bool objDecapTimerActive[OBJ_C + 1] = {false, false, false};

methodmap Objective {
	public Objective(int index) { return view_as<Objective>(index); }

	property int index {
		public get() { return view_as<int>(this); }
	}

	property bool isValid {
		public get() { return this.index != -1; }
	}

	property int initialSide {
		public get() { return objInitialSide[this.index]; }
		public set(int value) { objInitialSide[this.index] = value; }
	}

	property bool isEnabled {
		public get() { return objInitialSide[this.index] != -1; }
	}

	property int countSec {
		public get() { return objPlayerCount[this.index][SEC]; }
	}

	property int countIns {
		public get() { return objPlayerCount[this.index][INS]; }
	}

	property int side {
		public get() { return GetEntProp(objRscEnt, Prop_Send, "m_iOwningTeam", 1, this.index); }
		public set(int value) { SetEntProp(objRscEnt, Prop_Send, "m_iOwningTeam", value, 1, this.index); }
	}

	property float percent {
		public get() { return GetEntPropFloat(objRscEnt, Prop_Send, "m_flLazyCapPerc", this.index); }
		public set(float value) { SetEntPropFloat(objRscEnt, Prop_Send, "m_flLazyCapPerc", value, this.index); }
	}

	property bool isLockedSec {
		public get() { return view_as<bool>(GetEntProp(objRscEnt, Prop_Send, "m_bSecurityLocked", 1, this.index)); }
		public set(bool value) { SetEntProp(objRscEnt, Prop_Send, "m_bSecurityLocked", view_as<int>(value), 1, this.index); }
	}

	property bool isLockedIns {
		public get() { return view_as<bool>(GetEntProp(objRscEnt, Prop_Send, "m_bInsurgentsLocked", 1, this.index)); }
		public set(bool value) { SetEntProp(objRscEnt, Prop_Send, "m_bInsurgentsLocked", view_as<int>(value), 1, this.index); }
	}

	property bool isLocked {
		public get() { return this.isLockedSec && this.isLockedIns; }

		public set(bool value) {
			this.isLockedSec = value;
			this.isLockedIns = value;
		}
	}

	property bool decapTimerActive {
		public get() { return objDecapTimerActive[this.index]; }
		public set(bool value) { objDecapTimerActive[this.index] = value; }
	}

	public int countPlayers(int side) {
		if (IsNeutral(side)) { return this.countSec + this.countIns; }
		return objPlayerCount[this.index][side];
	}

	public bool isContested() {
		return this.percent != 0.0 || this.countPlayers(GetOpponent(this.side)) > 0;
	}
	/*
	public bool isBeingCapped() {
		if (this.isContested()) {
			int side = this.side;

			if (IsNeutral(side)) { return (this.countSec == 0 || this.countIns == 0); }
			else { return (this.countPlayers(side) == 0); }
		}

		return false;
	}
	*/
	public bool isActivelyCapping() {
		int side = this.side;

		if (IsNeutral(side)) {
			if (this.countSec == 0) { return this.countIns > 0; }
			return this.countIns == 0;
		}

		return this.countPlayers(side) == 0 && this.countPlayers(GetOpponent(side)) > 0;
	}

	public bool isLockedFor(int side) {
		if (side == SEC) { return this.isLockedSec; }
		if (side == INS) { return this.isLockedIns; }
		return false;
	}

	public void lockFor(int side) {
		if (side == SEC) { this.isLockedSec = true; }
		if (side == INS) { this.isLockedIns = true; }
	}

	public void unlockFor(int side) {
		if (side == SEC) { this.isLockedSec = false; }
		if (side == INS) { this.isLockedIns = false; }
	}

	public void reset() {
		objPlayerCount[this.index][SEC] = 0;
		objPlayerCount[this.index][INS] = 0;
		this.decapTimerActive = false;
	}

	public bool doCheckForDecap() {
		if (IsNeutral(this.side)) { return false; }

		int dCount = this.countPlayers(this.side);
		int aCount = this.countPlayers(GetOpponent(this.side));

		if (aCount > dCount) { return false; }
		if (aCount == dCount) { return this.percent == 0.0; }

		return aCount > 0 || this.percent > 0.0;
	}

	public void onPlayerCountChanged() {
		if (!this.decapTimerActive && this.doCheckForDecap()) {
			this.decapTimerActive = true;
			CreateTimer(0.1, CheckForDecap, this.index, TIMER_REPEAT);
		}

		UpdateRoundPauseState();
	}

	public void onEntered(Player player) {
		if (this.isEnabled) {
			if (!cfg_concurrentCaps.BoolValue) {
				if (!this.isLockedFor(player.side) && player.side != defenders) {
					for (int i = OBJ_A; i <= OBJ_C; i++) {
						if (i != this.index) {
							Objective obj = Objective(i);
							if (obj.isEnabled) { obj.lockFor(player.side); }
						}
					}
				}
			}

			objPlayerCount[this.index][player.side]++;
			this.onPlayerCountChanged();
		}
	}

	public void onExited(Player player) {
		if (this.isEnabled) {
			if (!cfg_concurrentCaps.BoolValue) {
				if (!this.isLockedFor(player.side) && player.side != defenders) {
					for (int i = OBJ_A; i <= OBJ_C; i++) {
						if (i != this.index) {
							Objective obj = Objective(i);

							if (obj.isEnabled) {
								obj.unlockFor(player.side);

								if (obj.countPlayers(player.side) > 0) {
									this.lockFor(player.side);
									break;
								}
							}
						}
					}
				}
			}

			objPlayerCount[this.index][player.side]--;
			this.onPlayerCountChanged();
		}
	}

	public void onCapped(int side) {
		this.side = side;
		this.percent = 0.0;

		if (!EndRoundIfTeamHasControl()) {
			ResetRoundTimer();
			UpdateRoundPauseState();
		}
	}

	public void onDecapped() {
		this.percent = 0.0;
		if (!EndRoundIfTeamHasControl()) { UpdateRoundPauseState(); }
	}
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

public void InitializeObjectives() {
	objRscEnt = FindEntityByClassname(-1, "ins_objective_resource");
	int entity = FindEntityByClassname(-1, "point_controlpoint");

	while (IsValidEdict(entity)) {
		int side = GetEntProp(entity, Prop_Data, "m_iTeamNum");
		Objective obj;

		if (side == SEC) {
			obj = Objective(OBJ_A);

			if (obj.isEnabled) {
				if (IsNeutral(obj.initialSide)) { AcceptEntityInput(entity, "Reset"); }
				else if (obj.initialSide == INS) {
					SetVariantInt(INS);
					AcceptEntityInput(entity, "SetOwner");
				}
			}
			else {
				AcceptEntityInput(entity, "Reset");
				obj.isLocked = true;
			}
		}
		else if (side == INS) {
			obj = Objective(OBJ_C);

			if (obj.isEnabled) {
				if (IsNeutral(obj.initialSide)) { AcceptEntityInput(entity, "Reset"); }
				else if (obj.initialSide == SEC) {
					SetVariantInt(SEC);
					AcceptEntityInput(entity, "SetOwner");
				}
			}
			else {
				AcceptEntityInput(entity, "Reset");
				obj.isLocked = true;
			}
		}
		else {
			obj = Objective(OBJ_B);

			if (obj.isEnabled) {
				if (!IsNeutral(obj.initialSide)) {
					SetVariantInt(obj.initialSide);
					AcceptEntityInput(entity, "SetOwner");
				}
			}
			else { obj.isLocked = true; }
		}

		entity = FindEntityByClassname(entity, "point_controlpoint");
	}

	/*
	if (Objective(OBJ_A).isEnabled) {
		if (Objective(OBJ_B).isEnabled) {
			if (!Objective(OBJ_C).isEnabled) { SetEntProp(objRscEnt, Prop_Send, "m_iNumControlPoints", 2); }
		}
		else if (!Objective(OBJ_C).isEnabled) { SetEntProp(objRscEnt, Prop_Send, "m_iNumControlPoints", 1); }
	}
	else { SetEntPropVector(objRscEnt, Prop_Send, "m_vCPPositions", view_as<float>({-10000.0, -10000.0, -10000.0})); }
	*/
}

public Action CheckForDecap(Handle timer, any objIndex) {
	Objective obj = Objective(objIndex);

	if (IsMidRound()) {
		if (obj.doCheckForDecap()) { return Plugin_Continue; }
		if (obj.percent == 0.0) { obj.onDecapped(); }
	}

	obj.decapTimerActive = false;
	return Plugin_Stop;
}
