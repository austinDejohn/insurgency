
public any native_VoteCmd(Handle plugin, int numParams) {
    char cmdName[ML_CMD], pluginName[ML_PLUGIN], params[ML_DESC], desc[ML_DESC], action[ML_ACTION];

    GetPluginFilename(plugin, pluginName, ML_PLUGIN);
    GetNativeString(1, cmdName, ML_CMD);
    stringToLower(cmdName);

    if (m_index.ContainsKey(cmdName)) {
        return ThrowNativeError(SP_ERROR_NATIVE, "Unable to register ChatCmd \"%s\" (already registered)", cmdName);
    }

    Function validator = GetNativeFunction(2);
    Function handler = GetNativeFunction(3);
    GetNativeString(4, params, ML_DESC);
    GetNativeString(5, desc, ML_DESC);
    GetNativeString(6, action, ML_ACTION);
    bool isTeamOnly = view_as<bool>(GetNativeCell(7));
    float quorumRatio = view_as<float>(GetNativeCell(8));
    bool isEnabled = view_as<bool>(GetNativeCell(9));

    DataPack validatorData = new DataPack();
    DataPack handlerData = new DataPack();

    validatorData.WriteFunction(validator);
    handlerData.WriteFunction(handler);

    return view_as<VoteCmd>(
        pushVoteCmd(
            cmdName,
            pluginName,
            params,
            desc,
            action,
            validatorData,
            handlerData,
            isTeamOnly,
            quorumRatio,
            isEnabled
        )
    );
}

public any native_VoteCmd_alias(Handle plugin, int numParams) {
    VoteCmd cmd = view_as<VoteCmd>(GetNativeCell(1));
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

public any native_VoteCmd_isTeamOnly_get(Handle plugin, int numParams) {
    VoteCmd cmd = view_as<VoteCmd>(GetNativeCell(1));
    if (!cmd.isValid) { return ThrowNativeError(SP_ERROR_NATIVE, "Invalid index (%i)", cmd.index); }

    return l_isTeamOnlyVote.Get(getVoteIndex(cmd));
}

public any native_VoteCmd_quorumRatio_get(Handle plugin, int numParams) {
    VoteCmd cmd = view_as<VoteCmd>(GetNativeCell(1));
    if (!cmd.isValid) { return ThrowNativeError(SP_ERROR_NATIVE, "Invalid index (%i)", cmd.index); }

    return l_quorumRatio.Get(getVoteIndex(cmd));
}

public any native_VoteCmd_quorumRatio_set(Handle plugin, int numParams) {
    VoteCmd cmd = view_as<VoteCmd>(GetNativeCell(1));
    if (!cmd.isValid) { return ThrowNativeError(SP_ERROR_NATIVE, "Invalid index (%i)", cmd.index); }

    l_quorumRatio.Set(getVoteIndex(cmd), GetNativeCell(2));
    return 0;
}

public any native_VoteCmd_getActionText(Handle plugin, int numParams) {
    VoteCmd cmd = view_as<VoteCmd>(GetNativeCell(1));
    if (!cmd.isValid) { return ThrowNativeError(SP_ERROR_NATIVE, "Invalid index (%i)", cmd.index); }

    int length = GetNativeCell(3);
    char[] buffer = new char[length];
    GetNativeString(2, buffer, length);
    l_actionText.GetString(getVoteIndex(cmd), buffer, length);

    SetNativeString(2, buffer, length, false);
    return 0;
}

public any native_VoteCmd_validate(Handle plugin, int numParams) {
    VoteCmd cmd = view_as<VoteCmd>(GetNativeCell(1));
    if (!cmd.isValid) { return ThrowNativeError(SP_ERROR_NATIVE, "Invalid index (%i)", cmd.index); }

    int client = GetNativeCell(2);
    int argsLength = GetNativeCell(4);

    char[] args = new char[argsLength];
    bool result = false;

    GetNativeString(3, args, argsLength);

    Call_StartFunction(cmd.getPlugin(), getVoteValidator(cmd));
    Call_PushCell(client);
    Call_PushCell(cmd);

    Call_PushStringEx(
        args,
        argsLength,
		SM_PARAM_STRING_UTF8 | SM_PARAM_STRING_COPY,
        SM_PARAM_COPYBACK
    );

    Call_Finish(result);

    SetNativeString(3, args, argsLength, true);

    return result;
}