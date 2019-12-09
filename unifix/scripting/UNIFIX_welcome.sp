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
	name = "UNIFIX welcome",
	author = "Mis",
	description = "Gives a welcome to the server.",
	version = "1.0",
	url = "https://github.com/misdocumeno"
};

public void OnClientPutInServer(int client)
{
	CreateTimer(15.0, WelcomePlayer, GetClientSerial(client));
}
 
public Action WelcomePlayer(Handle timer, any serial)
{
	int client = GetClientFromSerial(serial);
 
	if (client == 0)
	{
		return Plugin_Stop;
	}

	CPrintToChat(client, "Welcome to {blue}UNIFIX{default}!"
		..."\nFeel free to use our {blue}VPN {default}service"
		..."\n{default}Use {blue}!vpn {default} to see those available for this server"
		..."\n{default}Join us on discord: {olive}https://discord.me/unifixservers");

	return Plugin_Handled;
}