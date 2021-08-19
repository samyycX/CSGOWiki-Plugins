// implement utility submit
public Action:Command_Submit(client, args) {
    if (!check_function_on(g_hOnUtilitySubmit, "\x02道具上传功能关闭，请联系服务器管理员", client)) {
        return;
    }
    if (e_cDefault != g_aPlayerStatus[client]) {
        return;
    }
    if (BotMimic_IsPlayerMimicing(client)) {
        PrintToChat(client, "%s \x02正在播放录像", PREFIX);
        return;
    }
    PrintToChat(client, "%s \x06道具上传功能开启", PREFIX);
    PrintToChat(client, "%s 你接下来的道具投掷记录将会被自动上传至\x09mycsgolab", PREFIX);
    PrintToChat(client, "%s 输入\x04!abort\x01终止上传", PREFIX);
    GetClientAbsOrigin(client, g_aStartPositions[client]);
    GetClientEyeAngles(client, g_aStartAngles[client]);
    g_aPlayerStatus[client] = e_cThrowReady;
    g_aPlayerUtilityPath[client] = new JSON_Array();
}

public Action:Command_SubmitAbort(client, args) {
    if (e_cDefault != g_aPlayerStatus[client]) {
        g_aPlayerStatus[client] = e_cDefault;
        ResetSingleClientSubmitState(client);
        PrintToChat(client, "%s 已终止上传流程", PREFIX);
    }
    if (BotMimic_IsPlayerMimicing(client)) {
        BotMimic_StopPlayerMimic(client);
    }
}

// float float_reserve(float v) {
//     // float power = Pow(10.0, float(e));
//     return float(RoundFloat(v * 10.0)) / 10.0;
// }

void OnPlayerRunCmdForUtilitySubmit(client, &buttons) {
    // record action => encoded
    if (e_cThrowReady == g_aPlayerStatus[client] || e_cM_ThrowReady == g_aPlayerStatus[client]) {
        for (new idx = 0; idx < CSGO_ACTION_NUM; idx++) {
            if ((g_aCsgoActionMap[idx] & buttons) && 
                !(g_aActionRecord[client] & (1 << idx))) {
                g_aActionRecord[client] |= 1 << idx;
            }
        }
    }
    if (e_cAlreadyThrown == g_aPlayerStatus[client] || e_cM_AlreadyThrown == g_aPlayerStatus[client]) {
        if (g_iUtilityEntityId[client] != 0 && g_iPlayerUtilityPathFrameCount[client] % g_iUtilityPathInterval == 0) {
            float position[3];
            JSON_Array pos = new JSON_Array();
            GetEntPropVector(g_iUtilityEntityId[client], Prop_Send, "m_vecOrigin", position);
            // pos.PushFloat(float_reserve(position[0]));
            // pos.PushFloat(float_reserve(position[1]));
            // pos.PushFloat(float_reserve(position[2]));
            pos.PushFloat(position[0]);
            pos.PushFloat(position[1]);
            pos.PushFloat(position[2]);
            g_aPlayerUtilityPath[client].PushObject(pos);
        }
        g_iPlayerUtilityPathFrameCount[client] ++;
    }
}

public void CSU_OnThrowGrenade(int client, int entity, GrenadeType grenadeType,
        const float origin[3], const float velocity[3]) {
        if (g_aPlayerStatus[client] != e_cThrowReady && g_aPlayerStatus[client] != e_cM_ThrowReady && g_aPlayerStatus[client] != e_cV_ThrowReady)
            return;
        if (grenadeType == GrenadeType_None || grenadeType == GrenadeType_Decoy) 
            return;
        g_iUtilityEntityId[client] = entity;
        g_aThrowPositions[client] = origin;
        g_aUtilityVelocity[client] = velocity;
        g_aUtilityAirtime[client] = GetEngineTime();
        g_aUtilityType[client] = grenadeType;
        if (e_cM_ThrowReady == g_aPlayerStatus[client]) 
            g_aPlayerStatus[client] = e_cM_AlreadyThrown;
        else if (e_cThrowReady == g_aPlayerStatus[client])
            g_aPlayerStatus[client] = e_cAlreadyThrown;
        else {
            g_aPlayerStatus[client] = e_cDefault;
            TriggerVelocity(client);
        }
        PrintToChat(client, "%s \x03已经记录你的动作，等待道具生效...", PREFIX);
}

void Event_HegrenadeDetonateForUtilitySubmit(Handle:event) {
    UtilityDetonateStat(event, GrenadeType_HE);
}

void Event_FlashbangDetonateForUtilitySubmit(Handle:event) {
    UtilityDetonateStat(event, GrenadeType_Flash);
}

void Event_SmokegrenadeDetonateForUtilitySubmit(Handle:event) {
    UtilityDetonateStat(event, GrenadeType_Smoke);
}

void Event_MolotovDetonateForUtilitySubmit(Handle:event) {
    UtilityDetonateStat(event, GrenadeType_Molotov);
}

// implement utility submit function
void ResetSingleClientSubmitState(client) {
    g_aPlayerStatus[client] = e_cDefault;
    g_aActionRecord[client] = 0;
    g_iPlayerUtilityPathFrameCount[client] = 0;
    g_iUtilityEntityId[client] = 0;
    json_cleanup_and_delete(g_aPlayerUtilityPath[client]);
}

void ResetUtilitySubmitState() {
    for (new client = 0; client <= MAXPLAYERS; client++) {
        ResetSingleClientSubmitState(client);
    }
}

void UtilityDetonateStat(Handle:event, GrenadeType utCode) {
    new client = GetClientOfUserId(GetEventInt(event, "userid"));
    if ((e_cAlreadyThrown == g_aPlayerStatus[client]
        || e_cM_AlreadyThrown == g_aPlayerStatus[client])
        && utCode == g_aUtilityType[client]) {
        // next state
        g_aUtilityAirtime[client] = GetEngineTime() - g_aUtilityAirtime[client];
        g_aEndspotPositions[client][0] = GetEventFloat(event, "x");
        g_aEndspotPositions[client][1] = GetEventFloat(event, "y");
        g_aEndspotPositions[client][2] = GetEventFloat(event, "z");

        if (e_cM_AlreadyThrown == g_aPlayerStatus[client]) {
            g_aPlayerStatus[client] = e_cM_ThrowEnd;
            TriggerWikiModify(client);
        }
        else {
            g_aPlayerStatus[client] = e_cThrowEnd;
            TriggerWikiPost(client);
        }
        g_iPlayerUtilityPathFrameCount[client] = 0;
        g_iUtilityEntityId[client] = 0;
        json_cleanup_and_delete(g_aPlayerUtilityPath[client]);
    }
}

void TriggerWikiPost(client) {
    // post api
    // url = "https://api.csgowiki.top/api/utility/submit/"

    // param define
    char token[LENGTH_TOKEN] = "";
    char steamid[LENGTH_STEAMID64] = "";
    char utTinyName[LENGTH_UTILITY_TINY] = "";
    bool wikiAction[CSGOWIKI_ACTION_NUM] = {};  // init all false
    char tickTag[LENGTH_STATUS] = "";
    char str[202400];
    char path[202400];
    // param fix
    GetConVarString(g_hCSGOWikiToken, token, LENGTH_TOKEN);
    GetClientAuthId(client, AuthId_SteamID64, steamid, LENGTH_STEAMID64);
    GrenadeType_2_Tinyname(g_aUtilityType[client], utTinyName);
    Action_Int2Array(client, wikiAction);
    TicktagGenerate(tickTag, wikiAction);
    g_aPlayerUtilityPath[client].Encode(str, sizeof(str));

    EncodeBase64(path, sizeof(path), str);
    PrintToChat(client, "total frame: %d; sampled frame: %d", g_iPlayerUtilityPathFrameCount[client], g_iPlayerUtilityPathFrameCount[client] / g_iUtilityPathInterval);

    // request
    char url[128] = "";
    char apiHost[LENGTH_TOKEN];
    GetConVarString(g_hApiHost, apiHost, sizeof(apiHost));
    Format(url, sizeof(url), "%s/utility/utility/submit/?token=%s", apiHost, token);
    System2HTTPRequest httpRequest = new System2HTTPRequest(
        WikiPostResponseCallback, url
    );
    // remain path [TODO]
    httpRequest.SetHeader("Content-Type", "application/json");
    httpRequest.SetData(
        "{\
            \"steam_id\": \"%s\",\
            \"start_x\": %f,\
            \"start_y\": %f,\
            \"start_z\": %f,\
            \"end_x\": %f,\
            \"end_y\": %f,\
            \"end_z\": %f,\
            \"aim_pitch\": %f,\
            \"aim_yaw\": %f,\
            \"is_run\": %b,\
            \"is_walk\": %b,\
            \"is_jump\": %b,\
            \"is_duck\": %b,\
            \"is_left\": %b,\
            \"is_right\": %b,\
            \"map_belong\": \"%s\",\
            \"tickrate\": \"%s\",\
            \"utility_type\": \"%s\",\
            \"throw_x\": %f,\
            \"throw_y\": %f,\
            \"throw_z\": %f,\
            \"air_time\": %f,\
            \"velocity_x\": %f,\
            \"velocity_y\": %f,\
            \"velocity_z\": %f,\
            \"path\": \"%s\"\
        }",
        steamid, g_aStartPositions[client][0], g_aStartPositions[client][1],
        g_aStartPositions[client][2], g_aEndspotPositions[client][0],
        g_aEndspotPositions[client][1], g_aEndspotPositions[client][2],
        g_aStartAngles[client][0], g_aStartAngles[client][1],
        wikiAction[e_wRun], wikiAction[e_wWalk], wikiAction[e_wJump],
        wikiAction[e_wDuck], wikiAction[e_wLeftclick], wikiAction[e_wRightclick],
        g_sCurrentMap, tickTag, utTinyName, g_aThrowPositions[client][0],
        g_aThrowPositions[client][1], g_aThrowPositions[client][2], g_aUtilityAirtime[client],
        g_aUtilityVelocity[client][0], g_aUtilityVelocity[client][1], g_aUtilityVelocity[client][2], path
    );
    httpRequest.Any = client;
    httpRequest.POST();
    delete httpRequest;
}


public WikiPostResponseCallback(bool success, const char[] error, System2HTTPRequest request, System2HTTPResponse response, HTTPRequestMethod method) {
    new client = request.Any;
    if (success) {
        char[] status = new char[LENGTH_STATUS];
        char[] content = new char[response.ContentLength + 1];
        response.GetContent(content, response.ContentLength + 1);
        if (response.ContentLength <= 1 || content[0] != '{') {
            PrintToChat(client, "%s \x02服务器异常：%s", PREFIX, content);
            return;
        }
        JSON_Object json_obj = json_decode(content);
        PrintToChat(client, "%s", content);
        json_obj.GetString("status", status, LENGTH_STATUS);
        if (StrEqual(status, "ok")) {
            char[] utId = new char[LENGTH_UTILITY_ID];
            json_obj.GetString("code", utId, LENGTH_UTILITY_ID);
            ShowResult(client, utId);
        }
        else {
            char[] message = new char[LENGTH_NAME];
            json_obj.GetString("message", message, LENGTH_NAME);
            PrintToChat(client, "%s \x02%s", PREFIX, message);
        }
        json_cleanup_and_delete(json_obj);
    }
    else {
        PrintToChat(client, "%s \x02连接至mycsgolab失败", PREFIX);
    }
    ResetSingleClientSubmitState(client);
}

void ShowResult(client, char[] utId) { 
    char strAction[LENGTH_MESSAGE] = "";
    Action_Int2Str(client, strAction);
    PrintToChat(client, "\x09 ------------------------------------- ");
    PrintToChat(client, "%s 已将道具记录上传至\x09mycsgolab\x01", PREFIX);
    PrintToChat(client, "%s [\x0F起点\x01] \x0D%f,%f,%f", PREFIX, g_aStartPositions[client][0], g_aStartPositions[client][1], g_aStartPositions[client][2]);
    PrintToChat(client, "%s [\x0F角度\x01] \x0D%f,%f, 0.0", PREFIX, g_aStartAngles[client][0], g_aStartAngles[client][1]);
    PrintToChat(client, "%s [\x0F出手点\x01] \x0D%f,%f,%f", PREFIX, g_aThrowPositions[client][0], g_aThrowPositions[client][1], g_aThrowPositions[client][2]);
    PrintToChat(client, "%s [\x0F落点\x01] \x0D%f,%f,%f", PREFIX, g_aEndspotPositions[client][0], g_aEndspotPositions[client][1], g_aEndspotPositions[client][2]);
    PrintToChat(client, "%s [\x0F动作列表\x01] \x0D%s", PREFIX, strAction);
    PrintToChat(client, "%s 该道具记录的唯一标识为<\x04%s\x01>", PREFIX, utId);
    PrintToChat(client, "%s 请在\x02尽快\x01登陆网站补全道具信息(图片和文字描述)", PREFIX);
    PrintToChat(client, "\x09 ------------------------------------- ");
}