
public void ParseTransform(const char[] src, float pos[3], float rot[3]) {
	char splitSrc[2][ML_VEC];
	ExplodeString(src, " ", splitSrc, 2, ML_VEC, false);

	ParseVector(splitSrc[0], pos);
	ParseVector(splitSrc[1], rot);
}

public void ParseVector(const char[] vecString, float vector[3]) {
	char components[3][ML_VEC];
	ExplodeString(vecString, ",", components, 3, ML_VEC, false);

	vector[0] = StringToFloat(components[0]);
	vector[1] = StringToFloat(components[1]);
	vector[2] = StringToFloat(components[2]);
}

public void StringToLower(char[] str) {
	for (int n = 0; n < strlen(str); n++) { str[n] = CharToLower(str[n]); }
}

public void StringToUpper(char[] str, int size) {
	for (int n = 0; n < size; n++) { str[n] = CharToUpper(str[n]); }
}

public void OffsetVector(float pos[3], float direction, float distance) {
	pos[0] = pos[0] + (Cosine(direction) * distance);
	pos[1] = pos[1] + (Sine(direction) * distance);
}

public void GetMap(char[] buffer) {
	GetCurrentMap(buffer, ML_MAP);
	StringToLower(buffer);
}

public void CopyVector(float src[3], float dest[3]) {
	for (int i = 0; i < 3; i++) { dest[i] = src[i]; }
}

public int MaxInt(int a, int b) { return (a > b) ? a : b; }
public int MinInt(int a, int b) { return (a < b) ? a : b; }

public int Abs(int value) {
	if (value < 0) { return -value; }
	return value;
}