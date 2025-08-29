
static ArrayList spawnPositions;
static ArrayList spawnRotations;

static ArrayList spawnSecInstances;
static ArrayList spawnInsInstances;

static int spawnLastUsed[INS + 1] = {0, 0, 0, 0};
static float spawnArea[INS + 1][3] = {{0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}, {0.0, 0.0, 0.0}};

static ArrayList spawnDefaultZones;

methodmap Spawn {
	public Spawn(int side, const float pos[3], const float rot[3]) {
		if (side != SEC && side != INS) { return view_as<Spawn>(-1); }

		Spawn newSpawn = view_as<Spawn>(spawnPositions.Length);

		spawnPositions.PushArray(pos);
		spawnRotations.PushArray(rot);

		if (side == SEC) { spawnSecInstances.Push(newSpawn); }
		else { spawnInsInstances.Push(newSpawn); }

		spawnArea[side][0] += pos[0];
		spawnArea[side][1] += pos[1];
		spawnArea[side][2] += pos[2];

		return newSpawn;
	}

	property int index {
		public get() { return view_as<int>(this); }
	}

	property bool isValid {
		public get() { return (this.index != -1); }
	}

	public void getPosition(float pos[3]) { spawnPositions.GetArray(this.index, pos, 3); }
	public void getRotation(float rot[3]) { spawnRotations.GetArray(this.index, rot, 3); }
}

public void ClearSpawns() {
	if (spawnPositions == null) {
		spawnPositions = new ArrayList(3);
		spawnRotations = new ArrayList(3);
		spawnSecInstances = new ArrayList();
		spawnInsInstances = new ArrayList();
		spawnDefaultZones = new ArrayList();
	}
	else {
		spawnPositions.Clear();
		spawnRotations.Clear();
		spawnSecInstances.Clear();
		spawnInsInstances.Clear();
		spawnDefaultZones.Clear();
	}

	spawnLastUsed[SEC] = GetRandomInt(0, 4);
	spawnLastUsed[INS] = GetRandomInt(0, 4);

	for (int i = SEC; i <= INS; i++) {
		for (int n = 0; n < 3; n++) { spawnArea[i][n] = 0.0; }
	}

	hasCustomSpawns = false;
}

public Spawn GetNextSpawn(int side) {
	if (side == SEC && spawnSecInstances.Length != 0) {
		spawnLastUsed[SEC] = (spawnLastUsed[SEC] + 1) % spawnSecInstances.Length;
		return spawnSecInstances.Get(spawnLastUsed[SEC]);
	}
	else if (side == INS && spawnInsInstances.Length != 0) {
		spawnLastUsed[INS] = (spawnLastUsed[INS] + 1) % spawnInsInstances.Length;
		return spawnInsInstances.Get(spawnLastUsed[INS]);
	}

	return view_as<Spawn>(-1);
}

public void FinalizeSpawnAreas() {
	if (spawnSecInstances.Length != 0 && spawnInsInstances.Length != 0) {
		for (int i = 0; i < 3; i++) { spawnArea[SEC][i] /= spawnSecInstances.Length; }
		for (int i = 0; i < 3; i++) { spawnArea[INS][i] /= spawnInsInstances.Length; }
		hasCustomSpawns = true;
	}
}

public void InitializeZones() {
	if (hasCustomSpawns) {
		char spawnAreaModel[8];
		GetSpawnAreaModel(spawnAreaModel, sizeof(spawnAreaModel));

		for (int i = MaxClients; i < GetEntityCount(); i++) {
			if (IsDefaultZone(i)) { AcceptEntityInput(i, "disable"); }
		}

		CreateSpawnArea(SEC, spawnArea[SEC], spawnAreaModel);
		CreateSpawnArea(INS, spawnArea[INS], spawnAreaModel);
	}
}

public bool IsDefaultZone(int entity) {
	if (!IsValidEdict(entity)) { return false; }

	char classname[16];
	GetEntityClassname(entity, classname, sizeof(classname));

	if (StrEqual(classname, "func_buyzone") || StrEqual(classname, "ins_spawnzone") || StrEqual(classname, "ins_blockzone")) {
		return GetEntProp(entity, Prop_Data, "m_bDisabled") == 0;
	}

	return false;
}

public void CreateSpawnArea(int side, const float pos[3], const char[] model) {
	int entity = CreateEntityByName("ins_spawnzone");
	DispatchSpawn(entity);
	ActivateEntity(entity);
	TeleportEntity(entity, pos, NULL_VECTOR, NULL_VECTOR);
	SetEntityModel(entity, model);
	SetEntProp(entity, Prop_Send, "m_nSolidType", 2);
	SetEntProp(entity, Prop_Send, "m_iTeamNum", side);
}

public void GetSpawnAreaModel(char[] buffer, int bufferSize) {
	int entity = FindEntityByClassname(-1, "ins_spawnzone");
	int bestEntity = -1;
	float bestError = -1.0;
	float minVec[3];
	float maxVec[3];
	float targetLength = 1000.0;

	while (IsValidEdict(entity)) {
		GetEntPropVector(entity, Prop_Send, "m_vecMins", minVec);
		GetEntPropVector(entity, Prop_Send, "m_vecMaxs", maxVec);

		float w = FloatAbs(minVec[0]) + FloatAbs(maxVec[0]);
		float h = FloatAbs(minVec[1]) + FloatAbs(maxVec[1]);

		float error = FloatAbs(targetLength - w) + FloatAbs(targetLength - h);

		if (error < bestError || bestError < 0) {
			bestError = error;
			bestEntity = entity;
		}

		entity = FindEntityByClassname(entity, "ins_spawnzone");
	}

	if (bestEntity != -1) { GetEntPropString(bestEntity, Prop_Data, "m_ModelName", buffer, bufferSize); }
}
