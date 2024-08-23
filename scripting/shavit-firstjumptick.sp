#include <sourcemod>
#include <sdktools>
#include <clientprefs>

// Including the 'shavit' library for timer-related functions
#undef REQUIRE_PLUGIN
#include <shavit>

#pragma newdecls required
#pragma semicolon 1

// Handles for storing client preferences (cookies)
Handle gH_FirstJumpTickCookie;
Handle gH_CookieSet;

// Array to track whether jump tick printing is enabled for each player
bool gB_FirstJumpTick[MAXPLAYERS + 1];

// Plugin metadata
public Plugin myinfo =
{
	name = "[shavit] First Jump Tick",
	author = "Blank & Nairda",
	description = "Prints the tick at which the very first jump occurred after leaving the start zone",
	version = "2.0",
	url = ""
};

// Struct for storing custom chat messages
chatstrings_t gS_ChatStrings;

// Called when the plugin starts
public void OnPluginStart()
{
	// Load translations for chat messages
	LoadTranslations("shavit-firstjumptick.phrases");

	// Register console commands for toggling the feature
	RegConsoleCmd("sm_fjt", Command_FirstJumpTick, "Toggles Jump Tick Printing");
	RegConsoleCmd("sm_jumptick", Command_FirstJumpTick, "Toggles Jump Tick Printing");
	RegConsoleCmd("sm_tick", Command_FirstJumpTick, "Toggles Jump Tick Printing");
	RegConsoleCmd("sm_jt", Command_FirstJumpTick, "Toggles Jump Tick Printing");

	// Register cookies to save player preferences
	gH_FirstJumpTickCookie = RegClientCookie("FJT_enabled", "FJT_enabled", CookieAccess_Protected);
	gH_CookieSet = RegClientCookie("FJT_default", "FJT_default", CookieAccess_Protected);

	// Initialize player settings if their cookies are already cached
	for (int i = 1; i <= MaxClients; i++)
	{
		if (AreClientCookiesCached(i))
		{
			OnClientCookiesCached(i);
		}
	}

	// Hook into the player_jump event to detect when... a player jumps :O
	HookEvent("player_jump", OnPlayerJump);
}

// Toggles the jump tick printing feature for the player
public Action Command_FirstJumpTick(int client, int args)
{
	// Toggle the feature on or off
	gB_FirstJumpTick[client] = !gB_FirstJumpTick[client];

	// Save the new setting in a cookie
	SetCookie(client, gH_FirstJumpTickCookie, gB_FirstJumpTick[client]);

	// Choose the appropriate action message to display in their game chat
	char action[32];
	Format(action, sizeof(action), gB_FirstJumpTick[client] ? "FirstJumpTickEnabled" : "FirstJumpTickDisabled");

	// Notify the player of the change
	Shavit_PrintToChat(client, "%T", action, client, gS_ChatStrings.sVariable);

	return Plugin_Handled;
}

// Initializes the player's settings based on their cookies
public void OnClientCookiesCached(int client)
{
	char sCookie[2];

	// Get the client's default setting
	GetClientCookie(client, gH_CookieSet, sCookie, sizeof(sCookie));

	// If no default is set, enable the feature and set a default value
	if (StringToInt(sCookie) == 0)
	{
		SetCookie(client, gH_FirstJumpTickCookie, true); // Enable the feature by default
		SetCookie(client, gH_CookieSet, true); // Mark the default as set
	}

	// Get the current setting and apply it
	GetClientCookie(client, gH_FirstJumpTickCookie, sCookie, sizeof(sCookie));
	gB_FirstJumpTick[client] = view_as<bool>(StringToInt(sCookie));
}

// Handles the player_jump event
public Action OnPlayerJump(Event event, char[] name, bool dontBroadcast)
{
	// Get the client who triggered the event
	int client = GetClientOfUserId(event.GetInt("userid"));

	// Validate the client
	if (!IsValidClient(client))
		return Plugin_Continue;

	// Get the target player (self or observed player)
	int target = GetHUDTarget(client);

	// Print the jump tick if applicable
	PrintJumpTick(client, target);

	return Plugin_Continue;
}

// Determines which player the client is observing, if any
int GetHUDTarget(int client)
{
	// If client is invalid, return the client itself
	if (!IsValidClient(client))
		return client;

	// Get the client's observer mode (spectator mode)
	int iObserverMode = GetEntProp(client, Prop_Send, "m_iObserverMode");

	// If the client is observing someone, return the target player
	if (iObserverMode >= 3 && iObserverMode <= 5)
	{
		int iTarget = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");

		if (IsValidClientIndex(iTarget))
			return iTarget;
	}

	// Otherwise, return the client itself
	return client;
}

// Prints the jump tick information to the client, if conditions are met
void PrintJumpTick(int client, int target)
{
	// Only print if the feature is enabled for the client
	if (!gB_FirstJumpTick[client])
		return;

	// Check conditions: inside start zone, timer running, and it's the first jump
	bool isInsideZone = Shavit_InsideZone(target, Zone_Start, -1);
	bool isTimerRunning = Shavit_GetTimerStatus(target) == Timer_Running;
	bool isFirstJump = Shavit_GetClientJumps(target) == 1;

	// Print the appropriate message based on the player's state
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

// Helper function to save an integer value as a cookie for a client
stock void SetCookie(int client, Handle hCookie, int n)
{
	char sCookie[64];

	IntToString(n, sCookie, sizeof(sCookie));
	SetClientCookie(client, hCookie, sCookie);
}

// Checks if a client index is valid, because fuck Volvo™
stock bool IsValidClientIndex(int client)
{
	return (client > 0 && client <= MaxClients);
}
