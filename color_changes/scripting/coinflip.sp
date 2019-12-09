/*    
		Coinflip
   by purpletreefactory
   Credit for the idea goes to Fig
   This version was made out of convenience
   
   1.0.2: added e-z-p-z commands, removed unnecessary colors.inc, removed generation of config file
 */
 
#include <sourcemod>
#include <sdktools>
#include <colors>

new result_int;
new String:client_name[32]; // Used to store the client_name of the player who calls coinflip
new previous_timeC = 0; // Used for coinflip
new current_timeC = 0; // Used for coinflip
new previous_timeN = 0; // Used for picknumber
new current_timeN = 0; // Used for picknumber
new Handle:delay_time; // Handle for the coinflip_delay cvar
new number_max = 20; // Default maximum bound for picknumber

public Plugin:myinfo =
{
	name = "Coinflip",
	author = "purpletreefactory, epilimic",
	description = "purpletreefactory's version of coinflip",
	version = "1.0.2",
	url = "http://www.sourcemod.net/"
}
 
public OnPluginStart()
{
	delay_time = CreateConVar("coinflip_delay","-1", "Time delay in seconds between allowed coinflips. Set at -1 if no delay at all is desired.");

	RegConsoleCmd("sm_coinflip", Command_Coinflip);
	RegConsoleCmd("sm_cf", Command_Coinflip);
	RegConsoleCmd("sm_flip", Command_Coinflip);
	RegConsoleCmd("sm_roll", Command_Picknumber);
	RegConsoleCmd("sm_picknumber", Command_Picknumber);
}

public Action:Command_Coinflip(client, args)
{
	current_timeC = GetTime();
	
	if((current_timeC - previous_timeC) > GetConVarInt(delay_time)) // Only perform a coinflip if enough time has passed since the last one. This prevents spamming.
	{
		result_int = GetURandomInt() % 2; // Gets a random integer and checks to see whether it's odd or even
		GetClientName(client, client_name, sizeof(client_name)); // Gets the client_name of the person using the command
		
		if(result_int == 0)
			CPrintToChatAll("{blue}[{default}Coinflip{blue}] {olive}%s {default}flipped a coin!\n{blue}[{default}Coinflip{blue}] {default}It's {olive}Heads{default}!", client_name); // Here \x04 is actually yellow
		else
			CPrintToChatAll("{blue}[{default}Coinflip{blue}] {olive}%s {default}flipped a coin!\n{blue}[{default}Coinflip{blue}] {default}It's {olive}Tails{default}!", client_name);
		
		previous_timeC = current_timeC; // Update the previous time
	}
	else
	{
		PrintToConsole(client, "[Coinflip] Whoa there buddy, slow down. Wait at least %d seconds.", GetConVarInt(delay_time));
	}
	
	return Plugin_Handled;
}

public Action:Command_Picknumber(client, args)
{
	current_timeN = GetTime();
	
	if((current_timeN - previous_timeN) > GetConVarInt(delay_time)) // Only perform a numberpick if enough time has passed since the last one.
	{
		GetClientName(client, client_name, sizeof(client_name)); // Gets the client_name of the person using the command
		
		if(GetCmdArgs() == 0)
		{
			result_int = GetURandomInt() % (number_max); // Generates a random number within the default range
			
			CPrintToChatAll("{blue}[{default}Coinflip{blue}] {olive}%s{default} rolled a {blue}%d {default}sided die!\n{blue}[{default}Coinflip{blue}] {default}It's {olive}%d{default}!", client_name, number_max, result_int + 1);
		}
		else
		{
			new String:arg[32];
			new max;
			
			GetCmdArg(1, arg, sizeof(arg)); // Get the command argument
			max = StringToInt(arg);
			
			result_int = GetURandomInt() % (max); // Generates a random number within the specified range
			CPrintToChatAll("{blue}[{default}Coinflip{blue}] {olive}%s{default} rolled a {blue}%d {default}sided die!\n{blue}[{default}Coinflip{blue}] {default}It's {olive}%d{default}!", client_name, max, result_int + 1);
		}
		
		previous_timeN = current_timeN; // Update the previous time
	}
	else
	{
		PrintToConsole(client, "[Coinflip] Whoa there buddy, slow down. Wait at least %d seconds.", GetConVarInt(delay_time));
	}
}