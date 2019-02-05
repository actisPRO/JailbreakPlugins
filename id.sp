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
	
	int toKick = cts - maxCt;
	
	/*int[] players = new int[MaxClients];
	for (int i = 0; i <= MaxClients; ++i)
	{
		if (IsClientInGame(i))
		{
			if (GetClientTeam(i) == CS_TEAM_CT)
			{
				players[i] = GetAdminPriority(GetAdminRank(i));
			}
			else
			{
				players[i] = 0;
			}
		}
		else
		{
			players[i] = 0;
		}
	}
	
	SortIntegers(players, MaxClients, Sort_Descending);*/
	
	
	for (int i = 0; i < toKick; ++i)
	{
		int lowestClient = -1;
		int lowestClientXp = VERY_BIG_NUMBER;
		
		for (int j = 1; j <= MaxClients; ++j)
		{
			if (IsClientInGame(j) && GetClientTeam(j) == CS_TEAM_CT)
			{				
				int xp = GetXP(j);
				
				PrintToServer("%d vs %d", GetAdminPriority(GetAdminRank(lowestClient)), GetAdminPriority(GetAdminRank(j)));
				PrintToServer("%d vs %d", lowestClientXp, GetXP(j));
				
				if (GetAdminPriority(GetAdminRank(j)) < GetAdminPriority(GetAdminRank(lowestClient)))	
				{
					lowestClient = j;
					lowestClientXp = xp;	
				}
				else if (GetAdminPriority(GetAdminRank(j)) == GetAdminPriority(GetAdminRank(lowestClient)))
				{
					if (xp <= lowestClientXp)
					{
						lowestClient = j;
						lowestClientXp = xp;						
					}
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
		char ip[32];
		char usr[35];
	   	GetClientAuthId(client, AuthId_SteamID64, steamid64, 64);
	   	GetClientAuthId(client, AuthId_Steam2, steamid2, 64);
		GetClientIP(client, ip, 32, true);
		GetClientName(client, usr, 35);
		
		
		char buffer[255];
		Format(buffer, 255, "SELECT `id` FROM `id_accounts` WHERE `steamid64` = '%s'", steamid64);
		DBResultSet query = SQL_Query(db, buffer);
		if (query == null)
	   	{
			/* здесь был ненужный код, а теперь его нет. вообще, надо поставить обработчик ошибок, но... зачем? */
	   	}
		else 
		{
			if (SQL_GetRowCount(query) == 0)
			{
				Format(buffer, 255, "INSERT INTO `id_accounts` (`id`, `steamid`, `steamid64`, `IP`, `name`, `xp`) VALUES (NULL, '%s', '%s', '%s', '%s', '0');", steamid2, steamid64, ip, usr);
				if (!SQL_FastQuery(db, buffer))
				{
					SQL_GetError(db, error, sizeof(error));
					PrintToServer("Failed to query (error: %s)", error);
				}
			}
			else
			{
				Format(buffer, 255, "UPDATE `id_accounts` SET `IP` = '%s', `name` = '%s' WHERE `id_accounts`.`steamid64` = %s;", ip, usr, steamid64);
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
	
	return 1;
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
	if (client == -1)
	{
		return 0;
	}
	
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
	if (client == -1)
	{
		char res[64] = "Говнокод";
		return res;
	}
	
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

int GetAdminPriority(char[] rank)
{
	if (StrEqual(rank, "Главный администратор"))
	{
		return 5;
	}
	else if (StrEqual(rank, "Суперадминистратор"))
	{
		return 4;
	}
	else if (StrEqual(rank, "Администратор"))
	{
		return 3;
	}
	else if (StrEqual(rank, "Хэлпер"))
	{
		return 2;
	}
	else if (StrEqual(rank, "Говнокод"))
	{
		return 1000;
	}
	else
	{
		return 1;
	}
}