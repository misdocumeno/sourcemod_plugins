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
#include <colors>

public Plugin:myinfo =
{
	name = "UNIFIX lobby reminder",
	author = "Mis",
	description = "Prints the command to create game from lobby, then kicks the player.",
	version = "1.0",
	url = "https://github.com/misdocumeno"
};

char g_sIP[32];
int g_iValue[MAXPLAYERS+1];

public void OnConfigsExecuted()
{
    ConVar hUnifixServerIp = FindConVar("unifix_server_ip");
    
    if (hUnifixServerIp)
    {
        hUnifixServerIp.GetString(g_sIP, sizeof g_sIP);
    }
}

void SendTimer(int client)
{    
    CreateTimer(20.0, Timer_PrintMessageThreeTimes,  GetClientUserId(client), TIMER_REPEAT);
    g_iValue[client] = 0;
}

public void OnPluginStart()
{
    for (int i=1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i))
        {
            SendTimer(i);
        }
    }
}

public void OnClientPutInServer(int client)
{
	SendTimer(client);
}

public Action Timer_PrintMessageThreeTimes(Handle timer, int userid)
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
            CPrintToChat(client, "{blue}[{default}!{blue}]{default} You should join this server from the lobby..."
				..."\n{blue}[{default}!{blue}]{default} Use \"{olive}mm_dedicated_force_servers %s{default}\" in console", g_sIP);
        }
        case 1:
        {
            CPrintToChat(client, "{blue}[{default}!{blue}]{default} You'll be {olive}kicked {default}on 20 seconds..."
				..."\n{blue}[{default}!{blue}]{default} Use \"{olive}mm_dedicated_force_servers %s{default}\" in console", g_sIP);
        }
        case 2:
        {
            KickClient(client, "mm_dedicated_force_servers %s", g_sIP);
            g_iValue[client] = 0;
            return Plugin_Stop;
        }
    }
    ++g_iValue[client];
    return Plugin_Continue;
}