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
	version     = "1.1.0",
	url         = "CS-JB.RU"
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_kill", KillYourself);
	RegConsoleCmd("sm_t", SwitchSide);
	RegConsoleCmd("sm_steamid", GetSteamID);
	RegConsoleCmd("sm_site", ShowSite);
	RegConsoleCmd("sm_rules", ShowRules);
	RegAdminCmd("sm_z", ZSay, ADMFLAG_GENERIC, "");
	
	HookEvent("player_spawn", Event_PlayerSpawn);
}

void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	SetEntityRenderMode(client, RENDER_TRANSCOLOR);
	SetEntityRenderColor(client, 255, 255, 255, 255);
	
	
	char steamid[64];
	GetClientAuthId(client, AuthId_Steam2, steamid, 64);
}

public Action ShowSite(int client, int args)
{
	CGOPrintToChatAll("Наш сайт: {GREEN}cs-jb.ru{DEFAULT}");
	
	char name[35];
	GetClientName(client, name, 35);
	
	LogMessage("%s triggered sm_site", name);
	return Plugin_Handled;
}

public Action ShowRules(int client, int args)
{
	CGOPrintToChatAll("Актуальные правила всегда можно прочитать на сайте: {GREEN}cs-jb.ru/rules{DEFAULT}");
	
	char name[35];
	GetClientName(client, name, 35);
	
	LogMessage("%s triggered sm_rules", name);
	return Plugin_Handled;
}

public Action ZSay(int client, int args)
{
	char message[192];
	GetCmdArgString(message, 192);
	
	char name[35];
	GetClientName(client, name, 35);
	
	CGOPrintToChatAll("%s: {OLIVE}%s", name, message); 
	LogMessage("%s triggered sm_z with text: %s", name, message);
	return Plugin_Handled;
}

public Action GetSteamID(int client, int args)
{
	char steamid[32];
	GetClientAuthId(client, AuthId_Steam2, steamid, 32);
	
	char name[35];
	GetClientName(client, name, 35);
	
	CGOPrintToChatAll("{GREEN}SteamID игрока %s:{DEFAULT} %s", name, steamid);
	
	LogMessage("%s triggered sm_steamid", name);
	return Plugin_Handled;
}

public Action KillYourself(int client, int args)
{
	ForcePlayerSuicide(client);
	
	char name[35];
	GetClientName(client, name, 35);
	
	LogMessage("%s triggered sm_kill", name);
	return Plugin_Handled;
}

public Action SwitchSide(int client, int args)
{
	if (GetClientTeam(client) != CS_TEAM_T)
	{
		ChangeClientTeam(client, CS_TEAM_T);		
	}
	
	char name[35];
	GetClientName(client, name, 35);
	
	LogMessage("%s triggered sm_t", name);
	return Plugin_Handled;
}