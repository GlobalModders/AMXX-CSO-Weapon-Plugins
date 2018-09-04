#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <cstrike>

#define PLUGIN "[CSO] Weapon: JANUS-VII"
#define VERSION "1.0"
#define AUTHOR "Dias Pendragon"

#define DAMAGE_A 40 // Damage in Non-Charged Mode
#define DAMAGE_B 80 // Damage in Charged Mode
#define CHARGE_AMMO 57 // After shoot X bullets, you can active Janus Transform System
#define CHARGE_LIMITTIME 7 // After X Second(s), Janus Transform System will be turned off if not using
#define CHARGE_TIME 15 // Time Use for Janus Transform System

#define CLIP 100
#define CHANGE_TIME 2.0
#define LIGHTNING_RANGE 500.0
#define LIGHTNING_HEADSHOTABLE 1 // Can deal Headshot

#define CSW_JANUS7 CSW_M249
#define weapon_janus7 "weapon_m249"
#define PLAYER_ANIMEXT "m249"
#define Janus7_OLDMODEL "models/w_m249.mdl"

#define V_MODEL "models/v_janus7.mdl"
#define P_MODEL "models/p_janus7.mdl"
#define W_MODEL "models/w_janus7.mdl"

#define TASK_CHANGE 42343
#define TASK_CHANGELIMITTIME 54364
#define TASK_USETIME 34647

new const Janus7_Sounds[9][] = 
{
	"weapons/janus7_shoot.wav",
	"weapons/janus7_shoot2.wav",
	"weapons/change1_ready.wav",
	"weapons/mg3_open.wav",
	"weapons/mg3_clipin.wav",
	"weapons/mg3_clipout.wav",
	"weapons/mg3_close.wav",
	"weapons/janus7_change1.wav",
	"weapons/janus7_change2.wav"
}

new const Janus7_Resources[4][] = 
{
	"sprites/weapon_janus7.txt",
	"sprites/640hud7_2.spr",
	"sprites/640hud12_2.spr",
	"sprites/640hud99_2.spr"
}

enum
{
	J7_ANIM_IDLE = 0,
	J7_ANIM_RELOAD,
	J7_ANIM_DRAW,
	J7_ANIM_SHOOT1,
	J7_ANIM_SHOOT1_2,
	J7_ANIM_SHOOT1_ACTIVE,
	J7_ANIM_CHANGE_TO_JANUS,
	J7_ANIM_IDLE_JANUS,
	J7_ANIM_DRAW_JANUS,
	J7_ANIM_SHOOT1_JANUS,
	J7_ANIM_SHOOT2_JANUS,
	J7_ANIM_CHANGE_TO_BACK,
	J7_ANIM_IDLE_ACTIVE,
	J7_ANIM_RELOAD_ACTIVE,
	J7_ANIM_DRAW_ACTIVE
}

enum
{
	Janus7_NORMAL = 0,
	Janus7_ACTIVE,
	Janus7_JANUS
}

// MACROS
#define Get_BitVar(%1,%2) (%1 & (1 << (%2 & 31)))
#define Set_BitVar(%1,%2) %1 |= (1 << (%2 & 31))
#define UnSet_BitVar(%1,%2) %1 &= ~(1 << (%2 & 31))

const PRIMARY_WEAPONS_BIT_SUM = (1<<CSW_SCOUT)|(1<<CSW_XM1014)|(1<<CSW_MAC10)|(1<<CSW_AUG)|(1<<CSW_UMP45)|(1<<CSW_SG550)|(1<<CSW_GALIL)|(1<<CSW_FAMAS)|(1<<CSW_AWP)|(1<<CSW_MP5NAVY)|(1<<CSW_M249)|(1<<CSW_M3)|(1<<CSW_M4A1)|(1<<CSW_TMP)|(1<<CSW_G3SG1)|(1<<CSW_SG552)|(1<<CSW_AK47)|(1<<CSW_P90)
const SECONDARY_WEAPONS_BIT_SUM = (1<<CSW_P228)|(1<<CSW_ELITE)|(1<<CSW_FIVESEVEN)|(1<<CSW_USP)|(1<<CSW_GLOCK18)|(1<<CSW_DEAGLE)

new g_Had_Janus7, g_Janus7_Mode[33], g_Janus7_Clip[33], g_BulletCount[33], g_ChangingMode, Float:EmitSoundTime[33]
new g_Event_Janus7, g_Msg_WeaponList, g_SmokePuff_SprId, g_RifleShell_Id, g_ham_bot, g_SprId, g_MaxPlayers

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	register_forward(FM_UpdateClientData,"fw_UpdateClientData_Post", 1)	
	register_forward(FM_PlaybackEvent, "fw_PlaybackEvent")	
	register_forward(FM_SetModel, "fw_SetModel")	
	register_forward(FM_CmdStart, "fw_CmdStart")
	
	RegisterHam(Ham_Weapon_WeaponIdle, weapon_janus7, "fw_Weapon_WeaponIdle_Post", 1)
	RegisterHam(Ham_Item_Deploy, weapon_janus7, "fw_Item_Deploy_Post", 1)	
	RegisterHam(Ham_Item_AddToPlayer, weapon_janus7, "fw_Item_AddToPlayer_Post", 1)
	RegisterHam(Ham_Item_PostFrame, weapon_janus7, "fw_Item_PostFrame")	
	RegisterHam(Ham_Weapon_Reload, weapon_janus7, "fw_Weapon_Reload")
	RegisterHam(Ham_Weapon_Reload, weapon_janus7, "fw_Weapon_Reload_Post", 1)	
	
	RegisterHam(Ham_TraceAttack, "worldspawn", "fw_TraceAttack_World")
	RegisterHam(Ham_TraceAttack, "player", "fw_TraceAttack_Player")	
	
	g_Msg_WeaponList = get_user_msgid("WeaponList")
	g_MaxPlayers = get_maxplayers()
	 
	register_clcmd("admin_get_janus7", "Get_Janus7")
	register_clcmd("weapon_janus7", "Hook_Weapon")
}

public plugin_precache()
{
	engfunc(EngFunc_PrecacheModel, V_MODEL)
	engfunc(EngFunc_PrecacheModel, P_MODEL)
	engfunc(EngFunc_PrecacheModel, W_MODEL)
	
	new i
	for(i = 0; i < sizeof(Janus7_Sounds); i++)
		engfunc(EngFunc_PrecacheSound, Janus7_Sounds[i])
	for(i = 0; i < sizeof(Janus7_Resources); i++)
	{
		if(i == 0) engfunc(EngFunc_PrecacheGeneric, Janus7_Resources[i])
		else engfunc(EngFunc_PrecacheModel, Janus7_Resources[i])
	}
	
	g_RifleShell_Id = engfunc(EngFunc_PrecacheModel, "models/rshell.mdl")
	g_SmokePuff_SprId = engfunc(EngFunc_PrecacheModel, "sprites/wall_puff1.spr")
	g_SprId = precache_model( "sprites/lgtning.spr" )
	
	register_forward(FM_PrecacheEvent, "fw_PrecacheEvent_Post", 1)
}

public fw_PrecacheEvent_Post(type, const name[])
{
	if(equal("events/m249.sc", name)) g_Event_Janus7 = get_orig_retval()		
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


public Get_Janus7(id)
{
	if(!is_user_alive(id))
		return
		
	drop_weapons(id, 1)
		
	g_Janus7_Mode[id] = Janus7_NORMAL
	g_BulletCount[id] = 0
	
	Set_BitVar(g_Had_Janus7, id)
	UnSet_BitVar(g_ChangingMode, id)
	fm_give_item(id, weapon_janus7)
	
	Give_RealAmmo(id, CSW_JANUS7)
	
	engfunc(EngFunc_MessageBegin, MSG_ONE_UNRELIABLE, get_user_msgid("CurWeapon"), {0, 0, 0}, id)
	write_byte(1)
	write_byte(CSW_JANUS7)
	write_byte(CLIP)
	message_end()
}

public Remove_Janus7(id)
{
	g_Janus7_Mode[id] = Janus7_NORMAL
	g_BulletCount[id] = 0
	
	UnSet_BitVar(g_Had_Janus7, id)
	UnSet_BitVar(g_ChangingMode, id)
	
	remove_task(id+TASK_CHANGE)
	remove_task(id+TASK_CHANGELIMITTIME)
	remove_task(id+TASK_USETIME)
}

public Hook_Weapon(id)
{
	engclient_cmd(id, weapon_janus7)
	return PLUGIN_HANDLED
}

public fw_UpdateClientData_Post(id, sendweapons, cd_handle)
{
	if(!is_user_alive(id) || !is_user_connected(id))
		return FMRES_IGNORED	
	if(get_user_weapon(id) == CSW_JANUS7 && Get_BitVar(g_Had_Janus7, id))
		set_cd(cd_handle, CD_flNextAttack, get_gametime() + 0.001) 
	
	return FMRES_HANDLED
}

public fw_PlaybackEvent(flags, invoker, eventid, Float:delay, Float:origin[3], Float:angles[3], Float:fparam1, Float:fparam2, iParam1, iParam2, bParam1, bParam2)
{
	if (!is_user_connected(invoker))
		return FMRES_IGNORED	
	if(get_user_weapon(invoker) != CSW_JANUS7 || !Get_BitVar(g_Had_Janus7, invoker))
		return FMRES_IGNORED
	if(eventid != g_Event_Janus7)
		return FMRES_IGNORED
	
	engfunc(EngFunc_PlaybackEvent, flags | FEV_HOSTONLY, invoker, eventid, delay, origin, angles, fparam1, fparam2, iParam1, iParam2, bParam1, bParam2)
		
	if(g_Janus7_Mode[invoker] == Janus7_NORMAL) set_weapon_anim(invoker, J7_ANIM_SHOOT1)
	else if(g_Janus7_Mode[invoker] == Janus7_ACTIVE) set_weapon_anim(invoker, J7_ANIM_SHOOT1_ACTIVE)
	else if(g_Janus7_Mode[invoker] == Janus7_JANUS) set_weapon_anim(invoker, random_num(J7_ANIM_SHOOT1_JANUS, J7_ANIM_SHOOT2_JANUS))
	
	emit_sound(invoker, CHAN_WEAPON, g_Janus7_Mode[invoker] == Janus7_JANUS ? Janus7_Sounds[1] : Janus7_Sounds[0], 1.0, ATTN_NORM, 0, PITCH_NORM)
	Eject_Shell(invoker, g_RifleShell_Id, 0.01)
	
	static Ent; Ent = fm_find_ent_by_owner(-1, weapon_janus7, invoker)
	if(pev_valid(Ent) && g_Janus7_Mode[invoker] == Janus7_JANUS) cs_set_weapon_ammo(Ent, cs_get_weapon_ammo(Ent) + 1)
	
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
	
	if(equal(model, Janus7_OLDMODEL))
	{
		static weapon; weapon = fm_find_ent_by_owner(-1, weapon_janus7, entity)
		
		if(!pev_valid(weapon))
			return FMRES_IGNORED;
		
		if(Get_BitVar(g_Had_Janus7, iOwner))
		{
			Remove_Janus7(iOwner)
			
			set_pev(weapon, pev_impulse, 11012014)
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
	if(!Get_BitVar(g_Had_Janus7, id) || get_user_weapon(id) != CSW_JANUS7)	
		return FMRES_IGNORED
		
	static PressButton; PressButton = get_uc(uc_handle, UC_Buttons)
	
	if((PressButton & IN_ATTACK) && g_Janus7_Mode[id] == Janus7_JANUS && !Get_BitVar(g_ChangingMode, id))
	{
		PressButton &= ~IN_ATTACK
		set_uc(uc_handle, UC_Buttons, PressButton)

		if(get_gametime() - 3.0 > EmitSoundTime[id])
		{
			emit_sound(id, CHAN_WEAPON, Janus7_Sounds[1], 1.0, ATTN_NORM, 0, PITCH_NORM)
			EmitSoundTime[id] = get_gametime()
		}
		
		if(get_pdata_float(id, 83, 5) > 0.0)
			return FMRES_IGNORED
			
		set_weapon_anim(id, J7_ANIM_SHOOT1_JANUS)
		Make_ShootEffect(id)
		Janus7_Lighting(id)
		
		set_pdata_float(id, 83, 0.075, 5)
		
		return FMRES_IGNORED
	}
	
	if((PressButton & IN_RELOAD) && g_Janus7_Mode[id] == Janus7_JANUS)
		return FMRES_SUPERCEDE
	
	if((PressButton & IN_ATTACK2))
	{
		PressButton &= ~IN_ATTACK2
		set_uc(uc_handle, UC_Buttons, PressButton)
		
		if((pev(id, pev_oldbuttons) & IN_ATTACK2))
			return FMRES_IGNORED
		if(g_Janus7_Mode[id] != Janus7_ACTIVE)
			return FMRES_IGNORED
		if(get_pdata_float(id, 83, 5) > 0.0)
			return FMRES_IGNORED
		
		remove_task(id+TASK_CHANGELIMITTIME)
		
		Set_BitVar(g_ChangingMode, id)
		Set_Player_NextAttack(id, CSW_JANUS7, CHANGE_TIME)
		
		set_weapon_anim(id, J7_ANIM_CHANGE_TO_JANUS)
		set_task(CHANGE_TIME, "ChangeTo_JanusTransform", id+TASK_CHANGE)
	}
	
	return FMRES_IGNORED
}

public Make_ShootEffect(id)
{
	static Float:Angles[3]
	pev(id, pev_punchangle, Angles)
	
	Angles[0] += random_float(-1.5, 0.0)
	Angles[1] += random_float(-0.75, 0.75)
	
	set_pev(id, pev_punchangle, Angles)
}

public Janus7_Lighting(id)
{
	static Float:TargetOrigin[3], Float:Origin[3], NearestId, Float:Range, Float:MyOrigin[3]
	fm_get_aim_origin(id, TargetOrigin)
	Range = 4096.0
	NearestId = 0
	pev(id, pev_origin, MyOrigin)
	
	for(new i = 0; i < g_MaxPlayers; i++)
	{
		if(!is_user_alive(i))
			continue
		if(cs_get_user_team(id) == cs_get_user_team(i))
			continue
		if(entity_range(id, i) > LIGHTNING_RANGE)
			continue
			
		pev(i, pev_origin, Origin)
		if(is_wall_between_points(MyOrigin, Origin, id))
			continue
		if(!is_in_viewcone(id, Origin))
			continue

		if(entity_range(id, i) <= Range)
		{
			NearestId = i
			Range = entity_range(id, i)
		}
	}
	
	if(is_user_alive(NearestId))
	{
		pev(NearestId, pev_origin, TargetOrigin)
		
		static TakeDamage; TakeDamage = LIGHTNING_HEADSHOTABLE
		if(!TakeDamage) ExecuteHamB(Ham_TakeDamage, NearestId, 0, id, float(DAMAGE_B), DMG_BLAST)
		else do_attack(id, NearestId, 0, float(DAMAGE_B))
	}
	
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_BEAMENTPOINT)
	write_short(id | 0x1000) 
	engfunc(EngFunc_WriteCoord, TargetOrigin[0])
	engfunc(EngFunc_WriteCoord, TargetOrigin[1])
	engfunc(EngFunc_WriteCoord, TargetOrigin[2])
	write_short(g_SprId)
	write_byte(0) // framerate
	write_byte(0) // framerate
	write_byte(1) // life
	write_byte(30)  // width
	write_byte(15)   // noise
	write_byte(255)   // r, g, b
	write_byte(170)   // r, g, b
	write_byte(0)   // r, g, b
	write_byte(255)	// brightness
	write_byte(25)		// speed
	message_end()
	
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_BEAMENTPOINT)
	write_short(id | 0x1000) 
	engfunc(EngFunc_WriteCoord, TargetOrigin[0])
	engfunc(EngFunc_WriteCoord, TargetOrigin[1])
	engfunc(EngFunc_WriteCoord, TargetOrigin[2])
	write_short(g_SprId)
	write_byte(0) // framerate
	write_byte(0) // framerate
	write_byte(1) // life
	write_byte(20)  // width
	write_byte(50)   // noise
	write_byte(250)   // r, g, b
	write_byte(250)   // r, g, b
	write_byte(0)   // r, g, b
	write_byte(255)	// brightness
	write_byte(25)		// speed
	message_end()
	
	
}

public ChangeTo_JanusTransform(id)
{
	id -= TASK_CHANGE
	
	if(!is_user_alive(id))
		return
	if(get_user_weapon(id) != CSW_JANUS7 || !Get_BitVar(g_Had_Janus7, id))	
		return
	if(!Get_BitVar(g_ChangingMode, id))
		return
		
	UnSet_BitVar(g_ChangingMode, id)
	g_Janus7_Mode[id] = Janus7_JANUS
	
	set_weapon_anim(id, J7_ANIM_IDLE_JANUS)
	
	remove_task(id+TASK_USETIME)
	set_task(float(CHARGE_TIME), "TurnOff_JTS2", id+TASK_USETIME)
}

public TurnOff_JTS2(id)
{
	id -= TASK_USETIME
	
	if(!is_user_alive(id))
		return
	g_Janus7_Mode[id] = Janus7_NORMAL
	if(get_user_weapon(id) != CSW_JANUS7 || !Get_BitVar(g_Had_Janus7, id))	
		return
	if(g_Janus7_Mode[id] != Janus7_JANUS)
		return
		
	Set_BitVar(g_ChangingMode, id)
	Set_Player_NextAttack(id, CSW_JANUS7, CHANGE_TIME - 1.0)
		
	set_weapon_anim(id, J7_ANIM_CHANGE_TO_BACK)
	emit_sound(id, CHAN_WEAPON, Janus7_Sounds[8], 1.0, ATTN_NORM, 0, PITCH_NORM)
	set_task(CHANGE_TIME - 1.0, "ChangeTo_Back", id+TASK_CHANGE)
}

public ChangeTo_Back(id)
{
	id -= TASK_CHANGE
	
	if(!is_user_alive(id))
		return
	g_Janus7_Mode[id] = Janus7_NORMAL
	if(get_user_weapon(id) != CSW_JANUS7 || !Get_BitVar(g_Had_Janus7, id))	
		return
	if(g_Janus7_Mode[id] != Janus7_JANUS)
		return
		
	g_Janus7_Mode[id] = Janus7_NORMAL
}

public fw_Weapon_WeaponIdle_Post(Ent)
{
	if(pev_valid(Ent) != 2)
		return HAM_IGNORED	
	static Id; Id = get_pdata_cbase(Ent, 41, 4)
	if(get_pdata_cbase(Id, 373) != Ent)
		return HAM_IGNORED	
	if(!Get_BitVar(g_Had_Janus7, Id))
		return HAM_IGNORED	
		
	if(get_pdata_float(Ent, 48, 4) <= 0.1) 
	{
		if(g_Janus7_Mode[Id] == Janus7_NORMAL) set_weapon_anim(Id, J7_ANIM_IDLE)
		else if(g_Janus7_Mode[Id] == Janus7_ACTIVE) set_weapon_anim(Id, J7_ANIM_IDLE_ACTIVE)
		else if(g_Janus7_Mode[Id] == Janus7_JANUS) set_weapon_anim(Id, J7_ANIM_IDLE_JANUS)
		
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
	if(!Get_BitVar(g_Had_Janus7, Id))
		return
	
	set_pev(Id, pev_viewmodel2, V_MODEL)
	set_pev(Id, pev_weaponmodel2, P_MODEL)
	
	if(g_Janus7_Mode[Id] == Janus7_NORMAL) set_weapon_anim(Id, J7_ANIM_DRAW)
	else if(g_Janus7_Mode[Id] == Janus7_ACTIVE) set_weapon_anim(Id, J7_ANIM_DRAW_ACTIVE)
	else if(g_Janus7_Mode[Id] == Janus7_JANUS) set_weapon_anim(Id, J7_ANIM_DRAW_JANUS)
}

public fw_Item_AddToPlayer_Post(Ent, id)
{
	if(!pev_valid(Ent))
		return HAM_IGNORED
		
	if(pev(Ent, pev_impulse) == 11012014)
	{
		Set_BitVar(g_Had_Janus7, id)
		set_pev(Ent, pev_impulse, 0)
	}		
	
	message_begin(MSG_ONE_UNRELIABLE, g_Msg_WeaponList, .player = id)
	write_string(Get_BitVar(g_Had_Janus7, id) ? "weapon_janus7" : "weapon_m249")
	write_byte(3) // PrimaryAmmoID
	write_byte(200) // PrimaryAmmoMaxAmount
	write_byte(-1) // SecondaryAmmoID
	write_byte(-1) // SecondaryAmmoMaxAmount
	write_byte(0) // SlotID (0...N)
	write_byte(4) // NumberInSlot (1...N)
	write_byte(Get_BitVar(g_Had_Janus7, id) ? CSW_JANUS7 : CSW_M249) // WeaponID
	write_byte(0) // Flags
	message_end()

	return HAM_HANDLED	
}

public fw_Item_PostFrame(ent)
{
	static id; id = pev(ent, pev_owner)
	if(!is_user_alive(id))
		return HAM_IGNORED
	if(!Get_BitVar(g_Had_Janus7, id))
		return HAM_IGNORED	
	
	static Float:flNextAttack; flNextAttack = get_pdata_float(id, 83, 5)
	static bpammo; bpammo = cs_get_user_bpammo(id, CSW_JANUS7)
	
	static iClip; iClip = get_pdata_int(ent, 51, 4)
	static fInReload; fInReload = get_pdata_int(ent, 54, 4)
	
	if(fInReload && flNextAttack <= 0.0)
	{
		static temp1
		temp1 = min(CLIP - iClip, bpammo)

		set_pdata_int(ent, 51, iClip + temp1, 4)
		cs_set_user_bpammo(id, CSW_JANUS7, bpammo - temp1)		
		
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
	if(!Get_BitVar(g_Had_Janus7, id))
		return HAM_IGNORED	
	if(g_Janus7_Mode[id] == Janus7_JANUS)
	{
		set_pdata_int(ent, 54, 0, 4)
		return HAM_SUPERCEDE
	}

	g_Janus7_Clip[id] = -1
		
	static BPAmmo; BPAmmo = cs_get_user_bpammo(id, CSW_JANUS7)
	static iClip; iClip = get_pdata_int(ent, 51, 4)
		
	if(BPAmmo <= 0)
		return HAM_SUPERCEDE
	if(iClip >= CLIP)
		return HAM_SUPERCEDE		
			
	g_Janus7_Clip[id] = iClip	
	
	return HAM_HANDLED
}

public fw_Weapon_Reload_Post(ent)
{
	static id; id = pev(ent, pev_owner)
	if(!is_user_alive(id))
		return HAM_IGNORED
	if(!Get_BitVar(g_Had_Janus7, id))
		return HAM_IGNORED	
	if(g_Janus7_Mode[id] == Janus7_JANUS)
	{
		set_pdata_int(ent, 54, 0, 4)
		return HAM_SUPERCEDE
	}
		
	if((get_pdata_int(ent, 54, 4) == 1))
	{ // Reload
		if(g_Janus7_Clip[id] == -1)
			return HAM_IGNORED
		
		set_pdata_int(ent, 51, g_Janus7_Clip[id], 4)
		
		if(g_Janus7_Mode[id] == Janus7_NORMAL) set_weapon_anim(id, J7_ANIM_RELOAD)
		else if(g_Janus7_Mode[id] == Janus7_ACTIVE) set_weapon_anim(id, J7_ANIM_RELOAD_ACTIVE)
		
		//Set_Player_NextAttack(id, CSW_JANUS7, 
	}
	
	return HAM_HANDLED
}

public fw_TraceAttack_World(Victim, Attacker, Float:Damage, Float:Direction[3], Ptr, DamageBits)
{
	if(!is_user_connected(Attacker))
		return HAM_IGNORED	
	if(get_user_weapon(Attacker) != CSW_JANUS7 || !Get_BitVar(g_Had_Janus7, Attacker))
		return HAM_IGNORED
		
	static Float:flEnd[3], Float:vecPlane[3]
		
	get_tr2(Ptr, TR_vecEndPos, flEnd)
	get_tr2(Ptr, TR_vecPlaneNormal, vecPlane)		
			
	Make_BulletHole(Attacker, flEnd, Damage)
	Make_BulletSmoke(Attacker, Ptr)

	SetHamParamFloat(3, g_Janus7_Mode[Attacker] == Janus7_JANUS ? float(DAMAGE_B) : float(DAMAGE_A))
	
	if(g_Janus7_Mode[Attacker] == Janus7_NORMAL)
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
	if(get_user_weapon(Attacker) != CSW_JANUS7 || !Get_BitVar(g_Had_Janus7, Attacker))
		return HAM_IGNORED
		
	SetHamParamFloat(3, g_Janus7_Mode[Attacker] == Janus7_JANUS ? float(DAMAGE_B) : float(DAMAGE_A))
	if(cs_get_user_team(Attacker) != cs_get_user_team(Victim) && g_Janus7_Mode[Attacker] == Janus7_NORMAL) 
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
		g_Janus7_Mode[id] = Janus7_ACTIVE
		set_weapon_anim(id, J7_ANIM_IDLE_ACTIVE)
		
		emit_sound(id, CHAN_VOICE, Janus7_Sounds[2], 1.0, ATTN_NORM, 0, PITCH_NORM)
		
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
		
	g_Janus7_Mode[id] = Janus7_NORMAL
	g_BulletCount[id] = 0
	
	set_weapon_anim(id, J7_ANIM_IDLE)
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
