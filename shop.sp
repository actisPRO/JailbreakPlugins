#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <sdktools_entinput>
#include <sdkhooks>
#include <entity_prop_stocks>
#include <csgo_colors>
#include <clients>
#include <menus>
#include <lastrequest>
#include <jwp>
#include <achivements>

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo = {
	name        = "JailBreak Shop",
	author      = "Actis",
	description = "Shop for JailBreak",
	version     = "2.1.0",
	url         = "CS-JB.RU"
};

/* КОНВАРЫ */

ConVar g_priceSmoke;
ConVar g_priceFlash;
ConVar g_priceHealth;
ConVar g_priceArmor;
ConVar g_priceDeagle;
ConVar g_priceProtein;
ConVar g_startMoney;
ConVar g_roundEndMoney;
ConVar g_roundWinMoney;
ConVar g_killCtMoney;
ConVar g_priceRoulette;
ConVar g_priceHealthCT;
ConVar g_priceTacticalGrenade;
ConVar g_priceArmorCT;
ConVar g_priceAWP;
ConVar g_priceAntiterror;
ConVar g_roundEndTokens;
ConVar g_roundWinTokens;
ConVar g_roundWinWardenTokens;
ConVar g_killRebelTokens;

/* ГЛОБАЛЬНЫЕ ПЕРМЕННЫЕ */ 
int g_ShopUsed[MAXPLAYERS+1]; // сколько раз пользователь использовал магазин
bool g_RouletteUsed[MAXPLAYERS+1]; // использовал ли пользователь рулетку
Handle g_Timer; // таймер для блокировки магазина
bool g_ShopAvaliable; // доступен ли магазин

/* ФОРВАРДЫ */

public void OnPluginStart()
{
	RegConsoleCmd("sm_shop", OpenShopMenu);
	RegConsoleCmd("sm_store", OpenShopMenu);
	RegConsoleCmd("sm_smoke", Smoke);
	RegConsoleCmd("sm_balance", CheckBalance);
	RegConsoleCmd("sm_transfer", Transfer);
	
	g_priceSmoke = CreateConVar("jbs_price_smoke", "200", "Sets smoke price");
	g_priceFlash = CreateConVar("jbs_price_flashbang", "150", "Sets flashbang price");
	g_priceHealth = CreateConVar("jbs_price_healthshot", "5", "Sets healthshot price");
	g_priceArmor = CreateConVar("jbs_price_armor", "100", "Sets armor price");
	g_priceDeagle = CreateConVar("jbs_price_deagle", "120", "Sets deagle price");
	g_priceProtein = CreateConVar("jbs_price_protein", "500", "Sets protein price");
	g_priceRoulette = CreateConVar("jbs_price_roulette", "15", "Sets roulette price");
	
	g_priceHealthCT = CreateConVar("jbs_price_healthshot_ct", "1", "Sets healthshot price for CT team"); //5 credits def
	g_priceTacticalGrenade = CreateConVar("jbs_price_tagrenade", "15", "Sets tactical grenade price for CT team"); //75 credits def
	g_priceArmorCT = CreateConVar("jbs_price_armor_ct", "20", "Sets armor price for CT team"); //100 credits def
	g_priceAWP = CreateConVar("jbs_price_awp", "50", "Sets AWP price for CT team"); // 250 credits def
	g_priceAntiterror = CreateConVar("jbs_price_antiterror", "120", "Sets Anti-Terror pack price");	 //600 credits def
	
	g_startMoney = CreateConVar("jbs_start_money", "300", "Player receives this amount of money, when he joins the server first time");
	
	g_roundEndMoney = CreateConVar("jbs_round_end_money", "5", "Each (dead, alive, ts, but not spectators and cts) player receives this amount of money, when round ends");
	g_roundWinMoney = CreateConVar("jbs_round_win_money", "5", "Each alive member of winner team (T only) gets this amount of money");
	
	g_roundEndTokens = CreateConVar("jbs_round_end_tokens", "1", "Each dead or alive CT gets this amount of tokens");
	g_roundWinTokens = CreateConVar("jbs_round_win_tokens", "1", "Each alive CT gets this amount of money if his team wins a round");
	g_roundWinWardenTokens = CreateConVar("jbs_round_win_warden_tokens", "1", "Warden gets this amount of money if his team wins a round");
	
	g_killCtMoney = CreateConVar("jbs_kill_ct_money", "2", "CT killer gets this amount of money");	
	g_killRebelTokens = CreateConVar("jbs_kill_rebel_tokens", "1", "Rebel killer gets this amount of tokens");
	
	HookEvent("round_start", Event_RoundStart);
	HookEvent("round_end", Event_RoundEnd);
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_death", Event_PlayerDeath);
	
	AutoExecConfig(true, "jail_shop");
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("Shop_GetTokens", Native_GetTokens);
	CreateNative("Shop_SetTokens", Native_SetTokens);
	CreateNative("Shop_GetCredits", Native_GetCredits);
	CreateNative("Shop_SetCredits", Native_SetCredits);
	return APLRes_Success;
}

/* НАТИВЫ */

public int Native_GetTokens(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	return GetTokens(client);
}

public int Native_SetTokens(Handle plugin, int numParams)
{
	int client, newValue;
	client = GetNativeCell(1);
	newValue = GetNativeCell(2);
	return SetTokens(client, newValue);
}

public int Native_GetCredits(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	return GetCredits(client);
}

public int Native_SetCredits(Handle plugin, int numParams)
{
	int client, newValue;
	client = GetNativeCell(1);
	newValue = GetNativeCell(2);
	return SetCredits(client, newValue);
}

/* ХУКИ ДЛЯ КОМАНД */

public Action CheckBalance(int client, int args)
{
	char buffer[255];
	Format(buffer, 255, "{GREEN}[Чёрный рынок]{DEFAULT} Ваши сигареты: {GREEN}%d{DEFAULT}.", GetCredits(client));
	CGOPrintToChat(client, buffer);
	
	return Plugin_Handled;
}

public Action Transfer(int client, int args)
{
	char name[64];
	if (args < 2)
	{
		CGOPrintToChat(client, "Используйте !transfer <ник> количество");
		return Plugin_Handled;
	}
	
	int target = -1;
	GetCmdArg(1, name, sizeof(name));
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientConnected(i))
		{
			continue;
		}
		char other[32];
		GetClientName(i, other, sizeof(other));
		if (StrEqual(name, other))
		{
			target = i;
		}
	}
	
	if (target == -1)
	{
		CGOPrintToChat(client, "{RED}[ERROR]{DEFAULT} Нет игрока с именем \"%s\".", name);
		return Plugin_Handled;
	}
	
	if (client == target)
	{
		CGOPrintToChat(client, "{RED}[ERROR]{DEFAULT} Нельзя передать кредиты самому себе", name);
		return Plugin_Handled;
	}
	
	char amount[10];
	GetCmdArg(2, amount, sizeof(amount));
	
	int cash = StringToInt(amount);
	int credits = GetCredits(client);
	if (cash > credits)
	{
		CGOPrintToChat(client, "{RED}[ERROR]{DEFAULT} Количество передаваемых сигарет превышает их количество у вас.");
		return Plugin_Handled;
	}
	
	if (cash < 1)
	{
		CGOPrintToChat(client, "{RED}[ERROR]{DEFAULT} Ты здесь не самый умный.");
		return Plugin_Handled;
	}
	
	SetCredits(client, credits - cash);
	SetCredits(target, GetCredits(target) + cash);
	
	char buffer[255];
	Format(buffer, 255, "{GREEN}[Чёрный рынок]{DEFAULT} Успешно передано %d сигарет игроку %s.", cash, name);
	CGOPrintToChat(client, buffer);
	
	char uName[35];
	GetClientName(client, uName, 35);
	Format(buffer, 255, "{GREEN}[Чёрный рынок]{DEFAULT} Игрок %s передал вам %d сигарет.", uName, cash);
	CGOPrintToChat(target, buffer);
	
	return Plugin_Handled;
}

public Action Smoke(int client, int args)
{
	if (!IsPlayerAlive(client))
	{
		CGOPrintToChat(client, "{RED}Мертвецы не могут курить.{DEFAULT}");
		return;
	}	
	
	int credits = GetCredits(client);
	SetEntityHealth(client, GetClientHealth(client) - 1);
	credits = SetCredits(client, credits - 1);
	
	int random = GetRandomInt(1, 10);
	if (random == 1)
	{
		char name[35];
		GetClientName(client, name, 35);
		ForcePlayerSuicide(client);
		CGOPrintToChatAll("{RED}%s умер от рака лёгких!{DEFAULT}", name);
	}
	
	random = GetRandomInt(1, 500);
	if (random == 1)
	{
		char name[35];
		GetClientName(client, name, 35);
		CGOPrintToChatAll("{GREEN}%s курил сигаретку и вдруг обнаружил в своем кармане еще тысячу.{DEFAULT}", name);
		credits = SetCredits(client, credits + 1000);
	}
	else
	{
		CGOPrintToChat(client, "{GREEN}Вы скурили сигаретку.{DEFAULT}");
	}

	char steamid[64];
	GetClientAuthId(client, AuthId_Steam2, steamid, 64);
	
	int score = Achivements_GetValue(steamid, "smoke");
	if (score < 0)
	{
		LogError("Errored while getting smoke score for %s. Error code: %d", steamid, score);
		return;
	}
	
	int result = Achivements_SetValue(steamid, "smoke", score + 1);
	if (result < 0)
	{
		LogError("Errored while setting smoke score for %s. Error code: %d", steamid, result);
		return;
	}	
}

public Action OpenShopMenu(int client, int args)
{
	if (IsPlayerAlive(client)) 
	{
		if (GetClientTeam(client) == CS_TEAM_T) //черный рынок
		{
			int credits = GetCredits(client);
			
			Menu menu = new Menu(ShopMenuHandler, MENU_ACTIONS_ALL);
			
			char title[255];
			Format(title, 255, "Чёрный рынок | Баланс: %d сигарет", credits);
			menu.SetTitle(title);
			
			char buffer[255];
			menu.AddItem("buy", "Купить сигареты");
			Format(buffer, 255, "Аптечка (%d сигарет)", g_priceHealth.IntValue);
			menu.AddItem("healthshot", buffer);			
			Format(buffer, 255, "Броня (%d сигарет)", g_priceArmor.IntValue);
			menu.AddItem("armor", buffer);			
			Format(buffer, 255, "Пистолет (%d сигарет)", g_priceDeagle.IntValue);
			menu.AddItem("deagle", buffer);			
			Format(buffer, 255, "Световая граната (%d сигарет)", g_priceFlash.IntValue);
			menu.AddItem("flashbang", buffer);
			Format(buffer, 255, "Дымовая граната (%d сигарет)", g_priceSmoke.IntValue);
			menu.AddItem("smoke", buffer);
			Format(buffer, 255, "Протеин (%d сигарет)", g_priceProtein.IntValue);
			menu.AddItem("protein", buffer);
			Format(buffer, 255, "Рулетка (%d сигарет)", g_priceRoulette.IntValue);
			menu.AddItem("roulette", buffer);			
		
			menu.Display(client, MENU_TIME_FOREVER);					
		}
		else if (GetClientTeam(client) == CS_TEAM_CT) //арсенал
		{
			int tokens = GetTokens(client);
			
			Menu menu = new Menu(CTShopMenuHandler, MENU_ACTIONS_ALL);
			
			char title[255];
			Format(title, 255, "Арсенал | Баланс: %d жетонов", tokens);
			menu.SetTitle(title);
			
			char buffer[255];
			menu.AddItem("buy", "Купить жетоны"); 
			Format(buffer, 255, "Аптечка (%d жетон)", g_priceHealthCT.IntValue);
			menu.AddItem("healthshot", buffer);
			Format(buffer, 255, "Тактическая граната (%d жетонов)", g_priceTacticalGrenade.IntValue);
			menu.AddItem("tagrenade", buffer);			
			Format(buffer, 255, "Броня (%d жетонов)", g_priceArmorCT.IntValue);
			menu.AddItem("armor", buffer);
			Format(buffer, 255, "Снайперская винтовка (%d жетонов)", g_priceAWP.IntValue);
			menu.AddItem("awp", buffer);
			Format(buffer, 255, "Антитеррор (%d жетонов)", g_priceAntiterror.IntValue);
			menu.AddItem("antiterror", buffer);
		
			menu.Display(client, MENU_TIME_FOREVER);
		}
		else
		{			
			CGOPrintToChat(client, "{GREEN}[Чёрный рынок]{DEFAULT} Магазин доступен только игрокам.");
		}
	}
	else
	{
		if (GetClientTeam(client) == CS_TEAM_T)
		{			
			CGOPrintToChat(client, "{GREEN}[Чёрный рынок]{DEFAULT} Вы должны быть живы, чтобы воспользоваться услугами чёрного рынка.");
		}
		else if (GetClientTeam(client) == CS_TEAM_CT)
		{
			CGOPrintToChat(client, "{GREEN}[Арсенал]{DEFAULT} Вы должны быть живы, чтобы воспользоваться арсеналом.");
		}
	}
	
	return Plugin_Handled;
}

/* СОБЫТИЯ */

void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{	
	int killer = GetClientOfUserId(event.GetInt("attacker"));
	int killed = GetClientOfUserId(event.GetInt("userid"));
	
	if (killer != killed)
	{
		if (GetClientTeam(killer) == CS_TEAM_T && GetClientTeam(killed) == CS_TEAM_CT)
		{			
			SetCredits(killer, GetCredits(killer) + g_killCtMoney.IntValue);
			char buffer[255];
			Format(buffer, 255, "{GREEN}[Чёрный рынок]{DEFAULT} Вы получаете %d сигарету за убийство КТ!", g_killCtMoney.IntValue);
			CGOPrintToChat(killer, buffer);								
		}
		else if (GetClientTeam(killer) == CS_TEAM_CT && IsClientRebel(killed))
		{
			SetTokens(killer, GetTokens	(killer) + g_killRebelTokens.IntValue);
			char buffer[255];
			Format(buffer, 255, "{GREEN}[Арсенал]{DEFAULT} Вы получаете %d жетон за убийство бунтующего заключенного!", g_killRebelTokens.IntValue);
			CGOPrintToChat(killer, buffer);
		}
	}
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	for (int i = 1; i <= MaxClients; ++i)
	{
		if (IsClientInGame(i))
		{
			if (GetClientTeam(i) != CS_TEAM_SPECTATOR)
			{
				if (GetClientTeam(i) == CS_TEAM_T)
				{					
					SetCredits(i, GetCredits(i) + g_roundEndMoney.IntValue);
					char buffer[255];
					Format(buffer, 255, "{GREEN}[Чёрный рынок]{DEFAULT} Вы получаете %d сигарет за окончание раунда.", g_roundEndMoney.IntValue);
					CGOPrintToChat(i, buffer);
				}
				else 
				{
					SetTokens(i, GetTokens(i) + g_roundEndTokens.IntValue);
					char buffer[255];
					Format(buffer, 255, "{GREEN}[Арсенал]{DEFAULT} Вы получаете %d жетон за окончание раунда.", g_roundEndTokens.IntValue);
					CGOPrintToChat(i, buffer);
				}
			}
			
			if (GetClientTeam(i) == event.GetInt("winner") && IsPlayerAlive(i))
			{
				if (GetClientTeam(i) == CS_TEAM_T)
				{					
					SetCredits(i, GetCredits(i) + g_roundWinMoney.IntValue);
					char buffer[255];
					Format(buffer, 255, "{GREEN}[Чёрный рынок]{DEFAULT} И дополнительно %d сигарет за победу!", g_roundWinMoney.IntValue);
					CGOPrintToChat(i, buffer);
				}
				else 
				{
					SetTokens(i, GetTokens(i) + g_roundWinTokens.IntValue);
					char buffer[255];
					Format(buffer, 255, "{GREEN}[Арсенал]{DEFAULT} И дополнительно %d жетон за победу!", g_roundWinTokens.IntValue);
					CGOPrintToChat(i, buffer);
					if (JWP_IsWarden(i))
					{
						SetTokens(i, GetTokens(i) + g_roundWinWardenTokens.IntValue);
					}
				}
			}
		}
	}
	
	if (g_Timer != INVALID_HANDLE)
	{
		KillTimer(g_Timer);
		g_Timer = null;
	}	
	
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	g_ShopAvaliable = true;
	for (int i = 0; i < MAXPLAYERS + 1; ++i) 
	{
		g_ShopUsed[i] = 0;
	}
	g_Timer = CreateTimer(30.0, BlockShop);
}

void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	g_RouletteUsed[client] = false;
	
	char error[255];
	Database db = SQL_DefConnect(error, sizeof(error));
		    
	if (db == null)
	{
	  	PrintToServer("Could not connect: %s", error);
	} 
	else 
	{
	   	char steamid[64];
	   	GetClientAuthId(client, AuthId_SteamID64, steamid, 64);
	    	
	   	char query_text[512]; 
	   	Format(query_text, 512, "SELECT `balance` FROM `jbs_accounts` WHERE `steamid` = '%s'", steamid);
	   	DBResultSet query = SQL_Query(db, query_text);
		    	
	   	if (query == null)
	   	{
	   		// засунуть обработчик ошибок
	   	} 
	   	else 
	   	{
	   		if (SQL_GetRowCount(query) == 0)
			{
				char buffer[255];
				Format(buffer, 255, "INSERT INTO `jbs_accounts` (`steamid`, `balance`, `tokens`) VALUES ('%s', '%d', '0');", steamid, g_startMoney.IntValue);
				if (!SQL_FastQuery(db, buffer))
				{
					SQL_GetError(db, error, sizeof(error));
					PrintToServer("Failed to query (error: %s)", error);
				}
				Format(buffer, 255, "{GREEN}[Чёрный рынок]{DEFAULT} Вы впервые зашли на сервер и получили %d сигарет! Используйте !shop, чтобы их потратить.", g_startMoney.IntValue);
				CGOPrintToChat(client, buffer);
			}
	   		
	   		delete query;
	   	}	
		delete db;
	}
}

/* ХЭНДЛЕРЫ МЕНЮ */

int ShopMenuHandler(Menu menu, MenuAction action, int param1, int param2) 
{		
	int credits;
	switch (action)
	{
		case MenuAction_DrawItem:
		{
			credits = GetCredits(param1);
			
			int style;
			char info[32];
			menu.GetItem(param2, info, sizeof(info), style);			
			
			if (StrEqual(info, "smoke"))
			{
				if (credits >= g_priceSmoke.IntValue)
				{
					return style;
				}
				else
				{
					return ITEMDRAW_DISABLED;
				}
			}
			else if (StrEqual(info, "flashbang"))
			{
				if (credits >= g_priceFlash.IntValue)
				{
					return style;
				}
				else
				{
					return ITEMDRAW_DISABLED;
				}
			}
			else if (StrEqual(info, "healthshot"))
			{
				if (credits >= g_priceHealth.IntValue)
				{
					return style;
				}
				else
				{
					return ITEMDRAW_DISABLED;
				}
			}
			else if (StrEqual(info, "armor"))
			{
				if (credits >= g_priceArmor.IntValue)
				{
					return style;
				}
				else
				{
					return ITEMDRAW_DISABLED;
				}
			}
			else if (StrEqual(info, "deagle")) 
			{
				if (credits >= g_priceDeagle.IntValue)
				{
					return style;
				}
				else
				{
					return ITEMDRAW_DISABLED;
				}
			}
			else if (StrEqual(info, "protein"))
			{
				if (credits >= g_priceProtein.IntValue)
				{
					return style;
				}
				else
				{
					return ITEMDRAW_DISABLED;
				}
			}
			else if (StrEqual(info, "roulette"))
			{
				if (credits >= 15)
				{
					return style;
				}
				else 
				{
					return ITEMDRAW_DISABLED;
				}
			}
		}
		
		case MenuAction_Select:
		{
			credits = GetCredits(param1);
			
			char info[32];
			menu.GetItem(param2, info, sizeof(info));			
			
			if (g_ShopAvaliable)
			{
				if (g_ShopUsed[param1] == 0)
				{
					if (StrEqual(info, "buy"))
					{
						int tokens = GetTokens(param1);
						credits = GetCredits(param1);
			
						Menu buyMenu = new Menu(BuyCreditsMenuHandler, MENU_ACTIONS_ALL);
						char title[255];
						Format(title, 255, "Покупка сигарет | Баланс: %d жетонов, %d сигарет", tokens, credits);
						buyMenu.SetTitle(title);
						
						buyMenu.AddItem("5", "5 сигарет (1 жетон)");
						buyMenu.AddItem("50", "50 сигарет (10 жетонов)");
						buyMenu.AddItem("100", "100 сигарет (20 жетонов)");						
						buyMenu.AddItem("500", "500 сигарет (100 жетонов)");						
						buyMenu.AddItem("1000", "1000 сигарет (200 жетонов)");						
						buyMenu.AddItem("10000", "10000 сигарет (2000 жетонов)");
						
						buyMenu.Display(param1, MENU_TIME_FOREVER);
					}
					else if (StrEqual(info, "smoke"))
					{
						Item_Smoke(param1);				
						WriteShopUsed(param1);
						credits = SetCredits(param1, credits - g_priceSmoke.IntValue);
						
						char steamid[64];
						GetClientAuthId(param1, AuthId_Steam2, steamid, 64);						
						int score = Achivements_GetValue(steamid, "spentcredits");
						Achivements_SetValue(steamid, "spentcredits", score + g_priceSmoke.IntValue);
					}
					else if (StrEqual(info, "flashbang"))
					{
						Item_Flashbang(param1);
						WriteShopUsed(param1);
						credits = SetCredits(param1, credits - g_priceFlash.IntValue);
						
						char steamid[64];
						GetClientAuthId(param1, AuthId_Steam2, steamid, 64);						
						int score = Achivements_GetValue(steamid, "spentcredits");
						Achivements_SetValue(steamid, "spentcredits", score + g_priceFlash.IntValue);
					}
					else if (StrEqual(info, "healthshot"))
					{
						Item_Healthshot(param1);
						WriteShopUsed(param1);
						credits = SetCredits(param1, credits - g_priceHealth.IntValue);
						
						char steamid[64];
						GetClientAuthId(param1, AuthId_Steam2, steamid, 64);						
						int score = Achivements_GetValue(steamid, "spentcredits");
						Achivements_SetValue(steamid, "spentcredits", score + g_priceHealth.IntValue);
					}
					else if (StrEqual(info, "armor"))
					{
						Item_Armor(param1);
						WriteShopUsed(param1);
						credits = SetCredits(param1, credits - g_priceArmor.IntValue);
						
						char steamid[64];
						GetClientAuthId(param1, AuthId_Steam2, steamid, 64);						
						int score = Achivements_GetValue(steamid, "spentcredits");
						Achivements_SetValue(steamid, "spentcredits", score + g_priceArmor.IntValue);
					}
					else if (StrEqual(info, "deagle")) 
					{
						Item_Deagle(param1);
						WriteShopUsed(param1);
						credits = SetCredits(param1, credits - g_priceDeagle.IntValue);
						
						char steamid[64];
						GetClientAuthId(param1, AuthId_Steam2, steamid, 64);						
						int score = Achivements_GetValue(steamid, "spentcredits");
						Achivements_SetValue(steamid, "spentcredits", score + g_priceDeagle.IntValue);
					}
					else if (StrEqual(info, "protein"))
					{
						Item_Protein(param1);
						WriteShopUsed(param1);
						credits = SetCredits(param1, credits - g_priceProtein.IntValue);
						
						char steamid[64];
						GetClientAuthId(param1, AuthId_Steam2, steamid, 64);						
						int score = Achivements_GetValue(steamid, "spentcredits");
						Achivements_SetValue(steamid, "spentcredits", score + g_priceProtein.IntValue);
					}
					else if (StrEqual(info, "roulette"))
					{
						Roulette(param1);
						credits = SetCredits(param1, credits - 15);
						OpenShopMenu(param1, 0);
						
						char steamid[64];
						GetClientAuthId(param1, AuthId_Steam2, steamid, 64);						
						int score = Achivements_GetValue(steamid, "spentcredits");
						Achivements_SetValue(steamid, "spentcredits", score + 15);
					}
				}
				else
				{
					CGOPrintToChat(param1, "{GREEN}[Чёрный рынок]{DEFAULT} Прости, но я могу пронести тебе только одну вещь за день. Ты же не хочешь чтобы нас накрыли?");
				}				
			}
			else
			{
				CGOPrintToChat(param1, "{GREEN}[Чёрный рынок]{DEFAULT} Прости, я могу торговать только в первые 30 секунд раунда.");
			}
		}		
	}
	
	return 0;
}

int CTShopMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	int tokens;
	switch (action)
	{
		case MenuAction_DrawItem:
		{
			tokens = GetTokens(param1);
				
			int style;
			char info[32];
			menu.GetItem(param2, info, sizeof(info), style);

			if (StrEqual(info, "healthshot"))
			{
				if (tokens >= g_priceHealthCT.IntValue)
				{
					return style;
				}				
				else
				{
					return ITEMDRAW_DISABLED;
				}
			}
			else if (StrEqual(info, "tagrenade"))
			{
				if (tokens >= g_priceTacticalGrenade.IntValue)
				{
					return style;
				}				
				else
				{
					return ITEMDRAW_DISABLED;
				}
			}
			else if (StrEqual(info, "armor"))
			{
				if (tokens >= g_priceArmor.IntValue)
				{
					return style;
				}				
				else
				{
					return ITEMDRAW_DISABLED;
				}
			}
			else if (StrEqual(info, "awp"))
			{
				if (tokens >= g_priceAWP.IntValue)
				{
					return style;
				}				
				else
				{
					return ITEMDRAW_DISABLED;
				}
			}
			else if (StrEqual(info, "antiterror"))
			{
				if (tokens >= g_priceAntiterror.IntValue)
				{
					return style;
				}				
				else
				{
					return ITEMDRAW_DISABLED;
				}
			}
		}
		case MenuAction_Select:
		{
			tokens = GetTokens(param1);
			
			char info[32];
			menu.GetItem(param2, info, sizeof(info));			
			
			if (g_ShopAvaliable)
			{
				if (g_ShopUsed[param1] == 0)
				{
					if (StrEqual(info, "buy"))
					{
						tokens = GetTokens(param1);
						int credits = GetCredits(param1);
				
						Menu buyMenu = new Menu(BuyTokensMenuHandler, MENU_ACTIONS_ALL);
						char title[255];
						Format(title, 255, "Покупка жетонов | Баланс: %d сигарет, %d жетонов", credits, tokens);
						buyMenu.SetTitle(title);
							
						buyMenu.AddItem("1", "1 жетон (5 сигарет)");
						buyMenu.AddItem("10", "10 жетонов (50 сигарет)");
						buyMenu.AddItem("20", "20 жетонов (100 сигарет)");						
						buyMenu.AddItem("100", "100 жетонов (500 сигарет)");						
						buyMenu.AddItem("200", "200 жетонов (1000 сигарет)");						
						buyMenu.AddItem("2000", "2000 жетонов (10000 сигарет)");
							
						buyMenu.Display(param1, MENU_TIME_FOREVER);
					}
					else if (StrEqual(info, "healthshot"))
					{
						Item_HealthshotCT(param1);
						g_ShopUsed[param1]++;
						SetTokens(param1, tokens - g_priceHealthCT.IntValue);
						
						char steamid[64];
						GetClientAuthId(param1, AuthId_Steam2, steamid, 64);						
						int score = Achivements_GetValue(steamid, "spenttokens");
						Achivements_SetValue(steamid, "spenttokens", score + g_priceHealthCT.IntValue);
					}
					else if (StrEqual(info, "tagrenade"))
					{
						Item_TaGrenade(param1);
						g_ShopUsed[param1]++;
						SetTokens(param1, tokens - g_priceTacticalGrenade.IntValue);
						
						char steamid[64];
						GetClientAuthId(param1, AuthId_Steam2, steamid, 64);						
						int score = Achivements_GetValue(steamid, "spenttokens");
						Achivements_SetValue(steamid, "spenttokens", score + g_priceTacticalGrenade.IntValue);
					}
					else if (StrEqual(info, "armor"))
					{
						Item_ArmorCT(param1);
						g_ShopUsed[param1]++;
						SetTokens(param1, tokens - g_priceArmorCT.IntValue);
						
						char steamid[64];
						GetClientAuthId(param1, AuthId_Steam2, steamid, 64);						
						int score = Achivements_GetValue(steamid, "spenttokens");
						Achivements_SetValue(steamid, "spenttokens", score + g_priceArmorCT.IntValue);
					}
					else if (StrEqual(info, "awp"))
					{
						Item_Awp(param1);
						g_ShopUsed[param1]++;
						SetTokens(param1, tokens - g_priceAWP.IntValue);
						
						char steamid[64];
						GetClientAuthId(param1, AuthId_Steam2, steamid, 64);						
						int score = Achivements_GetValue(steamid, "spenttokens");
						Achivements_SetValue(steamid, "spenttokens", score + g_priceAWP.IntValue);
					}
					else if (StrEqual(info, "antiterror"))
					{
						Item_Antiterror(param1);
						g_ShopUsed[param1]++;						
						SetTokens(param1, tokens - g_priceAntiterror.IntValue);
						
						char steamid[64];
						GetClientAuthId(param1, AuthId_Steam2, steamid, 64);						
						int score = Achivements_GetValue(steamid, "spenttokens");
						Achivements_SetValue(steamid, "spenttokens", score + g_priceAntiterror.IntValue);
					}
				}
				else 
				{
					CGOPrintToChat(param1, "{GREEN}[Арсенал]{DEFAULT} Вы можете запрашивать лишь одну вещь за день.");
				}
			}
			else 
			{
				CGOPrintToChat(param1, "{GREEN}[Арсенал]{DEFAULT} Арсенал доступен только в первые 30 секунд раунда.");
			}
		}
	}
	
	return 0;
}

int BuyCreditsMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	int tokens;
	switch (action)
	{
		case MenuAction_DrawItem:
		{
			tokens = GetTokens(param1);
			
			int style;
			char info[32];
			menu.GetItem(param2, info, sizeof(info), style);			
			
			if (StrEqual(info, "5"))
			{
				if (tokens >= 1)
				{
					return style;
				}
				else 
				{
					return ITEMDRAW_DISABLED;
				}
			}
			else if (StrEqual(info, "50"))
			{
				if (tokens >= 10)
				{
					return style;
				}
				else 
				{
					return ITEMDRAW_DISABLED;
				}
			}
			else if (StrEqual(info, "100"))
			{
				if (tokens >= 20)
				{
					return style;
				}
				else 
				{
					return ITEMDRAW_DISABLED;
				}
			}
			else if (StrEqual(info, "500"))
			{
				if (tokens >= 100)
				{
					return style;
				}
				else 
				{
					return ITEMDRAW_DISABLED;
				}
			}
			else if (StrEqual(info, "1000"))
			{
				if (tokens >= 200)
				{
					return style;
				}
				else 
				{
					return ITEMDRAW_DISABLED;
				}
			}			
			else if (StrEqual(info, "10000"))
			{
				if (tokens >= 2000)
				{
					return style;
				}
				else 
				{
					return ITEMDRAW_DISABLED;
				}
			}
		}
		case MenuAction_Select:
		{
			tokens = GetTokens(param1);
			int credits = GetCredits(param1);
			
			char info[32];
			menu.GetItem(param2, info, sizeof(info));
			
			if (StrEqual(info, "5"))
			{
				credits = SetCredits(param1, credits + 5);
				tokens = SetTokens(param1, tokens - 1);
			}
			else if (StrEqual(info, "50"))
			{
				credits = SetCredits(param1, credits + 50);
				tokens = SetTokens(param1, tokens - 10);
			}
			else if (StrEqual(info, "100"))
			{
				credits = SetCredits(param1, credits + 100);
				tokens = SetTokens(param1, tokens - 20);
			}
			else if (StrEqual(info, "500"))
			{
				credits = SetCredits(param1, credits + 500);
				tokens = SetTokens(param1, tokens - 100);
			}
			else if (StrEqual(info, "1000"))
			{
				credits = SetCredits(param1, credits + 1000);
				tokens = SetTokens(param1, tokens - 200);
			}			
			else if (StrEqual(info, "10000"))
			{
				credits = SetCredits(param1, credits + 10000);
				tokens = SetTokens(param1, tokens - 2000);
			}
			
			Menu buyMenu = new Menu(BuyCreditsMenuHandler, MENU_ACTIONS_ALL);
			char title[255];
			Format(title, 255, "Покупка сигарет | Баланс: %d жетонов, %d сигарет", tokens, credits);
			buyMenu.SetTitle(title);
			
			buyMenu.AddItem("5", "5 сигарет (1 жетон)");
			buyMenu.AddItem("50", "50 сигарет (10 жетонов)");
			buyMenu.AddItem("100", "100 сигарет (20 жетонов)");						
			buyMenu.AddItem("500", "500 сигарет (100 жетонов)");						
			buyMenu.AddItem("1000", "1000 сигарет (200 жетонов)");						
			buyMenu.AddItem("10000", "10000 сигарет (2000 жетонов)");
			
			buyMenu.Display(param1, MENU_TIME_FOREVER);
		}
	
		case MenuAction_Cancel:
		{
			OpenShopMenu(param1, 0); 
		}
	}
	
	return 0;
}

int BuyTokensMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	int credits;
	switch (action)
	{
		case MenuAction_DrawItem:
		{
			credits = GetCredits(param1);
			
			int style;
			char info[32];
			menu.GetItem(param2, info, sizeof(info), style);			
			
			if (StrEqual(info, "1"))
			{
				if (credits >= 5)
				{
					return style;
				}
				else 
				{
					return ITEMDRAW_DISABLED;
				}
			}
			else if (StrEqual(info, "10"))
			{
				if (credits >= 50)
				{
					return style;
				}
				else 
				{
					return ITEMDRAW_DISABLED;
				}
			}
			else if (StrEqual(info, "20"))
			{
				if (credits >= 100)
				{
					return style;
				}
				else 
				{
					return ITEMDRAW_DISABLED;
				}
			}
			else if (StrEqual(info, "100"))
			{
				if (credits >= 500)
				{
					return style;
				}
				else 
				{
					return ITEMDRAW_DISABLED;
				}
			}
			else if (StrEqual(info, "200"))
			{
				if (credits >= 1000)
				{
					return style;
				}
				else 
				{
					return ITEMDRAW_DISABLED;
				}
			}			
			else if (StrEqual(info, "2000"))
			{
				if (credits >= 10000)
				{
					return style;
				}
				else 
				{
					return ITEMDRAW_DISABLED;
				}
			}
		}
		case MenuAction_Select:
		{
			int tokens = GetTokens(param1);
			credits = GetCredits(param1);
			
			char info[32];
			menu.GetItem(param2, info, sizeof(info));
			
			if (StrEqual(info, "1"))
			{
				credits = SetCredits(param1, credits - 5);
				tokens = SetTokens(param1, tokens + 1);
			}
			else if (StrEqual(info, "10"))
			{
				credits = SetCredits(param1, credits - 50);
				tokens = SetTokens(param1, tokens + 10);
			}
			else if (StrEqual(info, "20"))
			{
				credits = SetCredits(param1, credits - 100);
				tokens = SetTokens(param1, tokens + 20);
			}
			else if (StrEqual(info, "100"))
			{
				credits = SetCredits(param1, credits - 500);
				tokens = SetTokens(param1, tokens + 100);
			}
			else if (StrEqual(info, "200"))
			{
				credits = SetCredits(param1, credits - 1000);
				tokens = SetTokens(param1, tokens + 200);
			}			
			else if (StrEqual(info, "2000"))
			{
				credits = SetCredits(param1, credits - 10000);
				tokens = SetTokens(param1, tokens + 2000);
			}
			
			Menu buyMenu = new Menu(BuyTokensMenuHandler, MENU_ACTIONS_ALL);
			char title[255];
			Format(title, 255, "Покупка жетонов | Баланс: %d сигарет, %d жетонов", credits, tokens);
			buyMenu.SetTitle(title);
				
			buyMenu.AddItem("1", "1 жетон (5 сигарет)");
			buyMenu.AddItem("10", "10 жетонов (50 сигарет)");
			buyMenu.AddItem("20", "20 жетонов (100 сигарет)");						
			buyMenu.AddItem("100", "100 жетонов (500 сигарет)");						
			buyMenu.AddItem("200", "200 жетонов (1000 сигарет)");						
			buyMenu.AddItem("2000", "2000 жетонов (10000 сигарет)");
				
			buyMenu.Display(param1, MENU_TIME_FOREVER);
		}
	
		case MenuAction_Cancel:
		{
			OpenShopMenu(param1, 0); 
		}
	}
	
	return 0;
}

int pMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char info[32];
			menu.GetItem(param2, info, sizeof(info));
			
			int client = param1;
			if (StrEqual(info, "mp5"))
			{
				int weapon;
				if ((weapon = GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY)) != -1)
				{
					SDKHooks_DropWeapon(client, weapon, NULL_VECTOR, NULL_VECTOR);
					AcceptEntityInput(weapon, "Kill");
				}
				GivePlayerItem(client, "weapon_mp5sd");
			}
			else if (StrEqual(info, "m4a1"))
			{
				int weapon;
				if ((weapon = GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY)) != -1)
				{
					SDKHooks_DropWeapon(client, weapon, NULL_VECTOR, NULL_VECTOR);
					AcceptEntityInput(weapon, "Kill");
				}
				GivePlayerItem(client, "weapon_m4a1");
			}
			else if (StrEqual(info, "m4a1-s"))
			{
				int weapon;
				if ((weapon = GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY)) != -1)
				{
					SDKHooks_DropWeapon(client, weapon, NULL_VECTOR, NULL_VECTOR);
					AcceptEntityInput(weapon, "Kill");
				}
				GivePlayerItem(client, "weapon_m4a1_silencer");
			}
			else if (StrEqual(info, "xm1014"))
			{
				int weapon;
				if ((weapon = GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY)) != -1)
				{
					SDKHooks_DropWeapon(client, weapon, NULL_VECTOR, NULL_VECTOR);
					AcceptEntityInput(weapon, "Kill");
				}
				GivePlayerItem(client, "weapon_xm1014");
			}
			else if (StrEqual(info, "awp"))
			{
				int weapon;
				if ((weapon = GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY)) != -1)
				{
					SDKHooks_DropWeapon(client, weapon, NULL_VECTOR, NULL_VECTOR);
					AcceptEntityInput(weapon, "Kill");
				}
				GivePlayerItem(client, "weapon_awp");
			}
			else if (StrEqual(info, "m249"))
			{
				int weapon;
				if ((weapon = GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY)) != -1)
				{
					SDKHooks_DropWeapon(client, weapon, NULL_VECTOR, NULL_VECTOR);
					AcceptEntityInput(weapon, "Kill");
				}
				GivePlayerItem(client, "weapon_m249");
			}
			else if (StrEqual(info, "negev"))
			{
				int weapon;
				if ((weapon = GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY)) != -1)
				{
					SDKHooks_DropWeapon(client, weapon, NULL_VECTOR, NULL_VECTOR);
					AcceptEntityInput(weapon, "Kill");
				}
				GivePlayerItem(client, "weapon_negev");
			}
			
			//secondary weapons
			Menu s = new Menu(sMenuHandler, MENU_ACTIONS_ALL);
			s.SetTitle("Выбор оружия");
			s.Pagination = MENU_NO_PAGINATION;
			
			s.AddItem("usp", "USP-S");
			s.AddItem("p250", "P250");
			s.AddItem("tec", "Tec-9");
			s.AddItem("berettas", "Dual Berettas");
			s.AddItem("deagle", "Desert Eagle");
			s.AddItem("revolver", "R8 Revoler");
			s.AddItem("none", "Пропустить");
			
			s.Display(client, MENU_TIME_FOREVER);
		}
	}
}

int sMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char info[32];
			menu.GetItem(param2, info, sizeof(info));
			
			int client = param1;
			if (StrEqual(info, "usp"))
			{
				int weapon;
				if ((weapon = GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY)) != -1)
				{
					SDKHooks_DropWeapon(client, weapon, NULL_VECTOR, NULL_VECTOR);
					AcceptEntityInput(weapon, "Kill");
				}
				GivePlayerItem(client, "weapon_usp_silencer");
			}
			else if (StrEqual(info, "p250"))
			{
				int weapon;
				if ((weapon = GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY)) != -1)
				{
					SDKHooks_DropWeapon(client, weapon, NULL_VECTOR, NULL_VECTOR);
					AcceptEntityInput(weapon, "Kill");
				}
				GivePlayerItem(client, "weapon_p250");
			}
			else if (StrEqual(info, "tec"))
			{
				int weapon;
				if ((weapon = GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY)) != -1)
				{
					SDKHooks_DropWeapon(client, weapon, NULL_VECTOR, NULL_VECTOR);
					AcceptEntityInput(weapon, "Kill");
				}
				GivePlayerItem(client, "weapon_tec9");
			}
			else if (StrEqual(info, "berettas"))
			{
				int weapon;
				if ((weapon = GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY)) != -1)
				{
					SDKHooks_DropWeapon(client, weapon, NULL_VECTOR, NULL_VECTOR);
					AcceptEntityInput(weapon, "Kill");
				}
				GivePlayerItem(client, "weapon_elite");
			}
			else if (StrEqual(info, "deagle"))
			{
				int weapon;
				if ((weapon = GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY)) != -1)
				{
					SDKHooks_DropWeapon(client, weapon, NULL_VECTOR, NULL_VECTOR);
					AcceptEntityInput(weapon, "Kill");
				}
				GivePlayerItem(client, "weapon_deagle");
			}
			else if (StrEqual(info, "revolver"))
			{
				int weapon;
				if ((weapon = GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY)) != -1)
				{
					SDKHooks_DropWeapon(client, weapon, NULL_VECTOR, NULL_VECTOR);
					AcceptEntityInput(weapon, "Kill");
				}
				GivePlayerItem(client, "weapon_revolver");
			}
		
			Menu g = new Menu(gMenuHandler, MENU_ACTIONS_ALL);
			g.SetTitle("Выбор гранаты");
			g.Pagination = MENU_NO_PAGINATION;
			
			g.AddItem("he_fire", "Наступательная + зажигательная");
			g.AddItem("he_smoke", "Наступательная + дымовая");
			g.AddItem("flash_smoke", "Световая + дымовая");
			g.AddItem("flash_fire", "Световая + зажигательная");
			
			g.Display(client, MENU_TIME_FOREVER);
		}
	}
}

int gMenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch (action)
	{
		case MenuAction_Select:
		{
			char info[32];
			menu.GetItem(param2, info, sizeof(info));
			
			int client = param1;
			if (StrEqual(info, "he_fire"))
			{
				GivePlayerItem(client, "weapon_hegrenade");
				GivePlayerItem(client, "weapon_incgrenade");
			}
			else if (StrEqual(info, "he_smoke"))
			{				
				GivePlayerItem(client, "weapon_hegrenade");
				GivePlayerItem(client, "weapon_smokegrenade");
			}			
			else if (StrEqual(info, "flash_smoke"))
			{				
				GivePlayerItem(client, "weapon_flashbang");
				GivePlayerItem(client, "weapon_smokegrenade");
			}			
			else if (StrEqual(info, "flash_fire"))
			{
				GivePlayerItem(client, "weapon_flashbang");
				GivePlayerItem(client, "weapon_incgrenade");
			}			
		}		
	}
}

/* ТЕХНИЧЕСКИЕ ФУНКЦИИ */

int GetTokens(int client)
{
	int tokens;
	
	char error[255];
	Database db = SQL_DefConnect(error, sizeof(error));
		    
	if (db == null)
	{
	  	PrintToServer("Could not connect: %s", error);
	} 
	else 
	{
	   	char steamid[64];
	   	GetClientAuthId(client, AuthId_SteamID64, steamid, 64);
	    	
	   	char query_text[512]; 
	   	Format(query_text, 512, "SELECT `tokens` FROM `jbs_accounts` WHERE `steamid` = '%s'", steamid);
	   	DBResultSet query = SQL_Query(db, query_text);
		    	
	   	if (query == null)
	   	{
	   		tokens = 0;
	   	} 
	   	else 
	   	{
	   		while (SQL_FetchRow(query))
	  		{						
	   			tokens = SQL_FetchInt(query, 0);
	   		} 
	   		
	   		delete query;
	   	}	
		delete db;
	}
	
	return tokens;
}

int SetTokens(int client, int amount)
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
	   	GetClientAuthId(client, AuthId_SteamID64, steamid, 64);
	    	
	   	char query_text[512]; 
	   	Format(query_text, 512, "UPDATE `jbs_accounts` SET `tokens` = '%d' WHERE `jbs_accounts`.`steamid` = '%s';", amount, steamid);
		
	   	if (!SQL_FastQuery(db, query_text))
		{			
			SQL_GetError(db, error, sizeof(error));
			PrintToServer("Failed to query (error: %s)", error);
		}
		delete db;
	}
	
	return amount;
}

int GetCredits(int client)
{
	int credits;
	
	char error[255];
	Database db = SQL_DefConnect(error, sizeof(error));
		    
	if (db == null)
	{
	  	PrintToServer("Could not connect: %s", error);
	} 
	else 
	{
	   	char steamid[64];
	   	GetClientAuthId(client, AuthId_SteamID64, steamid, 64);
	    	
	   	char query_text[512]; 
	   	Format(query_text, 512, "SELECT `balance` FROM `jbs_accounts` WHERE `steamid` = '%s'", steamid);
	   	DBResultSet query = SQL_Query(db, query_text);
		    	
	   	if (query == null)
	   	{
	   		credits = 0;
	   	} 
	   	else 
	   	{
	   		while (SQL_FetchRow(query))
	  		{						
	   			credits = SQL_FetchInt(query, 0);
	   		} 
	   		
	   		delete query;
	   	}	
		delete db;
	}
	
	return credits;
}

int SetCredits(int client, int amount)
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
	   	GetClientAuthId(client, AuthId_SteamID64, steamid, 64);
	    	
	   	char query_text[512]; 
	   	Format(query_text, 512, "UPDATE `jbs_accounts` SET `balance` = '%d' WHERE `jbs_accounts`.`steamid` = '%s';", amount, steamid);
		
	   	if (!SQL_FastQuery(db, query_text))
		{
			SQL_GetError(db, error, sizeof(error));
			PrintToServer("Failed to query (error: %s)", error);
		}
		delete db;
	}
	
	return amount;
}

void WriteShopUsed(int client)
{
	g_ShopUsed[client] = 1;
}

/* ХУКИ ДЛЯ ТАЙМЕРОВ */

Action BlockShop(Handle timer)
{
	g_ShopAvaliable = false;
}

/* ТОВАРЫ МАГАЗИНА */

void Item_Smoke(int client)
{
	GivePlayerItem(client, "weapon_smokegrenade");
	CGOPrintToChatAll("{GREEN}[Чёрный рынок]{DEFAULT} Кому-то пронесли дымовую шашку.");
}

void Item_Flashbang(int client)
{
	GivePlayerItem(client, "weapon_flashbang");
	CGOPrintToChatAll("{GREEN}[Чёрный рынок]{DEFAULT} Кому-то пронесли световую гранату.");
}

void Item_Healthshot(int client)
{
	GivePlayerItem(client, "weapon_healthshot");
	CGOPrintToChatAll("{GREEN}[Чёрный рынок]{DEFAULT} Кому-то пронесли аптечку.");
}

void Item_Armor(int client)
{
	SetEntProp(client, Prop_Data, "m_ArmorValue", 100, 1);
	CGOPrintToChatAll("{GREEN}[Чёрный рынок]{DEFAULT} Кому-то пронесли броню.");
}

void Item_Deagle(int client)
{	
	int weapon;
	if ((weapon = GetPlayerWeaponSlot(client, CS_SLOT_SECONDARY)) != -1) 
	{
		SDKHooks_DropWeapon(client, weapon, NULL_VECTOR, NULL_VECTOR);
		AcceptEntityInput(weapon, "Kill");
	}
	int iDeagle = GivePlayerItem(client, "weapon_deagle");
	SetEntProp(iDeagle, Prop_Send, "m_iPrimaryReserveAmmoCount", 7);

	CGOPrintToChatAll("{GREEN}[Чёрный рынок]{DEFAULT} Кому-то пронесли пистолет.");
	
	char steamid[64];
	GetClientAuthId(client, AuthId_Steam2, steamid, 64);
	
	int score = Achivements_GetValue(steamid, "deagle");
	if (score < 0)
	{
		LogError("Errored while getting deagle score for %s. Error code: %d", steamid, score);
		return;
	}
	
	int result = Achivements_SetValue(steamid, "deagle", score + 1);
	if (result < 0)
	{
		LogError("Errored while setting deagle score for %s. Error code: %d", steamid, result);
		return;
	}
}

void Item_Protein(int client)
{
	SetEntityHealth(client, 500);
	CGOPrintToChatAll("{GREEN}[Чёрный рынок]{DEFAULT} Кому-то пронесли протеин.");
	
	char steamid[64];
	GetClientAuthId(client, AuthId_Steam2, steamid, 64);
	
	int score = Achivements_GetValue(steamid, "protein");
	if (score < 0)
	{
		LogError("Errored while getting protein score for %s. Error code: %d", steamid, score);
		return;
	}
	
	int result = Achivements_SetValue(steamid, "protein", score + 1);
	if (result < 0)
	{
		LogError("Errored while setting protein score for %s. Error code: %d", steamid, result);
		return;
	}
}

void Roulette(int client)
{	
	if (!g_RouletteUsed[client])
	{	
		int random = GetRandomInt(1, 10000);
		if (random >= 1 && random < 10) //0,09%
		{
			GivePlayerItem(client, "weapon_negev");
			CGOPrintToChat(client, "{GREEN}Поздравляем!{DEFAULT} Вы выиграли пулемёт!{DEFAULT}");
			
		}
		if (random >= 10 && random < 900)  //8,1%
		{
			GivePlayerItem(client, "weapon_smokegrenade");
			CGOPrintToChat(client, "{GREEN}Поздравляем! Вы выиграли дымовую гранату!{DEFAULT}");
		}
		if (random >= 900 && random < 2000) //11%
		{
			GivePlayerItem(client, "weapon_flashbang");
			CGOPrintToChat(client, "{GREEN}Поздравляем! Вы выиграли световую гранату!{DEFAULT}");
		}
		if (random >= 2000 && random < 5000) //30%
		{
			GivePlayerItem(client, "weapon_healthshot");
			CGOPrintToChat(client, "{GREEN}Медицинский шприц!{DEFAULT}");
		}
		if (random >= 5000 && random < 10000) //50%
		{
			CGOPrintToChat(client, "{GREEN}К сожалению, вы ничего не выиграли{DEFAULT}");
		}
		g_RouletteUsed[client] = true;
	}
	else
	{
		CGOPrintToChat(client, "{GREEN} Вы не можете играть в рулетку второй раз, но сигареты мы у вас забрали. {DEFAULT}");
	}
}

void Item_HealthshotCT(int client)
{
	GivePlayerItem(client, "weapon_healthshot");
	CGOPrintToChatAll("{GREEN}[Арсенал]{DEFAULT} Охрана запросила медикаменты.");
}

void Item_TaGrenade(int client)
{
	GivePlayerItem(client, "weapon_tagrenade");	
	CGOPrintToChatAll("{GREEN}[Арсенал]{DEFAULT} Охрана запросила тактическую гранату.");
}

void Item_ArmorCT(int client)
{
	SetEntProp(client, Prop_Data, "m_ArmorValue", 150, 1);
	CGOPrintToChatAll("{GREEN}[Арсенал]{DEFAULT} Охрана запросила броню.");
}

void Item_Awp(int client)
{
	int weapon;
	if ((weapon = GetPlayerWeaponSlot(client, CS_SLOT_PRIMARY)) != -1)
	{
		SDKHooks_DropWeapon(client, weapon, NULL_VECTOR, NULL_VECTOR);
		AcceptEntityInput(weapon, "Kill");
	}
	GivePlayerItem(client, "weapon_awp");	
	CGOPrintToChatAll("{GREEN}[Арсенал]{DEFAULT} Охрана запросила снайперскую винтовку.");
}

void Item_Antiterror(int client)
{
	SetEntityHealth(client, 300);	
	SetEntProp(client, Prop_Data, "m_ArmorValue", 250, 1);
	if (!JWP_IsWarden(client))
	{
		SetEntityModel(client, "models/player/custom_player/darnias/gign.mdl");
		SetEntPropString(client, Prop_Send, "m_szArmsModel", "models/player/custom_player/kuristaja/jailbreak/guard3/guard3_arms.mdl");
	}
	CGOPrintToChatAll("{GREEN}[Арсенал]{DEFAULT} Охрана запросила антитеррористический набор.");
	
	//primary weapons
	Menu p = new Menu(pMenuHandler, MENU_ACTIONS_ALL);
	p.SetTitle("Выбор оружия");
	p.Pagination = MENU_NO_PAGINATION;
	
	p.AddItem("mp5", "MP5-SD");
	p.AddItem("m4a1", "M4A1");
	p.AddItem("m4a1-s", "M4A1-S");
	p.AddItem("xm1014", "XM1014");
	p.AddItem("awp", "AWP");
	p.AddItem("m249", "M249");
	p.AddItem("negev", "Negev");
	p.AddItem("none", "Пропустить");
	
	p.Display(client, MENU_TIME_FOREVER);	
}

