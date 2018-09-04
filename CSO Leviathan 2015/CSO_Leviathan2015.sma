#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <cstrike>
#include <fun>

#define PLUGIN "[CSO] Leviathan"
#define VERSION "2015"
#define AUTHOR "Dias Pendragon Leon"

#define CSW_SAL CSW_M249
#define weapon_sal "weapon_m249"

#define DAMAGE 21
#define FIRE_SPEED 480.0
#define RECOIL 0.0

#define MODEL_V "models/v_watercannon.mdl"
#define MODEL_P "models/p_watercannon.mdl"
#define MODEL_W "models/w_watercannon.mdl"
#define DEFAULT_W_MODEL "models/w_m249.mdl"

new const WeaponSounds[6][] =
{
	"weapons/watercannon_shoot1.wav",
	"weapons/watercannon_shoot_start.wav",
	"weapons/watercannon_shoot_end.wav",
	"weapons/watercannon_draw.wav",
	"weapons/watercannon_clipin.wav",
	"weapons/watercannon_clipout.wav"
}

new const WeaponResources[4][] = 
{
	"sprites/waterstream.spr",
	"sprites/weapon_watercannon.txt",
	"sprites/640hud7_2.spr",
	"sprites/640hud92_2.spr"
}

enum
{
	ANIM_IDLE = 0,
	ANIM_SHOOT_START,
	ANIM_SHOOT_LOOP,
	ANIM_SHOOT_END,
	ANIM_RELOAD,
	ANIM_DRAW
}

// Marcros
#define Get_BitVar(%1,%2)		(%1 & (1 << (%2 & 31)))
#define Set_BitVar(%1,%2)		(%1 |= (1 << (%2 & 31)));
#define UnSet_BitVar(%1,%2)		(%1 &= ~(1 << (%2 & 31)));

// Vars
new g_Had_Salamander, g_WeaponEnt, g_SmokePuff_SprID, Float:g_PunchAngles[33]
new g_MsgCurWeapon, g_MsgWeaponList

// Safety
new g_HamBot
new g_IsConnected, g_IsAlive, g_PlayerWeapon[33]

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	// Your highness!
	Register_SafetyFunc()
	
	// Forward
	register_forward(FM_UpdateClientData, "fw_UpdateClientData_Post", 1)
	register_forward(FM_SetModel, "fw_SetModel")
	register_forward(FM_PlaybackEvent, "fw_PlaybackEvent")
	register_forward(FM_CmdStart, "fw_CmdStart")
	register_forward(FM_PrecacheEvent, "fw_PrecacheEvent_Post", 1)
	
	// Engine
	register_think("fireinsaigon", "fw_Fire_Think")
	register_touch("fireinsaigon", "*", "fw_Fire_Touch")
	
	// Hams
	RegisterHam(Ham_Item_Deploy, weapon_sal, "fw_Item_Deploy_Post", 1)	
	RegisterHam(Ham_Item_AddToPlayer, weapon_sal, "fw_Item_AddToPlayer_Post", 1)
	
	RegisterHam(Ham_TraceAttack, "player", "fw_TraceAttack")
	RegisterHam(Ham_TraceAttack, "worldspawn", "fw_TraceAttack")
	RegisterHam(Ham_Weapon_PrimaryAttack, weapon_sal, "fw_Weapon_PrimaryAttack")
	RegisterHam(Ham_Weapon_PrimaryAttack, weapon_sal, "fw_Weapon_PrimaryAttack_Post", 1)
	RegisterHam(Ham_Weapon_Reload, weapon_sal, "fw_Weapon_Reload_Post", 1)
	
	g_MsgCurWeapon = get_user_msgid("CurWeapon")
	g_MsgWeaponList = get_user_msgid("WeaponList")
	
	register_clcmd("say /get", "Get_Salamander")
	register_clcmd("weapon_watercannon", "Hook_Weapon")
}

public plugin_precache()
{
	precache_model(MODEL_V)
	precache_model(MODEL_P)
	precache_model(MODEL_W)
	
	for(new i = 0; i < sizeof(WeaponSounds); i++)
		precache_sound(WeaponSounds[i])
	for(new i = 0; i < sizeof(WeaponResources); i++)
	{
		if(i == 1) precache_generic(WeaponResources[i])
		else precache_model(WeaponResources[i])
	}
}

public fw_PrecacheEvent_Post(type, const name[])
{
	if(equal("events/m249.sc", name))
		g_WeaponEnt = get_orig_retval()
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

public Register_HamBot(id) 
{
	Register_SafetyFuncBot(id)
	RegisterHamFromEntity(Ham_TraceAttack, id, "fw_TraceAttack")
}

public client_disconnect(id)
{
	Safety_Disconnected(id)
}

public Hook_Weapon(id)
{
	engclient_cmd(id, weapon_sal)
	return PLUGIN_HANDLED
}

public Get_Salamander(id)
{
	Set_BitVar(g_Had_Salamander, id)
	give_item(id, weapon_sal)
	
	message_begin(MSG_ONE_UNRELIABLE, g_MsgCurWeapon, _, id)
	write_byte(1)
	write_byte(CSW_SAL)
	write_byte(100)
	message_end()
	
	cs_set_user_bpammo(id, CSW_SAL, 200)
}

public Remove_Salamander(id)
{
	UnSet_BitVar(g_Had_Salamander, id)
}

public fw_UpdateClientData_Post(id, sendweapons, cd_handle)
{
	if(!is_alive(id))
		return FMRES_IGNORED
	if(get_player_weapon(id) != CSW_SAL || !Get_BitVar(g_Had_Salamander, id))
		return FMRES_IGNORED
	
	set_cd(cd_handle, CD_flNextAttack, get_gametime() + 0.001) 
	
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
	
	if(equal(model, DEFAULT_W_MODEL))
	{
		static weapon; weapon = fm_find_ent_by_owner(-1, weapon_sal, entity)
		
		if(!pev_valid(weapon))
			return FMRES_IGNORED
		
		if(Get_BitVar(g_Had_Salamander, id))
		{
			set_pev(weapon, pev_impulse, 4420152)
			engfunc(EngFunc_SetModel, entity, MODEL_W)
			
			UnSet_BitVar(g_Had_Salamander, id)
			
			return FMRES_SUPERCEDE
		}
	}

	return FMRES_IGNORED
}

public fw_PlaybackEvent(flags, invoker, eventid, Float:delay, Float:origin[3], Float:angles[3], Float:fparam1, Float:fparam2, iParam1, iParam2, bParam1, bParam2)
{
	if(!is_alive(invoker))
		return FMRES_IGNORED
	if(get_player_weapon(invoker) != CSW_SAL || !Get_BitVar(g_Had_Salamander, invoker))
		return FMRES_IGNORED	
	if(eventid == g_WeaponEnt)
	{
		playback_event(flags | FEV_HOSTONLY, invoker, eventid, delay, origin, angles, fparam1, fparam2, iParam1, iParam2, bParam1, bParam2)	
		
		static weapon; weapon = fm_get_user_weapon_entity(invoker, CSW_SAL)
		if(pev_valid(weapon)) 
		{
			if(get_pdata_int(weapon, 64, 4) > 1) 
			{
				if(pev(invoker, pev_weaponanim) != ANIM_SHOOT_LOOP) Set_WeaponAnim(invoker, ANIM_SHOOT_LOOP)
			} else Set_WeaponAnim(invoker, ANIM_SHOOT_START)
		}
		
		return FMRES_SUPERCEDE
	}
	
	return FMRES_HANDLED
}

public fw_CmdStart(id, uc_handle, seed)
{
	if(!is_alive(id))
		return FMRES_IGNORED
	if(get_player_weapon(id) != CSW_SAL || !Get_BitVar(g_Had_Salamander, id))
		return FMRES_IGNORED
		
	static PressedButton
	PressedButton = get_uc(uc_handle, UC_Buttons)
	
	if(!(PressedButton & IN_ATTACK))
	{
		if((pev(id, pev_oldbuttons) & IN_ATTACK) && pev(id, pev_weaponanim) == ANIM_SHOOT_LOOP)
		{
			static weapon; weapon = fm_get_user_weapon_entity(id, CSW_SAL)
			if(pev_valid(weapon)) set_pdata_float(weapon, 48, 2.0, 4)
			
			Set_WeaponAnim(id, ANIM_SHOOT_END)
			emit_sound(id, CHAN_WEAPON, WeaponSounds[2], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
			Make_FireSmoke(id)
		}
	}
		
	return FMRES_HANDLED
}

public Make_FireSmoke(id)
{
	static Float:Origin[3]
	get_position(id, 40.0, 5.0, -15.0, Origin)
	
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY) 
	write_byte(TE_EXPLOSION) 
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2])
	write_short(g_SmokePuff_SprID) 
	write_byte(5)
	write_byte(30)
	write_byte(14)
	message_end()
}

public fw_Item_Deploy_Post(Ent)
{
	if(pev_valid(Ent) != 2)
		return
	static Id; Id = get_pdata_cbase(Ent, 41, 4)
	if(get_pdata_cbase(Id, 373) != Ent)
		return
	if(!Get_BitVar(g_Had_Salamander, Id))
		return
	
	set_pev(Id, pev_viewmodel2, MODEL_V)
	set_pev(Id, pev_weaponmodel2, MODEL_P)
	
	Set_WeaponAnim(Id, ANIM_DRAW)
}

public fw_Item_AddToPlayer_Post(Ent, id)
{
	if(!pev_valid(Ent))
		return HAM_IGNORED
		
	if(pev(Ent, pev_impulse) == 4420152)
	{
		Set_BitVar(g_Had_Salamander, id)
		set_pev(Ent, pev_impulse, 0)
	}
	
	if(Get_BitVar(g_Had_Salamander, id))
	{
		message_begin(MSG_ONE_UNRELIABLE, g_MsgWeaponList, _, id)
		write_string("weapon_watercannon")
		write_byte(3)
		write_byte(200)
		write_byte(-1)
		write_byte(-1)
		write_byte(0)
		write_byte(4)
		write_byte(CSW_SAL)
		write_byte(0)
		message_end()	
	}
	
	return HAM_HANDLED	
}

public fw_TraceAttack(Ent, Attacker, Float:Damage, Float:Dir[3], ptr, DamageType)
{
	if(!is_alive(Attacker))
		return HAM_IGNORED
	if(get_player_weapon(Attacker) != CSW_SAL || !Get_BitVar(g_Had_Salamander, Attacker))
		return HAM_IGNORED
	
	return HAM_SUPERCEDE
}

public CreateFire(id, Float:Speed)
{
	new iEnt = create_entity("env_sprite")
	if(!pev_valid(iEnt)) return
	
	static Float:vfAngle[3], Float:MyOrigin[3]
	static Float:Origin[3], Float:TargetOrigin[3], Float:Velocity[3]

	get_position(id, 40.0, 5.0, -5.0, Origin)
	get_position(id, 1024.0, 0.0, 0.0, TargetOrigin)
	
	pev(id, pev_angles, vfAngle)
	pev(id, pev_origin, MyOrigin)
	
	vfAngle[2] = float(random(18) * 20)

	// set info for ent
	set_pev(iEnt, pev_movetype, MOVETYPE_FLY)
	set_pev(iEnt, pev_rendermode, kRenderTransAdd)
	set_pev(iEnt, pev_renderamt, 160.0)
	set_pev(iEnt, pev_fuser1, get_gametime() + 1.0)	// time remove
	set_pev(iEnt, pev_scale, 0.25)
	set_pev(iEnt, pev_nextthink, get_gametime() + 0.05)
	
	entity_set_string(iEnt, EV_SZ_classname, "fireinsaigon")
	engfunc(EngFunc_SetModel, iEnt, WeaponResources[0])
	set_pev(iEnt, pev_mins, Float:{-1.0, -1.0, -1.0})
	set_pev(iEnt, pev_maxs, Float:{1.0, 1.0, 1.0})
	set_pev(iEnt, pev_origin, Origin)
	set_pev(iEnt, pev_gravity, 0.01)
	set_pev(iEnt, pev_angles, vfAngle)
	set_pev(iEnt, pev_solid, SOLID_TRIGGER)
	set_pev(iEnt, pev_owner, id)	
	set_pev(iEnt, pev_frame, 0.0)
	set_pev(iEnt, pev_iuser2, get_user_team(id))

	get_speed_vector(Origin, TargetOrigin, Speed, Velocity)
	set_pev(iEnt, pev_velocity, Velocity)
	
	emit_sound(iEnt, CHAN_BODY, WeaponSounds[0], 1.0, ATTN_NORM, 0, PITCH_NORM)	
}

public fw_Fire_Think(iEnt)
{
	if(!pev_valid(iEnt)) 
		return
	
	static Float:fFrame, Float:fScale
	pev(iEnt, pev_frame, fFrame)
	pev(iEnt, pev_scale, fScale)

	// effect exp
	if(pev(iEnt, pev_movetype) == MOVETYPE_NONE)
	{
		fFrame += 1.0
		fScale += 0.1
		fScale = floatmin(fScale, 1.35)

		if(fFrame > 21.0)
		{
			engfunc(EngFunc_RemoveEntity, iEnt)
			return
		}
		
		set_pev(iEnt, pev_nextthink, get_gametime() + 0.025)
	} else {
		fFrame += 1.25
		fFrame = floatmin(21.0, fFrame)
		fScale += 0.1
		fScale = floatmin(fScale, 1.35)
		
		set_pev(iEnt, pev_nextthink, get_gametime() + 0.05)
	}

	set_pev(iEnt, pev_frame, fFrame)
	set_pev(iEnt, pev_scale, fScale)
	
	// time remove
	static Float:fTimeRemove
	pev(iEnt, pev_fuser1, fTimeRemove)
	if (get_gametime() >= fTimeRemove)
	{
		engfunc(EngFunc_RemoveEntity, iEnt)
		return;
	}
}

public fw_Fire_Touch(ent, id)
{
	if(!pev_valid(ent))
		return
		
	if(pev_valid(id))
	{
		static Classname[32]
		pev(id, pev_classname, Classname, sizeof(Classname))
		
		if(equal(Classname, "fireinsaigon")) return
		else if(is_alive(id)) 
		{
			static EntTeam; EntTeam = pev(ent, pev_iuser2)
			if(get_user_team(id) != EntTeam)
			{
				static Attacker; Attacker = pev(ent, pev_owner)
				if(is_connected(Attacker))
				{
					ExecuteHamB(Ham_TakeDamage, id, 0, Attacker, float(DAMAGE), DMG_BULLET)
				}
			}
		}
	}
		
	set_pev(ent, pev_movetype, MOVETYPE_NONE)
	set_pev(ent, pev_solid, SOLID_NOT)
}

public fw_Weapon_PrimaryAttack(ent)
{
	static id; id = pev(ent, pev_owner)
	pev(id, pev_punchangle, g_PunchAngles[id])
	
	return HAM_IGNORED	
}

public fw_Weapon_PrimaryAttack_Post(ent)
{
	static id; id = pev(ent, pev_owner)

	if(get_player_weapon(id) == CSW_SAL && Get_BitVar(g_Had_Salamander, id) && cs_get_weapon_ammo(ent) > 0)
	{
		static Float:push[3]
		pev(id, pev_punchangle, push)
		xs_vec_sub(push, g_PunchAngles[id], push)
		
		xs_vec_mul_scalar(push, RECOIL, push)
		xs_vec_add(push, g_PunchAngles[id], push)
		set_pev(id, pev_punchangle, push)
		
		CreateFire(id, FIRE_SPEED)
	} else {
		static Float:push[3]
		pev(id, pev_punchangle, push)
		xs_vec_sub(push, g_PunchAngles[id], push)
		
		xs_vec_mul_scalar(push, 0.0, push)
		xs_vec_add(push, g_PunchAngles[id], push)
		set_pev(id, pev_punchangle, push)
	}
	
	return HAM_IGNORED	
}

public fw_Weapon_Reload_Post(Ent)
{
	if(pev_valid(Ent) != 2)
		return
	static Id; Id = get_pdata_cbase(Ent, 41, 4)
	if(get_pdata_cbase(Id, 373) != Ent)
		return
	if(!Get_BitVar(g_Had_Salamander, Id))
		return
		
	Set_WeaponAnim(Id, ANIM_RELOAD)
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

stock Set_WeaponAnim(id, anim)
{
	set_pev(id, pev_weaponanim, anim)
	
	message_begin(MSG_ONE_UNRELIABLE, SVC_WEAPONANIM, {0, 0, 0}, id)
	write_byte(anim)
	write_byte(pev(id, pev_body))
	message_end()
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


// ===================== STOCK... =======================
// ======================================================
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang3076\\ f0\\ fs16 \n\\ par }
*/
