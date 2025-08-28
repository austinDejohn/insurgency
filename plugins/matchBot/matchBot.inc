
#if defined LIB_MATCH_BOT
  #endinput
#endif

#define LIB_MATCH_BOT "matchBot"

enum MatchState {
    MatchState_Warmup,
    MatchState_Paused,
    MatchState_Live,
    MatchState_Finished
}

enum MatchBot { matchBot, };

methodmap MatchBot {
    property MatchState state {
        public native get();
    }

    property bool isWarmup {
        public get() { return this.state == MatchState_Warmup; }
    }

    property bool isPaused {
        public get() { return this.state == MatchState_Paused; }
    }

    property bool isLive {
        public get() { return this.state == MatchState_Live; }
    }

    property bool isFinished {
        public get() { return this.state == MatchState_Finished; }
    }
}

public SharedPlugin __pl_matchBot = {
    name = "matchBot",
    file = "matchBot.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_matchBot_SetNTVOptional() {
    MarkNativeAsOptional("MatchBot.state.get");
}
#endif