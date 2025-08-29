
public any native_ChatCmd(Handle plugin, int numParams) {
    char cmdName[ML_CMD], pluginName[ML_PLUGIN], params[ML_DESC], desc[ML_DESC];

    GetPluginFilename(plugin, pluginName, ML_PLUGIN);
    GetNativeString(1, cmdName, ML_CMD);
    stringToLower(cmdName);

    if (m_index.ContainsKey(cmdName)) {
        return ThrowNativeError(SP_ERROR_NATIVE, "Unable to register ChatCmd \"%s\" (already registered)", cmdName);
    }

    Function handler = GetNativeFunction(2);
    GetNativeString(3, params, ML_DESC);
    GetNativeString(4, desc, ML_DESC);
    CmdAccess access = view_as<CmdAccess>(GetNativeCell(5));
    bool doPrint = view_as<bool>(GetNativeCell(6));
    bool isEnabled = view_as<bool>(GetNativeCell(7));

    DataPack data = new DataPack();
    data.WriteFunction(handler);

    return view_as<ChatCmd>(pushChatCmd(cmdName, pluginName, params, desc, data, access, doPrint, isEnabled));
}

public any native_ChatCmd_alias(Handle plugin, int numParams) {
    ChatCmd cmd = view_as<ChatCmd>(GetNativeCell(1));
    if (!cmd.isValid) { return ThrowNativeError(SP_ERROR_NATIVE, "Invalid index (%i)", cmd.index); }

    char aliasName[ML_CMD], aliases[ML_DESC];

    GetNativeString(2, aliasName, ML_CMD);
    stringToLower(aliasName);

    if (!m_index.SetValue(aliasName, cmd.index, false)) {
        return ThrowNativeError(SP_ERROR_NATIVE, "Unable to register ChatCmd \"%s\" (already registered)", aliasName);
    }

    if (l_aliases.GetString(cmd.index, aliases, ML_DESC) > 0) {
        Format(aliases, ML_DESC, "%s, %s", aliases, aliasName);
        l_aliases.SetString(cmd.index, aliases);
    }
    else { l_aliases.SetString(cmd.index, aliasName); }

    return cmd;
}

public any native_ChatCmd_isValid_get(Handle plugin, int numParams) {
    int index = GetNativeCell(1);
    return index >= 0 && index < l_enabled.Length;
}

public any native_ChatCmd_isVote_get(Handle plugin, int numParams) {
    ChatCmd cmd = view_as<ChatCmd>(GetNativeCell(1));
    if (!cmd.isValid) { return ThrowNativeError(SP_ERROR_NATIVE, "Invalid index (%i)", cmd.index); }

    return l_voteIndex.Get(cmd.index) != -1;
}

public any native_ChatCmd_access_get(Handle plugin, int numParams) {
    ChatCmd cmd = view_as<ChatCmd>(GetNativeCell(1));
    if (!cmd.isValid) { return ThrowNativeError(SP_ERROR_NATIVE, "Invalid index (%i)", cmd.index); }

    return l_access.Get(cmd.index);
}

public any native_ChatCmd_doPrint_get(Handle plugin, int numParams) {
    ChatCmd cmd = view_as<ChatCmd>(GetNativeCell(1));
    if (!cmd.isValid) { return ThrowNativeError(SP_ERROR_NATIVE, "Invalid index (%i)", cmd.index); }

    return l_doPrint.Get(cmd.index);
}

public any native_ChatCmd_isEnabled_get(Handle plugin, int numParams) {
    ChatCmd cmd = view_as<ChatCmd>(GetNativeCell(1));
    if (!cmd.isValid) { return ThrowNativeError(SP_ERROR_NATIVE, "Invalid index (%i)", cmd.index); }

    return l_enabled.Get(cmd.index);
}

public any native_ChatCmd_isEnabled_set(Handle plugin, int numParams) {
    ChatCmd cmd = view_as<ChatCmd>(GetNativeCell(1));
    if (!cmd.isValid) { return ThrowNativeError(SP_ERROR_NATIVE, "Invalid index (%i)", cmd.index); }

    l_enabled.Set(cmd.index, GetNativeCell(2));
    return 0;
}

public int native_ChatCmd_getName(Handle plugin, int numParams) {
    ChatCmd cmd = view_as<ChatCmd>(GetNativeCell(1));
    if (!cmd.isValid) { return ThrowNativeError(SP_ERROR_NATIVE, "Invalid index (%i)", cmd.index); }

    int length = GetNativeCell(3);
    char[] buffer = new char[length];
    GetNativeString(2, buffer, length);
    l_name.GetString(cmd.index, buffer, length);

    SetNativeString(2, buffer, length, false);
    return 0;
}

public any native_ChatCmd_getPlugin(Handle plugin, int numParams) {
    ChatCmd cmd = view_as<ChatCmd>(GetNativeCell(1));
    if (!cmd.isValid) { return ThrowNativeError(SP_ERROR_NATIVE, "Invalid index (%i)", cmd.index); }

    char pluginName[ML_PLUGIN];
    l_plugin.GetString(cmd.index, pluginName, ML_PLUGIN);

    return FindPluginByFile(pluginName);
}

public int native_ChatCmd_exec(Handle plugin, int numParams) {
    ChatCmd cmd = view_as<ChatCmd>(GetNativeCell(1));
    if (!cmd.isValid) { return ThrowNativeError(SP_ERROR_NATIVE, "Invalid index (%i)", cmd.index); }

    char args[ML_MSG];

    int client = GetNativeCell(2);
    GetNativeString(3, args, ML_MSG);

    Call_StartFunction(cmd.getPlugin(), getCmdHandler(cmd));
    Call_PushCell(client);
    Call_PushCell(cmd);
    Call_PushString(args);
    Call_Finish();

    return 0;
}