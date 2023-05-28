#pragma semicolon 1
#pragma newdecls required
#include <sourcemod>
#include <dhooks>

#define PLUGIN_NAME				"L4D2 Multiple Players"
#define PLUGIN_AUTHOR			"Lyseria Editor"
#define PLUGIN_DESCRIPTION		"Edit for me"
#define PLUGIN_VERSION			"1.5"
#define PLUGIN_URL				"Somewhere in alliedmodders"

#define GAMEDATA 				"l4d2_multiple_players"
#define CVAR_FLAGS 				FCVAR_NOTIFY
#define MAX_SLOT				5
#define TEAM_NOTEAM				0
#define TEAM_SPECTATOR			1
#define TEAM_SURVIVOR			2
#define TEAM_INFECTED   		3
#define JOIN_MANUAL				(1 << 0)
#define JOIN_AUTOMATIC			(1 << 1)
#define SOUND_SPECMENU			"ui/beep22.wav"

Handle
	g_hBotsTimer,
	g_hSDK_NextBotCreatePlayerBot_SurvivorBot,
	g_hSDK_CTerrorPlayer_RoundRespawn,
	g_hSDK_CCSPlayer_State_Transition,
	g_hSDK_SurvivorBot_SetHumanSpectator,
	g_hSDK_CTerrorPlayer_TakeOverBot,
	g_hSDK_CDirector_IsInTransition;

StringMap
	g_smSteamIDs;

ArrayList
	g_aMeleeScripts;

Address
	g_pDirector,
	g_pStatsCondition,
	g_pSavedSurvivorBotsCount;

ConVar
	g_cBotLimit,
	g_cJoinLimit,
	g_cJoinFlags,
	g_cJoinRespawn,
	g_cSpecNotify,
	g_cGiveType,
	g_cGiveTime,
	g_cSurLimit;

int
	g_iSurvivorBot,
	g_iBotLimit,
	g_iJoinLimit,
	g_iJoinFlags,
	g_iSpecNotify,
	m_hWeaponHandle,
	m_iRestoreAmmo,
	m_restoreWeaponID,
	m_hHiddenWeapon,
	m_isOutOfCheckpoint,
	RestartScenarioTimer;

bool
	g_bLateLoad,
	g_bJoinRespawn,
	g_bGiveType,
	g_bGiveTime,
	g_bInSpawnTime,
	g_bRoundStart,
	g_bShouldFixAFK,
	g_bShouldIgnore,
	g_bBlockUserMsg;

enum struct Weapon {
	ConVar Flags;

	int Count;
	int Allowed[20];
}

Weapon
	g_eWeapon[MAX_SLOT];

enum struct Player {
	int Bot;
	int Player;

	bool Notify;

	char Model[128];
	char AuthId[32];
}

Player
	g_ePlayer[MAXPLAYERS + 1];

static const char
	g_sSurvivorNames[][] = {
		"Nick",
		"Rochelle",
		"Coach",
		"Ellis",
		"Bill",
		"Zoey",
		"Francis",
		"Louis"
	},
	g_sSurvivorModels[][] = {
		"models/survivors/survivor_gambler.mdl",
		"models/survivors/survivor_producer.mdl",
		"models/survivors/survivor_coach.mdl",
		"models/survivors/survivor_mechanic.mdl",
		"models/survivors/survivor_namvet.mdl",
		"models/survivors/survivor_teenangst.mdl",
		"models/survivors/survivor_biker.mdl",
		"models/survivors/survivor_manager.mdl"
	},
	g_sWeaponName[MAX_SLOT][][] = {
		{//slot 0(Main Weapon)
			"weapon_smg",						//1 Uzi smg
			"weapon_smg_mp5",					//2 MP5 
			"weapon_smg_silenced",				//4 Silenced smg
			"weapon_pumpshotgun",				//8 Pumpshotgun
			"weapon_shotgun_chrome",			//16 ShotgunChrome
			"weapon_rifle",						//32 M16 Rifle
			"weapon_rifle_desert",				//64 Desert Rifle
			"weapon_rifle_ak47",				//128 AK47 Rifle
			"weapon_rifle_sg552",				//256 SG552 Rifle
			"weapon_autoshotgun",				//512 Autoshotgun
			"weapon_shotgun_spas",				//1024 Spass Shotgun
			"weapon_hunting_rifle",				//2048 Sniper hunting rìle
			"weapon_sniper_military",			//4096 Military Sniper
			"weapon_sniper_scout",				//8192 Scout Sniper
			"weapon_sniper_awp",				//16384 Sniper Awp
			"weapon_rifle_m60",					//32768 Rifle M60
			"weapon_grenade_launcher"			//65536 Grenade Laucher
		},
		{//slot 1(Second Weapon)
			"weapon_pistol",					//1 Pistol
			"weapon_pistol_magnum",				//2	Magnum
			"weapon_chainsaw",					//4 Chainsaw
			"fireaxe",							//8 Fireaxe
			"frying_pan",						//16 Frying Pan
			"machete",							//32 Machete
			"baseball_bat",						//64 Baseball Bat
			"crowbar",							//128 Crowbar
			"cricket_bat",						//256 Cricket Bat
			"tonfa",							//512 Tonfa
			"katana",							//1024 Katana
			"electric_guitar",					//2048 Guita
			"knife",							//4096 Knife
			"golfclub",							//8192 Golf Club
			"shovel",							//16384 Shovel
			"pitchfork",						//32768 Pitchfork 3 chia
			"riotshield",						//65536 Shield
		},
		{//slot 2(Bomb)
			"weapon_molotov",					//1 Molotov
			"weapon_pipe_bomb",					//2 Pipe Bomb
			"weapon_vomitjar",					//4 Vomitjar
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			""
		},
		{//slot 3
			"weapon_first_aid_kit",				//1 First Aid Kit
			"weapon_defibrillator",				//2 Defibrillator
			"weapon_upgradepack_incendiary",	//4 Incendiary Ammo
			"weapon_upgradepack_explosive",		//8 Explosive Ammo
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			""
		},
		{//slot 4
			"weapon_pain_pills",				//1 Pills
			"weapon_adrenaline",				//2 Adrenaline
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			""
		}
	},
	g_sWeaponModels[][] = {
		"models/w_models/weapons/w_smg_uzi.mdl",
		"models/w_models/weapons/w_smg_mp5.mdl",
		"models/w_models/weapons/w_smg_a.mdl",
		"models/w_models/weapons/w_pumpshotgun_A.mdl",
		"models/w_models/weapons/w_shotgun.mdl",
		"models/w_models/weapons/w_rifle_m16a2.mdl",
		"models/w_models/weapons/w_desert_rifle.mdl",
		"models/w_models/weapons/w_rifle_ak47.mdl",
		"models/w_models/weapons/w_rifle_sg552.mdl",
		"models/w_models/weapons/w_autoshot_m4super.mdl",
		"models/w_models/weapons/w_shotgun_spas.mdl",
		"models/w_models/weapons/w_sniper_mini14.mdl",
		"models/w_models/weapons/w_sniper_military.mdl",
		"models/w_models/weapons/w_sniper_scout.mdl",
		"models/w_models/weapons/w_sniper_awp.mdl",
		"models/w_models/weapons/w_m60.mdl",
		"models/w_models/weapons/w_grenade_launcher.mdl",
	
		"models/w_models/weapons/w_pistol_a.mdl",
		"models/w_models/weapons/w_desert_eagle.mdl",
		"models/weapons/melee/w_chainsaw.mdl",
		"models/weapons/melee/v_fireaxe.mdl",
		"models/weapons/melee/w_fireaxe.mdl",
		"models/weapons/melee/v_frying_pan.mdl",
		"models/weapons/melee/w_frying_pan.mdl",
		"models/weapons/melee/v_machete.mdl",
		"models/weapons/melee/w_machete.mdl",
		"models/weapons/melee/v_bat.mdl",
		"models/weapons/melee/w_bat.mdl",
		"models/weapons/melee/v_crowbar.mdl",
		"models/weapons/melee/w_crowbar.mdl",
		"models/weapons/melee/v_cricket_bat.mdl",
		"models/weapons/melee/w_cricket_bat.mdl",
		"models/weapons/melee/v_tonfa.mdl",
		"models/weapons/melee/w_tonfa.mdl",
		"models/weapons/melee/v_katana.mdl",
		"models/weapons/melee/w_katana.mdl",
		"models/weapons/melee/v_electric_guitar.mdl",
		"models/weapons/melee/w_electric_guitar.mdl",
		"models/v_models/v_knife_t.mdl",
		"models/w_models/weapons/w_knife_t.mdl",
		"models/weapons/melee/v_golfclub.mdl",
		"models/weapons/melee/w_golfclub.mdl",
		"models/weapons/melee/v_shovel.mdl",
		"models/weapons/melee/w_shovel.mdl",
		"models/weapons/melee/v_pitchfork.mdl",
		"models/weapons/melee/w_pitchfork.mdl",
		"models/weapons/melee/v_riotshield.mdl",
		"models/weapons/melee/w_riotshield.mdl",

		"models/w_models/weapons/w_eq_molotov.mdl",
		"models/w_models/weapons/w_eq_pipebomb.mdl",
		"models/w_models/weapons/w_eq_bile_flask.mdl",

		"models/w_models/weapons/w_eq_medkit.mdl",
		"models/w_models/weapons/w_eq_defibrillator.mdl",
		"models/w_models/weapons/w_eq_incendiary_ammopack.mdl",
		"models/w_models/weapons/w_eq_explosive_ammopack.mdl",

		"models/w_models/weapons/w_eq_adrenaline.mdl",
		"models/w_models/weapons/w_eq_painpills.mdl"
	};

public Plugin myinfo = {
	name = PLUGIN_NAME,
	author = PLUGIN_AUTHOR,
	description = PLUGIN_DESCRIPTION,
	version = PLUGIN_VERSION,
	url = PLUGIN_URL
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max) {
	g_bLateLoad = late;
	return APLRes_Success;
}

public void OnPluginStart() {
	InitData();
	g_smSteamIDs = new StringMap();
	g_aMeleeScripts = new ArrayList(ByteCountToCells(64));

	AddCommandListener(Listener_spec_next, "spec_next");
	HookUserMessage(GetUserMessageId("SayText2"), umSayText2, true);
	CreateConVar("multiple_player_version", PLUGIN_VERSION, "multiple_player plugin version.", FCVAR_NOTIFY|FCVAR_DONTRECORD);

	g_cBotLimit =				CreateConVar("multiple_player_limit",				"4",		"How many survivor spawn in start?", CVAR_FLAGS, true, 1.0, true, float(MaxClients));
	g_cJoinLimit =				CreateConVar("multiple_player_join_limit",			"-1",		"After the number of survivors reaches this value, join will be disabled (you can set base number sv_maxplayer or lower). \n-1=Plugin does nothing.", CVAR_FLAGS, true, -1.0, true, float(MaxClients));
	g_cJoinFlags =				CreateConVar("multiple_player_join_method",			"3",		"The method for extra players to join survivors. \n0=Add-on does not process, 1=Spectator wait enter !join to join manually, 2=Automatically join survivor, 3=IDLE wait to takeover.", CVAR_FLAGS);
	g_cJoinRespawn =			CreateConVar("multiple_player_join_respawn",		"1",		"When the player join the server, if there is no Bot. \n0=Dead Wait Checkpoint Rescure, 1=Spawn new survivor Bot.", CVAR_FLAGS);
	g_cSpecNotify =				CreateConVar("multiple_player_spec_notify",		"0",		"Notify message to survivor in spectator \n0=No message, 1=Chat, 2=Hintext, 3=Menu Option.", CVAR_FLAGS);
	g_eWeapon[0].Flags =		CreateConVar("multiple_player_give_slot0",			"31",	"Slot 0. Main weapon of survivor: \n0=Nothing, 1=Uzi, 4=Silent smg, 8=Pumpshotgun, 16=Chromeshotgun, 32=Rifle, 128=Ak47, 2048=HuntingRifle, 31=Tier1, 32736=Tier2, 98304=Tier0.", CVAR_FLAGS);
	g_eWeapon[1].Flags =		CreateConVar("multiple_player_give_slot1",			"64",		"Slot 1.Second weapon of survivor. \n0=Nothing, 1=Pistol, 2=Magnum, 8=Fireaxe, 16=Frying Pan,64=Baseball Bat, 1024=Katana, 131071=Random All", CVAR_FLAGS);
	g_eWeapon[2].Flags = 		CreateConVar("multiple_player_give_slot2",			"0",		"Slot 2. Bomb for survivor. \n0=Nothing, 1=Molotov, 2=Pipebomb, 4=Vomitjar, 7=Random.", CVAR_FLAGS);
	g_eWeapon[3].Flags =		CreateConVar("multiple_player_give_slot3",			"0",		"Slot 3. Rescue supplies for survivor.\n0=Nothing, 1=First aid kit, 2=Defibrillator,4=Incendary Ammo,8=Explosive Ammo, 15=Random.", CVAR_FLAGS);
	g_eWeapon[4].Flags =		CreateConVar("multiple_player_give_slot4",			"0",		"Slot 4. Medicine for survivor.\n0=Nothing,1=Pills, 2=Adrenaline, 3=Random.", CVAR_FLAGS);
	g_cGiveType =				CreateConVar("multiple_player_give_type",			"2",		"After player join and plugin creat Bot. Auto caculate if have setting random equipment. \n0=Do nothing. \n1=The setting of each slot. \n2=The average equipment of survivor in game (only primary and secondary weapons).", CVAR_FLAGS);
	g_cGiveTime =				CreateConVar("multiple_player_give_time",			"1",		"When to equip the player. \n0=Every time you spawn at map start. \n1=Only when player 5+ join server.", CVAR_FLAGS);

	g_cSurLimit = FindConVar("survivor_limit");
	g_cSurLimit.Flags &= ~FCVAR_NOTIFY;
	g_cSurLimit.SetBounds(ConVarBound_Upper, true, float(MaxClients));

	g_cBotLimit.AddChangeHook(CvarChanged_Limit);
	g_cSurLimit.AddChangeHook(CvarChanged_Limit);

	g_cJoinLimit.AddChangeHook(CvarChanged_General);
	g_cJoinFlags.AddChangeHook(CvarChanged_General);
	g_cJoinRespawn.AddChangeHook(CvarChanged_General);
	g_cSpecNotify.AddChangeHook(CvarChanged_General);

	g_eWeapon[0].Flags.AddChangeHook(CvarChanged_Weapon);
	g_eWeapon[1].Flags.AddChangeHook(CvarChanged_Weapon);
	g_eWeapon[2].Flags.AddChangeHook(CvarChanged_Weapon);
	g_eWeapon[3].Flags.AddChangeHook(CvarChanged_Weapon);
	g_eWeapon[4].Flags.AddChangeHook(CvarChanged_Weapon);

	g_cGiveType.AddChangeHook(CvarChanged_Weapon);
	g_cGiveTime.AddChangeHook(CvarChanged_Weapon);
	
	AutoExecConfig(true, "l4d2_multiple_players");

	RegConsoleCmd("sm_afk",				cmdGoIdle,		"IDLE");
	RegConsoleCmd("sm_idle",				cmdGoIdle,		"IDLE");
	RegConsoleCmd("sm_treomay",				cmdGoIdle,		"IDLE");
	
	RegConsoleCmd("sm_teams",			cmdTeamPanel,	"Team_menu");
	RegConsoleCmd("sm_team",			cmdTeamPanel,	"Team_menu");
	RegConsoleCmd("sm_doi",			cmdTeamPanel,	"Team_menu");
	RegConsoleCmd("sm_ds",			cmdTeamPanel,	"Team_menu");
	RegConsoleCmd("sm_danhsach",			cmdTeamPanel,	"Team_menu");
	
	RegConsoleCmd("sm_join",			cmdJoinTeam2,	"Join_the_survivors");
	RegConsoleCmd("sm_thamgia",			cmdJoinTeam2,	"Join_the_survivors");

	HookEvent("round_end",				Event_RoundEnd,		EventHookMode_PostNoCopy);
	HookEvent("round_start",			Event_RoundStart,	EventHookMode_PostNoCopy);
	HookEvent("player_spawn",			Event_PlayerSpawn);
	HookEvent("player_death",			Event_PlayerDeath,	EventHookMode_Pre);
	HookEvent("player_team",			Event_PlayerTeam);
	HookEvent("player_bot_replace",		Event_PlayerBotReplace);
	HookEvent("bot_player_replace",		Event_BotPlayerReplace);
	HookEvent("finale_vehicle_leaving",	Event_FinaleVehicleLeaving);

	if (g_bLateLoad)
		g_bRoundStart = !OnEndScenario();
}

public void OnPluginEnd() {
	StatsConditionPatch(false);
}

Action cmdGoIdle(int client, int args) {
	if (!client || !IsClientInGame(client) || IsFakeClient(client))
		return Plugin_Handled;

	if (!g_bRoundStart) {
		ReplyToCommand(client, "Something wrong.");
		return Plugin_Handled;
	}

	if (GetClientTeam(client) != TEAM_SURVIVOR || !IsPlayerAlive(client))
		return Plugin_Handled;
	// Setup delay thời gian afk để plugin tiến hành lưu trữ dữ liệu
	GoAFKTimer(client, 2.5);
	return Plugin_Handled;
}

void GoAFKTimer(int client, float flDuration) {
	static int m_GoAFKTimer = -1;
	if (m_GoAFKTimer == -1)
		m_GoAFKTimer = FindSendPropInfo("CTerrorPlayer", "m_lookatPlayer") - 12;

	SetEntDataFloat(client, m_GoAFKTimer + 4, flDuration);
	SetEntDataFloat(client, m_GoAFKTimer + 8, GetGameTime() + flDuration);
}

Action cmdTeamPanel(int client, int args) {
	if (!client || !IsClientInGame(client) || IsFakeClient(client))
		return Plugin_Handled;

	DrawTeamPanel(client, false);
	return Plugin_Handled;
}

Action cmdJoinTeam2(int client, int args) {
	if (!client || !IsClientInGame(client) || IsFakeClient(client))
		return Plugin_Handled;
	
	if (!g_bRoundStart) {
		PrintToChat(client, "Something wrong.");
		return Plugin_Handled;
	}

	if (!(g_iJoinFlags & JOIN_MANUAL)) {
		PrintToChat(client, "Manual join disabled.");
		return Plugin_Handled;
	}

	if (CheckJoinLimit()) {
		PrintToChat(client, "\x05Admin set cvar \x04%d is max player.\x01.", g_iJoinLimit);
		return Plugin_Handled;
	}

	switch (GetClientTeam(client)) {
		case TEAM_SPECTATOR: {
			if (GetBotOfIdlePlayer(client))
				return Plugin_Handled;
		}

		case TEAM_SURVIVOR: {
			PrintToChat(client, "You are currently in the survivor team.");
			return Plugin_Handled;
		}

		default:
			ChangeClientTeam(client, TEAM_SPECTATOR);
	}

	JoinSurTeam(client);
	return Plugin_Handled;
}

bool JoinSurTeam(int client) {
	int bot = GetClientOfUserId(g_ePlayer[client].Bot);
	bool canRespawn = g_bJoinRespawn && IsFirstTime(client);
	if (!bot || !IsValidSurBot(bot))
		bot = FindUselessSurBot(canRespawn);

	if (!bot && !canRespawn) {
		ChangeClientTeam(client, TEAM_SURVIVOR);
		if (IsPlayerAlive(client))
			State_Transition(client, 6);

		PrintToChat(client, "\x05You just exit the server and join back. \x04Dead State\x01.");
		return true;
	}

	bool canTake;
	if (!canRespawn) {
		if (IsPlayerAlive(bot)) {
			canTake = CheckForTake(bot, bot);
			SetHumanSpec(bot, client);
			if (canTake) {
				TakeOverBot(client);
				SetInvulnerable(client, 1.5);
			}
			else {
				SetInvulnerable(bot, 1.5);
				WriteTakeoverPanel(client, bot);
			}
		}
		else {
			SetHumanSpec(bot, client);
			TakeOverBot(client);
			PrintToChat(client, "\x05You just exit the server and join back. \x04Dead State\x01.");
		}
	}
	else {
		bool addBot = !bot;
		if (addBot && (bot = SpawnSurBot()) == -1)
			return false;

		if (!IsPlayerAlive(bot)) {
			RespawnPlayer(bot);
			canTake = CheckForTake(bot, TeleportPlayer(bot));
		}
		else
			canTake = CheckForTake(bot, addBot ? TeleportPlayer(bot) : bot);

		SetHumanSpec(bot, client);
		if (canTake) {
			TakeOverBot(client);
			SetInvulnerable(client, 1.5);
		}
		else {
			SetInvulnerable(bot, 1.5);
			WriteTakeoverPanel(client, bot);
		}
	}

	return true;
}

int IsTeamAllowed(int client) {
	int team = GetClientTeam(client);
	switch (team) {
		case TEAM_SPECTATOR: {
			if (GetBotOfIdlePlayer(client))
				team = 0;
		}

		case TEAM_SURVIVOR: {
			if (IsPlayerAlive(client))
				team = 0;
		}
	}
	return team;
}

void TakeOverBotMenu(int client) {
	char info[12];
	char disp[64];
	Menu menu = new Menu(TakeOverBot_MenuHandler);
	menu.SetTitle("- Take Control Bot -");
	menu.AddItem("o", "Current Spectator Target");

	for (int i = 1; i <= MaxClients; i++) {
		if (!IsValidSurBot(i))
			continue;

		FormatEx(info, sizeof info, "%d", GetClientUserId(i));
		FormatEx(disp, sizeof disp, "%s - %s", IsPlayerAlive(i) ? "Stable" : "Dead", g_sSurvivorNames[GetCharacter(i)]);
		menu.AddItem(info, disp);
	}

	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

int TakeOverBot_MenuHandler(Menu menu, MenuAction action, int param1, int param2) {
	switch (action) {
		case MenuAction_Select: {
			if (CheckJoinLimit()) {
				PrintToChat(param1, "\x05Survivor Limit Reached \x04%d\x01.", g_iJoinLimit);
				return 0;
			}

			int bot;
			char item[12];
			menu.GetItem(param2, item, sizeof item);
			if (item[0] == 'o') {
				bot = GetEntPropEnt(param1, Prop_Send, "m_hObserverTarget");
				if (bot > 0 && IsValidSurBot(bot)) {
					SetHumanSpec(bot, param1);
					TakeOverBot(param1);
				}
				else
					PrintToChat(param1, "The current spectator target is not a takeover Bot.");
			}
			else {
				bot = GetClientOfUserId(StringToInt(item));
				if (!bot || !IsValidSurBot(bot))
					PrintToChat(param1, "The selected target bot has expired.");
				else {
					int team = IsTeamAllowed(param1);
					if (!team)
						PrintToChat(param1, "Not eligible for takeover.");
					else {
						if (team != TEAM_SPECTATOR)
							ChangeClientTeam(param1, TEAM_SPECTATOR);

						SetHumanSpec(bot, param1);
						TakeOverBot(param1);
					}
				}
			}
		}

		case MenuAction_End:
			delete menu;
	}

	return 0;
}

Action Listener_spec_next(int client, char[] command, int argc) {
	if (!g_bRoundStart)
		return Plugin_Continue;

	if (!(g_iJoinFlags & JOIN_MANUAL) || !g_ePlayer[client].Notify)
		return Plugin_Continue;

	if (!client || !IsClientInGame(client) || IsFakeClient(client))
		return Plugin_Continue;

	if (GetClientTeam(client) != TEAM_SPECTATOR || GetBotOfIdlePlayer(client))
		return Plugin_Continue;

	if (CheckJoinLimit())
		return Plugin_Continue;

	if (PrepRestoreBots())
		return Plugin_Continue;

	g_ePlayer[client].Notify = false;

	switch (g_iSpecNotify)
	{
		case 1:// Chỉnh thông báo của bạn ở dòng PrinToChat bên dưới.
			PrintToChat(client, "\x04[Core_Player] \03Type command in chat \x04!join \x03to join the game.");

		case 2:
			PrintHintText(client, "Type command in chat !join to join the game.");

		case 3:
			JoinTeam2Menu(client);
	}

	return Plugin_Continue;
}

void JoinTeam2Menu(int client) {
	EmitSoundToClient(client, SOUND_SPECMENU, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);

	Menu menu = new Menu(JoinTeam2_MenuHandler);
	menu.SetTitle("Join the survivor?");
	menu.AddItem("y", "Yes");
	menu.AddItem("n", "No");

	if (FindUselessSurBot(true))
		menu.AddItem("t", "Take over the designated BOT");

	menu.ExitButton = false;
	menu.ExitBackButton = false;
	menu.Display(client, MENU_TIME_FOREVER);
}

int JoinTeam2_MenuHandler(Menu menu, MenuAction action, int param1, int param2) {
	switch (action) {
		case MenuAction_Select: {
			switch (param2) {
				case 0:
					cmdJoinTeam2(param1, 0);

				case 2: {
					if (FindUselessSurBot(true))
						TakeOverBotMenu(param1);
					else
						PrintToChat(param1, "\x05No \x04Stable Bot \x05 can't take over now.");
				}
			}
		}

		case MenuAction_End:
			delete menu;
	}

	return 0;
}

Action umSayText2(UserMsg msg_id, BfRead msg, const int[] players, int playersNum, bool reliable, bool init) {
	if (!g_bBlockUserMsg)
		return Plugin_Continue;

	msg.ReadByte();
	msg.ReadByte();

	char buffer[254];
	msg.ReadString(buffer, sizeof buffer, true);
	if (strcmp(buffer, "#Cstrike_Name_Change") == 0)
		return Plugin_Handled;

	return Plugin_Continue;
}

public void OnConfigsExecuted() {
	static bool once;
	if (!once) {
		once = true;
		GeCvars_Limit();
	}

	GeCvars_Weapon();
	GeCvars_General();
}

void CvarChanged_Limit(ConVar convar, const char[] oldValue, const char[] newValue) {
	GeCvars_Limit();
}

void GeCvars_Limit() {
	g_iBotLimit = g_cSurLimit.IntValue = g_cBotLimit.IntValue;
}

void CvarChanged_General(ConVar convar, const char[] oldValue, const char[] newValue) {
	GeCvars_General();
}

void GeCvars_General() {
	g_iJoinLimit = 		g_cJoinLimit.IntValue;
	g_iJoinFlags =		g_cJoinFlags.IntValue;
	g_bJoinRespawn =	g_cJoinRespawn.BoolValue;
	g_iSpecNotify =		g_cSpecNotify.IntValue;
}

void CvarChanged_Weapon(ConVar convar, const char[] oldValue, const char[] newValue) {
	GeCvars_Weapon();
}

void GeCvars_Weapon() {
	int num;
	for (int i; i < MAX_SLOT; i++) {
		g_eWeapon[i].Count = 0;
		if (!g_eWeapon[i].Flags.BoolValue || IsNullSlot(i))
			num++;
	}

	g_bGiveType = num < MAX_SLOT ? g_cGiveType.BoolValue : false;
	g_bGiveTime = g_cGiveTime.BoolValue;
}

bool IsNullSlot(int slot) {
	int flags = g_eWeapon[slot].Flags.IntValue;
	for (int i; i < sizeof g_sWeaponName[]; i++) {
		if (!g_sWeaponName[slot][i][0])
			break;

		if ((1 << i) & flags)
			g_eWeapon[slot].Allowed[g_eWeapon[slot].Count++] = i;
	}
	return !g_eWeapon[slot].Count;
}

public void OnClientDisconnect(int client) {
	if (IsFakeClient(client))
		return;

	g_ePlayer[client].AuthId[0] = '\0';

	if (g_bRoundStart) {
		delete g_hBotsTimer;
		g_hBotsTimer = CreateTimer(1.0, tmrBotsUpdate);
	}
}

Action tmrBotsUpdate(Handle timer) {
	g_hBotsTimer = null;

	if (!PrepRestoreBots())
		SpawnCheck();
	else
		g_hBotsTimer = CreateTimer(1.0, tmrBotsUpdate);

	return Plugin_Continue;
}

void SpawnCheck() {
	if (!g_bRoundStart)
		return;

	int iSurvivor		= GetTeamPlayers(TEAM_SURVIVOR, true);
	int iHumanSurvivor	= GetTeamPlayers(TEAM_SURVIVOR, false);
	int iSurvivorLimit	= g_iBotLimit;
	int iSurvivorMax	= iHumanSurvivor > iSurvivorLimit ? iHumanSurvivor : iSurvivorLimit;

	if (iSurvivor > iSurvivorMax)
		PrintToConsoleAll("Kicking %d bot(s)", iSurvivor - iSurvivorMax);

	if (iSurvivor < iSurvivorLimit)
		PrintToConsoleAll("Spawning %d bot(s)", iSurvivorLimit - iSurvivor);

	for (; iSurvivorMax < iSurvivor; iSurvivorMax++)
		KickUnusedSurBot();
	
	for (; iSurvivor < iSurvivorLimit; iSurvivor++)
		SpawnExtraSurBot();
}

void KickUnusedSurBot() {
	int bot = FindUnusedSurBot(); // Ưu tiên loại bỏ các Bot không tương ứng với người chơi thực
	if (bot) {
		RemoveAllWeapons(bot);
		KickClient(bot, "Kicking Useless Client.");
	}
}

void SpawnExtraSurBot() {
	int bot = SpawnSurBot();
	if (bot != -1) {
		if (!IsPlayerAlive(bot))
			RespawnPlayer(bot);

		TeleportPlayer(bot);
		SetInvulnerable(bot, 1.5);
	}
}

public void OnMapEnd() {
	ResetPlugin();
}

void ResetPlugin() {
	delete g_hBotsTimer;
	g_smSteamIDs.Clear();
	g_bRoundStart = false;
}

void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast) {
	ResetPlugin();

	int player;
	for (int i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i) || !IsFakeClient(i) || GetClientTeam(i) != TEAM_SURVIVOR)
			continue;

		player = GetIdlePlayerOfBot(i);
		if (player && IsClientInGame(player) && !IsFakeClient(player) && GetClientTeam(player) == TEAM_SPECTATOR) {
			SetHumanSpec(i, player);
			TakeOverBot(player);
		}
	}
}

void Event_RoundStart(Event event, const char[] name, bool dontBroadcast) {
	g_bRoundStart = true;
}

void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || !IsClientInGame(client) || GetClientTeam(client) != TEAM_SURVIVOR)
		return;

	delete g_hBotsTimer;
	g_hBotsTimer = CreateTimer(2.0, tmrBotsUpdate);

	SetEntProp(client, Prop_Send, "m_isGhost", 0);
	if (!IsFakeClient(client) && IsFirstTime(client))
		RecordSteamID(client);
}

void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || !IsClientInGame(client) || !IsFakeClient(client) || GetClientTeam(client) != TEAM_SURVIVOR)
		return;

	int player = GetIdlePlayerOfBot(client);
	if (player && IsClientInGame(player) && !IsFakeClient(player) && GetClientTeam(player) == TEAM_SPECTATOR) {
		SetHumanSpec(client, player);
		TakeOverBot(player);
	}
}

void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast) {
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || !IsClientInGame(client) || IsFakeClient(client))
		return;

	switch (event.GetInt("team")) {
		case TEAM_SPECTATOR: {
			g_ePlayer[client].Notify = true;

			if (g_iJoinFlags & JOIN_AUTOMATIC && event.GetInt("oldteam") == TEAM_NOTEAM)
				CreateTimer(1.0, tmrJoinTeam2, event.GetInt("userid"), TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
		}

		case TEAM_SURVIVOR:
			SetEntProp(client, Prop_Send, "m_isGhost", 0);
	}
}

Action tmrJoinTeam2(Handle timer, int client) {
	if (!(g_iJoinFlags & JOIN_AUTOMATIC))
		return Plugin_Stop;

	client = GetClientOfUserId(client);
	if (!client || !IsClientInGame(client))
		return Plugin_Stop;

	if (GetClientTeam(client) > TEAM_SPECTATOR || GetBotOfIdlePlayer(client))
		return Plugin_Stop;

	if (CheckJoinLimit())
		return Plugin_Stop;

	if (!g_bRoundStart || PrepRestoreBots() || GetClientTeam(client) <= TEAM_NOTEAM)
		return Plugin_Continue;

	JoinSurTeam(client);
	return Plugin_Stop;
}

void Event_PlayerBotReplace(Event event, char[] name, bool dontBroadcast) {
	int playerId = event.GetInt("player");
	int player = GetClientOfUserId(playerId);
	if (!player || !IsClientInGame(player) || IsFakeClient(player) || GetClientTeam(player) != TEAM_SURVIVOR)
		return;

	int botId = event.GetInt("bot");
	int bot = GetClientOfUserId(botId);

	g_ePlayer[bot].Player = playerId;
	g_ePlayer[player].Bot = botId;

	if (!g_ePlayer[player].Model[0])
		return;

	SetEntProp(bot, Prop_Send, "m_survivorCharacter", GetEntProp(player, Prop_Send, "m_survivorCharacter"));
	SetEntityModel(bot, g_ePlayer[player].Model);
	for (int i; i < sizeof g_sSurvivorModels; i++) {
		if (strcmp(g_ePlayer[player].Model, g_sSurvivorModels[i], false) == 0) {
			g_bBlockUserMsg = true;
			SetClientInfo(bot, "name", g_sSurvivorNames[i]);
			g_bBlockUserMsg = false;
			break;
		}
	}
}

void Event_BotPlayerReplace(Event event, const char[] name, bool dontBroadcast) {
	int player = GetClientOfUserId(event.GetInt("player"));
	if (!player || !IsClientInGame(player) || IsFakeClient(player) || GetClientTeam(player) != TEAM_SURVIVOR)
		return;

	int bot = GetClientOfUserId(event.GetInt("bot"));
	SetEntProp(player, Prop_Send, "m_survivorCharacter", GetEntProp(bot, Prop_Send, "m_survivorCharacter"));

	char model[128];
	GetClientModel(bot, model, sizeof model);
	SetEntityModel(player, model);
}

void Event_FinaleVehicleLeaving(Event event, const char[] name, bool dontBroadcast) {
	int iEnt = -1;
	int loop = MaxClients + 1;
	while ((loop = FindEntityByClassname(loop, "info_survivor_position")) != -1) {
		if (iEnt == -1)
			iEnt = loop;

		if (1 <= GetEntProp(loop, Prop_Send, "m_order") <= 4) {
			iEnt = loop;
			break;
		}
	}

	if (iEnt != -1) {
		float vPos[3];
		GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", vPos);

		loop = -1;
		static const char Order[][] = {"1", "2", "3", "4"};
		for (int i = 1; i <= MaxClients; i++) {
			if (!IsClientInGame(i) || GetClientTeam(i) != TEAM_SURVIVOR)
				continue;

			if (++loop < 4)
				continue;

			iEnt = CreateEntityByName("info_survivor_position");
			if (iEnt != -1) {
				DispatchKeyValue(iEnt, "Order", Order[loop % 4]);
				TeleportEntity(iEnt, vPos, NULL_VECTOR, NULL_VECTOR);
				DispatchSpawn(iEnt);
			}
		}
	}
}

bool IsFirstTime(int client) {
	if (!CacheSteamID(client))
		return false;

	bool allow = true;
	g_smSteamIDs.GetValue(g_ePlayer[client].AuthId, allow);
	return allow;
}

void RecordSteamID(int client) {
	if (CacheSteamID(client))
		g_smSteamIDs.SetValue(g_ePlayer[client].AuthId, false, true);
}

bool CacheSteamID(int client) {
	if (g_ePlayer[client].AuthId[0])
		return true;

	if (GetClientAuthId(client, AuthId_Steam2, g_ePlayer[client].AuthId, sizeof Player::AuthId))
		return true;

	g_ePlayer[client].AuthId[0] = '\0';
	return false;
}

int GetBotOfIdlePlayer(int client) {
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && IsFakeClient(i) && GetClientTeam(i) == TEAM_SURVIVOR && GetIdlePlayerOfBot(i) == client)
			return i;
	}
	return 0;
}

int GetIdlePlayerOfBot(int client) {
	if (!HasEntProp(client, Prop_Send, "m_humanSpectatorUserID"))
		return 0;

	return GetClientOfUserId(GetEntProp(client, Prop_Send, "m_humanSpectatorUserID"));
}

int GetTeamPlayers(int team, bool includeBots) {
	int num;
	for (int i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i) || GetClientTeam(i) != team)
			continue;

		if (!includeBots && IsFakeClient(i) && !GetIdlePlayerOfBot(i))
			continue;

		num++;
	}
	return num;
}

bool CheckJoinLimit() {
	if (g_iJoinLimit == -1)
		return false;

	int num;
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i) && GetClientTeam(i) == TEAM_SURVIVOR && (!IsFakeClient(i) || GetIdlePlayerOfBot(i)))
			num++;
	}

	return num >= g_iJoinLimit;
}

int FindUnusedSurBot() {
	int client = MaxClients;
	ArrayList aClients = new ArrayList(2);

	for (; client >= 1; client--) {
		if (!IsValidSurBot(client))
			continue;

		aClients.Set(aClients.Push(IsSpecInvalid(GetClientOfUserId(g_ePlayer[client].Player)) ? 0 : 1), client, 1);
	}

	if (!aClients.Length)
		client = 0;
	else {
		aClients.Sort(Sort_Ascending, Sort_Integer);
		client = aClients.Get(0, 1);
	}

	delete aClients;
	return client;
}

int FindUselessSurBot(bool alive) {
	int client;
	ArrayList aClients = new ArrayList(2);

	for (int i = MaxClients; i >= 1; i--) {
		if (!IsValidSurBot(i))
			continue;

		client = GetClientOfUserId(g_ePlayer[i].Player);
		aClients.Set(aClients.Push(IsPlayerAlive(i) == alive ? (IsSpecInvalid(client) ? 0 : 1) : (IsSpecInvalid(client) ? 2 : 3)), i, 1);
	}

	if (!aClients.Length)
		client = 0;
	else {
		aClients.Sort(Sort_Descending, Sort_Integer);

		client = aClients.Length - 1;
		client = aClients.Get(Math_GetRandomInt(aClients.FindValue(aClients.Get(client, 0)), client), 1);
	}

	delete aClients;
	return client;
}

bool IsValidSurBot(int client) {
	return IsClientInGame(client) && !IsClientInKickQueue(client) && IsFakeClient(client) && GetClientTeam(client) == TEAM_SURVIVOR && !GetIdlePlayerOfBot(client);
}

bool IsSpecInvalid(int client) {
	return !client || !IsClientInGame(client) || IsFakeClient(client) || GetClientTeam(client) == TEAM_SURVIVOR;
}

int TeleportPlayer(int client) {
	int target = 1;
	ArrayList aClients = new ArrayList(2);

	for (; target <= MaxClients; target++) {
		if (target == client || !IsClientInGame(target) || GetClientTeam(target) != TEAM_SURVIVOR || !IsPlayerAlive(target))
			continue;
	
		aClients.Set(aClients.Push(!GetEntProp(target, Prop_Send, "m_isIncapacitated") ? 0 : !GetEntProp(target, Prop_Send, "m_isHangingFromLedge") ? 1 : 2), target, 1);
	}

	if (!aClients.Length)
		target = 0;
	else {
		aClients.Sort(Sort_Descending, Sort_Integer);

		target = aClients.Length - 1;
		target = aClients.Get(Math_GetRandomInt(aClients.FindValue(aClients.Get(target, 0)), target), 1);
	}

	delete aClients;

	if (target) {
		SetEntProp(client, Prop_Send, "m_bDucked", 1);
		SetEntityFlags(client, GetEntityFlags(client)|FL_DUCKING);

		float vPos[3];
		GetClientAbsOrigin(target, vPos);
		TeleportEntity(client, vPos, NULL_VECTOR, NULL_VECTOR);
		return target;
	}

	return client;
}

void SetInvulnerable(int client, float flDuration) {
	static int m_invulnerabilityTimer = -1;
	if (m_invulnerabilityTimer == -1)
		m_invulnerabilityTimer = FindSendPropInfo("CTerrorPlayer", "m_noAvoidanceTimer") - 12;

	SetEntDataFloat(client, m_invulnerabilityTimer + 4, flDuration);
	SetEntDataFloat(client, m_invulnerabilityTimer + 8, GetGameTime() + flDuration);
}

// L4D2- Melee In The Saferoom (https://forums.alliedmods.net/showpost.php?p=2611529&postcount=484)
public void OnMapStart() {
	GetMeleeStringTable();
	PrecacheSound(SOUND_SPECMENU);

	int i;
	for (; i < sizeof g_sWeaponModels; i++)
		PrecacheModel(g_sWeaponModels[i], true);

	char buffer[64];
	for (i = 3; i < sizeof g_sWeaponName[]; i++) {
		FormatEx(buffer, sizeof buffer, "scripts/melee/%s.txt", g_sWeaponName[1][i]);
		PrecacheGeneric(buffer, true);
	}
}

void GetMeleeStringTable() {
	g_aMeleeScripts.Clear();
	int table = FindStringTable("meleeweapons");
	if (table != INVALID_STRING_TABLE) {
		int num = GetStringTableNumStrings(table);
		char str[64];
		for (int i; i < num; i++) {
			ReadStringTable(table, i, str, sizeof str);
			g_aMeleeScripts.PushString(str);
		}
	}
}

void GiveMelee(int client, const char[] meleeName) {
	char buffer[64];
	if (g_aMeleeScripts.FindString(meleeName) != -1)
		strcopy(buffer, sizeof buffer, meleeName);
	else
		g_aMeleeScripts.GetString(Math_GetRandomInt(0, g_aMeleeScripts.Length - 1), buffer, sizeof buffer);
	
	GivePlayerItem(client, buffer);
}

enum struct Zombie {
	int idx;
	int class;
	int client;
}

Handle g_hPanelTimer[MAXPLAYERS + 1];
void DrawTeamPanel(int client, bool autoRefresh) {
	static const char ZombieName[][] = {
		"Smoker",
		"Boomer",
		"Hunter",
		"Spitter",
		"Jockey",
		"Charger",
		"Witch",
		"Tank",
		"None"
	};

	Panel panel = new Panel();
	panel.SetTitle("-- Player Database Information --");

	static char info[MAX_NAME_LENGTH];
	static char name[MAX_NAME_LENGTH];

	FormatEx(info, sizeof info, "Spectator Team [%d]", GetTeamPlayers(TEAM_SPECTATOR, false));
	panel.DrawItem(info);

	int i = 1;
	for (; i <= MaxClients; i++) {
		if (!IsClientInGame(i) || GetClientTeam(i) != TEAM_SPECTATOR)
			continue;

		GetClientName(i, name, sizeof name);
		FormatEx(info, sizeof info, "%s - %s", GetBotOfIdlePlayer(i) ? "IDLE" : "Spectator", name);
		panel.DrawText(info);
	}

	FormatEx(info, sizeof info, "Survivor Players [%d/%d] - %d Bot(s)", GetTeamPlayers(TEAM_SURVIVOR, false), g_iBotLimit, GetSurBotsCount());
	panel.DrawItem(info);

	static ConVar cv;
	if (!cv)
		cv = FindConVar("survivor_max_incapacitated_count");

	int maxInc = cv.IntValue;
	for (i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i) || GetClientTeam(i) != TEAM_SURVIVOR)
			continue;

		GetClientName(i, name, sizeof name);

		if (!IsPlayerAlive(i))
			FormatEx(info, sizeof info, "Dead - %s", name);
		else {
			if (GetEntProp(i, Prop_Send, "m_isIncapacitated"))
				FormatEx(info, sizeof info, "Down - %dHP - %s", GetClientHealth(i) + GetTempHealth(i), name);
			else if (GetEntProp(i, Prop_Send, "m_currentReviveCount") >= maxInc)
				FormatEx(info, sizeof info, "Blind - %dHP - %s", GetClientHealth(i) + GetTempHealth(i), name);
			else
				FormatEx(info, sizeof info, "%dHP - %s", GetClientHealth(i) + GetTempHealth(i), name);
	
		}

		panel.DrawText(info);
	}

	FormatEx(info, sizeof info, "Enemy Team [%d]", GetTeamPlayers(TEAM_INFECTED, false));
	panel.DrawItem(info);

	Zombie zombie;
	ArrayList aClients = new ArrayList(sizeof Zombie);
	for (i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i) || GetClientTeam(i) != TEAM_INFECTED)
			continue;

		zombie.class = GetEntProp(i, Prop_Send, "m_zombieClass");
		if (zombie.class != 8 && IsFakeClient(i))
			continue;

		zombie.client = i;
		zombie.idx = zombie.class == 8 ? (!IsFakeClient(i) ? 0 : 1) : 2;
		aClients.PushArray(zombie);
	}

	int num = aClients.Length;
	if (num) {
		aClients.Sort(Sort_Ascending, Sort_Integer);
		for (i = 0; i < num; i++) {
			aClients.GetArray(i, zombie);
			GetClientName(zombie.client, name, sizeof name);

			if (IsPlayerAlive(zombie.client)) {
				if (GetEntProp(zombie.client, Prop_Send, "m_isGhost"))
					FormatEx(info, sizeof info, "(%s)Ghost - %s", ZombieName[zombie.class - 1], name);
				else
					FormatEx(info, sizeof info, "(%s) %dHP - %s", ZombieName[zombie.class - 1], GetEntProp(zombie.client, Prop_Data, "m_iHealth"), name);
			}
			else
				FormatEx(info, sizeof info, "(%s) Dead - %s", ZombieName[zombie.class - 1], name);

			panel.DrawText(info);
		}
	}

	delete aClients;

	FormatEx(info, sizeof info, "Refresh Panel[%s]", autoRefresh ? "●" : "○");
	panel.DrawItem(info);

	panel.Send(client, Panel_Handler, 15);
	delete panel;

	delete g_hPanelTimer[client];
	if (autoRefresh)
		g_hPanelTimer[client] = CreateTimer(1.0, tmrPanel, client);
}

int Panel_Handler(Menu menu, MenuAction action, int param1, int param2) {
	switch (action) {
		case MenuAction_Select: {
			if (param2 == 4 && !g_hPanelTimer[param1])
				DrawTeamPanel(param1, true);
			else
				delete g_hPanelTimer[param1];
		}

		case MenuAction_Cancel:
			delete g_hPanelTimer[param1];
	}

	return 0;
}

Action tmrPanel(Handle timer, int client) {
	g_hPanelTimer[client] = null;

	DrawTeamPanel(client, true);
	return Plugin_Continue;
}

int GetSurBotsCount() {
	int num;
	for (int i = 1; i <= MaxClients; i++) {
		if (IsValidSurBot(i))
			num++;
	}
	return num;
}

int GetTempHealth(int client) {
	static ConVar cPainPillsDecay;
	if (!cPainPillsDecay)
		cPainPillsDecay = FindConVar("pain_pills_decay_rate");

	int tempHealth = RoundToFloor(GetEntPropFloat(client, Prop_Send, "m_healthBuffer") - (GetGameTime() - GetEntPropFloat(client, Prop_Send, "m_healthBufferTime")) * cPainPillsDecay.FloatValue);
	return tempHealth < 0 ? 0 : tempHealth;
}

void InitData() {
	char buffer[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, buffer, sizeof buffer, "gamedata/%s.txt", GAMEDATA);
	if (!FileExists(buffer))
		SetFailState("\n==========\nMissing required file: \"%s\".\n==========", buffer);

	GameData hGameData = new GameData(GAMEDATA);
	if (!hGameData)
		SetFailState("Failed to load \"%s.txt\" gamedata.", GAMEDATA);

	g_pDirector = hGameData.GetAddress("CDirector");
	if (!g_pDirector)
		SetFailState("Failed to find address: \"CDirector\" (%s)", PLUGIN_VERSION);

	g_pSavedSurvivorBotsCount = hGameData.GetAddress("SavedSurvivorBotsCount");
	if (!g_pSavedSurvivorBotsCount)
		SetFailState("Failed to find address: \"SavedSurvivorBotsCount\"");

	int m_knockdownTimer = FindSendPropInfo("CTerrorPlayer", "m_knockdownTimer");
	m_hWeaponHandle = m_knockdownTimer + 100;
	
	m_iRestoreAmmo = m_knockdownTimer + 104;

	m_restoreWeaponID = m_knockdownTimer + 108;

	m_hHiddenWeapon = m_knockdownTimer + 116;

	m_isOutOfCheckpoint = FindSendPropInfo("CTerrorPlayer", "m_jumpSupressedUntil") + 4;

	RestartScenarioTimer = hGameData.GetOffset("RestartScenarioTimer");
	if (RestartScenarioTimer == -1)
		SetFailState("Failed to find offset: \"RestartScenarioTimer\" (%s)", PLUGIN_VERSION);

	StartPrepSDKCall(SDKCall_Static);
	Address addr = hGameData.GetMemSig("NextBotCreatePlayerBot<SurvivorBot>");
	if (!addr)
		SetFailState("Failed to find address: \"NextBotCreatePlayerBot<SurvivorBot>\" in \"CDirector::AddSurvivorBot\" (%s)", PLUGIN_VERSION);
	if (!hGameData.GetOffset("OS")) {
		Address offset = view_as<Address>(LoadFromAddress(addr + view_as<Address>(1), NumberType_Int32));
		if (!offset)
			SetFailState("Failed to find address: \"NextBotCreatePlayerBot<SurvivorBot>\" (%s)", PLUGIN_VERSION);

		addr += offset + view_as<Address>(5);
	}
	if (!PrepSDKCall_SetAddress(addr))
		SetFailState("Failed to find address: \"NextBotCreatePlayerBot<SurvivorBot>\" (%s)", PLUGIN_VERSION);
	PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer);
	PrepSDKCall_SetReturnInfo(SDKType_CBasePlayer, SDKPass_Pointer);
	if (!(g_hSDK_NextBotCreatePlayerBot_SurvivorBot = EndPrepSDKCall()))
		SetFailState("Failed to create SDKCall: \"NextBotCreatePlayerBot<SurvivorBot>\" (%s)", PLUGIN_VERSION);

	StartPrepSDKCall(SDKCall_Player);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTerrorPlayer::RoundRespawn"))
		SetFailState("Failed to find signature: \"CTerrorPlayer::RoundRespawn\" (%s)", PLUGIN_VERSION);
	if (!(g_hSDK_CTerrorPlayer_RoundRespawn = EndPrepSDKCall()))
		SetFailState("Failed to create SDKCall: \"CTerrorPlayer::RoundRespawn\" (%s)", PLUGIN_VERSION);

	StartPrepSDKCall(SDKCall_Player);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CCSPlayer::State_Transition"))
		SetFailState("Failed to find signature: \"CCSPlayer::State_Transition\" (%s)", PLUGIN_VERSION);
	PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain);
	if (!(g_hSDK_CCSPlayer_State_Transition = EndPrepSDKCall()))
		SetFailState("Failed to create SDKCall: \"CCSPlayer::State_Transition\" (%s)", PLUGIN_VERSION);

	StartPrepSDKCall(SDKCall_Player);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "SurvivorBot::SetHumanSpectator"))
		SetFailState("Failed to find signature: \"SurvivorBot::SetHumanSpectator\" (%s)", PLUGIN_VERSION);
	PrepSDKCall_AddParameter(SDKType_CBasePlayer, SDKPass_Pointer);
	if (!(g_hSDK_SurvivorBot_SetHumanSpectator = EndPrepSDKCall()))
		SetFailState("Failed to create SDKCall: \"SurvivorBot::SetHumanSpectator\" (%s)", PLUGIN_VERSION);
	
	StartPrepSDKCall(SDKCall_Player);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CTerrorPlayer::TakeOverBot"))
		SetFailState("Failed to find signature: \"CTerrorPlayer::TakeOverBot\" (%s)", PLUGIN_VERSION);
	PrepSDKCall_AddParameter(SDKType_Bool, SDKPass_Plain);
	if (!(g_hSDK_CTerrorPlayer_TakeOverBot = EndPrepSDKCall()))
		SetFailState("Failed to create SDKCall: \"CTerrorPlayer::TakeOverBot\" (%s)", PLUGIN_VERSION);

	StartPrepSDKCall(SDKCall_Raw);
	if (!PrepSDKCall_SetFromConf(hGameData, SDKConf_Signature, "CDirector::IsInTransition"))
		SetFailState("Failed to find signature: \"CDirector::IsInTransition\" (%s)", PLUGIN_VERSION);
	PrepSDKCall_SetReturnInfo(SDKType_Bool, SDKPass_Plain);
	if (!(g_hSDK_CDirector_IsInTransition = EndPrepSDKCall()))
		SetFailState("Failed to create SDKCall: \"CDirector::IsInTransition\" (%s)", PLUGIN_VERSION);

	InitPatchs(hGameData);
	SetupDetours(hGameData);

	delete hGameData;
}

void InitPatchs(GameData hGameData = null) {
	int iOffset = hGameData.GetOffset("RoundRespawn_Offset");
	if (iOffset == -1)
		SetFailState("Failed to find offset: \"RoundRespawn_Offset\" (%s)", PLUGIN_VERSION);

	int iByteMatch = hGameData.GetOffset("RoundRespawn_Byte");
	if (iByteMatch == -1)
		SetFailState("Failed to find byte: \"RoundRespawn_Byte\" (%s)", PLUGIN_VERSION);

	g_pStatsCondition = hGameData.GetMemSig("CTerrorPlayer::RoundRespawn");
	if (!g_pStatsCondition)
		SetFailState("Failed to find address: \"CTerrorPlayer::RoundRespawn\" (%s)", PLUGIN_VERSION);
	
	g_pStatsCondition += view_as<Address>(iOffset);
	int iByteOrigin = LoadFromAddress(g_pStatsCondition, NumberType_Int8);
	if (iByteOrigin != iByteMatch)
		SetFailState("Failed to load \"CTerrorPlayer::RoundRespawn\", byte mis-match @ %d (0x%02X != 0x%02X) (%s)", iOffset, iByteOrigin, iByteMatch, PLUGIN_VERSION);
}

// [L4D1 & L4D2] SM Respawn Improved (https://forums.alliedmods.net/showthread.php?t=323220)
void StatsConditionPatch(bool patch) {
	static bool patched;
	if (!patched && patch) {
		patched = true;
		StoreToAddress(g_pStatsCondition, 0xEB, NumberType_Int8);
	}
	else if (patched && !patch) {
		patched = false;
		StoreToAddress(g_pStatsCondition, 0x75, NumberType_Int8);
	}
}

// Left 4 Dead 2 - CreateSurvivorBot (https://forums.alliedmods.net/showpost.php?p=2729883&postcount=16)
int SpawnSurBot() {
	g_bInSpawnTime = true;
	int bot = SDKCall(g_hSDK_NextBotCreatePlayerBot_SurvivorBot, NULL_STRING);
	if (bot != -1)
		ChangeClientTeam(bot, TEAM_SURVIVOR);

	g_bInSpawnTime = false;
	return bot;
}

void RespawnPlayer(int client) {
	StatsConditionPatch(true);
	g_bInSpawnTime = true;
	SDKCall(g_hSDK_CTerrorPlayer_RoundRespawn, client);
	g_bInSpawnTime = false;
	StatsConditionPatch(false);
}

void SetHumanSpec(int bot, int client) {
	SDKCall(g_hSDK_SurvivorBot_SetHumanSpectator, bot, client);
	SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", bot);
	if (GetEntProp(client, Prop_Send, "m_iObserverMode") == 6)
		SetEntProp(client, Prop_Send, "m_iObserverMode", 5);
}

void TakeOverBot(int client) {
	SDKCall(g_hSDK_CTerrorPlayer_TakeOverBot, client, true);
}

void State_Transition(int client, int state) {
	SDKCall(g_hSDK_CCSPlayer_State_Transition, client, state);
}

bool CheckForTake(int bot, int target) {
	return !GetEntProp(bot, Prop_Send, "m_isIncapacitated") && !GetEntData(target, m_isOutOfCheckpoint);
}

bool OnEndScenario() {
	return view_as<float>(LoadFromAddress(g_pDirector + view_as<Address>(RestartScenarioTimer + 8), NumberType_Int32)) > 0.0;
}

bool PrepRestoreBots() {
	return SDKCall(g_hSDK_CDirector_IsInTransition, g_pDirector) && LoadFromAddress(g_pSavedSurvivorBotsCount, NumberType_Int32);
}

void SetupDetours(GameData hGameData = null) {
	DynamicDetour dDetour = DynamicDetour.FromConf(hGameData, "DD::CTerrorPlayer::GoAwayFromKeyboard");
	if (!dDetour)
		SetFailState("Failed to create DynamicDetour: \"DD::CTerrorPlayer::GoAwayFromKeyboard\" (%s)", PLUGIN_VERSION);

	if (!dDetour.Enable(Hook_Pre, DD_CTerrorPlayer_GoAwayFromKeyboard_Pre))
		SetFailState("Failed to detour pre: \"DD::CTerrorPlayer::GoAwayFromKeyboard\" (%s)", PLUGIN_VERSION);

	if (!dDetour.Enable(Hook_Post, DD_CTerrorPlayer_GoAwayFromKeyboard_Post))
		SetFailState("Failed to detour post: \"DD::CTerrorPlayer::GoAwayFromKeyboard\" (%s)", PLUGIN_VERSION);

	dDetour = DynamicDetour.FromConf(hGameData, "DD::SurvivorBot::SetHumanSpectator");
	if (!dDetour)
		SetFailState("Failed to create DynamicDetour: \"DD::SurvivorBot::SetHumanSpectator\" (%s)", PLUGIN_VERSION);
		
	if (!dDetour.Enable(Hook_Pre, DD_SurvivorBot_SetHumanSpectator_Pre))
		SetFailState("Failed to detour pre: \"DD::SurvivorBot::SetHumanSpectator\" (%s)", PLUGIN_VERSION);

	dDetour = DynamicDetour.FromConf(hGameData, "DD::CBasePlayer::SetModel");
	if (!dDetour)
		SetFailState("Failed to create DynamicDetour: \"DD::CBasePlayer::SetModel\" (%s)", PLUGIN_VERSION);
		
	if (!dDetour.Enable(Hook_Post, DD_CBasePlayer_SetModel_Post))
		SetFailState("Failed to detour post: \"DD::CBasePlayer::SetModel\" (%s)", PLUGIN_VERSION);

	dDetour = DynamicDetour.FromConf(hGameData, "DD::CTerrorPlayer::GiveDefaultItems");
	if (!dDetour)
		SetFailState("Failed to create DynamicDetour: \"DD::CTerrorPlayer::GiveDefaultItems\" (%s)", PLUGIN_VERSION);

	if (!dDetour.Enable(Hook_Pre, DD_CTerrorPlayer_GiveDefaultItems_Pre))
		SetFailState("Failed to detour pre: \"DD::CTerrorPlayer::GiveDefaultItems\" (%s)", PLUGIN_VERSION);
}

// [L4D1 & L4D2]Survivor_AFK_Fix[Left 4 Fix] (https://forums.alliedmods.net/showthread.php?p=2714236)
public void OnEntityCreated(int entity, const char[] classname) {
	if (!g_bShouldFixAFK)
		return;

	if (entity < 1 || entity > MaxClients)
		return;
	
	if (classname[0] != 's' || strcmp(classname[1], "urvivor_bot", false) != 0)
		return;

	g_iSurvivorBot = entity;
}

MRESReturn DD_CTerrorPlayer_GoAwayFromKeyboard_Pre(int pThis, DHookReturn hReturn) {
	g_bShouldFixAFK = true;
	return MRES_Ignored;
}

MRESReturn DD_CTerrorPlayer_GoAwayFromKeyboard_Post(int pThis, DHookReturn hReturn) {
	if (g_bShouldFixAFK && g_iSurvivorBot > 0 && IsFakeClient(g_iSurvivorBot)) {
		g_bShouldIgnore = true;
		SetHumanSpec(g_iSurvivorBot, pThis);
		WriteTakeoverPanel(pThis, g_iSurvivorBot);
		g_bShouldIgnore = false;
	}

	g_iSurvivorBot = 0;
	g_bShouldFixAFK = false;
	return MRES_Ignored;
}

MRESReturn DD_SurvivorBot_SetHumanSpectator_Pre(int pThis, DHookParam hParams) {
	if (!g_bShouldFixAFK)
		return MRES_Ignored;

	if (g_bShouldIgnore)
		return MRES_Ignored;

	if (g_iSurvivorBot < 1)
		return MRES_Ignored;

	return MRES_Supercede;
}

MRESReturn DD_CBasePlayer_SetModel_Post(int pThis, DHookParam hParams) {
	if (pThis < 1 || pThis > MaxClients || !IsClientInGame(pThis) || IsFakeClient(pThis))
		return MRES_Ignored;

	if (GetClientTeam(pThis) != TEAM_SURVIVOR) {
		g_ePlayer[pThis].Model[0] = '\0';
		return MRES_Ignored;
	}
	
	char model[128];
	hParams.GetString(1, model, sizeof model);
	if (StrContains(model, "models/survivors/survivor_", false) == 0)
		strcopy(g_ePlayer[pThis].Model, sizeof Player::Model, model);

	return MRES_Ignored;
}

MRESReturn DD_CTerrorPlayer_GiveDefaultItems_Pre(int pThis) {
	if (!g_bGiveType)
		return MRES_Ignored;

	if (g_bShouldFixAFK || g_bGiveTime && !g_bInSpawnTime)
		return MRES_Ignored;

	if (pThis < 1 || pThis > MaxClients || !IsClientInGame(pThis))
		return MRES_Ignored;

	if (GetClientTeam(pThis) != TEAM_SURVIVOR || !IsPlayerAlive(pThis) || ShouldIgnore(pThis))
		return MRES_Ignored;

	GiveDefaultItems(pThis);
	ClearRestoreWeapons(pThis);
	return MRES_Supercede;
}

void WriteTakeoverPanel(int client, int bot) {
	char buf[2];
	IntToString(GetCharacter(bot)/*GetEntProp(bot, Prop_Send, "m_survivorCharacter")*/, buf, sizeof buf);
	BfWrite bf = view_as<BfWrite>(StartMessageOne("VGUIMenu", client, USERMSG_RELIABLE));
	bf.WriteString("takeover_survivor_bar");
	bf.WriteByte(true);
	bf.WriteByte(1);
	bf.WriteString("character");
	bf.WriteString(buf);
	EndMessage();
}

int GetCharacter(int client) {
	char model[31];
	GetClientModel(client, model, sizeof model);
	switch (model[29]) {
		case 'b'://nick
			return 0;
		case 'd'://rochelle
			return 1;
		case 'c'://coach
			return 2;
		case 'h'://ellis
			return 3;
		case 'v'://bill
			return 4;
		case 'n'://zoey
			return 5;
		case 'e'://francis
			return 6;
		case 'a'://louis
			return 7;
		default:
			return GetEntProp(client, Prop_Send, "m_survivorCharacter");
	}
}

bool ShouldIgnore(int client) {
	if (IsFakeClient(client))
		return !!GetIdlePlayerOfBot(client);

	for (int i = 1; i <= MaxClients; i++) {
		if (!IsClientInGame(i) || !IsFakeClient(i) || GetClientTeam(i) != TEAM_SPECTATOR)
			continue;

		if (GetEntProp(GetPlayerResourceEntity(), Prop_Send, "m_iTeam", _, i) == TEAM_SURVIVOR && GetIdlePlayerOfBot(i) == client)
			return true;
	}

	return false;
}

void ClearRestoreWeapons(int client) {
	SetEntData(client, m_hWeaponHandle, 0, _, true);
	SetEntData(client, m_iRestoreAmmo, -1, _, true);
	SetEntData(client, m_restoreWeaponID, 0, _, true);
}

void GiveDefaultItems(int client) {
	RemoveAllWeapons(client);
	for (int i = 4; i >= 2; i--) {
		if (!g_eWeapon[i].Count)
			continue;

		GivePlayerItem(client, g_sWeaponName[i][g_eWeapon[i].Allowed[Math_GetRandomInt(0, g_eWeapon[i].Count - 1)]]);
	}

	GiveSecondary(client);
	switch (g_cGiveType.IntValue) {
		case 1:
			GivePresetPrimary(client);
		
		case 2:
			GiveAveragePrimary(client);
	}
}

void GiveSecondary(int client) {
	if (g_eWeapon[1].Count) {
		int val = g_eWeapon[1].Allowed[Math_GetRandomInt(0, g_eWeapon[1].Count - 1)];
		if (val > 2)
			GiveMelee(client, g_sWeaponName[1][val]);
		else
			GivePlayerItem(client, g_sWeaponName[1][val]);
	}
}

void GivePresetPrimary(int client) {
	if (g_eWeapon[0].Count)
		GivePlayerItem(client, g_sWeaponName[0][g_eWeapon[0].Allowed[Math_GetRandomInt(0, g_eWeapon[0].Count - 1)]]);
}

bool IsWeaponTier1(int weapon) {
	char cls[32];
	GetEntityClassname(weapon, cls, sizeof cls);
	for (int i; i < 5; i++) {
		if (strcmp(cls, g_sWeaponName[0][i], false) == 0)
			return true;
	}
	return false;
}

void GiveAveragePrimary(int client) {
	int i = 1, tier, total, weapon;
	if (g_bRoundStart) {
		for (; i <= MaxClients; i++) {
			if (i == client || !IsClientInGame(i) || GetClientTeam(i) != TEAM_SURVIVOR || !IsPlayerAlive(i))
				continue;

			total += 1;
			weapon = GetPlayerWeaponSlot(i, 0);
			if (weapon <= MaxClients || !IsValidEntity(weapon))
				continue;

			tier += IsWeaponTier1(weapon) ? 1 : 2;
		}
	}

	switch (total > 0 ? RoundToNearest(float(tier) / float(total)) : 0) {
		case 1:
			GivePlayerItem(client, g_sWeaponName[0][Math_GetRandomInt(0, 4)]);

		case 2:
			GivePlayerItem(client, g_sWeaponName[0][Math_GetRandomInt(5, 14)]);
	}
}

void RemoveAllWeapons(int client) {
	int weapon;
	for (int i; i < MAX_SLOT; i++) {
		if ((weapon = GetPlayerWeaponSlot(client, i)) <= MaxClients)
			continue;

		RemovePlayerItem(client, weapon);
		RemoveEntity(weapon);
	}

	weapon = GetEntDataEnt2(client, m_hHiddenWeapon);
	SetEntDataEnt2(client, m_hHiddenWeapon, -1, true);
	if (weapon > MaxClients && IsValidEntity(weapon) && GetEntPropEnt(weapon, Prop_Data, "m_hOwnerEntity") == client) {
		RemovePlayerItem(client, weapon);
		RemoveEntity(weapon);
	}
}

#define SIZE_OF_INT	2147483647 // without 0
int Math_GetRandomInt(int min, int max) {
	int random = GetURandomInt();
	if (random == 0)
		random++;

	return RoundToCeil(float(random) / (float(SIZE_OF_INT) / float(max - min + 1))) + min - 1;
}
