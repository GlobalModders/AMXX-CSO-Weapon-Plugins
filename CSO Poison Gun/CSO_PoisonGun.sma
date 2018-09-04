#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <cstrike>
#include <fun>

#define PLUGIN "[CSO] Poison Gun"
#define VERSION "2015"
#define AUTHOR "Dias Pendragon Leon"

#define CSW_POISONGUN CSW_M249
#define weapon_poisongun "weapon_m249"

#define DAMAGE 38
#define FIRE_SPEED 960.0
#define RECOIL 0.0
#define CLIP 100
#define BPAMMO 200

#define AFTERPOISON_TIME 10.0
#define AFTERPOISON_DAMAGE 25

#define MODEL_V "models/v_poisongun.mdl"
#define MODEL_P "models/p_poisongun.mdl"
#define MODEL_W "models/w_poisongun.mdl"
#define DEFAULT_W_MODEL "models/w_m249.mdl"
#define POISON_CLASSNAME "poisonu"

new const WeaponSounds[7][] =
{
	"weapons/poisongun-1.wav",
	"weapons/poisongun-2.wav",
	"weapons/flamegun_draw.wav",
	"weapons/flamegun_clipin1.wav",
	"weapons/flamegun_clipin2.wav",
	"weapons/flamegun_clipout1.wav",
	"weapons/flamegun_clipout2.wav"
}

new const WeaponResources[5][] = 
{
	"sprites/ef_smoke_poison.spr", // Fire Effect
	"sprites/ef_smoke_poison.spr", // Burn Effect
	"sprites/weapon_poisongun.txt",
	"sprites/640hud7_2.spr",
	"sprites/640hud75_2.spr"
}

enum
{
	ANIM_IDLE = 0,
	ANIM_SHOOT,
	ANIM_SHOOT_END,
	ANIM_RELOAD,
	ANIM_DRAW
}

// Marcros
#define Get_BitVar(%1,%2)		(%1 & (1 << (%2 & 31)))
#define Set_BitVar(%1,%2)		(%1 |= (1 << (%2 & 31)));
#define UnSet_BitVar(%1,%2)		(%1 &= ~(1 << (%2 & 31)));

// Vars
new g_PoisonGun
new g_Had_PoisonGun, g_WeaponEnt, Float:g_PunchAngles[33]
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
	register_think(POISON_CLASSNAME, "fw_Fire_Think")
	register_touch(POISON_CLASSNAME, "*", "fw_Fire_Touch")
	register_think("afterpoison", "fw_FireBurn_Think")
	
	// Hams
	RegisterHam(Ham_Item_Deploy, weapon_poisongun, "fw_Item_Deploy_Post", 1)	
	RegisterHam(Ham_Item_AddToPlayer, weapon_poisongun, "fw_Item_AddToPlayer_Post", 1)
	
	RegisterHam(Ham_TraceAttack, "player", "fw_TraceAttack")
	RegisterHam(Ham_TraceAttack, "worldspawn", "fw_TraceAttack")
	RegisterHam(Ham_Weapon_PrimaryAttack, weapon_poisongun, "fw_Weapon_PrimaryAttack")
	RegisterHam(Ham_Weapon_PrimaryAttack, weapon_poisongun, "fw_Weapon_PrimaryAttack_Post", 1)
	
	g_MsgCurWeapon = get_user_msgid("CurWeapon")
	g_MsgWeaponList = get_user_msgid("WeaponList")
	
	register_clcmd("say /get", "Get_PoisonGun")
	register_clcmd("weapon_poisongun", "Hook_Weapon")
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
		if(i == 2) precache_generic(WeaponResources[i])
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

public zeli_base_register(Ent, Team)
{
	RegisterHamFromEntity(Ham_TraceAttack, Ent, "fw_TraceAttack")
}

public client_disconnect(id)
{
	Safety_Disconnected(id)
}

public Hook_Weapon(id)
{
	engclient_cmd(id, weapon_poisongun)
	return PLUGIN_HANDLED
}

// public zeli_user_spawned -> Remove_AfterPoison(id)

public zeli_weapon_selected(id, ItemID, ClassID)
{
	if(ItemID == g_PoisonGun) Get_PoisonGun(id)
}

public zeli_weapon_removed(id, ItemID)
{
	if(ItemID == g_PoisonGun) Remove_PoisonGun(id)
}

public Get_PoisonGun(id)
{
	Set_BitVar(g_Had_PoisonGun, id)
	give_item(id, weapon_poisongun)
	
	static Ent; Ent = fm_get_user_weapon_entity(id, CSW_POISONGUN)
	if(pev_valid(Ent)) cs_set_weapon_ammo(Ent, CLIP)
	
	message_begin(MSG_ONE_UNRELIABLE, g_MsgCurWeapon, _, id)
	write_byte(1)
	write_byte(CSW_POISONGUN)
	write_byte(CLIP)
	message_end()
	
	cs_set_user_bpammo(id, CSW_POISONGUN, BPAMMO)
}

public Remove_PoisonGun(id)
{
	UnSet_BitVar(g_Had_PoisonGun, id)
}

public fw_UpdateClientData_Post(id, sendweapons, cd_handle)
{
	if(!is_alive(id))
		return FMRES_IGNORED
	if(get_player_weapon(id) != CSW_POISONGUN || !Get_BitVar(g_Had_PoisonGun, id))
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
		static weapon; weapon = fm_find_ent_by_owner(-1, weapon_poisongun, entity)
		
		if(!pev_valid(weapon))
			return FMRES_IGNORED
		
		if(Get_BitVar(g_Had_PoisonGun, id))
		{
			set_pev(weapon, pev_impulse, 1562015)
			engfunc(EngFunc_SetModel, entity, MODEL_W)
			
			UnSet_BitVar(g_Had_PoisonGun, id)
			
			return FMRES_SUPERCEDE
		}
	}

	return FMRES_IGNORED
}

public fw_PlaybackEvent(flags, invoker, eventid, Float:delay, Float:origin[3], Float:angles[3], Float:fparam1, Float:fparam2, iParam1, iParam2, bParam1, bParam2)
{
	if(!is_alive(invoker))
		return FMRES_IGNORED
	if(get_player_weapon(invoker) != CSW_POISONGUN || !Get_BitVar(g_Had_PoisonGun, invoker))
		return FMRES_IGNORED	
	if(eventid == g_WeaponEnt)
	{
		playback_event(flags | FEV_HOSTONLY, invoker, eventid, delay, origin, angles, fparam1, fparam2, iParam1, iParam2, bParam1, bParam2)	
		if(pev(invoker, pev_weaponanim) != ANIM_SHOOT) Set_WeaponAnim(invoker, ANIM_SHOOT)
		
		return FMRES_SUPERCEDE
	}
	
	return FMRES_HANDLED
}

public fw_CmdStart(id, uc_handle, seed)
{
	if(!is_alive(id))
		return FMRES_IGNORED
	if(get_player_weapon(id) != CSW_POISONGUN || !Get_BitVar(g_Had_PoisonGun, id))
		return FMRES_IGNORED
		
	static PressedButton
	PressedButton = get_uc(uc_handle, UC_Buttons)
	
	if(!(PressedButton & IN_ATTACK))
	{
		if((pev(id, pev_oldbuttons) & IN_ATTACK) && pev(id, pev_weaponanim) == ANIM_SHOOT)
		{
			static weapon; weapon = fm_get_user_weapon_entity(id, CSW_POISONGUN)
			if(pev_valid(weapon)) set_pdata_float(weapon, 48, 2.0, 4)
			
			Set_WeaponAnim(id, ANIM_SHOOT_END)
			emit_sound(id, CHAN_WEAPON, WeaponSounds[1], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
		}
	}
		
	return FMRES_HANDLED
}

public fw_Item_Deploy_Post(Ent)
{
	if(pev_valid(Ent) != 2)
		return
	static Id; Id = get_pdata_cbase(Ent, 41, 4)
	if(get_pdata_cbase(Id, 373) != Ent)
		return
	if(!Get_BitVar(g_Had_PoisonGun, Id))
		return
	
	set_pev(Id, pev_viewmodel2, MODEL_V)
	set_pev(Id, pev_weaponmodel2, MODEL_P)
}

public fw_Item_AddToPlayer_Post(Ent, id)
{
	if(!pev_valid(Ent))
		return HAM_IGNORED
		
	if(pev(Ent, pev_impulse) == 1562015)
	{
		Set_BitVar(g_Had_PoisonGun, id)
		set_pev(Ent, pev_impulse, 0)
	}
	
	if(Get_BitVar(g_Had_PoisonGun, id))
	{
		message_begin(MSG_ONE_UNRELIABLE, g_MsgWeaponList, _, id)
		write_string("weapon_poisongun")
		write_byte(3)
		write_byte(200)
		write_byte(-1)
		write_byte(-1)
		write_byte(0)
		write_byte(4)
		write_byte(CSW_POISONGUN)
		write_byte(0)
		message_end()	
	}
	
	return HAM_HANDLED	
}

public fw_TraceAttack(Ent, Attacker, Float:Damage, Float:Dir[3], ptr, DamageType)
{
	if(!is_alive(Attacker))
		return HAM_IGNORED
	if(get_player_weapon(Attacker) != CSW_POISONGUN || !Get_BitVar(g_Had_PoisonGun, Attacker))
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
	
	entity_set_string(iEnt, EV_SZ_classname, POISON_CLASSNAME)
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
		fFrame += 1.5
		fScale += 0.1
		fScale = floatmin(fScale, 1.75)

		if(fFrame > 38.0)
		{
			engfunc(EngFunc_RemoveEntity, iEnt)
			return
		}
		
		set_pev(iEnt, pev_nextthink, get_gametime() + 0.025)
	} else {
		fFrame += 1.75
		fFrame = floatmin(38.0, fFrame)
		fScale += 0.15
		fScale = floatmin(fScale, 1.75)
		
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
		
		if(equal(Classname, POISON_CLASSNAME)) return
		else if(is_alive(id)) 
		{
			static EntTeam; EntTeam = pev(ent, pev_iuser2)
			if(get_user_team(id) != EntTeam)
			{
				static Attacker; Attacker = pev(ent, pev_owner)
				if(is_connected(Attacker))
				{
					ExecuteHamB(Ham_TakeDamage, id, 0, Attacker, float(DAMAGE), DMG_BULLET)
					if(is_alive(id)) Make_AfterPoison(id, Attacker, AFTERPOISON_TIME, AFTERPOISON_DAMAGE)
				}
			}
		}
	}
		
	set_pev(ent, pev_movetype, MOVETYPE_NONE)
	set_pev(ent, pev_solid, SOLID_NOT)
}

public Make_AfterPoison(id, attacker, Float:Time, Damage)
{
	static Ent; Ent = fm_find_ent_by_owner(-1, "afterpoison", id)
	if(!pev_valid(Ent))
	{
		new iEnt = create_entity("env_sprite")
		static Float:MyOrigin[3]
		
		pev(id, pev_origin, MyOrigin)
		
		// set info for ent
		set_pev(iEnt, pev_movetype, MOVETYPE_FLY)
		set_pev(iEnt, pev_rendermode, kRenderTransAdd)
		set_pev(iEnt, pev_renderamt, 250.0)
		set_pev(iEnt, pev_scale, 0.375)
		set_pev(iEnt, pev_fuser1, get_gametime() + Time)	// time remove
		set_pev(iEnt, pev_iuser1, Damage)
		
		entity_set_string(iEnt, EV_SZ_classname, "afterpoison")
		engfunc(EngFunc_SetModel, iEnt, WeaponResources[1])
		set_pev(iEnt, pev_origin, MyOrigin)
		set_pev(iEnt, pev_owner, id)
		set_pev(iEnt, pev_aiment, id)
		set_pev(iEnt, pev_frame, 0.0)
		set_pev(iEnt, pev_iuser4, attacker)
		
		set_pev(iEnt, pev_nextthink, get_gametime() + 0.05)
	} else {
		set_pev(Ent, pev_fuser1, get_gametime() + Time)	// time remove
		set_pev(Ent, pev_iuser1, Damage)
		
		set_pev(Ent, pev_nextthink, get_gametime() + 0.05)
	}
}

public Remove_AfterPoison(id)
{
	static Ent; Ent = fm_find_ent_by_owner(-1, "afterpoison", id)
	if(pev_valid(Ent) == 2) 
	{
		set_pev(Ent, pev_nextthink, get_gametime() + 0.05)
		set_pev(Ent, pev_flags, FL_KILLME)
	}
}

public fw_FireBurn_Think(iEnt)
{
	if(!pev_valid(iEnt)) 
		return
	
	static Float:fFrame
	pev(iEnt, pev_frame, fFrame)

	// effect exp
	fFrame += 1.0
	if(fFrame > 7.0) fFrame = 0.0

	set_pev(iEnt, pev_frame, fFrame)
	set_pev(iEnt, pev_nextthink, get_gametime() + 0.05)
	
	static id; id = pev(iEnt, pev_owner)
	static attacker; attacker = pev(iEnt, pev_iuser4)
	if(!is_alive(id))
	{
		engfunc(EngFunc_RemoveEntity, iEnt)
		return;
	}
	if(!is_connected(attacker))
	{
		engfunc(EngFunc_RemoveEntity, iEnt)
		return;
	}
	
	if(get_gametime() - 2.0 > pev(iEnt, pev_fuser2))
	{
		ExecuteHamB(Ham_TakeDamage, id, 0, attacker, 0.0, DMG_BURN)
		if((get_user_health(id) - pev(iEnt, pev_iuser1)) > 0) set_user_health(id, get_user_health(id) - pev(iEnt, pev_iuser1))
		else ExecuteHamB(Ham_TakeDamage, id, 0, attacker, pev(iEnt, pev_iuser1) * 10.0, DMG_BURN)
		set_pev(iEnt, pev_fuser2, get_gametime())
	}
	
	// time remove
	static Float:fTimeRemove
	pev(iEnt, pev_fuser1, fTimeRemove)
	if (get_gametime() >= fTimeRemove)
	{
		engfunc(EngFunc_RemoveEntity, iEnt)
		return;
	}
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

	if(get_player_weapon(id) == CSW_POISONGUN && Get_BitVar(g_Had_PoisonGun, id) && cs_get_weapon_ammo(ent) > 0)
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
