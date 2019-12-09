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


char DeadCenter[][] = {"c1m1_hotel", "c1m2_streets", "c1m3_mall", "c1m4_atrium"};
int DeadCenterSize = 4;

char DarkCarnival[][] = {"c2m1_highway", "c2m2_fairgrounds", "c2m3_coaster", "c2m4_barns", "c2m5_concert"};
int DarkCarnivalSize = 5;

char SwampFever[][] = {"c3m1_plankcountry", "c3m2_swamp", "c3m3_shantytown", "c3m4_plantation"};
int SwampFeverSize = 4;

char HardRain[][] = {"c4m1_milltown_a", "c4m2_sugarmill_a", "c4m3_sugarmill_b", "c4m4_milltown_b", "c4m5_milltown_escape"};
int HardRainSize = 5;

char TheParish[][] = {"c5m1_waterfront", "c5m2_park", "c5m3_cemetery", "c5m4_quarter", "c5m5_bridge"};
int TheParishSize = 5;

char ThePasing[][] = {"c6m1_riverbank", "c6m2_bedlam", "c6m3_port"};
int ThePasingSize = 3;

char TheSacrifice[][] = {"c7m1_docks", "c7m2_barge", "c7m3_port"};
int TheSacrificeSize = 3;

char NoMercy[][] = {"c8m1_apartment", "c8m2_subway", "c8m3_sewers", "c8m4_interior", "c8m5_rooftop"};
int NoMercySize = 5;

char CrashCourse[][] = {"c9m1_alleys", "c9m2_lots"};
int CrashCourseSize = 2;

char DeathToll[][] = {"c10m1_caves", "c10m2_drainage", "c10m3_ranchhouse", "c10m4_mainstreet", "c10m5_houseboat"};
int DeathTollSize = 5;

char DeadAir[][] = {"c11m1_greenhouse", "c11m2_offices", "c11m3_garage", "c11m4_terminal", "c11m5_runway"};
int DeadAirSize = 5;

char BloodHarvest[][] = {"c12m1_hilltop", "c12m2_traintunnel", "c12m3_bridge", "c12m4_barn", "c12m5_cornfield"};
int BloodHarvestSize = 5;

char ColdStream[][] = {"c13m1_alpinecreek", "c13m2_southpinestream", "c13m3_memorialbridge", "c13m4_cutthroatcreek"};
int ColdStreamSize = 4;


public Plugin myinfo = {
	name = "First map command",
	author = "Mis",
	description = "This plugin adds the !firstmap command to load the first map of the current campaign",
	version = "1.0",
	url = "https://github.com/misdocumeno"
}

public void OnPluginStart()
{
	RegAdminCmd("sm_firstmap", ChangeMapTimer, ADMFLAG_CHEATS, "Switch to the first map of the current campaign.");
}

public Action ChangeMapTimer(int client, int args)
{
	CPrintToChatAll("{blue}[{default}Confogl{blue}] {default}Restarting map!");
	
	CreateTimer(5.0, FirstMapCMD);
}

public Action FirstMapCMD(Handle timer)
{
	char CurrentMap[PLATFORM_MAX_PATH];
	GetCurrentMap(CurrentMap, sizeof(CurrentMap));
	
	for ( int i = 0; i < DeadCenterSize; i++ )
    {
        if (StrEqual(CurrentMap, DeadCenter[i]))
        {
            ServerCommand("changelevel %s", DeadCenter[0]);
        }
    }
	for ( int i = 0; i < DarkCarnivalSize; i++ )
    {
        if (StrEqual(CurrentMap, DarkCarnival[i]))
        {
            ServerCommand("changelevel %s", DarkCarnival[0]);
        }
    }
	for ( int i = 0; i < SwampFeverSize; i++ )
    {
        if (StrEqual(CurrentMap, SwampFever[i]))
        {
            ServerCommand("changelevel %s", SwampFever[0]);
        }
    }
	for ( int i = 0; i < HardRainSize; i++ )
    {
        if (StrEqual(CurrentMap, HardRain[i]))
        {
            ServerCommand("changelevel %s", HardRain[0]);
        }
    }
	for ( int i = 0; i < TheParishSize; i++ )
    {
        if (StrEqual(CurrentMap, TheParish[i]))
        {
            ServerCommand("changelevel %s", TheParish[0]);
        }
    }
	for ( int i = 0; i < ThePasingSize; i++ )
    {
        if (StrEqual(CurrentMap, ThePasing[i]))
        {
            ServerCommand("changelevel %s", ThePasing[0]);
        }
    }
	for ( int i = 0; i < TheSacrificeSize; i++ )
    {
        if (StrEqual(CurrentMap, TheSacrifice[i]))
        {
            ServerCommand("changelevel %s", TheSacrifice[0]);
        }
    }
	for ( int i = 0; i < NoMercySize; i++ )
    {
        if (StrEqual(CurrentMap, NoMercy[i]))
        {
            ServerCommand("changelevel %s", NoMercy[0]);
        }
    }
	for ( int i = 0; i < CrashCourseSize; i++ )
    {
        if (StrEqual(CurrentMap, CrashCourse[i]))
        {
            ServerCommand("changelevel %s", CrashCourse[0]);
        }
    }
	for ( int i = 0; i < DeathTollSize; i++ )
    {
        if (StrEqual(CurrentMap, DeathToll[i]))
        {
            ServerCommand("changelevel %s", DeathToll[0]);
        }
    }
	for ( int i = 0; i < DeadAirSize; i++ )
    {
        if (StrEqual(CurrentMap, DeadAir[i]))
        {
            ServerCommand("changelevel %s", DeadAir[0]);
        }
    }
	for ( int i = 0; i < BloodHarvestSize; i++ )
    {
        if (StrEqual(CurrentMap, BloodHarvest[i]))
        {
            ServerCommand("changelevel %s", BloodHarvest[0]);
        }
    }
	for ( int i = 0; i < ColdStreamSize; i++ )
    {
        if (StrEqual(CurrentMap, ColdStream[i]))
        {
            ServerCommand("changelevel %s", ColdStream[0]);
        }
    }
}