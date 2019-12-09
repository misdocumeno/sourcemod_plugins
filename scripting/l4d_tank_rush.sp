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

#pragma semicolon 1

#include <sourcemod>
#include <left4downtown>
#include <colors>
#include <sdktools>

const TANK_ZOMBIE_CLASS = 8;

new bool:bSecondRound = false;
new bool:bTankAlive = false;
new bool:bHooked = false;

new iDistance;

int door_index, door_index2, door_ref, door_ref2;

new Handle:cvar_noTankRush;

public Plugin:myinfo = {
	name = "L4D2 No Tank Rush",
	author = "Jahze, vintik [Mis edit]",
	version = "1.1",
	description = "Stops distance points accumulating and locks the saferoom door whilst the tank is alive",
	url = "https://github.com/misdocumeno"
}

public OnPluginStart() {
	cvar_noTankRush = CreateConVar("l4d_no_tank_rush", "1", "Prevents survivor team from accumulating points whilst the tank is alive", FCVAR_PLUGIN);
	HookConVarChange(cvar_noTankRush, NoTankRushChange);
	if (GetConVarBool(cvar_noTankRush)) {
		PluginEnable();
	}
}

public OnPluginEnd() {
	bHooked = false;
	PluginDisable();
}

stock bool:IsFinalMap()
{
    return (FindEntityByClassname(-1, "info_changelevel") == -1
            && FindEntityByClassname(-1, "trigger_changelevel") == -1);
}

public OnMapStart() {
	bSecondRound = false;
	bTankAlive = false;	
}

PluginEnable() {
	if ( !bHooked ) {
		HookEvent("round_start", RoundStart);
		HookEvent("round_end", RoundEnd);
		HookEvent("tank_spawn", TankSpawn);
		HookEvent("player_death", PlayerDeath);
		
		if ( FindTank() > 0 ) {
			FreezePoints();
		}
		bHooked = true;
	}
}

PluginDisable() {
	if ( bHooked ) {
		UnhookEvent("round_start", RoundStart);
		UnhookEvent("round_end", RoundEnd);
		UnhookEvent("tank_spawn", TankSpawn);
		UnhookEvent("player_death", PlayerDeath);
		
		bHooked = false;
	}
	UnFreezePoints();
}

public NoTankRushChange( Handle:cvar, const String:oldValue[], const String:newValue[] ) {
	if ( StringToInt(newValue) == 0 ) {
		PluginDisable();
	}
	else {
		PluginEnable();
	}
}

public Action:RoundStart( Handle:event, const String:name[], bool:dontBroadcast ) {
	if ( bSecondRound ) {
		UnFreezePoints();
	}
	
	door_index = FindEntityByClassname(-1, "prop_door_rotating_checkpoint");
	door_ref = EntIndexToEntRef(door_index);
	
	door_index2 = FindEntityByClassname(door_index, "prop_door_rotating_checkpoint");
	door_ref2 = EntIndexToEntRef(door_index2);
}

public Action:RoundEnd( Handle:event, const String:name[], bool:dontBroadcast ) {
	bSecondRound = true;
}

public Action:TankSpawn( Handle:event, const String:name[], bool:dontBroadcast ) {
	FreezePoints(true);
}

public Action:PlayerDeath( Handle:event, const String:name[], bool:dontBroadcast ) {
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if ( IsTank(client) ) {
		CreateTimer(0.1, CheckForTanksDelay, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public OnClientDisconnect( client ) {
	if ( IsTank(client) ) {
		CreateTimer(0.1, CheckForTanksDelay, TIMER_FLAG_NO_MAPCHANGE);
	}
}

public Action:CheckForTanksDelay( Handle:timer ) {
	if ( FindTank() == -1 ) {
		UnFreezePoints(true);
	}
}

FreezePoints( bool:show_message = false ) {
	
	if (!IsFinalMap())
	{
		if ( !bTankAlive )
		{
			iDistance = L4D_GetVersusMaxCompletionScore();
			if ( show_message ) PrintToServer("[!] Tank has spawned!");
			L4D_SetVersusMaxCompletionScore(0);
			bTankAlive = true;
		
			PrintToServer("[!] Locking saferoom door");
			
			CPrintToChatAll("{red}[{default}!{red}] {olive}Tank {default}has spawned!"
				..."\n{red}[{default}!{red}] {olive}Freezing {default}distance points!"
				..."\n{red}[{default}!{red}] {olive}Water Slowdown {default}reduced");
		
			door_index = EntRefToEntIndex(door_ref);
			DispatchKeyValue(door_index, "spawnflags", "32768");
			door_ref = EntRefToEntIndex(door_index);
		
			door_index2 = EntRefToEntIndex(door_ref2);
			DispatchKeyValue(door_index2, "spawnflags", "32768");
			door_ref2 = EntIndexToEntRef(door_index2);
		}
	}
	else
	{
		if ( !bTankAlive )
		{
			CPrintToChatAll("{red}[{default}!{red}] {olive}Tank {default}has spawned!"
				..."\n{red}[{default}!{red}] {olive}Water Slowdown {default}reduced");
		}
	}
}

UnFreezePoints( bool:show_message = false ) {
	if (!IsFinalMap())
	{
		if ( bTankAlive ) {
			if ( show_message ) PrintToServer("[!]Tank is dead!");
			L4D_SetVersusMaxCompletionScore(iDistance);
			bTankAlive = false;
		
			PrintToServer("[!] Unlocking saferoom door");
			
			CPrintToChatAll("[{green}!{default}] {blue}Tank {default}is dead "
				..."\n{default}[{green}!{default}] {blue}Unfreezing {default}distance points!");
		
			door_index = EntRefToEntIndex(door_ref);
			DispatchKeyValue(door_index, "spawnflags", "8192");
			door_ref = EntRefToEntIndex(door_index);
			
			door_index2 = EntRefToEntIndex(door_ref2);
			DispatchKeyValue(door_index2, "spawnflags", "8192");
			door_ref2 = EntIndexToEntRef(door_index2);	
		}
	}
	else
	{
		if ( bTankAlive )
		{
			CPrintToChatAll("[{green}!{default}] {blue}Tank {default}is dead");
		}
	}
}

FindTank() {
	for ( new i = 1; i <= MaxClients; i++ ) {
		if ( IsTank(i) && IsPlayerAlive(i) ) {
			return i;
		}
	}
	
	return -1;
}

bool:IsTank( client ) {
	if ( client <= 0
	|| !IsClientInGame(client)
	|| GetClientTeam(client) != 3 ) {
		return false;
	}
	
	new playerClass = GetEntProp(client, Prop_Send, "m_zombieClass");
	
	if ( playerClass == TANK_ZOMBIE_CLASS ) {
		return true;
	}
	
	return false;
}