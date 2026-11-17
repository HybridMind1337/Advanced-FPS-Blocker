#include <amxmodx>
#include <amxmisc>
#include <cromchat>

#define PLUGIN_NAME     "Advanced FPS Blocker"
#define PLUGIN_VERSION  "1.2.0"
#define PLUGIN_AUTHOR   "HybridMind"

#define TASK_MONITOR    48520
#define CHECK_KEY       "_afbcheck"
#define MAX_CLIENTS     32

new g_pEnabled, g_pMaxFps, g_pFpsInterval, g_pJoinGrace, g_pMapGrace;
new g_pFilterEnabled, g_pFilterInterval, g_pFilterWait, g_pFilterFailures;
new g_pFilterKick, g_pPublicKicks, g_pNotify, g_pLog, g_pFpsNotifyInterval;
new g_pDeveloperCheck, g_pDeveloperInterval, g_pDeveloperNotifyInterval;

new Float:g_fMapReady, Float:g_fJoinReady[33];
new Float:g_fNextFPS[33], Float:g_fLastFPSMessage[33];
new Float:g_fNextFilter[33], Float:g_fFilterSent[33];
new Float:g_fNextDeveloper[33], Float:g_fDeveloperSent[33], Float:g_fLastDeveloperMessage[33];
new bool:g_bCvarPending[33], bool:g_bFilterPending[33], bool:g_bDeveloperPending[33];
new g_iPendingUserid[33], g_iFilterUserid[33], g_iDeveloperUserid[33];
new g_iExpected[33], g_iFailures[33], g_iChecks[33], g_iFpsCorrections[33];
new g_iDeveloperCorrections[33];

public plugin_init()
{
    register_plugin(PLUGIN_NAME, PLUGIN_VERSION, PLUGIN_AUTHOR);

    g_pEnabled = register_cvar("afb_enabled", "1");
    g_pMaxFps = register_cvar("afb_max_fps", "100");
    g_pFpsInterval = register_cvar("afb_fps_interval", "3.0");
    g_pJoinGrace = register_cvar("afb_join_grace", "15.0");
    g_pMapGrace = register_cvar("afb_map_grace", "15.0");
    g_pFilterEnabled = register_cvar("afb_filter_enabled", "1");
    g_pFilterInterval = register_cvar("afb_filter_interval", "15.0");
    g_pFilterWait = register_cvar("afb_filter_wait", "3.0");
    g_pFilterFailures = register_cvar("afb_filter_failures", "3");
    g_pFilterKick = register_cvar("afb_filter_kick", "0");
    g_pPublicKicks = register_cvar("afb_public_kicks", "1");
    g_pNotify = register_cvar("afb_fps_notify", "1");
    g_pLog = register_cvar("afb_log", "1");
    g_pFpsNotifyInterval = register_cvar("afb_fps_notify_interval", "30.0");
    g_pDeveloperCheck = register_cvar("afb_developer_check", "1");
    g_pDeveloperInterval = register_cvar("afb_developer_interval", "8.0");
    g_pDeveloperNotifyInterval = register_cvar("afb_developer_notify_interval", "30.0");

    register_clcmd("say /fps", "CmdFps");
    register_clcmd("say_team /fps", "CmdFps");

    CC_SetPrefix("&x04[FPS Blocker]&x01");
    g_fMapReady = get_gametime() + get_pcvar_float(g_pMapGrace);
    set_task(1.0, "TaskMonitor", TASK_MONITOR, _, _, "b");
}

public client_putinserver(id)
{
    ResetPlayer(id);
    g_fJoinReady[id] = get_gametime() + get_pcvar_float(g_pJoinGrace);
}

public client_disconnected(id)
{
    ResetPlayer(id);
}

stock ResetPlayer(id)
{
    g_fJoinReady[id] = 0.0;
    g_fNextFPS[id] = 0.0;
    g_fLastFPSMessage[id] = -9999.0;
    g_fNextFilter[id] = 0.0;
    g_fFilterSent[id] = 0.0;
    g_fNextDeveloper[id] = 0.0;
    g_fDeveloperSent[id] = 0.0;
    g_fLastDeveloperMessage[id] = -9999.0;
    g_bDeveloperPending[id] = false;
    g_iDeveloperUserid[id] = 0;
    g_iDeveloperCorrections[id] = 0;
    g_bCvarPending[id] = false;
    g_bFilterPending[id] = false;
    g_iPendingUserid[id] = 0;
    g_iFilterUserid[id] = 0;
    g_iExpected[id] = 0;
    g_iFailures[id] = 0;
    g_iChecks[id] = 0;
    g_iFpsCorrections[id] = 0;
}

public TaskMonitor()
{
    if (!get_pcvar_num(g_pEnabled))
        return;

    new Float:now = get_gametime();
    if (now < g_fMapReady)
        return;

    new id, Float:fpsInterval = floatmax(1.0, get_pcvar_float(g_pFpsInterval));
    new Float:filterInterval = floatmax(5.0, get_pcvar_float(g_pFilterInterval));
    new Float:filterWait = floatmax(1.0, get_pcvar_float(g_pFilterWait));
    new Float:developerInterval = floatmax(3.0, get_pcvar_float(g_pDeveloperInterval));

    for (id = 1; id <= MAX_CLIENTS; id++)
    {
        if (!is_user_connected(id) || is_user_bot(id) || is_user_hltv(id))
            continue;
        if (now < g_fJoinReady[id])
            continue;

        if (g_bCvarPending[id] && now - g_fNextFPS[id] > 10.0)
            g_bCvarPending[id] = false;

        if (!g_bCvarPending[id] && now >= g_fNextFPS[id])
        {
            g_bCvarPending[id] = true;
            g_iPendingUserid[id] = get_user_userid(id);
            g_fNextFPS[id] = now + fpsInterval;
            query_client_cvar(id, "fps_max", "OnFpsResult");
        }

        // HNS: check developer without affecting movement, FPS, or gameplay timing.
        if (get_pcvar_num(g_pDeveloperCheck))
        {
            if (g_bDeveloperPending[id] && now - g_fDeveloperSent[id] >= 10.0)
                g_bDeveloperPending[id] = false;

            if (!g_bDeveloperPending[id] && now >= g_fNextDeveloper[id])
            {
                g_bDeveloperPending[id] = true;
                g_iDeveloperUserid[id] = get_user_userid(id);
                g_fDeveloperSent[id] = now;
                g_fNextDeveloper[id] = now + developerInterval;
                query_client_cvar(id, "developer", "OnDeveloperResult");
            }
        }
        else
        {
            g_bDeveloperPending[id] = false;
        }

        if (!get_pcvar_num(g_pFilterEnabled))
        {
            g_bFilterPending[id] = false;
            continue;
        }

        if (g_bFilterPending[id] && now - g_fFilterSent[id] >= filterWait)
            FinishFilterTest(id);
        else if (!g_bFilterPending[id] && now >= g_fNextFilter[id])
        {
            g_iExpected[id] = random_num(100000, 999999);
            g_iFilterUserid[id] = get_user_userid(id);
            g_bFilterPending[id] = true;
            g_fFilterSent[id] = now;
            g_fNextFilter[id] = now + filterInterval;
            client_cmd(id, "setinfo ^"%s^" ^"%d^"", CHECK_KEY, g_iExpected[id]);
        }
    }
}

public OnFpsResult(id, const cvar[], const value[])
{
    if (!is_user_connected(id) || get_user_userid(id) != g_iPendingUserid[id])
        return;

    g_bCvarPending[id] = false;

    if (!get_pcvar_num(g_pEnabled) || !equali(cvar, "fps_max"))
        return;

    if (!value[0] || equal(value, "Bad CVAR request") || equal(value, "Bad CVAR Request"))
        return;

    new Float:fps = str_to_float(value);
    new maxFps = clamp(get_pcvar_num(g_pMaxFps), 20, 1000);

    if ((fps > float(maxFps)) || (fps == 0.0 && value[0] == '0'))
    {
        client_cmd(id, "fps_max %d", maxFps);
        g_iFpsCorrections[id]++;
        new Float:now = get_gametime();
        if (get_pcvar_num(g_pNotify) && now - g_fLastFPSMessage[id] >= floatmax(1.0, get_pcvar_float(g_pFpsNotifyInterval)))
        {
            CC_SendMessage(id, "Your &x03fps_max&x01 exceeds the limit. Requested value: &x04%d&x01.", maxFps);
            g_fLastFPSMessage[id] = now;
        }
    }
}

public OnDeveloperResult(id, const cvar[], const value[])
{
    if (id < 1 || id > MAX_CLIENTS || !is_user_connected(id)
        || !g_bDeveloperPending[id] || get_user_userid(id) != g_iDeveloperUserid[id])
        return;

    g_bDeveloperPending[id] = false;

    if (!get_pcvar_num(g_pEnabled) || !get_pcvar_num(g_pDeveloperCheck)
        || !equali(cvar, "developer"))
        return;

    if (!value[0] || equali(value, "Bad CVAR request"))
        return;

    new pos = 0;
    while (value[pos] == ' ' || value[pos] == 9)
        pos++;
    if (value[pos] == '-' || value[pos] == '+')
        pos++;
    new bool:hasDigit = false;
    new bool:valid = true;
    for (; value[pos]; pos++)
    {
        if (value[pos] >= '0' && value[pos] <= '9')
        {
            hasDigit = true;
            continue;
        }
        if (value[pos] == '.')
            continue;
        if (value[pos] == ' ' || value[pos] == 9)
            break;
        valid = false;
        break;
    }
    if (!valid || !hasDigit)
        return;

    if (str_to_float(value) == 0.0)
        return;

    client_cmd(id, "developer 0");
    g_iDeveloperCorrections[id]++;

    new Float:now = get_gametime();
    if (get_pcvar_num(g_pNotify)
        && now - g_fLastDeveloperMessage[id] >= floatmax(5.0, get_pcvar_float(g_pDeveloperNotifyInterval)))
    {
        CC_SendMessage(id, "HNS requires &x03developer &x04 0&x01. Requested correction.");
        g_fLastDeveloperMessage[id] = now;
    }
}

stock FinishFilterTest(id)
{
    g_bFilterPending[id] = false;
    if (!is_user_connected(id) || get_user_userid(id) != g_iFilterUserid[id])
        return;

    new actual[32], expected[16];
    get_user_info(id, CHECK_KEY, actual, charsmax(actual));
    num_to_str(g_iExpected[id], expected, charsmax(expected));
    g_iChecks[id]++;

    if (equal(actual, expected))
    {
        g_iFailures[id] = 0;
        return;
    }

    g_iFailures[id]++;
    new failuresRequired = clamp(get_pcvar_num(g_pFilterFailures), 1, 20);
    if (get_pcvar_num(g_pLog))
    {
        new name[32];
        get_user_name(id, name, charsmax(name));
        log_amx("AFB: setinfo verification failed: %s (userid %d), %d/%d. This is not proof of cl_filterstuffcmd.",
            name, get_user_userid(id), g_iFailures[id], failuresRequired);
    }

    if (g_iFailures[id] < failuresRequired)
        return;

    g_iFailures[id] = 0;
    if (!get_pcvar_num(g_pFilterKick))
        return;

    new name[32];
    get_user_name(id, name, charsmax(name));
    CC_RemoveExploits(name, charsmax(name));
    if (get_pcvar_num(g_pPublicKicks))
        CC_SendMessage(0, "Player &x03%s&x01 was kicked: client setinfo verification failed.", name);

    server_cmd("kick #%d ^"Client settings verification failed^"", get_user_userid(id));
    server_exec();
}

public CmdFps(id)
{
    if (!is_user_connected(id))
        return PLUGIN_HANDLED;

    if (!get_pcvar_num(g_pEnabled))
        CC_SendMessage(id, "The FPS limiter is currently &x03disabled&x01.");
    else
        CC_SendMessage(id, "Server FPS limit: &x04%d&x01. Client checks run every &x04%.1f&x01 seconds.",
            clamp(get_pcvar_num(g_pMaxFps), 20, 1000), floatmax(1.0, get_pcvar_float(g_pFpsInterval)));
    return PLUGIN_HANDLED;
}
