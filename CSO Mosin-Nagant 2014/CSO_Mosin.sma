#include <amxmodx>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <cstrike>
#include <fun>

#define PLUGIN "[CSO] Mosin-Nagant"
#define VERSION "1.0"
#define AUTHOR "Dias Pendragon"

#define DAMAGE 91 // 191 for Zombie

#define CLIP 5
#define BPAMMO 45

#define SPEED 1.25

#define MODEL_V "models/v_mosin.mdl"
#define MODEL_P "models/p_mosin.mdl"
#define MODEL_W "models/w_mosin.mdl"

new const WeaponSounds[4][] = 
{
	"weapons/mosin-1.wav",
	"weapons/mosin_start_reload.wav",
	"weapons/mosin_insert.wav",
	"weapons/mosin_after_reload.wav"
}

enum
{
	ANIM_IDLE = 0,
	ANIM_SHOOT,
	ANIM_INSERT,
	ANIM_AFTER_RELOAD,
	ANIM_START_RELOAD,
	ANIM_DRAW
}

enum
{
	EVENT_NONE = 0,
	EVENT_ATTACK1,
	EVENT_ATTACK2,
	EVENT_RELOAD
}

#define CSW_MOSIN CSW_SCOUT
#define weapon_mosin "weapon_scout"

#define WEAPON_SECRETCODE 2892014
#define OLD_W_MODEL "models/w_scout.mdl"
#define OLD_EVENT "events/scout.sc"

// MACROS
#define Get_BitVar(%1,%2) (%1 & (1 << (%2 & 31)))
#define Set_BitVar(%1,%2) %1 |= (1 << (%2 & 31))
#define UnSet_BitVar(%1,%2) %1 &= ~(1 << (%2 & 31))

// Main Vars
new g_Had_Mosin, g_Old_Weapon[33]
new g_HamBot, g_Event_MS, g_SmokePuff_Id
new g_MsgCurWeapon

// Safety
new g_IsConnected, g_IsAlive, g_PlayerWeapon[33]

// Reload Shotgun Style

// Shotgun Reload Style
const NOCLIP_WPN_BS	= ((1<<CSW_HEGRENADE)|(1<<CSW_SMOKEGRENADE)|(1<<CSW_FLASHBANG)|(1<<CSW_KNIFE)|(1<<CSW_C4))
const SHOTGUNS_BS	= ((1<<CSW_M3)|(1<<CSW_XM1014))
const SILENT_BS	= ((1<<CSW_USP)|(1<<CSW_M4A1))

// weapons offsets
#define XTRA_OFS_WEAPON			4
#define m_pPlayer				41
#define m_iId					43
#define m_fKnown				44
#define m_flNextPrimaryAttack		46
#define m_flNextSecondaryAttack	47
#define m_flTimeWeaponIdle		48
#define m_iPrimaryAmmoType		49
#define m_iClip				51
#define m_fInReload				54
#define m_fInSpecialReload		55
#define m_fSilent				74

// players offsets
#define XTRA_OFS_PLAYER		5
#define m_flNextAttack		83
#define m_rgAmmo_player_Slot0	376

stock const Float:g_fDelay[CSW_P90+1] = {
	0.00, 2.70, 0.00, 2.00, 0.00, 0.55,   0.00, 3.15, 3.30, 0.00, 4.50, 
		 2.70, 3.50, 3.35, 2.45, 3.30,   2.70, 2.20, 2.50, 2.63, 4.70, 
		 0.55, 3.05, 2.12, 3.50, 0.00,   2.20, 3.00, 2.45, 0.00, 3.40
}

new stock const g_iDftMaxClip[CSW_P90+1] = {
	-1,  13, -1, 10,  1,  7,    1, 30, 30,  1,  30, 
		20, 25, 30, 35, 25,   12, 20, 10, 30, 100, 
		8 , 30, 30, 20,  2,    7, 30, 30, -1,  50}

stock const g_iReloadAnims[CSW_P90+1] = {
	-1,  5, -1, 3, -1,  6,   -1, 1, 1, -1, 14, 
		4,  2, 3,  1,  1,   13, 7, 4,  1,  3, 
		6, 11, 1,  3, -1,    4, 1, 1, -1,  1}

public plugin_init() 
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	Register_SafetyFunc()
	
	register_event("CurWeapon", "Event_CurWeapon", "be", "1=1")
	
	register_forward(FM_SetModel, "fw_SetModel")
	register_forward(FM_CmdStart, "fw_CmdStart")
	register_forward(FM_UpdateClientData, "fw_UpdateClientData_Post", 1)	
	register_forward(FM_PlaybackEvent, "fw_PlaybackEvent")	
	
	
	RegisterHam(Ham_TraceAttack, "player", "fw_TraceAttack")
	RegisterHam(Ham_TraceAttack, "worldspawn", "fw_TraceAttack")		
	
	RegisterHam(Ham_Item_Deploy, weapon_mosin, "fw_Item_Deploy_Post", 1)	
	RegisterHam(Ham_Item_AddToPlayer, weapon_mosin, "fw_Item_AddToPlayer_Post", 1)
	RegisterHam(Ham_Weapon_Reload, weapon_mosin, "fw_Weapon_Reload")
	RegisterHam(Ham_Item_PostFrame, weapon_mosin, "fw_Item_PostFrame")
	//RegisterHam(Ham_Weapon_Reload, weapon_railcannon, "fw_Weapon_Reload_Post", 1)
	
	g_MsgCurWeapon = get_user_msgid("CurWeapon")
	
	register_clcmd("say /get", "Get_Mosin")
}

public plugin_precache()
{
	precache_model(MODEL_V)
	precache_model(MODEL_P)
	precache_model(MODEL_W)
	
	for(new i = 0; i < sizeof(WeaponSounds); i++)
		precache_sound(WeaponSounds[i])
		
	register_forward(FM_PrecacheEvent, "fw_PrecacheEvent_Post", 1)	
	
	g_SmokePuff_Id = engfunc(EngFunc_PrecacheModel, "sprites/wall_puff1.spr")	
}

public fw_PrecacheEvent_Post(type, const name[])
{
	if(equal(OLD_EVENT, name))
		g_Event_MS = get_orig_retval()
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
	RegisterHamFromEntity(Ham_TraceAttack, id, "fw_TraceAttack")
}

public client_disconnect(id)
{
	Safety_Disconnected(id)
}

public Get_Mosin(id)
{
	Remove_Mosin(id)
	
	Set_BitVar(g_Had_Mosin, id)
	
	give_item(id, weapon_mosin)
	cs_set_user_bpammo(id, CSW_MOSIN, BPAMMO)
	
	static Ent; Ent = fm_get_user_weapon_entity(id, CSW_MOSIN)
	if(pev_valid(Ent)) cs_set_weapon_ammo(Ent, CLIP)
	
	engfunc(EngFunc_MessageBegin, MSG_ONE_UNRELIABLE, g_MsgCurWeapon, {0, 0, 0}, id)
	write_byte(1)
	write_byte(CSW_MOSIN)
	write_byte(CLIP)
	message_end()
}

public Remove_Mosin(id)
{
	UnSet_BitVar(g_Had_Mosin, id)
}

public Event_CurWeapon(id)
{
	if(!is_alive(id))
		return
	
	static CSWID; CSWID = read_data(2)
	
	if((CSWID == CSW_MOSIN && g_Old_Weapon[id] == CSW_MOSIN) && Get_BitVar(g_Had_Mosin, id)) 
	{
		static Ent; Ent = fm_get_user_weapon_entity(id, CSW_MOSIN)
		if(!pev_valid(Ent))
		{
			g_Old_Weapon[id] = get_user_weapon(id)
			return
		}
		
		if(cs_get_user_zoom(id) == 1)
		{
			set_pev(id, pev_viewmodel2, MODEL_V)
		} else if(cs_get_user_zoom(id) == 2 || cs_get_user_zoom(id) == 3) {
			set_pev(id, pev_viewmodel2, "")
		}
		
		static Float:TargetTime; TargetTime = get_pdata_float(Ent, 46, 4) * SPEED
		
		set_pdata_float(Ent, 46, TargetTime, 4)
		set_pdata_float(id, 83, TargetTime, 5)
	}
	
	g_Old_Weapon[id] = get_user_weapon(id)
}

public fw_SetModel(entity, model[])
{
	if(!pev_valid(entity))
		return FMRES_IGNORED
	
	static Classname[64]
	pev(entity, pev_classname, Classname, sizeof(Classname))
	
	if(!equal(Classname, "weaponbox"))
		return FMRES_IGNORED
	
	static id
	id = pev(entity, pev_owner)
	
	if(equal(model, OLD_W_MODEL))
	{
		static weapon
		weapon = fm_get_user_weapon_entity(entity, CSW_MOSIN)
		
		if(!pev_valid(weapon))
			return FMRES_IGNORED
		
		if(Get_BitVar(g_Had_Mosin, id))
		{
			set_pev(weapon, pev_impulse, WEAPON_SECRETCODE)
			engfunc(EngFunc_SetModel, entity, MODEL_W)
			
			Remove_Mosin(id)
			
			return FMRES_SUPERCEDE
		}
	}

	return FMRES_IGNORED;
}

public fw_CmdStart(id, uc_handle, seed)
{
	if(!is_alive(id))
		return FMRES_IGNORED
		
	static iEnt; iEnt = fm_get_user_weapon_entity(id, get_user_weapon(id))
	static PressButton; PressButton = get_uc(uc_handle, UC_Buttons)
	
	if((PressButton & IN_RELOAD) && cs_get_weapon_ammo(iEnt) < CLIP && cs_get_user_bpammo(id, CSW_MOSIN) > 0 && !get_pdata_int(iEnt, m_fInSpecialReload, XTRA_OFS_WEAPON))
	{
		set_uc(uc_handle, UC_Buttons, PressButton & ~IN_RELOAD)
		
		cs_set_user_zoom(id, CS_RESET_ZOOM, 1)
		
		set_pdata_int(iEnt, m_fInReload, 0, XTRA_OFS_WEAPON)
		set_pdata_int(iEnt, m_fInSpecialReload, 1, XTRA_OFS_WEAPON)
	}
	
	return FMRES_IGNORED
}
    
public fw_UpdateClientData_Post(id, sendweapons, cd_handle)
{
	if(!is_alive(id))
		return FMRES_IGNORED	
	if(get_player_weapon(id) == CSW_MOSIN && Get_BitVar(g_Had_Mosin, id))
		set_cd(cd_handle, CD_flNextAttack, get_gametime() + 0.001) 
	
	return FMRES_HANDLED
}

public fw_PlaybackEvent(flags, invoker, eventid, Float:delay, Float:origin[3], Float:angles[3], Float:fparam1, Float:fparam2, iParam1, iParam2, bParam1, bParam2)
{
	if (!is_connected(invoker))
		return FMRES_IGNORED		
	if(get_player_weapon(invoker) == CSW_MOSIN && Get_BitVar(g_Had_Mosin, invoker) && eventid == g_Event_MS)
	{
		engfunc(EngFunc_PlaybackEvent, flags | FEV_HOSTONLY, invoker, eventid, delay, origin, angles, fparam1, fparam2, iParam1, iParam2, bParam1, bParam2)	

		Set_WeaponAnim(invoker, ANIM_SHOOT)
		emit_sound(invoker, CHAN_WEAPON, WeaponSounds[0], 1.0, ATTN_NORM, 0, PITCH_NORM)	

		set_pdata_float(invoker, 111, get_gametime() + 0.75)
		
		static Ent; Ent = fm_get_user_weapon_entity(invoker, CSW_MOSIN)
		set_pdata_int(Ent, m_fInSpecialReload, 0, XTRA_OFS_WEAPON)
		
		return FMRES_SUPERCEDE
	}
	
	return FMRES_HANDLED
}

public fw_TraceAttack(Ent, Attacker, Float:Damage, Float:Dir[3], ptr, DamageType)
{
	if(!is_connected(Attacker))
		return HAM_IGNORED	
	if(get_player_weapon(Attacker) != CSW_MOSIN || !Get_BitVar(g_Had_Mosin, Attacker))
		return HAM_IGNORED
		
	static Float:flEnd[3], Float:vecPlane[3]
		
	get_tr2(ptr, TR_vecEndPos, flEnd)
	get_tr2(ptr, TR_vecPlaneNormal, vecPlane)		
			
	make_bullet(Attacker, flEnd)
	fake_smoke(Attacker, ptr)
		
	SetHamParamFloat(3, float(DAMAGE))
		
	return HAM_HANDLED	
}

public fw_Item_Deploy_Post(Ent)
{
	if(pev_valid(Ent) != 2)
		return
	static Id; Id = get_pdata_cbase(Ent, 41, 4)
	if(get_pdata_cbase(Id, 373) != Ent)
		return
	if(!Get_BitVar(g_Had_Mosin, Id))
		return

	set_pev(Id, pev_viewmodel2, MODEL_V)
	set_pev(Id, pev_weaponmodel2, MODEL_P)
	
	Set_WeaponAnim(Id, ANIM_DRAW)
	set_pdata_int(Ent, m_fInSpecialReload, 0, XTRA_OFS_WEAPON)
}

public fw_Item_AddToPlayer_Post(ent, id)
{
	if(pev(ent, pev_impulse) == WEAPON_SECRETCODE)
	{
		Set_BitVar(g_Had_Mosin, id)
		set_pev(ent, pev_impulse, 0)
	}			
}

public fw_Weapon_Reload(iEnt)
{
	static id ; id = get_pdata_cbase(iEnt, m_pPlayer, XTRA_OFS_WEAPON)
	if(!is_alive(id))
		return HAM_IGNORED
	if(!Get_BitVar(g_Had_Mosin, id))
		return HAM_IGNORED	
	
	set_pdata_int(iEnt, m_fInReload, 0, 4)
	set_pdata_int(iEnt, m_fInSpecialReload, 1, XTRA_OFS_WEAPON)
	
	return HAM_SUPERCEDE
}

public fw_Item_PostFrame( iEnt )
{
	static id ; id = get_pdata_cbase(iEnt, m_pPlayer, XTRA_OFS_WEAPON)	

	static iBpAmmo ; iBpAmmo = get_pdata_int(id, 381, XTRA_OFS_PLAYER)
	static iClip ; iClip = get_pdata_int(iEnt, m_iClip, XTRA_OFS_WEAPON)

	if(get_pdata_int(id, m_flNextAttack, XTRA_OFS_PLAYER) > 0.0)
		return

	switch(get_pdata_int(iEnt, m_fInSpecialReload, XTRA_OFS_WEAPON) )
	{
		case 1: // Check, Start
		{
			if(cs_get_weapon_ammo(iEnt) >= CLIP || cs_get_user_bpammo(id, CSW_MOSIN) <= 0)
			{
				set_pdata_int(iEnt, m_fInSpecialReload, 0, XTRA_OFS_WEAPON)
				return
			}
			
			Set_WeaponAnim(id, ANIM_START_RELOAD)
			
			set_pdata_float(id, m_flNextAttack, 0.75, 5)
			set_pdata_float(iEnt, m_flTimeWeaponIdle, 0.75, XTRA_OFS_WEAPON)
			set_pdata_float(iEnt, m_flNextPrimaryAttack, 0.75, XTRA_OFS_WEAPON)
			set_pdata_float(iEnt, m_flNextSecondaryAttack, 0.75, XTRA_OFS_WEAPON)
			
			set_pdata_int(iEnt, m_fInSpecialReload, 2, XTRA_OFS_WEAPON)
		}
		case 2: // Insert 
		{
			if(cs_get_weapon_ammo(iEnt) >= CLIP || cs_get_user_bpammo(id, CSW_MOSIN) <= 0)
			{
				set_pdata_int(iEnt, m_fInSpecialReload, 4, XTRA_OFS_WEAPON)
				return
			} else {
				set_pdata_int(iEnt, m_fInSpecialReload, 3, XTRA_OFS_WEAPON)
			}
			
			emit_sound(id, CHAN_ITEM, WeaponSounds[2], 1.0, ATTN_NORM, 0, 85 + random_num(0,0x1f))
			Set_WeaponAnim(id, ANIM_INSERT)

			set_pdata_float(iEnt, m_flTimeWeaponIdle, 0.45, XTRA_OFS_WEAPON)
			set_pdata_float(iEnt, m_flNextPrimaryAttack, 0.45, XTRA_OFS_WEAPON)
			set_pdata_float(iEnt, m_flNextSecondaryAttack, 0.45, XTRA_OFS_WEAPON)
			set_pdata_float(id, m_flNextAttack, 0.45, 5)
		}
		case 3: // Done Insert
		{
			set_pdata_int(iEnt, m_iClip, iClip + 1, XTRA_OFS_WEAPON)
			set_pdata_int(id, 381, iBpAmmo-1, XTRA_OFS_PLAYER)
			cs_set_user_bpammo(id, CSW_MOSIN, cs_get_user_bpammo(id, CSW_MOSIN) - 1)
			
			set_pdata_float(iEnt, m_flTimeWeaponIdle, 0.1, XTRA_OFS_WEAPON)
			set_pdata_float(iEnt, m_flNextPrimaryAttack, 0.1, XTRA_OFS_WEAPON)
			set_pdata_float(iEnt, m_flNextSecondaryAttack, 0.1, XTRA_OFS_WEAPON)
			set_pdata_float(id, m_flNextAttack, 0.1, 5)
			
			set_pdata_int(iEnt, m_fInSpecialReload, 2, XTRA_OFS_WEAPON)
		}
		case 4: // Stop Reload
		{
			Set_WeaponAnim(id, ANIM_AFTER_RELOAD)

			set_pdata_int(iEnt, m_fInSpecialReload, 0, XTRA_OFS_WEAPON)
			set_pdata_float(iEnt, m_flTimeWeaponIdle, 1.5, XTRA_OFS_WEAPON)
			set_pdata_float(iEnt, m_flNextPrimaryAttack, 1.5, XTRA_OFS_WEAPON)
			set_pdata_float(iEnt, m_flNextSecondaryAttack, 1.5, XTRA_OFS_WEAPON)
			set_pdata_float(id, m_flNextAttack, 1.5, 5)
		}
	}
}

stock Set_WeaponAnim(id, anim)
{
	set_pev(id, pev_weaponanim, anim)
	
	message_begin(MSG_ONE_UNRELIABLE, SVC_WEAPONANIM, {0, 0, 0}, id)
	write_byte(anim)
	write_byte(pev(id, pev_body))
	message_end()
}

stock Set_Weapon_Idle(id, WeaponId ,Float:TimeIdle)
{
	static entwpn; entwpn = fm_get_user_weapon_entity(id, WeaponId)
	if(!pev_valid(entwpn)) 
		return
		
	set_pdata_float(entwpn, 46, TimeIdle, 4)
	set_pdata_float(entwpn, 47, TimeIdle, 4)
	set_pdata_float(entwpn, 48, TimeIdle + 0.5, 4)
}

stock Set_Player_NextAttack(id, Float:NextTime) set_pdata_float(id, 83, NextTime, 5)
stock make_bullet(id, Float:Origin[3])
{
	// Find target
	new decal = random_num(41, 45)
	const loop_time = 2
	
	static Body, Target
	get_user_aiming(id, Target, Body, 999999)
	
	if(is_user_connected(Target))
		return
	
	for(new i = 0; i < loop_time; i++)
	{
		// Put decal on "world" (a wall)
		message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
		write_byte(TE_WORLDDECAL)
		engfunc(EngFunc_WriteCoord, Origin[0])
		engfunc(EngFunc_WriteCoord, Origin[1])
		engfunc(EngFunc_WriteCoord, Origin[2])
		write_byte(decal)
		message_end()
		
		// Show sparcles
		message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
		write_byte(TE_GUNSHOTDECAL)
		engfunc(EngFunc_WriteCoord, Origin[0])
		engfunc(EngFunc_WriteCoord, Origin[1])
		engfunc(EngFunc_WriteCoord, Origin[2])
		write_short(id)
		write_byte(decal)
		message_end()
	}
}

stock fake_smoke(id, trace_result)
{
	static Float:vecSrc[3], Float:vecEnd[3], TE_FLAG
	
	get_weapon_attachment(id, vecSrc)
	global_get(glb_v_forward, vecEnd)
    
	xs_vec_mul_scalar(vecEnd, 8192.0, vecEnd)
	xs_vec_add(vecSrc, vecEnd, vecEnd)

	get_tr2(trace_result, TR_vecEndPos, vecSrc)
	get_tr2(trace_result, TR_vecPlaneNormal, vecEnd)
    
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
	write_short(g_SmokePuff_Id)
	write_byte(2)
	write_byte(50)
	write_byte(TE_FLAG)
	message_end()
}

stock get_weapon_attachment(id, Float:output[3], Float:fDis = 40.0)
{ 
	new Float:vfEnd[3], viEnd[3] 
	get_user_origin(id, viEnd, 3)  
	IVecFVec(viEnd, vfEnd) 
	
	new Float:fOrigin[3], Float:fAngle[3]
	
	pev(id, pev_origin, fOrigin) 
	pev(id, pev_view_ofs, fAngle)
	
	xs_vec_add(fOrigin, fAngle, fOrigin) 
	
	new Float:fAttack[3]
	
	xs_vec_sub(vfEnd, fOrigin, fAttack)
	xs_vec_sub(vfEnd, fOrigin, fAttack) 
	
	new Float:fRate
	
	fRate = fDis / vector_length(fAttack)
	xs_vec_mul_scalar(fAttack, fRate, fAttack)
	
	xs_vec_add(fOrigin, fAttack, output)
}

stock get_position(ent, Float:forw, Float:right, Float:up, Float:vStart[])
{
	static Float:vOrigin[3], Float:vAngle[3], Float:vForward[3], Float:vRight[3], Float:vUp[3]
	
	pev(ent, pev_origin, vOrigin)
	pev(ent, pev_view_ofs,vUp) //for player
	xs_vec_add(vOrigin,vUp,vOrigin)
	pev(ent, pev_v_angle, vAngle) // if normal entity ,use pev_angles
	
	angle_vector(vAngle,ANGLEVECTOR_FORWARD,vForward) //or use EngFunc_AngleVectors
	angle_vector(vAngle,ANGLEVECTOR_RIGHT,vRight)
	angle_vector(vAngle,ANGLEVECTOR_UP,vUp)
	
	vStart[0] = vOrigin[0] + vForward[0] * forw + vRight[0] * right + vUp[0] * up
	vStart[1] = vOrigin[1] + vForward[1] * forw + vRight[1] * right + vUp[1] * up
	vStart[2] = vOrigin[2] + vForward[2] * forw + vRight[2] * right + vUp[2] * up
}

stock PlaySound(id, const sound[])
{
	if(equal(sound[strlen(sound)-4], ".mp3")) client_cmd(id, "mp3 play ^"sound/%s^"", sound)
	else client_cmd(id, "spk ^"%s^"", sound)
}

stock Eject_Shell(id, Shell_ModelIndex, Float:Time) // By Dias
{
	static Ent; Ent = get_pdata_cbase(id, 373, 5)
	if(!pev_valid(Ent))
		return

        set_pdata_int(Ent, 57, Shell_ModelIndex, 4)
        set_pdata_float(id, 111, get_gametime() + Time)
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
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang1042\\ f0\\ fs16 \n\\ par }
*/
