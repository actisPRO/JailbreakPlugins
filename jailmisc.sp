#include <sourcemod>
#include <cstrike>
#include <clients>
#include <console>
#include <sdktools>
#include <csgo_colors>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo = {
	name        = "JailBreak Misc",
	author      = "Actis",
	description = "",
	version     = "1.0.0",
	url         = "CS-JB.RU"
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_kill", KillYourself);
	RegConsoleCmd("sm_t", SwitchSide);
	RegConsoleCmd("sm_steamid", GetSteamID);
	RegConsoleCmd("sm_site", ShowSite);
	RegConsoleCmd("sm_rules", ShowRules);
	RegAdminCmd("sm_z", ASay, ADMFLAG_GENERIC, "");
}

public Action ShowSite(int client, int args)
{
	CGOPrintToChatAll("Наш сайт: {GREEN}cs-jb.ru{DEFAULT}");
}

public Action ShowRules(int client, int args)
{
	CGOPrintToChatAll("Актуальные правила всегда можно прочитать на сайте: {GREEN}cs-jb.ru/rules{DEFAULT}");
}

public Action ASay(int client, int args)
{
	char message[192];
	GetCmdArgString(message, 192);
	
	char name[35];
	GetClientName(client, name, 35);
	
	CGOPrintToChatAll("%s: {OLIVE}%s", name, message); 
	LogMessage("%s triggered sm_z with text: %s", name, message);
}

public Action GetSteamID(int client, int args)
{
	char steamid[32];
	GetClientAuthId(client, AuthId_Steam2, steamid, 32);
	
	char name[35];
	GetClientName(client, name, 35);
	
	CGOPrintToChatAll("{GREEN}SteamID игрока %s:{DEFAULT} %s", name, steamid);
}

public Action KillYourself(int client, int args)
{
	ForcePlayerSuicide(client);
	return Plugin_Handled;
}

public Action SwitchSide(int client, int args)
{
	if (GetClientTeam(client) != CS_TEAM_T)
	{
		ChangeClientTeam(client, CS_TEAM_T);		
	}
}