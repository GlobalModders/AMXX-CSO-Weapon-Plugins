#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <cstrike>
#include <fun>

#define PLUGIN "[CSO] Hammer"
#define VERSION "1.0"
#define AUTHOR "2015"

#define DAMAGE_A 1300
#define DAMAGE_B 650

#define RADIUS_A 96.0
#define RADIUS_B 110.0

#define SPEED_A 250.0
#define SPEED_B 150.0

#define ATTACK_A_DELAY 1.0
#define NEXTATK_B 2.0

#define CHANGE_TIME 1.35
#define KNOCKBACK_POWER 1000.0

#define MODEL_V "models/v_hammer.mdl"
#define MODEL_P "models/p_hammer.mdl"

new const Hammer_Sounds[4][] = 
{
	"weapons/hammer_draw.wav",
	"weapons/hammer_hit_slash.wav",
	"weapons/hammer_hit_stab.wav",
	"weapons/hammer_swing.wav"
}

enum
{
	ANIM_IDLE_A = 0,
	ANIM_ATTACK_A,
	ANIM_DRAW_A,
	ANIM_IDLE_B,
	ANIM_ATTACK_B,
	ANIM_DRAW_B,
	ANIM_CHANGE_AB,
	ANIM_CHANGE_BA
}

enum
{
	HIT_NOTHING = 0,
	HIT_ENEMY,
	HIT_WALL
}

#define TASK_CHANGE 2512015
#define TASK_ATTACK 25120152

#define CSW_HAMMER CSW_KNIFE
#define weapon_hammer "weapon_knife"

// MACROS
#define Get_BitVar(%1,%2) (%1 & (1 << (%2 & 31)))
#define Set_BitVar(%1,%2) %1 |= (1 << (%2 & 31))
#define UnSet_BitVar(%1,%2) %1 &= ~(1 << (%2 & 31))

// Vars
new g_Had_Hammer, g_SpecialMode, g_ChangingMode, g_TempingAttack
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
	register_forward(FM_UpdateClientData, "fw_UpdateClientData_Post", 1)
	register_forward(FM_CmdStart, "fw_CmdStart")
	register_forward(FM_EmitSound, "fw_EmitSound")
	register_forward(FM_TraceLine, "fw_TraceLine")
	register_forward(FM_TraceHull, "fw_TraceHull")		
	
	RegisterHam(Ham_Item_Deploy, weapon_hammer, "fw_Item_Deploy_Post", 1)	
	RegisterHam(Ham_Weapon_WeaponIdle, weapon_hammer, "fw_Weapon_WeaponIdle_Post", 1)
	
	g_MaxPlayers = get_maxplayers()
	
	register_clcmd("say /get", "Get_Hammer")
}

public plugin_precache()
{
	precache_model(MODEL_V)
	precache_model(MODEL_P)
	
	for(new i = 0; i < sizeof(Hammer_Sounds); i++)
		precache_sound(Hammer_Sounds[i])
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

public Do_Register_HamBot(id) Register_SafetyFuncBot(id)
public client_disconnect(id)
{
	Safety_Disconnected(id)
}

public Get_Hammer(id)
{
	Set_BitVar(g_Had_Hammer, id)
	UnSet_BitVar(g_TempingAttack, id)
	UnSet_BitVar(g_SpecialMode, id)
	UnSet_BitVar(g_ChangingMode, id)
	
	g_WillBeHit[id] = HIT_NOTHING
	
	if(get_user_weapon(id) == CSW_KNIFE)
	{
		set_pev(id, pev_viewmodel2, MODEL_V)
		set_pev(id, pev_weaponmodel2, MODEL_P)	

		Set_WeaponAnim(id, ANIM_DRAW_A)
	} else {
		engclient_cmd(id, weapon_hammer)
	}	
}

public Remove_Papin(id)
{
	UnSet_BitVar(g_Had_Hammer, id)
	UnSet_BitVar(g_SpecialMode, id)
	UnSet_BitVar(g_ChangingMode, id)
}

public fw_UpdateClientData_Post(id, sendweapons, cd_handle)
{
	if(!is_alive(id))
		return FMRES_IGNORED	
	if(get_player_weapon(id) == CSW_HAMMER && Get_BitVar(g_Had_Hammer, id))
		set_cd(cd_handle, CD_flNextAttack, get_gametime() + 0.001) 
	
	return FMRES_HANDLED
}

public fw_EmitSound(id, channel, const sample[], Float:volume, Float:attn, flags, pitch)
{
	if(!is_connected(id))
		return FMRES_IGNORED
	if(get_player_weapon(id) != CSW_HAMMER || !Get_BitVar(g_Had_Hammer, id))
		return FMRES_IGNORED
		
	if(sample[8] == 'k' && sample[9] == 'n' && sample[10] == 'i')
	{
		if(sample[14] == 's' && sample[15] == 'l' && sample[16] == 'a')
		{
			return FMRES_SUPERCEDE
		}
		if (sample[14] == 'h' && sample[15] == 'i' && sample[16] == 't')
		{
			if (sample[17] == 'w') // wall
			{
				return FMRES_SUPERCEDE
			} else {
				return FMRES_SUPERCEDE
			}
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
	if(get_player_weapon(id) != CSW_HAMMER || !Get_BitVar(g_Had_Hammer, id))
		return FMRES_IGNORED
	
	static Float:vecStart[3], Float:vecEnd[3], Float:v_angle[3], Float:v_forward[3], Float:view_ofs[3], Float:fOrigin[3]
	
	pev(id, pev_origin, fOrigin)
	pev(id, pev_view_ofs, view_ofs)
	xs_vec_add(fOrigin, view_ofs, vecStart)
	pev(id, pev_v_angle, v_angle)
	
	engfunc(EngFunc_MakeVectors, v_angle)
	get_global_vector(GL_v_forward, v_forward)

	if(!Get_BitVar(g_TempingAttack, id)) 
	{
		if(Get_BitVar(g_SpecialMode, id)) xs_vec_mul_scalar(v_forward, RADIUS_B, v_forward)
		else xs_vec_mul_scalar(v_forward, RADIUS_A, v_forward)
	} else xs_vec_mul_scalar(v_forward, 0.0, v_forward)
	xs_vec_add(vecStart, v_forward, vecEnd)
	
	engfunc(EngFunc_TraceLine, vecStart, vecEnd, ignored_monster, id, handle)
	
	return FMRES_SUPERCEDE
}

public fw_TraceHull(Float:vector_start[3], Float:vector_end[3], ignored_monster, hull, id, handle)
{
	if(!is_alive(id))
		return FMRES_IGNORED	
	if(get_player_weapon(id) != CSW_HAMMER || !Get_BitVar(g_Had_Hammer, id))
		return FMRES_IGNORED
	
	static Float:vecStart[3], Float:vecEnd[3], Float:v_angle[3], Float:v_forward[3], Float:view_ofs[3], Float:fOrigin[3]
	
	pev(id, pev_origin, fOrigin)
	pev(id, pev_view_ofs, view_ofs)
	xs_vec_add(fOrigin, view_ofs, vecStart)
	pev(id, pev_v_angle, v_angle)
	
	engfunc(EngFunc_MakeVectors, v_angle)
	get_global_vector(GL_v_forward, v_forward)

	if(!Get_BitVar(g_TempingAttack, id)) 
	{
		if(Get_BitVar(g_SpecialMode, id)) xs_vec_mul_scalar(v_forward, RADIUS_B, v_forward)
		else xs_vec_mul_scalar(v_forward, RADIUS_A, v_forward)
	} else xs_vec_mul_scalar(v_forward, 0.0, v_forward)
	xs_vec_add(vecStart, v_forward, vecEnd)
	
	engfunc(EngFunc_TraceHull, vecStart, vecEnd, ignored_monster, hull, id, handle)
	
	return FMRES_SUPERCEDE
}

public fw_CmdStart(id, uc_handle, seed)
{
	if(!is_alive(id)) 
		return
	if(get_player_weapon(id) != CSW_HAMMER || !Get_BitVar(g_Had_Hammer, id))
		return
	
	static Ent; Ent = fm_get_user_weapon_entity(id, CSW_HAMMER)
	if(!pev_valid(Ent))
		return
	if(get_pdata_float(id, 83, 5) > 0.0) 
		return
	
	static CurButton; CurButton = get_uc(uc_handle, UC_Buttons)
	if(CurButton & IN_ATTACK)
	{
		CurButton &= ~IN_ATTACK
		set_uc(uc_handle, UC_Buttons, CurButton)
		
		static Ent; Ent = fm_get_user_weapon_entity(id, CSW_HAMMER)
		if(!pev_valid(Ent)) return
		
		if(Get_BitVar(g_ChangingMode, id))
			return
			
		if(!Get_BitVar(g_SpecialMode, id))
		{
			Set_Weapon_Idle(id, CSW_HAMMER, (ATTACK_A_DELAY+1.0) + 0.3)
			Set_Player_NextAttack(id, (ATTACK_A_DELAY+1.0))
			
			Set_WeaponAnim(id, ANIM_ATTACK_A)
			set_task(ATTACK_A_DELAY, "Create_DamageA", id+TASK_ATTACK)
		} else {
			Set_Weapon_Idle(id, CSW_HAMMER, NEXTATK_B + 0.3)
			Set_Player_NextAttack(id, NEXTATK_B)
			
			Set_WeaponAnim(id, ANIM_ATTACK_B)
			Create_DamageB(id)
		}
	}
	
	if(CurButton & IN_ATTACK2) 
	{
		CurButton &= ~IN_ATTACK2
		set_uc(uc_handle, UC_Buttons, CurButton)
		
		static Ent; Ent = fm_get_user_weapon_entity(id, CSW_HAMMER)
		if(!pev_valid(Ent)) return
		
		if(Get_BitVar(g_ChangingMode, id))
			return
			
		Set_Weapon_Idle(id, CSW_HAMMER, CHANGE_TIME + 0.3)
		Set_Player_NextAttack(id, CHANGE_TIME)
		
		if(!Get_BitVar(g_SpecialMode, id))
		{
			Set_Speed(id, SPEED_B)
			Set_WeaponAnim(id, ANIM_CHANGE_AB)
		} else {
			Set_Speed(id, SPEED_A)
			Set_WeaponAnim(id, ANIM_CHANGE_BA)
		}
		
		remove_task(id+TASK_CHANGE)
		set_task(CHANGE_TIME - 0.15, "ChangeComplete", id+TASK_CHANGE)
	}
}

public Create_DamageA(id)
{
	id -= TASK_ATTACK
	
	if(!is_alive(id)) 
		return 0
	
	static Float:Max_Distance, Float:Point[4][3], Float:TB_Distance, Float:Point_Dis
	
	Point_Dis = RADIUS_A / 2.0
	Max_Distance = RADIUS_A
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
			ExecuteHamB(Ham_TakeDamage, i, "knife", id, float(DAMAGE_A), DMG_SLASH)
		}
	}	
	
	if(Have_Victim)
	{
		emit_sound(id, CHAN_ITEM, Hammer_Sounds[1], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	} else {
		static Float:StartOrigin[3], Float:EndOrigin[3]
		get_position(id, 0.0, 0.0, 26.0, StartOrigin)
		get_position(id, RADIUS_A, 0.0, 26.0, EndOrigin)
		
		if(is_wall_between_points(StartOrigin, EndOrigin, id)) 
		{
			emit_sound(id, CHAN_ITEM, Hammer_Sounds[3], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
		} else {
			emit_sound(id, CHAN_ITEM, Hammer_Sounds[3], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
		}
	}
	
	return 1
}

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
		emit_sound(id, CHAN_ITEM, Hammer_Sounds[2], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	} else {
		static Float:StartOrigin[3], Float:EndOrigin[3]
		get_position(id, 0.0, 0.0, 26.0, StartOrigin)
		get_position(id, RADIUS_A, 0.0, 26.0, EndOrigin)
		
		if(is_wall_between_points(StartOrigin, EndOrigin, id)) 
		{
			emit_sound(id, CHAN_ITEM, Hammer_Sounds[3], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
		} else {
			emit_sound(id, CHAN_ITEM, Hammer_Sounds[3], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
		}
	}
	
	return 1
}

public ChangeComplete(id)
{
	id -= TASK_CHANGE
	
	if(!is_alive(id)) 
		return
	if(get_player_weapon(id) != CSW_HAMMER || !Get_BitVar(g_Had_Hammer, id))
		return
		
	if(!Get_BitVar(g_SpecialMode, id)) Set_BitVar(g_SpecialMode, id)
	else UnSet_BitVar(g_SpecialMode, id)
}

public fw_Item_Deploy_Post(Ent)
{
	if(pev_valid(Ent) != 2)
		return
	static Id; Id = get_pdata_cbase(Ent, 41, 4)
	if(get_pdata_cbase(Id, 373) != Ent)
		return
	if(!Get_BitVar(g_Had_Hammer, Id))
		return
		
	set_pev(Id, pev_viewmodel2, MODEL_V)
	set_pev(Id, pev_weaponmodel2, MODEL_P)
	
	set_task(0.1, "Check_PlayerSpeed", Id)
	PlaySound(Id, Hammer_Sounds[0])
	
	Set_WeaponAnim(Id, Get_BitVar(g_SpecialMode, Id) ? ANIM_DRAW_B : ANIM_DRAW_A)
}

public Check_PlayerSpeed(Id)
{
	if(!is_user_alive(Id))
		return
	
	if(!Get_BitVar(g_SpecialMode, Id)) Set_Speed(Id, SPEED_A)
	else Set_Speed(Id, SPEED_B)
}

public fw_Weapon_WeaponIdle_Post(Ent)
{
	if(pev_valid(Ent) != 2)
		return HAM_IGNORED
	static Id; Id = get_pdata_cbase(Ent, 41, 4)
	if(get_pdata_cbase(Id, 373) != Ent)
		return HAM_IGNORED
	if(!Get_BitVar(g_Had_Hammer, Id))
		return HAM_IGNORED
		
	if(get_pdata_float(Ent, 48, 4) <= 0.25) 
	{
		Set_WeaponAnim(Id, Get_BitVar(g_SpecialMode, Id) ? ANIM_IDLE_B : ANIM_IDLE_A)
		set_pdata_float(Ent, 48, 20.0, 4)
	}
	
	return HAM_IGNORED
}

public Set_Speed(id, Float:Speed)
{
	set_pev(id, pev_maxspeed, Speed)
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
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang1042\\ f0\\ fs16 \n\\ par }
*/
