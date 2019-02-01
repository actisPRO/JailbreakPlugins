#include <sourcemod>
#include <clients>
#include <admin>
#include <cstrike>
#include <sdktools>
#include <csgo_colors>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo = {
	name        = "VIP",
	author      = "Actis",
	description = "",
	version     = "1.0.0",
	url         = "CS-JB.RU"
};

bool g_VipUsed[MAXPLAYERS+1];
bool g_VipActive[MAXPLAYERS+1];

int g_MaxHealth[MAXPLAYERS+1];
int g_MaxHealthCanBeRegenerated[MAXPLAYERS+1];	
int m_flLaggedMovementValue;
int g_Iteration[MAXPLAYERS+1];

float g_dSpeed;

Handle g_VipReactivate[MAXPLAYERS+1];

//-гравитация, +скорость, +100 хп, реген 5 хп/с, снять бунт, маскировка под кт
//+скорость, -гравитация


public void OnPluginStart()
{
	m_flLaggedMovementValue = FindSendPropOffs("CCSPlayer", "m_flLaggedMovementValue");
	
	/*RegAdminCmd("vip_gravity", CommandVIPGravity, ADMFLAG_CUSTOM5, "Decreases VIP gravity");
	RegAdminCmd("vip_speed", CommandVIPSpeed, ADMFLAG_CUSTOM5, "Increases VIP speed");
	RegAdminCmd("vip_heal", CommandVIPHeal, ADMFLAG_CUSTOM5, "Adds 100 HP to VIP");
	RegAdminCmd("vip_regen", CommandVIPRegenerate, ADMFLAG_CUSTOM5, "Regenerates VIP HP");
	RegAdminCmd("vip_unrebel", CommandVIPUnrebel, ADMFLAG_CUSTOM5, "Stop beeing rebel");
	RegAdminCmd("vip_fakect", CommandVIPFakect, ADMFLAG_CUSTOM5, "Set's CT VIP skin to T");*/
	RegAdminCmd("sm_vip", CommandVIP, ADMFLAG_CUSTOM5, "Opens admin menu");
	
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("round_end", Event_RoundEnd);
	
	for (int i = 0; i <= MAXPLAYERS; ++i)
	{
		g_VipUsed[i] = false;
	}	
	
	CreateTimer(120.0, Rehash, 0, TIMER_REPEAT);
}


public Action Rehash(Handle timer, int uselessInfo)
{
	ServerCommand("sm_rehash");
	PrintToServer("VIP plugin has reloaded admin list");
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	g_VipUsed[client] = false;
	
	if (!IsVip(client) && (GetClientTeam(client) == CS_TEAM_T || GetClientTeam(client) == CS_TEAM_CT))
	{
		return;
	}	
	
	g_dSpeed = GetEntDataFloat(client, m_flLaggedMovementValue);
	
	CreateTimer(0.6, SetVipFeatures, client);
	g_VipReactivate[client] = CreateTimer(1.0, SetVipFeaturesRepeating, client, TIMER_REPEAT);
}

public Action Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if (g_VipReactivate[client] != INVALID_HANDLE)
	{
		KillTimer(g_VipReactivate[client]);
	}
}

public Action Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	for (int i = 1; i <= MAXPLAYERS; ++i)
	{
		if (g_VipReactivate[i] != INVALID_HANDLE)
		{
			KillTimer(g_VipReactivate[i]);
		}
	}
}

public Action CommandVIP(int client, int args)
{
	if (IsPlayerAlive(client))
	{
		if ((GetClientTeam(client) == CS_TEAM_T || GetClientTeam(client) == CS_TEAM_CT) && !g_VipUsed[client])
		{
			Menu menu = new Menu(VipMenuHandler, MENU_ACTIONS_ALL);
			menu.SetTitle("VIP-меню");
			
			menu.AddItem("gravity", "Гравитация (10 секунд)");
			menu.AddItem("speed", "Скорость (10 секунд)");
			menu.AddItem("heal", "Лечение (+100 HP)");
			menu.AddItem("regen", "Регенерация (15 HP/с)");
			menu.AddItem("armor", "Броня (+100 брони)");
			
			if (GetClientTeam(client) == CS_TEAM_T)
			{
				menu.AddItem("unrebel", "Снять окраску бунтаря");
				menu.AddItem("fakect", "Маскировка (10 секунд)");			
			}
			
			menu.Display(client, MENU_TIME_FOREVER);
		}
		else if (g_VipUsed[client])
		{
			CGOPrintToChat(client, "{GREEN}[VIP]{DEFAULT} VIP-меню можно использовать только один раз за раунд!");
		}
	}
	else
	{
		CGOPrintToChat(client, "{GREEN}[VIP]{DEFAULT} VIP-меню доступно только живым!");
	}
	
	return Plugin_Handled;
}

public int VipMenuHandler(Menu menu, MenuAction action, int param1, int param2) 
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char info[32];
			menu.GetItem(param2, info, sizeof(info));
			
			if (StrEqual(info, "gravity"))
			{
				CommandVIPGravity(param1);
			}
			else if (StrEqual(info, "speed"))
			{
				CommandVIPSpeed(param1);
			}
			else if (StrEqual(info, "heal"))
			{
				CommandVIPHeal(param1);
			}
			else if (StrEqual(info, "regen"))
			{
				CommandVIPRegenerate(param1);
			}
			else if (StrEqual(info, "armor"))
			{
				CommandVIPArmor(param1);
			}
			else if (StrEqual(info, "unrebel"))
			{
				CommandVIPUnrebel(param1);
			}
			else if (StrEqual(info, "fakect"))
			{
				CommandVIPFakect(param1);
			}
			
			g_VipActive[param1] = true;
		}		
	}
}

public void CommandVIPGravity(int client)
{	
	SetEntityGravity(client, 0.5);	
	g_VipUsed[client] = true;	
	CreateTimer(10.0, DisableVipGravity, client);	
}

public void CommandVIPSpeed(int client)
{	
	SetEntDataFloat(client, m_flLaggedMovementValue, g_dSpeed * 2, true);
	g_VipUsed[client] = true;
	CreateTimer(10.0, DisableVipSpeed, client);
	
	g_VipUsed[client] = true;	
}

public void CommandVIPHeal(int client)
{	
	if (g_MaxHealth[client] - GetClientHealth(client) < 100)
	{
		SetEntityHealth(client, g_MaxHealth[client]);
	}
	else if (g_MaxHealth[client] - GetClientHealth(client) > 100)
	{
		SetEntityHealth(client, GetClientHealth(client) + 100);
	}
	
	g_VipUsed[client] = true;	
}

public void CommandVIPRegenerate(int client)
{	
	if (GetClientHealth(client) + 150 >= g_MaxHealth[client])
	{
		g_MaxHealthCanBeRegenerated[client] = g_MaxHealth[client];
	}
	else
	{
		g_MaxHealthCanBeRegenerated[client] = GetClientHealth(client) + 150;
	}
	g_Iteration[client] = 0;
	
	CreateTimer(1.0, RegenerateHP, client, TIMER_REPEAT);
	
	g_VipUsed[client] = true;	
}

public void CommandVIPArmor(int client)
{
	SetEntProp(client, Prop_Data, "m_ArmorValue", 100, 1);
	
	g_VipUsed[client] = true;
}

public void CommandVIPUnrebel(int client)
{	
	SetEntityRenderColor(client, 255, 255, 255, 255);
	
	g_VipUsed[client] = true;	
}

public void CommandVIPFakect(int client)
{	
	SetEntityModel(client, "models/player/custom_player/kuristaja/nanosuit/nanosuitv3.mdl");
	SetEntPropString(client, Prop_Send, "m_szArmsModel", "models/player/custom_player/kuristaja/nanosuit/nanosuit_arms.mdl");
	SetEntityHealth(client, 50);
	
	CreateTimer(10.0, DisableFakeCt, client);
	
	g_VipUsed[client] = true;	
}

bool IsVip(int client)
{
	char error[255];
	Database db = SQL_DefConnect(error, sizeof(error));
		    
	if (db == null)
	{
	  	PrintToServer("Could not connect: %s", error);
	}
	else 
	{		
		char steamid[64];
		GetClientAuthId(client, AuthId_Steam2, steamid, 64);
	
		char buffer[255];
		Format(buffer, 255, "SELECT `srv_flags` FROM `sb_admins` WHERE `authid` = '%s';", steamid);
		DBResultSet query = SQL_Query(db, buffer);
		
		if (query == null)
		{
			PrintToServer("SQL Query errored (GetXP(%d))", client);
		}
		else
		{
			while (SQL_FetchRow(query))
			{
				char result[255];
				SQL_FetchString(query, 0, result, 255);
				if (StrContains(result, "s", false) != -1)
				{
					return true;
				}
			}
			
			delete query;
		}
	
		ReplaceString(steamid, 64, "STEAM_1", "STEAM_0", false);
		Format(buffer, 255, "SELECT `srv_flags` FROM `sb_admins` WHERE `authid` = '%s';", steamid);
		query = SQL_Query(db, buffer);
		
		if (query == null)
		{
			PrintToServer("SQL Query errored (GetXP(%d))", client);
		}
		else
		{
			while (SQL_FetchRow(query))
			{
				char result[255];
				SQL_FetchString(query, 0, result, 255);
				if (StrContains(result, "s", false) != -1)
				{
					return true;
				}
				else
				{
					return false;
				}
			}
			
			delete query;
		}

		delete db;
	}
	
	return false;
}

int GetXP(int client)
{
	char error[255];
	Database db = SQL_DefConnect(error, sizeof(error));
		    
	if (db == null)
	{
	  	PrintToServer("Could not connect: %s", error);
	}
	else 
	{		
		char steamid64[64];
		GetClientAuthId(client, AuthId_SteamID64, steamid64, 64);
	
		char buffer[255];
		Format(buffer, 255, "SELECT `xp` FROM `id_accounts` WHERE `steamid64` = '%s'", steamid64);
		DBResultSet query = SQL_Query(db, buffer);
		
		if (query == null)
		{
			PrintToServer("SQL Query errored (GetXP(%d))", client);
		}
		else
		{
			while (SQL_FetchRow(query))
			{
				return SQL_FetchInt(query, 0);
			}
			
			delete query;
		}		
	}
	
	return -1;
}

int CalcRank(int xp)
{
	if (xp < 30)
	{
		return 1;
	}
	else if (xp >= 30 && xp < 90)
	{
		return 2;
	}
	else if (xp >= 90 && xp < 180)
	{
		return 3;
	}
	else if (xp >= 180 && xp < 450)
	{
		return 4;
	}
	else if (xp >= 450 && xp < 600)
	{
		return 5;
	}
	else if (xp >= 600 && xp < 1500)
	{
		return 6;
	}
	else if (xp >= 1500 && xp < 6700)
	{
		return 7;
	}
	else if (xp >= 6700 && xp < 11000)
	{
		return 8;
	}
	else if (xp >= 11000 && xp < 34000)
	{
		return 9;
	}
	else if (xp >= 89000 && xp < 89000)
	{
		return 10;
	}
	else if (xp >= 89000 && xp < 330000)
	{
		return 11;
	}	
	else if (xp >= 330000)
	{
		return 12;
	}
	
	return 1;
}

public Action SetVipFeatures(Handle timer, int client)
{
	if (!g_VipActive[client])
	{
		SetVipFeaturesFunc(client);		
	}
}

public Action SetVipFeaturesRepeating(Handle timer, int client)
{
	if (!g_VipActive[client])
	{
		SetVipFeaturesRepeatingFunc(client);		
	}
}

public void SetVipFeaturesFunc(int client)
{
	g_MaxHealth[client] = 100 + CalcRank(GetXP(client)) * 10;
	SetEntityHealth(client, g_MaxHealth[client]);
	SetEntityGravity(client, 0.85);
	
	SetEntDataFloat(client, m_flLaggedMovementValue, g_dSpeed * 1.05, true);
	
	CS_SetClientClanTag(client, "[VIP]");
	
	if (GetClientTeam(client) == CS_TEAM_T) 
	{
		SetEntityModel(client, "models/player/custom/ekko/ekko.mdl");
		SetEntPropString(client, Prop_Send, "m_szArmsModel", "models/player/custom_player/kuristaja/jailbreak/prisoner3/prisoner3_arms.mdl");
	}
	else
	{
		SetEntityModel(client, "models/player/custom_player/kuristaja/nanosuit/nanosuitv3.mdl");
		SetEntPropString(client, Prop_Send, "m_szArmsModel", "models/player/custom_player/kuristaja/nanosuit/nanosuit_arms.mdl");
	}
}

public void SetVipFeaturesRepeatingFunc(int client)
{
	SetEntityGravity(client, 0.85);	
	SetEntDataFloat(client, m_flLaggedMovementValue, g_dSpeed * 1.05, true);	
	CS_SetClientClanTag(client, "[VIP]");
}

public Action DisableVipGravity(Handle timer, int client)
{
	SetEntityGravity(client, 0.85);
	g_VipActive[client] = false;
}

public Action DisableVipSpeed(Handle timer, int client)
{
	SetEntDataFloat(client, m_flLaggedMovementValue, g_dSpeed * 1.05, true);
	g_VipActive[client] = false;
}

public Action RegenerateHP(Handle timer, int client)
{
	if (g_Iteration[client] == 15)
	{
		g_VipActive[client] = false;
		KillTimer(timer);
		return;
	}
	
	if (GetClientHealth(client) < g_MaxHealthCanBeRegenerated[client])
	{
		SetEntityHealth(client, GetClientHealth(client) + 15);
	}
	else
	{
		SetEntityHealth(client, g_MaxHealthCanBeRegenerated[client]);
	}
	
	g_Iteration[client]++;
}

public Action DisableFakeCt(Handle timer, int client)
{
	SetEntityModel(client, "models/player/custom/ekko/ekko.mdl");
	SetEntPropString(client, Prop_Send, "m_szArmsModel", "models/player/custom_player/kuristaja/jailbreak/prisoner3/prisoner3_arms.mdl");
	g_VipActive[client] = false;
}