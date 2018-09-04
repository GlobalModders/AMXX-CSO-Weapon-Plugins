#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <cstrike>
#include <xs>
#include <fun>

#define PLUGIN "[CSO] Brick Peace V2"
#define VERSION "1.0"
#define AUTHOR "Dias Pendragon Leon"

#define DAMAGE_A 30 // 60 for Zombie
#define DAMAGE_B 150 // 300 for Zombie

#define CLIP 40
#define BPAMMO 200
#define SPEED 1.25

#define CSW_BLOCKAR CSW_M4A1
#define weapon_blockar "weapon_m4a1"

#define WEAPON_ANIMEXT_A "rifle"
#define WEAPON_ANIMEXT_B "m249"

#define MODEL_V "models/v_blockar1.mdl"
#define MODEL_V2 "models/v_blockar2.mdl"
#define MODEL_VC "models/v_blockchange.mdl"
#define MODEL_P "models/p_blockar1.mdl"
#define MODEL_P2 "models/p_blockar2.mdl"
#define MODEL_W "models/w_blockar1.mdl"
#define MODEL_W2 "models/w_blockar2.mdl"
#define MODEL_S "models/block_missile.mdl"
#define MODEL_SHELL "models/block_shell.mdl"

#define BLOCKAR_OLDMODEL "models/w_m4a1.mdl"
#define ROCKET_CLASSNAME "Thomas_Hadley"

new const WeaponSounds[18][] =
{
	"weapons/blockar1-1.wav",
	"weapons/blockar2-1.wav",
	"weapons/block_change.wav",
	"weapons/blockar1_change1.wav",
	"weapons/blockar1_change2.wav",
	"weapons/blockar1_clipin.wav",
	"weapons/blockar1_clipout.wav",
	"weapons/blockar1_draw.wav",
	"weapons/blockar1_shell1.wav",
	"weapons/blockar1_shell2.wav",
	"weapons/blockar1_shell3.wav",
	"weapons/blockar2_change1_1.wav",
	"weapons/blockar2_change2_1.wav",
	"weapons/blockar2_change2_2.wav",
	"weapons/blockar2_idle.wav",
	"weapons/blockar2_reload.wav",
	"weapons/blockar2_shoot_start.wav",
	"weapons/blockar2_shoot_end.wav"
}

new const WeaponResources[3][] =
{
	"sprites/weapon_blockar.txt",
	"sprites/640hud8_2.spr",
	"sprites/640hud115_2.spr"
}

enum
{
	ANIME1_IDLE = 0,
	ANIME1_SHOOT1,
	ANIME1_SHOOT2,
	ANIME1_SHOOT3,
	ANIME1_CHANGE_AB,
	ANIME1_CHANGE_BA,
	ANIME1_RELOAD,
	ANIME1_DRAW
}

enum
{
	ANIME2_IDLE1 = 0,
	ANIME2_IDLE2,
	ANIME2_SHOOT_BEGIN,
	ANIME2_SHOOT_END,
	ANIME2_CHANGE_BA1,
	ANIME2_CHANGE_BA2,
	ANIME2_CHANGE_AB1,
	ANIME2_CHANGE_AB2,
	ANIME2_RELOAD,
	ANIME2_DRAW1,
	ANIME2_DRAW2
}

#define TASK_CHANGING 21611
#define TASK_TENLUA 21612

// MACROS
#define Get_BitVar(%1,%2) (%1 & (1 << (%2 & 31)))
#define Set_BitVar(%1,%2) %1 |= (1 << (%2 & 31))
#define UnSet_BitVar(%1,%2) %1 &= ~(1 << (%2 & 31))

new g_Had_BlockAR, g_LauncherMode, g_TenLuaReady
new g_Event_BlockAR, g_InTempingAttack, g_ShellId, g_Clip[33], g_SmokePuff_SprId
new g_MsgCurWeapon, g_MsgAmmoX, g_MsgWeaponList, g_Exp_SprId, g_SmokeSprId, g_MaxPlayers

// Safety
new g_IsConnected, g_IsAlive, g_PlayerWeapon[33], g_HamBot

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	// Safety
	Register_SafetyFunc()
	
	register_event("CurWeapon", "Event_CurWeapon", "be", "1=1")
	
	register_think(ROCKET_CLASSNAME, "fw_Rocket_Think")
	register_touch(ROCKET_CLASSNAME, "*", "fw_Rocket_Touch")
	
	register_forward(FM_UpdateClientData, "fw_UpdateClientData_Post", 1)
	register_forward(FM_PlaybackEvent, "fw_PlaybackEvent")
	register_forward(FM_CmdStart, "fw_CmdStart")
	register_forward(FM_SetModel, "fw_SetModel")	
	register_forward(FM_EmitSound, "fw_EmitSound")
	register_forward(FM_TraceLine, "fw_TraceLine")
	register_forward(FM_TraceHull, "fw_TraceHull")
	
	RegisterHam(Ham_Item_Deploy, weapon_blockar, "fw_Item_Deploy_Post", 1)	
	RegisterHam(Ham_Item_AddToPlayer, weapon_blockar, "fw_Item_AddToPlayer_Post", 1)
	RegisterHam(Ham_Weapon_WeaponIdle, weapon_blockar, "fw_Weapon_WeaponIdle_Post", 1)
	RegisterHam(Ham_Item_PostFrame, weapon_blockar, "fw_Item_PostFrame")	
	RegisterHam(Ham_Weapon_Reload, weapon_blockar, "fw_Weapon_Reload")
	RegisterHam(Ham_Weapon_Reload, weapon_blockar, "fw_Weapon_Reload_Post", 1)	
	
	RegisterHam(Ham_TraceAttack, "worldspawn", "fw_TraceAttack_World")
	RegisterHam(Ham_TraceAttack, "player", "fw_TraceAttack_Player")	
	
	g_MsgCurWeapon = get_user_msgid("CurWeapon")
	g_MsgAmmoX = get_user_msgid("AmmoX")
	g_MsgWeaponList = get_user_msgid("WeaponList")
	g_MaxPlayers = get_maxplayers()
	
	register_clcmd("say /get", "Get_BlockAR")
	register_clcmd("weapon_blockar", "HookWeapon")
}

public plugin_precache()
{
	precache_model(MODEL_V)
	precache_model(MODEL_V2)
	precache_model(MODEL_VC)
	precache_model(MODEL_P)
	precache_model(MODEL_P2)
	precache_model(MODEL_W)
	precache_model(MODEL_W2)
	precache_model(MODEL_S)
	
	for(new i = 0; i < sizeof(WeaponSounds); i++)
		precache_sound(WeaponSounds[i])
	
	precache_generic(WeaponResources[0])
	precache_model(WeaponResources[1])
	precache_model(WeaponResources[2])
	
	register_forward(FM_PrecacheEvent, "fw_PrecacheEvent_Post", 1)
	
	g_Exp_SprId = precache_model("sprites/zerogxplode.spr")
	g_SmokePuff_SprId = precache_model("sprites/wall_puff1.spr")
	g_SmokeSprId = engfunc(EngFunc_PrecacheModel, "sprites/steam1.spr")
	g_ShellId = precache_model(MODEL_SHELL)
}

public fw_PrecacheEvent_Post(type, const name[])
{
	if(equal("events/m4a1.sc", name)) g_Event_BlockAR = get_orig_retval()		
}

public client_putinserver(id)
{
	Safety_Connected(id)
	
	if(!g_HamBot && is_user_bot(id))
	{
		g_HamBot = 1
		set_task(0.1, "Do_Register_HamBot", id)
	}
}

public Do_Register_HamBot(id) 
{
	Register_SafetyFuncBot(id)
}

public client_disconnect(id)
{
	Safety_Disconnected(id)
}

public HookWeapon(id)
{
	engclient_cmd(id, weapon_blockar)
	return PLUGIN_HANDLED
}

public Get_BlockAR(id)
{
	UnSet_BitVar(g_InTempingAttack, id)
	UnSet_BitVar(g_LauncherMode, id)
	UnSet_BitVar(g_TenLuaReady, id)
	Set_BitVar(g_Had_BlockAR, id)
	
	give_item(id, weapon_blockar)
	
	// Clip & Ammo
	static Ent; Ent = fm_get_user_weapon_entity(id, CSW_BLOCKAR)
	if(!pev_valid(Ent)) return
	
	cs_set_weapon_ammo(Ent, CLIP)
	cs_set_user_bpammo(id, CSW_BLOCKAR, BPAMMO)
	
	// Update Hud
	message_begin(MSG_ONE_UNRELIABLE, g_MsgCurWeapon, _, id)
	write_byte(1)
	write_byte(CSW_BLOCKAR)
	write_byte(CLIP)
	message_end()
	
	message_begin(MSG_ONE_UNRELIABLE, g_MsgAmmoX, _, id)
	write_byte(4)
	write_byte(BPAMMO)
	message_end()
}

public Remove_BlockAR(id)
{
	UnSet_BitVar(g_InTempingAttack, id)
	UnSet_BitVar(g_LauncherMode, id)
	UnSet_BitVar(g_TenLuaReady, id)
	UnSet_BitVar(g_Had_BlockAR, id)
	
	remove_task(id+TASK_CHANGING)
	remove_task(id+TASK_TENLUA)
}

public Event_CurWeapon(id)
{
	static CSW; CSW = read_data(2)
	
	if(CSW != CSW_BLOCKAR || !Get_BitVar(g_Had_BlockAR, id))	
		return

	static Float:Delay, Float:Delay2
	static Ent; Ent = fm_get_user_weapon_entity(id, CSW_BLOCKAR)
	if(!pev_valid(Ent)) return
	
	Delay = get_pdata_float(Ent, 46, 4) * SPEED
	Delay2 = get_pdata_float(Ent, 47, 4) * SPEED
	
	if(Delay > 0.0)
	{
		set_pdata_float(Ent, 46, Delay, 4)
		set_pdata_float(Ent, 47, Delay2, 4)
	}
}


public fw_UpdateClientData_Post(id, sendweapons, cd_handle)
{
	if(!is_alive(id))
		return FMRES_IGNORED	
	if(get_user_weapon(id) == CSW_BLOCKAR && Get_BitVar(g_Had_BlockAR, id))
		set_cd(cd_handle, CD_flNextAttack, get_gametime() + 0.001) 
	
	return FMRES_HANDLED
}

public fw_PlaybackEvent(flags, invoker, eventid, Float:delay, Float:origin[3], Float:angles[3], Float:fparam1, Float:fparam2, iParam1, iParam2, bParam1, bParam2)
{
	if (!is_connected(invoker))
		return FMRES_IGNORED	
	if(get_player_weapon(invoker) != CSW_BLOCKAR || !Get_BitVar(g_Had_BlockAR, invoker))
		return FMRES_IGNORED
	if(eventid != g_Event_BlockAR)
		return FMRES_IGNORED
	
	engfunc(EngFunc_PlaybackEvent, flags | FEV_HOSTONLY, invoker, eventid, delay, origin, angles, fparam1, fparam2, iParam1, iParam2, bParam1, bParam2)

	if(!Get_BitVar(g_LauncherMode, invoker)) 
	{
		Set_WeaponAnim(invoker, ANIME1_SHOOT1)
		emit_sound(invoker, CHAN_WEAPON, WeaponSounds[0], 1.0, ATTN_NORM, 0, PITCH_NORM)
		
		Eject_Shell(invoker, g_ShellId, 0.01)
	}
	
	return FMRES_SUPERCEDE
}

public fw_SetModel(entity, model[])
{
	if(!pev_valid(entity))
		return FMRES_IGNORED
	
	static Classname[32]
	pev(entity, pev_classname, Classname, sizeof(Classname))
	
	if(!equal(Classname, "weaponbox"))
		return FMRES_IGNORED
	
	static iOwner
	iOwner = pev(entity, pev_owner)
	
	if(equal(model, BLOCKAR_OLDMODEL))
	{
		static weapon; weapon = find_ent_by_owner(-1, weapon_blockar, entity)
		
		if(!pev_valid(weapon))
			return FMRES_IGNORED;
		
		if(Get_BitVar(g_Had_BlockAR, iOwner))
		{
			set_pev(weapon, pev_impulse, 21062015)
			
			if(!Get_BitVar(g_LauncherMode, iOwner))
			{
				engfunc(EngFunc_SetModel, entity, MODEL_W)
				set_pev(weapon, pev_iuser1, 0)
			} else {
				engfunc(EngFunc_SetModel, entity, MODEL_W2)
				set_pev(weapon, pev_iuser1, 1)
				
				if(Get_BitVar(g_TenLuaReady, iOwner)) set_pev(weapon, pev_iuser2, 1)
				else set_pev(weapon, pev_iuser2, 0)
			}
			
			Remove_BlockAR(iOwner)
			
			return FMRES_SUPERCEDE
		}
	}

	return FMRES_IGNORED;
}

public fw_CmdStart(id, uc_handle, seed)
{
	if(!is_alive(id))
		return FMRES_IGNORED
	if(get_user_weapon(id) != CSW_BLOCKAR || !Get_BitVar(g_Had_BlockAR, id))
		return FMRES_IGNORED
		
	static PressedButton
	PressedButton = get_uc(uc_handle, UC_Buttons)
	
	if(Get_BitVar(g_LauncherMode, id) && !Get_BitVar(g_TenLuaReady, id))
	{
		if(get_pdata_float(id, 83, 5) > 0.0)
			return FMRES_IGNORED
		
		Set_BitVar(g_TenLuaReady, id)
		
		Set_PlayerNextAttack(id, 2.0)
		Set_WeaponIdleTime(id, CSW_BLOCKAR, 2.0)
		
		Set_WeaponAnim(id, ANIME2_RELOAD)
	}
	
	if(PressedButton & IN_ATTACK)
	{
		if(get_pdata_float(id, 83, 5) > 0.0)
			return FMRES_IGNORED
		if(!Get_BitVar(g_LauncherMode, id))
			return FMRES_IGNORED
		if(!Get_BitVar(g_TenLuaReady, id))
			return FMRES_IGNORED
			
		Shoot_TenLua(id)
			
		PressedButton &= ~IN_ATTACK2
		set_uc(uc_handle, UC_Buttons, PressedButton)
	} else if(PressedButton & IN_ATTACK2) {
		if(get_pdata_float(id, 83, 5) > 0.0)
			return FMRES_IGNORED
			
		PressedButton &= ~IN_ATTACK2
		set_uc(uc_handle, UC_Buttons, PressedButton)
	
		if(!Get_BitVar(g_LauncherMode, id))
		{
			Set_WeaponAnim(id, ANIME1_CHANGE_AB)
			set_pdata_float(id, 83, 1.5, 5)
			
			remove_task(id+TASK_CHANGING)
			set_task(1.25, "ChangeAB_Stage1", id+TASK_CHANGING)
		} else {
			if(Get_BitVar(g_TenLuaReady, id))
			{
				Set_WeaponAnim(id, ANIME2_CHANGE_BA1)
			} else {
				Set_WeaponAnim(id, ANIME2_CHANGE_BA2)
			}
			
			set_pdata_float(id, 83, 1.5, 5)
			
			remove_task(id+TASK_CHANGING)
			set_task(1.25, "ChangeBA_Stage1", id+TASK_CHANGING)
		}
	}
		
	return FMRES_HANDLED
}

public Shoot_TenLua(id)
{
	remove_task(id+TASK_TENLUA)
	
	Set_PlayerNextAttack(id, 3.0)
	Set_WeaponAnim(id, ANIME2_SHOOT_BEGIN)
	
	set_task(0.75, "Shoot_TenLua2", id+TASK_TENLUA)
}

public Shoot_TenLua2(id)
{
	id -= TASK_TENLUA
	
	if(!is_alive(id))
		return
	if(get_user_weapon(id) != CSW_BLOCKAR || !Get_BitVar(g_Had_BlockAR, id))
		return
	if(!Get_BitVar(g_LauncherMode, id) || !Get_BitVar(g_TenLuaReady, id))
		return
		
	UnSet_BitVar(g_TenLuaReady, id)
		
	Set_WeaponAnim(id, ANIME2_SHOOT_END)
	emit_sound(id, CHAN_WEAPON, WeaponSounds[1], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	
	// Fake
	static Float:Origin[3]
	Origin[0] = random_float(-2.5, -5.0)
	
	set_pev(id, pev_punchangle, Origin)
	
	// Rocket
	Shoot_Rocket(id)
	Set_PlayerNextAttack(id, 1.0)
}

public Shoot_Rocket(id)
{
	new iEnt = create_entity("info_target")
	
	static Float:Origin[3], Float:Angles[3], Float:TargetOrigin[3], Float:Velocity[3]
	
	get_weapon_attachment(id, Origin, 40.0)
	get_position(id, 2048.0, 6.0, 0.0, TargetOrigin)
	
	pev(id, pev_v_angle, Angles)
	Angles[0] *= -1.0

	// set info for ent
	set_pev(iEnt, pev_movetype, MOVETYPE_PUSHSTEP)
	entity_set_string(iEnt, EV_SZ_classname, ROCKET_CLASSNAME)
	engfunc(EngFunc_SetModel, iEnt, MODEL_S)
	
	set_pev(iEnt, pev_mins, Float:{-1.0, -1.0, -1.0})
	set_pev(iEnt, pev_maxs, Float:{1.0, 1.0, 1.0})
	set_pev(iEnt, pev_origin, Origin)
	set_pev(iEnt, pev_gravity, 0.1)
	set_pev(iEnt, pev_angles, Angles)
	set_pev(iEnt, pev_solid, SOLID_TRIGGER)
	set_pev(iEnt, pev_owner, id)	
	set_pev(iEnt, pev_iuser1, get_user_team(id))

	get_speed_vector(Origin, TargetOrigin, 2000.0, Velocity)
	set_pev(iEnt, pev_velocity, Velocity)	
	
	set_pev(iEnt, pev_nextthink, get_gametime() + 0.1)
}

public fw_Rocket_Think(Ent)
{
	if(!pev_valid(Ent))
		return
		
	static Float:Origin[3], TE_FLAG;
	pev(Ent, pev_origin, Origin)
	
	TE_FLAG |= TE_EXPLFLAG_NODLIGHTS
	TE_FLAG |= TE_EXPLFLAG_NOSOUND
	TE_FLAG |= TE_EXPLFLAG_NOPARTICLES
	
	engfunc(EngFunc_MessageBegin, MSG_PAS, SVC_TEMPENTITY, Origin, 0)
	write_byte(TE_EXPLOSION)
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2] - 8.0)
	write_short(g_SmokePuff_SprId)
	write_byte(4)
	write_byte(75)
	write_byte(TE_FLAG)
	message_end()
		
	set_pev(Ent, pev_nextthink, get_gametime() + 0.1)
}

public fw_Rocket_Touch(Ent, Touched)
{
	if(!pev_valid(Ent)) return
	
	static Float:Origin[3];
	pev(Ent, pev_origin, Origin)
	
	engfunc(EngFunc_MessageBegin, MSG_PAS, SVC_TEMPENTITY, Origin, 0)
	write_byte(TE_EXPLOSION)
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2])
	write_short(g_Exp_SprId)
	write_byte(30)
	write_byte(15)
	write_byte(0)
	message_end()
	
	// Put decal on "world" (a wall)
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_WORLDDECAL)
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2])
	write_byte(random_num(46, 48))
	message_end()	
	
	message_begin(MSG_BROADCAST ,SVC_TEMPENTITY)
	write_byte(TE_SMOKE)
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2])
	write_short(g_SmokeSprId)	// sprite index 
	write_byte(30)	// scale in 0.1's 
	write_byte(10)	// framerate 
	message_end()
	
	static ID; ID = pev(Ent, pev_owner)
	static Team; Team = pev(Ent, pev_iuser1)
	
	if(is_user_connected(ID)) Rocket_Damage(ID, Team, Origin)
	
	set_pev(Ent, pev_flags, FL_KILLME)
	set_pev(Ent, pev_nextthink, get_gametime() + 0.1)
}

public Rocket_Damage(id, Team, Float:Origin[3])
{
	static Float:MyOrigin[3]
	for(new i = 0; i < g_MaxPlayers; i++)
	{
		if(!is_user_alive(id))
			continue
		if(get_user_team(i) == Team)
			continue
		if(id == i)
			continue
		pev(i, pev_origin, MyOrigin)
		if(get_distance_f(Origin, MyOrigin) > 100.0)
			continue
			
		ExecuteHamB(Ham_TakeDamage, i, 0, id, float(DAMAGE_B), DMG_BULLET)
	}
}

public ChangeAB_Stage1(id)
{
	id -= TASK_CHANGING
	
	if(!is_alive(id))
		return
	if(get_user_weapon(id) != CSW_BLOCKAR || !Get_BitVar(g_Had_BlockAR, id))
		return
		
	set_pev(id, pev_viewmodel2, MODEL_VC)
	Set_WeaponAnim(id, 0)
	set_pdata_float(id, 83, 2.5, 5)
	
	remove_task(id+TASK_CHANGING)
	set_task(2.25, "ChangeAB_Stage2", id+TASK_CHANGING)
}

public ChangeAB_Stage2(id)
{
	id -= TASK_CHANGING
	
	if(!is_alive(id))
		return
	if(get_user_weapon(id) != CSW_BLOCKAR || !Get_BitVar(g_Had_BlockAR, id))
		return
		
	Set_BitVar(g_LauncherMode, id)
	Set_BitVar(g_TenLuaReady, id)
	
	set_pev(id, pev_viewmodel2, MODEL_V2)
	set_pev(id, pev_weaponmodel2, MODEL_P2)
	
	Set_WeaponAnim(id, ANIME2_CHANGE_AB1)
	Set_PlayerNextAttack(id, 0.9)
	Set_WeaponIdleTime(id, CSW_BLOCKAR, 1.0)
	
	set_pdata_string(id, (492) * 4, WEAPON_ANIMEXT_B, -1 , 20)
	
	remove_task(id+TASK_CHANGING)
}

public ChangeBA_Stage1(id)
{
	id -= TASK_CHANGING
	
	if(!is_alive(id))
		return
	if(get_user_weapon(id) != CSW_BLOCKAR || !Get_BitVar(g_Had_BlockAR, id))
		return
		
	set_pev(id, pev_viewmodel2, MODEL_VC)
	Set_WeaponAnim(id, 0)
	set_pdata_float(id, 83, 2.5, 5)
	
	remove_task(id+TASK_CHANGING)
	set_task(2.25, "ChangeBA_Stage2", id+TASK_CHANGING)
}

public ChangeBA_Stage2(id)
{
	id -= TASK_CHANGING
	
	if(!is_alive(id))
		return
	if(get_user_weapon(id) != CSW_BLOCKAR || !Get_BitVar(g_Had_BlockAR, id))
		return
		
	UnSet_BitVar(g_LauncherMode, id)
	UnSet_BitVar(g_TenLuaReady, id)
	
	set_pev(id, pev_viewmodel2, MODEL_V)
	set_pev(id, pev_weaponmodel2, MODEL_P)
	
	Set_WeaponAnim(id, ANIME1_CHANGE_BA)
	Set_PlayerNextAttack(id, 0.9)
	Set_WeaponIdleTime(id, CSW_BLOCKAR, 1.0)
	
	set_pdata_string(id, (492) * 4, WEAPON_ANIMEXT_A, -1 , 20)
	
	remove_task(id+TASK_CHANGING)
}

public fw_EmitSound(id, channel, const sample[], Float:volume, Float:attn, flags, pitch)
{
	if(!is_connected(id))
		return FMRES_IGNORED
	if(!Get_BitVar(g_InTempingAttack, id))
		return FMRES_IGNORED
		
	if(sample[8] == 'k' && sample[9] == 'n' && sample[10] == 'i')
	{
		if(sample[14] == 's' && sample[15] == 'l' && sample[16] == 'a')
			return FMRES_SUPERCEDE
		if (sample[14] == 'h' && sample[15] == 'i' && sample[16] == 't')
		{
			if (sample[17] == 'w')  return FMRES_SUPERCEDE
			else  return FMRES_SUPERCEDE
		}
		if (sample[14] == 's' && sample[15] == 't' && sample[16] == 'a')
			return FMRES_SUPERCEDE;
	}
	
	return FMRES_IGNORED
}

public fw_TraceLine(Float:vector_start[3], Float:vector_end[3], ignored_monster, id, handle)
{
	if(!is_user_alive(id))
		return FMRES_IGNORED	
	if(!Get_BitVar(g_InTempingAttack, id))
		return FMRES_IGNORED
	
	static Float:vecStart[3], Float:vecEnd[3], Float:v_angle[3], Float:v_forward[3], Float:view_ofs[3], Float:fOrigin[3]
	
	pev(id, pev_origin, fOrigin)
	pev(id, pev_view_ofs, view_ofs)
	xs_vec_add(fOrigin, view_ofs, vecStart)
	pev(id, pev_v_angle, v_angle)
	
	engfunc(EngFunc_MakeVectors, v_angle)
	get_global_vector(GL_v_forward, v_forward)

	xs_vec_mul_scalar(v_forward, 0.0, v_forward)
	xs_vec_add(vecStart, v_forward, vecEnd)
	
	engfunc(EngFunc_TraceLine, vecStart, vecEnd, ignored_monster, id, handle)
	
	return FMRES_SUPERCEDE
}

public fw_TraceHull(Float:vector_start[3], Float:vector_end[3], ignored_monster, hull, id, handle)
{
	if(!is_user_alive(id))
		return FMRES_IGNORED	
	if(!Get_BitVar(g_InTempingAttack, id))
		return FMRES_IGNORED
	
	static Float:vecStart[3], Float:vecEnd[3], Float:v_angle[3], Float:v_forward[3], Float:view_ofs[3], Float:fOrigin[3]
	
	pev(id, pev_origin, fOrigin)
	pev(id, pev_view_ofs, view_ofs)
	xs_vec_add(fOrigin, view_ofs, vecStart)
	pev(id, pev_v_angle, v_angle)
	
	engfunc(EngFunc_MakeVectors, v_angle)
	get_global_vector(GL_v_forward, v_forward)
	
	xs_vec_mul_scalar(v_forward, 0.0, v_forward)
	xs_vec_add(vecStart, v_forward, vecEnd)
	
	engfunc(EngFunc_TraceHull, vecStart, vecEnd, ignored_monster, hull, id, handle)
	
	return FMRES_SUPERCEDE
}

public Create_FakeAttackAnim(id)
{
	Set_BitVar(g_InTempingAttack, id)
	
	static Ent; Ent = fm_get_user_weapon_entity(id, CSW_KNIFE)
	if(pev_valid(Ent)) ExecuteHamB(Ham_Weapon_PrimaryAttack, Ent)
	
	UnSet_BitVar(g_InTempingAttack, id)
}

public fw_Item_Deploy_Post(Ent)
{
	if(pev_valid(Ent) != 2)
		return
	static Id; Id = get_pdata_cbase(Ent, 41, 4)
	if(get_pdata_cbase(Id, 373) != Ent)
		return
	if(!Get_BitVar(g_Had_BlockAR, Id))
		return
	
	remove_task(Id+TASK_CHANGING)
	set_pev(Id, pev_viewmodel2, Get_BitVar(g_LauncherMode, Id) ? MODEL_V2 : MODEL_V)
	set_pev(Id, pev_weaponmodel2, Get_BitVar(g_LauncherMode, Id) ? MODEL_P2 : MODEL_P)
	
	if(!Get_BitVar(g_LauncherMode, Id))
	{
		Set_WeaponAnim(Id, ANIME1_DRAW)
		set_pdata_string(Id, (492) * 4, WEAPON_ANIMEXT_A, -1 , 20)
	} else {
		if(Get_BitVar(g_TenLuaReady, Id)) Set_WeaponAnim(Id, ANIME2_DRAW1)
		else Set_WeaponAnim(Id, ANIME2_DRAW2)
		set_pdata_string(Id, (492) * 4, WEAPON_ANIMEXT_B, -1 , 20)
		
		Set_WeaponIdleTime(Id, CSW_BLOCKAR, 0.75)
	}
}

public fw_Item_AddToPlayer_Post(Ent, id)
{
	if(!pev_valid(Ent))
		return HAM_IGNORED
		
	if(pev(Ent, pev_impulse) == 21062015)
	{
		Set_BitVar(g_Had_BlockAR, id)
		set_pev(Ent, pev_impulse, 0)
		
		static Launcher, TenLuaReady; Launcher = pev(Ent, pev_iuser1); TenLuaReady = pev(Ent, pev_iuser2)
		if(Launcher)
		{
			Set_BitVar(g_LauncherMode, id)
			if(TenLuaReady) Set_BitVar(g_TenLuaReady, id)
		} else {
			UnSet_BitVar(g_LauncherMode, id)
			UnSet_BitVar(g_TenLuaReady, id)
		}
	}
	
	if(Get_BitVar(g_Had_BlockAR, id))
	{
		message_begin(MSG_ONE_UNRELIABLE, g_MsgWeaponList, _, id)
		write_string("weapon_blockar")
		write_byte(4)
		write_byte(200)
		write_byte(-1)
		write_byte(-1)
		write_byte(0)
		write_byte(6)
		write_byte(CSW_BLOCKAR)
		write_byte(0)
		message_end()
	}

	return HAM_HANDLED	
}

public fw_Weapon_WeaponIdle_Post( iEnt )
{
	if(pev_valid(iEnt) != 2)
		return
	static Id; Id = get_pdata_cbase(iEnt, 41, 4)
	if(get_pdata_cbase(Id, 373) != iEnt)
		return
	if(!Get_BitVar(g_Had_BlockAR, Id))
		return
		
	if(get_pdata_float(iEnt, 48, 4) <= 0.25)
	{
		if(!Get_BitVar(g_LauncherMode, Id))
		{
			Set_WeaponAnim(Id, ANIME1_IDLE)
		} else {
			if(Get_BitVar(g_TenLuaReady, Id)) Set_WeaponAnim(Id, ANIME2_IDLE1)
			else Set_WeaponAnim(Id, ANIME2_IDLE2)
		}
		
		set_pdata_float(iEnt, 48, 20.0, 4)
	}	
}

public fw_Item_PostFrame(ent)
{
	static id; id = pev(ent, pev_owner)
	if(!is_alive(id))
		return HAM_IGNORED
	if(!Get_BitVar(g_Had_BlockAR, id))
		return HAM_IGNORED	
	
	static Float:flNextAttack; flNextAttack = get_pdata_float(id, 83, 5)
	static bpammo; bpammo = cs_get_user_bpammo(id, CSW_BLOCKAR)
	
	static iClip; iClip = get_pdata_int(ent, 51, 4)
	static fInReload; fInReload = get_pdata_int(ent, 54, 4)
	
	if(fInReload && flNextAttack <= 0.0)
	{
		static temp1
		temp1 = min(CLIP - iClip, bpammo)

		set_pdata_int(ent, 51, iClip + temp1, 4)
		cs_set_user_bpammo(id, CSW_BLOCKAR, bpammo - temp1)		
		
		set_pdata_int(ent, 54, 0, 4)
		
		fInReload = 0
	}		
	
	return HAM_IGNORED
}

public fw_Weapon_Reload(ent)
{
	static id; id = pev(ent, pev_owner)
	if(!is_alive(id))
		return HAM_IGNORED
	if(!Get_BitVar(g_Had_BlockAR, id))
		return HAM_IGNORED	
	if(Get_BitVar(g_LauncherMode, id))
	{
		set_pdata_int(ent, 54, 0, 4)
		return HAM_SUPERCEDE
	}

	g_Clip[id] = -1
		
	static BPAmmo; BPAmmo = cs_get_user_bpammo(id, CSW_BLOCKAR)
	static iClip; iClip = get_pdata_int(ent, 51, 4)
		
	if(BPAmmo <= 0)
		return HAM_SUPERCEDE
	if(iClip >= CLIP)
		return HAM_SUPERCEDE		
			
	g_Clip[id] = iClip	
	
	return HAM_HANDLED
}

public fw_Weapon_Reload_Post(ent)
{
	static id; id = pev(ent, pev_owner)
	if(!is_alive(id))
		return HAM_IGNORED
	if(!Get_BitVar(g_Had_BlockAR, id))
		return HAM_IGNORED	
	if(Get_BitVar(g_LauncherMode, id))
	{
		set_pdata_int(ent, 54, 0, 4)
		return HAM_SUPERCEDE
	}
		
	if((get_pdata_int(ent, 54, 4) == 1))
	{ // Reload
		if(g_Clip[id] == -1)
			return HAM_IGNORED
		
		set_pdata_int(ent, 51, g_Clip[id], 4)
		Set_WeaponAnim(id, ANIME1_RELOAD)
	}
	
	return HAM_HANDLED
}

public fw_TraceAttack_World(Victim, Attacker, Float:Damage, Float:Direction[3], Ptr, DamageBits)
{
	if(!is_connected(Attacker))
		return HAM_IGNORED	
	if(get_player_weapon(Attacker) != CSW_BLOCKAR || !Get_BitVar(g_Had_BlockAR, Attacker))
		return HAM_IGNORED
		
	static Float:flEnd[3], Float:vecPlane[3]
		
	get_tr2(Ptr, TR_vecEndPos, flEnd)
	get_tr2(Ptr, TR_vecPlaneNormal, vecPlane)		
			
	Make_BulletHole(Attacker, flEnd, Damage)
	Make_BulletSmoke(Attacker, Ptr)

	SetHamParamFloat(3, float(DAMAGE_A))
	
	return HAM_IGNORED
}

public fw_TraceAttack_Player(Victim, Attacker, Float:Damage, Float:Direction[3], Ptr, DamageBits)
{
	if(!is_connected(Attacker))
		return HAM_IGNORED	
	if(get_player_weapon(Attacker) != CSW_BLOCKAR || !Get_BitVar(g_Had_BlockAR, Attacker))
		return HAM_IGNORED
		
	SetHamParamFloat(3, float(DAMAGE_A))
	
	return HAM_IGNORED
}


/* ===============================
------------- SAFETY -------------
=================================*/
public Register_SafetyFunc()
{
	register_event("CurWeapon", "Safety_CurWeapon", "be", "1=1")
	
	RegisterHam(Ham_Spawn, "player", "fw_Safety_Spawn_Post", 1)
	RegisterHam(Ham_Killed, "player", "fw_Safety_Killed_Post", 1)
}

public Register_SafetyFuncBot(id)
{
	RegisterHamFromEntity(Ham_Spawn, id, "fw_Safety_Spawn_Post", 1)
	RegisterHamFromEntity(Ham_Killed, id, "fw_Safety_Killed_Post", 1)
}

public Safety_Connected(id)
{
	Set_BitVar(g_IsConnected, id)
	UnSet_BitVar(g_IsAlive, id)
	
	g_PlayerWeapon[id] = 0
}

public Safety_Disconnected(id)
{
	UnSet_BitVar(g_IsConnected, id)
	UnSet_BitVar(g_IsAlive, id)
	
	g_PlayerWeapon[id] = 0
}

public Safety_CurWeapon(id)
{
	if(!is_alive(id))
		return
		
	static CSW; CSW = read_data(2)
	if(g_PlayerWeapon[id] != CSW) g_PlayerWeapon[id] = CSW
}

public fw_Safety_Spawn_Post(id)
{
	if(!is_user_alive(id))
		return
		
	Set_BitVar(g_IsAlive, id)
}

public fw_Safety_Killed_Post(id)
{
	UnSet_BitVar(g_IsAlive, id)
}

public is_alive(id)
{
	if(!(1 <= id <= 32))
		return 0
	if(!Get_BitVar(g_IsConnected, id))
		return 0
	if(!Get_BitVar(g_IsAlive, id)) 
		return 0
	
	return 1
}

public is_connected(id)
{
	if(!(1 <= id <= 32))
		return 0
	if(!Get_BitVar(g_IsConnected, id))
		return 0
	
	return 1
}

public get_player_weapon(id)
{
	if(!is_alive(id))
		return 0
	
	return g_PlayerWeapon[id]
}

/* ===============================
--------- End of SAFETY ----------
=================================*/

stock Set_WeaponAnim(id, anim)
{
	set_pev(id, pev_weaponanim, anim)
	
	message_begin(MSG_ONE_UNRELIABLE, SVC_WEAPONANIM, {0, 0, 0}, id)
	write_byte(anim)
	write_byte(pev(id, pev_body))
	message_end()
}

stock Eject_Shell(id, Shell_ModelIndex, Float:Time) // By Dias
{
	static Ent; Ent = get_pdata_cbase(id, 373, 5)
	if(!pev_valid(Ent))
		return

        set_pdata_int(Ent, 57, Shell_ModelIndex, 4)
        set_pdata_float(id, 111, get_gametime() + Time)
}

stock Make_BulletHole(id, Float:Origin[3], Float:Damage)
{
	// Find target
	static Decal; Decal = random_num(41, 45)
	static LoopTime; 
	
	if(Damage > 100.0) LoopTime = 2
	else LoopTime = 1
	
	for(new i = 0; i < LoopTime; i++)
	{
		// Put decal on "world" (a wall)
		message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
		write_byte(TE_WORLDDECAL)
		engfunc(EngFunc_WriteCoord, Origin[0])
		engfunc(EngFunc_WriteCoord, Origin[1])
		engfunc(EngFunc_WriteCoord, Origin[2])
		write_byte(Decal)
		message_end()
		
		// Show sparcles
		message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
		write_byte(TE_GUNSHOTDECAL)
		engfunc(EngFunc_WriteCoord, Origin[0])
		engfunc(EngFunc_WriteCoord, Origin[1])
		engfunc(EngFunc_WriteCoord, Origin[2])
		write_short(id)
		write_byte(Decal)
		message_end()
	}
}

stock Make_BulletSmoke(id, TrResult)
{
	static Float:vecSrc[3], Float:vecEnd[3], TE_FLAG
	
	get_weapon_attachment(id, vecSrc)
	global_get(glb_v_forward, vecEnd)
    
	xs_vec_mul_scalar(vecEnd, 8192.0, vecEnd)
	xs_vec_add(vecSrc, vecEnd, vecEnd)

	get_tr2(TrResult, TR_vecEndPos, vecSrc)
	get_tr2(TrResult, TR_vecPlaneNormal, vecEnd)
    
	xs_vec_mul_scalar(vecEnd, 2.5, vecEnd)
	xs_vec_add(vecSrc, vecEnd, vecEnd)
    
	TE_FLAG |= TE_EXPLFLAG_NODLIGHTS
	TE_FLAG |= TE_EXPLFLAG_NOSOUND
	TE_FLAG |= TE_EXPLFLAG_NOPARTICLES
	
	engfunc(EngFunc_MessageBegin, MSG_PAS, SVC_TEMPENTITY, vecEnd, 0)
	write_byte(TE_EXPLOSION)
	engfunc(EngFunc_WriteCoord, vecEnd[0])
	engfunc(EngFunc_WriteCoord, vecEnd[1])
	engfunc(EngFunc_WriteCoord, vecEnd[2] - 10.0)
	write_short(g_SmokePuff_SprId)
	write_byte(2)
	write_byte(50)
	write_byte(TE_FLAG)
	message_end()
}

stock get_weapon_attachment(id, Float:output[3], Float:fDis = 40.0)
{ 
	static Float:vfEnd[3], viEnd[3] 
	get_user_origin(id, viEnd, 3)  
	IVecFVec(viEnd, vfEnd) 
	
	static Float:fOrigin[3], Float:fAngle[3]
	
	pev(id, pev_origin, fOrigin) 
	pev(id, pev_view_ofs, fAngle)
	
	xs_vec_add(fOrigin, fAngle, fOrigin) 
	
	static Float:fAttack[3]
	
	xs_vec_sub(vfEnd, fOrigin, fAttack)
	xs_vec_sub(vfEnd, fOrigin, fAttack) 
	
	static Float:fRate
	
	fRate = fDis / vector_length(fAttack)
	xs_vec_mul_scalar(fAttack, fRate, fAttack)
	
	xs_vec_add(fOrigin, fAttack, output)
}

stock get_position(id,Float:forw, Float:right, Float:up, Float:vStart[])
{
	new Float:vOrigin[3], Float:vAngle[3], Float:vForward[3], Float:vRight[3], Float:vUp[3]
	
	pev(id, pev_origin, vOrigin)
	pev(id, pev_view_ofs,vUp) //for player
	xs_vec_add(vOrigin,vUp,vOrigin)
	pev(id, pev_v_angle, vAngle) // if normal entity ,use pev_angles
	
	angle_vector(vAngle,ANGLEVECTOR_FORWARD,vForward) //or use EngFunc_AngleVectors
	angle_vector(vAngle,ANGLEVECTOR_RIGHT,vRight)
	angle_vector(vAngle,ANGLEVECTOR_UP,vUp)
	
	vStart[0] = vOrigin[0] + vForward[0] * forw + vRight[0] * right + vUp[0] * up
	vStart[1] = vOrigin[1] + vForward[1] * forw + vRight[1] * right + vUp[1] * up
	vStart[2] = vOrigin[2] + vForward[2] * forw + vRight[2] * right + vUp[2] * up
}

stock get_speed_vector(const Float:origin1[3],const Float:origin2[3],Float:speed, Float:new_velocity[3])
{
	new_velocity[0] = origin2[0] - origin1[0]
	new_velocity[1] = origin2[1] - origin1[1]
	new_velocity[2] = origin2[2] - origin1[2]
	new Float:num = floatsqroot(speed*speed / (new_velocity[0]*new_velocity[0] + new_velocity[1]*new_velocity[1] + new_velocity[2]*new_velocity[2]))
	new_velocity[0] *= num
	new_velocity[1] *= num
	new_velocity[2] *= num
	
	return 1;
}

stock Set_WeaponIdleTime(id, WeaponId ,Float:TimeIdle)
{
	static entwpn; entwpn = fm_get_user_weapon_entity(id, WeaponId)
	if(!pev_valid(entwpn)) 
		return
		
	set_pdata_float(entwpn, 46, TimeIdle, 4)
	set_pdata_float(entwpn, 47, TimeIdle, 4)
	set_pdata_float(entwpn, 48, TimeIdle + 0.5, 4)
}

stock Set_PlayerNextAttack(id, Float:nexttime)
{
	set_pdata_float(id, 83, nexttime, 5)
}
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang1042\\ f0\\ fs16 \n\\ par }
*/
