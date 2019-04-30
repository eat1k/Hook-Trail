/*
 * Author: https://t.me/twisternick (https://dev-cs.ru/members/444/)
 *
 * Official resource topic: https://dev-cs.ru/resources/635/
 */

#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <reapi>

#pragma semicolon 1

new const PLUGIN_VERSION[]		= "1.8";

/****************************************************************************************
****************************************************************************************/

new const g_szSprite[] = "sprites/hook/neon_electric.spr";

/****************************************************************************************
****************************************************************************************/

#define IsPlayerValid(%0) (1 <= %0 <= MaxClients)

new bool:g_bAlive[MAX_PLAYERS+1];
new bool:g_bCanUseHook[MAX_PLAYERS+1];
new g_iHookOrigin[MAX_PLAYERS+1][3];
new bool:g_bHookUse[MAX_PLAYERS+1];
new bool:g_bNeedRefresh[MAX_PLAYERS+1];

enum (+= 100)
{
	TASK_ID_HOOK
};

new g_iLifeTime;

new g_pSpriteTrailHook;

/****************************************************************************************
****************************************************************************************/

public plugin_precache()
{
	register_plugin("Hook Trail", PLUGIN_VERSION, "w0w");

	if(!file_exists(g_szSprite))
		set_fail_state("Model ^"%s^" doesn't exist", g_szSprite);

	g_pSpriteTrailHook = precache_model(g_szSprite);
}

public plugin_init()
{
	register_dictionary("hook_trail.ini");

	register_clcmd("+hook", "func_HookEnable");
	register_clcmd("-hook", "func_HookDisable");

	RegisterHookChain(RG_CSGameRules_PlayerSpawn, "refwd_PlayerSpawn_Post", true);
	RegisterHookChain(RG_CBasePlayer_Killed, "refwd_PlayerKilled_Post", true);

	new iEnt = rg_create_entity("info_target", true);
	SetThink(iEnt, "think_Hook");
	set_entvar(iEnt, var_nextthink, get_gametime() + 0.1);

	new pCvar;

	pCvar = create_cvar("hook_trail_life_time", "2", FCVAR_NONE, fmt("%l", "HOOK_TRAIL_CVAR_LIFE_TIME"), true, 1.0, true, 25.0);
	bind_pcvar_num(pCvar, g_iLifeTime);

	AutoExecConfig(true, "hook_trail");

	pCvar = create_cvar("hook_trail_version", PLUGIN_VERSION, FCVAR_SERVER|FCVAR_SPONLY);
	set_pcvar_string(pCvar, PLUGIN_VERSION);
}

public OnConfigsExecuted()
{
	set_cvar_string("hook_trail_version", PLUGIN_VERSION);
}

public refwd_PlayerSpawn_Post(id)
{
	if(is_user_alive(id))
	{
		g_bAlive[id] = true;
		g_bHookUse[id] = false;
	}
}

public refwd_PlayerKilled_Post(iVictim)
{
	g_bAlive[iVictim] = g_bHookUse[iVictim] = false;
	remove_task(iVictim);
}

public client_disconnected(id)
{
	g_bAlive[id] = g_bHookUse[id] = g_bCanUseHook[id] = false;
	remove_task(id);
}

public func_HookEnable(id)
{
	if(!g_bAlive[id])
		return PLUGIN_HANDLED;

	if(!g_bCanUseHook[id])
	{
		client_print_color(id, print_team_red, "%l", "HOOK_TRAIL_ERROR_ACCESS");
		return PLUGIN_HANDLED;
	}

	g_bHookUse[id] = true;
	get_user_origin(id, g_iHookOrigin[id], Origin_AimEndEyes);

	if(!task_exists(id+TASK_ID_HOOK))
	{
		func_RemoveTrail(id);
		func_SetTrail(id);
		set_task_ex(0.1, "task_HookWings", id+TASK_ID_HOOK, .flags = SetTask_Repeat);
	}

	return PLUGIN_HANDLED;
}

public func_HookDisable(id)
{
	g_bHookUse[id] = false;
	return PLUGIN_HANDLED;
}

func_SetTrail(id)
{
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
	write_byte(TE_BEAMFOLLOW);
	write_short(id);					// entity
	write_short(g_pSpriteTrailHook);	// sprite index
	write_byte(g_iLifeTime * 10);		// life
	write_byte(15);						// width
	write_byte(255);					// red
	write_byte(255);					// green
	write_byte(255);					// blue
	write_byte(255);					// brightness
	message_end();
}

func_RemoveTrail(id)
{
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
	write_byte(TE_KILLBEAM);
	write_short(id);
	message_end();
}

public task_HookWings(id)
{
	id -= TASK_ID_HOOK;

	if(get_entvar(id, var_flags) & FL_ONGROUND && !g_bHookUse[id])
	{
		remove_task(id+TASK_ID_HOOK);
		func_RemoveTrail(id);
		return;
	}

	static Float:flVelocity[3];
	get_entvar(id, var_velocity, flVelocity);

	if(vector_length(flVelocity) < 10.0)
		g_bNeedRefresh[id] = true;
	else if(g_bNeedRefresh[id])
	{
		g_bNeedRefresh[id] = false;
		func_RemoveTrail(id);
		func_SetTrail(id);
	}
}

public think_Hook(iEnt)
{
	static iPlayers[MAX_PLAYERS], iPlayerCount;
	get_players_ex(iPlayers, iPlayerCount, GetPlayers_ExcludeDead);

	static iOrigin[3], Float:flVelocity[3], iDistance;

	for(new i, iPlayer; i < iPlayerCount; i++)
	{
		iPlayer = iPlayers[i];

		if(!g_bHookUse[iPlayer])
			continue;

		get_user_origin(iPlayer, iOrigin);
		iDistance = get_distance(g_iHookOrigin[iPlayer], iOrigin);
		if(iDistance > 25)
		{
			flVelocity[0] = (g_iHookOrigin[iPlayer][0] - iOrigin[0]) * (2.0 * 350.0 / iDistance);
			flVelocity[1] = (g_iHookOrigin[iPlayer][1] - iOrigin[1]) * (2.0 * 350.0 / iDistance);
			flVelocity[2] = (g_iHookOrigin[iPlayer][2] - iOrigin[2]) * (2.0 * 350.0 / iDistance);
			set_entvar(iPlayer, var_velocity, flVelocity);
		}
	}

	set_entvar(iEnt, var_nextthink, get_gametime() + 0.1);
}

/****************************************************************************************
****************************************************************************************/

public plugin_natives()
{
	register_native("hook_trail_user_manage", "__hook_trail_user_manage");
	register_native("hook_trail_has_user", "__hook_trail_has_user");
}

public __hook_trail_user_manage(iPlugin, iParams)
{
	enum { player = 1, enable };

	new iPlayer = get_param(player);

	if(!IsPlayerValid(iPlayer))
		abort(AMX_ERR_NATIVE, "Player out of range (%d)", iPlayer);

	g_bCanUseHook[iPlayer] = bool:get_param(enable);

	if(!g_bCanUseHook[iPlayer])
	{
		g_bHookUse[iPlayer] = false;
		remove_task(iPlayer);
	}
}

public __hook_trail_has_user(iPlugin, iParams)
{
	enum { player = 1 };

	new iPlayer = get_param(player);

	if(!IsPlayerValid(iPlayer))
		abort(AMX_ERR_NATIVE, "Player out of range (%d)", iPlayer);

	return g_bCanUseHook[iPlayer];
}