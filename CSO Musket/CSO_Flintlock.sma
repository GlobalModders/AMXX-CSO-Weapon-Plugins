#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <cstrike>
#include <xs>
#include <fun>

#define PLUGIN "[CSO] Flintlock (Musket)"
#define VERSION "1.0"
#define AUTHOR "Dias Pendragon Leon"

#define DAMAGE_A 200 // 400 for Zombie
#define AMMO 30

#define CSW_FLINTLOCK CSW_DEAGLE
#define weapon_flintlock "weapon_deagle"

#define MODEL_V "models/v_musket.mdl"
#define MODEL_P "models/p_musket.mdl"
#define MODEL_W "models/w_musket.mdl"

#define FLINTLOCK_OLDMODEL "models/w_deagle.mdl"

new const WeaponSounds[4][] =
{
	"weapons/musket_shoot.wav",
	"weapons/cartfrag.wav",
	"weapons/musket_clipin1.wav",
	"weapons/musket_clipin2.wav"
}

enum
{
	ANIME_IDLE = 0,
	ANIME_IDLE_EMPTY,
	ANIME_SHOOT_BEGIN,
	ANIME_SHOOT_FIRE,
	ANIME_SHOOT_LAST,
	ANIME_DRAW
}

const m_iShotsFired = 64;
#define TASK_SHOOTING 22611

// MACROS
#define Get_BitVar(%1,%2) (%1 & (1 << (%2 & 31)))
#define Set_BitVar(%1,%2) %1 |= (1 << (%2 & 31))
#define UnSet_BitVar(%1,%2) %1 &= ~(1 << (%2 & 31))

new g_Had_Flintlock, g_Ammo[33]
new g_Event_Flintlock, g_SmokePuff_SprId
new g_MsgCurWeapon, g_MsgAmmoX, g_MsgWeaponList, g_MaxPlayers

// Safety
new g_IsConnected, g_IsAlive, g_PlayerWeapon[33], g_HamBot

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	// Safety
	Register_SafetyFunc()
	
	register_event("CurWeapon", "Event_CurWeapon", "be", "1=1")
	
	register_forward(FM_UpdateClientData, "fw_UpdateClientData_Post", 1)
	register_forward(FM_PlaybackEvent, "fw_PlaybackEvent")
	register_forward(FM_CmdStart, "fw_CmdStart")
	register_forward(FM_SetModel, "fw_SetModel")	
	
	RegisterHam(Ham_Item_Deploy, weapon_flintlock, "fw_Item_Deploy_Post", 1)	
	RegisterHam(Ham_Item_AddToPlayer, weapon_flintlock, "fw_Item_AddToPlayer_Post", 1)
	RegisterHam(Ham_Weapon_WeaponIdle, weapon_flintlock, "fw_Weapon_WeaponIdle_Post", 1)
	RegisterHam(Ham_Weapon_PrimaryAttack, weapon_flintlock, "fw_Weapon_PrimaryAttack")
	RegisterHam(Ham_Weapon_Reload, weapon_flintlock, "fw_Weapon_Reload")
	RegisterHam(Ham_Weapon_Reload, weapon_flintlock, "fw_Weapon_Reload_Post", 1)	
	
	RegisterHam(Ham_TraceAttack, "worldspawn", "fw_TraceAttack_World")
	RegisterHam(Ham_TraceAttack, "player", "fw_TraceAttack_Player")	
	
	g_MsgCurWeapon = get_user_msgid("CurWeapon")
	g_MsgAmmoX = get_user_msgid("AmmoX")
	g_MsgWeaponList = get_user_msgid("WeaponList")
	g_MaxPlayers = get_maxplayers()
	
	register_clcmd("say /get", "Get_Flintlock")
}

public plugin_precache()
{
	precache_model(MODEL_V)
	precache_model(MODEL_P)
	precache_model(MODEL_W)

	for(new i = 0; i < sizeof(WeaponSounds); i++)
		precache_sound(WeaponSounds[i])
	
	register_forward(FM_PrecacheEvent, "fw_PrecacheEvent_Post", 1)
	g_SmokePuff_SprId = precache_model("sprites/wall_puff1.spr")
}

public fw_PrecacheEvent_Post(type, const name[])
{
	if(equal("events/deagle.sc", name)) g_Event_Flintlock = get_orig_retval()		
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
	RegisterHamFromEntity(Ham_TraceAttack, id, "fw_TraceAttack_Player")	
}

public client_disconnect(id)
{
	Safety_Disconnected(id)
}

public HookWeapon(id)
{
	engclient_cmd(id, weapon_flintlock)
	return PLUGIN_HANDLED
}

public Get_Flintlock(id)
{
	Set_BitVar(g_Had_Flintlock, id)
	give_item(id, weapon_flintlock)
	
	// Clip & Ammo
	static Ent; Ent = fm_get_user_weapon_entity(id, CSW_FLINTLOCK)
	if(!pev_valid(Ent)) return
	
	cs_set_weapon_ammo(Ent, 7)
	cs_set_user_bpammo(id, CSW_FLINTLOCK, AMMO)
	g_Ammo[id] = AMMO
	
	// Update Hud
	Update_AmmoHud(id)
}

public Update_AmmoHud(id)
{
	message_begin(MSG_ONE_UNRELIABLE, g_MsgCurWeapon, _, id)
	write_byte(1)
	write_byte(CSW_FLINTLOCK)
	write_byte(-1)
	message_end()
	
	message_begin(MSG_ONE_UNRELIABLE, g_MsgAmmoX, _, id)
	write_byte(8)
	write_byte(g_Ammo[id])
	message_end()
}

public Remove_Flintlock(id)
{
	UnSet_BitVar(g_Had_Flintlock, id)
	remove_task(id+TASK_SHOOTING)
}

public Event_CurWeapon(id)
{
	if(!is_alive(id)) return
	static CSW; CSW = read_data(2)
	if(CSW != CSW_FLINTLOCK || !Get_BitVar(g_Had_Flintlock, id)) return
	
	Update_AmmoHud(id)
}

public fw_UpdateClientData_Post(id, sendweapons, cd_handle)
{
	if(!is_alive(id))
		return FMRES_IGNORED	
	if(get_user_weapon(id) == CSW_FLINTLOCK && Get_BitVar(g_Had_Flintlock, id))
		set_cd(cd_handle, CD_flNextAttack, get_gametime() + 0.001) 
	
	return FMRES_HANDLED
}

public fw_PlaybackEvent(flags, invoker, eventid, Float:delay, Float:origin[3], Float:angles[3], Float:fparam1, Float:fparam2, iParam1, iParam2, bParam1, bParam2)
{
	if (!is_connected(invoker))
		return FMRES_IGNORED	
	if(get_player_weapon(invoker) != CSW_FLINTLOCK || !Get_BitVar(g_Had_Flintlock, invoker))
		return FMRES_IGNORED
	if(eventid != g_Event_Flintlock)
		return FMRES_IGNORED
	
	engfunc(EngFunc_PlaybackEvent, flags | FEV_HOSTONLY, invoker, eventid, delay, origin, angles, fparam1, fparam2, iParam1, iParam2, bParam1, bParam2)

	g_Ammo[invoker] --
	Update_AmmoHud(invoker)
	
	if(!g_Ammo[invoker]) Set_WeaponAnim(invoker, ANIME_SHOOT_LAST)
	else Set_WeaponAnim(invoker, ANIME_SHOOT_FIRE)
	
	static Ent; Ent = fm_get_user_weapon_entity(invoker, CSW_FLINTLOCK)
	if(pev_valid(Ent)) cs_set_weapon_ammo(Ent, 7)
	
	emit_sound(invoker, CHAN_WEAPON, WeaponSounds[0], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	emit_sound(invoker, CHAN_STATIC, WeaponSounds[0], VOL_NORM, ATTN_NORM, 0, PITCH_HIGH)
	
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
	
	if(equal(model, FLINTLOCK_OLDMODEL))
	{
		static weapon; weapon = find_ent_by_owner(-1, weapon_flintlock, entity)
		
		if(!pev_valid(weapon))
			return FMRES_IGNORED;
		
		if(Get_BitVar(g_Had_Flintlock, iOwner))
		{
			set_pev(weapon, pev_impulse, 2262015)
			
			engfunc(EngFunc_SetModel, entity, MODEL_W)
			set_pev(weapon, pev_iuser1, g_Ammo[iOwner])
			
			Remove_Flintlock(iOwner)
			
			return FMRES_SUPERCEDE
		}
	}

	return FMRES_IGNORED;
}

public fw_CmdStart(id, uc_handle, seed)
{
	if(!is_alive(id))
		return FMRES_IGNORED
	if(get_user_weapon(id) != CSW_FLINTLOCK || !Get_BitVar(g_Had_Flintlock, id))
		return FMRES_IGNORED
		
	static PressedButton
	PressedButton = get_uc(uc_handle, UC_Buttons)
	
	if(PressedButton & IN_ATTACK)
	{
		if(get_pdata_float(id, 83, 5) > 0.0)
			return FMRES_IGNORED
			
		PressedButton &= ~IN_ATTACK
		set_uc(uc_handle, UC_Buttons, PressedButton)
			
		if(g_Ammo[id] <= 0)
			return FMRES_IGNORED
			
		Set_PlayerNextAttack(id, 1.0)
		Set_WeaponAnim(id, ANIME_SHOOT_BEGIN)
		
		remove_task(id+TASK_SHOOTING)
		set_task(0.25, "Shoot_Fire", id+TASK_SHOOTING)
	}
	
	return FMRES_HANDLED
}

public Shoot_Fire(id)
{
	id -= TASK_SHOOTING
	
	if(!is_alive(id))
		return
	if(get_user_weapon(id) != CSW_FLINTLOCK || !Get_BitVar(g_Had_Flintlock, id))
		return
		
	static Ent; Ent = fm_get_user_weapon_entity(id, CSW_FLINTLOCK)
	if(pev_valid(Ent)) ExecuteHamB(Ham_Weapon_PrimaryAttack, Ent)
	
	Set_PlayerNextAttack(id, 2.25)
	Set_WeaponIdleTime(id, CSW_FLINTLOCK, 2.5)
}

public fw_Item_Deploy_Post(Ent)
{
	if(pev_valid(Ent) != 2)
		return
	static Id; Id = get_pdata_cbase(Ent, 41, 4)
	if(get_pdata_cbase(Id, 373) != Ent)
		return
	if(!Get_BitVar(g_Had_Flintlock, Id))
		return
	
	remove_task(Id+TASK_SHOOTING)
	set_pev(Id, pev_viewmodel2, MODEL_V)
	set_pev(Id, pev_weaponmodel2, MODEL_P)
	
	Set_WeaponAnim(Id, ANIME_DRAW)
}

public fw_Item_AddToPlayer_Post(Ent, id)
{
	if(!pev_valid(Ent))
		return HAM_IGNORED
		
	if(pev(Ent, pev_impulse) == 2262015)
	{
		Set_BitVar(g_Had_Flintlock, id)
		set_pev(Ent, pev_impulse, 0)
		
		static Ammo; Ammo = pev(Ent, pev_iuser1)
		g_Ammo[id] = Ammo 
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
	if(!Get_BitVar(g_Had_Flintlock, Id))
		return
		
	if(get_pdata_float(iEnt, 48, 4) <= 0.25)
	{
		Set_WeaponAnim(Id, g_Ammo[Id] > 0 ? ANIME_IDLE : ANIME_IDLE_EMPTY)
		set_pdata_float(iEnt, 48, 20.0, 4)
	}	
}

public fw_Weapon_PrimaryAttack(Ent)
{
	if(pev_valid(Ent) != 2)
		return
	static Id; Id = get_pdata_cbase(Ent, 41, 4)
	if(get_pdata_cbase(Id, 373) != Ent)
		return
	if(!Get_BitVar(g_Had_Flintlock, Id))
		return
		
	set_pdata_int(Ent, m_iShotsFired, -1)
}

public fw_Weapon_Reload(ent)
{
	static id; id = pev(ent, pev_owner)
	if(!is_alive(id))
		return HAM_IGNORED
	if(!Get_BitVar(g_Had_Flintlock, id))
	{
		set_pdata_int(ent, 54, 0, 4)
		return HAM_SUPERCEDE
	}	
	
	return HAM_HANDLED
}

public fw_Weapon_Reload_Post(ent)
{
	static id; id = pev(ent, pev_owner)
	if(!is_alive(id))
		return HAM_IGNORED
	if(!Get_BitVar(g_Had_Flintlock, id))
	{
		set_pdata_int(ent, 54, 0, 4)
		return HAM_SUPERCEDE
	}
	
	return HAM_HANDLED
}

public fw_TraceAttack_World(Victim, Attacker, Float:Damage, Float:Direction[3], Ptr, DamageBits)
{
	if(!is_connected(Attacker))
		return HAM_IGNORED	
	if(get_player_weapon(Attacker) != CSW_FLINTLOCK || !Get_BitVar(g_Had_Flintlock, Attacker))
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
	if(get_player_weapon(Attacker) != CSW_FLINTLOCK || !Get_BitVar(g_Had_Flintlock, Attacker))
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
