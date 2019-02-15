#include <sourcemod>

#pragma semicolon 1
#pragma newdecls required

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
	return 0;
}

int SetValue(char[] steamid, char[] index, int newValue)
{
	return newValue;
}