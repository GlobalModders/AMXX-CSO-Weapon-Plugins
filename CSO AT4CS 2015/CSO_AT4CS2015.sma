#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <cstrike>
#include <fun>

#define PLUGIN "[CSO] AT4CS"
#define VERSION "2015"
#define AUTHOR "Dias Pendragon Leon"

#define RECOIL 1.5
#define DAMAGE 350

#define CSW_AT4CS CSW_M249
#define weapon_at4cs "weapon_m249"

#define MODEL_V "models/v_at4ex.mdl"
#define MODEL_P "models/p_at4ex.mdl"
#define MODEL_W "models/w_at4ex.mdl"
#define MODEL_S "models/s_rocket.mdl"
#define DEFAULT_W_MODEL "models/w_m249.mdl"

#define WEAPON_ANIMEXT "grenade"

new const WeaponSounds[5][] =
{
	"weapons/at4-1.wav",
	"weapons/at4_draw.wav",
	"weapons/at4_clipin1.wav",
	"weapons/at4_clipin2.wav",
	"weapons/at4_clipin3.wav"
}

new const WeaponResources[3][] = 
{
	"sprites/weapon_at4cs.txt",
	"sprites/at4cs.spr",
	"sprites/smokepuff.spr"
}

enum
{
	ANIM_IDLE = 0,
	ANIM_SHOOT1,
	ANIM_SHOOT2,
	ANIM_RELOAD,
	ANIM_DRAW
}

// Marcros
#define Get_BitVar(%1,%2)		(%1 & (1 << (%2 & 31)))
#define Set_BitVar(%1,%2)		(%1 |= (1 << (%2 & 31)));
#define UnSet_BitVar(%1,%2)		(%1 &= ~(1 << (%2 & 31)));

// Vars
new g_Had_AT4CS, g_WeaponEnt, g_SmokePuff_SprID, Float:g_PunchAngles[33], g_Clip[33], Float:DelayTime[33]
new g_MsgWeaponList, g_MsgCurWeapon, g_Exp_SprId, g_SmokeSprId, g_MaxPlayers, g_Aiming

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
	register_think("at4ex_rocket", "fw_Rocket_Think")
	register_touch("at4ex_rocket", "*", "fw_Rocket_Touch")
	
	// Hams
	RegisterHam(Ham_Item_Deploy, weapon_at4cs, "fw_Item_Deploy_Post", 1)	
	RegisterHam(Ham_Item_AddToPlayer, weapon_at4cs, "fw_Item_AddToPlayer_Post", 1)
	RegisterHam(Ham_Weapon_Reload, weapon_at4cs, "fw_Weapon_Reload")
	RegisterHam(Ham_Weapon_Reload, weapon_at4cs, "fw_Weapon_Reload_Post", 1)
	RegisterHam(Ham_Item_PostFrame, weapon_at4cs, "fw_Item_PostFrame")
	
	RegisterHam(Ham_TraceAttack, "player", "fw_TraceAttack")
	RegisterHam(Ham_TraceAttack, "worldspawn", "fw_TraceAttack")
	RegisterHam(Ham_Weapon_PrimaryAttack, weapon_at4cs, "fw_Weapon_PrimaryAttack")
	RegisterHam(Ham_Weapon_PrimaryAttack, weapon_at4cs, "fw_Weapon_PrimaryAttack_Post", 1)
	
	g_MsgCurWeapon = get_user_msgid("CurWeapon")
	g_MsgWeaponList = get_user_msgid("WeaponList")
	g_MaxPlayers = get_maxplayers()
	
	register_clcmd("say /get", "Get_AT4CS")
	register_clcmd("weapon_at4cs", "Hook_Weapon")
}

public plugin_precache()
{
	precache_model(MODEL_V)
	precache_model(MODEL_P)
	precache_model(MODEL_W)
	precache_model(MODEL_S)
	
	for(new i = 0; i < sizeof(WeaponSounds); i++)
		precache_sound(WeaponSounds[i])
	for(new i = 0; i < sizeof(WeaponResources); i++)
	{
		if(i == 0) precache_generic(WeaponResources[i])
		else if(i == 2) g_SmokePuff_SprID = precache_model(WeaponResources[i])
		else precache_model(WeaponResources[i])
	}
	
	g_Exp_SprId = engfunc(EngFunc_PrecacheModel,"sprites/zerogxplode.spr")
	g_SmokeSprId = engfunc(EngFunc_PrecacheModel, "sprites/steam1.spr")
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
	engclient_cmd(id, weapon_at4cs)
	return PLUGIN_HANDLED
}

public Get_AT4CS(id)
{
	UnSet_BitVar(g_Aiming, id)
	Set_BitVar(g_Had_AT4CS, id)
	give_item(id, weapon_at4cs)
	
	static Ent; Ent = fm_get_user_weapon_entity(id, CSW_AT4CS)
	if(pev_valid(Ent)) cs_set_weapon_ammo(Ent, 1)
	
	message_begin(MSG_ONE_UNRELIABLE, g_MsgCurWeapon, _, id)
	write_byte(1)
	write_byte(CSW_AT4CS)
	write_byte(1)
	message_end()
	
	cs_set_user_bpammo(id, CSW_AT4CS, 10)
	
	set_pev(id, pev_maxspeed, 350.0)
}

public Remove_AT4CS(id)
{
	UnSet_BitVar(g_Had_AT4CS, id)
}

public fw_UpdateClientData_Post(id, sendweapons, cd_handle)
{
	if(!is_alive(id))
		return FMRES_IGNORED
	if(get_player_weapon(id) != CSW_AT4CS || !Get_BitVar(g_Had_AT4CS, id))
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
		static weapon; weapon = fm_find_ent_by_owner(-1, weapon_at4cs, entity)
		
		if(!pev_valid(weapon))
			return FMRES_IGNORED
		
		if(Get_BitVar(g_Had_AT4CS, id))
		{
			set_pev(weapon, pev_impulse, 4420152)
			engfunc(EngFunc_SetModel, entity, MODEL_W)
			
			UnSet_BitVar(g_Had_AT4CS, id)
			
			return FMRES_SUPERCEDE
		}
	}

	return FMRES_IGNORED
}

public fw_PlaybackEvent(flags, invoker, eventid, Float:delay, Float:origin[3], Float:angles[3], Float:fparam1, Float:fparam2, iParam1, iParam2, bParam1, bParam2)
{
	if(!is_alive(invoker))
		return FMRES_IGNORED
	if(get_player_weapon(invoker) != CSW_AT4CS || !Get_BitVar(g_Had_AT4CS, invoker))
		return FMRES_IGNORED	
	if(eventid == g_WeaponEnt)
	{
		playback_event(flags | FEV_HOSTONLY, invoker, eventid, delay, origin, angles, fparam1, fparam2, iParam1, iParam2, bParam1, bParam2)	
		Set_WeaponAnim(invoker, ANIM_SHOOT1)
		emit_sound(invoker, CHAN_WEAPON, WeaponSounds[0], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
		
		Create_Rocket(invoker)
		UnSet_BitVar(g_Aiming, invoker)
		cs_set_user_zoom(invoker, CS_RESET_ZOOM, 1)
		
		return FMRES_SUPERCEDE
	}
	
	return FMRES_HANDLED
}

public fw_CmdStart(id, uc_handle, seed)
{
	if(!is_alive(id))
		return FMRES_IGNORED
	if(get_player_weapon(id) != CSW_AT4CS || !Get_BitVar(g_Had_AT4CS, id))
		return FMRES_IGNORED
	
	static PressedButton
	PressedButton = get_uc(uc_handle, UC_Buttons)
	
	if((PressedButton & IN_ATTACK2))
	{
		if(get_gametime() - 0.5 > DelayTime[id])
		{
			if(!Get_BitVar(g_Aiming, id))
			{
				cs_set_user_zoom(id, CS_SET_FIRST_ZOOM, 1)
				Set_BitVar(g_Aiming, id)
			} else {
				cs_set_user_zoom(id, CS_RESET_ZOOM, 1)
				UnSet_BitVar(g_Aiming, id)
			}
			
			DelayTime[id] = get_gametime()
		}
	}
		
	return FMRES_HANDLED
}

public Create_Rocket(id)
{
	new ent, Float:Origin[3], Float:Angles[3], Float:Velocity[3]
	
	ent = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"))
	get_position(id, 40.0, 10.0, -10.0, Origin)
	pev(id, pev_v_angle, Angles)
	
	Angles[0] *= -1.0
	
	set_pev(ent, pev_origin, Origin)
	set_pev(ent, pev_angles, Angles)
	set_pev(ent, pev_v_angle, Angles)
	set_pev(ent, pev_solid, SOLID_BBOX)
	set_pev(ent, pev_movetype, MOVETYPE_FLY)
	set_pev(ent, pev_classname, "at4ex_rocket")
	set_pev(ent, pev_owner, id)
	engfunc(EngFunc_SetModel, ent, MODEL_S)
	set_pev(ent, pev_iuser1, Get_BitVar(g_Aiming, id) ? 1 : 0)
	
	set_pev(ent, pev_mins, {-1.0, -1.0, -1.0})
	set_pev(ent, pev_maxs, {1.0, 1.0, 1.0})
	
	velocity_by_aim(id, 2000, Velocity)
	set_pev(ent, pev_velocity, Velocity)
	
	set_pev(ent, pev_nextthink, halflife_time() + 0.05)
}

public fw_Rocket_Think(Ent)
{
	if(!pev_valid(Ent)) 
		return
		
	static Owner; Owner = pev(Ent, pev_owner)
	if(is_connected(Owner) && pev(Ent, pev_iuser1))
	{
		static Victim; Victim = FindClosesEnemy(Ent)
		if(is_alive(Victim) && entity_range(Victim, Ent) <= 640.0)
		{
			static Float:Origin[3]; pev(Victim, pev_origin, Origin)
			Aim_To(Ent, Origin, 1.0, 0)
			
			static Float:Velocity[3], Float:Cur[3];
			
			pev(Ent, pev_origin, Cur)
			get_speed_vector(Cur, Origin, 2000.0, Velocity)
			set_pev(Ent, pev_velocity, Velocity)
		}
	}
		
	Make_FireSmoke(Ent)
	set_pev(Ent, pev_nextthink, halflife_time() + 0.1)
}

public fw_Rocket_Touch(Ent, Id)
{
	if(!pev_valid(Ent)) 
		return
		
	static Float:Origin[3]
	pev(Ent, pev_origin, Origin)		
		
	message_begin(MSG_BROADCAST ,SVC_TEMPENTITY)
	write_byte(TE_EXPLOSION)
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2])
	write_short(g_Exp_SprId)	// sprite index
	write_byte(30)	// scale in 0.1's
	write_byte(15)	// framerate
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
	write_byte(30)	// scale in 0.1's 
	write_byte(10)	// framerate 
	message_end()
	
	static Owner; Owner = pev(Ent, pev_owner)
	if(is_connected(Owner))
	{
		for(new i = 0; i < g_MaxPlayers; i++)
		{
			if(!is_alive(i))
				continue
			if(entity_range(i, Ent) > 200.0)
				continue
			if(get_user_team(i) == get_user_team(Owner))
				continue
				
			ExecuteHamB(Ham_TakeDamage, i, 0, Owner, float(DAMAGE), DMG_BULLET)
		}
	}
	
	set_pev(Ent, pev_flags, FL_KILLME)
}

public Make_FireSmoke(Ent)
{
	static Float:Origin[3]
	pev(Ent, pev_origin, Origin)
	
	Origin[2] -= 6.0
	
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY) 
	write_byte(TE_EXPLOSION) 
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2])
	write_short(g_SmokePuff_SprID) 
	write_byte(10)
	write_byte(10)
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
	if(!Get_BitVar(g_Had_AT4CS, Id))
		return
	
	set_pev(Id, pev_viewmodel2, MODEL_V)
	set_pev(Id, pev_weaponmodel2, MODEL_P)
	
	set_pdata_string(Id, (492) * 4, WEAPON_ANIMEXT, -1 , 20)
}

public fw_Item_AddToPlayer_Post(Ent, id)
{
	if(!pev_valid(Ent))
		return HAM_IGNORED
		
	if(pev(Ent, pev_impulse) == 4420152)
	{
		Set_BitVar(g_Had_AT4CS, id)
		set_pev(Ent, pev_impulse, 0)
	}
	
	if(Get_BitVar(g_Had_AT4CS, id))
	{
		message_begin(MSG_ONE_UNRELIABLE, g_MsgWeaponList, _, id)
		write_string("weapon_at4cs")
		write_byte(3)
		write_byte(200)
		write_byte(-1)
		write_byte(-1)
		write_byte(0)
		write_byte(4)
		write_byte(CSW_AT4CS)
		write_byte(0)
		message_end()	
	}
	
	return HAM_HANDLED	
}


public fw_Item_PostFrame(ent)
{
	if(!pev_valid(ent))
		return HAM_IGNORED
	
	static id
	id = pev(ent, pev_owner)
	
	if(is_alive(id) && Get_BitVar(g_Had_AT4CS, id))
	{	
		static Float:flNextAttack; flNextAttack = get_pdata_float(id, 83, 5)
		static bpammo; bpammo = cs_get_user_bpammo(id, CSW_AT4CS)
		static iClip; iClip = get_pdata_int(ent, 51, 4)
		static fInReload; fInReload = get_pdata_int(ent, 54, 4)
		
		if(fInReload && flNextAttack <= 0.0)
		{
			static temp1; temp1 = min(1 - iClip, bpammo)

			set_pdata_int(ent, 51, iClip + temp1, 4)
			cs_set_user_bpammo(id, CSW_AT4CS, bpammo - temp1)		
			
			set_pdata_int(ent, 54, 0, 4)
			
			fInReload = 0
		}		
	}
	
	return HAM_IGNORED	
}

public fw_Weapon_Reload(ent)
{
	static id; id = pev(ent, pev_owner)
	if(!is_user_alive(id))
		return HAM_IGNORED
	if(!Get_BitVar(g_Had_AT4CS, id))
		return HAM_IGNORED
	
	g_Clip[id] = -1
	
	static bpammo; bpammo = cs_get_user_bpammo(id, CSW_AT4CS)
	static iClip; iClip = get_pdata_int(ent, 51, 4)
	
	if(bpammo <= 0) return HAM_SUPERCEDE
	
	if(iClip >= 1) return HAM_SUPERCEDE		
		
	g_Clip[id] = iClip

	return HAM_HANDLED
}

public fw_Weapon_Reload_Post(ent)
{
	static id; id = pev(ent, pev_owner)
	if(!is_user_alive(id))
		return HAM_IGNORED
	if(!Get_BitVar(g_Had_AT4CS, id))
		return HAM_IGNORED

	if (g_Clip[id] == -1)
		return HAM_IGNORED
	
	set_pdata_int(ent, 51, g_Clip[id], 4)
	set_pdata_int(ent, 54, 1, 4)
	
	Set_WeaponAnim(id, ANIM_RELOAD)
	set_pdata_float(id, 83, 3.5, 5)

	return HAM_HANDLED
}

public fw_TraceAttack(Ent, Attacker, Float:Damage, Float:Dir[3], ptr, DamageType)
{
	if(!is_alive(Attacker))
		return HAM_IGNORED
	if(get_player_weapon(Attacker) != CSW_AT4CS || !Get_BitVar(g_Had_AT4CS, Attacker))
		return HAM_IGNORED
	
	return HAM_SUPERCEDE
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

	if(get_player_weapon(id) == CSW_AT4CS && Get_BitVar(g_Had_AT4CS, id) && cs_get_weapon_ammo(ent) > 0)
	{
		static Float:push[3]
		pev(id, pev_punchangle, push)
		xs_vec_sub(push, g_PunchAngles[id], push)
		
		xs_vec_mul_scalar(push, RECOIL, push)
		xs_vec_add(push, g_PunchAngles[id], push)
		set_pev(id, pev_punchangle, push)
	}/* else {
		static Float:push[3]
		pev(id, pev_punchangle, push)
		xs_vec_sub(push, g_PunchAngles[id], push)
		
		xs_vec_mul_scalar(push, 0.0, push)
		xs_vec_add(push, g_PunchAngles[id], push)
		set_pev(id, pev_punchangle, push)
	}*/
	
	return HAM_IGNORED	
}

stock FindClosesEnemy(entid)
{
	new Float:Dist
	new Float:maxdistance=300.0
	new indexid=0	
	for(new i=1;i<=get_maxplayers();i++){
		if(is_user_alive(i) && is_valid_ent(i) && can_see_fm(entid, i)
		&& pev(entid, pev_owner) != i && cs_get_user_team(pev(entid, pev_owner)) != cs_get_user_team(i))
		{
			Dist = entity_range(entid, i)
			if(Dist <= maxdistance)
			{
				maxdistance=Dist
				indexid=i
				
				return indexid
			}
		}	
	}	
	return 0
}

public Aim_To(iEnt, Float:vTargetOrigin[3], Float:flSpeed, Style)
{
	if(!pev_valid(iEnt))	
		return
		
	if(!Style)
	{
		static Float:Vec[3], Float:Angles[3]
		pev(iEnt, pev_origin, Vec)
		
		Vec[0] = vTargetOrigin[0] - Vec[0]
		Vec[1] = vTargetOrigin[1] - Vec[1]
		Vec[2] = vTargetOrigin[2] - Vec[2]
		engfunc(EngFunc_VecToAngles, Vec, Angles)
		Angles[0] = Angles[2] = 0.0 
		
		set_pev(iEnt, pev_v_angle, Angles)
		set_pev(iEnt, pev_angles, Angles)
	} else {
		new Float:f1, Float:f2, Float:fAngles, Float:vOrigin[3], Float:vAim[3], Float:vAngles[3];
		pev(iEnt, pev_origin, vOrigin);
		xs_vec_sub(vTargetOrigin, vOrigin, vOrigin);
		xs_vec_normalize(vOrigin, vAim);
		vector_to_angle(vAim, vAim);
		
		if (vAim[1] > 180.0) vAim[1] -= 360.0;
		if (vAim[1] < -180.0) vAim[1] += 360.0;
		
		fAngles = vAim[1];
		pev(iEnt, pev_angles, vAngles);
		
		if (vAngles[1] > fAngles)
		{
			f1 = vAngles[1] - fAngles;
			f2 = 360.0 - vAngles[1] + fAngles;
			if (f1 < f2)
			{
				vAngles[1] -= flSpeed;
				vAngles[1] = floatmax(vAngles[1], fAngles);
			}
			else
			{
				vAngles[1] += flSpeed;
				if (vAngles[1] > 180.0) vAngles[1] -= 360.0;
			}
		}
		else
		{
			f1 = fAngles - vAngles[1];
			f2 = 360.0 - fAngles + vAngles[1];
			if (f1 < f2)
			{
				vAngles[1] += flSpeed;
				vAngles[1] = floatmin(vAngles[1], fAngles);
			}
			else
			{
				vAngles[1] -= flSpeed;
				if (vAngles[1] < -180.0) vAngles[1] += 360.0;
			}		
		}
	
		set_pev(iEnt, pev_v_angle, vAngles)
		set_pev(iEnt, pev_angles, vAngles)
	}
}


stock bool:can_see_fm(entindex1, entindex2)
{
	if (!entindex1 || !entindex2)
		return false

	if (pev_valid(entindex1) && pev_valid(entindex1))
	{
		new flags = pev(entindex1, pev_flags)
		if (flags & EF_NODRAW || flags & FL_NOTARGET)
		{
			return false
		}

		new Float:lookerOrig[3]
		new Float:targetBaseOrig[3]
		new Float:targetOrig[3]
		new Float:temp[3]

		pev(entindex1, pev_origin, lookerOrig)
		pev(entindex1, pev_view_ofs, temp)
		lookerOrig[0] += temp[0]
		lookerOrig[1] += temp[1]
		lookerOrig[2] += temp[2]

		pev(entindex2, pev_origin, targetBaseOrig)
		pev(entindex2, pev_view_ofs, temp)
		targetOrig[0] = targetBaseOrig [0] + temp[0]
		targetOrig[1] = targetBaseOrig [1] + temp[1]
		targetOrig[2] = targetBaseOrig [2] + temp[2]

		engfunc(EngFunc_TraceLine, lookerOrig, targetOrig, 0, entindex1, 0) //  checks the had of seen player
		if (get_tr2(0, TraceResult:TR_InOpen) && get_tr2(0, TraceResult:TR_InWater))
		{
			return false
		} 
		else 
		{
			new Float:flFraction
			get_tr2(0, TraceResult:TR_flFraction, flFraction)
			if (flFraction == 1.0 || (get_tr2(0, TraceResult:TR_pHit) == entindex2))
			{
				return true
			}
			else
			{
				targetOrig[0] = targetBaseOrig [0]
				targetOrig[1] = targetBaseOrig [1]
				targetOrig[2] = targetBaseOrig [2]
				engfunc(EngFunc_TraceLine, lookerOrig, targetOrig, 0, entindex1, 0) //  checks the body of seen player
				get_tr2(0, TraceResult:TR_flFraction, flFraction)
				if (flFraction == 1.0 || (get_tr2(0, TraceResult:TR_pHit) == entindex2))
				{
					return true
				}
				else
				{
					targetOrig[0] = targetBaseOrig [0]
					targetOrig[1] = targetBaseOrig [1]
					targetOrig[2] = targetBaseOrig [2] - 17.0
					engfunc(EngFunc_TraceLine, lookerOrig, targetOrig, 0, entindex1, 0) //  checks the legs of seen player
					get_tr2(0, TraceResult:TR_flFraction, flFraction)
					if (flFraction == 1.0 || (get_tr2(0, TraceResult:TR_pHit) == entindex2))
					{
						return true
					}
				}
			}
		}
	}
	return false
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
