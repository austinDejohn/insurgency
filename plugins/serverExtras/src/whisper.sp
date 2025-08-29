
#define MAX_PREFIX_LENGTH (MAX_NAME_LENGTH + 10)
#define ERROR_EMPTY_WHISPER "You cannot whisper sweet nothings, only sweet somethings. Please type a message to send to %N."

static StringMap _lastWhisperer;

public void initializeWhisper() {
    _lastWhisperer = new StringMap();

    ChatCmd(
        "w",
        onCmdWhisper,
        "<partial name> <message>",
        "Sends a whisper to the specified player (partial name should not have spaces)",
        CmdAccess_All,
        false,
        true
    )
    .alias("whisper");

    ChatCmd(
        "reply",
        onCmdReply,
        "<message>",
        "Sends a whisper to the last player who sent the caller a whisper",
        CmdAccess_All,
        false,
        true
    );
}

public void onCmdWhisper(int client, ChatCmd cmd, const char[] args) {
    char splitArgs[2][ML_MSG];
    int argCount = ExplodeString(args, " ", splitArgs, 2, ML_MSG, true);

    int recipient = getClientFromPartialName(splitArgs[0]);

    if (recipient != -1) {
        if (argCount == 2) {
            whisper(client, recipient, splitArgs[1]);
        }
        else {
            PrintToChat(client, ERROR_EMPTY_WHISPER, recipient);
        }
    }
    else {
        PrintToChat(client, "Unable to find a player whose name contains '%s'", splitArgs[0]);
    }
}

public void onCmdReply(int client, ChatCmd cmd, const char[] args) {
    int recipient = getLastWhisperer(client);

    if (recipient != -1) {
        if (strlen(args) > 0) {
            whisper(client, recipient, args);
        }
        else {
            PrintToChat(client, ERROR_EMPTY_WHISPER, recipient);
        }
    }
    else {
        PrintToChat(client, "Unable to find the last person who sent you a whisper");
    }
}

static void setLastWhisperer(int client, int whisperer) {
    char key[10]
    IntToString(GetClientSerial(client), key, 10);
    _lastWhisperer.SetValue(key, GetClientSerial(whisperer), true);
}

static int getLastWhisperer(int client) {
    int lastWhisperer = 0;
    char key[10];
    IntToString(GetClientSerial(client), key, 10);

    if (_lastWhisperer.GetValue(key, lastWhisperer)) {
        lastWhisperer = GetClientFromSerial(lastWhisperer);
    }

    return lastWhisperer == 0 ? -1 : lastWhisperer;
}

static int getClientFromPartialName(const char[] partialName) {
    int client = -1;

    for (int i = 1; i <= MaxClients; i++) {
        if (IsClientInGame(i)) {
            char name[MAX_NAME_LENGTH];
            GetClientName(i, name, MAX_NAME_LENGTH);

            if (StrContains(name, partialName, false) != -1) {
                if (client != -1) { return -1; }
                client = i;
            }
        }
    }

    return client;
}

static void whisper(int sender, int recipient, const char[] msg) {
    char outPrefix[MAX_PREFIX_LENGTH];

    if (recipient != sender) {
        char inPrefix[MAX_PREFIX_LENGTH];
        Format(outPrefix, MAX_PREFIX_LENGTH, "%N (to %N)", sender, recipient);
        Format(inPrefix, MAX_PREFIX_LENGTH, "%N (whisper)", sender);

        sendMsg(recipient, inPrefix, msg);
    }
    else {
        Format(outPrefix, MAX_PREFIX_LENGTH, "%N (to self)", sender);
    }

    sendMsg(sender, outPrefix, msg);
    setLastWhisperer(recipient, sender);
}

static void sendMsg(int client, const char[] prefix, const char[] str) {
    BfWrite bf = view_as<BfWrite>(StartMessageOne("SayText2", client));

    if (bf != null) {
        bf.WriteShort(0);
        bf.WriteString("INS_Chat_All");
        bf.WriteString(prefix);
        bf.WriteString(str);
        bf.WriteByte(0);
        EndMessage();
    }
}