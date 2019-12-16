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

new Handle:fSetCampaignScores = INVALID_HANDLE;

public Plugin:myinfo =
{
	name = "Reset scores",
	author = "Mis",
	description = "Scores are set to 0 at each campaign start",
	version = "1.0",
	url = "https://github.com/misdocumeno"
};

public OnMapStart()
{
	ResetScores();
}

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
