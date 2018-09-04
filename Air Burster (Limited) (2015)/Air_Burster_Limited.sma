#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <cstrike>
#include <xs>
#include <fun>

#define PLUGIN "Air Burster (Limited)"
#define VERSION "2015"
#define AUTHOR "Dias"

#define V_MODEL "models/v_airburster.mdl"
#define P_MODEL "models/p_airburster.mdl"
#define W_MODEL "models/w_airburster.mdl"

#define RADIUS 405

#define CLIP 4
#define BPAMMOX 40

#define TIME_DRAW 0.75
#define TIME_SHOOT 1.25
#define TIME_RELOAD 5.0

#define CSW_CANNON CSW_MP5NAVY
#define weapon_cannon "weapon_mp5navy"

#define WEAPON_EVENT "events/mp5n.sc"
#define WEAPON_W_MODEL "models/w_mp5.mdl"
#define WEAPON_ANIMEXT "m249"
#define WEAPON_SECRET_CODE 2086

#define CANNONFIRE_CLASSNAME "air"

// Fire Start
#define WEAPON_ATTACH_F 30.0
#define WEAPON_ATTACH_R 6.0
#define WEAPON_ATTACH_U -2.0

new const WeaponSounds[8][] =
{
	"weapons/airburster_shoot2.wav",
	"weapons/airburster_idle.wav",
	"weapons/airburster_draw.wav",
	"weapons/airburster_clipin1.wav",
	"weapons/airburster_clipin2.wav",
	"weapons/airburster_clipin3.wav",
	"weapons/airburster_clipin4.wav",
	"weapons/airburster_clipout.wav"
}

new const WeaponResources[5][] = 
{
	"sprites/ef_aircyclone.spr",
	"sprites/ef_airexplosion.spr",
	"sprites/weapon_airburster.txt",
	"sprites/640hud130_2.spr",
	"sprites/640hud14_2.spr"
}

enum
{
	CANNON_ANIM_IDLE = 0,
	CANNON_ANIM_SHOOT,
	CANNON_ANIM_SHOOT_END,
	CANNON_ANIM_RELOAD,
	CANNON_ANIM_DRAW,
	CANNON_ANIM_SHOOT2
}

// MACROS
#define Get_BitVar(%1,%2) (%1 & (1 << (%2 & 31)))
#define Set_BitVar(%1,%2) %1 |= (1 << (%2 & 31))
#define UnSet_BitVar(%1,%2) %1 &= ~(1 << (%2 & 31))

new g_Had_Cannon, g_InTempingAttack, g_Clip[33], g_CodeNumber
new g_OldWeapon[33], Float:g_LastAttack[33], Float:g_NextTime[33], g_PreAmmo[33]
new g_SmokePuff_SprId, g_MsgCurWeapon, g_MsgAmmoX, g_MsgWeaponList

// Safety
new g_HamBot
new g_IsConnected, g_IsAlive, g_PlayerWeapon[33]

public plugin_init() 
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	Register_SafetyFunc()
	register_event("CurWeapon", "Event_CurWeapon", "be", "1=1")

	register_think(CANNONFIRE_CLASSNAME, "fw_Cannon_Think")
	register_touch(CANNONFIRE_CLASSNAME, "*", "fw_Cannon_Touch")	
	
	register_forward(FM_UpdateClientData, "fw_UpdateClientData_Post", 1)
	register_forward(FM_CmdStart, "fw_CmdStart")
	register_forward(FM_SetModel, "fw_SetModel")	
	register_forward(FM_EmitSound, "fw_EmitSound")
	register_forward(FM_TraceLine, "fw_TraceLine")
	register_forward(FM_TraceHull, "fw_TraceHull")
	
	RegisterHam(Ham_Item_PostFrame, weapon_cannon, "fw_Item_PostFrame")	
	RegisterHam(Ham_Weapon_Reload, weapon_cannon, "fw_Weapon_Reload")
	RegisterHam(Ham_Weapon_Reload, weapon_cannon, "fw_Weapon_Reload_Post", 1)	
	RegisterHam(Ham_Item_AddToPlayer, weapon_cannon, "fw_Item_AddToPlayer_Post", 1)
	RegisterHam(Ham_Weapon_WeaponIdle, weapon_cannon, "fw_Weapon_WeaponIdle_Post", 1)
	
	g_MsgCurWeapon = get_user_msgid("CurWeapon")
	g_MsgAmmoX = get_user_msgid("AmmoX")
	g_MsgWeaponList = get_user_msgid("WeaponList")
	
	register_clcmd("say /get", "Get_Cannon")
	register_clcmd("weapon_airburster", "HookWeapon")
}

public plugin_precache()
{
	engfunc(EngFunc_PrecacheModel, V_MODEL)
	engfunc(EngFunc_PrecacheModel, P_MODEL)
	engfunc(EngFunc_PrecacheModel, W_MODEL)
	
	new i
	for(i = 0; i < sizeof(WeaponSounds); i++)
		engfunc(EngFunc_PrecacheSound, WeaponSounds[i])
	for(i = 0; i < sizeof(WeaponResources); i++)
	{
		if(i == 1) g_CodeNumber = precache_model(WeaponResources[i])
		else if(i == 2) engfunc(EngFunc_PrecacheGeneric, WeaponResources[i])
		else engfunc(EngFunc_PrecacheModel, WeaponResources[i])
	}
	
	g_SmokePuff_SprId = engfunc(EngFunc_PrecacheModel, "sprites/smokepuff.spr")
}

public client_putinserver(id) 
{
	Safety_Connected(id)
	if(!g_HamBot && is_user_bot(id))
	{
		g_HamBot = 1
		set_task(0.1, "Register_HamBot", id)
	}
}
public client_disconnect(id) Safety_Disconnected(id)
public Register_HamBot(id) 
{
	Register_SafetyFuncBot(id)
}

public Get_Cannon(id)
{
	Set_BitVar(g_Had_Cannon, id)
	UnSet_BitVar(g_InTempingAttack, id)
	g_NextTime[id] = 0.0
	
	give_item(id, weapon_cannon)
	
	cs_set_user_bpammo(id, CSW_CANNON, BPAMMOX)
	static Ent; Ent = fm_get_user_weapon_entity(id, CSW_CANNON)
	if(!pev_valid(Ent)) return
	
	cs_set_weapon_ammo(Ent, CLIP)
	Update_Ammo2(id, CLIP, BPAMMOX)
}

public Remove_Cannon(id)
{
	UnSet_BitVar(g_Had_Cannon, id)
	UnSet_BitVar(g_InTempingAttack, id)
}

public HookWeapon(id)
{
	engclient_cmd(id, weapon_cannon)
	return PLUGIN_HANDLED
}

public Event_CurWeapon(id)
{
	if(!is_alive(id))
		return
		
	static CSWID; CSWID = read_data(2)
	if((CSWID == CSW_CANNON && g_OldWeapon[id] != CSW_CANNON) && Get_BitVar(g_Had_Cannon, id))
	{
		set_pev(id, pev_viewmodel2, V_MODEL)
		set_pev(id, pev_weaponmodel2, P_MODEL)
		
		set_weapon_anim(id, CANNON_ANIM_DRAW)
		set_pdata_float(id, 83, TIME_DRAW, 5)
		
		remove_task(id+2092015)
		
		g_PreAmmo[id] = cs_get_user_bpammo(id, CSW_CANNON)
		set_pdata_string(id, (492) * 4, WEAPON_ANIMEXT, -1 , 20)
		//update_ammo(id, -1, g_CannonRound[id])
	} else if((CSWID == CSW_CANNON && g_OldWeapon[id] == CSW_CANNON) && Get_BitVar(g_Had_Cannon, id)) {
		//update_ammo(id, -1, g_CannonRound[id])
	} else if((CSWID != CSW_CANNON && g_OldWeapon[id] == CSW_CANNON) && Get_BitVar(g_Had_Cannon, id)) {
		//cs_set_user_bpammo(id, CSW_CANNON, g_PreAmmo[id])
	}
	
	g_OldWeapon[id] = CSWID
}

public fw_Cannon_Think(iEnt)
{
	if(!pev_valid(iEnt)) 
		return
	
	static Float:fFrame, Float:fNextThink, Float:fScale
	pev(iEnt, pev_frame, fFrame)
	pev(iEnt, pev_scale, fScale)
	
	// effect exp
	static iMoveType; iMoveType = pev(iEnt, pev_movetype)
	if (iMoveType == MOVETYPE_NONE)
	{
		fNextThink = 0.0015
		fFrame += random_float(0.25, 0.75)
		fScale += 0.01
		
		fScale = floatmin(1.5, fFrame)
		if(fFrame > 21.0)
		{
			engfunc(EngFunc_RemoveEntity, iEnt)
			return
		}
	} else {
		fNextThink = 0.045
		
		fFrame += random_float(0.5, 1.0)
		fScale += 0.001
		
		fFrame = floatmin(21.0, fFrame)
		fScale = floatmin(1.5, fFrame)
	}
	
	set_pev(iEnt, pev_frame, fFrame)
	set_pev(iEnt, pev_scale, fScale)
	set_pev(iEnt, pev_nextthink, halflife_time() + fNextThink)
	
	// time remove
	static Float:fTimeRemove
	pev(iEnt, pev_fuser1, fTimeRemove)
	if(get_gametime() >= fTimeRemove)
	{
		static Float:Amount; pev(iEnt, pev_renderamt, Amount)
		if(Amount <= 5.0)
		{
			engfunc(EngFunc_RemoveEntity, iEnt)
			return
		} else {
			Amount -= 5.0
			set_pev(iEnt, pev_renderamt, Amount)
		}
	}
}

public fw_Cannon_Touch(ent, id)
{
	if(!pev_valid(ent))
		return
		
	if(pev_valid(id))
	{
		static Classname[32]
		pev(id, pev_classname, Classname, sizeof(Classname))
		
		if(equal(Classname, CANNONFIRE_CLASSNAME)) return
	}
		
	set_pev(ent, pev_movetype, MOVETYPE_NONE)
	set_pev(ent, pev_solid, SOLID_NOT)
}

public fw_UpdateClientData_Post(id, sendweapons, cd_handle)
{
	if(!is_alive(id))
		return FMRES_IGNORED
	if(get_player_weapon(id) != CSW_CANNON || !Get_BitVar(g_Had_Cannon, id))
		return FMRES_IGNORED
	
	set_cd(cd_handle, CD_flNextAttack, get_gametime() + 0.001) 
	
	return FMRES_HANDLED
}

public fw_CmdStart(id, uc_handle, seed)
{
	if(!is_alive(id))
		return FMRES_IGNORED
	if(get_player_weapon(id) != CSW_CANNON || !Get_BitVar(g_Had_Cannon, id))
		return FMRES_IGNORED
	
	static CurButton
	CurButton = get_uc(uc_handle, UC_Buttons)
	
	if(CurButton & IN_ATTACK)
	{
		CurButton &= ~IN_ATTACK
		set_uc(uc_handle, UC_Buttons, CurButton)
		
		HandleShoot_Cannon(id)
	}
	
	return FMRES_HANDLED
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
	
	if(equal(model, WEAPON_W_MODEL))
	{
		static weapon
		weapon = fm_find_ent_by_owner(-1, weapon_cannon, entity)
		
		if(!pev_valid(weapon))
			return FMRES_IGNORED
		
		if(Get_BitVar(g_Had_Cannon, id))
		{
			set_pev(weapon, pev_impulse, WEAPON_SECRET_CODE)
			
			engfunc(EngFunc_SetModel, entity, W_MODEL)
			cs_set_user_bpammo(id, CSW_CANNON, g_PreAmmo[id])
			Remove_Cannon(id)
			
			return FMRES_SUPERCEDE
		}
	}

	return FMRES_IGNORED
}

public fw_EmitSound(id, channel, const sample[], Float:volume, Float:attn, flags, pitch)
{
	if(!is_alive(id))
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
	if(!is_alive(id))
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
	if(!is_alive(id))
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

public fw_Item_AddToPlayer_Post(ent, id)
{
	if(!pev_valid(ent))
		return HAM_IGNORED
		
	if(pev(ent, pev_impulse) == WEAPON_SECRET_CODE)
	{
		Remove_Cannon(id)
		Set_BitVar(g_Had_Cannon, id)
	}
	
	if(Get_BitVar(g_Had_Cannon, id))
	{
		message_begin(MSG_ONE_UNRELIABLE, g_MsgWeaponList, _, id)
		write_string("weapon_airburster")
		write_byte(10)
		write_byte(20)
		write_byte(-1)
		write_byte(-1)
		write_byte(0)
		write_byte(7)
		write_byte(CSW_CANNON)
		write_byte(0)
		message_end()
	}
	
	return HAM_HANDLED	
}


public fw_Item_PostFrame(ent)
{
	static id; id = pev(ent, pev_owner)
	if(!is_alive(id))
		return HAM_IGNORED
	if(!Get_BitVar(g_Had_Cannon, id))
		return HAM_IGNORED	
	
	static Float:flNextAttack; flNextAttack = get_pdata_float(id, 83, 5)
	static bpammo; bpammo = cs_get_user_bpammo(id, CSW_CANNON)
	
	static iClip; iClip = get_pdata_int(ent, 51, 4)
	static fInReload; fInReload = get_pdata_int(ent, 54, 4)
	
	if(fInReload && flNextAttack <= 0.0)
	{
		static temp1
		temp1 = min(CLIP - iClip, bpammo)

		set_pdata_int(ent, 51, iClip + temp1, 4)
		cs_set_user_bpammo(id, CSW_CANNON, bpammo - temp1)		
		
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
	if(!Get_BitVar(g_Had_Cannon, id))
		return HAM_IGNORED	

	g_Clip[id] = -1
		
	static BPAmmo; BPAmmo = cs_get_user_bpammo(id, CSW_CANNON)
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
	if(!Get_BitVar(g_Had_Cannon, id))
		return HAM_IGNORED	
	
	if((get_pdata_int(ent, 54, 4) == 1))
	{ // Reload
		if(g_Clip[id] == -1)
			return HAM_IGNORED
		
		set_pdata_int(ent, 51, g_Clip[id], 4)
		set_weapon_anim(id, CANNON_ANIM_RELOAD)
		
		set_player_nextattack(id, TIME_RELOAD)
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
	if(!Get_BitVar(g_Had_Cannon, Id))
		return
		
	if(get_pdata_float(iEnt, 48, 4) <= 0.25)
	{
		
	}	
}

public HandleShoot_Cannon(id)
{
	if(get_pdata_float(id, 83, 5) > 0.0)
		return
		
	static Ent; Ent = fm_get_user_weapon_entity(id, CSW_CANNON)
	if(!pev_valid(Ent)) return
		
	if(cs_get_weapon_ammo(Ent) <= 0)
		return
	if(get_gametime() - TIME_SHOOT <= g_LastAttack[id])
	{
		set_player_nextattack(id, g_LastAttack[id] - get_gametime())
		return
	}

	Create_FakeAttack(id)
	set_weapon_anim(id, CANNON_ANIM_SHOOT2)

	cs_set_weapon_ammo(Ent, cs_get_weapon_ammo(Ent) - 1)
	emit_sound(id, CHAN_WEAPON, WeaponSounds[0], 1.0, 0.4, 0, 94 + random_num(0, 15))
	
	set_task(0.5, "Make_FireSmoke", id)
	Create_CannonFire(id, 1)
	
	Make_Push(id)
	Check_RadiusDamage(id)

	set_player_nextattack(id, TIME_SHOOT)
	set_weapons_timeidle(id, CSW_CANNON, TIME_SHOOT)
	
	if(!cs_get_weapon_ammo(Ent) && cs_get_user_bpammo(id, CSW_CANNON))
	{
		remove_task(id+2092015)
		set_task(TIME_SHOOT, "Check_Reload", id+2092015)
	}
	
	g_LastAttack[id] = get_gametime()
	g_NextTime[id] = get_gametime()
}

public Check_Reload(id)
{
	id -= 2092015
	
	if(!is_alive(id))
		return 
	if(get_player_weapon(id) != CSW_CANNON || !Get_BitVar(g_Had_Cannon, id))
		return 
		
	static Ent; Ent = fm_get_user_weapon_entity(id, CSW_CANNON)
	if(!pev_valid(Ent)) return
		
	set_player_nextattack(id, 0.0)
	set_weapons_timeidle(id, CSW_CANNON, 0.0)
	ExecuteHamB(Ham_Weapon_Reload, Ent)
}

public Create_CannonFire(id, OffSet)
{
	const MAX_FIRE = 12
	static Float:StartOrigin[3], Float:TargetOrigin[MAX_FIRE][3], Float:Speed[MAX_FIRE]

	// Get Target
	get_position(id, random_float(30.0, 40.0), 0.0, WEAPON_ATTACH_U - 5.0, StartOrigin)
	
	engfunc(EngFunc_MessageBegin, MSG_PAS, SVC_TEMPENTITY, StartOrigin, 0)
	write_byte(TE_EXPLOSION)
	engfunc(EngFunc_WriteCoord, StartOrigin[0])
	engfunc(EngFunc_WriteCoord, StartOrigin[1])
	engfunc(EngFunc_WriteCoord, StartOrigin[2])
	write_short(g_CodeNumber)
	write_byte(5)
	write_byte(20)
	write_byte(TE_EXPLFLAG_NOPARTICLES | TE_EXPLFLAG_NOSOUND)
	message_end()
	
	// -- Left
	get_position(id, 100.0, random_float(-10.0, -35.0), WEAPON_ATTACH_U, TargetOrigin[0]); Speed[0] = 150.0
	get_position(id, 100.0, random_float(-10.0, -35.0), WEAPON_ATTACH_U, TargetOrigin[1]); Speed[1] = 180.0
	get_position(id, 100.0,	random_float(-10.0, -35.0), WEAPON_ATTACH_U, TargetOrigin[2]); Speed[2] = 210.0
	get_position(id, 100.0, random_float(-10.0, -30.0), WEAPON_ATTACH_U + random_float(-5.0, 5.0), TargetOrigin[3]); Speed[3] = 240.0
	get_position(id, 100.0, random_float(-10.0, -15.0), WEAPON_ATTACH_U + random_float(-5.0, 5.0), TargetOrigin[4]); Speed[4] = 300.0

	// -- Center
	get_position(id, 100.0, 0.0, WEAPON_ATTACH_U - random_float(5.0, 10.0), TargetOrigin[5]); Speed[5] = 200.0
	get_position(id, 100.0, 0.0, WEAPON_ATTACH_U + random_float(5.0, 10.0), TargetOrigin[6]); Speed[6] = 200.0
	
	// -- Right
	get_position(id, 100.0, random_float(10.0, 15.0), WEAPON_ATTACH_U + random_float(-5.0, 5.0), TargetOrigin[7]); Speed[7] = 150.0
	get_position(id, 100.0, random_float(10.0, 30.0) , WEAPON_ATTACH_U + random_float(-5.0, 5.0), TargetOrigin[8]); Speed[8] = 180.0
	get_position(id, 100.0,	random_float(10.0, 35.0), WEAPON_ATTACH_U, TargetOrigin[9]); Speed[9] = 210.0
	get_position(id, 100.0, random_float(10.0, 35.0), WEAPON_ATTACH_U, TargetOrigin[10]); Speed[10] = 240.0
	get_position(id, 100.0, random_float(10.0, 35.0), WEAPON_ATTACH_U, TargetOrigin[11]); Speed[11] = 300.0

	for(new i = 0; i < MAX_FIRE; i++)
	{
		// Get Start
		get_position(id, random_float(30.0, 40.0), 0.0, WEAPON_ATTACH_U, StartOrigin)
		Create_Fire(id, StartOrigin, TargetOrigin[i], Speed[i] * 1.0, OffSet)
	}
}

public Create_Fire(id, Float:Origin[3], Float:TargetOrigin[3], Float:Speed, Offset)
{
	static Ent; Ent = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "env_sprite"))
	if(!pev_valid(Ent)) return
	
	static Float:Velocity[3], Float:MyVel[3]
	pev(id, pev_velocity, MyVel)

	// Set info for ent
	set_pev(Ent, pev_movetype, MOVETYPE_FLY)
	set_pev(Ent, pev_rendermode, kRenderTransAdd)
	set_pev(Ent, pev_renderamt, 75.0)
	set_pev(Ent, pev_fuser1, get_gametime() + 0.75)	// time remove
	set_pev(Ent, pev_scale, random_float(0.25, 0.75))
	set_pev(Ent, pev_nextthink, halflife_time() + 0.05)
	
	entity_set_string(Ent, EV_SZ_classname, CANNONFIRE_CLASSNAME)
	engfunc(EngFunc_SetModel, Ent, WeaponResources[0])
	set_pev(Ent, pev_mins, Float:{-1.0, -1.0, -1.0})
	set_pev(Ent, pev_maxs, Float:{1.0, 1.0, 1.0})
	set_pev(Ent, pev_origin, Origin)
	set_pev(Ent, pev_gravity, 0.01)
	set_pev(Ent, pev_solid, SOLID_TRIGGER)
	set_pev(Ent, pev_frame, 0.0)
	set_pev(Ent, pev_owner, id)
	set_pev(Ent, pev_iuser4, Offset)
	
	xs_vec_mul_scalar(MyVel, 0.5, MyVel)
	get_speed_vector(Origin, TargetOrigin, Speed, Velocity)
	xs_vec_add(Velocity, MyVel, Velocity)
	
	set_pev(Ent, pev_velocity, Velocity)
}

public Make_FireSmoke(id)
{
	static Float:Origin[3]
	get_position(id, WEAPON_ATTACH_F + 8.0, WEAPON_ATTACH_R, WEAPON_ATTACH_U - 14.0, Origin)
	
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY) 
	write_byte(TE_EXPLOSION) 
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2])
	write_short(g_SmokePuff_SprId)
	write_byte(5)
	write_byte(15)
	write_byte(14)
	message_end()
}

public Check_RadiusDamage(id)
{
	static Victim; Victim = -1
	static Float:Origin[3]; pev(id, pev_origin, Origin)
	static Float:Speed
	static Float:Target[3]

	while((Victim = find_ent_in_sphere(Victim, Origin, float(RADIUS))) != 0)
	{
		if(Victim == id)
			continue
		if(!is_alive(Victim))
			continue
		pev(Victim, pev_origin, Target)
		if(!is_in_viewcone(id, Target, 1))
			continue

		if(cs_get_user_team(id) != cs_get_user_team(Victim))
		{
			Speed = float(RADIUS) - entity_range(id, Victim)
			hook_ent2(Victim, Origin, Speed, 10.0 , 2)
		}
	}
}

public Create_FakeAttack(id)
{
	static Ent; Ent = fm_get_user_weapon_entity(id, CSW_KNIFE)
	if(!pev_valid(Ent)) return
	
	Set_BitVar(g_InTempingAttack, id)
	ExecuteHamB(Ham_Weapon_PrimaryAttack, Ent)
	
	// Set Real Attack Anim
	static iAnimDesired,  szAnimation[64]

	formatex(szAnimation, charsmax(szAnimation), (pev(id, pev_flags) & FL_DUCKING) ? "crouch_shoot_%s" : "ref_shoot_%s", WEAPON_ANIMEXT)
	if((iAnimDesired = lookup_sequence(id, szAnimation)) == -1)
		iAnimDesired = 0
	
	set_pev(id, pev_sequence, iAnimDesired)
	UnSet_BitVar(g_InTempingAttack, id)
}

public Make_Push(id)
{
	static Float:VirtualVec[3]
	VirtualVec[0] = random_float(-5.0, -10.0)
	VirtualVec[1] = random_float(1.0, -1.0)
	VirtualVec[2] = 0.0	
	
	set_pev(id, pev_punchangle, VirtualVec)		
}

public Update_Ammo2(id, Ammo, BpAmmo)
{
	message_begin(MSG_ONE_UNRELIABLE, g_MsgCurWeapon, _, id)
	write_byte(1)
	write_byte(CSW_CANNON)
	write_byte(Ammo)
	message_end()
	
	message_begin(MSG_ONE_UNRELIABLE, g_MsgAmmoX, _, id)
	write_byte(10)
	write_byte(BpAmmo)
	message_end()
	
	cs_set_user_bpammo(id, CSW_CANNON, BpAmmo)
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

stock PlaySound(id, const sound[])
{
	if(equal(sound[strlen(sound)-4], ".mp3")) client_cmd(id, "mp3 play ^"sound/%s^"", sound)
	else client_cmd(id, "spk ^"%s^"", sound)
}

stock get_speed_vector(const Float:origin1[3],const Float:origin2[3],Float:speed, Float:new_velocity[3])
{
	new_velocity[0] = origin2[0] - origin1[0]
	new_velocity[1] = origin2[1] - origin1[1]
	new_velocity[2] = origin2[2] - origin1[2]
	static Float:num; num = floatsqroot(speed*speed / (new_velocity[0]*new_velocity[0] + new_velocity[1]*new_velocity[1] + new_velocity[2]*new_velocity[2]))
	new_velocity[0] *= num
	new_velocity[1] *= num
	new_velocity[2] *= num
	
	return 1;
}

stock set_weapons_timeidle(id, WeaponId ,Float:TimeIdle)
{
	static entwpn; entwpn = fm_get_user_weapon_entity(id, WeaponId)
	if(!pev_valid(entwpn)) 
		return
		
	set_pdata_float(entwpn, 46, TimeIdle, 4)
	set_pdata_float(entwpn, 47, TimeIdle, 4)
	set_pdata_float(entwpn, 48, TimeIdle + 0.5, 4)
}

stock set_player_nextattack(id, Float:nexttime)
{
	set_pdata_float(id, 83, nexttime, 5)
}

stock set_weapon_anim(id, anim)
{
	set_pev(id, pev_weaponanim, anim)
	
	message_begin(MSG_ONE_UNRELIABLE, SVC_WEAPONANIM, {0, 0, 0}, id)
	write_byte(anim)
	write_byte(pev(id, pev_body))
	message_end()
}

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

stock hook_ent2(ent, Float:VicOrigin[3], Float:speed, Float:multi, type)
{
	static Float:fl_Velocity[3]
	static Float:EntOrigin[3]
	static Float:EntVelocity[3]
	
	pev(ent, pev_velocity, EntVelocity)
	pev(ent, pev_origin, EntOrigin)
	static Float:distance_f
	distance_f = get_distance_f(EntOrigin, VicOrigin)
	
	static Float:fl_Time; fl_Time = distance_f / speed
	static Float:fl_Time2; fl_Time2 = distance_f / (speed * multi)
	
	if(type == 1)
	{
		fl_Velocity[0] = ((VicOrigin[0] - EntOrigin[0]) / fl_Time2) * 1.5
		fl_Velocity[1] = ((VicOrigin[1] - EntOrigin[1]) / fl_Time2) * 1.5
		fl_Velocity[2] = (VicOrigin[2] - EntOrigin[2]) / fl_Time		
	} else if(type == 2) {
		fl_Velocity[0] = ((EntOrigin[0] - VicOrigin[0]) / fl_Time2) * 1.5
		fl_Velocity[1] = ((EntOrigin[1] - VicOrigin[1]) / fl_Time2) * 1.5
		fl_Velocity[2] = (EntOrigin[2] - VicOrigin[2]) / fl_Time
	}

	xs_vec_add(EntVelocity, fl_Velocity, fl_Velocity)
	set_pev(ent, pev_velocity, fl_Velocity)
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

public is_connected(id)
{
	if(!(1 <= id <= 32))
		return 0
	if(!Get_BitVar(g_IsConnected, id))
		return 0

	return 1
}

public is_alive(id)
{
	if(!is_connected(id))
		return 0
	if(!Get_BitVar(g_IsAlive, id))
		return 0
		
	return 1
}

public get_player_weapon(id)
{
	if(!is_alive(id))
		return 0
	
	return g_PlayerWeapon[id]
}
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang1042\\ f0\\ fs16 \n\\ par }
*/
