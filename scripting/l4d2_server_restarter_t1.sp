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

new bool:isFirstMapStart = true;
new bool:isSwitchingMaps = true;
new bool:startedTimer = false;
new Handle:switchMapTimer = INVALID_HANDLE;
 
public Plugin myinfo =
{
	name = "L4D2 Server Restarter [T1]",
	author = "Luckylock [Mis edit]",
	description = "Restarts server automatically. Uses the built-in restart of srcds_run",
	version = "2.1",
	url = "https://github.com/LuckyServ/ https://github.com/misdocumeno/"
};

public void OnPluginStart()
{
    new ConVar:cvarHibernateWhenEmpty = FindConVar("sv_hibernate_when_empty");
    SetConVarInt(cvarHibernateWhenEmpty, 0, false, false);
    
    RegAdminCmd("sm_rs", KickClientsAndRestartServer, ADMFLAG_ROOT, "Kicks all clients and restarts server");
}

public void OnPluginEnd()
{
    CrashIfNoHumans(INVALID_HANDLE);
}

public Action KickClientsAndRestartServer(int client, int args)
{
    for (new i = 1; i <= MaxClients; ++i) {
        if (IsHuman(i)) {
            KickClient(i, "go next"); 
        }
    }

    CrashServer();
}

public void OnMapStart()
{
    if(!isFirstMapStart && !startedTimer) {
        CreateTimer(600.0, CrashIfNoHumans, _, TIMER_REPEAT); 
        startedTimer = true;
    }

    if (switchMapTimer != INVALID_HANDLE) {
        KillTimer(switchMapTimer);
    }

    switchMapTimer = CreateTimer(30.0, SwitchedMap);

    isFirstMapStart = false;
}

public void OnMapEnd()
{
    isSwitchingMaps = true;
}

public Action SwitchedMap(Handle timer)
{
    isSwitchingMaps = false;

    switchMapTimer = INVALID_HANDLE;

    return Plugin_Stop;
}

public Action CrashIfNoHumans(Handle timer) 
{
    if (!isSwitchingMaps && !HumanFound()) {
        CrashServer();
    }

    return Plugin_Continue;
}

public bool HumanFound() 
{
    new bool:humanFound = false;
    new i = 1;

    while (!humanFound && i <= MaxClients) {
        humanFound = IsHuman(i);
        ++i;
    }

    return humanFound;
}

public bool IsHuman(client)
{
    return IsClientInGame(client) && !IsFakeClient(client);
}

public void CrashServer()
{
    PrintToServer("L4D2 Server Restarter: Crashing the server...");
    SetCommandFlags("crash", GetCommandFlags("crash")&~FCVAR_CHEAT);
    ServerCommand("crash");
}