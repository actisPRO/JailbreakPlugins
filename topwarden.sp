#include <sourcemod>
#include <jwp>
#include <clients>
#include <cstrike>
#include <achivements>

#pragma semicolon 1
#pragma newdecls required

Handle g_Timer;

public Plugin myinfo = {
	name        = "Top warden",
	author      = "Actis",
	description = "",
	version     = "1.0.0",
	url         = "CS-JB.RU"
};

public void OnPluginStart()
{
	HookEvent("round_start", Event_RoundStart);
	HookEvent("round_end", Event_RoundEnd);
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	int random = GetRandomInt(1, 5);
	if (random == 1)
	{
		float randomTime = GetRandomFloat(120.0, 210.0);
		g_Timer = CreateTimer(randomTime, AskQuestion);
	}
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	if (g_Timer != INVALID_HANDLE)
	{
		KillTimer(g_Timer);
	}
}

Action AskQuestion(Handle time)
{
	int warden = JWP_GetWarden();
	if (warden == 0)
	{
		return Plugin_Handled;
	}
	
	ArrayList t_team = new ArrayList();
	for (int i = 1; i <= MaxClients; ++i)
	{
		if (IsPlayerAlive(i) && GetClientTeam(i) == CS_TEAM_T)
		{
			t_team.Push(i);
		}
	}
	
	int random = GetRandomInt(0, t_team.Length - 1);
	int client = t_team.Get(random);
	
	char wardenName[32];
	GetClientName(warden, wardenName, 32);
	
	char title[255];
	Format(title, 255, "Вам нравится командир %s?", wardenName);
	
	Menu menu = new Menu(MenuHandler, MENU_ACTIONS_ALL);
	menu.SetTitle(title);
	menu.Pagination = MENU_NO_PAGINATION;
	menu.AddItem("yes", "Да");
	menu.AddItem("no", "No");
	
	menu.Display(client, MENU_TIME_FOREVER);
	
	return Plugin_Handled;
}

int MenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char info[32];
			menu.GetItem(param2, info, sizeof(info));
			
			char steamid[64];
			GetClientAuthId(param1, AuthId_Steam2, steamid, 64);
			
			char achivement_name[42];
			Format(achivement_name, 42, "achivement_likew_%s", param2);
			Achivements_SetValue(steamid, achivement_name, Achivements_GetValue(steamid, achivement_name) + 1);
		}
	}
}