#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <cstrike>
#include <fun>

#define PLUGIN "[CSO] Thanatos-3"
#define VERSION "1.0"
#define AUTHOR "Dias no Pendragon"

#define DAMAGE 25 // 45 for zombie
#define CLIP 60
#define BPAMMO 240

#define SCYTHE_SLASHTIME 7.0

#define STAGE_AMMO 10 // every x ammo -> stage up
#define RELOAD_TIME 3.25
#define ANIME_EXT "onehanded"

#define V_MODEL "models/v_thanatos3.mdl"
#define P_MODEL "models/p_thanatos3.mdl"
#define W_MODEL "models/w_thanatos3.mdl"
#define W_MODEL2 "models/w_thanatos3b.mdl"
#define S_MODEL "models/thanatos3_knife.mdl"
#define S_MODEL2 "models/thanatos3_wind.mdl"

new const WeaponSounds[29][] =
{
	"weapons/thanatos3-1.wav",
	"weapons/thanatos3_fly_shoot.wav",
	"weapons/thanatos3_fly_w2.wav",
	"weapons/thanatos3_fly_w3.wav",
	"weapons/thanatos3_ilde_w1.wav",
	"weapons/thanatos3_ilde_w2.wav",
	"weapons/thanatos3_ilde_w3.wav",
	"weapons/thanatos3_draw.wav",
	"weapons/thanatos3_draw_w1.wav",
	"weapons/thanatos3_draw_w2.wav",
	"weapons/thanatos3_draw_w3.wav",
	"weapons/thanatos3_boltpull.wav",
	"weapons/thanatos3_clipin.wav",
	"weapons/thanatos3_clipout.wav",
	"weapons/thanatos3_knife_hit1.wav",
	"weapons/thanatos3_knife_hit2.wav",
	"weapons/thanatos3_knife_swish.wav",
	"weapons/thanatos3_metal1.wav",
	"weapons/thanatos3_metal2.wav",
	"weapons/thanatos3_reload_w1.wav",
	"weapons/thanatos3_reload_w2.wav",
	"weapons/thanatos3_reload_w3.wav",
	"weapons/thanatos3_spread_w1.wav",
	"weapons/thanatos3_spread_w2.wav",
	"weapons/thanatos3_spread_w3.wav",
	"weapons/thanatos3_stone1.wav",
	"weapons/thanatos3_stone2.wav",
	"weapons/thanatos3_wood1.wav",
	"weapons/thanatos3_wood2.wav"
}

enum
{
	ANIME_IDLE = 0,
	ANIME_IDLE_W1,
	ANIME_IDLE_W2,
	ANIME_IDLE_W3,
	ANIME_SHOOT,
	ANIME_SHOOT_W1,
	ANIME_SHOOT_W2,
	ANIME_SHOOT_W3,
	ANIME_FLY_W1,
	ANIME_FLY_W2,
	ANIME_FLY_W3,
	ANIME_RELOAD,
	ANIME_RELOAD_W1,
	ANIME_RELOAD_W2,
	ANIME_RELOAD_W3,
	ANIME_SPREAD_W1,
	ANIME_SPREAD_W2,
	ANIME_SPREAD_W3,
	ANIME_DRAW,
	ANIME_DRAW_W1,
	ANIME_DRAW_W2,
	ANIME_DRAW_W3
}

enum
{
	STAGE_NONE = 0,
	STAGE_ULTIMATE,
	STAGE_OMEGA,
	STAGE_METATRON
}

#define SCYTHE_CLASSNAME "saisu"

#define CSW_THANATOS3 CSW_MP5NAVY
#define weapon_thanatos3 "weapon_mp5navy"

// Fire Start
#define THANATOS3_OLDMODEL "models/w_mp5.mdl"

const PRIMARY_WEAPONS_BIT_SUM = (1<<CSW_SCOUT)|(1<<CSW_XM1014)|(1<<CSW_MAC10)|(1<<CSW_AUG)|(1<<CSW_UMP45)|(1<<CSW_SG550)|(1<<CSW_GALIL)|(1<<CSW_FAMAS)|(1<<CSW_AWP)|(1<<CSW_MP5NAVY)|(1<<CSW_M249)|(1<<CSW_M3)|(1<<CSW_M4A1)|(1<<CSW_TMP)|(1<<CSW_G3SG1)|(1<<CSW_SG552)|(1<<CSW_AK47)|(1<<CSW_P90)
const SECONDARY_WEAPONS_BIT_SUM = (1<<CSW_P228)|(1<<CSW_ELITE)|(1<<CSW_FIVESEVEN)|(1<<CSW_USP)|(1<<CSW_GLOCK18)|(1<<CSW_DEAGLE)

// MACROS
#define Get_BitVar(%1,%2) (%1 & (1 << (%2 & 31)))
#define Set_BitVar(%1,%2) %1 |= (1 << (%2 & 31))
#define UnSet_BitVar(%1,%2) %1 &= ~(1 << (%2 & 31))

new g_Had_Thanatos3, g_Thanatos3_Clip[33], g_Thanatos3_Stage[33], g_Thanatos3_Count[33]
new g_MsgCurWeapon, g_InTempingAttack
new g_Event_Thanatos3, g_ShellId, g_SmokePuff_SprId, g_HamBot

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
	
	RegisterHam(Ham_Item_Deploy, weapon_thanatos3, "fw_Item_Deploy_Post", 1)	
	RegisterHam(Ham_Item_AddToPlayer, weapon_thanatos3, "fw_Item_AddToPlayer_Post", 1)
	RegisterHam(Ham_Item_PostFrame, weapon_thanatos3, "fw_Item_PostFrame")	
	RegisterHam(Ham_Weapon_Reload, weapon_thanatos3, "fw_Weapon_Reload")
	RegisterHam(Ham_Weapon_Reload, weapon_thanatos3, "fw_Weapon_Reload_Post", 1)	
	RegisterHam(Ham_Weapon_WeaponIdle, weapon_thanatos3, "fw_Weapon_WeaponIdle_Post", 1)
	RegisterHam(Ham_Weapon_PrimaryAttack, weapon_thanatos3, "fw_Weapon_PrimaryAttack_Post", 1)	
	
	RegisterHam(Ham_TraceAttack, "worldspawn", "fw_TraceAttack_World")
	RegisterHam(Ham_TraceAttack, "player", "fw_TraceAttack_Player")	
	
	g_MsgCurWeapon = get_user_msgid("CurWeapon")
	
	register_clcmd("say /get", "Get_Thanatos3", ADMIN_KICK)
}

public plugin_precache()
{
	precache_model(V_MODEL)
	precache_model(P_MODEL)
	precache_model(W_MODEL)
	precache_model(W_MODEL2)
	precache_model(S_MODEL)
	precache_model(S_MODEL2)
	
	for(new i = 0; i < sizeof(WeaponSounds); i++)
		precache_sound(WeaponSounds[i])
	
	g_ShellId = precache_model("models/rshell.mdl")
	g_SmokePuff_SprId = precache_model("sprites/wall_puff1.spr")
	
	register_forward(FM_PrecacheEvent, "fw_PrecacheEvent_Post", 1)
}

public fw_PrecacheEvent_Post(type, const name[])
{
	if(equal("events/mp5n.sc", name)) g_Event_Thanatos3 = get_orig_retval()		
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

public Get_Thanatos3(id)
{
	g_Thanatos3_Count[id] = 0
	g_Thanatos3_Stage[id] = STAGE_NONE
	Set_BitVar(g_Had_Thanatos3, id)
	give_item(id, weapon_thanatos3)
	
	static Ent; Ent = fm_get_user_weapon_entity(id, CSW_THANATOS3)
	if(pev_valid(Ent)) cs_set_weapon_ammo(Ent, CLIP)
	
	Update_Ammo(id, CLIP)
	cs_set_user_bpammo(id, CSW_THANATOS3, BPAMMO)
}

public Remove_Thanatos3(id)
{
	g_Thanatos3_Count[id] = 0
	g_Thanatos3_Stage[id] = STAGE_NONE
	UnSet_BitVar(g_Had_Thanatos3, id)
}

public Update_Ammo(id, Ammo)
{
	if(!is_user_alive(id))
		return
	
	engfunc(EngFunc_MessageBegin, MSG_ONE_UNRELIABLE, g_MsgCurWeapon, {0, 0, 0}, id)
	write_byte(1)
	write_byte(CSW_THANATOS3)
	write_byte(Ammo)
	message_end()
}

public fw_UpdateClientData_Post(id, sendweapons, cd_handle)
{
	if(!is_user_alive(id))
		return FMRES_IGNORED	
	if(get_user_weapon(id) == CSW_THANATOS3 && Get_BitVar(g_Had_Thanatos3, id))
		set_cd(cd_handle, CD_flNextAttack, get_gametime() + 0.001) 
	
	return FMRES_HANDLED
}

public fw_PlaybackEvent(flags, invoker, eventid, Float:delay, Float:origin[3], Float:angles[3], Float:fparam1, Float:fparam2, iParam1, iParam2, bParam1, bParam2)
{
	if (!is_user_connected(invoker))
		return FMRES_IGNORED	
	if(get_user_weapon(invoker) != CSW_THANATOS3 || !Get_BitVar(g_Had_Thanatos3, invoker))
		return FMRES_IGNORED
	if(eventid != g_Event_Thanatos3)
		return FMRES_IGNORED
	
	engfunc(EngFunc_PlaybackEvent, flags | FEV_HOSTONLY, invoker, eventid, delay, origin, angles, fparam1, fparam2, iParam1, iParam2, bParam1, bParam2)
	
	switch(g_Thanatos3_Stage[invoker])
	{
		case STAGE_NONE: Set_WeaponAnim(invoker, ANIME_SHOOT)
		case STAGE_ULTIMATE: Set_WeaponAnim(invoker, ANIME_SHOOT_W1)
		case STAGE_OMEGA: Set_WeaponAnim(invoker, ANIME_SHOOT_W2)
		case STAGE_METATRON: Set_WeaponAnim(invoker, ANIME_SHOOT_W3)
	}
	
	emit_sound(invoker, CHAN_WEAPON, WeaponSounds[0], 1.0, 0.4, 0, 94 + random_num(0, 15))
	Eject_Shell(invoker, g_ShellId, 0.01)
	
	// Check Stage
	g_Thanatos3_Count[invoker]++
	if(g_Thanatos3_Count[invoker] >= STAGE_AMMO)
	{
		if(g_Thanatos3_Stage[invoker] < STAGE_METATRON)
		{
			g_Thanatos3_Stage[invoker]++
			
			switch(g_Thanatos3_Stage[invoker])
			{
				case STAGE_ULTIMATE: Set_WeaponAnim(invoker, ANIME_SPREAD_W1)
				case STAGE_OMEGA: Set_WeaponAnim(invoker, ANIME_SPREAD_W2)
				case STAGE_METATRON: Set_WeaponAnim(invoker, ANIME_SPREAD_W3)
			}
		}
		
		g_Thanatos3_Count[invoker] = 0
	}

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
	
	if(equal(model, THANATOS3_OLDMODEL))
	{
		static weapon; weapon = find_ent_by_owner(-1, weapon_thanatos3, entity)
		
		if(!pev_valid(weapon))
			return FMRES_IGNORED;
		
		if(Get_BitVar(g_Had_Thanatos3, iOwner))
		{
			set_pev(weapon, pev_impulse, 25112015)
			set_pev(weapon, pev_iuser3, g_Thanatos3_Count[iOwner])
			set_pev(weapon, pev_iuser4, g_Thanatos3_Stage[iOwner])
			
			engfunc(EngFunc_SetModel, entity, g_Thanatos3_Stage[iOwner] ? W_MODEL2 : W_MODEL)
			Remove_Thanatos3(iOwner)
			
			return FMRES_SUPERCEDE
		}
	}

	return FMRES_IGNORED;
}

public fw_CmdStart(id, uc_handle, seed)
{
	if(!is_user_alive(id))
		return FMRES_IGNORED
	if(get_user_weapon(id) != CSW_THANATOS3 || !Get_BitVar(g_Had_Thanatos3, id))
		return FMRES_IGNORED
		
	static PressedButton
	PressedButton = get_uc(uc_handle, UC_Buttons)
	
	if(PressedButton & IN_ATTACK2)
	{
		if(get_pdata_float(id, 83, 5) > 0.0)
			return FMRES_IGNORED
		
		PressedButton &= ~IN_ATTACK2
		set_uc(uc_handle, UC_Buttons, PressedButton)
		
		if(g_Thanatos3_Stage[id]) Check_Scythe(id)
	}
		
	return FMRES_HANDLED
}

public Check_Scythe(id)
{
	Create_FakeAttackAnim(id)
	
	Set_Player_NextAttack(id, 1.75)
	Set_WeaponIdleTime(id, CSW_THANATOS3, 2.0)
	
	switch(g_Thanatos3_Stage[id])
	{
		case STAGE_ULTIMATE: Set_WeaponAnim(id, ANIME_FLY_W1)
		case STAGE_OMEGA: Set_WeaponAnim(id, ANIME_FLY_W2)
		case STAGE_METATRON: Set_WeaponAnim(id, ANIME_FLY_W3)
	}
	
	emit_sound(id, CHAN_WEAPON, WeaponSounds[1], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	Shoot_Scyche(id, g_Thanatos3_Stage[id])
	
	// Fake Punch
	static Float:Origin[3]; Origin[0] = -2.5
	set_pev(id, pev_punchangle, Origin)
	
	g_Thanatos3_Stage[id] = STAGE_NONE
}

public Shoot_Scyche(id, Level)
{
	static Float:Origin[6][3], Float:Target[3], LoopTime, Float:Speed[6]
	
	get_position(id, 48.0, -10.0, random_float(-5.0, 5.0), Origin[0]); Speed[0] = random_float(500.0, 1000.0)
	get_position(id, 48.0, 10.0, random_float(-5.0, 5.0), Origin[1]); Speed[1] = random_float(500.0, 1000.0)
	get_position(id, 48.0, -20.0, random_float(-5.0, 5.0), Origin[2]); Speed[2] = random_float(500.0, 1000.0)
	get_position(id, 48.0, 20.0, random_float(-5.0, 5.0), Origin[3]); Speed[3] = random_float(500.0, 1000.0)
	get_position(id, 48.0, -30.0, random_float(-5.0, 5.0), Origin[4]); Speed[4] = random_float(500.0, 1000.0)
	get_position(id, 48.0, 30.0, random_float(-5.0, 5.0), Origin[5]); Speed[5] = random_float(500.0, 1000.0)
	
	get_position(id, 1024.0, 0.0, 0.0, Target)
	
	switch(Level)
	{
		case STAGE_ULTIMATE: LoopTime = 2
		case STAGE_OMEGA: LoopTime = 4
		case STAGE_METATRON: LoopTime = 6
	}
	
	for(new i = 0; i < LoopTime; i++)
		Create_Scythe(id, Origin[i], Target, Speed[i])
}

public Create_Scythe(id, Float:Start[3], Float:End[3], Float:Speed)
{
	static Float:Velocity[3], Float:Angles[3]
	
	pev(id, pev_v_angle, Angles)
	new Ent = create_entity("info_target")
	
	Angles[0] *= -1.0

	// set info for ent
	set_pev(Ent, pev_movetype, MOVETYPE_FLY)
	entity_set_string(Ent, EV_SZ_classname, SCYTHE_CLASSNAME)
	engfunc(EngFunc_SetModel, Ent, S_MODEL)
	
	set_pev(Ent, pev_mins, Float:{-1.0, -1.0, -1.0})
	set_pev(Ent, pev_maxs, Float:{1.0, 1.0, 1.0})
	set_pev(Ent, pev_origin, Start)
	set_pev(Ent, pev_gravity, 0.25)
	set_pev(Ent, pev_angles, Angles)
	set_pev(Ent, pev_solid, SOLID_TRIGGER)
	set_pev(Ent, pev_owner, id)	
	set_pev(Ent, pev_iuser1, get_user_team(id))
	set_pev(Ent, pev_iuser2, 0)
	set_pev(Ent, pev_iuser3, 206)
	set_pev(Ent, pev_fuser1, get_gametime() + SCYTHE_SLASHTIME)

	get_speed_vector(Start, End, Speed, Velocity)
	set_pev(Ent, pev_velocity, Velocity)	
	
	set_pev(Ent, pev_nextthink, get_gametime() + 0.1)
	
	// Animation
	set_pev(Ent, pev_animtime, get_gametime())
	set_pev(Ent, pev_framerate, 1.0)
	set_pev(Ent, pev_sequence, 0)
	
	// Sound
	emit_sound(Ent, CHAN_BODY, WeaponSounds[16], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
}

public fw_Scythe_Think(Ent)
{
	if(!pev_valid(Ent))
		return
		
	static Float:Time; pev(Ent, pev_fuser1, Time)
	static Float:Time2; pev(Ent, pev_fuser2, Time2)
	static Owner; Owner = pev(Ent, pev_owner)
	static Team; Team = pev(Ent, pev_iuser1)
	static Target; Target = pev(Ent, pev_iuser2)
	
	if(Time <= get_gametime() || !is_user_connected(Owner))
	{
		set_pev(Ent, pev_flags, FL_KILLME)
		set_pev(Ent, pev_nextthink, get_gametime() + 0.1)
			
		return
	}
	
	if(is_user_alive(Target))
	{
		if(get_user_team(Target) == Team)
		{
			set_pev(Ent, pev_flags, FL_KILLME)
			set_pev(Ent, pev_nextthink, get_gametime() + 0.1)
			
			return
		}
		
		if(get_gametime() - 0.75 > Time2)
		{
			emit_sound(Ent, CHAN_BODY, WeaponSounds[16], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
			set_pev(Ent, pev_fuser2, get_gametime())
		}
		
		ExecuteHamB(Ham_TakeDamage, Target, 0, Owner, float(DAMAGE) / 1.5, DMG_SLASH)
	} else {
		if(Target)
		{
			set_pev(Ent, pev_flags, FL_KILLME)
			set_pev(Ent, pev_nextthink, get_gametime() + 0.1)
				
			return
		}
	}
	
	set_pev(Ent, pev_nextthink, get_gametime() + 0.2)
}

public fw_Scythe_Touch(Ent, id)
{
	if(!pev_valid(Ent))
		return
	if(pev_valid(id) && pev(id, pev_iuser3) == 206)
		return
		
	if(!is_user_alive(id))
	{
		static Float:Origin[3]; pev(Ent, pev_origin, Origin)
		
		set_pev(Ent, pev_fuser1, get_gametime() + random_float(1.0, 3.0))
		
		set_pev(Ent, pev_velocity, {0.0, 0.0, 0.0})
		set_pev(Ent, pev_movetype, MOVETYPE_NONE)
		set_pev(Ent, pev_solid, SOLID_NOT)
		
		// Animation
		set_pev(Ent, pev_animtime, get_gametime())
		set_pev(Ent, pev_framerate, 1.0)
		set_pev(Ent, pev_sequence, 1)
		
		// Bullet Hole
		static Owner; Owner = pev(Ent, pev_owner)
		Make_BulletHole(Owner, Origin, float(DAMAGE))
		
		// Sound
		emit_sound(Ent, CHAN_BODY, WeaponSounds[random_num(25, 28)], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	} else {
		static Team; Team = pev(Ent, pev_iuser1)
		if(get_user_team(id) == Team)
			return
		static Owner; Owner = pev(Ent, pev_owner)
		if(!is_user_connected(Owner))
			return
		
		if(!pev(Ent, pev_iuser2))
		{
			set_pev(Ent, pev_fuser1, get_gametime() + SCYTHE_SLASHTIME)
			set_pev(Ent, pev_iuser2, id)
			
			set_pev(Ent, pev_velocity, {0.0, 0.0, 0.0})
			set_pev(Ent, pev_movetype, MOVETYPE_FOLLOW)
			set_pev(Ent, pev_solid, SOLID_NOT)
			set_pev(Ent, pev_aiment, id)
			
			engfunc(EngFunc_SetModel, Ent, S_MODEL2)
			
			// Animation
			set_pev(Ent, pev_animtime, get_gametime())
			set_pev(Ent, pev_framerate, random_float(1.0, 5.0))
			set_pev(Ent, pev_sequence, 0)
			
			// Sound
			emit_sound(id, CHAN_STATIC, WeaponSounds[random_num(14, 15)], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
		}
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
	if(!Get_BitVar(g_Had_Thanatos3, Id))
		return
	
	set_pev(Id, pev_viewmodel2, V_MODEL)
	set_pev(Id, pev_weaponmodel2, P_MODEL)
	
	switch(g_Thanatos3_Stage[Id])
	{
		case STAGE_NONE: Set_WeaponAnim(Id, ANIME_DRAW)
		case STAGE_ULTIMATE: Set_WeaponAnim(Id, ANIME_DRAW_W1)
		case STAGE_OMEGA: Set_WeaponAnim(Id, ANIME_DRAW_W2)
		case STAGE_METATRON: Set_WeaponAnim(Id, ANIME_DRAW_W3)
	}
	
	set_pdata_string(Id, (492) * 4, ANIME_EXT, -1 , 20)
}

public fw_Item_AddToPlayer_Post(Ent, id)
{
	if(!pev_valid(Ent))
		return HAM_IGNORED
		
	if(pev(Ent, pev_impulse) == 25112015)
	{
		Set_BitVar(g_Had_Thanatos3, id)
		set_pev(Ent, pev_impulse, 0)
		
		g_Thanatos3_Count[id] = pev(Ent, pev_iuser3)
		g_Thanatos3_Stage[id] = pev(Ent, pev_iuser4)
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
	if(!Get_BitVar(g_Had_Thanatos3, Id))
		return
		
	if(get_pdata_float(iEnt, 48, 4) <= 0.1)
	{
		switch(g_Thanatos3_Stage[Id])
		{
			case STAGE_NONE: Set_WeaponAnim(Id, ANIME_IDLE)
			case STAGE_ULTIMATE: Set_WeaponAnim(Id, ANIME_IDLE_W1)
			case STAGE_OMEGA: Set_WeaponAnim(Id, ANIME_IDLE_W2)
			case STAGE_METATRON: Set_WeaponAnim(Id, ANIME_IDLE_W3)
		}
		
		set_pdata_float(iEnt, 48, 20.0, 4)
	}	
}

public fw_TraceAttack_World(Victim, Attacker, Float:Damage, Float:Direction[3], Ptr, DamageBits)
{
	if(!is_user_connected(Attacker))
		return HAM_IGNORED	
	if(get_user_weapon(Attacker) != CSW_THANATOS3 || !Get_BitVar(g_Had_Thanatos3, Attacker))
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
	if(get_user_weapon(Attacker) != CSW_THANATOS3 || !Get_BitVar(g_Had_Thanatos3, Attacker))
		return HAM_IGNORED
		
	SetHamParamFloat(3, float(DAMAGE))
	
	return HAM_IGNORED
}

public fw_Item_PostFrame(ent)
{
	static id; id = pev(ent, pev_owner)
	if(!is_user_alive(id))
		return HAM_IGNORED
	if(!Get_BitVar(g_Had_Thanatos3, id))
		return HAM_IGNORED	
	
	static Float:flNextAttack; flNextAttack = get_pdata_float(id, 83, 5)
	static bpammo; bpammo = cs_get_user_bpammo(id, CSW_THANATOS3)
	
	static iClip; iClip = get_pdata_int(ent, 51, 4)
	static fInReload; fInReload = get_pdata_int(ent, 54, 4)
	
	if(fInReload && flNextAttack <= 0.0)
	{
		static temp1
		temp1 = min(CLIP - iClip, bpammo)

		set_pdata_int(ent, 51, iClip + temp1, 4)
		cs_set_user_bpammo(id, CSW_THANATOS3, bpammo - temp1)		
		
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
	if(!Get_BitVar(g_Had_Thanatos3, id))
		return HAM_IGNORED	

	g_Thanatos3_Clip[id] = -1
		
	static BPAmmo; BPAmmo = cs_get_user_bpammo(id, CSW_THANATOS3)
	static iClip; iClip = get_pdata_int(ent, 51, 4)
		
	if(BPAmmo <= 0)
		return HAM_SUPERCEDE
	if(iClip >= CLIP)
		return HAM_SUPERCEDE		
			
	g_Thanatos3_Clip[id] = iClip	
	
	return HAM_HANDLED
}

public fw_Weapon_Reload_Post(ent)
{
	static id; id = pev(ent, pev_owner)
	if(!is_user_alive(id))
		return HAM_IGNORED
	if(!Get_BitVar(g_Had_Thanatos3, id))
		return HAM_IGNORED	
		
	if((get_pdata_int(ent, 54, 4) == 1))
	{ // Reload
		if(g_Thanatos3_Clip[id] == -1)
			return HAM_IGNORED
		
		set_pdata_int(ent, 51, g_Thanatos3_Clip[id], 4)
		set_pdata_float(id, 83, RELOAD_TIME, 5)
		set_pdata_float(ent, 48, 3.5, 4)
		
		switch(g_Thanatos3_Stage[id])
		{
			case STAGE_NONE: Set_WeaponAnim(id, ANIME_RELOAD)
			case STAGE_ULTIMATE: Set_WeaponAnim(id, ANIME_RELOAD_W1)
			case STAGE_OMEGA: Set_WeaponAnim(id, ANIME_RELOAD_W2)
			case STAGE_METATRON: Set_WeaponAnim(id, ANIME_RELOAD_W3)
		}
	}
	
	return HAM_HANDLED
}

public fw_Weapon_PrimaryAttack_Post(Ent)
{
	static id; id = pev(Ent, pev_owner)
	if(!is_user_alive(id))
		return HAM_IGNORED
	if(!Get_BitVar(g_Had_Thanatos3, id))
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
