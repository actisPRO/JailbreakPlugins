#include <sourcemod>
#include <clients>
#include <csgo_colors>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo = {
	name        = "Total Gametime",
	author      = "Actis",
	description = "Gametime",
	version     = "1.0.0",
	url         = "CS-JB.RU"
};

public void OnPluginStart()
{	
	RegConsoleCmd("sm_gametime", Command_GameTime);
}

public void OnClientDisconnect(int client)
{
	char steamid[64];
	GetClientAuthId(client, AuthId_Steam2, steamid, 64);
	
	SetGameTimeSQL(client, GetGameTimeSQL(client) + RoundToNearest(GetClientTime(client)));
}

Action Command_GameTime(int client, int args) 
{
	int time = GetGameTimeSQL(client);
	int totalTime = time + RoundToNearest(GetClientTime(client));
	
	char serverTime_s[32];	
	FormatTime(serverTime_s, 32, "%F %X", GetTime());
	
	CGOPrintToChat(client, "Общее время: {GREEN}%s{DEFAULT}. Текущее время на сервере: {GREEN}%s{DEFAULT}", GetNormalTime(totalTime), serverTime_s);
}

int GetGameTimeSQL(int client)
{	
	char error[255];
	Database db = SQL_DefConnect(error, sizeof(error));
	
	if (db == null)
	{
		LogError("Errored while connecting to DB: %s", error);
		return -1;
	}
	else
	{
		char steamid[64];
		GetClientAuthId(client, AuthId_Steam2, steamid, 64);

		char query_text[512];
		Format(query_text, 512, "SELECT `gametime` FROM `id_accounts` WHERE `steamid` = '%s'", steamid);
	   	DBResultSet query = SQL_Query(db, query_text);
		
		if (query == null)
	   	{
	   		SQL_GetError(db, error, sizeof(error));
			return -1;
	   	} 
	   	else 
	   	{
	   		while (SQL_FetchRow(query))
	  		{						
	   			return SQL_FetchInt(query, 0);
	   		}	   		
	   		delete query;
	   	}	
		delete db;
		
		return 0;
	}
}

int SetGameTimeSQL(int client, int gametime)
{
	char error[255];
	Database db = SQL_DefConnect(error, sizeof(error));
		    
	if (db == null)
	{
	  	LogError("Could not connect: %s", error);
		return -1;
	} 
	else 
	{
	   	char steamid[64];
	   	GetClientAuthId(client, AuthId_SteamID64, steamid, 64);
	    	
	   	char query_text[512]; 
	   	Format(query_text, 512, "UPDATE `id_accounts` SET `gametime` = '%d' WHERE `id_accounts`.`steamid64` = '%s';", gametime, steamid);
		PrintToServer(query_text);
		
	   	if (!SQL_FastQuery(db, query_text))
		{
			SQL_GetError(db, error, sizeof(error));
			LogError("Failed to query (error: %s)", error);
			return -2;
		}
		
		delete db;
		return gametime;
	}
}

char[] GetNormalTime(int time)
{
	int hours = time / 3600;
	int minutes = (time - hours * 3600) / 60;
	int seconds = time - minutes * 60 - hours * 3600;
	
	char hours_s[6];
	char minutes_s[6];
	char seconds_s[6];
	if (hours == 0)
	{
		hours_s = "00";
	}
	else if (hours < 10)
	{
		Format(hours_s, 6, "0%d", hours);
	}
	else
	{
		Format(hours_s, 6, "%d", hours);
	}
	
	if (minutes == 0)
	{
		minutes_s = "00";
	}
	else if (minutes < 10)
	{
		Format(minutes_s, 6, "0%d", minutes);
	}
	else 
	{
		Format(minutes_s, 6, "%d", minutes);
	}
	
	if (seconds == 0)
	{
		seconds_s = "00";
	}
	else if (seconds < 10)
	{
		Format(seconds_s, 6, "0%d", seconds);
	}
	else
	{
		Format(seconds_s, 6, "%d", seconds);
	}
	
	char buffer[16];
	Format(buffer, 16, "%s:%s:%s", hours_s, minutes_s, seconds_s);
	return buffer;
}
