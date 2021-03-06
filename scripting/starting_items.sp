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
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#define HEALTH_FIRST_AID_KIT	1
#define HEALTH_DEFIBRILLATOR	2
#define HEALTH_PAIN_PILLS	   4
#define HEALTH_ADRENALINE	   8

#define THROWABLE_PIPE_BOMB	 16
#define THROWABLE_MOLOTOV	   32
#define THROWABLE_VOMITJAR	  64


public Plugin myinfo =
{
	name = "Starting Items",
	author = "CircleSquared [Mis Edit]",
	description = "Gives health items and throwables to survivors at the start of each round",
	version = "1.1",
	url = "https://github.com/misdocumeno"
}

enum Slot
{
    Slot_0, // Primary weapon.
    Slot_1, // Secondary weapon, sidearm. Usually only "weapon_pistol".
    Slot_2, // Grenade.
    Slot_3, // First aid kit.
    Slot_4, // Pain pills.
};

ConVar hCvarItemType;
int iItemFlags;

public void OnPluginStart()
{
	hCvarItemType = CreateConVar("starting_item_flags", "0",
		"Item flags to give on leaving the saferoom (1: Kit, 2: Defib, 4: Pills, 8: Adren, 16: Pipebomb, 32: Molotov, 64: Bile)");
	HookEvent("player_left_start_area", PlayerLeftStartArea);
}

public Action PlayerLeftStartArea(Handle event, const char[] name, bool dontBroadcast)
{
	char strItemName[32];
	iItemFlags = hCvarItemType.IntValue;

	if (iItemFlags) {
		if (iItemFlags & HEALTH_FIRST_AID_KIT) {
			strItemName = "weapon_first_aid_kit";
			giveStartingItem(strItemName);
		}
		else if (iItemFlags & HEALTH_DEFIBRILLATOR) {
			strItemName = "weapon_defibrillator";
			giveStartingItem(strItemName);
		}
		if (iItemFlags & HEALTH_PAIN_PILLS) {
			strItemName = "weapon_pain_pills";
			giveStartingItem(strItemName);
		}
		else if (iItemFlags & HEALTH_ADRENALINE) {
			strItemName = "weapon_adrenaline";
			giveStartingItem(strItemName);
		}
		if (iItemFlags & THROWABLE_PIPE_BOMB) {
			strItemName = "weapon_pipe_bomb";
			giveStartingItem(strItemName);
		}
		else if (iItemFlags & THROWABLE_MOLOTOV) {
			strItemName = "weapon_molotov";
			giveStartingItem(strItemName);
		}
		else if (iItemFlags & THROWABLE_VOMITJAR) {
			strItemName = "weapon_vomitjar";
			giveStartingItem(strItemName);
		}
	}

	return Plugin_Continue;
}

public int GetPlayerWeapon(int client, const char[] name)
{
	int size = GetEntPropArraySize(client, Prop_Send, "m_hMyWeapons");
	for (int i = 0; i < size; i++)
	{
		int weapon = GetEntPropEnt(client, Prop_Send, "m_hMyWeapons", i);
		if (IsValidEntity(weapon))
		{
			char classname[64];
			GetEntityClassname(weapon, classname, sizeof(classname));

			if(StrEqual(classname, name))
			{
				return weapon;
			}
		}
	}
	return -1;	
}

public void giveStartingItem(const char[] strItemName)
{
	int startingItem;
	
	float clientOrigin[3];
	
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && GetClientTeam(i) == 2)
		{
			int slot2_item = GetPlayerWeaponSlot(i, view_as<int>(Slot_2));
			int slot3_item = GetPlayerWeaponSlot(i, view_as<int>(Slot_3));
			int slot4_item = GetPlayerWeaponSlot(i, view_as<int>(Slot_4));
			
			if(slot2_item != -1)
			{
				SDKHooks_DropWeapon(i, slot2_item, NULL_VECTOR, NULL_VECTOR);
				RemoveEntity(slot2_item);
			}
			if(slot3_item != -1)
			{
				SDKHooks_DropWeapon(i, slot3_item, NULL_VECTOR, NULL_VECTOR);
				RemoveEntity(slot3_item);
			}
			if(slot4_item != -1)
			{
				SDKHooks_DropWeapon(i, slot4_item, NULL_VECTOR, NULL_VECTOR);
				RemoveEntity(slot4_item);
			}
			if (GetPlayerWeapon(i, strItemName) == -1)
			{
				startingItem = CreateEntityByName(strItemName);
				GetClientAbsOrigin(i, clientOrigin);
				TeleportEntity(startingItem, clientOrigin, NULL_VECTOR, NULL_VECTOR);
				DispatchSpawn(startingItem);
				EquipPlayerWeapon(i, startingItem);
			}
		}
	}
}