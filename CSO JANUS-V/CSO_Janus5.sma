#include <amxmodx>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <cstrike>

#define PLUGIN "[CSO] Weapon: JANUS-V"
#define VERSION "1.0"
#define AUTHOR "Dias Pendragon"

#define DAMAGE_A 35 // Damage in Non-Charged Mode
#define DAMAGE_B 70 // Damage in Charged Mode
#define CHARGE_AMMO 57 // After shoot X bullets, you can active Janus Transform System
#define CHARGE_LIMITTIME 7 // After X Second(s), Janus Transform System will be turned off if not using
#define CHARGE_TIME 10 // Time Use for Janus Transform System

#define CLIP 30
#define CHANGE_TIME 2.0
#define CHARGESHOOT_DELAY 0.75
#define CHARGESHOOT_RECOIL 0.25

#define CSW_JANUS5 CSW_M4A1
#define weapon_janus5 "weapon_m4a1"
#define PLAYER_ANIMEXT "carbine"
#define JANUS5_OLDMODEL "models/w_m4a1.mdl"

#define V_MODEL "models/v_janusmk5.mdl"
#define P_MODEL "models/p_janusmk5.mdl"
#define W_MODEL "models/w_janusmk5.mdl"

#define TASK_CHANGE 42342
#define TASK_CHANGELIMITTIME 54363
#define TASK_USETIME 34646

new const Janus5_Sounds[9][] = 
{
	"weapons/janusmk5_shoot1.wav",
	"weapons/janusmk5_shoot2.wav",
	"weapons/change1_ready.wav",
	"weapons/janusmk5_draw1.wav",
	"weapons/janusmk5_clipout.wav",
	"weapons/janusmk5_clipin.wav",
	"weapons/janusmk5_change2.wav",
	"weapons/janusmk5_change1.wav",
	"weapons/janusmk5_boltpull.wav"
}

new const Janus5_Resources[4][] = 
{
	"sprites/weapon_janusmk5.txt",
	"sprites/640hud7_2.spr",
	"sprites/640hud12_2.spr",
	"sprites/640hud98_2.spr"
}

enum
{
	J5_ANIM_IDLE = 0,
	J5_ANIM_RELOAD,
	J5_ANIM_DRAW,
	J5_ANIM_SHOOT1,
	J5_ANIM_SHOOT1_ACTIVE,
	J5_ANIM_CHANGE_TO_JANUS,
	J5_ANIM_IDLE_JANUS,
	J5_ANIM_DRAW_JANUS,
	J5_ANIM_SHOOT1_JANUS,
	J5_ANIM_SHOOT2_JANUS,
	J5_ANIM_SHOOT3_JANUS,
	J5_ANIM_CHANGE_TO_BACK,
	J5_ANIM_IDLE_ACTIVE,
	J5_ANIM_RELOAD_ACTIVE,
	J5_ANIM_DRAW_ACTIVE
}

enum
{
	JANUS5_NORMAL = 0,
	JANUS5_ACTIVE,
	JANUS5_JANUS
}

// MACROS
#define Get_BitVar(%1,%2) (%1 & (1 << (%2 & 31)))
#define Set_BitVar(%1,%2) %1 |= (1 << (%2 & 31))
#define UnSet_BitVar(%1,%2) %1 &= ~(1 << (%2 & 31))

const PRIMARY_WEAPONS_BIT_SUM = (1<<CSW_SCOUT)|(1<<CSW_XM1014)|(1<<CSW_MAC10)|(1<<CSW_AUG)|(1<<CSW_UMP45)|(1<<CSW_SG550)|(1<<CSW_GALIL)|(1<<CSW_FAMAS)|(1<<CSW_AWP)|(1<<CSW_MP5NAVY)|(1<<CSW_M249)|(1<<CSW_M3)|(1<<CSW_M4A1)|(1<<CSW_TMP)|(1<<CSW_G3SG1)|(1<<CSW_SG552)|(1<<CSW_AK47)|(1<<CSW_P90)
const SECONDARY_WEAPONS_BIT_SUM = (1<<CSW_P228)|(1<<CSW_ELITE)|(1<<CSW_FIVESEVEN)|(1<<CSW_USP)|(1<<CSW_GLOCK18)|(1<<CSW_DEAGLE)

new g_Had_Janus5, g_Janus5_Mode[33], g_Janus5_Clip[33], g_BulletCount[33], g_ChangingMode, Float:g_Recoil[33][3]
new g_Event_Janus5, g_Msg_WeaponList, g_SmokePuff_SprId, g_RifleShell_Id, g_ham_bot

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	register_event("CurWeapon", "Event_CurWeapon", "be", "1=1")
	
	register_forward(FM_UpdateClientData,"fw_UpdateClientData_Post", 1)	
	register_forward(FM_PlaybackEvent, "fw_PlaybackEvent")	
	register_forward(FM_SetModel, "fw_SetModel")	
	register_forward(FM_CmdStart, "fw_CmdStart")
	
	RegisterHam(Ham_Weapon_WeaponIdle, weapon_janus5, "fw_Weapon_WeaponIdle_Post", 1)
	RegisterHam(Ham_Weapon_PrimaryAttack, weapon_janus5, "fw_Weapon_PrimaryAttack")
	RegisterHam(Ham_Weapon_PrimaryAttack, weapon_janus5, "fw_Weapon_PrimaryAttack_Post", 1)	
	RegisterHam(Ham_Item_Deploy, weapon_janus5, "fw_Item_Deploy_Post", 1)	
	RegisterHam(Ham_Item_AddToPlayer, weapon_janus5, "fw_Item_AddToPlayer_Post", 1)
	RegisterHam(Ham_Item_PostFrame, weapon_janus5, "fw_Item_PostFrame")	
	RegisterHam(Ham_Weapon_Reload, weapon_janus5, "fw_Weapon_Reload")
	RegisterHam(Ham_Weapon_Reload, weapon_janus5, "fw_Weapon_Reload_Post", 1)	
	
	RegisterHam(Ham_TraceAttack, "worldspawn", "fw_TraceAttack_World")
	RegisterHam(Ham_TraceAttack, "player", "fw_TraceAttack_Player")	
	
	g_Msg_WeaponList = get_user_msgid("WeaponList")
	register_clcmd("admin_get_janus5", "Get_Janus5")
	register_clcmd("weapon_janusmk5", "Hook_Weapon")
}

public plugin_precache()
{
	engfunc(EngFunc_PrecacheModel, V_MODEL)
	engfunc(EngFunc_PrecacheModel, P_MODEL)
	engfunc(EngFunc_PrecacheModel, W_MODEL)
	
	new i
	for(i = 0; i < sizeof(Janus5_Sounds); i++)
		engfunc(EngFunc_PrecacheSound, Janus5_Sounds[i])
	for(i = 0; i < sizeof(Janus5_Resources); i++)
	{
		if(i == 0) engfunc(EngFunc_PrecacheGeneric, Janus5_Resources[i])
		else engfunc(EngFunc_PrecacheModel, Janus5_Resources[i])
	}
	
	g_RifleShell_Id = engfunc(EngFunc_PrecacheModel, "models/rshell.mdl")
	g_SmokePuff_SprId = engfunc(EngFunc_PrecacheModel, "sprites/wall_puff1.spr")
	
	register_forward(FM_PrecacheEvent, "fw_PrecacheEvent_Post", 1)
}

public fw_PrecacheEvent_Post(type, const name[])
{
	if(equal("events/m4a1.sc", name)) g_Event_Janus5 = get_orig_retval()		
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


public Get_Janus5(id)
{
	if(!is_user_alive(id))
		return
		
	drop_weapons(id, 1)
		
	g_Janus5_Mode[id] = JANUS5_NORMAL
	g_BulletCount[id] = 0
	
	Set_BitVar(g_Had_Janus5, id)
	UnSet_BitVar(g_ChangingMode, id)
	fm_give_item(id, weapon_janus5)
	
	Give_RealAmmo(id, CSW_JANUS5)
	
	engfunc(EngFunc_MessageBegin, MSG_ONE_UNRELIABLE, get_user_msgid("CurWeapon"), {0, 0, 0}, id)
	write_byte(1)
	write_byte(CSW_M4A1)
	write_byte(30)
	message_end()
}

public Remove_Janus5(id)
{
	g_Janus5_Mode[id] = JANUS5_NORMAL
	g_BulletCount[id] = 0
	
	UnSet_BitVar(g_Had_Janus5, id)
	UnSet_BitVar(g_ChangingMode, id)
	
	remove_task(id+TASK_CHANGE)
	remove_task(id+TASK_CHANGELIMITTIME)
	remove_task(id+TASK_USETIME)
}

public Hook_Weapon(id)
{
	engclient_cmd(id, weapon_janus5)
	return PLUGIN_HANDLED
}

public Event_CurWeapon(id)
{
	if(!Get_BitVar(g_Had_Janus5, id))	
		return
	if(g_Janus5_Mode[id] != JANUS5_JANUS)
		return

	static Float:Delay, Float:Delay2
	static Ent; Ent = fm_get_user_weapon_entity(id, CSW_JANUS5)
	if(!pev_valid(Ent)) return
	
	Delay = get_pdata_float(Ent, 46, 4) * CHARGESHOOT_DELAY
	Delay2 = get_pdata_float(Ent, 47, 4) * CHARGESHOOT_DELAY
	
	if(Delay > 0.0)
	{
		set_pdata_float(Ent, 46, Delay, 4)
		set_pdata_float(Ent, 47, Delay2, 4)
	}
}

public fw_UpdateClientData_Post(id, sendweapons, cd_handle)
{
	if(!is_user_alive(id) || !is_user_connected(id))
		return FMRES_IGNORED	
	if(get_user_weapon(id) == CSW_JANUS5 && Get_BitVar(g_Had_Janus5, id))
		set_cd(cd_handle, CD_flNextAttack, get_gametime() + 0.001) 
	
	return FMRES_HANDLED
}

public fw_PlaybackEvent(flags, invoker, eventid, Float:delay, Float:origin[3], Float:angles[3], Float:fparam1, Float:fparam2, iParam1, iParam2, bParam1, bParam2)
{
	if (!is_user_connected(invoker))
		return FMRES_IGNORED	
	if(get_user_weapon(invoker) != CSW_JANUS5 || !Get_BitVar(g_Had_Janus5, invoker))
		return FMRES_IGNORED
	if(eventid != g_Event_Janus5)
		return FMRES_IGNORED
	
	engfunc(EngFunc_PlaybackEvent, flags | FEV_HOSTONLY, invoker, eventid, delay, origin, angles, fparam1, fparam2, iParam1, iParam2, bParam1, bParam2)
		
	if(g_Janus5_Mode[invoker] == JANUS5_NORMAL) set_weapon_anim(invoker, J5_ANIM_SHOOT1)
	else if(g_Janus5_Mode[invoker] == JANUS5_ACTIVE) set_weapon_anim(invoker, J5_ANIM_SHOOT1_ACTIVE)
	else if(g_Janus5_Mode[invoker] == JANUS5_JANUS) set_weapon_anim(invoker, random_num(J5_ANIM_SHOOT1_JANUS, J5_ANIM_SHOOT3_JANUS))
	
	emit_sound(invoker, CHAN_WEAPON, g_Janus5_Mode[invoker] == JANUS5_JANUS ? Janus5_Sounds[1] : Janus5_Sounds[0], 1.0, ATTN_NORM, 0, PITCH_NORM)
	Eject_Shell(invoker, g_RifleShell_Id, 0.01)
	
	static Ent; Ent = fm_find_ent_by_owner(-1, weapon_janus5, invoker)
	if(pev_valid(Ent) && g_Janus5_Mode[invoker] == JANUS5_JANUS) cs_set_weapon_ammo(Ent, cs_get_weapon_ammo(Ent) + 1)
	
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
	
	if(equal(model, JANUS5_OLDMODEL))
	{
		static weapon; weapon = fm_find_ent_by_owner(-1, weapon_janus5, entity)
		
		if(!pev_valid(weapon))
			return FMRES_IGNORED;
		
		if(Get_BitVar(g_Had_Janus5, iOwner))
		{
			Remove_Janus5(iOwner)
			
			set_pev(weapon, pev_impulse, 31122013)
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
	if(!Get_BitVar(g_Had_Janus5, id) || get_user_weapon(id) != CSW_JANUS5)	
		return FMRES_IGNORED
		
	static PressButton; PressButton = get_uc(uc_handle, UC_Buttons)
	
	if((PressButton & IN_RELOAD) && g_Janus5_Mode[id] == JANUS5_JANUS)
		return FMRES_SUPERCEDE
		
	if((PressButton & IN_ATTACK2))
	{
		PressButton &= ~IN_ATTACK2
		set_uc(uc_handle, UC_Buttons, PressButton)
		
		if((pev(id, pev_oldbuttons) & IN_ATTACK2))
			return FMRES_IGNORED
		if(g_Janus5_Mode[id] != JANUS5_ACTIVE)
			return FMRES_IGNORED
		if(get_pdata_float(id, 83, 5) > 0.0)
			return FMRES_IGNORED
		
		remove_task(id+TASK_CHANGELIMITTIME)
		
		Set_BitVar(g_ChangingMode, id)
		Set_Player_NextAttack(id, CSW_JANUS5, CHANGE_TIME)
		
		set_weapon_anim(id, J5_ANIM_CHANGE_TO_JANUS)
		set_task(CHANGE_TIME, "ChangeTo_JanusTransform", id+TASK_CHANGE)
	}
	
	return FMRES_IGNORED
}

public ChangeTo_JanusTransform(id)
{
	id -= TASK_CHANGE
	
	if(!is_user_alive(id))
		return
	if(get_user_weapon(id) != CSW_JANUS5 || !Get_BitVar(g_Had_Janus5, id))	
		return
	if(!Get_BitVar(g_ChangingMode, id))
		return
		
	UnSet_BitVar(g_ChangingMode, id)
	g_Janus5_Mode[id] = JANUS5_JANUS
	
	set_weapon_anim(id, J5_ANIM_IDLE_JANUS)
	
	remove_task(id+TASK_USETIME)
	set_task(float(CHARGE_TIME), "TurnOff_JTS2", id+TASK_USETIME)
}

public TurnOff_JTS2(id)
{
	id -= TASK_USETIME
	
	if(!is_user_alive(id))
		return
	g_Janus5_Mode[id] = JANUS5_NORMAL
	if(get_user_weapon(id) != CSW_JANUS5 || !Get_BitVar(g_Had_Janus5, id))	
		return
	if(g_Janus5_Mode[id] != JANUS5_JANUS)
		return
		
	Set_BitVar(g_ChangingMode, id)
	Set_Player_NextAttack(id, CSW_JANUS5, CHANGE_TIME - 1.0)
		
	set_weapon_anim(id, J5_ANIM_CHANGE_TO_BACK)
	set_task(CHANGE_TIME - 1.0, "ChangeTo_Back", id+TASK_CHANGE)
}

public ChangeTo_Back(id)
{
	id -= TASK_CHANGE
	
	if(!is_user_alive(id))
		return
	g_Janus5_Mode[id] = JANUS5_NORMAL	
	if(get_user_weapon(id) != CSW_JANUS5 || !Get_BitVar(g_Had_Janus5, id))	
		return
	if(g_Janus5_Mode[id] != JANUS5_JANUS)
		return
		
	g_Janus5_Mode[id] = JANUS5_NORMAL
}

public fw_Weapon_PrimaryAttack(Ent)
{
	static id; id = pev(Ent, pev_owner)
	pev(id, pev_punchangle, g_Recoil[id])
	
	return HAM_IGNORED
}

public fw_Weapon_PrimaryAttack_Post(Ent)
{
	static id; id = pev(Ent, pev_owner)
	
	if(Get_BitVar(g_Had_Janus5, id) && g_Janus5_Mode[id] == JANUS5_JANUS)
	{
		static Float:Push[3]
		pev(id, pev_punchangle, Push)
		xs_vec_sub(Push, g_Recoil[id], Push)
		
		xs_vec_mul_scalar(Push, CHARGESHOOT_RECOIL, Push)
		xs_vec_add(Push, g_Recoil[id], Push)
		set_pev(id, pev_punchangle, Push)
		
		Event_CurWeapon(id)
	}
}

public fw_Weapon_WeaponIdle_Post(Ent)
{
	if(pev_valid(Ent) != 2)
		return HAM_IGNORED	
	static Id; Id = get_pdata_cbase(Ent, 41, 4)
	if(get_pdata_cbase(Id, 373) != Ent)
		return HAM_IGNORED	
	if(!Get_BitVar(g_Had_Janus5, Id))
		return HAM_IGNORED	
		
	if(get_pdata_float(Ent, 48, 4) <= 0.1) 
	{
		if(g_Janus5_Mode[Id] == JANUS5_NORMAL) set_weapon_anim(Id, J5_ANIM_IDLE)
		else if(g_Janus5_Mode[Id] == JANUS5_ACTIVE) set_weapon_anim(Id, J5_ANIM_IDLE_ACTIVE)
		else if(g_Janus5_Mode[Id] == JANUS5_JANUS) set_weapon_anim(Id, J5_ANIM_IDLE_JANUS)
		
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
	if(!Get_BitVar(g_Had_Janus5, Id))
		return
	
	set_pev(Id, pev_viewmodel2, V_MODEL)
	set_pev(Id, pev_weaponmodel2, P_MODEL)
	
	if(g_Janus5_Mode[Id] == JANUS5_NORMAL) set_weapon_anim(Id, J5_ANIM_DRAW)
	else if(g_Janus5_Mode[Id] == JANUS5_ACTIVE) set_weapon_anim(Id, J5_ANIM_DRAW_ACTIVE)
	else if(g_Janus5_Mode[Id] == JANUS5_JANUS) set_weapon_anim(Id, J5_ANIM_DRAW_JANUS)
}

public fw_Item_AddToPlayer_Post(Ent, id)
{
	if(!pev_valid(Ent))
		return HAM_IGNORED
		
	if(pev(Ent, pev_impulse) == 31122013)
	{
		Set_BitVar(g_Had_Janus5, id)
		set_pev(Ent, pev_impulse, 0)
	}		
	
	message_begin(MSG_ONE_UNRELIABLE, g_Msg_WeaponList, .player = id)
	write_string(Get_BitVar(g_Had_Janus5, id) ? "weapon_janusmk5" : "weapon_m4a1")
	write_byte(4) // PrimaryAmmoID
	write_byte(90) // PrimaryAmmoMaxAmount
	write_byte(-1) // SecondaryAmmoID
	write_byte(-1) // SecondaryAmmoMaxAmount
	write_byte(0) // SlotID (0...N)
	write_byte(6) // NumberInSlot (1...N)
	write_byte(Get_BitVar(g_Had_Janus5, id) ? CSW_JANUS5 : CSW_M4A1) // WeaponID
	write_byte(0) // Flags
	message_end()

	return HAM_HANDLED	
}

public fw_Item_PostFrame(ent)
{
	static id; id = pev(ent, pev_owner)
	if(!is_user_alive(id))
		return HAM_IGNORED
	if(!Get_BitVar(g_Had_Janus5, id))
		return HAM_IGNORED	
	
	static Float:flNextAttack; flNextAttack = get_pdata_float(id, 83, 5)
	static bpammo; bpammo = cs_get_user_bpammo(id, CSW_JANUS5)
	
	static iClip; iClip = get_pdata_int(ent, 51, 4)
	static fInReload; fInReload = get_pdata_int(ent, 54, 4)
	
	if(fInReload && flNextAttack <= 0.0)
	{
		static temp1
		temp1 = min(CLIP - iClip, bpammo)

		set_pdata_int(ent, 51, iClip + temp1, 4)
		cs_set_user_bpammo(id, CSW_JANUS5, bpammo - temp1)		
		
		set_pdata_int(ent, 54, 0, 4)
		
		fInReload = 0
	}		
	
	return HAM_IGNORED
}

public fw_Weapon_Reload(ent)
{
	static id; id = pev(ent, pev_owner)
	if(!is_user_alive(id))
		return HAM_IGNORED
	if(!Get_BitVar(g_Had_Janus5, id))
		return HAM_IGNORED	
	if(g_Janus5_Mode[id] == JANUS5_JANUS)
	{
		set_pdata_int(ent, 54, 0, 4)
		return HAM_SUPERCEDE
	}

	g_Janus5_Clip[id] = -1
		
	static BPAmmo; BPAmmo = cs_get_user_bpammo(id, CSW_JANUS5)
	static iClip; iClip = get_pdata_int(ent, 51, 4)
		
	if(BPAmmo <= 0)
		return HAM_SUPERCEDE
	if(iClip >= CLIP)
		return HAM_SUPERCEDE		
			
	g_Janus5_Clip[id] = iClip	
	
	return HAM_HANDLED
}

public fw_Weapon_Reload_Post(ent)
{
	static id; id = pev(ent, pev_owner)
	if(!is_user_alive(id))
		return HAM_IGNORED
	if(!Get_BitVar(g_Had_Janus5, id))
		return HAM_IGNORED	
	if(g_Janus5_Mode[id] == JANUS5_JANUS)
	{
		set_pdata_int(ent, 54, 0, 4)
		return HAM_SUPERCEDE
	}
		
	if((get_pdata_int(ent, 54, 4) == 1))
	{ // Reload
		if(g_Janus5_Clip[id] == -1)
			return HAM_IGNORED
		
		set_pdata_int(ent, 51, g_Janus5_Clip[id], 4)
		
		if(g_Janus5_Mode[id] == JANUS5_NORMAL) set_weapon_anim(id, J5_ANIM_RELOAD)
		else if(g_Janus5_Mode[id] == JANUS5_ACTIVE) set_weapon_anim(id, J5_ANIM_RELOAD_ACTIVE)
		
		//Set_Player_NextAttack(id, CSW_JANUS5, 
	}
	
	return HAM_HANDLED
}

public fw_TraceAttack_World(Victim, Attacker, Float:Damage, Float:Direction[3], Ptr, DamageBits)
{
	if(!is_user_connected(Attacker))
		return HAM_IGNORED	
	if(get_user_weapon(Attacker) != CSW_JANUS5 || !Get_BitVar(g_Had_Janus5, Attacker))
		return HAM_IGNORED
		
	static Float:flEnd[3], Float:vecPlane[3]
		
	get_tr2(Ptr, TR_vecEndPos, flEnd)
	get_tr2(Ptr, TR_vecPlaneNormal, vecPlane)		
			
	Make_BulletHole(Attacker, flEnd, Damage)
	Make_BulletSmoke(Attacker, Ptr)

	SetHamParamFloat(3, g_Janus5_Mode[Attacker] == JANUS5_JANUS ? float(DAMAGE_B) : float(DAMAGE_A))
	
	if(g_Janus5_Mode[Attacker] == JANUS5_NORMAL)
	{
		g_BulletCount[Attacker]++
		CheckCharge(Attacker)
	}
	
	return HAM_IGNORED
}

public fw_TraceAttack_Player(Victim, Attacker, Float:Damage, Float:Direction[3], Ptr, DamageBits)
{
	if(!is_user_connected(Attacker))
		return HAM_IGNORED	
	if(get_user_weapon(Attacker) != CSW_JANUS5 || !Get_BitVar(g_Had_Janus5, Attacker))
		return HAM_IGNORED
		
	SetHamParamFloat(3, g_Janus5_Mode[Attacker] == JANUS5_JANUS ? float(DAMAGE_B) : float(DAMAGE_A))
	if(cs_get_user_team(Attacker) != cs_get_user_team(Victim) && g_Janus5_Mode[Attacker] == JANUS5_NORMAL) 
	{
		g_BulletCount[Attacker]++
		CheckCharge(Attacker)
	}
	
	return HAM_IGNORED
}

public CheckCharge(id)
{
	if(g_BulletCount[id] >= CHARGE_AMMO)
	{
		g_Janus5_Mode[id] = JANUS5_ACTIVE
		set_weapon_anim(id, J5_ANIM_IDLE_ACTIVE)
		
		emit_sound(id, CHAN_VOICE, Janus5_Sounds[2], 1.0, ATTN_NORM, 0, PITCH_NORM)
		
		g_BulletCount[id] = 0
	
		remove_task(id+TASK_CHANGELIMITTIME)
		set_task(float(CHARGE_LIMITTIME), "TurnOff_JTS", id+TASK_CHANGELIMITTIME)
	}
}

public TurnOff_JTS(id)
{
	id -= TASK_CHANGELIMITTIME
	if(!is_user_alive(id))
		return
		
	g_Janus5_Mode[id] = JANUS5_NORMAL
	g_BulletCount[id] = 0
	
	set_weapon_anim(id, J5_ANIM_IDLE)
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

stock Set_Player_NextAttack(id, CSWID, Float:NextTime)
{
	static Ent; Ent = fm_get_user_weapon_entity(id, CSWID)
	if(!pev_valid(Ent)) return
	
	set_pdata_float(id, 83, NextTime, 5)
	
	set_pdata_float(Ent, 46 , NextTime, 4)
	set_pdata_float(Ent, 47, NextTime, 4)
	set_pdata_float(Ent, 48, NextTime, 4)
}
