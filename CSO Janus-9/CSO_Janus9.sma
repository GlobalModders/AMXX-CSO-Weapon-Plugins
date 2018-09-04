#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <cstrike>
#include <fun>

#define PLUGIN "[CSO] Janus-9"
#define VERSION "1.0"
#define AUTHOR "Dias Pendragon"

/* ===============================
------------ Configs -------------
=================================*/
#define DAMAGE_A 60 // 200 for Zombie
#define DAMAGE_B 120 // 400 for Zombie

#define RADIUS_A 86
#define RADIUS_B 100

#define DELAY_TIME 0.75
#define RESET_TIME 5.0

#define ANIMEXT_A "knife"
#define ANIMEXT_B "knife"

#define V_MODEL "models/v_janus9.mdl"
#define P_MODEL_A "models/p_janus9_a.mdl"
#define P_MODEL_B "models/p_janus9_b.mdl"

new const WeaponSounds[10][] =
{
	"weapons/janus9_draw.wav",
	"weapons/janus9_endsignal.wav",
	"weapons/janus9_hit1.wav",
	"weapons/janus9_hit2.wav",
	"weapons/janus9_slash1.wav",
	"weapons/janus9_slash2_signal.wav",
	"weapons/janus9_stab1.wav",
	"weapons/janus9_stab2.wav",
	"weapons/janus9_stone1.wav",
	"weapons/janus9_stone2.wav"
}

enum
{
	ANIM_IDLE_A = 0,
	ANIM_IDLE_B,
	ANIM_SIGNAL_END,
	ANIM_SLASH1,
	ANIM_SLASH1_STARTSIGNAL,
	ANIM_SLASH1_SIGNAL,
	ANIM_SLASH2,
	ANIM_SLASH2_STARTSIGNAL,
	ANIM_SLASH2_SIGNAL,
	ANIM_DRAW,
	ANIM_DRAW_SIGNAL,
	ANIM_STAB1,
	ANIM_STAB2
}

/* ===============================
--------- End of Config ----------
=================================*/

#define CSW_JANUS9 CSW_KNIFE
#define weapon_janus9 "weapon_knife"

// MACROS
#define Get_BitVar(%1,%2) (%1 & (1 << (%2 & 31)))
#define Set_BitVar(%1,%2) %1 |= (1 << (%2 & 31))
#define UnSet_BitVar(%1,%2) %1 &= ~(1 << (%2 & 31))

#define TASK_RESET 4965

enum
{
	HIT_NOTHING = 0,
	HIT_ENEMY,
	HIT_WALL
}

enum
{
	ATTACK_SLASH1 = 0,
	ATTACK_SLASH2,
	ATTACK_SLASH3
}

// Vars
//new g_Janus9
new g_Had_Janus9, g_JanusForm, g_TempingAttack
new g_WillBeHit[33], g_SlashType
new g_HamBot

// Safety
new g_IsConnected, g_IsAlive, g_PlayerWeapon[33]

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	register_forward(FM_UpdateClientData, "fw_UpdateClientData_Post", 1)
	register_forward(FM_CmdStart, "fw_CmdStart")
	register_forward(FM_EmitSound, "fw_EmitSound")
	register_forward(FM_TraceLine, "fw_TraceLine")
	register_forward(FM_TraceHull, "fw_TraceHull")		
	
	Register_SafetyFunc()
	
	RegisterHam(Ham_Item_Deploy, weapon_janus9, "fw_Item_Deploy_Post", 1)	
	RegisterHam(Ham_Weapon_WeaponIdle, weapon_janus9, "fw_Weapon_WeaponIdle_Post", 1)
	
	register_clcmd("admin_get_janus9", "Get_Janus9", ADMIN_KICK)
}

public plugin_precache()
{
	precache_model(V_MODEL)
	precache_model(P_MODEL_A)
	precache_model(P_MODEL_B)
	
	for(new i = 0; i < sizeof(WeaponSounds); i++)
		precache_sound(WeaponSounds[i])
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

public Get_Janus9(id)
{
	Set_BitVar(g_Had_Janus9, id)
	
	UnSet_BitVar(g_TempingAttack, id)
	UnSet_BitVar(g_JanusForm, id)
	UnSet_BitVar(g_SlashType, id)
	
	g_WillBeHit[id] = HIT_NOTHING
	remove_task(id+TASK_RESET)
	
	give_item(id, weapon_janus9)
	if(get_user_weapon(id) == CSW_JANUS9)
	{
		set_pev(id, pev_viewmodel2, V_MODEL)
		set_pev(id, pev_weaponmodel2, P_MODEL_A)	

		Set_WeaponAnim(id, ANIM_DRAW)
		PlaySound(id, WeaponSounds[0])
	} else {
		engclient_cmd(id, weapon_janus9)
	}	
}

public fw_UpdateClientData_Post(id, sendweapons, cd_handle)
{
	if(!is_player(id, 1))
		return FMRES_IGNORED	
	if(get_player_weapon(id) == CSW_JANUS9 && Get_BitVar(g_Had_Janus9, id))
		set_cd(cd_handle, CD_flNextAttack, get_gametime() + 0.001) 
	
	return FMRES_HANDLED
}

public fw_EmitSound(id, channel, const sample[], Float:volume, Float:attn, flags, pitch)
{
	if(!is_player(id, 0))
		return FMRES_IGNORED
	if(get_player_weapon(id) != CSW_JANUS9 || !Get_BitVar(g_Had_Janus9, id))
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
	if(!is_player(id, 1))
		return FMRES_IGNORED	
	if(get_player_weapon(id) != CSW_JANUS9 || !Get_BitVar(g_Had_Janus9, id))
		return FMRES_IGNORED
	
	static Float:vecStart[3], Float:vecEnd[3], Float:v_angle[3], Float:v_forward[3], Float:view_ofs[3], Float:fOrigin[3]
	
	pev(id, pev_origin, fOrigin)
	pev(id, pev_view_ofs, view_ofs)
	xs_vec_add(fOrigin, view_ofs, vecStart)
	pev(id, pev_v_angle, v_angle)
	
	engfunc(EngFunc_MakeVectors, v_angle)
	get_global_vector(GL_v_forward, v_forward)

	if(!Get_BitVar(g_TempingAttack, id)) xs_vec_mul_scalar(v_forward, (Get_BitVar(g_JanusForm, id) ? float(RADIUS_B) : float(RADIUS_A)), v_forward)
	else xs_vec_mul_scalar(v_forward, 0.0, v_forward)
	xs_vec_add(vecStart, v_forward, vecEnd)
	
	engfunc(EngFunc_TraceLine, vecStart, vecEnd, ignored_monster, id, handle)
	
	return FMRES_SUPERCEDE
}

public fw_TraceHull(Float:vector_start[3], Float:vector_end[3], ignored_monster, hull, id, handle)
{
	if(!is_player(id, 1))
		return FMRES_IGNORED	
	if(get_player_weapon(id) != CSW_JANUS9 || !Get_BitVar(g_Had_Janus9, id))
		return FMRES_IGNORED
	
	static Float:vecStart[3], Float:vecEnd[3], Float:v_angle[3], Float:v_forward[3], Float:view_ofs[3], Float:fOrigin[3]
	
	pev(id, pev_origin, fOrigin)
	pev(id, pev_view_ofs, view_ofs)
	xs_vec_add(fOrigin, view_ofs, vecStart)
	pev(id, pev_v_angle, v_angle)
	
	engfunc(EngFunc_MakeVectors, v_angle)
	get_global_vector(GL_v_forward, v_forward)
	
	if(!Get_BitVar(g_TempingAttack, id)) xs_vec_mul_scalar(v_forward, (Get_BitVar(g_JanusForm, id) ? float(RADIUS_B) : float(RADIUS_A)), v_forward)
	else xs_vec_mul_scalar(v_forward, 0.0, v_forward)
	xs_vec_add(vecStart, v_forward, vecEnd)
	
	engfunc(EngFunc_TraceHull, vecStart, vecEnd, ignored_monster, hull, id, handle)
	
	return FMRES_SUPERCEDE
}

public fw_CmdStart(id, uc_handle, seed)
{
	if(!is_player(id,1)) 
		return
	if(get_player_weapon(id) != CSW_JANUS9|| !Get_BitVar(g_Had_Janus9, id))
		return
	
	static Ent; Ent = fm_get_user_weapon_entity(id, CSW_JANUS9)
	if(!pev_valid(Ent))
		return
	if(get_pdata_float(id, 83, 5) > 0.0) 
		return
	
	static CurButton; CurButton = get_uc(uc_handle, UC_Buttons)
	if(CurButton & IN_ATTACK)
	{
		CurButton &= ~IN_ATTACK
		set_uc(uc_handle, UC_Buttons, CurButton)

		static Ent; Ent = fm_get_user_weapon_entity(id, CSW_JANUS9)
		if(!pev_valid(Ent)) return
	
		set_pdata_string(id, (492) * 4, ANIMEXT_A, -1 , 20)
			
		Set_BitVar(g_TempingAttack, id)
		ExecuteHamB(Ham_Weapon_PrimaryAttack, Ent)
		UnSet_BitVar(g_TempingAttack, id)
		
		Set_Weapon_Idle(id, CSW_JANUS9, DELAY_TIME)
		Set_Player_NextAttack(id, DELAY_TIME)
		
		if(!Get_BitVar(g_SlashType, id))
		{
			Set_BitVar(g_SlashType, id)
			
			Set_WeaponAnim(id, Get_BitVar(g_JanusForm, id) ? ANIM_SLASH1_SIGNAL : ANIM_SLASH1)
			emit_sound(id, CHAN_WEAPON, WeaponSounds[4], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
		} else {
			UnSet_BitVar(g_SlashType, id)
			
			Set_WeaponAnim(id, Get_BitVar(g_JanusForm, id) ? ANIM_SLASH2_SIGNAL : ANIM_SLASH2_STARTSIGNAL)
			emit_sound(id, CHAN_WEAPON, WeaponSounds[5], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
			
			// Enable Janus-Form
			if(!Get_BitVar(g_JanusForm, id))
			{
				Set_BitVar(g_JanusForm, id)
				set_task(RESET_TIME, "Stop_JanusForm", id+TASK_RESET)
			}
		}	
		
		Janus9_Damage(id, 0)
	} 
	
	if(CurButton & IN_ATTACK2) 
	{
		CurButton &= ~IN_ATTACK2
		set_uc(uc_handle, UC_Buttons, CurButton)
		
		if(!Get_BitVar(g_JanusForm, id))
			return
			
		static Ent; Ent = fm_get_user_weapon_entity(id, CSW_JANUS9)
		if(!pev_valid(Ent)) return
	
		set_pdata_string(id, (492) * 4, ANIMEXT_B, -1 , 20)
			
		Set_BitVar(g_TempingAttack, id)
		ExecuteHamB(Ham_Weapon_PrimaryAttack, Ent)
		UnSet_BitVar(g_TempingAttack, id)	
			

		Set_Weapon_Idle(id, CSW_JANUS9, DELAY_TIME + 0.5)
		Set_Player_NextAttack(id, DELAY_TIME)
	
		if(random_num(0, 1))
		{
			Set_WeaponAnim(id, ANIM_STAB1)
			emit_sound(id, CHAN_WEAPON, WeaponSounds[6], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
		} else {
			Set_WeaponAnim(id, ANIM_STAB2)
			emit_sound(id, CHAN_WEAPON, WeaponSounds[7], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
		}
		
		Janus9_Damage(id, 1)
		
		UnSet_BitVar(g_JanusForm, id)
		remove_task(id+TASK_RESET)
	}
}

public Janus9_Damage(id, Special)
{
	static Float:Max_Distance, Float:Point[4][3], Float:TB_Distance, Float:Point_Dis
	
	if(!Special)
	{
		Point_Dis = RADIUS_A / 2.0
		Max_Distance = float(RADIUS_A)
		TB_Distance = Max_Distance / 4.0
	} else {
		Point_Dis = RADIUS_B / 1.5
		Max_Distance = float(RADIUS_B)
		TB_Distance = Max_Distance / 4.0
	}

	static Float:VicOrigin[3], Float:MyOrigin[3]
	pev(id, pev_origin, MyOrigin)
	
	for(new i = 0; i < 4; i++)
		get_position(id, TB_Distance * (i + 1), 0.0, 0.0, Point[i])
		
	static Have_Victim; Have_Victim = 0
	static ent
	ent = fm_get_user_weapon_entity(id, get_user_weapon(id))
		
	if(!pev_valid(ent))
		return 0
		
	for(new i = 0; i < get_maxplayers(); i++)
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
			
			if(!Special) ExecuteHamB(Ham_TakeDamage, i, "knife", id, float(DAMAGE_A), DMG_SLASH)
			else ExecuteHamB(Ham_TakeDamage, i, "knife", id, float(DAMAGE_B), DMG_SLASH)
		}
	}	
	
	if(Have_Victim)
	{
		emit_sound(id, CHAN_ITEM, WeaponSounds[random_num(2, 3)], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	} else {
		static Float:StartOrigin[3], Float:EndOrigin[3]
		get_position(id, 0.0, 0.0, 26.0, StartOrigin)
		get_position(id, Special ? float(RADIUS_B) : float(RADIUS_A), 0.0, 26.0, EndOrigin)
		
		if(is_wall_between_points(StartOrigin, EndOrigin, id)) emit_sound(id, CHAN_ITEM, WeaponSounds[random_num(8, 9)], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	}
	
	return 0	
}

public Stop_JanusForm(id)
{
	id -= TASK_RESET
	
	if(!is_player(id, 1))
		return
	if(!Get_BitVar(g_JanusForm, id))
		return
	// Remove Janus
	UnSet_BitVar(g_JanusForm, id)

	if(get_player_weapon(id) != CSW_JANUS9 || !Get_BitVar(g_Had_Janus9, id))
		return
		
	Set_WeaponAnim(id, ANIM_SIGNAL_END)
		
	Set_Weapon_Idle(id, CSW_JANUS9, 0.0)
	Set_Player_NextAttack(id, 0.0)
	
	PlaySound(id, WeaponSounds[1])
}

public fw_Item_Deploy_Post(Ent)
{
	if(pev_valid(Ent) != 2)
		return
	static Id; Id = get_pdata_cbase(Ent, 41, 4)
	if(get_pdata_cbase(Id, 373) != Ent)
		return
	if(!Get_BitVar(g_Had_Janus9, Id))
		return
		
	UnSet_BitVar(g_SlashType, Id)
	
	set_pev(Id, pev_viewmodel2, V_MODEL)
	set_pev(Id, pev_weaponmodel2, Get_BitVar(g_JanusForm, Id) ? P_MODEL_B : P_MODEL_A)
	
	set_pdata_string(Id, (492) * 4, Get_BitVar(g_JanusForm, Id) ? ANIMEXT_B : ANIMEXT_A, -1 , 20)
	Set_WeaponAnim(Id, Get_BitVar(g_JanusForm, Id) ? ANIM_DRAW_SIGNAL : ANIM_DRAW)
	
	PlaySound(Id, WeaponSounds[0])
}

public fw_Weapon_WeaponIdle_Post(Ent)
{
	if(pev_valid(Ent) != 2)
		return HAM_IGNORED
	static Id; Id = get_pdata_cbase(Ent, 41, 4)
	if(get_pdata_cbase(Id, 373) != Ent)
		return HAM_IGNORED
	if(!Get_BitVar(g_Had_Janus9, Id))
		return HAM_IGNORED
		
	if(get_pdata_float(Ent, 48, 4) <= 0.25) 
	{
		Set_WeaponAnim(Id, Get_BitVar(g_JanusForm, Id) ? ANIM_IDLE_B : ANIM_IDLE_A)
		set_pdata_float(Ent, 48, 20.0, 4)
	}
	
	return HAM_IGNORED
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
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang3076\\ f0\\ fs16 \n\\ par }
*/
