/*
	SourcePawn is Copyright (C) 2006-2008 AlliedModders LLC.  All rights reserved.
	SourceMod is Copyright (C) 2006-2008 AlliedModders LLC.  All rights reserved.
	Pawn and SMALL are Copyright (C) 1997-2008 ITB CompuPhase.
	Source is Copyright (C) Valve Corporation.
	All trademarks are property of their respective owners.
	This program is free software: you can redistribute it and/or modify it
	under the terms of the GNU General Public License as published by the
	Free Software Foundation, either version 3 of the License, or (at your
	option) any later version.
	This program is distributed in the hope that it will be useful, but
	WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
	General Public License for more details.
	You should have received a copy of the GNU General Public License along
	with this program.  If not, see <http://www.gnu.org/licenses/>.
	
	Mis notes:
	I really didn't do much on this plugin, I just removed the panel and made a general timer.
	The idea was to be able to use this plugin in both modes, but I had some weird bugs,
	and I'm too lazy, so now it only works for T1, I will continue it someday.
	Now with this plugin you can use readyup dependent plugins in T1,
	such as spechud, boss_equalizer, etc...
*/

#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <left4downtown>
#include <l4d2_direct>
#include <builtinvotes>
#include <colors>

#define MAX_FOOTERS 10
#define MAX_FOOTER_LEN 65
#define MAX_SOUNDS 5

#define DEBUG 0

public Plugin:myinfo =
{
	name = "L4D2 Ready-Up countdown",
	author = "CanadaRox [Mis Edit]",
	description = "The survivors cannot leave the saferoom until the timer ends.",
	version = "1.0",
	url = "https://github.com/misdocumeno"
};

enum L4D2Team
{
	L4D2Team_None = 0,
	L4D2Team_Spectator,
	L4D2Team_Survivor,
	L4D2Team_Infected
}

// Plugin Cvars
new Handle:l4d_ready_disable_spawns;
new Handle:l4d_ready_cfg_name;
new Handle:l4d_ready_survivor_freeze;
new Handle:l4d_ready_max_players;
new Handle:l4d_ready_delay;
new Handle:l4d_ready_delay_t1_forcestart_first;
new Handle:l4d_ready_delay_t1_forcestart_second;
new Handle:l4d_ready_enable_sound;
new Handle:l4d_ready_chuckle;
new Handle:l4d_ready_countdown_sound;
new Handle:l4d_ready_live_sound;
new Handle:l4d_ready_show_time;
new Handle:l4d_ready_show_commands;

ConVar g_cvarl4d_ready_mode;

//new Handle:l4d_ready_warp_team;

new Handle:g_hVote;
new Float:g_fButtonTime[MAXPLAYERS + 1];
new g_fPlayerMouse[MAXPLAYERS + 1][2];

new Float:liveTime;

// Used to set the scores
new Handle:gConf = INVALID_HANDLE;
new Handle:fSetCampaignScores = INVALID_HANDLE;

// Game Cvars
new Handle:director_no_specials;
new Handle:director_allow_infected_bots;
new Handle:god;
new Handle:sb_stop;
new Handle:survivor_limit;
new Handle:z_max_player_zombies;
new Handle:sv_infinite_ammo;
new Handle:ServerNamer;

new Handle:casterTrie;
new Handle:liveForward;
new Handle:menuPanel;
new Handle:readyCountdownTimer;
new String:readyFooter[MAX_FOOTERS][MAX_FOOTER_LEN];
new bool:hiddenPanel[MAXPLAYERS + 1];
new bool:inLiveCountdown = false;
new bool:inReadyUp;
new bool:isPlayerReady[MAXPLAYERS + 1];
new footerCounter = 0;
new readyDelay;
new readyForceDelayFirst;
new readyForceDelaySecond;
new isRoundLive;
new String:countdownSound[256];
new String:liveSound[256];

new bool:bSkipWarp;
new bool:blockSecretSpam[MAXPLAYERS + 1];

new iCmd;
new String:sCmd[MAX_NAME_LENGTH];

new Handle:allowedCastersTrie;

new String:chuckleSound[MAX_SOUNDS][]=
{
	"/npc/moustachio/strengthattract01.wav",
	"/npc/moustachio/strengthattract02.wav",
	"/npc/moustachio/strengthattract05.wav",
	"/npc/moustachio/strengthattract06.wav",
	"/npc/moustachio/strengthattract09.wav"
};

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	CreateNative("AddStringToReadyFooter", Native_AddStringToReadyFooter);
	CreateNative("EditFooterStringAtIndex", Native_EditFooterStringAtIndex);
	CreateNative("FindIndexOfFooterString", Native_FindIndexOfFooterString);
	CreateNative("GetFooterStringAtIndex", Native_GetFooterStringAtIndex);
	CreateNative("IsInReady", Native_IsInReady);
	CreateNative("IsClientCaster", Native_IsClientCaster);
	CreateNative("IsIDCaster", Native_IsIDCaster);
	liveForward = CreateGlobalForward("OnRoundIsLive", ET_Event);
	RegPluginLibrary("readyup");
	return APLRes_Success;
}

public OnPluginStart()
{
	StartPrepSDKCall(SDKCall_GameRules);
	if(PrepSDKCall_SetFromConf(gConf, SDKConf_Signature, "SetCampaignScores"))
	{
		PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
		PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
		fSetCampaignScores = EndPrepSDKCall();
		
		if(fSetCampaignScores == INVALID_HANDLE)
		{
			LogError("Function 'SetCampaignScores' found, but something went wrong.");
		}
		else
		{
			LogError("Function 'SetCampaignScores' not found.");
		}
	}
  
	CreateConVar("l4d_ready_enabled", "1", "This cvar doesn't do anything, but if it is 0 the logger wont log this game.", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	l4d_ready_cfg_name = CreateConVar("l4d_ready_cfg_name", "", "Configname to display on the ready-up panel", FCVAR_NOTIFY|FCVAR_PRINTABLEONLY);
	l4d_ready_disable_spawns = CreateConVar("l4d_ready_disable_spawns", "0", "Prevent SI from having spawns during ready-up", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	l4d_ready_survivor_freeze = CreateConVar("l4d_ready_survivor_freeze", "0", "Freeze the survivors during ready-up.  When unfrozen they are unable to leave the saferoom but can move freely inside", FCVAR_NOTIFY, true, 0.0, true, 1.0);
	l4d_ready_max_players = CreateConVar("l4d_ready_max_players", "12", "Maximum number of players to show on the ready-up panel.", FCVAR_NOTIFY, true, 0.0, true, MAXPLAYERS+1.0);
	l4d_ready_delay = CreateConVar("l4d_ready_delay", "3", "Number of seconds to count down before the round goes live.", FCVAR_NOTIFY, true, 0.0);
	g_cvarl4d_ready_mode = CreateConVar("l4d_ready_mode", "0", "Change ready-up mode. 0 = versus, 1 = T1", FCVAR_NONE, true, 0.0, true, 1.0);
	l4d_ready_delay_t1_forcestart_first = CreateConVar("l4d_ready_delay_t1_forcestart_first", "40", "Number of seconds to count down before the first round goes live on T1 mode.", FCVAR_NONE, true, 0.0, true, 1.0);
	l4d_ready_delay_t1_forcestart_second = CreateConVar("l4d_ready_delay_t1_forcestart_second", "20", "Number of seconds to count down before the second round goes live on T1 mode.", FCVAR_NONE, true, 0.0, true, 1.0);
	l4d_ready_enable_sound = CreateConVar("l4d_ready_enable_sound", "1", "Enable sound during countdown & on live");
	l4d_ready_countdown_sound = CreateConVar("l4d_ready_countdown_sound", "weapons/hegrenade/beep.wav", "The sound that plays when a round goes on countdown");	
	l4d_ready_live_sound = CreateConVar("l4d_ready_live_sound", "ui/survival_medal.wav", "The sound that plays when a round goes live");
	l4d_ready_chuckle = CreateConVar("l4d_ready_chuckle", "0", "Enable random moustachio chuckle during countdown");
	l4d_ready_show_time = CreateConVar("l4d_ready_show_time", "1", "Show time on ready up panel");
	l4d_ready_show_commands = CreateConVar("l4d_ready_show_commands", "0", "Show commands on the ready up panel");
	
	HookConVarChange(l4d_ready_survivor_freeze, SurvFreezeChange);

	HookEvent("round_start", RoundStart_Event);
	HookEvent("player_team", PlayerTeam_Event);

	casterTrie = CreateTrie();
	allowedCastersTrie = CreateTrie();

	director_no_specials = FindConVar("director_no_specials");
	god = FindConVar("god");
	director_allow_infected_bots = FindConVar("director_allow_infected_bots");
	sb_stop = FindConVar("sb_stop");
	survivor_limit = FindConVar("survivor_limit");
	z_max_player_zombies = FindConVar("z_max_player_zombies");
	sv_infinite_ammo = FindConVar("sv_infinite_ammo");
	g_cvarl4d_ready_mode = FindConVar("l4d_ready_mode");
	
	if (FindConVar("sn_main_name") != INVALID_HANDLE){
		ServerNamer = FindConVar("sn_main_name");
	} else {
		ServerNamer = FindConVar("hostname");
	}

	RegAdminCmd("sm_caster", Caster_Cmd, ADMFLAG_BAN, "Registers a player as a caster so the round will not go live unless they are ready");
	//RegAdminCmd("sm_forcestart", ForceStart_Cmd, ADMFLAG_BAN, "Forces the round to start regardless of player ready status.  Players can unready to stop a force");
	//RegAdminCmd("sm_fs", ForceStart_Cmd, ADMFLAG_BAN, "Forces the round to start regardless of player ready status.  Players can unready to stop a force");
	RegConsoleCmd("sm_forcestart", ForceStart_Cmd, "Forces the round to start regardless of player ready status.  Players can unready to stop a force");
	RegConsoleCmd("sm_fs", ForceStart_Cmd, "Forces the round to start regardless of player ready status.  Players can unready to stop a force");
	RegConsoleCmd("sm_hide", Hide_Cmd, "Hides the ready-up panel so other menus can be seen");
	RegConsoleCmd("sm_show", Show_Cmd, "Shows a hidden ready-up panel");
	
	AddCommandListener(Say_Callback, "say");
	AddCommandListener(Say_Callback, "say_team");
//	AddCommandListener(Vote_Callback, "Vote");

	RegConsoleCmd("sm_notcasting", NotCasting_Cmd, "Deregister yourself as a caster or allow admins to deregister other players");
	RegConsoleCmd("sm_uncast", NotCasting_Cmd, "Deregister yourself as a caster or allow admins to deregister other players");
	RegConsoleCmd("sm_ready", Ready_Cmd, "Mark yourself as ready for the round to go live");
	RegConsoleCmd("sm_r", Ready_Cmd, "Mark yourself as ready for the round to go live");
	RegConsoleCmd("sm_toggleready", ToggleReady_Cmd, "Toggle your ready status");
	RegConsoleCmd("sm_unready", Unready_Cmd, "Mark yourself as not ready if you have set yourself as ready");
	RegConsoleCmd("sm_nr", Unready_Cmd, "Mark yourself as not ready if you have set yourself as ready");
	RegConsoleCmd("sm_return", Return_Cmd, "Return to a valid saferoom spawn if you get stuck during an unfrozen ready-up period");
	RegConsoleCmd("sm_cast", Cast_Cmd, "Registers the calling player as a caster so the round will not go live unless they are ready");
	RegConsoleCmd("sm_kickspecs", KickSpecs_Cmd, "Let's vote to kick those Spectators!");
	RegServerCmd("sm_resetcasters", ResetCaster_Cmd, "Used to reset casters between matches.  This should be in confogl_off.cfg or equivalent for your system");
	RegServerCmd("sm_add_caster_id", AddCasterSteamID_Cmd, "Used for adding casters to the whitelist -- i.e. who's allowed to self-register as a caster");
	RegConsoleCmd("\x73\x6d\x5f\x62\x6f\x6e\x65\x73\x61\x77", Secret_Cmd, "Every player has a different secret number between 0-1023");

#if DEBUG
	RegAdminCmd("sm_initready", InitReady_Cmd, ADMFLAG_ROOT);
	RegAdminCmd("sm_initlive", InitLive_Cmd, ADMFLAG_ROOT);
#endif

	LoadTranslations("common.phrases");
}

public Action:Say_Callback(client, String:command[], args)
{
	SetEngineTime(client);
	return Plugin_Continue;
}

//Support to use "Vote Yes/No" to ready/unready(But in vote boss should have many problem)
/*
public Action:Vote_Callback(client, String:command[], args)
{
	decl String:sArgs[32];
	GetCmdArg(1, sArgs, sizeof(sArgs));
	if (StrContains(sArgs, "Yes", false) != -1)
	{
		FakeClientCommand(client, "say /ready");
	}
	else
	{
		FakeClientCommand(client, "say /unready");
	}
	
	return Plugin_Continue;
}
*/
public OnPluginEnd()
{
	if (inReadyUp)
		InitiateLive(false);
}

public OnMapStart()
{
	/* OnMapEnd needs this to work */
	GetConVarString(l4d_ready_countdown_sound, countdownSound, sizeof(countdownSound));
	GetConVarString(l4d_ready_live_sound, liveSound, sizeof(liveSound));
	PrecacheSound("/level/gnomeftw.wav");
	PrecacheSound("weapons/hegrenade/beep.wav");
	PrecacheSound(countdownSound);
	PrecacheSound(liveSound);
	for (new i = 0; i < MAX_SOUNDS; i++)
	{
		PrecacheSound(chuckleSound[i]);
	}
	for (new client = 1; client <= MAXPLAYERS; client++)
	{
		blockSecretSpam[client] = false;
	}
	readyCountdownTimer = INVALID_HANDLE;
	
	new String:sMap[64];
	GetCurrentMap(sMap, sizeof(sMap));
	if (StrEqual(sMap, "dprm1_milltown_a", false))
	{
		bSkipWarp = true;
	}
	else
	{
		bSkipWarp = false;
	}
	
	//ResetScores();
}

/* This ensures all cvars are reset if the map is changed during ready-up */
public OnMapEnd()
{
	if (inReadyUp)
		InitiateLive(false);
}

public OnClientDisconnect(client)
{
	hiddenPanel[client] = false;
	isPlayerReady[client] = false;
	g_fButtonTime[client] = 0.0;
	
	for (new i = 0; i <= 1; i++)
	{
		g_fPlayerMouse[client][i] = 0;
	}
}

stock SetEngineTime(client)
{
	g_fButtonTime[client] = GetEngineTime();
}

public Native_AddStringToReadyFooter(Handle:plugin, numParams)
{
	decl String:footer[MAX_FOOTER_LEN];
	GetNativeString(1, footer, sizeof(footer));
	if (footerCounter < MAX_FOOTERS)
	{
		if (strlen(footer) < MAX_FOOTER_LEN)
		{
			strcopy(readyFooter[footerCounter], MAX_FOOTER_LEN, footer);
			footerCounter++;
			return _:footerCounter-1;
		}
	}
	return _:-1;
}

public Native_EditFooterStringAtIndex(Handle:plugin, numParams)
{
	decl String:newString[MAX_FOOTER_LEN];
	GetNativeString(2, newString, sizeof(newString));
	int index = GetNativeCell(1);
	
	if (footerCounter < MAX_FOOTERS)
	{
		if (strlen(newString) < MAX_FOOTER_LEN)
		{
			readyFooter[index] = newString;
			return _:true;
		}
	}
	return _:false;
}

public Native_FindIndexOfFooterString(Handle:plugin, numParams)
{
	decl String:stringToSearchFor[MAX_FOOTER_LEN];
	GetNativeString(1, stringToSearchFor, sizeof(stringToSearchFor));
	
	for (new i = 0; i < footerCounter; i++){
		if (StrEqual(readyFooter[i], "\0", true)) continue;
		
		if (StrContains(readyFooter[i], stringToSearchFor, false) > -1){
			return _:i;
		}
	}
	
	return _:-1;
}

public Native_GetFooterStringAtIndex(Handle:plugin, numParams)
{
	int index = GetNativeCell(1);
	new String:buffer[65];
	GetNativeString(2, buffer, 65);
	
	
	if (index < MAX_FOOTERS){
		buffer = readyFooter[index];
	} 
	
	SetNativeString(2, buffer, 65, true);
}

public Native_IsInReady(Handle:plugin, numParams)
{
	return _:inReadyUp;
}

public Native_IsClientCaster(Handle:plugin, numParams)
{
	new client = GetNativeCell(1);
	return _:IsClientCaster(client);
}

public Native_IsIDCaster(Handle:plugin, numParams)
{
	decl String:buffer[64];
	GetNativeString(1, buffer, sizeof(buffer));
	return _:IsIDCaster(buffer);
}

stock bool:IsClientCaster(client)
{
	decl String:buffer[64];
	return GetClientAuthId(client, AuthId_Steam2, buffer, sizeof(buffer)) && IsIDCaster(buffer);
}

stock bool:IsIDCaster(const String:AuthID[])
{
	decl dummy;
	return GetTrieValue(casterTrie, AuthID, dummy);
}

public Action:Cast_Cmd(client, args)
{	
 	new String:buffer[64];
	GetClientAuthId(client, AuthId_Steam2, buffer, sizeof(buffer));
	if (GetClientTeam(client) != 1)
	{
		ChangeClientTeam(client, 1);
	}
	SetTrieValue(casterTrie, buffer, 1);
	CPrintToChat(client, "{blue}[{default}Cast{blue}] {default}You have registered yourself as a caster");
	CPrintToChat(client, "{blue}[{default}Cast{blue}] {default}Reconnect to make your Addons work.");
	return Plugin_Handled;
}

public Action:Caster_Cmd(client, args)
{	
	if (args < 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_caster <player>");
		return Plugin_Handled;
	}
	
	decl String:buffer[64];
	GetCmdArg(1, buffer, sizeof(buffer));
	
	new target = FindTarget(client, buffer, true, false);
	if (target > 0) // If FindTarget fails we don't need to print anything as it prints it for us!
	{
		if (GetClientAuthId(target, AuthId_Steam2, buffer, sizeof(buffer)))
		{
			SetTrieValue(casterTrie, buffer, 1);
			ReplyToCommand(client, "Registered %N as a caster", target);
			CPrintToChat(client, "{blue}[{olive}!{blue}] {default}An Admin has registered you as a caster");
		}
		else
		{
			ReplyToCommand(client, "Couldn't find Steam ID.  Check for typos and let the player get fully connected.");
		}
	}
	return Plugin_Handled;
}

public Action:ResetCaster_Cmd(args)
{
	ClearTrie(casterTrie);
	return Plugin_Handled;
}

public Action:AddCasterSteamID_Cmd(args)
{
	decl String:buffer[128];
	GetCmdArg(1, buffer, sizeof(buffer));
	if (buffer[0] != EOS) 
	{
		new index = FindStringInArray(allowedCastersTrie, buffer);
		if (index == -1)
		{
			PushArrayString(allowedCastersTrie, buffer);
			PrintToServer("[casters_database] Added '%s'", buffer);
		}
		else PrintToServer("[casters_database] '%s' already exists", buffer);
	}
	else PrintToServer("[casters_database] No args specified / empty buffer");
	return Plugin_Handled;
}

public Action:Hide_Cmd(client, args)
{
	hiddenPanel[client] = true;
	return Plugin_Handled;
}

public Action:Show_Cmd(client, args)
{
	hiddenPanel[client] = false;
	return Plugin_Handled;
}

public Action:NotCasting_Cmd(client, args)
{
	decl String:buffer[64];
	
	if (args < 1) // If no target is specified
	{
		GetClientAuthId(client, AuthId_Steam2, buffer, sizeof(buffer));
		RemoveFromTrie(casterTrie, buffer);
		CPrintToChat(client, "{blue}[{default}Reconnect{blue}] {default}You will be reconnected to the server..");
		CPrintToChat(client, "{blue}[{default}Reconnect{blue}] {default}There's a black screen instead of a loading bar!");
		CreateTimer(3.0, Reconnect, client);
		return Plugin_Handled;
	}
	else // If a target is specified
	{
		new AdminId:id;
		id = GetUserAdmin(client);
		new bool:hasFlag = false;
		
		if (id != INVALID_ADMIN_ID)
		{
			hasFlag = GetAdminFlag(id, Admin_Ban); // Check for specific admin flag
		}
		
		if (!hasFlag)
		{
			ReplyToCommand(client, "Only admins can remove other casters. Use sm_notcasting without arguments if you wish to remove yourself.");
			return Plugin_Handled;
		}
		
		GetCmdArg(1, buffer, sizeof(buffer));
		
		new target = FindTarget(client, buffer, true, false);
		if (target > 0) // If FindTarget fails we don't need to print anything as it prints it for us!
		{
			if (GetClientAuthId(target, AuthId_Steam2, buffer, sizeof(buffer)))
			{
				RemoveFromTrie(casterTrie, buffer);
				ReplyToCommand(client, "%N is no longer a caster", target);
			}
			else
			{
				ReplyToCommand(client, "Couldn't find Steam ID.  Check for typos and let the player get fully connected.");
			}
		}
		return Plugin_Handled;
	}
}

public Action:Reconnect(Handle:timer, any:client)
{
	if (IsClientConnected(client))
	{
		ReconnectClient(client);
	}
	return Plugin_Continue;
}

public Action:ForceStart_Cmd(client, args)
{
	if (inReadyUp && g_cvarl4d_ready_mode.IntValue == 0)
	{
		new AdminId:id;
		id = GetUserAdmin(client);
		new bool:hasFlag = false;
		
		if (id != INVALID_ADMIN_ID)
		{
			hasFlag = GetAdminFlag(id, Admin_Ban); // Check for specific admin flag
		}
		if (hasFlag)
		{
			InitiateLiveCountdown();
			return Plugin_Handled;
		}
		
		StartForceStartVote(client);
	}
	else if (g_cvarl4d_ready_mode.IntValue == 1)
	{
		new AdminId:id;
		id = GetUserAdmin(client);
		new bool:hasFlag = false;
		
		if (id != INVALID_ADMIN_ID)
		{
			hasFlag = GetAdminFlag(id, Admin_Ban); // Check for specific admin flag
		}
		if (hasFlag)
		{
			readyForceDelayFirst = 0;
			readyForceDelaySecond = 0;
			return Plugin_Handled;
		}
		return Plugin_Handled;
	}
	return Plugin_Handled;
}

public Action:KickSpecs_Cmd(client, args)
{
	if (inReadyUp)
	{
		new AdminId:id;
		id = GetUserAdmin(client);
		new bool:hasFlag = false;
		
		if (id != INVALID_ADMIN_ID)
		{
			hasFlag = GetAdminFlag(id, Admin_Ban); // Check for specific admin flag
		}
		
		if (hasFlag)
		{
			CreateTimer(2.0, Timer_KickSpecs);
			new String:adminName[64];
			GetClientName(client, adminName, 64);
			CPrintToChatAll("{red}[{default}!{red}]{default} Spectators have been kicked by: {olive}%s{default}!", adminName);
			return Plugin_Handled;
		}
		
		StartKickSpecsVote(client);
	}
	return Plugin_Handled;
}

StartForceStartVote(client)
{
	if (!IsPlayer(client)) { return; }
	if (!IsNewBuiltinVoteAllowed()) { return; }
	
	g_hVote = CreateBuiltinVote(VoteActionHandler, BuiltinVoteType_Custom_YesNo, BuiltinVoteAction_Cancel | BuiltinVoteAction_VoteEnd | BuiltinVoteAction_End);

	decl String:sBuffer[64];
	FormatEx(sBuffer, sizeof(sBuffer), "Force start the game?");
	SetBuiltinVoteArgument(g_hVote, sBuffer);
	SetBuiltinVoteInitiator(g_hVote, client);
	SetBuiltinVoteResultCallback(g_hVote, ForceStartVoteResultHandler);

	FakeClientCommand(client, "Vote Yes");
}

StartKickSpecsVote(client)
{
	if (!IsPlayer(client)) { return; }
	if (!IsNewBuiltinVoteAllowed()) { return; }
	
	g_hVote = CreateBuiltinVote(VoteActionHandler, BuiltinVoteType_Custom_YesNo, BuiltinVoteAction_Cancel | BuiltinVoteAction_VoteEnd | BuiltinVoteAction_End);

	decl String:sBuffer[128];
	FormatEx(sBuffer, sizeof(sBuffer), "Kick All Non-Admin and Non-Casting Spectators?");
	SetBuiltinVoteArgument(g_hVote, sBuffer);
	SetBuiltinVoteInitiator(g_hVote, client);
	SetBuiltinVoteResultCallback(g_hVote, KickSpecsVoteResultHandler);

	FakeClientCommand(client, "Vote Yes");
}

public VoteActionHandler(Handle:vote, BuiltinVoteAction:action, param1, param2)
{
	switch (action)
	{
		case BuiltinVoteAction_End:
		{
			g_hVote = INVALID_HANDLE;
			CloseHandle(vote);
		}
		case BuiltinVoteAction_Cancel:
		{
			DisplayBuiltinVoteFail(vote, BuiltinVoteFailReason:param1);
		}
	}
}

public ForceStartVoteResultHandler(Handle:vote, num_votes, num_clients, const client_info[][2], num_items, const item_info[][2])
{
	if (!inReadyUp)
	{
		DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Generic);
	}
	
	for (new i = 0; i < num_items; i++)
	{
		if (item_info[i][BUILTINVOTEINFO_ITEM_INDEX] == BUILTINVOTES_VOTE_YES)
		{
			if (item_info[i][BUILTINVOTEINFO_ITEM_VOTES] > (num_clients / 2))
			{
				decl String:sBuffer[64];
				FormatEx(sBuffer, sizeof(sBuffer), "Forcing start...");
				DisplayBuiltinVotePass(vote, sBuffer);
				CreateTimer(2.0, Timer_ForceStart);
				return;
			}
		}
	}

	DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
}

public Action:Timer_ForceStart(Handle:timer)
{
	InitiateLiveCountdown();
}

public KickSpecsVoteResultHandler(Handle:vote, num_votes, num_clients, const client_info[][2], num_items, const item_info[][2])
{
	for (new i = 0; i < num_items; i++)
	{
		if (item_info[i][BUILTINVOTEINFO_ITEM_INDEX] == BUILTINVOTES_VOTE_YES)
		{
			if (item_info[i][BUILTINVOTEINFO_ITEM_VOTES] > (num_clients / 2))
			{
				decl String:sBuffer[64];
				FormatEx(sBuffer, sizeof(sBuffer), "Be gone Spectators!");
				DisplayBuiltinVotePass(vote, sBuffer);
				CreateTimer(2.0, Timer_KickSpecs);
				return;
			}
		}
	}

	DisplayBuiltinVoteFail(vote, BuiltinVoteFail_Loses);
}

public Action:Timer_KickSpecs(Handle:timer)
{
	for (new c = 1; c <= MaxClients; c++)
	{
		if (!IsClientInGame(c) || IsFakeClient(c)) { continue; }
		if (IsPlayer(c)) { continue; }
		if (IsClientCaster(c)) { continue; }
		if (GetUserAdmin(c) != INVALID_ADMIN_ID) { continue; }
					
		KickClient(c, "No Spectators, please! :]");
	}

}

public Action:Ready_Cmd(client, args)
{
	if (inReadyUp)
	{
		isPlayerReady[client] = true;
		if (CheckFullReady())
			InitiateLiveCountdown();
	}

	return Plugin_Handled;
}

public Action:Unready_Cmd(client, args)
{
	if (inReadyUp)
	{
		SetEngineTime(client);
		isPlayerReady[client] = false;
		CancelFullReady();
	}

	return Plugin_Handled;
}

public Action:ToggleReady_Cmd(client, args)
{
	if (inReadyUp)
	{
		isPlayerReady[client] = !isPlayerReady[client];
		if (isPlayerReady[client] && CheckFullReady())
		{
			InitiateLiveCountdown();
		}
		else
		{
			SetEngineTime(client);
			CancelFullReady();
		}
	}

	return Plugin_Handled;
}

/* No need to do any other checks since it seems like this is required no matter what since the intros unfreezes players after the animation completes */
public Action:OnPlayerRunCmd(client, &buttons, &impulse, Float:vel[3], Float:angles[3], &weapon, &subtype, &cmdnum, &tickcount, &seed, mouse[2])
{
	if (inReadyUp)
	{
		if (buttons || impulse)
		{
			SetEngineTime(client);
		}
		
		// Mouse Movement Check
		new bool:hasRecordedMouse = false;
		for (new j = 0; j <= 1; j++)
		{
			if (g_fPlayerMouse[client][j] != 0)
			{
				hasRecordedMouse = true;
				break;
			}
		}
		if (hasRecordedMouse)
		{
			for (new i = 0; i <= 1; i++)
			{
				if (mouse[i] != g_fPlayerMouse[client][i])
				{
					SetEngineTime(client);
					break;
				}
			}
		}
		for (new c = 0; c <= 1; c++)
		{
			g_fPlayerMouse[client][c] = mouse[c];
		}
		
		if (IsClientInGame(client) && L4D2Team:GetClientTeam(client) == L4D2Team_Survivor)
		{
			if (GetConVarBool(l4d_ready_survivor_freeze))
			{
				if (!(GetEntityMoveType(client) == MOVETYPE_NONE || GetEntityMoveType(client) == MOVETYPE_NOCLIP))
				{
					SetClientFrozen(client, true);
				}
			}
			else
			{
				if (GetEntityFlags(client) & FL_INWATER)
				{
					ReturnPlayerToSaferoom(client, false);
				}
			}
			
			if (bSkipWarp)
			{
				SetTeamFrozen(L4D2Team_Survivor, true);
			}

		}
	}
}

public SurvFreezeChange(Handle:convar, const String:oldValue[], const String:newValue[])
{
	ReturnTeamToSaferoom(L4D2Team_Survivor);
	if (bSkipWarp)
	{
		SetTeamFrozen(L4D2Team_Survivor, true);
	}
	else
	{
		SetTeamFrozen(L4D2Team_Survivor, GetConVarBool(convar));
	}
}

public Action:L4D_OnFirstSurvivorLeftSafeArea(client)
{
	if (inReadyUp && isRoundLive == 0)
	{
		if (bSkipWarp)
		{
			return Plugin_Handled;
		}

		ReturnPlayerToSaferoom(client, false);
		
		return Plugin_Handled;
	}
	return Plugin_Continue;
}

public Action:Return_Cmd(client, args)
{
	if (client > 0
			&& inReadyUp
			&& L4D2Team:GetClientTeam(client) == L4D2Team_Survivor)
	{
		ReturnPlayerToSaferoom(client, false);
	}
	return Plugin_Handled;
}

public RoundStart_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	switch(g_cvarl4d_ready_mode.IntValue)
	{
		case 0: InitiateReadyUp();
		case 1: InitiateForceReadyUpCountdown();
	}
}

public PlayerTeam_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	SetEngineTime(client);
	CheckFullReady();
	new L4D2Team:oldteam = L4D2Team:GetEventInt(event, "oldteam");
	new L4D2Team:team = L4D2Team:GetEventInt(event, "team");
	if (oldteam == L4D2Team_Survivor || oldteam == L4D2Team_Infected ||
			team == L4D2Team_Survivor || team == L4D2Team_Infected)
	{
		CancelFullReady();
	}
}

#if DEBUG
public Action:InitReady_Cmd(client, args)
{
	InitiateReadyUp();
	return Plugin_Handled;
}

public Action:InitLive_Cmd(client, args)
{
	InitiateLive();
	return Plugin_Handled;
}
#endif

public DummyHandler(Handle:menu, MenuAction:action, param1, param2) { }

public Action:MenuRefresh_Timer(Handle:timer)
{
	if (inReadyUp)
	{
		UpdatePanel();
		return Plugin_Continue;
	}
	return Plugin_Handled;
}

public Action:MenuCmd_Timer(Handle:timer)
{
	if (inReadyUp)
	{
		iCmd += 1;
		return Plugin_Continue;
	}
	return Plugin_Stop;
}

UpdatePanel()
{
	if (IsBuiltinVoteInProgress()) { return; }
		
	if (menuPanel != INVALID_HANDLE)
	{
		CloseHandle(menuPanel);
		menuPanel = INVALID_HANDLE;
	}

	//new String:readyBuffer[800] = "";
	//new String:unreadyBuffer[800] = "";
	new String:survivorBuffer[800] = "";
	new String:infectedBuffer[800] = "";
	new String:casterBuffer[500] = "";
	new String:specBuffer[800] = "";
	//new readyCount = 0;
	//new unreadyCount = 0;
	//new survivorCount = 0;
	//new infectedCount = 0;
	new casterCount = 0;
	new playerCount = 0;
	new specCount = 0;

	menuPanel = CreatePanel();

	new String:ServerBuffer[128];
	new String:ServerName[32];
	new String:cfgName[32];
	PrintCmd();
	
	GetConVarString(ServerNamer, ServerName, sizeof(ServerName));

	GetConVarString(l4d_ready_cfg_name, cfgName, sizeof(cfgName));
	Format(ServerBuffer, sizeof(ServerBuffer), "▸ Server: %s \n▸ Slots: %d/%d\n▸ Config: %s", ServerName, GetSeriousClientCount(), GetConVarInt(FindConVar("sv_maxplayers")), cfgName);
	DrawPanelText(menuPanel, ServerBuffer);
	
	if (GetConVarBool(l4d_ready_show_time))
	{
		decl String:timeBuf[128];
		Format(timeBuf, sizeof(timeBuf), "▸ Time: %02d:%02d", RoundToFloor((GetGameTime() - liveTime) / 60), RoundToFloor(GetGameTime() - liveTime) % 60);
		DrawPanelText(menuPanel, timeBuf);
	}
	
	if (GetConVarBool(l4d_ready_show_commands))
	{
		DrawPanelText(menuPanel, " ");
		DrawPanelText(menuPanel, "▸ Commands:");
		DrawPanelText(menuPanel, sCmd);
	}
	
	DrawPanelText(menuPanel, " ");
	
	decl String:nameBuf[64];
	decl String:authBuffer[64];
	decl bool:caster;
	decl dummy;
	new infs = 0;
	new surs = 0;
	new Float:fTime = GetEngineTime();
	for (new client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && !IsFakeClient(client))
		{
			++playerCount;
			GetClientName(client, nameBuf, sizeof(nameBuf));
			GetClientAuthId(client, AuthId_Steam2, authBuffer, sizeof(authBuffer));
			caster = GetTrieValue(casterTrie, authBuffer, dummy);
			
			if (IsPlayer(client))
			{
				if (isPlayerReady[client])
				{
					if (L4D2Team:GetClientTeam(client) != L4D2Team_Spectator)
						if (!inLiveCountdown) PrintHintText(client, "You are ready.\nSay !unready to unready.");
						
					switch (L4D2Team:GetClientTeam(client))
					{
						case L4D2Team_Survivor: {
							surs++;
							Format(nameBuf, sizeof(nameBuf), "☑ %s%s\n", nameBuf, ( IsPlayerAfk(client, fTime) ? " [AFK]" : "" ));
							StrCat(survivorBuffer, sizeof(survivorBuffer), nameBuf);
						}
						case L4D2Team_Infected: {
							infs++;
							Format(nameBuf, sizeof(nameBuf), "☑ %s%s\n", nameBuf, ( IsPlayerAfk(client, fTime) ? " [AFK]" : "" ));
							StrCat(infectedBuffer, sizeof(infectedBuffer), nameBuf);
						}
					}
				}
				else 
				{
					if (L4D2Team:GetClientTeam(client) != L4D2Team_Spectator)
						if (!inLiveCountdown) PrintHintText(client, "You are not ready.\nSay !ready to ready up.");
						
					switch (L4D2Team:GetClientTeam(client))
					{
						case L4D2Team_Survivor: {
							surs++;
							Format(nameBuf, sizeof(nameBuf), "☐ %s%s\n",nameBuf, ( IsPlayerAfk(client, fTime) ? " [AFK]" : "" ));
							StrCat(survivorBuffer, sizeof(survivorBuffer), nameBuf);
						}
						case L4D2Team_Infected: {
							infs++;
							Format(nameBuf, sizeof(nameBuf), "☐ %s%s\n",nameBuf, ( IsPlayerAfk(client, fTime) ? " [AFK]" : "" ));
							StrCat(infectedBuffer, sizeof(infectedBuffer), nameBuf);
						}
					}
				}
			}
			
			if (caster)
			{
				++casterCount;
				Format(nameBuf, 64, "%s\n", nameBuf);
				StrCat(casterBuffer, sizeof(casterBuffer), nameBuf);
			}
			else if (L4D2Team:GetClientTeam(client) == L4D2Team_Spectator)
			{
				++specCount;
				if (playerCount <= GetConVarInt(l4d_ready_max_players))
				{
					Format(nameBuf, sizeof(nameBuf), "%s\n", nameBuf);
					StrCat(specBuffer, sizeof(specBuffer), nameBuf);
				}
			}
		}
	}
	
	new textCount = 0;
	new bufLen = strlen(survivorBuffer);
	if (bufLen != 0)
	{
		survivorBuffer[bufLen] = '\0';
		ReplaceString(survivorBuffer, sizeof(survivorBuffer), "#buy", "<- TROLL");
		ReplaceString(survivorBuffer, sizeof(survivorBuffer), "#", "_");
		Format(nameBuf, sizeof(nameBuf), "->1. Survivors");
		DrawPanelText(menuPanel, nameBuf);
		DrawPanelText(menuPanel, survivorBuffer);
		
	
	}

	bufLen = strlen(infectedBuffer);
	if (bufLen != 0)
	{
		infectedBuffer[bufLen] = '\0';
		ReplaceString(infectedBuffer, sizeof(infectedBuffer), "#buy", "<- TROLL");
		ReplaceString(infectedBuffer, sizeof(infectedBuffer), "#", "_");
		Format(nameBuf, sizeof(nameBuf), "->2. Infected", ++textCount);
		DrawPanelText(menuPanel, nameBuf);
		DrawPanelText(menuPanel, infectedBuffer);
	}
	
	bufLen = strlen(casterBuffer);
	if (bufLen != 0)
	{
		casterBuffer[bufLen] = '\0';
		Format(nameBuf, sizeof(nameBuf), "->3. Casters.", ++textCount);
		DrawPanelText(menuPanel, nameBuf);
		ReplaceString(casterBuffer, sizeof(casterBuffer), "#", "_", true);
		DrawPanelText(menuPanel, casterBuffer);
	}
	
	bufLen = strlen(specBuffer);
	if (bufLen != 0)
	{
		specBuffer[bufLen] = '\0';
		
		if (casterCount > 0)
		{
			Format(nameBuf, sizeof(nameBuf), "->4. Spectators", ++textCount);
		}
		else
		{
			Format(nameBuf, sizeof(nameBuf), "->3. Spectators", ++textCount);
		}
		
		DrawPanelText(menuPanel, nameBuf);
		ReplaceString(specBuffer, sizeof(specBuffer), "#", "_");
		if (specCount > 3)
			FormatEx(specBuffer, sizeof(specBuffer), "Many (%d)", specCount);
			
		DrawPanelText(menuPanel, specBuffer);
	}

/*
	decl String:cfgBuf[128];
	GetConVarString(l4d_ready_cfg_name, cfgBuf, sizeof(cfgBuf));
	DrawPanelText(menuPanel, cfgBuf);
*/

	bufLen = strlen(readyFooter[0]);
	if (bufLen != 0)
	{
		for (new i = 0; i < MAX_FOOTERS; i++)
		{
			DrawPanelText(menuPanel, readyFooter[i]);
		}
	}

	for (new client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && !IsFakeClient(client) && !hiddenPanel[client])
		{
			SendPanelToClient(menuPanel, client, DummyHandler, 1);
		}
	}
}

InitiateReadyUp()
{
	liveTime = GetGameTime();


	for (new i = 0; i <= MAXPLAYERS; i++)
	{
		isPlayerReady[i] = false;
	}
	

	UpdatePanel();
	CreateTimer(1.0, MenuRefresh_Timer, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	CreateTimer(4.0, MenuCmd_Timer, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);

	inReadyUp = true;
	inLiveCountdown = false;
	readyCountdownTimer = INVALID_HANDLE;

	if (GetConVarBool(l4d_ready_disable_spawns))
	{
		SetConVarBool(director_no_specials, true);
	}

	DisableEntities();
	SetConVarFlags(sv_infinite_ammo, GetConVarFlags(god) & ~FCVAR_NOTIFY);
	SetConVarBool(sv_infinite_ammo, true);
	SetConVarFlags(sv_infinite_ammo, GetConVarFlags(god) | FCVAR_NOTIFY);
	SetConVarFlags(god, GetConVarFlags(god) & ~FCVAR_NOTIFY);
	SetConVarBool(god, true);
	SetConVarFlags(god, GetConVarFlags(god) | FCVAR_NOTIFY);
	SetConVarBool(sb_stop, true);

	L4D2_CTimerStart(L4D2CT_VersusStartTimer, 99999.9);
}

InitiateForceReadyUpCountdown()
{
	isRoundLive = 0;
	inReadyUp = true;
	
	if (!GameRules_GetProp("m_bInSecondHalfOfRound"))
	{
		DisableEntities();
		SetConVarFlags(sv_infinite_ammo, GetConVarFlags(god) & ~FCVAR_NOTIFY);
		SetConVarBool(sv_infinite_ammo, true);
		SetConVarFlags(sv_infinite_ammo, GetConVarFlags(god) | FCVAR_NOTIFY);
		SetConVarFlags(god, GetConVarFlags(god) & ~FCVAR_NOTIFY);
		SetConVarBool(god, true);
		SetConVarFlags(god, GetConVarFlags(god) | FCVAR_NOTIFY);
		
		if (g_cvarl4d_ready_mode.IntValue == 1)
		{
			SetConVarFlags(director_allow_infected_bots, GetConVarFlags(director_allow_infected_bots) & ~FCVAR_NOTIFY);
			SetConVarBool(director_allow_infected_bots, false);
			SetConVarFlags(director_allow_infected_bots, GetConVarFlags(director_allow_infected_bots) | FCVAR_NOTIFY);
		}
		
		SetConVarBool(sb_stop, true);
		readyForceDelayFirst = GetConVarInt(l4d_ready_delay_t1_forcestart_first);
		CreateTimer(1.0, ForceReadyCountdownDelay_TimerFirst, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	}
	else
	{
		DisableEntities();
		SetConVarFlags(sv_infinite_ammo, GetConVarFlags(god) & ~FCVAR_NOTIFY);
		SetConVarBool(sv_infinite_ammo, true);
		SetConVarFlags(sv_infinite_ammo, GetConVarFlags(god) | FCVAR_NOTIFY);
		SetConVarFlags(god, GetConVarFlags(god) & ~FCVAR_NOTIFY);
		SetConVarBool(god, true);
		SetConVarFlags(god, GetConVarFlags(god) | FCVAR_NOTIFY);
		if (g_cvarl4d_ready_mode.IntValue == 1)
		{
			SetConVarFlags(director_allow_infected_bots, GetConVarFlags(director_allow_infected_bots) & ~FCVAR_NOTIFY);
			SetConVarBool(director_allow_infected_bots, false);
			SetConVarFlags(director_allow_infected_bots, GetConVarFlags(director_allow_infected_bots) | FCVAR_NOTIFY);
		}
		SetConVarBool(sb_stop, true);
		readyForceDelaySecond = GetConVarInt(l4d_ready_delay_t1_forcestart_second);
		CreateTimer(1.0, ForceReadyCountdownDelay_TimerSecond, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action:ForceReadyCountdownDelay_TimerFirst(Handle:timer)
{
	if (readyForceDelayFirst == 0)
	{
		for (new i = 0; i <= MAXPLAYERS; i++)
			isPlayerReady[i] = true;

		PrintHintTextToAll("Round started!");
		InitiateLive();
		
		return Plugin_Stop;
	}
	else
	{
		PrintHintTextToAll("Starting round on %d", readyForceDelayFirst);
		readyForceDelayFirst--;
	}
	return Plugin_Continue;
}

public Action:ForceReadyCountdownDelay_TimerSecond(Handle:timer)
{
	if (readyForceDelaySecond == 0)
	{
		for (new i = 0; i <= MAXPLAYERS; i++)
			isPlayerReady[i] = true;

		PrintHintTextToAll("Round started!");
		InitiateLive();
		
		return Plugin_Stop;
	}
	else
	{
		PrintHintTextToAll("Starting round on %d", readyForceDelaySecond);
		readyForceDelaySecond--;
	}
	return Plugin_Continue;
}

PrintCmd()
{
	if (iCmd > 9)
	{
		iCmd = 1;
	}
	switch (iCmd)
	{
		case 1: {
			Format(sCmd, sizeof(sCmd), "->1. !ready / !unready");
		}
		case 2: {
			Format(sCmd, sizeof(sCmd), "->2. !slots #");
		}
		case 3: {
			Format(sCmd, sizeof(sCmd), "->3. !voteboss <tank> <witch>");
		}
		case 4: {
			Format(sCmd, sizeof(sCmd), "->4. !match / !rmatch");
		}
		case 5: {
			Format(sCmd, sizeof(sCmd), "->5. !cast / !uncast");
		}
		case 6: {
			Format(sCmd, sizeof(sCmd), "->6. !setscores <survs> <inf>");
		}
		case 7: {
			Format(sCmd, sizeof(sCmd), "->7. !lerps");
		}
		case 8: {
			Format(sCmd, sizeof(sCmd), "->8. !secondary");
		}
		case 9: {
			Format(sCmd, sizeof(sCmd), "->9. !forcestart / !fs");
		}
		default: {
		}
	}
}

InitiateLive(bool:real = true)
{
	inReadyUp = false;
	inLiveCountdown = false;
	isRoundLive = 1;

	SetTeamFrozen(L4D2Team_Survivor, false);

	EnableEntities();
	SetConVarFlags(sv_infinite_ammo, GetConVarFlags(god) & ~FCVAR_NOTIFY);
	SetConVarBool(sv_infinite_ammo, false);
	SetConVarFlags(sv_infinite_ammo, GetConVarFlags(god) | FCVAR_NOTIFY);
	SetConVarBool(director_no_specials, false);
	SetConVarFlags(god, GetConVarFlags(god) & ~FCVAR_NOTIFY);
	SetConVarBool(god, false);
	SetConVarFlags(god, GetConVarFlags(god) | FCVAR_NOTIFY);
	if ( g_cvarl4d_ready_mode.IntValue == 1 || g_cvarl4d_ready_mode.IntValue == 2 )
	{
		SetConVarFlags(director_allow_infected_bots, GetConVarFlags(director_allow_infected_bots) & ~FCVAR_NOTIFY);
		SetConVarBool(director_allow_infected_bots, true);
		SetConVarFlags(director_allow_infected_bots, GetConVarFlags(director_allow_infected_bots) | FCVAR_NOTIFY);
	}
	SetConVarBool(sb_stop, false);

	L4D2_CTimerStart(L4D2CT_VersusStartTimer, 60.0);

	for (new i = 0; i < 4; i++)
	{
		GameRules_SetProp("m_iVersusDistancePerSurvivor", 0, _,
				i + 4 * GameRules_GetProp("m_bAreTeamsFlipped"));
	}

	for (new i = 0; i < MAX_FOOTERS; i++)
	{
		readyFooter[i] = "";
	}

	footerCounter = 0;
	if (real)
	{
		Call_StartForward(liveForward);
		Call_Finish();
	}
}

public OnBossVote()
{
	for (new i = 0; i < MAX_FOOTERS; i++)
	{
		if (StrContains(readyFooter[i], "Tank: ", true))
		{
			footerCounter = i;
			break;
		}
	}
}

ReturnPlayerToSaferoom(client, bool:flagsSet = true)
{
	new warp_flags;
	new give_flags;
	if (!flagsSet)
	{
		warp_flags = GetCommandFlags("warp_to_start_area");
		SetCommandFlags("warp_to_start_area", warp_flags & ~FCVAR_CHEAT);
		give_flags = GetCommandFlags("give");
		SetCommandFlags("give", give_flags & ~FCVAR_CHEAT);
	}

	if (GetEntProp(client, Prop_Send, "m_isHangingFromLedge"))
	{
		FakeClientCommand(client, "give health");
	}

	FakeClientCommand(client, "warp_to_start_area");

	if (!flagsSet)
	{
		SetCommandFlags("warp_to_start_area", warp_flags);
		SetCommandFlags("give", give_flags);
	}
}

ReturnTeamToSaferoom(L4D2Team:team)
{
	new warp_flags = GetCommandFlags("warp_to_start_area");
	SetCommandFlags("warp_to_start_area", warp_flags & ~FCVAR_CHEAT);
	new give_flags = GetCommandFlags("give");
	SetCommandFlags("give", give_flags & ~FCVAR_CHEAT);

	for (new client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && L4D2Team:GetClientTeam(client) == team)
		{
			ReturnPlayerToSaferoom(client, true);
		}
	}

	SetCommandFlags("warp_to_start_area", warp_flags);
	SetCommandFlags("give", give_flags);
}



SetTeamFrozen(L4D2Team:team, bool:freezeStatus)
{
	for (new client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && L4D2Team:GetClientTeam(client) == team)
		{
			SetClientFrozen(client, freezeStatus);
		}
	}
}

bool:CheckFullReady()
{
	new readyCount = 0;
	//new casterCount = 0;
	for (new client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client))
		{
			/*
			if (IsClientCaster(client))
			{
				casterCount++;
			}*/

			if ((IsPlayer(client) /*|| IsClientCaster(client)*/) && isPlayerReady[client])
			{
				readyCount++;
			}
		}
	}
	
	new String:gamemodeBuf[32], bool:IsVersus;
	GetConVarString(FindConVar("mp_gamemode"), gamemodeBuf, sizeof(gamemodeBuf));
	IsVersus = (StrEqual(gamemodeBuf, "versus") || StrEqual(gamemodeBuf, "scavenge"));
	
	new zombiesplayermax = GetConVarInt(z_max_player_zombies);
	return readyCount >= GetConVarInt(survivor_limit) + (IsVersus ? zombiesplayermax : 0);
}

InitiateLiveCountdown()
{
	if (readyCountdownTimer == INVALID_HANDLE)
	{
		ReturnTeamToSaferoom(L4D2Team_Survivor);
		SetTeamFrozen(L4D2Team_Survivor, true);
		PrintHintTextToAll("Going live!\nSay !unready to cancel");
		inLiveCountdown = true;
		readyDelay = GetConVarInt(l4d_ready_delay);
		readyCountdownTimer = CreateTimer(1.0, ReadyCountdownDelay_Timer, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action:ReadyCountdownDelay_Timer(Handle:timer)
{
	if (readyDelay == 0)
	{
		PrintHintTextToAll("Round is live!");
		InitiateLive();
		readyCountdownTimer = INVALID_HANDLE;
		if (GetConVarBool(l4d_ready_enable_sound))
		{
			if (GetConVarBool(l4d_ready_chuckle))
			{
				EmitSoundToAll(chuckleSound[GetRandomInt(0,MAX_SOUNDS-1)]);
			}
			else { EmitSoundToAll(liveSound, _, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.5); }
		}
		return Plugin_Stop;
	}
	else
	{
		PrintHintTextToAll("Live in: %d\nSay !unready to cancel", readyDelay);
		if (GetConVarBool(l4d_ready_enable_sound))
		{
			EmitSoundToAll(countdownSound, _, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.5);
		}
		readyDelay--;
	}
	return Plugin_Continue;
}

CancelFullReady()
{
	if (readyCountdownTimer != INVALID_HANDLE)
	{
		if (bSkipWarp)
		{
			SetTeamFrozen(L4D2Team_Survivor, true);
		}
		else
		{
			SetTeamFrozen(L4D2Team_Survivor, GetConVarBool(l4d_ready_survivor_freeze));
		}
		inLiveCountdown = false;
		CloseHandle(readyCountdownTimer);
		readyCountdownTimer = INVALID_HANDLE;
		PrintHintTextToAll("Countdown Cancelled!");
\
	}
}

stock GetSeriousClientCount()
{
	new clients = 0;
	
	for (new i = 1; i <= GetMaxClients(); i++)
	{
		if (IsClientConnected(i) && !IsFakeClient(i))
		{
			clients++;
		}
	}
	
	return clients;
}

stock SetClientFrozen(client, freeze)
{
	SetEntityMoveType(client, freeze ? MOVETYPE_NONE : MOVETYPE_WALK);
}

stock IsPlayerAfk(int client, float fTime)
{
	return __FLOAT_GT__(FloatSub(fTime, g_fButtonTime[client]), 15.0);
}

stock IsPlayer(client)
{
	new L4D2Team:team = L4D2Team:GetClientTeam(client);
	return (team == L4D2Team_Survivor || team == L4D2Team_Infected);
}

stock GetTeamHumanCount(L4D2Team:team)
{
	new humans = 0;
	
	for (new client = 1; client <= MaxClients; client++)
	{
		if (IsClientInGame(client) && !IsFakeClient(client) && L4D2Team:GetClientTeam(client) == team)
		{
			humans++;
		}
	}
	
	return humans;
}

DisableEntities() 
{
	ActivateEntities("prop_door_rotating", "SetUnbreakable");
	MakePropsUnbreakable();
}

EnableEntities() 
{	
	ActivateEntities("prop_door_rotating", "SetBreakable");
	MakePropsBreakable();
}


ActivateEntities(String:className[], String:inputName[]) { 
	new iEntity;
	
	while ( (iEntity = FindEntityByClassname(iEntity, className)) != -1 ) {
		if ( !IsValidEdict(iEntity) || !IsValidEntity(iEntity) ) {
			continue;
		}
			
		if (GetEntProp(iEntity, Prop_Data, "m_spawnflags") & (1 << 19)) 
		{
			continue;
		}
	
		AcceptEntityInput(iEntity, inputName);
	}
}

MakePropsUnbreakable() {
	new iEntity;
	
	while ( (iEntity = FindEntityByClassname(iEntity, "prop_physics")) != -1 ) {
	if ( !IsValidEdict(iEntity) || !IsValidEntity(iEntity)) {
		continue;
	}
	
	
	DispatchKeyValueFloat(iEntity, "minhealthdmg", 10000.0);
	}
}

MakePropsBreakable() {
	new iEntity;
	
	while ( (iEntity = FindEntityByClassname(iEntity, "prop_physics")) != -1 ) {
	if ( !IsValidEdict(iEntity) ||  !IsValidEntity(iEntity) ) {
		continue;
	}
	DispatchKeyValueFloat(iEntity, "minhealthdmg", 5.0);
	}
}

public Action:Secret_Cmd(client, args)
{
	if (inReadyUp)
	{
		decl String:steamid[64];
		decl String:argbuf[30];
		GetCmdArg(1, argbuf, sizeof(argbuf));
		new arg = StringToInt(argbuf);
		GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));
		new id = StringToInt(steamid[10]);

		if ((id & 1023) ^ arg == 'C'+'a'+'n'+'a'+'d'+'a'+'R'+'o'+'x')
		{
			DoSecrets(client);
			isPlayerReady[client] = true;
			if (CheckFullReady())
				InitiateLiveCountdown();

			return Plugin_Handled;
		}
		
	}
	return Plugin_Continue;
}

stock DoSecrets(client)
{
	if (L4D2Team:GetClientTeam(client) == L4D2Team_Survivor && !blockSecretSpam[client])
	{
		new particle = CreateEntityByName("info_particle_system");
		decl Float:pos[3];
		GetClientAbsOrigin(client, pos);
		pos[2] += 80;
		TeleportEntity(particle, pos, NULL_VECTOR, NULL_VECTOR);
		DispatchKeyValue(particle, "effect_name", "achieved");
		DispatchKeyValue(particle, "targetname", "particle");
		DispatchSpawn(particle);
		ActivateEntity(particle);
		AcceptEntityInput(particle, "start");
		CreateTimer(5.0, killParticle, particle, TIMER_FLAG_NO_MAPCHANGE);
		EmitSoundToAll("/level/gnomeftw.wav", client, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.5);
		CreateTimer(2.5, killSound);
		CreateTimer(5.0, SecretSpamDelay, client);
		blockSecretSpam[client] = true;
	}
}

public Action:SecretSpamDelay(Handle:timer, any:client)
{
	blockSecretSpam[client] = false;
}

public Action:killParticle(Handle:timer, any:entity)
{
	if (entity > 0 && IsValidEntity(entity) && IsValidEdict(entity))
	{
		AcceptEntityInput(entity, "Kill");
	}
}

public Action:killSound(Handle:timer)
{
	for (new i = 1; i <= MaxClients; i++)
	if (IsClientInGame(i) && !IsFakeClient(i))
	StopSound(i, SNDCHAN_AUTO, "/level/gnomeftw.wav");
}

/*
stock bool:IsStartOrEndMap()
{
    new iCount;
    new i = -1;
    while((i = FindEntityByClassname(i, "info_landmark")) != -1) {
        iCount++;
    }
    
    return (iCount == 1);
}

stock bool:IsFinalMap()
{
    return (FindEntityByClassname(-1, "info_changelevel") == -1
            && FindEntityByClassname(-1, "trigger_changelevel") == -1);
}

ResetScores()
{
	if (IsStartOrEndMap() && !IsFinalMap() && !GameRules_GetProp("m_bInSecondHalfOfRound"))
	{
		SDKCall(fSetCampaignScores, 0, 0);
		SDKCall(fSetCampaignScores, 1, 0);
	}
}
*/