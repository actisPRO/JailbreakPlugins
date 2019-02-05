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

#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo = {
	name        = "JailBreak Shop",
	author      = "Actis",
	description = "Shop for JailBreak",
	version     = "1.1.0",
	url         = "CS-JB.RU"
};

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
ConVar g_killRebelMoney;

int g_ShopUsed[MAXPLAYERS+1];
bool g_RouletteUsed[MAXPLAYERS+1];
Handle g_Timer;
bool g_ShopAvaliable;

public void OnPluginStart()
{
	RegConsoleCmd("sm_shop", OpenShopMenu);
	RegConsoleCmd("sm_store", OpenShopMenu);
	RegConsoleCmd("sm_smoke", Smoke);
	RegConsoleCmd("sm_balance", CheckBalance);
	RegConsoleCmd("sm_transfer", Transfer);
	
	g_priceSmoke = CreateConVar("jbs_price_smoke", "50", "Sets smoke price");
	g_priceFlash = CreateConVar("jbs_price_flashbang", "100", "Sets flashbang price");
	g_priceHealth = CreateConVar("jbs_price_healthshot", "150", "Sets healthshot price");
	g_priceArmor = CreateConVar("jbs_price_armor", "200", "Sets armor price");
	g_priceDeagle = CreateConVar("jbs_price_deagle", "500", "Sets deagle price");
	g_priceProtein = CreateConVar("jbs_price_protein", "1500", "Sets protein price");
	g_startMoney = CreateConVar("jbs_start_money", "300", "Player receives this amount of money, when he joins the server first time");
	g_roundEndMoney = CreateConVar("jbs_round_end_money", "5", "Each (dead, alive, ct, t, but not spectators) receives this amount of money, when round ends");
	g_roundWinMoney = CreateConVar("jbs_round_win_money", "5", "Each alive member of winner team gets this amount of money");
	g_killCtMoney = CreateConVar("jbs_kill_ct_money", "1", "CT killer gets this amount of money");
	g_killRebelMoney = CreateConVar("jbs_kill_rebel_money", "1", "Rebel killer gets this amount of money");	
	
	HookEvent("round_start", Event_RoundStart);
	HookEvent("round_end", Event_RoundEnd);
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("player_death", Event_PlayerDeath);
	
	AutoExecConfig(true, "jail_shop");
}

public Action CheckBalance(int client, int args)
{
	char buffer[255];
	Format(buffer, 255, "{GREEN}[Чёрный рынок]{DEFAULT} Ваши сигареты: {GREEN}%d{DEFAULT}.", Shop_GetCredits(client));
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
	int credits = Shop_GetCredits(client);
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
	
	Shop_SetCredits(client, credits - cash);
	Shop_SetCredits(target, Shop_GetCredits(target) + cash);
	
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
	
	int credits = Shop_GetCredits(client);
	SetEntityHealth(client, GetClientHealth(client) - 1);
	credits = Shop_SetCredits(client, credits - 1);
	
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
		credits = Shop_SetCredits(client, credits + 1000);
	}
	else
	{
		CGOPrintToChat(client, "{GREEN}Вы скурили сигаретку.{DEFAULT}");
	}	
}

public Action OpenShopMenu(int client, int args)
{
	if (IsPlayerAlive(client)) 
	{
		if (GetClientTeam(client) == CS_TEAM_T || GetClientTeam(client) == CS_TEAM_CT)
		{
			int credits = Shop_GetCredits(client);
			
			Menu menu = new Menu(ShopMenuHandler, MENU_ACTIONS_ALL);
			
			char title[255];
			Format(title, 255, "Чёрный рынок | Баланс: %d", credits);
			menu.SetTitle(title);
			
			char buffer[255];			
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
			
			if (GetClientTeam(client) == CS_TEAM_T)
			{
				menu.AddItem("roulette", "Рулетка (15 сигарет)");
			}			
		
			menu.Display(client, MENU_TIME_FOREVER);					
		}
		else
		{
			CGOPrintToChat(client, "{GREEN}[Чёрный рынок]{DEFAULT} Магазин доступен только игрокам.");
		}
	}
	else
	{
		CGOPrintToChat(client, "{GREEN}[Чёрный рынок]{DEFAULT} Вы должны быть живы, чтобы воспользоваться услугами черного рынка.");
	}
	
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
			Shop_SetCredits(killer, Shop_GetCredits(killer) + g_killCtMoney.IntValue);
			char buffer[255];
			Format(buffer, 255, "{GREEN}[Чёрный рынок]{DEFAULT} Вы получаете %d сигарету за убийство КТ!", g_killCtMoney.IntValue);
			CGOPrintToChat(killer, buffer);								
		}
		else if (GetClientTeam(killer) == CS_TEAM_CT && IsClientRebel(killed))
		{
			Shop_SetCredits(killer, Shop_GetCredits(killer) + g_killRebelMoney.IntValue);
			char buffer[255];
			Format(buffer, 255, "{GREEN}[Чёрный рынок]{DEFAULT} Вы получаете %d сигарету за убийство бунтующего заключенного!", g_killRebelMoney.IntValue);
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
				Shop_SetCredits(i, Shop_GetCredits(i) + g_roundEndMoney.IntValue);
				char buffer[255];
				Format(buffer, 255, "{GREEN}[Чёрный рынок]{DEFAULT} Вы получаете %d сигарет за окончание раунда.", g_roundEndMoney.IntValue);
				CGOPrintToChat(i, buffer);
			}
			
			if (GetClientTeam(i) == event.GetInt("winner") && IsPlayerAlive(i))
			{
				Shop_SetCredits(i, Shop_GetCredits(i) + g_roundWinMoney.IntValue);
				char buffer[255];
				Format(buffer, 255, "{GREEN}[Чёрный рынок]{DEFAULT} И дополнительно %d сигарет за победу!", g_roundWinMoney.IntValue);
				CGOPrintToChat(i, buffer);
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
				Format(buffer, 255, "INSERT INTO `jbs_accounts` (`steamid`, `balance`) VALUES ('%s', '%d');", steamid, g_startMoney.IntValue);
				if (!SQL_FastQuery(db, buffer))
				{
					char error[255];
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

public int ShopMenuHandler(Menu menu, MenuAction action, int param1, int param2) 
{		
	int credits;
	switch (action)
	{
		case MenuAction_DrawItem:
		{
			credits = Shop_GetCredits(param1);
			
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
			credits = Shop_GetCredits(param1);
			
			char info[32];
			menu.GetItem(param2, info, sizeof(info));			
			
			if (g_ShopAvaliable)
			{
				if (g_ShopUsed[param1] == 0)
				{
					if (StrEqual(info, "smoke"))
					{
						Item_Smoke(param1);				
						WriteShopUsed(param1);
						credits = Shop_SetCredits(param1, credits - g_priceSmoke.IntValue);
					}
					else if (StrEqual(info, "flashbang"))
					{
						Item_Flashbang(param1);
						WriteShopUsed(param1);
						credits = Shop_SetCredits(param1, credits - g_priceFlash.IntValue);
					}
					else if (StrEqual(info, "healthshot"))
					{
						Item_Healthshot(param1);
						WriteShopUsed(param1);
						credits = Shop_SetCredits(param1, credits - g_priceHealth.IntValue);
					}
					else if (StrEqual(info, "armor"))
					{
						Item_Armor(param1);
						WriteShopUsed(param1);
						credits = Shop_SetCredits(param1, credits - g_priceArmor.IntValue);
					}
					else if (StrEqual(info, "deagle")) 
					{
						Item_Deagle(param1);
						WriteShopUsed(param1);
						credits = Shop_SetCredits(param1, credits - g_priceDeagle.IntValue);
					}
					else if (StrEqual(info, "protein"))
					{
						Item_Protein(param1);
						WriteShopUsed(param1);
						credits = Shop_SetCredits(param1, credits - g_priceProtein.IntValue);
					}
					else if (StrEqual(info, "roulette"))
					{
						Roulette(param1);
						WriteShopUsed(param1);
						credits = Shop_SetCredits(param1, credits - 15);
						OpenShopMenu(param1, 0);
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
}

int Shop_GetCredits(int client)
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

int Shop_SetCredits(int client, int amount)
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
			char error[255];
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

Action BlockShop(Handle timer)
{
	g_ShopAvaliable = false;
}

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
}

void Item_Protein(int client)
{
	SetEntityHealth(client, 500);
	CGOPrintToChatAll("{GREEN}[Чёрный рынок]{DEFAULT} Кому-то пронесли протеин.");
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