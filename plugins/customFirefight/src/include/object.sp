
static ArrayList objModel;
static ArrayList objPosition;
static ArrayList objRotation;
static ArrayList objIsVisible;

static ArrayList objEntities;

methodmap Object {
	public Object(const char[] model, const float pos[3], const float rot[3], bool isVisible) {
		objModel.PushString(model);
		objPosition.PushArray(pos);
		objRotation.PushArray(rot);
		objIsVisible.Push(isVisible);

		return view_as<Object>(objModel.Length - 1);
	}

	property int index {
		public get() { return view_as<int>(this); }
	}

	public void getModel(char[] buffer) { objModel.GetString(this.index, buffer, ML_MODEL); }
	public void getPosition(float pos[3]) { objPosition.GetArray(this.index, pos, 3); }
	public void getRotation(float rot[3]) { objRotation.GetArray(this.index, rot, 3); }
	public bool isVisible() { return objIsVisible.Get(this.index); }

	public void spawn() {
		char model[ML_MODEL];
		float pos[3];
		float rot[3];

		this.getModel(model);
		this.getPosition(pos);
		this.getRotation(rot);

		int entity = CreateEntityByName("prop_dynamic_override");
		objEntities.Push(entity);

		DispatchKeyValue(entity, "model", model);
		DispatchKeyValue(entity, "solid", "6");
		SetEntityModel(entity, model);
		DispatchSpawn(entity);

		if (!this.isVisible()) {
			AcceptEntityInput(entity, "DisableShadow");
			SetEntityRenderMode(entity, RENDER_NONE);
		}

		TeleportEntity(entity, pos, rot, NULL_VECTOR);
	}
}

public void ClearObjects() {
	if (objModel == null) {
		objModel = new ArrayList(ML_MODEL);
		objPosition = new ArrayList(3);
		objRotation = new ArrayList(3);
		objIsVisible = new ArrayList();
		objEntities = new ArrayList();
	}
	else {
		objModel.Clear();
		objPosition.Clear();
		objRotation.Clear();
		objIsVisible.Clear();

		KillEntities();
	}
}

public void SpawnAllObjects() {
	objEntities.Clear();
	for (int i = 0; i < objModel.Length; i++) { (view_as<Object>(i)).spawn(); }
}

public void KillEntities() {
	for (int i = 0; i < objEntities.Length; i++) {
		int entity = objEntities.Get(i);
		if (IsValidEdict(entity)) { AcceptEntityInput(entity, "kill"); }
	}

	objEntities.Clear();
}
