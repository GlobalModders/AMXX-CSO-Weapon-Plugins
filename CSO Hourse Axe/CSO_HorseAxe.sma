#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <cstrike>
#include <fun>

#define PLUGIN "[CSO] Horse Axe"
#define VERSION "1.0"
#define AUTHOR "2015"

#define DAMAGE_A 120
#define DAMAGE_B 240

#define RADIUS 72.0
#define KNOCKBACK_POWER 350.0

#define MODEL_V "models/v_horseaxe.mdl"
#define MODEL_P "models/p_horseaxe.mdl"

new const HorseAxe_Sounds[8][] = 
{
	"weapons/tomahawk_draw.wav",
	"weapons/tomahawk_slash1.wav",
	"weapons/tomahawk_slash1_hit.wav",
	"weapons/tomahawk_slash2.wav",
	"weapons/tomahawk_slash2_hit.wav",	
	"weapons/tomahawk_stab_hit.wav",
	"weapons/tomahawk_stab_miss.wav",
	"weapons/tomahawk_wall.wav"
}

enum
{
	ANIM_IDLE = 0,
	ANIM_SLASH1,
	ANIM_SLASH2,
	ANIM_DRAW,
	ANIM_STAB,
	ANIM_STAB_MISS,
	ANIM_MIDSLASH1,
	ANIM_MIDSLASH2
}

enum
{
	HIT_NOTHING = 0,
	HIT_ENEMY,
	HIT_WALL
}

#define TASK_CHANGE 2512015
#define TASK_ATTACK 25120152

#define CSW_HORSEAXE CSW_KNIFE
#define weapon_horseaxe "weapon_knife"

// MACROS
#define Get_BitVar(%1,%2) (%1 & (1 << (%2 & 31)))
#define Set_BitVar(%1,%2) %1 |= (1 << (%2 & 31))
#define UnSet_BitVar(%1,%2) %1 &= ~(1 << (%2 & 31))

// Vars
new g_Had_HorseAxe, g_TempingAttack, g_Stab
new g_WillBeHit[33]
new g_MaxPlayers

// Safety
new g_IsConnected, g_IsAlive, g_PlayerWeapon[33], g_HamBot

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	// Safety
	Register_SafetyFunc()
	
	// Code
	register_forward(FM_EmitSound, "fw_EmitSound")
	register_forward(FM_TraceLine, "fw_TraceLine")
	register_forward(FM_TraceHull, "fw_TraceHull")		
	
	RegisterHam(Ham_Item_Deploy, weapon_horseaxe, "fw_Item_Deploy_Post", 1)	
	RegisterHam(Ham_TakeDamage, "player", "fw_TakeDamage")
	RegisterHam(Ham_TakeDamage, "player", "fw_TakeDamage_Post", 1)
	
	g_MaxPlayers = get_maxplayers()
	
	register_clcmd("say /get", "Get_HorseAxe")
}

public plugin_precache()
{
	precache_model(MODEL_V)
	precache_model(MODEL_P)
	
	for(new i = 0; i < sizeof(HorseAxe_Sounds); i++)
		precache_sound(HorseAxe_Sounds[i])
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
	RegisterHamFromEntity(Ham_TakeDamage, id, "fw_TakeDamage")
	RegisterHamFromEntity(Ham_TakeDamage, id, "fw_TakeDamage_Post", 1)
}

public client_disconnect(id)
{
	Safety_Disconnected(id)
}

public Get_HorseAxe(id)
{
	Set_BitVar(g_Had_HorseAxe, id)
	UnSet_BitVar(g_TempingAttack, id)
	
	g_WillBeHit[id] = HIT_NOTHING
	
	if(get_user_weapon(id) == CSW_KNIFE)
	{
		set_pev(id, pev_viewmodel2, MODEL_V)
		set_pev(id, pev_weaponmodel2, MODEL_P)	

		Set_WeaponAnim(id, ANIM_DRAW)
	} else {
		engclient_cmd(id, weapon_horseaxe)
	}	
}

public Remove_Papin(id)
{
	UnSet_BitVar(g_Had_HorseAxe, id)
}

public fw_EmitSound(id, channel, const sample[], Float:volume, Float:attn, flags, pitch)
{
	if(!is_connected(id))
		return FMRES_IGNORED
	if(get_player_weapon(id) != CSW_HORSEAXE || !Get_BitVar(g_Had_HorseAxe, id))
		return FMRES_IGNORED

	if(sample[8] == 'k' && sample[9] == 'n' && sample[10] == 'i')
	{
		if(sample[14] == 's' && sample[15] == 'l' && sample[16] == 'a')
		{
			emit_sound(id, channel, random_num(0, 1) ? HorseAxe_Sounds[1] : HorseAxe_Sounds[3], volume, attn, flags, pitch)
			set_task(0.1, "Set_Speed", id)
			
			UnSet_BitVar(g_Stab, id)
			
			return FMRES_SUPERCEDE
		}
		if (sample[14] == 'h' && sample[15] == 'i' && sample[16] == 't')
		{
			set_task(0.1, "Set_Speed", id)
			if (sample[17] == 'w') // wall
			{
				UnSet_BitVar(g_Stab, id)
				emit_sound(id, channel, HorseAxe_Sounds[7], volume, attn, flags, pitch)
				return FMRES_SUPERCEDE
			} else {
				UnSet_BitVar(g_Stab, id)
				emit_sound(id, channel, random_num(0, 1) ? HorseAxe_Sounds[2] : HorseAxe_Sounds[4], volume, attn, flags, pitch)
				return FMRES_SUPERCEDE
			}
		}
		if (sample[14] == 's' && sample[15] == 't' && sample[16] == 'a')
		{
			Set_BitVar(g_Stab, id)
			
			emit_sound(id, channel, HorseAxe_Sounds[5], volume, attn, flags, pitch)
			set_task(0.1, "Set_Speed2", id)
			return FMRES_SUPERCEDE;
		}
	}
	
	return FMRES_IGNORED
}

public Set_Speed(id)
{
	Set_Weapon_Idle(id, CSW_HORSEAXE, 0.25 + 0.3)
	Set_Player_NextAttack(id, 0.25)	
}

public Set_Speed2(id)
{
	Set_Weapon_Idle(id, CSW_HORSEAXE, 0.5 + 0.3)
	Set_Player_NextAttack(id, 0.5)	
}

public fw_TraceLine(Float:vector_start[3], Float:vector_end[3], ignored_monster, id, handle)
{
	if(!is_alive(id))
		return FMRES_IGNORED	
	if(get_player_weapon(id) != CSW_HORSEAXE || !Get_BitVar(g_Had_HorseAxe, id))
		return FMRES_IGNORED
	
	static Float:vecStart[3], Float:vecEnd[3], Float:v_angle[3], Float:v_forward[3], Float:view_ofs[3], Float:fOrigin[3]
	
	pev(id, pev_origin, fOrigin)
	pev(id, pev_view_ofs, view_ofs)
	xs_vec_add(fOrigin, view_ofs, vecStart)
	pev(id, pev_v_angle, v_angle)
	
	engfunc(EngFunc_MakeVectors, v_angle)
	get_global_vector(GL_v_forward, v_forward)

	if(!Get_BitVar(g_TempingAttack, id)) xs_vec_mul_scalar(v_forward, RADIUS, v_forward)
	else xs_vec_mul_scalar(v_forward, 0.0, v_forward)
	xs_vec_add(vecStart, v_forward, vecEnd)
	
	engfunc(EngFunc_TraceLine, vecStart, vecEnd, ignored_monster, id, handle)
	
	return FMRES_SUPERCEDE
}

public fw_TraceHull(Float:vector_start[3], Float:vector_end[3], ignored_monster, hull, id, handle)
{
	if(!is_alive(id))
		return FMRES_IGNORED	
	if(get_player_weapon(id) != CSW_HORSEAXE || !Get_BitVar(g_Had_HorseAxe, id))
		return FMRES_IGNORED
	
	static Float:vecStart[3], Float:vecEnd[3], Float:v_angle[3], Float:v_forward[3], Float:view_ofs[3], Float:fOrigin[3]
	
	pev(id, pev_origin, fOrigin)
	pev(id, pev_view_ofs, view_ofs)
	xs_vec_add(fOrigin, view_ofs, vecStart)
	pev(id, pev_v_angle, v_angle)
	
	engfunc(EngFunc_MakeVectors, v_angle)
	get_global_vector(GL_v_forward, v_forward)

	if(!Get_BitVar(g_TempingAttack, id)) xs_vec_mul_scalar(v_forward, RADIUS, v_forward)
	else xs_vec_mul_scalar(v_forward, 0.0, v_forward)
	xs_vec_add(vecStart, v_forward, vecEnd)
	
	engfunc(EngFunc_TraceHull, vecStart, vecEnd, ignored_monster, hull, id, handle)
	
	return FMRES_SUPERCEDE
}

/*
public Create_DamageB(id)
{
	static Float:Max_Distance, Float:Point[4][3], Float:TB_Distance, Float:Point_Dis
	
	Point_Dis = RADIUS_B / 2.0
	Max_Distance = RADIUS_B
	TB_Distance = Max_Distance / 4.0
	
	static Float:VicOrigin[3], Float:MyOrigin[3]
	pev(id, pev_origin, MyOrigin)
	
	for(new i = 0; i < 4; i++)
		get_position(id, TB_Distance * (i + 1), 0.0, 0.0, Point[i])
		
	static Have_Victim; Have_Victim = 0
	static ent; ent = fm_get_user_weapon_entity(id, get_user_weapon(id))
		
	if(!pev_valid(ent))
		return 0
		
	for(new i = 0; i < g_MaxPlayers; i++)
	{
		if(!is_user_alive(i))
			continue
		if(id == i)
			continue
		if(entity_range(id, i) > Max_Distance)
			continue

		pev(i, pev_origin, VicOrigin)
		if(is_wall_between_points(MyOrigin, VicOrigin, id))
			continue
			
		if(get_distance_f(VicOrigin, Point[0]) <= Point_Dis
		|| get_distance_f(VicOrigin, Point[1]) <= Point_Dis
		|| get_distance_f(VicOrigin, Point[2]) <= Point_Dis
		|| get_distance_f(VicOrigin, Point[3]) <= Point_Dis)
		{
			if(!Have_Victim) Have_Victim = 1
			ExecuteHamB(Ham_TakeDamage, i, "knife", id, float(DAMAGE_B), DMG_SLASH)
			
			HookEnt(i, MyOrigin, KNOCKBACK_POWER)
		}
	}	
	
	if(Have_Victim)
	{
		emit_sound(id, CHAN_ITEM, HorseAxe_Sounds[2], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	} else {
		static Float:StartOrigin[3], Float:EndOrigin[3]
		get_position(id, 0.0, 0.0, 26.0, StartOrigin)
		get_position(id, RADIUS_A, 0.0, 26.0, EndOrigin)
		
		if(is_wall_between_points(StartOrigin, EndOrigin, id)) 
		{
			emit_sound(id, CHAN_ITEM, HorseAxe_Sounds[3], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
		} else {
			emit_sound(id, CHAN_ITEM, HorseAxe_Sounds[3], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
		}
	}
	
	return 1
}
*/

public fw_TakeDamage(Victim, Inflictor, Attacker, Float:Damage, DamageBits)
{
	if(!is_alive(Attacker))
		return HAM_IGNORED
	if(get_player_weapon(Attacker) != CSW_HORSEAXE || !Get_BitVar(g_Had_HorseAxe, Attacker))
		return HAM_IGNORED
		
	if(Get_BitVar(g_Stab, Attacker)) 
	{
		SetHamParamFloat(4, float(DAMAGE_B))
	} else {
		SetHamParamFloat(4, float(DAMAGE_A))
	}
	
	return HAM_HANDLED
}

public fw_TakeDamage_Post(Victim, Inflictor, Attacker, Float:Damage, DamageBits)
{
	if(!is_alive(Attacker))
		return HAM_IGNORED
	if(get_player_weapon(Attacker) != CSW_HORSEAXE || !Get_BitVar(g_Had_HorseAxe, Attacker))
		return HAM_IGNORED
		
	if(Get_BitVar(g_Stab, Attacker)) 
	{
		static Float:Origin[3]; pev(Attacker, pev_origin, Origin)
		if(is_user_alive(Victim)) HookEnt(Victim, Origin, KNOCKBACK_POWER)
	}
	
	return HAM_HANDLED
}

public fw_Item_Deploy_Post(Ent)
{
	if(pev_valid(Ent) != 2)
		return
	static Id; Id = get_pdata_cbase(Ent, 41, 4)
	if(get_pdata_cbase(Id, 373) != Ent)
		return
	if(!Get_BitVar(g_Had_HorseAxe, Id))
		return
		
	set_pev(Id, pev_viewmodel2, MODEL_V)
	set_pev(Id, pev_weaponmodel2, MODEL_P)
	
	PlaySound(Id, HorseAxe_Sounds[0])
	
	Set_WeaponAnim(Id, ANIM_DRAW)
}

stock HookEnt(ent, Float:VicOrigin[3], Float:speed)
{
	static Float:fl_Velocity[3]
	static Float:EntOrigin[3]
	
	pev(ent, pev_origin, EntOrigin)
	static Float:distance_f
	distance_f = get_distance_f(EntOrigin, VicOrigin)
	
	static Float:fl_Time; fl_Time = distance_f / speed
	
	fl_Velocity[0] = ((EntOrigin[0] - VicOrigin[0]) / fl_Time) * 1.5
	fl_Velocity[1] = ((EntOrigin[1] - VicOrigin[1]) / fl_Time) * 1.5
	fl_Velocity[2] = ((EntOrigin[2] - VicOrigin[2]) / fl_Time) + 500.0

	set_pev(ent, pev_velocity, fl_Velocity)
}

stock is_wall_between_points(Float:start[3], Float:end[3], ignore_ent)
{
	static ptr
	ptr = create_tr2()

	engfunc(EngFunc_TraceLine, start, end, IGNORE_MONSTERS, ignore_ent, ptr)
	
	static Float:EndPos[3]
	get_tr2(ptr, TR_vecEndPos, EndPos)

	free_tr2(ptr)
	return floatround(get_distance_f(end, EndPos))
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
stock PlaySound(id, const sound[])
{
	if(equal(sound[strlen(sound)-4], ".mp3")) client_cmd(id, "mp3 play ^"sound/%s^"", sound)
	else client_cmd(id, "spk ^"%s^"", sound)
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
	if(!(1 <= id <= 32))
		return 0
	if(!Get_BitVar(g_IsConnected, id))
		return 0
	if(Get_BitVar(g_IsAlive, id)) return 1
	else return 0
	
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
