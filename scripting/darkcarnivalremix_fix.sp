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

char DarkCarnivalRemix[][] = {"dkr_m1_motel", "dkr_m2_carnival", "dkr_m3_tunneloflove", "dkr_m4_ferris", "dkr_m5_stadium"};
int DarkCarnivalRemixSize = 5;

public Plugin myinfo = {
	name = "Dark Carnival Remix Fix",
	author = "Mis",
	description = "A messy way to unload l4d2_boss_percents on Dark Carnival Remix",
	version = "1.0",
	url = "https://github.com/misdocumeno"
}

public void OnMapStart()
{
	char CurrentMap[PLATFORM_MAX_PATH];
	GetCurrentMap(CurrentMap, sizeof(CurrentMap));
	
	for (int i = 0; i < DarkCarnivalRemixSize; i++)
    {
        if (StrEqual(CurrentMap, DarkCarnivalRemix[i]))
        {
            CreateTimer (3.0, OnDarkCarnivalRemixMap);
        }
    }
}

public Action OnDarkCarnivalRemixMap(Handle timer)
{
	// Add other custom paths here
	
	ServerCommand("sm plugins unload optional/nextmod/l4d2_boss_percents.smx");
	ServerCommand("sm plugins unload optional/zonemod/l4d2_boss_percents.smx");
	ServerCommand("sm plugins unload optional/skeetmod/l4d2_boss_percents.smx");
	ServerCommand("sm plugins unload optional/savagemod/l4d2_boss_percents.smx");
}