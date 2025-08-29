
public bool isValidSide(int side) { return side == SEC || side == INS; }
public int getClientSide(int client) { return GetClientTeam(client); }

////////////////////////////////////////////////////////////////

stock int abs(int value) { return value < 0 ? -value : value; }

stock int min(int a, int b) { return a < b ? a : b; }
stock int max(int a, int b) { return a > b ? a : b; }

stock int clamp(int val, int minVal, int maxVal) { return min(max(val, minVal), maxVal); }

stock float minFloat(float a, float b) { return a < b ? a : b; }
stock float maxFloat(float a, float b) { return a > b ? a : b; }

stock float clampFloat(float val, float minVal, float maxVal) { return minFloat(maxFloat(val, minVal), maxVal); }

////////////////////////////////////////////////////////////////

stock void stringToLower(char[] str) {
    for (int n = 0; n < strlen(str); n++) { str[n] = CharToLower(str[n]); }
}

stock void stringToUpper(char[] str) {
    for (int n = 0; n < strlen(str); n++) { str[n] = CharToUpper(str[n]); }
}

stock void copyToLower(const char[] src, char[] buffer, int bufferSize) {
    strcopy(buffer, bufferSize, src);
    stringToLower(buffer);
}

////////////////////////////////////////////////////////////////

public int countFilesInDirectory(const char[] dir) {
    DirectoryListing listing = OpenDirectory(dir);
    int fileCount = 0;

    if (listing != null) {
        char file[ML_PATH];
        FileType type = FileType_Directory;

        while (listing.GetNext(file, ML_PATH, type)) {
            if (type == FileType_File) { fileCount++; }
        }

        listing.Close();
    }

    return fileCount;
}

public void cleanUpDirectory(const char[] dir, int fileCountMax) {
    int fileCount = countFilesInDirectory(dir);

    if (fileCount > fileCountMax) {
        DirectoryListing listing = OpenDirectory(dir);

        if (listing != null) {
            char file[ML_PATH];
            FileType type;

            while (fileCount > fileCountMax && listing.GetNext(file, ML_PATH, type)) {
                if (type == FileType_File) {
                    Format(file, ML_PATH, "%s/%s", dir, file);

                    if (DeleteFile(file)) { fileCount--; }
                    else {
                        LogError("Unable to delete file: %s", file);
                        fileCount = fileCountMax;
                    }
                }
            }

            listing.Close();
        }
    }
}
