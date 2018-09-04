#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <cstrike>
#include <xs>
#include <fun>

#define PLUGIN "[CSO] Dart Pistol"
#define VERSION "1.0"
#define AUTHOR "Dias"

#define DAMAGE 35
#define CLIP 5
#define BPAMMO 50
#define TIME_RELOAD 4.0
#define TIME_SHOOT 4.0

#define DART_SPEED 1000
#define DART_SHOCKTIME 1.0
#define DART_LIVETIME 5.0
#define DART_SHOCKRADIUS 64.0

#define MODEL_V "models/v_dartpistol.mdl"
#define MODEL_P "models/p_dartpistol.mdl"
#define MODEL_W "models/w_dartpistol.mdl"
#define MODEL_S "models/dart.mdl"

#define DARTPISTOL_OLDMODEL "models/w_deagle.mdl"
#define DART_CLASSNAME "dart"

new const WeaponSounds[10][] =
{
	"weapons/dartpistol-1.wav",
	"weapons/dartpistol_shoot_empty.wav",
	"weapons/dartpistol_explosion1.wav",
	"weapons/dartpistol_explosion2.wav",
	"weapons/dartpistol_draw.wav",
	"weapons/dartpistol_clipin1.wav",
	"weapons/dartpistol_clipin2.wav",
	"weapons/dartpistol_clipin3.wav",
	"weapons/dartpistol_clipout1.wav",
	"weapons/dartpistol_clipout2.wav"
}

new const Electric_Sprite[] = "sprites/dart_explosion.spr"

enum
{
	ANIME_IDLE = 0,
	ANIME_SHOOT,
	ANIME_SHOOT2,
	ANIME_RELOAD,
	ANIME_DRAW,
	ANIME_SHOOT_EMPTY
}

// MACROS
#define Get_BitVar(%1,%2) (%1 & (1 << (%2 & 31)))
#define Set_BitVar(%1,%2) %1 |= (1 << (%2 & 31))
#define UnSet_BitVar(%1,%2) %1 &= ~(1 << (%2 & 31))

const pev_user = pev_iuser1
const pev_touched = pev_iuser2
const pev_attached = pev_iuser3
const pev_hitgroup = pev_iuser4
const pev_time = pev_fuser1
const pev_time2 = pev_fuser2
const pev_time3 = pev_fuser4

const m_iLastHitGroup = 75

// Vars
new g_Had_DartPistol, g_Clip[33]
new g_SprID, g_Event_DartPistol, g_SprId_LaserBeam
new g_CvarFriendlyFire, g_MaxPlayers

// Safety
new g_IsConnected, g_IsAlive, g_PlayerWeapon[33], g_HamBot

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	// Safety
	Register_SafetyFunc()
	
	register_event("CurWeapon", "Event_CurWeapon", "be", "1=1")
	
	// Forward
	register_forward(FM_UpdateClientData, "fw_UpdateClientData_Post", 1)
	register_forward(FM_PlaybackEvent, "fw_PlaybackEvent")
	register_forward(FM_CmdStart, "fw_CmdStart")
	register_forward(FM_SetModel, "fw_SetModel")	
	
	register_think(DART_CLASSNAME, "fw_SpearThink")
	register_touch(DART_CLASSNAME, "*", "fw_SpearTouch")
	
	// Ham
	RegisterHam(Ham_Item_Deploy, "weapon_deagle", "fw_Item_Deploy_Post", 1)	
	RegisterHam(Ham_Item_AddToPlayer, "weapon_deagle", "fw_Item_AddToPlayer_Post", 1)
	RegisterHam(Ham_Weapon_WeaponIdle, "weapon_deagle", "fw_Weapon_WeaponIdle_Post", 1)
	RegisterHam(Ham_Item_PostFrame, "weapon_deagle", "fw_Item_PostFrame")	
	RegisterHam(Ham_Weapon_Reload, "weapon_deagle", "fw_Weapon_Reload")
	RegisterHam(Ham_Weapon_Reload, "weapon_deagle", "fw_Weapon_Reload_Post", 1)	
	
	RegisterHam(Ham_TraceAttack, "worldspawn", "fw_TraceAttack_World")
	RegisterHam(Ham_TraceAttack, "player", "fw_TraceAttack_Player")	
	
	g_CvarFriendlyFire = get_cvar_pointer("mp_friendlyfire")
	g_MaxPlayers = get_maxplayers()
	
	register_clcmd("say /get", "Get_DartPistol")
}

public plugin_precache()
{
	precache_model(MODEL_V)
	precache_model(MODEL_P)
	precache_model(MODEL_W)
	precache_model(MODEL_S)

	for(new i = 0; i < sizeof(WeaponSounds); i++)
		precache_sound(WeaponSounds[i])
		
	g_SprID = precache_model(Electric_Sprite)
	g_SprId_LaserBeam = engfunc(EngFunc_PrecacheModel, "sprites/laserbeam.spr")
	
	register_forward(FM_PrecacheEvent, "fw_PrecacheEvent_Post", 1)
}

public fw_PrecacheEvent_Post(type, const name[])
{
	if(equal("events/deagle.sc", name)) g_Event_DartPistol = get_orig_retval()		
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

public Get_DartPistol(id)
{
	Set_BitVar(g_Had_DartPistol, id)
	give_item(id, "weapon_deagle")
	
	// Clip & Ammo
	static Ent; Ent = fm_get_user_weapon_entity(id, CSW_DEAGLE)
	if(!pev_valid(Ent)) return
	
	cs_set_weapon_ammo(Ent, CLIP)
	cs_set_user_bpammo(id, CSW_DEAGLE, BPAMMO)
	
}

public Remove_DartPistol(id)
{
	UnSet_BitVar(g_Had_DartPistol, id)
}

public Event_CurWeapon(id)
{
	static CSW; CSW = read_data(2)
	if(CSW != CSW_DEAGLE)
		return
	if(!Get_BitVar(g_Had_DartPistol, id))	
		return

	static Float:Delay, Float:Delay2
	static Ent; Ent = fm_get_user_weapon_entity(id, CSW_DEAGLE)
	if(!pev_valid(Ent)) return
	
	Delay = get_pdata_float(Ent, 46, 4) * TIME_SHOOT
	Delay2 = get_pdata_float(Ent, 47, 4) * TIME_SHOOT
	
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
	if(get_user_weapon(id) == CSW_DEAGLE && Get_BitVar(g_Had_DartPistol, id))
		set_cd(cd_handle, CD_flNextAttack, get_gametime() + 0.001) 
	
	return FMRES_HANDLED
}

public fw_PlaybackEvent(flags, invoker, eventid, Float:delay, Float:origin[3], Float:angles[3], Float:fparam1, Float:fparam2, iParam1, iParam2, bParam1, bParam2)
{
	if (!is_connected(invoker))
		return FMRES_IGNORED	
	if(get_player_weapon(invoker) != CSW_DEAGLE || !Get_BitVar(g_Had_DartPistol, invoker))
		return FMRES_IGNORED
	if(eventid != g_Event_DartPistol)
		return FMRES_IGNORED
	
	engfunc(EngFunc_PlaybackEvent, flags | FEV_HOSTONLY, invoker, eventid, delay, origin, angles, fparam1, fparam2, iParam1, iParam2, bParam1, bParam2)

	Set_WeaponAnim(invoker, ANIME_SHOOT)
	emit_sound(invoker, CHAN_WEAPON, WeaponSounds[0], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	
	Create_Dart(invoker)
	
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
	
	if(equal(model, DARTPISTOL_OLDMODEL))
	{
		static weapon; weapon = find_ent_by_owner(-1, "weapon_deagle", entity)
		
		if(!pev_valid(weapon))
			return FMRES_IGNORED;
		
		if(Get_BitVar(g_Had_DartPistol, iOwner))
		{
			set_pev(weapon, pev_impulse, 1372015)
			engfunc(EngFunc_SetModel, entity, MODEL_W)
		
			Remove_DartPistol(iOwner)
			
			return FMRES_SUPERCEDE
		}
	}

	return FMRES_IGNORED;
}

public fw_CmdStart(id, uc_handle, seed)
{
	if(!is_alive(id))
		return FMRES_IGNORED
	if(get_user_weapon(id) != CSW_DEAGLE || !Get_BitVar(g_Had_DartPistol, id))
		return FMRES_IGNORED
		
	
	
	return FMRES_HANDLED
}


public fw_Item_Deploy_Post(Ent)
{
	if(pev_valid(Ent) != 2)
		return
	static Id; Id = get_pdata_cbase(Ent, 41, 4)
	if(get_pdata_cbase(Id, 373) != Ent)
		return
	if(!Get_BitVar(g_Had_DartPistol, Id))
		return
	
	set_pev(Id, pev_viewmodel2, MODEL_V)
	set_pev(Id, pev_weaponmodel2, MODEL_P)
	
	Set_WeaponAnim(Id, ANIME_DRAW)
}

public fw_Item_AddToPlayer_Post(Ent, id)
{
	if(!pev_valid(Ent))
		return HAM_IGNORED
		
	if(pev(Ent, pev_impulse) == 1372015)
	{
		Set_BitVar(g_Had_DartPistol, id)
		set_pev(Ent, pev_impulse, 0)
	}
	
	return HAM_HANDLED	
}

public fw_Item_PostFrame(ent)
{
	static id; id = pev(ent, pev_owner)
	if(!is_user_alive(id))
		return HAM_IGNORED
	if(!Get_BitVar(g_Had_DartPistol, id))
		return HAM_IGNORED	
	
	static Float:flNextAttack; flNextAttack = get_pdata_float(id, 83, 5)
	static bpammo; bpammo = cs_get_user_bpammo(id, CSW_DEAGLE)
	
	static iClip; iClip = get_pdata_int(ent, 51, 4)
	static fInReload; fInReload = get_pdata_int(ent, 54, 4)
	
	if(fInReload && flNextAttack <= 0.0)
	{
		static temp1
		temp1 = min(CLIP - iClip, bpammo)

		set_pdata_int(ent, 51, iClip + temp1, 4)
		cs_set_user_bpammo(id, CSW_DEAGLE, bpammo - temp1)		
		
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
	if(!Get_BitVar(g_Had_DartPistol, id))
		return HAM_IGNORED	

	g_Clip[id] = -1
		
	static BPAmmo; BPAmmo = cs_get_user_bpammo(id, CSW_DEAGLE)
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
	if(!is_user_alive(id))
		return HAM_IGNORED
	if(!Get_BitVar(g_Had_DartPistol, id))
		return HAM_IGNORED	
	
	if((get_pdata_int(ent, 54, 4) == 1))
	{ // Reload
		if(g_Clip[id] == -1)
			return HAM_IGNORED
		
		set_pdata_int(ent, 51, g_Clip[id], 4)
		Set_WeaponAnim(id, ANIME_RELOAD)
		
		Set_PlayerNextAttack(id, TIME_RELOAD)
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
	if(!Get_BitVar(g_Had_DartPistol, Id))
		return
		
	//if(get_pdata_float(iEnt, 48, 4) <= 0.25)
	//{
		//Set_WeaponAnim(Id, g_Ammo[Id] > 0 ? ANIME_IDLE : ANIME_IDLE_EMPTY)
		//set_pdata_float(iEnt, 48, 20.0, 4)
	//}	
}


public fw_TraceAttack_World(Victim, Attacker, Float:Damage, Float:Direction[3], Ptr, DamageBits)
{
	if(!is_connected(Attacker))
		return HAM_IGNORED	
	if(get_player_weapon(Attacker) != CSW_DEAGLE || !Get_BitVar(g_Had_DartPistol, Attacker))
		return HAM_IGNORED
		
	set_tr2(Ptr, TR_vecEndPos, {4960.0, 4960.0, 4960.0})
	
	return HAM_SUPERCEDE
}

public fw_TraceAttack_Player(Victim, Attacker, Float:Damage, Float:Direction[3], Ptr, DamageBits)
{
	if(!is_connected(Attacker))
		return HAM_IGNORED	
	if(get_player_weapon(Attacker) != CSW_DEAGLE || !Get_BitVar(g_Had_DartPistol, Attacker))
		return HAM_IGNORED

	set_tr2(Ptr, TR_vecEndPos, {4960.0, 4960.0, 4960.0})
	
	return HAM_SUPERCEDE
}

public Create_Dart(id)
{
	static Ent; Ent = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"))
	if(!pev_valid(Ent)) return
	
	static Float:Origin[3], Float:Target[3], Float:Angles[3], Float:Velocity[3]
	
	Get_Position(id, 12.0, 6.0, -3.0, Origin)
	Get_Position(id, 1024.0, 0.0, 0.0, Target)
	
	pev(id, pev_v_angle, Angles); 
	
	//Angles[0] *= -1.0
	Angles[1] += 180.0
	
	// Set info for ent
	set_pev(Ent, pev_movetype, MOVETYPE_FLY)
	
	set_pev(Ent, pev_classname, DART_CLASSNAME)
	engfunc(EngFunc_SetModel, Ent, MODEL_S)
	
	set_pev(Ent, pev_mins, Float:{-1.0, -1.0, -1.0})
	set_pev(Ent, pev_maxs, Float:{1.0, 1.0, 1.0})
	
	set_pev(Ent, pev_origin, Origin)
	set_pev(Ent, pev_angles, Angles)
	set_pev(Ent, pev_gravity, 0.01)
	
	set_pev(Ent, pev_solid, SOLID_TRIGGER)
	
	set_pev(Ent, pev_user, id)
	set_pev(Ent, pev_touched, 0)
	set_pev(Ent, pev_time, 0.0)
	set_pev(Ent, pev_time2, get_gametime() + 15.0)
	set_pev(Ent, pev_hitgroup, -1)
	
	set_pev(Ent, pev_nextthink, get_gametime() + 0.05)
	
	get_speed_vector(Origin, Target, float(DART_SPEED), Velocity)
	set_pev(Ent, pev_velocity, Velocity)
	
	// Create Beam
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_BEAMFOLLOW)
	write_short(Ent)
	write_short(g_SprId_LaserBeam)
	write_byte(5)
	write_byte(1)
	write_byte(0)
	write_byte(127)
	write_byte(255)
	write_byte(150)
	message_end()
}

public fw_SpearThink(Ent)
{
	if(!pev_valid(Ent))
		return
	if(pev(Ent, pev_flags) == FL_KILLME)
		return
		
	static Victim; Victim = pev(Ent, pev_attached)
	static Owner; Owner = pev(Ent, pev_user)
	if(is_alive(Victim))
	{
		static Float:Origin[3]; pev(Victim, pev_origin, Origin)
		engfunc(EngFunc_SetOrigin, Ent, Origin)
	} else {
		
	}
	
	if(is_connected(Owner) && pev(Ent, pev_touched))
	{
		static Float:Time; pev(Ent, pev_fuser4, Time)
		if(get_gametime() - DART_SHOCKTIME > Time)
		{
			static Float:Origin[3]; pev(Ent, pev_origin, Origin)
			
			message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
			write_byte(TE_EXPLOSION)
			engfunc(EngFunc_WriteCoord, Origin[0])
			engfunc(EngFunc_WriteCoord, Origin[1])
			engfunc(EngFunc_WriteCoord, Origin[2])
			write_short(g_SprID)
			write_byte(6)
			write_byte(15)
			write_byte(TE_EXPLFLAG_NODLIGHTS | TE_EXPLFLAG_NOPARTICLES | TE_EXPLFLAG_NOSOUND)
			message_end()
			
			emit_sound(Ent, CHAN_BODY, WeaponSounds[random_num(2, 3)], VOL_NORM, ATTN_NONE, 0, PITCH_NORM)
			
			Check_Damage(Ent, Owner, Origin, Owner)
			
			Time = get_gametime()
			set_pev(Ent, pev_fuser4, Time)
		}
	}
	
	if(pev(Ent, pev_touched) && pev(Ent, pev_time) <= get_gametime())
		set_pev(Ent, pev_flags, FL_KILLME)
	
	if(pev(Ent, pev_time2) <= get_gametime())
		set_pev(Ent, pev_flags, FL_KILLME)
	
	set_pev(Ent, pev_nextthink, get_gametime() + 0.05)
}

public Check_Damage(Ent, id, Float:Origin[3], Except)
{
	for(new i = 0; i < g_MaxPlayers; i++)
	{
		if(!is_alive(i))
			continue
		if(entity_range(Ent, i) > DART_SHOCKRADIUS)
			continue
		if(Except == i)
			continue
			
		if(id != i) ExecuteHamB(Ham_TakeDamage, i, 0, id, float(DAMAGE), DMG_BURN)
	}
}

public fw_SpearTouch(Ent, Touched)
{
	if(!pev_valid(Ent))
		return
	
	static id; id = pev(Ent, pev_user)
	if(!is_user_connected(id))
	{
		remove_entity(Ent)
		return
	}
	if(pev(Ent, pev_touched))
		return
	
	if(is_user_alive(Touched))
	{
		if(id == Touched)
			return
		if(!get_pcvar_num(g_CvarFriendlyFire))
		{
			if(cs_get_user_team(id) == cs_get_user_team(Touched))
				return
		}
		
		// Check hitgroup
		static Float:HeadOrigin[3], Float:HeadAngles[3];
		engfunc(EngFunc_GetBonePosition, Touched, 8, HeadOrigin, HeadAngles);
			
		static Float:EntOrigin[3]
		pev(Ent, pev_origin, EntOrigin)

		if(get_distance_f(EntOrigin, HeadOrigin) <= 10.0) set_pev(Ent, pev_hitgroup, HIT_HEAD)
		else set_pev(Ent, pev_hitgroup, HIT_CHEST)
		
		// Handle
		set_pev(Ent, pev_movetype, MOVETYPE_FOLLOW)
		
		set_pev(Ent, pev_touched, 1)
		set_pev(Ent, pev_time, get_gametime() + DART_LIVETIME)
		set_pev(Ent, pev_attached, Touched)
	} else {
		set_pev(Ent, pev_movetype, MOVETYPE_NONE)
		
		set_pev(Ent, pev_touched, 1)
		set_pev(Ent, pev_time, get_gametime() + DART_LIVETIME)
	}
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


stock Get_Position(id,Float:forw, Float:right, Float:up, Float:vStart[])
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
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang1042\\ f0\\ fs16 \n\\ par }
*/
