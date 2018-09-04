#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <cstrike>

#define PLUGIN "[CSO] Weapon: JANUS-I"
#define VERSION "1.0"
#define AUTHOR "Dias Pendragon"

#define DAMAGE_A 150 // Damage in Non-Charged Mode
#define DAMAGE_B 300 // Damage in Charged Mode
#define CHARGE_TIME 7 // Time Use for Janus Transform System

#define CHANGE_TIME 2.0
#define LIGHTNING_RANGE 500.0
#define LIGHTNING_HEADSHOTABLE 1 // Can deal Headshot

#define CSW_Janus1 CSW_DEAGLE
#define weapon_Janus1 "weapon_deagle"
#define PLAYER_ANIMEXT "onehanded"
#define Janus1_OLDMODEL "models/w_deagle.mdl"

#define V_MODEL "models/v_janus1.mdl"
#define P_MODEL "models/p_janus1.mdl"
#define W_MODEL "models/w_janus1.mdl"
#define S_MODEL "models/s_oicw.mdl"

#define TASK_CHANGE 4263
#define TASK_CHANGELIMITTIME 54354
#define TASK_USETIME 34547

new const Janus1_Sounds[6][] = 
{
	"weapons/janus1-1.wav",
	"weapons/janus1-2.wav",
	"weapons/change1_ready.wav",
	"weapons/janus1_exp.wav",
	"weapons/janus1_change1.wav",
	"weapons/janus1_change2.wav"
}

new const Janus1_Resources[4][] = 
{
	"sprites/weapon_janus1.txt",
	"sprites/640hud7_2.spr",
	"sprites/640hud12_2.spr",
	"sprites/640hud100_2.spr"
}

enum
{
	J1_ANIM_IDLE = 0,
	J1_ANIM_DRAW,
	J1_ANIM_SHOOT1,
	J1_ANIM_SHOOT1_2,
	J1_ANIM_SHOOT1_ACTIVE,
	J1_ANIM_CHANGE_TO_JANUS,
	J1_ANIM_IDLE_JANUS,
	J1_ANIM_DRAW_JANUS,
	J1_ANIM_SHOOT1_JANUS,
	J1_ANIM_SHOOT2_JANUS,
	J1_ANIM_CHANGE_TO_BACK,
	J1_ANIM_IDLE_ACTIVE,
	J1_ANIM_DRAW_ACTIVE
}

enum
{
	Janus1_NORMAL = 0,
	Janus1_ACTIVE,
	Janus1_JANUS
}

// MACROS
#define Get_BitVar(%1,%2) (%1 & (1 << (%2 & 31)))
#define Set_BitVar(%1,%2) %1 |= (1 << (%2 & 31))
#define UnSet_BitVar(%1,%2) %1 &= ~(1 << (%2 & 31))

const PRIMARY_WEAPONS_BIT_SUM = (1<<CSW_SCOUT)|(1<<CSW_XM1014)|(1<<CSW_MAC10)|(1<<CSW_AUG)|(1<<CSW_UMP45)|(1<<CSW_SG550)|(1<<CSW_GALIL)|(1<<CSW_FAMAS)|(1<<CSW_AWP)|(1<<CSW_MP5NAVY)|(1<<CSW_M249)|(1<<CSW_M3)|(1<<CSW_M4A1)|(1<<CSW_TMP)|(1<<CSW_G3SG1)|(1<<CSW_SG552)|(1<<CSW_AK47)|(1<<CSW_P90)
const SECONDARY_WEAPONS_BIT_SUM = (1<<CSW_P228)|(1<<CSW_ELITE)|(1<<CSW_FIVESEVEN)|(1<<CSW_USP)|(1<<CSW_GLOCK18)|(1<<CSW_DEAGLE)

new g_Had_Janus1, g_Janus1_Mode[33], g_ChangingMode, g_expspr_id , g_SmokeSprId
new g_Event_Janus1, g_Msg_WeaponList, g_ham_bot, g_MaxPlayers, spr_trail

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	register_event("CurWeapon", "Event_CurWeapon", "be", "1=1", "2=26")
	register_touch("grenade2", "*", "fw_GrenadeTouch")
	
	register_forward(FM_UpdateClientData,"fw_UpdateClientData_Post", 1)	
	register_forward(FM_PlaybackEvent, "fw_PlaybackEvent")	
	register_forward(FM_SetModel, "fw_SetModel")	
	register_forward(FM_CmdStart, "fw_CmdStart")
	
	RegisterHam(Ham_Weapon_WeaponIdle, weapon_Janus1, "fw_Weapon_WeaponIdle_Post", 1)
	RegisterHam(Ham_Item_Deploy, weapon_Janus1, "fw_Item_Deploy_Post", 1)	
	RegisterHam(Ham_Item_AddToPlayer, weapon_Janus1, "fw_Item_AddToPlayer_Post", 1)
	
	g_Msg_WeaponList = get_user_msgid("WeaponList")
	g_MaxPlayers = get_maxplayers()
	 
	register_clcmd("admin_get_janus1", "Get_Janus1")
	register_clcmd("weapon_janus1", "Hook_Weapon")
}

public plugin_precache()
{
	engfunc(EngFunc_PrecacheModel, V_MODEL)
	engfunc(EngFunc_PrecacheModel, P_MODEL)
	engfunc(EngFunc_PrecacheModel, W_MODEL)
	precache_model(S_MODEL)
	
	new i
	for(i = 0; i < sizeof(Janus1_Sounds); i++)
		engfunc(EngFunc_PrecacheSound, Janus1_Sounds[i])
	for(i = 0; i < sizeof(Janus1_Resources); i++)
	{
		if(i == 0) engfunc(EngFunc_PrecacheGeneric, Janus1_Resources[i])
		else engfunc(EngFunc_PrecacheModel, Janus1_Resources[i])
	}
	
	spr_trail = engfunc(EngFunc_PrecacheModel, "sprites/laserbeam.spr")
	g_expspr_id = engfunc(EngFunc_PrecacheModel, "sprites/zerogxplode.spr")
	g_SmokeSprId = engfunc(EngFunc_PrecacheModel, "sprites/steam1.spr")
	
	register_forward(FM_PrecacheEvent, "fw_PrecacheEvent_Post", 1)
}

public fw_PrecacheEvent_Post(type, const name[])
{
	if(equal("events/deagle.sc", name)) g_Event_Janus1 = get_orig_retval()		
}

public client_putinserver(id)
{
	if(!g_ham_bot && is_user_bot(id))
	{
		g_ham_bot = 1
		set_task(0.1, "Do_Register_HamBot", id)
	}
}

public Do_Register_HamBot(id)
{
	RegisterHamFromEntity(Ham_TraceAttack, id, "fw_TraceAttack_Player")
}

public Get_Janus1(id)
{
	if(!is_user_alive(id))
		return
		
	drop_weapons(id, 1)
		
	g_Janus1_Mode[id] = Janus1_NORMAL
	
	Set_BitVar(g_Had_Janus1, id)
	UnSet_BitVar(g_ChangingMode, id)
	fm_give_item(id, weapon_Janus1)
	
	cs_set_user_bpammo(id, CSW_Janus1, 5)
	
	engfunc(EngFunc_MessageBegin, MSG_ONE_UNRELIABLE, get_user_msgid("CurWeapon"), {0, 0, 0}, id)
	write_byte(1)
	write_byte(CSW_Janus1)
	write_byte(-1)
	message_end()
}

public Remove_Janus1(id)
{
	g_Janus1_Mode[id] = Janus1_NORMAL
	
	UnSet_BitVar(g_Had_Janus1, id)
	UnSet_BitVar(g_ChangingMode, id)
	
	remove_task(id+TASK_CHANGE)
	remove_task(id+TASK_CHANGELIMITTIME)
	remove_task(id+TASK_USETIME)
}

public Hook_Weapon(id)
{
	engclient_cmd(id, weapon_Janus1)
	return PLUGIN_HANDLED
}

public Event_CurWeapon(id)
{
	if(!is_user_alive(id))
		return
	if(!Get_BitVar(g_Had_Janus1, id))
		return
		
	engfunc(EngFunc_MessageBegin, MSG_ONE_UNRELIABLE, get_user_msgid("CurWeapon"), {0, 0, 0}, id)
	write_byte(1)
	write_byte(CSW_Janus1)
	write_byte(-1)
	message_end()
}

public fw_UpdateClientData_Post(id, sendweapons, cd_handle)
{
	if(!is_user_alive(id) || !is_user_connected(id))
		return FMRES_IGNORED	
	if(get_user_weapon(id) == CSW_Janus1 && Get_BitVar(g_Had_Janus1, id))
		set_cd(cd_handle, CD_flNextAttack, get_gametime() + 0.001) 
	
	return FMRES_HANDLED
}

public fw_PlaybackEvent(flags, invoker, eventid, Float:delay, Float:origin[3], Float:angles[3], Float:fparam1, Float:fparam2, iParam1, iParam2, bParam1, bParam2)
{
	if (!is_user_connected(invoker))
		return FMRES_IGNORED	
	if(get_user_weapon(invoker) != CSW_Janus1 || !Get_BitVar(g_Had_Janus1, invoker))
		return FMRES_IGNORED
	if(eventid != g_Event_Janus1)
		return FMRES_IGNORED
	
	return FMRES_IGNORED
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
	
	if(equal(model, Janus1_OLDMODEL))
	{
		static weapon; weapon = fm_find_ent_by_owner(-1, weapon_Janus1, entity)
		
		if(!pev_valid(weapon))
			return FMRES_IGNORED;
		
		if(Get_BitVar(g_Had_Janus1, iOwner))
		{
			Remove_Janus1(iOwner)
			
			set_pev(weapon, pev_impulse, 18012014)
			engfunc(EngFunc_SetModel, entity, W_MODEL)
			
			return FMRES_SUPERCEDE
		}
	}

	return FMRES_IGNORED;
}

public fw_CmdStart(id, uc_handle, seed)
{
	if(!is_user_alive(id))
		return FMRES_IGNORED	
	if(!Get_BitVar(g_Had_Janus1, id) || get_user_weapon(id) != CSW_Janus1)	
		return FMRES_IGNORED
		
	static PressButton; PressButton = get_uc(uc_handle, UC_Buttons)
	
	if((PressButton & IN_ATTACK))
	{
		PressButton &= ~IN_ATTACK
		set_uc(uc_handle, UC_Buttons, PressButton)
		
		if(Get_BitVar(g_ChangingMode, id))
			return FMRES_IGNORED
		if(get_pdata_float(id, 83, 5) > 0.0)
			return FMRES_IGNORED
		
		if(g_Janus1_Mode[id] != Janus1_JANUS)
		{ // Normal
			if(cs_get_user_bpammo(id, CSW_Janus1) <= 0)
			{
				set_pdata_float(id, 83, 0.5, 5)
				return FMRES_IGNORED
			}
			
			set_weapon_anim(id, J1_ANIM_SHOOT1)
			emit_sound(id, CHAN_WEAPON, Janus1_Sounds[0], 1.0, ATTN_NORM, 0, PITCH_NORM)
			Set_Player_NextAttack(id, CSW_Janus1, 2.5)
			
			cs_set_user_bpammo(id, CSW_Janus1, cs_get_user_bpammo(id, CSW_Janus1) - 1)
			Make_ShootEffect(id)
			Make_GrenadeAmmo(id)
			
			if(cs_get_user_bpammo(id, CSW_Janus1) <= 0)
			{
				g_Janus1_Mode[id] = Janus1_ACTIVE
				emit_sound(id, CHAN_WEAPON, Janus1_Sounds[2], 1.0, ATTN_NORM, 0, PITCH_NORM)
			}
		} else if(g_Janus1_Mode[id] == Janus1_ACTIVE) { // Ready Mode
			if(cs_get_user_bpammo(id, CSW_Janus1) <= 0)
			{
				set_pdata_float(id, 83, 0.5, 5)
				return FMRES_IGNORED
			}
			
			set_weapon_anim(id, J1_ANIM_SHOOT1_ACTIVE)
			emit_sound(id, CHAN_WEAPON, Janus1_Sounds[0], 1.0, ATTN_NORM, 0, PITCH_NORM)
			Set_Player_NextAttack(id, CSW_Janus1, 2.5)
			
			cs_set_user_bpammo(id, CSW_Janus1, cs_get_user_bpammo(id, CSW_Janus1) - 1)
			Make_ShootEffect(id)
			Make_GrenadeAmmo(id)
		} else { // JTS Mode
			set_weapon_anim(id, J1_ANIM_SHOOT1_JANUS)
			emit_sound(id, CHAN_WEAPON, Janus1_Sounds[1], 1.0, ATTN_NORM, 0, PITCH_NORM)
			Set_Player_NextAttack(id, CSW_Janus1, 0.25)
			
			Make_ShootEffect(id)
			Make_GrenadeAmmo(id)
		}
		
		return FMRES_IGNORED
	}
	
	if((PressButton & IN_RELOAD))
		return FMRES_SUPERCEDE
	
	if((PressButton & IN_ATTACK2))
	{
		PressButton &= ~IN_ATTACK2
		set_uc(uc_handle, UC_Buttons, PressButton)
		
		if((pev(id, pev_oldbuttons) & IN_ATTACK2))
			return FMRES_IGNORED
		if(g_Janus1_Mode[id] != Janus1_ACTIVE)
			return FMRES_IGNORED
		if(get_pdata_float(id, 83, 5) > 0.0)
			return FMRES_IGNORED
		
		remove_task(id+TASK_CHANGELIMITTIME)
		
		Set_BitVar(g_ChangingMode, id)
		Set_Player_NextAttack(id, CSW_Janus1, CHANGE_TIME)
		
		set_weapon_anim(id, J1_ANIM_CHANGE_TO_JANUS)
		set_task(CHANGE_TIME, "ChangeTo_JanusTransform", id+TASK_CHANGE)
	}
	
	return FMRES_IGNORED
}

public Make_GrenadeAmmo(id)
{
	Create_Grenade(id)
}

public Make_ShootEffect(id)
{
	static Float:Angles[3]
	pev(id, pev_punchangle, Angles)
	
	Angles[0] += random_float(-1.5, 0.0)
	Angles[1] += random_float(-0.75, 0.75)
	
	set_pev(id, pev_punchangle, Angles)
}

public Create_Grenade(id)
{
	static Ent; Ent = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"))
	if(!pev_valid(Ent)) return
	
	static Float:Origin[3], Float:Angles[3]
	
	get_weapon_attachment(id, Origin, 24.0)
	pev(id, pev_v_angle, Angles)
	
	set_pev(Ent, pev_movetype, MOVETYPE_PUSHSTEP)
	set_pev(Ent, pev_solid, SOLID_BBOX)
	
	set_pev(Ent, pev_classname, "grenade2")
	engfunc(EngFunc_SetModel, Ent, S_MODEL)
	set_pev(Ent, pev_origin, Origin)
	set_pev(Ent, pev_angles, Angles)
	set_pev(Ent, pev_owner, id)
	
	// Create Velocity
	static Float:Velocity[3], Float:TargetOrigin[3]
	
	fm_get_aim_origin(id, TargetOrigin)
	get_speed_vector(Origin, TargetOrigin, 1300.0, Velocity)
	
	set_pev(Ent, pev_velocity, Velocity)
	
	// Make a Beam
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_BEAMFOLLOW)
	write_short(Ent) // entity
	write_short(spr_trail) // sprite
	write_byte(15)  // life
	write_byte(2)  // width
	write_byte(100) // r
	write_byte(100);  // g
	write_byte(100);  // b
	write_byte(250); // brightness
	message_end();
}


public fw_GrenadeTouch(Ent, Id)
{
	if(!pev_valid(Ent))
		return
		
	Make_Explosion(Ent)
	engfunc(EngFunc_RemoveEntity, Ent)
}

public Make_Explosion(ent)
{
	static Float:Origin[3]
	pev(ent, pev_origin, Origin)
	
	message_begin(MSG_BROADCAST ,SVC_TEMPENTITY)
	write_byte(TE_EXPLOSION)
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2])
	write_short(g_expspr_id)	// sprite index
	write_byte(30)	// scale in 0.1's
	write_byte(20)	// framerate
	write_byte(0)	// flags
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
	write_byte(40)	// scale in 0.1's 
	write_byte(10)	// framerate 
	message_end()
	
	static Float:Origin2[3], id
	id = pev(ent, pev_owner)
	
	if(!is_user_alive(id))
		return
	
	for(new i = 0; i < g_MaxPlayers; i++)
	{
		if(!is_user_alive(i))
			continue
		pev(i, pev_origin, Origin2)
		if(get_distance_f(Origin, Origin2) > float(200))
			continue
		if(cs_get_user_team(id) == cs_get_user_team(i))
			continue

		static TakeDamage; TakeDamage = LIGHTNING_HEADSHOTABLE
		if(!TakeDamage) ExecuteHamB(Ham_TakeDamage, i, 0, id, g_Janus1_Mode[id] == Janus1_JANUS ? float(DAMAGE_B) : float(DAMAGE_A), DMG_BLAST)
		else do_attack(id, i, 0, g_Janus1_Mode[id] == Janus1_JANUS ? float(DAMAGE_B) : float(DAMAGE_A))
	}
}

public ChangeTo_JanusTransform(id)
{
	id -= TASK_CHANGE
	
	if(!is_user_alive(id))
		return
	if(get_user_weapon(id) != CSW_Janus1 || !Get_BitVar(g_Had_Janus1, id))	
		return
	if(!Get_BitVar(g_ChangingMode, id))
		return
		
	UnSet_BitVar(g_ChangingMode, id)
	g_Janus1_Mode[id] = Janus1_JANUS
	
	set_weapon_anim(id, J1_ANIM_IDLE_JANUS)
	
	remove_task(id+TASK_USETIME)
	set_task(float(CHARGE_TIME), "TurnOff_JTS2", id+TASK_USETIME)
}

public TurnOff_JTS2(id)
{
	id -= TASK_USETIME
	
	if(!is_user_alive(id))
		return
	g_Janus1_Mode[id] = Janus1_NORMAL
	if(get_user_weapon(id) != CSW_Janus1 || !Get_BitVar(g_Had_Janus1, id))	
		return
	if(g_Janus1_Mode[id] != Janus1_JANUS)
		return
		
	Set_BitVar(g_ChangingMode, id)
	Set_Player_NextAttack(id, CSW_Janus1, CHANGE_TIME - 1.0)
		
	set_weapon_anim(id, J1_ANIM_CHANGE_TO_BACK)
	set_task(CHANGE_TIME - 1.0, "ChangeTo_Back", id+TASK_CHANGE)
}

public ChangeTo_Back(id)
{
	id -= TASK_CHANGE
	
	if(!is_user_alive(id))
		return
	g_Janus1_Mode[id] = Janus1_NORMAL
	if(get_user_weapon(id) != CSW_Janus1 || !Get_BitVar(g_Had_Janus1, id))	
		return
	if(g_Janus1_Mode[id] != Janus1_JANUS)
		return
		
	g_Janus1_Mode[id] = Janus1_NORMAL
}

public fw_Weapon_WeaponIdle_Post(Ent)
{
	if(pev_valid(Ent) != 2)
		return HAM_IGNORED	
	static Id; Id = get_pdata_cbase(Ent, 41, 4)
	if(get_pdata_cbase(Id, 373) != Ent)
		return HAM_IGNORED	
	if(!Get_BitVar(g_Had_Janus1, Id))
		return HAM_IGNORED	
		
	if(get_pdata_float(Ent, 48, 4) <= 0.1) 
	{
		if(g_Janus1_Mode[Id] == Janus1_NORMAL) set_weapon_anim(Id, J1_ANIM_IDLE)
		else if(g_Janus1_Mode[Id] == Janus1_ACTIVE) set_weapon_anim(Id, J1_ANIM_IDLE_ACTIVE)
		else if(g_Janus1_Mode[Id] == Janus1_JANUS) set_weapon_anim(Id, J1_ANIM_IDLE_JANUS)
		
		set_pdata_float(Ent, 48, 20.0, 4)
		set_pdata_string(Id, (492) * 4, PLAYER_ANIMEXT, -1 , 20)
	}
	
	return HAM_IGNORED	
}

public fw_Item_Deploy_Post(Ent)
{
	if(pev_valid(Ent) != 2)
		return
	static Id; Id = get_pdata_cbase(Ent, 41, 4)
	if(get_pdata_cbase(Id, 373) != Ent)
		return
	if(!Get_BitVar(g_Had_Janus1, Id))
		return
	
	set_pev(Id, pev_viewmodel2, V_MODEL)
	set_pev(Id, pev_weaponmodel2, P_MODEL)
	
	if(g_Janus1_Mode[Id] == Janus1_NORMAL) set_weapon_anim(Id, J1_ANIM_DRAW)
	else if(g_Janus1_Mode[Id] == Janus1_ACTIVE) set_weapon_anim(Id, J1_ANIM_DRAW_ACTIVE)
	else if(g_Janus1_Mode[Id] == Janus1_JANUS) set_weapon_anim(Id, J1_ANIM_DRAW_JANUS)
}

public fw_Item_AddToPlayer_Post(Ent, id)
{
	if(!pev_valid(Ent))
		return HAM_IGNORED
		
	if(pev(Ent, pev_impulse) == 18012014)
	{
		Set_BitVar(g_Had_Janus1, id)
		set_pev(Ent, pev_impulse, 0)
	}		
	
	message_begin(MSG_ONE_UNRELIABLE, g_Msg_WeaponList, .player = id)
	write_string(Get_BitVar(g_Had_Janus1, id) ? "weapon_janus1" : "weapon_deagle")
	write_byte(8) // PrimaryAmmoID
	write_byte(35) // PrimaryAmmoMaxAmount
	write_byte(-1) // SecondaryAmmoID
	write_byte(-1) // SecondaryAmmoMaxAmount
	write_byte(1) // SlotID (0...N)
	write_byte(1) // NumberInSlot (1...N)
	write_byte(Get_BitVar(g_Had_Janus1, id) ? CSW_Janus1 : CSW_DEAGLE) // WeaponID
	write_byte(0) // Flags
	message_end()

	return HAM_HANDLED	
}

public TurnOff_JTS(id)
{
	id -= TASK_CHANGELIMITTIME
	if(!is_user_alive(id))
		return
		
	g_Janus1_Mode[id] = Janus1_NORMAL
	
	set_weapon_anim(id, J1_ANIM_IDLE)
}

public Give_RealAmmo(id, CSWID)
{
	static Amount, Max
	switch(CSWID)
	{
		case CSW_P228: {Amount = 10; Max = 104;}
		case CSW_SCOUT: {Amount = 6; Max = 180;}
		case CSW_XM1014: {Amount = 8; Max = 64;}
		case CSW_MAC10: {Amount = 16; Max = 200;}
		case CSW_AUG: {Amount = 6; Max = 180;}
		case CSW_ELITE: {Amount = 16; Max = 200;}
		case CSW_FIVESEVEN: {Amount = 4; Max = 200;}
		case CSW_UMP45: {Amount = 16; Max = 200;}
		case CSW_SG550: {Amount = 6; Max = 180;}
		case CSW_GALIL: {Amount = 6; Max = 180;}
		case CSW_FAMAS: {Amount = 6; Max = 180;}
		case CSW_USP: {Amount = 18; Max = 200;}
		case CSW_GLOCK18: {Amount = 16; Max = 200;}
		case CSW_AWP: {Amount = 6; Max = 60;}
		case CSW_MP5NAVY: {Amount = 16; Max = 200;}
		case CSW_M249: {Amount = 4; Max = 200;}
		case CSW_M3: {Amount = 8; Max = 64;}
		case CSW_M4A1: {Amount = 7; Max = 180;}
		case CSW_TMP: {Amount = 7; Max = 200;}
		case CSW_G3SG1: {Amount = 7; Max = 180;}
		case CSW_DEAGLE: {Amount = 10; Max = 70;}
		case CSW_SG552: {Amount = 7; Max = 180;}
		case CSW_AK47: {Amount = 7; Max = 180;}
		case CSW_P90: {Amount = 4; Max = 200;}
		default: {Amount = 3; Max = 200;}
	}

	for(new i = 0; i < Amount; i++) give_ammo(id, 0, CSWID, Max)
}

public give_ammo(id, silent, CSWID, Max)
{
	static Amount, Name[32]
		
	switch(CSWID)
	{
		case CSW_P228: {Amount = 13; formatex(Name, sizeof(Name), "357sig");}
		case CSW_SCOUT: {Amount = 30; formatex(Name, sizeof(Name), "762nato");}
		case CSW_XM1014: {Amount = 8; formatex(Name, sizeof(Name), "buckshot");}
		case CSW_MAC10: {Amount = 12; formatex(Name, sizeof(Name), "45acp");}
		case CSW_AUG: {Amount = 30; formatex(Name, sizeof(Name), "556nato");}
		case CSW_ELITE: {Amount = 30; formatex(Name, sizeof(Name), "9mm");}
		case CSW_FIVESEVEN: {Amount = 50; formatex(Name, sizeof(Name), "57mm");}
		case CSW_UMP45: {Amount = 12; formatex(Name, sizeof(Name), "45acp");}
		case CSW_SG550: {Amount = 30; formatex(Name, sizeof(Name), "556nato");}
		case CSW_GALIL: {Amount = 30; formatex(Name, sizeof(Name), "556nato");}
		case CSW_FAMAS: {Amount = 30; formatex(Name, sizeof(Name), "556nato");}
		case CSW_USP: {Amount = 12; formatex(Name, sizeof(Name), "45acp");}
		case CSW_GLOCK18: {Amount = 30; formatex(Name, sizeof(Name), "9mm");}
		case CSW_AWP: {Amount = 10; formatex(Name, sizeof(Name), "338magnum");}
		case CSW_MP5NAVY: {Amount = 30; formatex(Name, sizeof(Name), "9mm");}
		case CSW_M249: {Amount = 30; formatex(Name, sizeof(Name), "556natobox");}
		case CSW_M3: {Amount = 8; formatex(Name, sizeof(Name), "buckshot");}
		case CSW_M4A1: {Amount = 30; formatex(Name, sizeof(Name), "556nato");}
		case CSW_TMP: {Amount = 30; formatex(Name, sizeof(Name), "9mm");}
		case CSW_G3SG1: {Amount = 30; formatex(Name, sizeof(Name), "762nato");}
		case CSW_DEAGLE: {Amount = 7; formatex(Name, sizeof(Name), "50ae");}
		case CSW_SG552: {Amount = 30; formatex(Name, sizeof(Name), "556nato");}
		case CSW_AK47: {Amount = 30; formatex(Name, sizeof(Name), "762nato");}
		case CSW_P90: {Amount = 50; formatex(Name, sizeof(Name), "57mm");}
	}
	
	if(!silent) emit_sound(id, CHAN_ITEM, "items/9mmclip1.wav", VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	ExecuteHamB(Ham_GiveAmmo, id, Amount, Name, Max)
}

stock Eject_Shell(id, Shell_ModelIndex, Float:Time) // By Dias
{
	static Ent; Ent = get_pdata_cbase(id, 373, 5)
	if(!pev_valid(Ent))
		return

        set_pdata_int(Ent, 57, Shell_ModelIndex, 4)
        set_pdata_float(id, 111, get_gametime() + Time)
}

// Drop primary/secondary weapons
stock drop_weapons(id, dropwhat)
{
	// Get user weapons
	static weapons[32], num, i, weaponid
	num = 0 // reset passed weapons count (bugfix)
	get_user_weapons(id, weapons, num)
	
	// Loop through them and drop primaries or secondaries
	for (i = 0; i < num; i++)
	{
		// Prevent re-indexing the array
		weaponid = weapons[i]
		
		if ((dropwhat == 1 && ((1<<weaponid) & PRIMARY_WEAPONS_BIT_SUM)) || (dropwhat == 2 && ((1<<weaponid) & SECONDARY_WEAPONS_BIT_SUM)))
		{
			// Get weapon entity
			static wname[32]; get_weaponname(weaponid, wname, charsmax(wname))
			engclient_cmd(id, "drop", wname)
		}
	}
}

stock set_weapon_anim(id, anim)
{
	set_pev(id, pev_weaponanim, anim)
	
	message_begin(MSG_ONE_UNRELIABLE, SVC_WEAPONANIM, {0, 0, 0}, id)
	write_byte(anim)
	write_byte(pev(id, pev_body))
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

stock Set_Player_NextAttack(id, CSWID, Float:NextTime)
{
	static Ent; Ent = fm_get_user_weapon_entity(id, CSWID)
	if(!pev_valid(Ent)) return
	
	set_pdata_float(id, 83, NextTime, 5)
	
	set_pdata_float(Ent, 46 , NextTime, 4)
	set_pdata_float(Ent, 47, NextTime, 4)
	set_pdata_float(Ent, 48, NextTime, 4)
}

do_attack(Attacker, Victim, Inflictor, Float:fDamage)
{
	fake_player_trace_attack(Attacker, Victim, fDamage)
	fake_take_damage(Attacker, Victim, fDamage, Inflictor)
}

fake_player_trace_attack(iAttacker, iVictim, &Float:fDamage)
{
	// get fDirection
	static Float:fAngles[3], Float:fDirection[3]
	pev(iAttacker, pev_angles, fAngles)
	angle_vector(fAngles, ANGLEVECTOR_FORWARD, fDirection)
	
	// get fStart
	static Float:fStart[3], Float:fViewOfs[3]
	pev(iAttacker, pev_origin, fStart)
	pev(iAttacker, pev_view_ofs, fViewOfs)
	xs_vec_add(fViewOfs, fStart, fStart)
	
	// get aimOrigin
	static iAimOrigin[3], Float:fAimOrigin[3]
	get_user_origin(iAttacker, iAimOrigin, 3)
	IVecFVec(iAimOrigin, fAimOrigin)
	
	// TraceLine from fStart to AimOrigin
	static ptr; ptr = create_tr2() 
	engfunc(EngFunc_TraceLine, fStart, fAimOrigin, DONT_IGNORE_MONSTERS, iAttacker, ptr)
	static pHit; pHit = get_tr2(ptr, TR_pHit)
	static iHitgroup; iHitgroup = get_tr2(ptr, TR_iHitgroup)
	static Float:fEndPos[3]
	get_tr2(ptr, TR_vecEndPos, fEndPos)

	// get target & body at aiming
	static iTarget, iBody
	get_user_aiming(iAttacker, iTarget, iBody)
	
	// if aiming find target is iVictim then update iHitgroup
	if (iTarget == iVictim)
	{
		iHitgroup = iBody
	}
	
	// if ptr find target not is iVictim
	else if (pHit != iVictim)
	{
		// get AimOrigin in iVictim
		static Float:fVicOrigin[3], Float:fVicViewOfs[3], Float:fAimInVictim[3]
		pev(iVictim, pev_origin, fVicOrigin)
		pev(iVictim, pev_view_ofs, fVicViewOfs) 
		xs_vec_add(fVicViewOfs, fVicOrigin, fAimInVictim)
		fAimInVictim[2] = fStart[2]
		fAimInVictim[2] += get_distance_f(fStart, fAimInVictim) * floattan( fAngles[0] * 2.0, degrees )
		
		// check aim in size of iVictim
		static iAngleToVictim; iAngleToVictim = get_angle_to_target(iAttacker, fVicOrigin)
		iAngleToVictim = abs(iAngleToVictim)
		static Float:fDis; fDis = 2.0 * get_distance_f(fStart, fAimInVictim) * floatsin( float(iAngleToVictim) * 0.5, degrees )
		static Float:fVicSize[3]
		pev(iVictim, pev_size , fVicSize)
		if ( fDis <= fVicSize[0] * 0.5 )
		{
			// TraceLine from fStart to aimOrigin in iVictim
			static ptr2; ptr2 = create_tr2() 
			engfunc(EngFunc_TraceLine, fStart, fAimInVictim, DONT_IGNORE_MONSTERS, iAttacker, ptr2)
			static pHit2; pHit2 = get_tr2(ptr2, TR_pHit)
			static iHitgroup2; iHitgroup2 = get_tr2(ptr2, TR_iHitgroup)
			
			// if ptr2 find target is iVictim
			if ( pHit2 == iVictim && (iHitgroup2 != HIT_HEAD || fDis <= fVicSize[0] * 0.25) )
			{
				pHit = iVictim
				iHitgroup = iHitgroup2
				get_tr2(ptr2, TR_vecEndPos, fEndPos)
			}
			
			free_tr2(ptr2)
		}
		
		// if pHit still not is iVictim then set default HitGroup
		if (pHit != iVictim)
		{
			// set default iHitgroup
			iHitgroup = HIT_GENERIC
			
			static ptr3; ptr3 = create_tr2() 
			engfunc(EngFunc_TraceLine, fStart, fVicOrigin, DONT_IGNORE_MONSTERS, iAttacker, ptr3)
			get_tr2(ptr3, TR_vecEndPos, fEndPos)
			
			// free ptr3
			free_tr2(ptr3)
		}
	}
	
	// set new Hit & Hitgroup & EndPos
	set_tr2(ptr, TR_pHit, iVictim)
	set_tr2(ptr, TR_iHitgroup, iHitgroup)
	set_tr2(ptr, TR_vecEndPos, fEndPos)

	// ExecuteHam
	fake_trake_attack(iAttacker, iVictim, fDamage, fDirection, ptr)
	
	// free ptr
	free_tr2(ptr)
}

stock fake_trake_attack(iAttacker, iVictim, Float:fDamage, Float:fDirection[3], iTraceHandle, iDamageBit = (DMG_NEVERGIB | DMG_BULLET))
{
	ExecuteHamB(Ham_TraceAttack, iVictim, iAttacker, fDamage, fDirection, iTraceHandle, iDamageBit)
}

stock fake_take_damage(iAttacker, iVictim, Float:fDamage, iInflictor, iDamageBit = (DMG_NEVERGIB | DMG_BULLET))
{
	ExecuteHamB(Ham_TakeDamage, iVictim, iInflictor, iAttacker, fDamage, iDamageBit)
}

stock get_angle_to_target(id, const Float:fTarget[3], Float:TargetSize = 0.0)
{
	static Float:fOrigin[3], iAimOrigin[3], Float:fAimOrigin[3], Float:fV1[3]
	pev(id, pev_origin, fOrigin)
	get_user_origin(id, iAimOrigin, 3) // end position from eyes
	IVecFVec(iAimOrigin, fAimOrigin)
	xs_vec_sub(fAimOrigin, fOrigin, fV1)
	
	static Float:fV2[3]
	xs_vec_sub(fTarget, fOrigin, fV2)
	
	static iResult; iResult = get_angle_between_vectors(fV1, fV2)
	
	if (TargetSize > 0.0)
	{
		static Float:fTan; fTan = TargetSize / get_distance_f(fOrigin, fTarget)
		static fAngleToTargetSize; fAngleToTargetSize = floatround( floatatan(fTan, degrees) )
		iResult -= (iResult > 0) ? fAngleToTargetSize : -fAngleToTargetSize
	}
	
	return iResult
}

stock get_angle_between_vectors(const Float:fV1[3], const Float:fV2[3])
{
	static Float:fA1[3], Float:fA2[3]
	engfunc(EngFunc_VecToAngles, fV1, fA1)
	engfunc(EngFunc_VecToAngles, fV2, fA2)
	
	static iResult; iResult = floatround(fA1[1] - fA2[1])
	iResult = iResult % 360
	iResult = (iResult > 180) ? (iResult - 360) : iResult
	
	return iResult
}

stock is_wall_between_points(Float:start[3], Float:end[3], ignore_ent)
{
	static ptr
	ptr = create_tr2()

	engfunc(EngFunc_TraceLine, start, end, IGNORE_MONSTERS, ignore_ent, ptr)
	
	static Float:EndPos[3]
	get_tr2(ptr, TR_vecEndPos, EndPos)

	free_tr2(ptr)
	return floatround(get_distance_f(end, EndPos))
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
