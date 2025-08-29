
#if defined LIB_CHAT_CMDS
  #endinput
#endif

#define LIB_CHAT_CMDS "ChatCmds"

enum CmdAccess {
    CmdAccess_Player = (1<<0),
    CmdAccess_Spectator = (1<<1),
    CmdAccess_Admin = (1<<2),
    CmdAccess_All = CmdAccess_Player | CmdAccess_Spectator | CmdAccess_Admin
}

typedef CmdHandler = function void (int client, ChatCmd cmd, const char[] args);
typedef VoteCmdValidator = function bool (int client, VoteCmd cmd, char[] args, int argsLength);
typedef VoteCmdHandler = function void (int client, VoteCmd cmd, const char[] args);

methodmap ChatCmd {
    public native ChatCmd(
        const char[] name,
        CmdHandler handler,
        const char[] params = "",
        const char[] desc = "",
        CmdAccess access = CmdAccess_Player,
        bool doPrint = true,
        bool isEnabled = true
    );

    public native ChatCmd alias(const char[] name);

    property int index {
        public get() { return view_as<int>(this); }
    }

    property bool isValid {
        public native get();
    }

    property bool isVote {
        public native get();
    }

    property bool isEnabled {
        public native get();
        public native set(bool doEnable);
    }

    property CmdAccess access {
        public native get();
    }

    property bool doPrint {
        public native get();
    }

    public native void getName(char[] buffer, int maxLength);
    public native Handle getPlugin();

    public native void exec(int client, const char[] args);
}

methodmap SecretCmd < ChatCmd {
    public SecretCmd(const char[] name, CmdHandler handler, CmdAccess access = CmdAccess_Player, bool isEnabled = true) {
        return view_as<SecretCmd>(ChatCmd(name, handler, _, _, access, false, isEnabled));
    }
}

methodmap VoteCmd < ChatCmd {
    public native VoteCmd(
        const char[] name,
        VoteCmdValidator validator,
        VoteCmdHandler handler,
        const char[] params = "",
        const char[] desc = "",
        const char[] action = "",
        bool isTeamOnly = false,
        float quorumRatio = 0.51,
        bool isEnabled = true
    );

    public native VoteCmd alias(const char[] name);

    property bool isTeamOnly {
        public native get();
    }

    property float quorumRatio {
        public native get();
        public native set(float quorumRatio);
    }

    public native void getActionText(char[] buffer, int maxLength);

    public native bool validate(int client, char[] args, int argsLength);
}