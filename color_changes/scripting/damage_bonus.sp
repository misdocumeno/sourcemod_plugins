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
*/
#include <sourcemod>
#include <sdkhooks>
#include <sdktools>
#include <left4downtown>
#include <l4d2_direct>
#undef REQUIRE_PLUGIN
#include <readyup>
#include <colors>

#define MAX(%0,%1) (((%0) > (%1)) ? (%0) : (%1))

#define TEAM_SURVIVOR   2

public Plugin:myinfo =
{
	name = "Damage Scoring",
	author = "CanadaRox, Stabby",
	description = "Custom damage scoring based on damage and a static bonus.  (It sounds as bad as vanilla but its not!!)",
	version = "0.99999",
	url = "https://github.com/CanadaRox/sourcemod-plugins"
};

new Handle: hTeamSize;

new Handle: hSurvivalBonusCvar;
new         iSurvivalBonusDefault;

new Handle: hTieBreakBonusCvar;
new         iTieBreakBonusDefault;

new Handle: hStaticBonusCvar;
new Handle: hMaxDamageCvar;
new Handle: hDamageMultiCvar;
new Handle: hMapMulti; 

new         iHealth[MAXPLAYERS + 1];
new         bTookDamage[MAXPLAYERS + 1];
new         iTotalDamage[2];
new bool:   bHasWiped[2];                   // true if they didn't get the bonus...
new bool:   bRoundOver[2];                  // whether the bonus will still change or not
new         iStoreBonus[2];                 // what was the actual bonus?
new         iStoreSurvivors[2];             // how many survived that round?

new bool:   readyUpIsAvailable;

public APLRes:AskPluginLoad2(Handle:myself, bool:late, String:error[], err_max)
{
	CreateNative("DamageBonus_GetCurrentBonus", Native_GetCurrentBonus);
	CreateNative("DamageBonus_GetRoundBonus", Native_GetRoundBonus);
	CreateNative("DamageBonus_GetRoundDamage", Native_GetRoundDamage);
	RegPluginLibrary("l4d2_damagebonus");

	MarkNativeAsOptional("IsInReady");
	return APLRes_Success;
}

public OnPluginStart()
{
	// Score Change Triggers
	HookEvent("door_close", DoorClose_Event);
	HookEvent("player_death", PlayerDeath_Event);
	HookEvent("finale_vehicle_leaving", FinaleVehicleLeaving_Event, EventHookMode_PostNoCopy);
	HookEvent("player_ledge_grab", PlayerLedgeGrab_Event);

	HookEvent("round_end", RoundEnd_Event);

	// Save default Cvar value
	hSurvivalBonusCvar = FindConVar("vs_survival_bonus");
	iSurvivalBonusDefault = GetConVarInt(hSurvivalBonusCvar);

	hTieBreakBonusCvar = FindConVar("vs_tiebreak_bonus");
	iTieBreakBonusDefault = GetConVarInt(hTieBreakBonusCvar);

	hTeamSize = FindConVar("survivor_limit");

	// Configuration Cvars
	hStaticBonusCvar = CreateConVar("sm_static_bonus", "25.0", "Extra static bonus that is awarded per survivor for completing the map", FCVAR_PLUGIN, true, 0.0);
	hMaxDamageCvar = CreateConVar("sm_max_damage", "800.0", "Max damage used for calculation (controls x in [x - damage])", FCVAR_PLUGIN);
	hDamageMultiCvar = CreateConVar("sm_damage_multi", "1.0", "Multiplier to apply to damage before subtracting it from the max damage", FCVAR_PLUGIN, true, 0.0);
	hMapMulti = CreateConVar("sm_damage_mapmulti", "-1", "Disabled if negative, else sm_max_damage will be ignored and max bonus will be replaced by [map distance]*[this factor]", FCVAR_PLUGIN);
	
	// Chat cleaning
	AddCommandListener(Command_Say, "say");
	AddCommandListener(Command_Say, "say_team");

	RegConsoleCmd("sm_bonus", Damage_Cmd, "Prints the damage taken by both teams");
	RegConsoleCmd("sm_damage", Damage_Cmd, "Prints the damage taken by both teams");
	RegConsoleCmd("sm_health", Damage_Cmd, "Prints the damage taken by both teams (Legacy option since I'll get yelled at without it!)");
}

public OnPluginEnd()
{
	SetConVarInt(hSurvivalBonusCvar, iSurvivalBonusDefault);
	SetConVarInt(hTieBreakBonusCvar, iTieBreakBonusDefault);
}

public OnAllPluginsLoaded()
{
	readyUpIsAvailable = LibraryExists("readyup");
}

public OnLibraryRemoved(const String:name[])
{
	if (StrEqual(name, "readyup")) readyUpIsAvailable = false;
}

public OnLibraryAdded(const String:name[])
{
	if (StrEqual(name, "readyup")) readyUpIsAvailable = true;
}

public Native_GetCurrentBonus(Handle:plugin, numParams)
{
	return CalculateSurvivalBonus() * GetAliveSurvivors();
}

public Native_GetRoundBonus(Handle:plugin, numParams)
{
	return iStoreBonus[GetNativeCell(1)];
}

public Native_GetRoundDamage(Handle:plugin, numParams)
{
	return iTotalDamage[GetNativeCell(1)];
}

public OnMapStart()
{
	for (new i = 0; i < 2; i++)
	{
		iTotalDamage[i] = 0;
		iStoreBonus[i] = 0;
		iStoreSurvivors[i] = 0;
		bRoundOver[i] = false;
		bHasWiped[i] = false;
	}
}

public OnClientPutInServer(client)
{
	SDKHook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	SDKHook(client, SDKHook_OnTakeDamagePost, OnTakeDamagePost);
}

public OnClientDisconnect(client)
{
	SDKUnhook(client, SDKHook_OnTakeDamage, OnTakeDamage);
	SDKUnhook(client, SDKHook_OnTakeDamagePost, OnTakeDamagePost);
}

public Action:Damage_Cmd(client, args)
{
	DisplayBonus(client);
	return Plugin_Handled;
}

public RoundEnd_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	// set whether the round was a wipe or not
	if (!GetUprightSurvivors()) {
		bHasWiped[GameRules_GetProp("m_bInSecondHalfOfRound")] = true;
	}

	// when round is over, 
	bRoundOver[GameRules_GetProp("m_bInSecondHalfOfRound")] = true;

	new reason = GetEventInt(event, "reason");
	if (reason == 5)
	{
		DisplayBonus();
		if (readyUpIsAvailable && bRoundOver[0] && !GameRules_GetProp("m_bInSecondHalfOfRound"))
		{
			decl String:readyMsgBuff[65];
			if (bHasWiped[0])
			{
				FormatEx(readyMsgBuff, sizeof(readyMsgBuff), "Round 1: Wipe (%d damage)", iTotalDamage[0]);
			}
			else
			{
				FormatEx(readyMsgBuff, sizeof(readyMsgBuff), "Round 1: %d (%d damage)", iStoreBonus[0], iTotalDamage[0]);
			}
		}
	}
}

public DoorClose_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	if (GetEventBool(event, "checkpoint"))
	{
		SetConVarInt(hSurvivalBonusCvar, CalculateSurvivalBonus());
		StoreBonus();
	}
}

public PlayerDeath_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));

	if (client && IsSurvivor(client))
	{
		SetConVarInt(hSurvivalBonusCvar, CalculateSurvivalBonus());
		StoreBonus();
	}
}

public FinaleVehicleLeaving_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && IsSurvivor(i) && IsPlayerIncap(i))
		{
			ForcePlayerSuicide(i);
		}
	}

	SetConVarInt(hSurvivalBonusCvar, CalculateSurvivalBonus());
	StoreBonus();
}

public OnTakeDamage(victim, attacker, inflictor, Float:damage, damagetype)
{
	iHealth[victim] = (!IsSurvivor(victim) || IsPlayerIncap(victim)) ? 0 : (GetSurvivorPermanentHealth(victim) + GetSurvivorTempHealth(victim));
	bTookDamage[victim] = true;
}

public PlayerLedgeGrab_Event(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	new health = L4D2Direct_GetPreIncapHealth(client);
	new temphealth = L4D2Direct_GetPreIncapHealthBuffer(client);

	iTotalDamage[GameRules_GetProp("m_bInSecondHalfOfRound")] += health + temphealth;
}

public Action:L4D2_OnRevived(client)
{
	new health = GetSurvivorPermanentHealth(client);
	new temphealth = GetSurvivorTempHealth(client);

	iTotalDamage[GameRules_GetProp("m_bInSecondHalfOfRound")] -= (health + temphealth);
}

public OnTakeDamagePost(victim, attacker, inflictor, Float:damage, damagetype)
{
	if (iHealth[victim])
	{
		if (!IsPlayerAlive(victim) || (IsPlayerIncap(victim) && !IsPlayerHanging(victim)))
		{
			iTotalDamage[GameRules_GetProp("m_bInSecondHalfOfRound")] += iHealth[victim];
		}
		else if (!IsPlayerHanging(victim))
		{
			iTotalDamage[GameRules_GetProp("m_bInSecondHalfOfRound")] += iHealth[victim] - (GetSurvivorPermanentHealth(victim) + GetSurvivorTempHealth(victim));
		}
		iHealth[victim] = (!IsSurvivor(victim) || IsPlayerIncap(victim)) ? 0 : (GetSurvivorPermanentHealth(victim) + GetSurvivorTempHealth(victim));
	}
}

public Action:Command_Say(client, const String:command[], args)
{
	if (IsChatTrigger())
	{
		decl String:sMessage[MAX_NAME_LENGTH];
		GetCmdArg(1, sMessage, sizeof(sMessage));

		if (StrEqual(sMessage, "!damage")) return Plugin_Handled;
		else if (StrEqual (sMessage, "!sm_damage")) return Plugin_Handled;
		else if (StrEqual (sMessage, "!health")) return Plugin_Handled;
		else if (StrEqual (sMessage, "!sm_health")) return Plugin_Handled;
	}

	return Plugin_Continue;
}

stock GetDamage(round=-1)
{
	return (round == -1) ? iTotalDamage[GameRules_GetProp("m_bInSecondHalfOfRound")] : iTotalDamage[round];
}

stock StoreBonus()
{
	// store bonus for display
	new round = GameRules_GetProp("m_bInSecondHalfOfRound");
	new aliveSurvs = GetAliveSurvivors();

	iStoreBonus[round] = GetConVarInt(hSurvivalBonusCvar) * aliveSurvs;
	iStoreSurvivors[round] = GetAliveSurvivors();
}

stock DisplayBonus(client=-1)
{
	decl String:msgPartHdr[48];
	decl String:msgPartDmg[48];

	for (new round = 0; round <= GameRules_GetProp("m_bInSecondHalfOfRound"); round++)
	{
		if (bRoundOver[round])
		{
			FormatEx(msgPartHdr, sizeof(msgPartHdr), "Round {olive}%i{default}:", round+1);
		}
		else
		{
			FormatEx(msgPartHdr, sizeof(msgPartHdr), "Current:");
		}

		if (bHasWiped[round])
		{
			FormatEx(msgPartDmg, sizeof(msgPartDmg), "{green}wipe");
		}
		else
		{
			FormatEx(msgPartDmg, sizeof(msgPartDmg), "{olive}%d {default}(dmg {green}%d{default})",
					(bRoundOver[round]) ? iStoreBonus[round] : CalculateSurvivalBonus() * GetAliveSurvivors(),
					iTotalDamage[round]);
		}

		if (client == -1)
		{
			PrintToConsoleAll("Map Distance: %d", L4D_GetVersusMaxCompletionScore());
			CPrintToChatAll("{blue}[{default}Bonus{blue}]{default} %s{default} %s", msgPartHdr, msgPartDmg);
		}
		else if (client)
		{
			PrintToConsole(client, "Map Distance: %d", L4D_GetVersusMaxCompletionScore());
			CPrintToChat(client, "{blue}[{default}Bonus{blue}]{default} %s{default} %s", msgPartHdr, msgPartDmg);
		}
		else
		{
			PrintToServer("Map Distance: %d", L4D_GetVersusMaxCompletionScore());
			PrintToServer("%s: %s", msgPartHdr, msgPartDmg);
		}
	}
}

stock bool:IsPlayerIncap(client) return bool:GetEntProp(client, Prop_Send, "m_isIncapacitated");
stock bool:IsPlayerHanging(client) return bool:GetEntProp(client, Prop_Send, "m_isHangingFromLedge");
stock bool:IsPlayerLedgedAtAll(client) return bool:(GetEntProp(client, Prop_Send, "m_isHangingFromLedge") | GetEntProp(client, Prop_Send, "m_isFallingFromLedge"));

stock GetSurvivorTempHealth(client)
{
	new temphp = RoundToCeil(GetEntPropFloat(client, Prop_Send, "m_healthBuffer") - ((GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime")) * GetConVarFloat(FindConVar("pain_pills_decay_rate")))) - 1;
	return (temphp > 0 ? temphp : 0);
}

stock GetSurvivorPermanentHealth(client) return GetEntProp(client, Prop_Send, "m_iHealth");

stock CalculateSurvivalBonus()
{
	if (GetConVarFloat(hMapMulti) < 0)
	{
		return RoundToFloor(( MAX(GetConVarFloat(hMaxDamageCvar) - GetDamage() * GetConVarFloat(hDamageMultiCvar), 0.0) ) / 4 + GetConVarFloat(hStaticBonusCvar));
	}
	else
	{
		return RoundToFloor((MAX(GetConVarFloat(hMapMulti) * L4D_GetVersusMaxCompletionScore() - GetDamage() * GetConVarFloat(hDamageMultiCvar), 0.0)) / 4 + GetConVarFloat(hStaticBonusCvar));
	}
}

stock GetAliveSurvivors()
{
	new iAliveCount;
	new iSurvivorCount;
	new maxSurvs = (hTeamSize != INVALID_HANDLE) ? GetConVarInt(hTeamSize) : 4;
	for (new i = 1; i <= MaxClients && iSurvivorCount < maxSurvs; i++)
	{
		if (IsSurvivor(i))
		{
			iSurvivorCount++;
			if (IsPlayerAlive(i)) iAliveCount++;
		}
	}
	return iAliveCount;
}

stock GetUprightSurvivors()
{
	new iAliveCount;
	new iSurvivorCount;
	new maxSurvs = (hTeamSize != INVALID_HANDLE) ? GetConVarInt(hTeamSize) : 4;
	for (new i = 1; i <= MaxClients && iSurvivorCount < maxSurvs; i++)
	{
		if (IsSurvivor(i))
		{
			iSurvivorCount++;
			if (IsPlayerAlive(i) && !IsPlayerIncap(i) && !IsPlayerLedgedAtAll(i))
			{
				iAliveCount++;
			}
		}
	}
	return iAliveCount;
}

stock bool:IsSurvivor(client)
{
	return IsClientAndInGame(client) && GetClientTeam(client) == TEAM_SURVIVOR;
}

stock bool:IsClientAndInGame(index) return (index > 0 && index <= MaxClients && IsClientInGame(index));