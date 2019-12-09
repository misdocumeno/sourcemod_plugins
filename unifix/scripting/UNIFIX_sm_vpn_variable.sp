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

#pragma newdecls required

#include <sourcemod>
#include <multicolors>

public Plugin:myinfo =
{
	name = "UNIFIX VPN",
	author = "Mis",
	description = "Shows VPNs avaliable for the server.",
	version = "1.0",
	url = "https://github.com/misdocumeno"
};

ConVar vpn_brasil;
ConVar vpn_chile;
ConVar vpn_peru;

public void OnPluginStart()
{
	vpn_brasil = CreateConVar("unifix_vpn_brasil", "default");
	vpn_chile = CreateConVar("unifix_vpn_chile", "default");
	vpn_peru = CreateConVar("unifix_vpn_peru", "default");
    
	RegConsoleCmd("sm_vpn", command);
    
	AutoExecConfig(true, "vpn_ip");
}

public Action command(int client, int args)
{
	char vpnbrasil[128], vpnchile[128], vpnperu[128];
    
	GetConVarString(vpn_brasil, vpnbrasil, sizeof(vpnbrasil));
	GetConVarString(vpn_chile, vpnchile, sizeof(vpnchile));
	GetConVarString(vpn_peru, vpnperu, sizeof(vpnperu));
    
	CPrintToChat(client, "Available {olive}VPNs {default}for this {blue}server{default}:"
		..."\n{green}• {blue}Brazil  {olive}%s"
		..."\n{green}• {blue}Chile   {olive}%s"
		..."\n{green}• {blue}Peru   {olive}%s", vpnbrasil, vpnchile, vpnperu);
	
	return Plugin_Handled;
}








