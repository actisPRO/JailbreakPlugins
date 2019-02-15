#include <sourcemod>
#include <clients>
#include <admin>
#include <cstrike>
#include <sdktools>
#include <sdkhooks>
#include <csgo_colors>
#include <id>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo = {
	name        = "VIP",
	author      = "Actis",
	description = "",
	version     = "1.1.0",
	url         = "CS-JB.RU"
};

bool g_VipUsed[MAXPLAYERS+1];
bool g_VipActive[MAXPLAYERS+1];

int g_MaxHealth[MAXPLAYERS+1];
int g_MaxHealthCanBeRegenerated[MAXPLAYERS+1];	
int g_Iteration[MAXPLAYERS+1];

int m_flLaggedMovementValue;

float g_dSpeed;

Handle g_VipReactivate[MAXPLAYERS+1];
ArrayList g_VipUsers;

public void OnPluginStart()
{
	m_flLaggedMovementValue = FindSendPropOffs("CCSPlayer", "m_flLaggedMovementValue");
	
	RegAdminCmd("sm_vip", CommandVIP, ADMFLAG_CUSTOM5, "Opens admin menu");
	
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("round_end", Event_RoundEnd);
	
	for (int i = 0; i <= MAXPLAYERS; ++i)
	{
		g_VipUsed[i] = false;
	}	
	
	CreateTimer(120.0, Rehash, 0, TIMER_REPEAT);
	g_VipUsers = new ArrayList();
}

public Action Rehash(Handle timer, int uselessInfo)
{
	ServerCommand("sm_rehash");
	LogMessage("VIP plugin has reloaded admin list");
}

public Action Event_PlayerSpawn(Event event, const char[] eName, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int user = event.GetInt("userid");
	
	g_VipUsed[client] = false;
	
	if (IsVip(client) && IsPlayerAlive(client))
	{
		g_dSpeed = GetEntDataFloat(client, m_flLaggedMovementValue); //надо переместить этот код нахуй отсюда
		CreateTimer(0.6, SetVipPassiveAbilities, client);
		CreateTimer(1.0, FixVipPassiveAbilities, client, TIMER_REPEAT);

		g_VipUsers.Push(user);
	}
}

public Action SetVipPassiveAbilities(Handle timer, int client)
{
	g_MaxHealth[client] = 100 + Id_CalcRank(Id_GetXP(client)) * 10;
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
	
	int weapon;
	if ((weapon = GetPlayerWeaponSlot(client, CS_SLOT_KNIFE)) != -1)
	{
		SDKHooks_DropWeapon(client, weapon, NULL_VECTOR, NULL_VECTOR);
		AcceptEntityInput(weapon, "Kill");
	}
	GivePlayerItem(client, "weapon_knifegg"); //why not?
}

public Action FixVipPassiveAbilities(Handle timer, int client)
{
	if (IsClientInGame(client))
	{
		if (ContainsInt(g_VipUsers, GetClientUserId(client)))
		{
			if (IsPlayerAlive(client))
			{
				if (!g_VipActive[client])
				{					
					SetEntityGravity(client, 0.85);
					SetEntDataFloat(client, m_flLaggedMovementValue, g_dSpeed * 1.05, true);
					CS_SetClientClanTag(client, "[VIP]");
				}					
			}
			else
			{
				return Plugin_Stop;
			}
		}
		else
		{
			SetEntityGravity(client, 1.0);
			SetEntDataFloat(client, m_flLaggedMovementValue, g_dSpeed, true);
			CS_SetClientClanTag(client, "");
			
			g_VipUsers.Erase(FindIndex(g_VipUsers, GetClientUserId(client)));
			return Plugin_Stop;
		}
	}
	else
	{
		return Plugin_Stop;
	}	
	
	return Plugin_Continue;
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
		if (GetClientTeam(client) == CS_TEAM_T || GetClientTeam(client) == CS_TEAM_CT)
		{
			if (!g_VipUsed[client])
			{
				Menu menu = new Menu(VipMenuHandler, MENU_ACTIONS_ALL);
				menu.SetTitle("VIP-меню");
				
				menu.AddItem("heal", "Лечение (+100 HP)");
				menu.AddItem("regen", "Регенерация (10 HP/с)");
				menu.AddItem("gravity", "Гравитация (10 секунд)");
				menu.AddItem("speed", "Скорость (10 секунд)");			
				menu.AddItem("armor", "Броня (+100 брони)");
				
				if (GetClientTeam(client) == CS_TEAM_T)
				{
					menu.AddItem("unrebel", "Снять окраску бунтаря");
					menu.AddItem("fakect", "Маскировка (10 секунд)");			
				}
				
				menu.Display(client, MENU_TIME_FOREVER);
			}
			else
			{
				CGOPrintToChat(client, "{GREEN}[VIP]{DEFAULT} VIP-меню можно использовать лишь один раз за раунд!");
			}			
		}
		else if (g_VipUsed[client])
		{
			CGOPrintToChat(client, "{GREEN}[VIP]{DEFAULT} Вы не можете использовать VIP-меню!");
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
	SetEntityGravity(client, 0.35);	
	g_VipUsed[client] = true;	
	CreateTimer(10.0, DisableVipGravity, client);	
}

public void CommandVIPSpeed(int client)
{	
	SetEntDataFloat(client, m_flLaggedMovementValue, g_dSpeed * 1.5, true);
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
			PrintToServer("SQL Query errored (Id_GetXP(%d))", client);
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
			PrintToServer("SQL Query errored (Id_GetXP(%d))", client);
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

bool ContainsInt(ArrayList array, int value)
{
	for (int i = 0; i < array.Length; ++i)
	{
		if (array.Get(i) == value)
		{
			return true;
		}
	}
	
	return false;
}

int FindIndex(ArrayList array, int value)
{
	for (int i = 0; i < array.Length; ++i)
	{
		if (array.Get(i) == value)
		{
			return i;
		}
	}
	
	return -1;
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
	
	if (GetClientHealth(client) < g_MaxHealthCanBeRegenerated[client] - 10)
	{
		SetEntityHealth(client, GetClientHealth(client) + 10);
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