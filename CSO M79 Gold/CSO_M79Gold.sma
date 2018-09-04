#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <cstrike>
#include <fun>

#define PLUGIN "[CSO] M79 Gold"
#define VERSION "1.0"
#define AUTHOR "Dias Pendoragon"

#define DAMAGE 70 // 280 for Zombies
#define AMMO 6

#define RELOAD_TIME 3.0
#define GRENADE_RADIUS 120.0

#define V_MODEL "models/v_m79g.mdl"
#define P_MODEL "models/p_m79g.mdl"
#define W_MODEL "models/w_m79g.mdl"
#define S_MODEL "models/s_oicw.mdl"

new const WeaponSounds[5][] =
{
	"weapons/m79-1.wav",
	"weapons/m79_draw.wav",
	"weapons/m79_clipin.wav",
	"weapons/m79_clipon.wav",
	"weapons/m79_clipout.wav"
}

#define CSW_M79G CSW_DEAGLE
#define weapon_m79g "weapon_deagle"

#define WEAPON_SECRETCODE 28122014
#define OLD_W_MODEL "models/w_deagle.mdl"
#define OLD_EVENT "events/deagle.sc"

// Fire Start
#define WEAPON_ATTACH_F 30.0
#define WEAPON_ATTACH_R 10.0
#define WEAPON_ATTACH_U -5.0

enum
{
	ANIM_IDLE = 0,
	ANIM_SHOOT,
	ANIM_SHOOT_LAST,
	ANIM_DRAW
}

// MACROS
#define Get_BitVar(%1,%2) (%1 & (1 << (%2 & 31)))
#define Set_BitVar(%1,%2) %1 |= (1 << (%2 & 31))
#define UnSet_BitVar(%1,%2) %1 &= ~(1 << (%2 & 31))

new g_Had_M79G, g_Ammo[33], Float:g_ShootTime[33], g_MaxPlayers
new g_HamBot, g_MsgCurWeapon, g_MsgAmmoX, g_SmokePuff_SprId, g_Trail_SprId, g_Exp_SprId, g_SmokeSprId

// Safety
new g_IsConnected, g_IsAlive, g_PlayerWeapon[33]

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	register_event("CurWeapon", "Event_CurWeapon", "be", "1=1")
	register_touch("grenade2", "*", "fw_GrenadeTouch")
	
	register_forward(FM_UpdateClientData, "fw_UpdateClientData_Post", 1)
	register_forward(FM_CmdStart, "fw_CmdStart")
	register_forward(FM_SetModel, "fw_SetModel")
	
	RegisterHam(Ham_Item_Deploy, weapon_m79g, "fw_Item_Deploy_Post", 1)	
	RegisterHam(Ham_Item_AddToPlayer, weapon_m79g, "fw_Item_AddToPlayer_Post", 1)	
	
	// Safety
	Register_SafetyFunc()
	
	g_MsgCurWeapon = get_user_msgid("CurWeapon")
	g_MsgAmmoX = get_user_msgid("AmmoX")
	g_MaxPlayers = get_maxplayers()
	
	register_clcmd("say /get", "Get_M79G")
}

public plugin_precache()
{
	precache_model(V_MODEL)
	precache_model(P_MODEL)
	precache_model(W_MODEL)
	precache_model(S_MODEL)
	
	for(new i = 0; i < sizeof(WeaponSounds); i++)
		precache_sound(WeaponSounds[i])
	
	g_SmokePuff_SprId = engfunc(EngFunc_PrecacheModel, "sprites/smokepuff.spr")
	g_Trail_SprId = engfunc(EngFunc_PrecacheModel, "sprites/laserbeam.spr")
	g_Exp_SprId = engfunc(EngFunc_PrecacheModel, "sprites/zerogxplode.spr")
	g_SmokeSprId = engfunc(EngFunc_PrecacheModel, "sprites/steam1.spr")
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
	//RegisterHamFromEntity(Ham_TraceAttack, id, "fw_TraceAttack")
}

public client_disconnect(id)
{
	Safety_Disconnected(id)
}

public Get_M79G(id)
{
	Remove_M79G(id)
	
	g_Ammo[id] = AMMO
	Set_BitVar(g_Had_M79G, id)
	
	give_item(id, weapon_m79g)
	update_ammo(id, -1, AMMO)
}

public Remove_M79G(id)
{
	UnSet_BitVar(g_Had_M79G, id)
}

public Event_CurWeapon(id)
{
	if(!is_user_alive(id))
		return
		
	static CSWID; CSWID = read_data(2)
	if(CSWID == CSW_M79G && Get_BitVar(g_Had_M79G, id)) 
		update_ammo(id, -1, g_Ammo[id])
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
	write_short(g_Exp_SprId)	// sprite index
	write_byte(40)	// scale in 0.1's
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
	write_byte(50)	// scale in 0.1's 
	write_byte(10)	// framerate 
	message_end()
	
	static id; id = pev(ent, pev_owner)
	if(!is_user_connected(id)) return
	
	static Float:Origin2[3]
	for(new i = 0; i < g_MaxPlayers; i++)
	{
		if(!is_user_alive(i))
			continue
		pev(i, pev_origin, Origin2)
		if(get_distance_f(Origin, Origin2) > GRENADE_RADIUS)
			continue
		if(cs_get_user_team(i) == cs_get_user_team(id))
			continue

		ExecuteHamB(Ham_TakeDamage, i, fm_get_user_weapon_entity(id, get_user_weapon(id)), id, float(DAMAGE), DMG_BLAST)
	}
}


public fw_UpdateClientData_Post(id, sendweapons, cd_handle)
{
	if(!is_player(id, 1))
		return FMRES_IGNORED
	if(get_user_weapon(id) != CSW_M79G || !Get_BitVar(g_Had_M79G, id))
		return FMRES_IGNORED
	
	set_cd(cd_handle, CD_flNextAttack, get_gametime() + 0.001) 
	
	return FMRES_HANDLED
}

public fw_CmdStart(id, uc_handle, seed)
{
	if(!is_player(id, 1))
		return FMRES_IGNORED
	if(get_user_weapon(id) != CSW_M79G || !Get_BitVar(g_Had_M79G, id))
		return FMRES_IGNORED
	
	static CurButton
	CurButton = get_uc(uc_handle, UC_Buttons)
	
	if(CurButton & IN_ATTACK)
	{
		CurButton &= ~IN_ATTACK
		set_uc(uc_handle, UC_Buttons, CurButton)
		
		HandleShoot(id)
	}
	
	return FMRES_HANDLED
}

public HandleShoot(id)
{
	if(get_pdata_float(id, 83, 5) > 0.0)
		return
	if(get_gametime() - RELOAD_TIME <= g_ShootTime[id])
		return
		
	g_ShootTime[id] = get_gametime()
	
	if(!g_Ammo[id])
		return
		
	g_Ammo[id]--
	update_ammo(id, -1, g_Ammo[id])
	
	if(g_Ammo[id]) 
	{
		Set_Weapon_Idle(id, CSW_M79G, RELOAD_TIME + 0.1)
		Set_Player_NextAttack(id, RELOAD_TIME)
		
		Set_WeaponAnim(id, ANIM_SHOOT)
	} else {
		Set_Weapon_Idle(id, CSW_M79G, RELOAD_TIME + 0.1)
		Set_Player_NextAttack(id, RELOAD_TIME)
		
		Set_WeaponAnim(id, ANIM_SHOOT_LAST)
	}
	
	emit_sound(id, CHAN_WEAPON, WeaponSounds[0], 1.0, ATTN_NORM, 0, PITCH_NORM)
	
	static Float:PunchAngles[3]
	PunchAngles[0] = random_float(-3.0, -6.0)
	
	set_pev(id, pev_punchangle, PunchAngles)
	Make_FireSmoke(id)
	
	Create_Grenade(id)
}

public Create_Grenade(id)
{
	static Ent; Ent = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"))
	if(!pev_valid(Ent)) return
	
	static Float:Origin[3], Float:Angles[3]
	
	get_weapon_attachment(id, Origin, 24.0)
	pev(id, pev_angles, Angles)
	
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
	get_speed_vector(Origin, TargetOrigin, 1800.0, Velocity)
	
	set_pev(Ent, pev_velocity, Velocity)
	
	// Make a Beam
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_BEAMFOLLOW)
	write_short(Ent) // entity
	write_short(g_Trail_SprId) // sprite
	write_byte(20)  // life
	write_byte(4)  // width
	write_byte(200) // r
	write_byte(200);  // g
	write_byte(200);  // b
	write_byte(200); // brightness
	message_end();
	
	
}

public Make_FireSmoke(id)
{
	static Float:Origin[3]
	get_position(id, WEAPON_ATTACH_F, WEAPON_ATTACH_R, WEAPON_ATTACH_U, Origin)
	
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY) 
	write_byte(TE_EXPLOSION) 
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2] - 5.0)
	write_short(g_SmokePuff_SprId)
	write_byte(10)
	write_byte(15)
	write_byte(14)
	message_end()
}

public fw_SetModel(entity, model[])
{
	if(!pev_valid(entity))
		return FMRES_IGNORED
	
	static szClassName[33]
	pev(entity, pev_classname, szClassName, charsmax(szClassName))
	
	if(!equal(szClassName, "weaponbox"))
		return FMRES_IGNORED
	
	static id
	id = pev(entity, pev_owner)
	
	if(equal(model, OLD_W_MODEL))
	{
		static weapon
		weapon = fm_find_ent_by_owner(-1, weapon_m79g, entity)
		
		if(!pev_valid(weapon))
			return FMRES_IGNORED
		
		if(Get_BitVar(g_Had_M79G, id))
		{
			set_pev(weapon, pev_impulse, WEAPON_SECRETCODE)
			set_pev(weapon, pev_iuser4, g_Ammo[id])
			
			engfunc(EngFunc_SetModel, entity, W_MODEL)
			Remove_M79G(id)
			
			return FMRES_SUPERCEDE
		}
	}

	return FMRES_IGNORED
}

public update_ammo(id, Ammo, BpAmmo)
{
	message_begin(MSG_ONE_UNRELIABLE, g_MsgCurWeapon, _, id)
	write_byte(1)
	write_byte(CSW_M79G)
	write_byte(Ammo)
	message_end()
	
	message_begin(MSG_ONE_UNRELIABLE, g_MsgAmmoX, _, id)
	write_byte(8)
	write_byte(BpAmmo)
	message_end()
	
	cs_set_user_bpammo(id, CSW_M79G, BpAmmo)
}

public fw_Item_Deploy_Post(Ent)
{
	if(pev_valid(Ent) != 2)
		return
	static Id; Id = get_pdata_cbase(Ent, 41, 4)
	if(get_pdata_cbase(Id, 373) != Ent)
		return
	if(!Get_BitVar(g_Had_M79G, Id))
		return

	set_pev(Id, pev_viewmodel2, V_MODEL)
	set_pev(Id, pev_weaponmodel2, P_MODEL)
	
	Set_WeaponAnim(Id, ANIM_DRAW)
}

public fw_Item_AddToPlayer_Post(ent, id)
{
	if(pev(ent, pev_impulse) == WEAPON_SECRETCODE)
	{
		Set_BitVar(g_Had_M79G, id)
		
		set_pev(ent, pev_impulse, 0)
		g_Ammo[id] = pev(ent, pev_iuser4)
	}			
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
stock get_position(id,Float:forw, Float:right, Float:up, Float:vStart[])
{
	static Float:vOrigin[3], Float:vAngle[3], Float:vForward[3], Float:vRight[3], Float:vUp[3]
	
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
	if(!is_player(id, 1))
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

public is_player(id, IsAliveCheck)
{
	if(!(1 <= id <= 32))
		return 0
	if(!Get_BitVar(g_IsConnected, id))
		return 0
	if(IsAliveCheck)
	{
		if(Get_BitVar(g_IsAlive, id)) return 1
		else return 0
	}
	
	return 1
}

public get_player_weapon(id)
{
	if(!is_player(id, 1))
		return 0
	
	return g_PlayerWeapon[id]
}

/* ===============================
--------- End of SAFETY ----------
=================================*/
