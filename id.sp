#include <sourcemod>
#include <clients>
#include <csgo_colors>
#include <cstrike>
#include <lastrequest>
#include <jwp>

#pragma semicolon 1
#pragma newdecls required

#define VERY_BIG_NUMBER 1000000

public Plugin myinfo = {
	name        = "ID and Ranks",
	author      = "Actis",
	description = "",
	version     = "1.0.0",
	url         = "CS-JB.RU"
};

public void OnPluginStart()
{
	RegConsoleCmd("sm_n", GetMyId);
	RegConsoleCmd("sm_id", GetInfo);
	
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("round_end", Event_RoundEnd);
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("round_freeze_end", Event_RoundFreezeEnd);
}

void Event_RoundFreezeEnd(Event event, const char[] name, bool dontBroadcast)
{	
	float allPlayersCount = 0.0;
	int cts = 0;
	int maxCt = 0;
	
	for (int i = 1; i <= MaxClients; ++i)
	{
		if (IsClientInGame(i) && (GetClientTeam(i) == CS_TEAM_CT || GetClientTeam(i) == CS_TEAM_T))
		{
			allPlayersCount++;
		}
	}
	
	for (int i = 1; i <= MaxClients; ++i)
	{
		if (IsClientInGame(i) && GetClientTeam(i) == CS_TEAM_CT)
		{
			cts++;
		}
	}
	
	if (allPlayersCount <= 2) 
	{
		maxCt = 1;
	}
	else 
	{
		maxCt = RoundToFloor(allPlayersCount / 3.0);
	}
	
	if (cts <= maxCt)
	{
		return;
	}
	
	int iterations = cts - maxCt;
	
	for (int i = 0; i < iterations; ++i)
	{
		int lowestClient;
		int lowestClientXp = VERY_BIG_NUMBER;
		
		for (int j = 1; j <= MaxClients; ++j)
		{
			if (IsClientInGame(j) && GetClientTeam(j) == CS_TEAM_CT)
			{
				PrintToServer("Client: %d", j);
				PrintToServer("Lowest Client: %d", lowestClient);
				PrintToServer("Lowest Xp: %d", lowestClientXp);
				
				int xp = GetXP(j);
				if (xp < lowestClientXp)
				{
					lowestClient = j;
					lowestClientXp = xp;
				}
			}
		}
		
		ChangeClientTeam(lowestClient, CS_TEAM_T);
		CS_RespawnPlayer(lowestClient);
	}
}

int PlayersIds(Menu menu, MenuAction action, int param1, int param2) 
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char info[32];
			menu.GetItem(param2, info, sizeof(info));
			int cid = -1;
			StringToIntEx(info, cid);
			
			char name[32];
			GetClientName(cid, name, 32);
			
			char buffer[255];
			Format(buffer, 255, "{GREEN}[!id]{DEFAULT} %s | Номер %d | Ранг %d | %s",
				name, GetId(cid), CalcRank(GetXP(cid)), GetAdminRank(cid));
			CGOPrintToChatAll(buffer);
		}
	}
}

public void AddXp(int client, int amount)
{
	int oldXp = GetXP(client);
	SetXp(client, oldXp + amount);
	int oldRank = CalcRank(oldXp);
	int newRank = CalcRank(oldXp + amount);
	char name[35];
	GetClientName(client, name, 35);
	if (newRank > oldRank)
	{
		CGOPrintToChatAll("{GREEN}[!id]{DEFAULT} {OLIVE}Игрок %s получил новый ранг!", name);
	}
}

Action GetInfo(int client, int args)
{
	Menu menu = new Menu(PlayersIds);
	menu.SetTitle("Выберите игрока:");
	
	for (int i = 1; i <= MaxClients; i++) 
	{
		if (IsClientInGame(i))
		{			
			if (GetClientTeam(i) == CS_TEAM_T || GetClientTeam(i) == CS_TEAM_CT || GetClientTeam(i) == CS_TEAM_SPECTATOR)
			{
				char name[32];
				GetClientName(i, name, 32);
			
				char cid[8];
				IntToString(i, cid, 8);
				menu.AddItem(cid, name);
			}
		}
	}
	
	menu.Display(client, MENU_TIME_FOREVER);
	
	return Plugin_Handled;
}

Action GetMyId(int client, int args)
{
	char buffer[255];
	Format(buffer, 255, "{GREEN}[!id]{DEFAULT} Ваш ID: %d", GetId(client));
	CGOPrintToChat(client, buffer);
	
	return Plugin_Handled;
}

void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int killer = GetClientOfUserId(event.GetInt("attacker"));
	int killed = GetClientOfUserId(event.GetInt("userid"));
	
	if (killer != killed)
	{
		if (GetClientTeam(killer) == CS_TEAM_T && GetClientTeam(killed) == CS_TEAM_CT)
		{			
			AddXp(killer, 1);							
		}
		else if (GetClientTeam(killer) == CS_TEAM_CT && IsClientRebel(killed))
		{
			AddXp(killer, 1);
		}
	}
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	int winner = event.GetInt("winner");
	for (int i = 1; i <= MaxClients; i++) 
	{
		if (IsClientInGame(i))
		{			
			if (GetClientTeam(i) == CS_TEAM_T || GetClientTeam(i) == CS_TEAM_CT)
			{
				AddXp(i, 1);
			}
			
			if (GetClientTeam(i) == winner)
			{
				if (IsPlayerAlive(i))
				{
					switch (GetClientTeam(i))
					{
						case CS_TEAM_T:
						{
							AddXp(i, 2);
						}
						case CS_TEAM_CT:
						{
							AddXp(i, 3);
							if (JWP_IsWarden(i))
							{
								AddXp(i, 2);	
							}
						}
					}
				}
			}			
			
		}
	}
}

/*
 * Выдача ID при первом спавне.
 */
void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	char error[255];
	Database db = SQL_DefConnect(error, sizeof(error));
		    
	if (db == null)
	{
	  	PrintToServer("Could not connect: %s", error);
	} 
	else 
	{
		char steamid64[64];
		char steamid2[64];
	   	GetClientAuthId(client, AuthId_SteamID64, steamid64, 64);
	   	GetClientAuthId(client, AuthId_Steam2, steamid2, 64);
		
		char buffer[255];
		Format(buffer, 255, "SELECT `id` FROM `id_accounts` WHERE `steamid64` = '%s'", steamid64);
		DBResultSet query = SQL_Query(db, buffer);
		if (query == null)
	   	{
			Format(buffer, 255, "INSERT INTO `id_accounts` (`id`, `steamid`, `steamid64`, `xp`) VALUES (NULL, '%s','%s', '0');", steamid2, steamid64);
			if (!SQL_FastQuery(db, buffer))
			{
				SQL_GetError(db, error, sizeof(error));
				PrintToServer("Failed to query (error: %s)", error);
			}
	   	}
		else 
		{
			if (SQL_GetRowCount(query) == 0)
			{
				Format(buffer, 255, "INSERT INTO `id_accounts` (`id`, `steamid`, `steamid64`, `xp`) VALUES (NULL, '%s','%s', '0');", steamid2, steamid64);
				if (!SQL_FastQuery(db, buffer))
				{
					SQL_GetError(db, error, sizeof(error));
					PrintToServer("Failed to query (error: %s)", error);
				}
			}
			
			delete query;
		}
	}
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
}

void SetXp(int client, int xp)
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
		Format(buffer, 255, "UPDATE `id_accounts` SET `xp` = '%d' WHERE `id_accounts`.`id` = %d ", xp, GetId(client));
		if (!SQL_FastQuery(db, buffer))
		{
			SQL_GetError(db, error, sizeof(error));
			PrintToServer("Failed to query (error: %s)", error);
		}
		
		delete db;
	}
}

int GetId(int client)
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
		Format(buffer, 255, "SELECT `id` FROM `id_accounts` WHERE `steamid64` = '%s'", steamid64);
		DBResultSet query = SQL_Query(db, buffer);
		
		if (query == null)
		{
			PrintToServer("SQL Query errored (GetId(%d))", client);
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

char[] GetAdminRank(int client)
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
		Format(buffer, 255, "SELECT `srv_group` FROM `sb_admins` WHERE `authid` = '%s';", steamid);
		DBResultSet query = SQL_Query(db, buffer);
		if (query == null)
		{
			PrintToServer("SQL Query errored (GetAdminStatus())");
		}
		else
		{
			if (SQL_GetRowCount(query) == 0)
			{
				char res[64] = "Игрок";
				return res;
			}
			else
			{
				char roleName[64];
				while (SQL_FetchRow(query))
				{
					SQL_FetchString(query, 0, roleName, 64);
				}
				
				if (StrEqual(roleName, "Root"))
				{
					char res[64] = "Главный администратор";
					return res;
				}
				else if (StrEqual(roleName, "Superadmin"))
				{
					char res[64] = "Суперадминистратор";
					return res;
				}
				else if (StrEqual(roleName, "Admin"))
				{
					char res[64] =  "Администратор";
					return res;
				}
				else if (StrEqual(roleName, "Helper"))
				{
					char res[64] = "Хэлпер";
					return res;
				}
				else
				{
					char res[64] =  "Игрок";
					return res;
				}
			}
		}
	}

	char res[64] = "Игрок";
	return res;
}

char[] GetAdminRankDeprecated(int client)
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
		Format(buffer, 255, "SELECT `id` FROM `sm_admins` WHERE `identity` = '%s';", steamid);
		DBResultSet query = SQL_Query(db, buffer);
		
		if (query == null)
		{
			PrintToServer("SQL Query errored (GetAdminStatus(%d), checking if player is admin.)", client);
		}
		else
		{
			if (SQL_GetRowCount(query) == 0)
			{
				char res[64] = "Игрок";
				return res;
			}
			else
			{
				int adminid;
				while (SQL_FetchRow(query))
				{					
					adminid = SQL_FetchInt(query, 0);
				}
				Format(buffer, 255, "SELECT `group_id` FROM `sm_admins_groups` WHERE `admin_id` = '%d';", adminid);
				DBResultSet query2 = SQL_Query(db, buffer);
				if (query2 == null)
				{
					PrintToServer("SQL Query errored (GetAdminStatus(%d), getting group id.)", client);
				}
				else
				{
					int gid;
					while (SQL_FetchRow(query2))
					{					
						gid = SQL_FetchInt(query2, 0);
					}
					Format(buffer, 255, "SELECT `name` FROM `sm_groups` WHERE `id` = '%d';", gid);
					DBResultSet query3 = SQL_Query(db, buffer);
					if (query3 == null)
					{
						PrintToServer("SQL Query errored (GetAdminStatus(%d), getting group.)", client);
					}
					else
					{
						char roleName[64];
						while (SQL_FetchRow(query3))
						{
							SQL_FetchString(query3, 0, roleName, 64);
						}
						
						if (StrEqual(roleName, "Root"))
						{
							char res[64] = "Главный администратор";
							return res;
						}
						else if (StrEqual(roleName, "Superadmin"))
						{
							char res[64] = "Суперадминистратор";
							return res;
						}
						else if (StrEqual(roleName, "Admin"))
						{
							char res[64] =  "Администратор";
							return res;
						}
						else if (StrEqual(roleName, "Helper"))
						{
							char res[64] = "Хэлпер";
							return res;
						}
						else
						{
							char res[64] =  "Игрок";
							return res;
						}
					}
				}				
			}
			
			delete query;
		}		
	}
	
	char res[64] = "-1";
	return res;
}

int GetAdminPriority(char[] rank)
{
	if (StrEqual(rank, "Главный администратор"))
	{
		return 4;
	}
	else if (StrEqual(rank, "Суперадминистратор"))
	{
		return 3;
	}
	else if (StrEqual(rank, "Администратор"))
	{
		return 2;
	}
	else if (StrEqual(rank, "Хэлпер"))
	{
		return 1;
	}
	else
	{
		return 1;
	}
}