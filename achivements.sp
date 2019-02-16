#include <sourcemod>

#pragma semicolon 1
#pragma newdecls required

#define ACHIVEMENT_ERR_DB_CONNECT -1
#define ACHIVEMENT_ERR_DB_QUERY -2
#define ACHIVEMENT_ERR_DB_NOVAL -3

public Plugin myinfo = {
	name        = "Achivements",
	author      = "Actis",
	description = "Achivements for JailBreak",
	version     = "1.0.0",
	url         = "CS-JB.RU"
};

/*public void OnPluginStart()
{
	
}*/

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("Achivements_GetValue", Native_GetValue);
	CreateNative("Achivements_SetValue", Native_SetValue);
	return APLRes_Success;
}

public int Native_GetValue(Handle plugin, int numParams)
{
	char steamid[32], index[32];
	GetNativeString(1, steamid, 32);
	GetNativeString(2, index, 32);
	
	return GetValue(steamid, index);
}

public int Native_SetValue(Handle plugin, int numParams)
{
	char steamid[32], index[32];
	int newValue;
	GetNativeString(1, steamid, 32);
	GetNativeString(2, index, 32);
	newValue = GetNativeCell(3);
	
	return SetValue(steamid, index, newValue);
}

int GetValue(char[] steamid, char[] index)
{
	int value;
	
	char error[255];
	Database db = SQL_DefConnect(error, sizeof(error));
	if (db == null)
	{
		return ACHIVEMENT_ERR_DB_CONNECT;
	}
	else
	{
		char query_text[512];
		Format(query_text, 512, "SELECT `achivement_%s` FROM `id_accounts` WHERE `steamid` = '%s'", index, steamid);
		DBResultSet query = SQL_Query(db, query_text);
		
		if (query == null)
		{
			return ACHIVEMENT_ERR_DB_QUERY;
		}
		else 
		{
			if (SQL_GetRowCount(query) == 0)
			{
				return ACHIVEMENT_ERR_DB_NOVAL;
			}
			else
			{
				while (SQL_FetchRow(query))
				{						
					value = SQL_FetchInt(query, 0);
				}
				return value;
			}
		}
	}
}

int SetValue(char[] steamid, char[] index, int newValue)
{
	return newValue;
}