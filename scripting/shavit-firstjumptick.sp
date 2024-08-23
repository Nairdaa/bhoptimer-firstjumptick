#include <sourcemod>
#include <sdktools>
#include <clientprefs>
 
#undef REQUIRE_PLUGIN
#include <shavit>
 
#pragma newdecls required
#pragma semicolon 1

Handle gH_FirstJumpTickCookie;
Handle gH_CookieSet;

bool gB_FirstJumpTick[MAXPLAYERS+1];

public Plugin myinfo =
{
	name = "[shavit] First Jump Tick",
	author = "Blank & Fixed by Nairda",
	description = "Print which tick first jump was at",
	version = "1.1e",
	url = ""
}

chatstrings_t gS_ChatStrings;

public void OnPluginStart()
{
	LoadTranslations("shavit-firstjumptick.phrases");

	RegConsoleCmd("sm_fjt", Command_FirstJumpTick, "Toggles Jump Tick Printing");
	RegConsoleCmd("sm_jumptick", Command_FirstJumpTick, "Toggles Jump Tick Printing");
	RegConsoleCmd("sm_tick", Command_FirstJumpTick, "Toggles Jump Tick Printing");
	RegConsoleCmd("sm_jt", Command_FirstJumpTick, "Toggles Jump Tick Printing");

	gH_FirstJumpTickCookie = RegClientCookie("FJT_enabled", "FJT_enabled", CookieAccess_Protected);
	gH_CookieSet = RegClientCookie("FJT_default", "FJT_default", CookieAccess_Protected);

	for (int i = 1; i <= MaxClients; i++)
	{
		if (AreClientCookiesCached(i))
		{
			OnClientCookiesCached(i);
		}
	}

	HookEvent("player_jump", OnPlayerJump);
}

public Action Command_FirstJumpTick(int client, int args)
{
	gB_FirstJumpTick[client] = !gB_FirstJumpTick[client];
	SetCookie(client, gH_FirstJumpTickCookie, gB_FirstJumpTick[client]);

	char action[32];
	Format(action, sizeof(action), gB_FirstJumpTick[client] ? "FirstJumpTickEnabled" : "FirstJumpTickDisabled");
	Shavit_PrintToChat(client, "%T", action, client, gS_ChatStrings.sVariable);
	
	return Plugin_Handled;
}

public void OnClientCookiesCached(int client)
{
	char sCookie[8];
	GetClientCookie(client, gH_CookieSet, sCookie, sizeof(sCookie));

	if (StringToInt(sCookie) == 0)
	{
		SetCookie(client, gH_FirstJumpTickCookie, false);
		SetCookie(client, gH_CookieSet, true);
	}

	GetClientCookie(client, gH_FirstJumpTickCookie, sCookie, sizeof(sCookie));
	gB_FirstJumpTick[client] = view_as<bool>(StringToInt(sCookie));
}

public Action OnPlayerJump(Event event, char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));

	if (!IsValidClient(client))
		return Plugin_Continue;
	
	int target = GetHUDTarget(client);
	
	PrintJumpTick(client, target);

	return Plugin_Continue;
}

int GetHUDTarget(int client)
{
	if (!IsValidClient(client)) 
		return client;

	int iObserverMode = GetEntProp(client, Prop_Send, "m_iObserverMode");

	if (iObserverMode >= 3 && iObserverMode <= 5) 
	{
		int iTarget = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");

		if (IsValidClientIndex(iTarget)) 
			return iTarget;
	}

	return client;
}

void PrintJumpTick(int client, int target)
{  
	if (!gB_FirstJumpTick[client]) 
		return;

	bool isInsideZone = Shavit_InsideZone(target, Zone_Start, -1);
	bool isTimerRunning = Shavit_GetTimerStatus(target) == Timer_Running;
	bool isFirstJump = Shavit_GetClientJumps(target) == 1;

	if (isInsideZone) 
	{
		Shavit_PrintToChat(client, "%T", "ZeroTick", client, gS_ChatStrings.sVariable, gS_ChatStrings.sText);
	} 
	else if (isTimerRunning && isFirstJump) 
	{
		float clientTime = Shavit_GetClientTime(target) * 100;
		Shavit_PrintToChat(client, "%T", "PrintFirstJumpTick", client, gS_ChatStrings.sVariable, RoundToFloor(clientTime), gS_ChatStrings.sText);
	}
}

stock void SetCookie(int client, Handle hCookie, int n)
{
	char sCookie[64];

	IntToString(n, sCookie, sizeof(sCookie));
	SetClientCookie(client, hCookie, sCookie);
}

// We don't want the -1 client id bug. Thank Volvo™ for this
stock bool IsValidClientIndex(int client)
{
	return (client > 0 && client <= MaxClients);
}
