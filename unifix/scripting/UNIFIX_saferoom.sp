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
#include <sdktools>
#include <multicolors>

new bool:bSkipWarp;

int g_iValue[MAXPLAYERS+1];

public Plugin:myinfo =
{
	name = "UNIFIX prohibit leaving the safe",
	author = "Mis",
	description = "Prints a !match message every minute, then kicks the player after 5 minutes.",
	version = "1.0",
	url = "https://github.com/misdocumeno"
};

public void OnClientPutInServer(int client)
{
	StartKickTimer(client);
}

void StartKickTimer(int client)
{
	CreateTimer(60.0, Timer_PrintMessageSixTimes,  GetClientUserId(client), TIMER_REPEAT);
	g_iValue[client] = 0;
}

public Action Timer_PrintMessageSixTimes(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);	
	
	if (!client)
	{
		return Plugin_Stop;
	}

	switch (g_iValue[client])
	{
		case 0:
		{
			CPrintToChat(client, "{blue}[{default}!{blue}]{default} Load a config with {olive}!match {default}or you'll be kicked!");
		}
		case 1:
		{
			CPrintToChat(client, "{blue}[{default}!{blue}]{default} Load a config with {olive}!match {default}or you'll be kicked!");
		}
		case 2:
		{
			CPrintToChat(client, "{blue}[{default}!{blue}]{default} Load a config with {olive}!match {default}or you'll be kicked!");
		}
		case 3:
		{
			CPrintToChat(client, "{blue}[{default}!{blue}]{default} Load a config with {olive}!match {default}or you'll be kicked!");
		}
		case 4:
		{
			CPrintToChat(client, "{blue}[{default}!{blue}]{default} Load a config with {olive}!match {default}or you'll be kicked!");
		}
		case 5:
		{
			KickClient(client, "Load a config to play on this server");
			g_iValue[client] = 0;
			return Plugin_Stop;
		}
	}
	++g_iValue[client];
	return Plugin_Continue;
}

public Action:L4D_OnFirstSurvivorLeftSafeArea(client)
{
		if (bSkipWarp)
		{
			return Plugin_Handled;
		}

		ReturnPlayerToSaferoom(client, false);
		
		CPrintToChat(client, "{blue}[{default}!{blue}]{default} Load a config with {olive}!match {default}or you'll be kicked!");
		
		return Plugin_Handled;
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