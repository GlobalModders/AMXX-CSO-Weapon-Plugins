#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <cstrike>
#include <fun>

#define PLUGIN "[CSO] Thanatos-1"
#define VERSION "1.0"
#define AUTHOR "Dias no Pendragon"

#define DAMAGE 42 // 84 for zombie
#define CLIP 7
#define BPAMMO 35

#define RELOAD_TIME 2.0
#define SCYTHE_SPEED 800.0

#define V_MODEL "models/v_thanatos1.mdl"
#define P_MODEL "models/p_thanatos1.mdl"
#define W_MODEL "models/w_thanatos1.mdl"
#define S_MODEL "models/s_thanatos1.mdl"

new const WeaponSounds[16][] =
{
	"weapons/thanatos1_shoot1.wav",
	"weapons/thanatos1_shoot_b.wav",
	"weapons/thanatos1_bidle.wav",
	"weapons/thanatos1_boltpull.wav",
	"weapons/thanatos1_changea.wav",
	"weapons/thanatos1_changeb.wav",
	"weapons/thanatos1_clipin.wav",
	"weapons/thanatos1_clipout.wav",
	"weapons/thanatos1_drawb.wav",
	"weapons/thanatos1_explode.wav",
	"weapons/thanatos1_reload_b.wav",
	"weapons/thanatos1_reloadb_clipin.wav",
	"weapons/thanatos1_reloadb_clipout.wav",
	"weapons/thanatos1_shoot_empty.wav",
	"weapons/thanatos1_shoot2_empty.wav",
	"weapons/thanatos1_stone1.wav"
}

enum
{
	ANIME_IDLE_A = 0,
	ANIME_IDLE_B,
	ANIME_SHOOT_A,
	ANIME_SHOOT_B,
	ANIME_SHOOT_SPECIAL,
	ANIME_SHOOT_EMPTY_A,
	ANIME_SHOOT_EMPTY_B,
	ANIME_RELOAD_A,
	ANIME_RELOAD_B,
	ANIME_CHANGE,
	ANIME_DRAW_A,
	ANIME_DRAW_B
}

#define TASK_CHANGING 32615
#define SCYTHE_CLASSNAME "shikkoku"

#define CSW_THANATOS1 CSW_DEAGLE
#define weapon_thanatos1 "weapon_deagle"

// Fire Start
#define THANATOS1_OLDMODEL "models/w_deagle.mdl"

const PRIMARY_WEAPONS_BIT_SUM = (1<<CSW_SCOUT)|(1<<CSW_XM1014)|(1<<CSW_MAC10)|(1<<CSW_AUG)|(1<<CSW_UMP45)|(1<<CSW_SG550)|(1<<CSW_GALIL)|(1<<CSW_FAMAS)|(1<<CSW_AWP)|(1<<CSW_MP5NAVY)|(1<<CSW_M249)|(1<<CSW_M3)|(1<<CSW_M4A1)|(1<<CSW_TMP)|(1<<CSW_G3SG1)|(1<<CSW_SG552)|(1<<CSW_AK47)|(1<<CSW_P90)
const SECONDARY_WEAPONS_BIT_SUM = (1<<CSW_P228)|(1<<CSW_ELITE)|(1<<CSW_FIVESEVEN)|(1<<CSW_USP)|(1<<CSW_GLOCK18)|(1<<CSW_DEAGLE)

// MACROS
#define Get_BitVar(%1,%2) (%1 & (1 << (%2 & 31)))
#define Set_BitVar(%1,%2) %1 |= (1 << (%2 & 31))
#define UnSet_BitVar(%1,%2) %1 &= ~(1 << (%2 & 31))

new g_Had_Thanatos1, g_Thanatos1_Clip[33], g_Charged, g_Changing
new g_MsgCurWeapon, g_InTempingAttack, g_ExpSprID, g_MaxPlayers
new g_Event_Thanatos1, g_ShellId, g_SmokePuff_SprId, g_HamBot

public plugin_init() 
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	register_event("HLTV", "Event_NewRound", "a", "1=0", "2=0")
	register_think(SCYTHE_CLASSNAME, "fw_Scythe_Think")
	register_touch(SCYTHE_CLASSNAME, "*", "fw_Scythe_Touch")
	
	register_forward(FM_UpdateClientData,"fw_UpdateClientData_Post", 1)	
	register_forward(FM_PlaybackEvent, "fw_PlaybackEvent")	
	register_forward(FM_SetModel, "fw_SetModel")		
	register_forward(FM_CmdStart, "fw_CmdStart")
	register_forward(FM_EmitSound, "fw_EmitSound")
	register_forward(FM_TraceLine, "fw_TraceLine")
	register_forward(FM_TraceHull, "fw_TraceHull")	
	
	RegisterHam(Ham_Item_Deploy, weapon_thanatos1, "fw_Item_Deploy_Post", 1)	
	RegisterHam(Ham_Item_AddToPlayer, weapon_thanatos1, "fw_Item_AddToPlayer_Post", 1)
	RegisterHam(Ham_Item_PostFrame, weapon_thanatos1, "fw_Item_PostFrame")	
	RegisterHam(Ham_Weapon_Reload, weapon_thanatos1, "fw_Weapon_Reload")
	RegisterHam(Ham_Weapon_Reload, weapon_thanatos1, "fw_Weapon_Reload_Post", 1)	
	RegisterHam(Ham_Weapon_WeaponIdle, weapon_thanatos1, "fw_Weapon_WeaponIdle_Post", 1)
	RegisterHam(Ham_Weapon_PrimaryAttack, weapon_thanatos1, "fw_Weapon_PrimaryAttack_Post", 1)	
	
	RegisterHam(Ham_TraceAttack, "worldspawn", "fw_TraceAttack_World")
	RegisterHam(Ham_TraceAttack, "player", "fw_TraceAttack_Player")	
	
	g_MaxPlayers = get_maxplayers()
	g_MsgCurWeapon = get_user_msgid("CurWeapon")
	
	register_clcmd("say /get", "Get_Thanatos1", ADMIN_KICK)
}

public plugin_precache()
{
	precache_model(V_MODEL)
	precache_model(P_MODEL)
	precache_model(W_MODEL)
	precache_model(S_MODEL)
	
	for(new i = 0; i < sizeof(WeaponSounds); i++)
		precache_sound(WeaponSounds[i])
	
	g_ShellId = precache_model("models/rshell.mdl")
	g_SmokePuff_SprId = precache_model("sprites/wall_puff1.spr")
	g_ExpSprID = precache_model("sprites/thanatos1_exp.spr")
	
	register_forward(FM_PrecacheEvent, "fw_PrecacheEvent_Post", 1)
}

public fw_PrecacheEvent_Post(type, const name[])
{
	if(equal("events/deagle.sc", name)) g_Event_Thanatos1 = get_orig_retval()		
}

public client_putinserver(id)
{
	if(!g_HamBot && is_user_bot(id))
	{
		g_HamBot = 1
		set_task(0.1, "Do_Register_HamBot", id)
	}
}

public Do_Register_HamBot(id)
{
	RegisterHamFromEntity(Ham_TraceAttack, id, "fw_TraceAttack_Player")
}

public Event_NewRound() remove_entity_name(SCYTHE_CLASSNAME)

public Get_Thanatos1(id)
{
	UnSet_BitVar(g_Changing, id)
	UnSet_BitVar(g_Charged, id)
	Set_BitVar(g_Had_Thanatos1, id)
	give_item(id, weapon_thanatos1)
	
	static Ent; Ent = fm_get_user_weapon_entity(id, CSW_THANATOS1)
	if(pev_valid(Ent)) cs_set_weapon_ammo(Ent, CLIP)
	
	Update_Ammo(id, CLIP)
	cs_set_user_bpammo(id, CSW_THANATOS1, BPAMMO)
}

public Remove_Thanatos1(id)
{
	UnSet_BitVar(g_Changing, id)
	UnSet_BitVar(g_Charged, id)
	UnSet_BitVar(g_Had_Thanatos1, id)
}

public Update_Ammo(id, Ammo)
{
	if(!is_user_alive(id))
		return
	
	engfunc(EngFunc_MessageBegin, MSG_ONE_UNRELIABLE, g_MsgCurWeapon, {0, 0, 0}, id)
	write_byte(1)
	write_byte(CSW_THANATOS1)
	write_byte(Ammo)
	message_end()
}

public fw_UpdateClientData_Post(id, sendweapons, cd_handle)
{
	if(!is_user_alive(id))
		return FMRES_IGNORED	
	if(get_user_weapon(id) == CSW_THANATOS1 && Get_BitVar(g_Had_Thanatos1, id))
		set_cd(cd_handle, CD_flNextAttack, get_gametime() + 0.001) 
	
	return FMRES_HANDLED
}

public fw_PlaybackEvent(flags, invoker, eventid, Float:delay, Float:origin[3], Float:angles[3], Float:fparam1, Float:fparam2, iParam1, iParam2, bParam1, bParam2)
{
	if (!is_user_connected(invoker))
		return FMRES_IGNORED	
	if(get_user_weapon(invoker) != CSW_THANATOS1 || !Get_BitVar(g_Had_Thanatos1, invoker))
		return FMRES_IGNORED
	if(eventid != g_Event_Thanatos1)
		return FMRES_IGNORED
	
	engfunc(EngFunc_PlaybackEvent, flags | FEV_HOSTONLY, invoker, eventid, delay, origin, angles, fparam1, fparam2, iParam1, iParam2, bParam1, bParam2)
	
	if(!Get_BitVar(g_Charged, invoker)) Set_WeaponAnim(invoker, ANIME_SHOOT_A)
	else Set_WeaponAnim(invoker, ANIME_SHOOT_B)
	
	emit_sound(invoker, CHAN_WEAPON, WeaponSounds[0], 1.0, 0.4, 0, 94 + random_num(0, 15))
	Eject_Shell(invoker, g_ShellId, 0.01)
	
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
	
	if(equal(model, THANATOS1_OLDMODEL))
	{
		static weapon; weapon = find_ent_by_owner(-1, weapon_thanatos1, entity)
		
		if(!pev_valid(weapon))
			return FMRES_IGNORED;
		
		if(Get_BitVar(g_Had_Thanatos1, iOwner))
		{
			set_pev(weapon, pev_impulse, 25112015)
			set_pev(weapon, pev_iuser4, Get_BitVar(g_Charged, iOwner) ? 1 : 0)
			
			engfunc(EngFunc_SetModel, entity, W_MODEL)
			Remove_Thanatos1(iOwner)
			
			return FMRES_SUPERCEDE
		}
	}

	return FMRES_IGNORED;
}

public fw_CmdStart(id, uc_handle, seed)
{
	if(!is_user_alive(id))
		return FMRES_IGNORED
	if(get_user_weapon(id) != CSW_THANATOS1 || !Get_BitVar(g_Had_Thanatos1, id))
		return FMRES_IGNORED
		
	static PressedButton
	PressedButton = get_uc(uc_handle, UC_Buttons)
	
	if(PressedButton & IN_ATTACK2)
	{
		if(get_pdata_float(id, 83, 5) > 0.0)
			return FMRES_IGNORED
		
		PressedButton &= ~IN_ATTACK2
		set_uc(uc_handle, UC_Buttons, PressedButton)
		
		if(Get_BitVar(g_Changing, id))
			return FMRES_IGNORED
		
		if(!Get_BitVar(g_Charged, id))
		{
			Set_BitVar(g_Changing, id)
			
			Set_Player_NextAttack(id, 2.0)
			Set_WeaponIdleTime(id, CSW_THANATOS1, 2.0)
			
			Set_WeaponAnim(id, ANIME_CHANGE)
			
			remove_task(id+TASK_CHANGING)
			set_task(1.85, "Complete_Change", id+TASK_CHANGING)
		} else {
			UnSet_BitVar(g_Changing, id)
			UnSet_BitVar(g_Charged, id)
			
			Create_FakeAttackAnim(id)
			
			Set_Player_NextAttack(id, 2.0)
			Set_WeaponIdleTime(id, CSW_THANATOS1, 2.0)
			
			Set_WeaponAnim(id, ANIME_SHOOT_SPECIAL)
			emit_sound(id, CHAN_WEAPON, WeaponSounds[1], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
			
			Create_Scythe(id)
			
			// Fake Punch
			static Float:Origin[3]; Origin[0] = -2.5
			set_pev(id, pev_punchangle, Origin)
		}
	}
		
	return FMRES_HANDLED
}

public Complete_Change(id)
{
	id -= TASK_CHANGING
	
	if(!is_user_alive(id))
		return
	
	UnSet_BitVar(g_Changing, id)
		
	if(get_user_weapon(id) != CSW_THANATOS1 || !Get_BitVar(g_Had_Thanatos1, id))
		return
		
	Set_BitVar(g_Charged, id)
}

public Create_Scythe(id)
{
	static Float:Origin[3], Float:Target[3], Float:Velocity[3], Float:Angles[3]
	
	get_position(id, 48.0, 6.0, 0.0, Origin)
	get_position(id, 1024.0, 0.0, 0.0, Target)
	
	pev(id, pev_v_angle, Angles)
	Angles[0] *= -1.0
	
	new Ent = create_entity("info_target")
	
	// set info for ent
	set_pev(Ent, pev_movetype, MOVETYPE_FLY)
	entity_set_string(Ent, EV_SZ_classname, SCYTHE_CLASSNAME)
	engfunc(EngFunc_SetModel, Ent, S_MODEL)
	
	set_pev(Ent, pev_mins, Float:{-1.0, -1.0, -1.0})
	set_pev(Ent, pev_maxs, Float:{1.0, 1.0, 1.0})
	set_pev(Ent, pev_origin, Origin)
	set_pev(Ent, pev_gravity, 0.25)
	set_pev(Ent, pev_angles, Angles)
	set_pev(Ent, pev_solid, SOLID_TRIGGER)
	set_pev(Ent, pev_owner, id)	
	set_pev(Ent, pev_iuser1, get_user_team(id))
	set_pev(Ent, pev_fuser1, get_gametime() + 5.0)

	get_speed_vector(Origin, Target, SCYTHE_SPEED, Velocity)
	set_pev(Ent, pev_velocity, Velocity)	
	
	set_pev(Ent, pev_nextthink, get_gametime() + 0.1)
	
	// Animation
	set_pev(Ent, pev_animtime, get_gametime())
	set_pev(Ent, pev_framerate, 1.0)
	set_pev(Ent, pev_sequence, 0)
}

public fw_Scythe_Think(Ent)
{
	if(!pev_valid(Ent))
		return
		
	static Float:Time; pev(Ent, pev_fuser1, Time)
	if(Time <= get_gametime())
	{
		set_pev(Ent, pev_flags, FL_KILLME)
		set_pev(Ent, pev_nextthink, get_gametime() + 0.1)
			
		return
	}
	
	set_pev(Ent, pev_nextthink, get_gametime() + 0.25)
}

public fw_Scythe_Touch(Ent, id)
{
	if(!pev_valid(Ent))
		return
	
	if(!is_user_alive(id))
	{
		static Float:Origin[3]; pev(Ent, pev_origin, Origin)
	
		set_pev(Ent, pev_velocity, {0.0, 0.0, 0.0})
		set_pev(Ent, pev_movetype, MOVETYPE_NONE)
		set_pev(Ent, pev_solid, SOLID_NOT)
		
		// Bullet Hole
		static Owner; Owner = pev(Ent, pev_owner)
		Make_BulletHole(Owner, Origin, float(DAMAGE))
		
		// Sound
		emit_sound(Ent, CHAN_ITEM, WeaponSounds[15], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
		emit_sound(Ent, CHAN_STATIC, WeaponSounds[9], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
		
		message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
		write_byte(TE_EXPLOSION)
		engfunc(EngFunc_WriteCoord, Origin[0])
		engfunc(EngFunc_WriteCoord, Origin[1])
		engfunc(EngFunc_WriteCoord, Origin[2])
		write_short(g_ExpSprID)
		write_byte(10)
		write_byte(20)
		write_byte(4) 
		message_end()
		
		// Entity
		set_pev(Ent, pev_fuser1, get_gametime() + 3.0)
		if(!is_user_connected(Owner))
			return
		
		for(new i = 0; i < g_MaxPlayers; i++)
		{
			if(!is_user_alive(i))
				continue
			if(get_user_team(i) == get_user_team(Owner))
				continue
			if(entity_range(i, Ent) > 180.0)
				continue
				
			ExecuteHamB(Ham_TakeDamage, i, 0, Owner, float(DAMAGE) * 2.0, DMG_SLASH)
		}
	
	} else {
		static Team; Team = pev(Ent, pev_iuser1)
		if(get_user_team(id) == Team)
			return
		static Owner; Owner = pev(Ent, pev_owner)
		if(!is_user_connected(Owner))
			return
		
		ExecuteHamB(Ham_TakeDamage, id, 0, Owner, float(DAMAGE), DMG_SLASH)
	}
}

public fw_EmitSound(id, channel, const sample[], Float:volume, Float:attn, flags, pitch)
{
	if(!is_user_connected(id))
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
	if(!is_user_alive(id))
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
	if(!is_user_alive(id))
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

public Create_FakeAttackAnim(id)
{
	Set_BitVar(g_InTempingAttack, id)
	
	static Ent; Ent = fm_get_user_weapon_entity(id, CSW_KNIFE)
	if(pev_valid(Ent)) ExecuteHamB(Ham_Weapon_PrimaryAttack, Ent)
	
	UnSet_BitVar(g_InTempingAttack, id)
}

public fw_Item_Deploy_Post(Ent)
{
	if(pev_valid(Ent) != 2)
		return
	static Id; Id = get_pdata_cbase(Ent, 41, 4)
	if(get_pdata_cbase(Id, 373) != Ent)
		return
	if(!Get_BitVar(g_Had_Thanatos1, Id))
		return
	
	set_pev(Id, pev_viewmodel2, V_MODEL)
	set_pev(Id, pev_weaponmodel2, P_MODEL)
	
	if(!Get_BitVar(g_Charged, Id)) Set_WeaponAnim(Id, ANIME_DRAW_A)
	else Set_WeaponAnim(Id, ANIME_DRAW_B)
	
	remove_task(Id+TASK_CHANGING)
	
	UnSet_BitVar(g_Changing, Id)
	UnSet_BitVar(g_Charged, Id)
}

public fw_Item_AddToPlayer_Post(Ent, id)
{
	if(!pev_valid(Ent))
		return HAM_IGNORED
		
	if(pev(Ent, pev_impulse) == 25112015)
	{
		Set_BitVar(g_Had_Thanatos1, id)
		set_pev(Ent, pev_impulse, 0)
		
		if(pev(Ent, pev_iuser4)) Set_BitVar(g_Charged, id)
		else UnSet_BitVar(g_Charged, id)
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
	if(!Get_BitVar(g_Had_Thanatos1, Id))
		return
		
	if(get_pdata_float(iEnt, 48, 4) <= 0.1)
	{
		if(!Get_BitVar(g_Charged, Id)) Set_WeaponAnim(Id, ANIME_IDLE_A)
		else Set_WeaponAnim(Id, ANIME_IDLE_B)
		
		set_pdata_float(iEnt, 48, 20.0, 4)
	}	
}

public fw_TraceAttack_World(Victim, Attacker, Float:Damage, Float:Direction[3], Ptr, DamageBits)
{
	if(!is_user_connected(Attacker))
		return HAM_IGNORED	
	if(get_user_weapon(Attacker) != CSW_THANATOS1 || !Get_BitVar(g_Had_Thanatos1, Attacker))
		return HAM_IGNORED
		
	static Float:flEnd[3], Float:vecPlane[3]
		
	get_tr2(Ptr, TR_vecEndPos, flEnd)
	get_tr2(Ptr, TR_vecPlaneNormal, vecPlane)		
			
	Make_BulletHole(Attacker, flEnd, Damage)
	Make_BulletSmoke(Attacker, Ptr)

	SetHamParamFloat(3, float(DAMAGE))
	
	return HAM_IGNORED
}

public fw_TraceAttack_Player(Victim, Attacker, Float:Damage, Float:Direction[3], Ptr, DamageBits)
{
	if(!is_user_connected(Attacker))
		return HAM_IGNORED	
	if(get_user_weapon(Attacker) != CSW_THANATOS1 || !Get_BitVar(g_Had_Thanatos1, Attacker))
		return HAM_IGNORED
		
	SetHamParamFloat(3, float(DAMAGE))
	
	return HAM_IGNORED
}

public fw_Item_PostFrame(ent)
{
	static id; id = pev(ent, pev_owner)
	if(!is_user_alive(id))
		return HAM_IGNORED
	if(!Get_BitVar(g_Had_Thanatos1, id))
		return HAM_IGNORED	
	
	static Float:flNextAttack; flNextAttack = get_pdata_float(id, 83, 5)
	static bpammo; bpammo = cs_get_user_bpammo(id, CSW_THANATOS1)
	
	static iClip; iClip = get_pdata_int(ent, 51, 4)
	static fInReload; fInReload = get_pdata_int(ent, 54, 4)
	
	if(fInReload && flNextAttack <= 0.0)
	{
		static temp1
		temp1 = min(CLIP - iClip, bpammo)

		set_pdata_int(ent, 51, iClip + temp1, 4)
		cs_set_user_bpammo(id, CSW_THANATOS1, bpammo - temp1)		
		
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
	if(!Get_BitVar(g_Had_Thanatos1, id))
		return HAM_IGNORED	

	g_Thanatos1_Clip[id] = -1
		
	static BPAmmo; BPAmmo = cs_get_user_bpammo(id, CSW_THANATOS1)
	static iClip; iClip = get_pdata_int(ent, 51, 4)
		
	if(BPAmmo <= 0)
		return HAM_SUPERCEDE
	if(iClip >= CLIP)
		return HAM_SUPERCEDE		
			
	g_Thanatos1_Clip[id] = iClip	
	
	return HAM_HANDLED
}

public fw_Weapon_Reload_Post(ent)
{
	static id; id = pev(ent, pev_owner)
	if(!is_user_alive(id))
		return HAM_IGNORED
	if(!Get_BitVar(g_Had_Thanatos1, id))
		return HAM_IGNORED	
		
	if((get_pdata_int(ent, 54, 4) == 1))
	{ // Reload
		if(g_Thanatos1_Clip[id] == -1)
			return HAM_IGNORED
		
		set_pdata_int(ent, 51, g_Thanatos1_Clip[id], 4)
		set_pdata_float(id, 83, RELOAD_TIME, 5)
		
		if(!Get_BitVar(g_Charged, id)) Set_WeaponAnim(id, ANIME_RELOAD_A)
		else Set_WeaponAnim(id, ANIME_RELOAD_B)
	}
	
	return HAM_HANDLED
}

public fw_Weapon_PrimaryAttack_Post(Ent)
{
	static id; id = pev(Ent, pev_owner)
	if(!is_user_alive(id))
		return HAM_IGNORED
	if(!Get_BitVar(g_Had_Thanatos1, id))
		return HAM_IGNORED
		
	set_pdata_float(Ent, 48, 0.5, 4)
	return HAM_IGNORED
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

stock Set_Player_NextAttack(id, Float:NextTime) set_pdata_float(id, 83, NextTime, 5)

stock Set_WeaponAnim(id, anim)
{
	set_pev(id, pev_weaponanim, anim)
	
	message_begin(MSG_ONE_UNRELIABLE, SVC_WEAPONANIM, {0, 0, 0}, id)
	write_byte(anim)
	write_byte(pev(id, pev_body))
	message_end()
}

stock Eject_Shell(id, Shell_ModelIndex, Float:Time) // By Dias
{
	static Ent; Ent = get_pdata_cbase(id, 373, 5)
	if(!pev_valid(Ent))
		return

        set_pdata_int(Ent, 57, Shell_ModelIndex, 4)
        set_pdata_float(id, 111, get_gametime() + Time)
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
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang1042\\ f0\\ fs16 \n\\ par }
*/
