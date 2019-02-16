#include <sourcemod>
#include <events>
#include <clients>
#include <cstrike>
#include <timers>
#include <csgo_colors>
#include <sdktools>

public Plugin myinfo = {
	name        = "Mute Prisoners",
	author      = "Actis",
	description = "",
	version     = "1.0.0",
	url         = "CS-JB.RU"
};

Handle g_Timer;

public void OnPluginStart()
{
	HookEvent("round_freeze_end", Event_RoundStart);
	HookEvent("round_end", Event_RoundEnd);
	HookEvent("player_death", Event_PlayerDeath);
}

void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{	
	int client = GetClientOfUserId(event.GetInt("userid"));
	SetClientListeningFlags(client, VOICE_NORMAL);
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	if (g_Timer != null)
	{
		KillTimer(g_Timer);
		g_Timer = null;
		
		for (int i = 1; i <= MaxClients; ++i)
		{
			if (IsClientInGame(i))
			{
				SetClientListeningFlags(i, VOICE_NORMAL);			
			}
		}
	}
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	for (int i = 1; i <= MaxClients; ++i)
	{
		if (IsClientInGame(i))
		{
			if (GetClientTeam(i) == CS_TEAM_T && IsPlayerAlive(i))
			{
				SetClientListeningFlags(i, VOICE_MUTED);
			}
		}
	}
	
	g_Timer = CreateTimer(30.0, UnmuteAll);
	CGOPrintToChatAll("{GREEN}Заключенным отключен микрофон на 30 секунд.");
}

Action UnmuteAll(Handle timer)
{
	for (int i = 1; i <= MaxClients; ++i)
	{
		if (IsClientInGame(i))
		{
			SetClientListeningFlags(i, VOICE_NORMAL);			
		}
	}
	
	CGOPrintToChatAll("{GREEN}Заключенные снова могут говорить.");
	g_Timer = null;
}
