#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <cstrike>
#include <xs>

#define PLUGIN "[CSO] LightSaber"
#define VERSION "1.0"
#define AUTHOR "Dias Leon"

/* ===============================
------------ Configs -------------
=================================*/
#define DAMAGE_LIGHTSABER 62
#define DAMAGE_ATTACK 31

#define RADIUS_ON 96
#define RADIUS_OFF 72

#define DRAW_TIME 0.75
#define TURN_TIME 0.5
#define RESET_TIME 1.5

#define ANIMEXT1 "onehanded"
#define ANIMEXT2 "knife"

#define V_MODEL "models/v_sfsword.mdl"
#define P_MODEL_ON "models/p_sfsword_on.mdl"
#define P_MODEL_OFF "models/p_sfsword_off.mdl"

new const LightSaber_Sounds[14][] =
{
	"weapons/sfsword_draw.wav",
	"weapons/sfsword_hit1.wav",
	"weapons/sfsword_hit2.wav",
	"weapons/sfsword_idle.wav",
	"weapons/sfsword_midslash1.wav",
	"weapons/sfsword_midslash2.wav",
	"weapons/sfsword_midslash3.wav",
	"weapons/sfsword_off.wav",
	"weapons/sfsword_off_hit.wav",
	"weapons/sfsword_off_slash1.wav",
	"weapons/sfsword_on.wav", // 10
	"weapons/sfsword_stab.wav",
	"weapons/sfsword_wall1.wav",
	"weapons/sfsword_wall2.wav"
}

enum
{
	LS_ANIM_IDLE_ON = 0,
	LS_ANIM_ON,
	LS_ANIM_OFF,
	LS_ANIM_DRAW,
	LS_ANIM_STAB,
	LS_ANIM_STAB_MISS,
	LS_ANIM_MIDSLASH1,
	LS_ANIM_MIDSLASH2,
	LS_ANIM_MIDSLASH3,
	LS_ANIM_IDLE_OFF,
	LS_ANIM_SLASH_OFF
}

/* ===============================
--------- End of Config ----------
=================================*/

#define CSW_LIGHTSABER CSW_KNIFE
#define weapon_lightsaber "weapon_knife"

#define TASK_TURN 4234234
#define TASK_SLASH 6948638
#define TASK_RESET 54893534

// MACROS
#define Get_BitVar(%1,%2) (%1 & (1 << (%2 & 31)))
#define Set_BitVar(%1,%2) %1 |= (1 << (%2 & 31))
#define UnSet_BitVar(%1,%2) %1 &= ~(1 << (%2 & 31))

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
new g_Had_LightSaber, g_IsOnMode, g_TempingAttack, g_InSpecialAttack
new g_OldWeapon[33], g_WillBeHit[33], g_AttackingMode[33]
new g_MaxPlayers, g_Ham_Bot

public plugin_init() 
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	register_event("CurWeapon", "Event_CurWeapon", "be", "1=1")
	
	register_forward(FM_CmdStart, "fw_CmdStart")
	register_forward(FM_EmitSound, "fw_EmitSound")
	register_forward(FM_TraceLine, "fw_TraceLine")
	register_forward(FM_TraceHull, "fw_TraceHull")			
	
	RegisterHam(Ham_TraceAttack, "player", "fw_TraceAttack")
	RegisterHam(Ham_Weapon_WeaponIdle, weapon_lightsaber, "fw_Weapon_WeaponIdle_Post", 1)
	g_MaxPlayers = get_maxplayers()
	
	register_clcmd("admin_get_lightsaber", "Get_LightSaber", ADMIN_BAN)
}

public plugin_precache()
{
	engfunc(EngFunc_PrecacheModel, V_MODEL)
	engfunc(EngFunc_PrecacheModel, P_MODEL_ON)
	engfunc(EngFunc_PrecacheModel, P_MODEL_OFF)
	
	for(new i = 0; i < sizeof(LightSaber_Sounds); i++)
		engfunc(EngFunc_PrecacheSound, LightSaber_Sounds[i])
}

public client_putinserver(id)
{
	Remove_LightSaber(id)

	if(!g_Ham_Bot && is_user_bot(id))
	{
		g_Ham_Bot = 1
		set_task(0.1, "Do_RegisterHam_Bot", id)
	}
}

public Do_RegisterHam_Bot(id)
{
	RegisterHamFromEntity(Ham_TraceAttack, id, "fw_TraceAttack")
}

public Get_LightSaber(id)
{
	if(!is_user_alive(id))
		return
		
	Set_BitVar(g_Had_LightSaber, id)
	Set_BitVar(g_IsOnMode, id)
	UnSet_BitVar(g_TempingAttack, id)
	UnSet_BitVar(g_InSpecialAttack, id)
	g_WillBeHit[id] = HIT_NOTHING
	g_AttackingMode[id] = 0
	
	remove_task(id+TASK_TURN)
	remove_task(id+TASK_SLASH)
	remove_task(id+TASK_RESET)
	
	fm_give_item(id, weapon_lightsaber)
	if(get_user_weapon(id) == CSW_LIGHTSABER)
	{
		set_pev(id, pev_viewmodel2, V_MODEL)
		set_pev(id, pev_weaponmodel2, Get_BitVar(g_IsOnMode, id) ? P_MODEL_ON : P_MODEL_OFF)	

		set_player_nextattack(id, DRAW_TIME)
		set_weapons_timeidle(id, CSW_LIGHTSABER, DRAW_TIME + 0.5)
		
		set_weapon_anim(id, LS_ANIM_DRAW)
	} else {
		engclient_cmd(id, weapon_lightsaber)
	}
}

public Remove_LightSaber(id)
{
	UnSet_BitVar(g_Had_LightSaber, id)
	UnSet_BitVar(g_IsOnMode, id)
	UnSet_BitVar(g_TempingAttack, id)
	UnSet_BitVar(g_InSpecialAttack, id)
	g_WillBeHit[id] = HIT_NOTHING
	g_AttackingMode[id] = 0
	
	remove_task(id+TASK_TURN)
	remove_task(id+TASK_SLASH)
	remove_task(id+TASK_RESET)
}

public Event_CurWeapon(id)
{
	if(!is_user_alive(id))
		return
	static CSWID; CSWID = read_data(2)
	
	if((CSWID == CSW_LIGHTSABER && g_OldWeapon[id] != CSW_LIGHTSABER) && Get_BitVar(g_Had_LightSaber, id))
	{
		set_pev(id, pev_viewmodel2, V_MODEL)
		set_pev(id, pev_weaponmodel2, Get_BitVar(g_IsOnMode, id) ? P_MODEL_ON : P_MODEL_OFF)
		
		set_player_nextattack(id, DRAW_TIME)
		set_weapons_timeidle(id, CSW_LIGHTSABER, DRAW_TIME + 0.5)
		
		set_weapon_anim(id, LS_ANIM_DRAW)
		set_pdata_string(id, (492) * 4, ANIMEXT1, -1 , 20)
	} else if(CSWID != CSW_LIGHTSABER && g_OldWeapon[id] == CSW_LIGHTSABER) {
		g_AttackingMode[id] = 0
		
		Set_BitVar(g_IsOnMode, id)
		UnSet_BitVar(g_InSpecialAttack, id)
		
		remove_task(id+TASK_TURN)
	}
	
	g_OldWeapon[id] = CSWID
}

public fw_EmitSound(id, channel, const sample[], Float:volume, Float:attn, flags, pitch)
{
	if(!is_user_connected(id))
		return FMRES_IGNORED
	if(get_user_weapon(id) != CSW_LIGHTSABER || !Get_BitVar(g_Had_LightSaber, id))
		return FMRES_IGNORED
		
	if(sample[8] == 'k' && sample[9] == 'n' && sample[10] == 'i')
	{
		if(sample[14] == 's' && sample[15] == 'l' && sample[16] == 'a')
		{
			g_WillBeHit[id] = HIT_NOTHING
			return FMRES_SUPERCEDE
		}
		if (sample[14] == 'h' && sample[15] == 'i' && sample[16] == 't')
		{
			if (sample[17] == 'w') // wall
			{
				g_WillBeHit[id] = HIT_WALL
				return FMRES_SUPERCEDE
			} else {
				g_WillBeHit[id] = HIT_ENEMY
				return FMRES_SUPERCEDE
			}
		}
		if (sample[14] == 's' && sample[15] == 't' && sample[16] == 'a')
			return FMRES_SUPERCEDE;
	}
	
	return FMRES_IGNORED
}

public fw_CmdStart(id, uc_handle, seed)
{
	if(!is_user_alive(id)) 
		return
	if(get_user_weapon(id) != CSW_LIGHTSABER || !Get_BitVar(g_Had_LightSaber, id))
		return
	
	static ent; ent = fm_get_user_weapon_entity(id, CSW_LIGHTSABER)
	if(!pev_valid(ent))
		return
	if(get_pdata_float(id, 83, 5) > 0.0) 
		return
	
	static CurButton; CurButton = get_uc(uc_handle, UC_Buttons)
	if(CurButton & IN_ATTACK)
	{
		CurButton &= ~IN_ATTACK
		set_uc(uc_handle, UC_Buttons, CurButton)
		
		if(Get_BitVar(g_IsOnMode, id))
		{
			if(!Get_BitVar(g_InSpecialAttack, id))
			{
				if(g_AttackingMode[id] == 0) g_AttackingMode[id] = 1
				
				g_AttackingMode[id]++
				if(g_AttackingMode[id] > ATTACK_SLASH3) g_AttackingMode[id] = 1
				
				set_pdata_string(id, (492) * 4, ANIMEXT2, -1 , 20)
					
				Set_BitVar(g_TempingAttack, id)
				ExecuteHamB(Ham_Weapon_PrimaryAttack, ent)
				UnSet_BitVar(g_TempingAttack, id)
				
				set_weapons_timeidle(id, CSW_LIGHTSABER, 1.0)
				set_player_nextattack(id, 1.0)
				
				if(g_AttackingMode[id] == 1) set_weapon_anim(id, LS_ANIM_MIDSLASH1)
				else if(g_AttackingMode[id] == 2) set_weapon_anim(id, LS_ANIM_MIDSLASH2)
				else if(g_AttackingMode[id] == 3) set_weapon_anim(id, LS_ANIM_MIDSLASH3)
				
				set_task(0.25, "Damage_Slash", id+TASK_SLASH)
				set_task(RESET_TIME, "Reset_Anim", id+TASK_RESET)
				Set_BitVar(g_InSpecialAttack, id)
			} else {
				set_pdata_string(id, (492) * 4, ANIMEXT2, -1 , 20)
					
				Set_BitVar(g_TempingAttack, id)
				ExecuteHamB(Ham_Weapon_PrimaryAttack, ent)
				UnSet_BitVar(g_TempingAttack, id)
				
				set_weapons_timeidle(id, CSW_LIGHTSABER, 1.0)
				set_player_nextattack(id, 1.0)
				
				set_weapon_anim(id, LS_ANIM_STAB)
				
				set_task(0.25, "Damage_Stab", id+TASK_SLASH)
				set_task(0.5, "Damage_Stab", id+TASK_SLASH)
				set_task(RESET_TIME, "Reset_Anim", id+TASK_RESET)
				UnSet_BitVar(g_InSpecialAttack, id)
			}
		} else {
			set_pdata_string(id, (492) * 4, ANIMEXT2, -1 , 20)
					
			Set_BitVar(g_TempingAttack, id)
			ExecuteHamB(Ham_Weapon_PrimaryAttack, ent)
			UnSet_BitVar(g_TempingAttack, id)
			
			set_weapons_timeidle(id, CSW_LIGHTSABER, 1.0)
			set_player_nextattack(id, 1.0)
			
			set_weapon_anim(id, LS_ANIM_SLASH_OFF)
			set_task(0.25, "Damage_OffStab", id+TASK_SLASH)
			set_task(RESET_TIME, "Reset_Anim", id+TASK_RESET)
			
			UnSet_BitVar(g_InSpecialAttack, id)
		}
	} else if(CurButton & IN_ATTACK2) {
		CurButton &= ~IN_ATTACK2
		set_uc(uc_handle, UC_Buttons, CurButton)
		
		set_weapon_anim(id, !Get_BitVar(g_IsOnMode, id) ? LS_ANIM_ON : LS_ANIM_OFF)
		
		set_player_nextattack(id, TURN_TIME)
		set_weapons_timeidle(id, CSW_LIGHTSABER, TURN_TIME)
		
		set_task(TURN_TIME - 0.1, "Turn_Complete", id+TASK_TURN)
	}
}

public Turn_Complete(id)
{
	id -= TASK_TURN
	if(!is_user_alive(id)) 
		return
	if(get_user_weapon(id) != CSW_LIGHTSABER || !Get_BitVar(g_Had_LightSaber, id))
		return
		
	if(Get_BitVar(g_IsOnMode, id)) UnSet_BitVar(g_IsOnMode, id)
	else Set_BitVar(g_IsOnMode, id)	
	
	set_pev(id, pev_weaponmodel2, Get_BitVar(g_IsOnMode, id) ? P_MODEL_ON : P_MODEL_OFF)
	set_pdata_string(id, (492) * 4, Get_BitVar(g_IsOnMode, id) ? ANIMEXT1 : ANIMEXT2, -1 , 20)
}

public Reset_Anim(id)
{
	id -= TASK_RESET
	if(!is_user_alive(id)) 
		return
	if(get_user_weapon(id) != CSW_LIGHTSABER || !Get_BitVar(g_Had_LightSaber, id))
		return
		
	set_pdata_string(id, (492) * 4, Get_BitVar(g_IsOnMode, id) ? ANIMEXT1 : ANIMEXT2, -1 , 20)
}

public Damage_Slash(id)
{
	id -= TASK_SLASH
	if(!is_user_alive(id)) 
		return
	if(get_user_weapon(id) != CSW_LIGHTSABER || !Get_BitVar(g_Had_LightSaber, id))
		return
		
	static Target; Target = CheckAttack(id, float(RADIUS_ON), 48.0, float(DAMAGE_LIGHTSABER))
	if(Target) emit_sound(id, CHAN_WEAPON, LightSaber_Sounds[random_num(1, 2)], 1.0, ATTN_NORM, 0, PITCH_NORM)
	else if(g_WillBeHit[id] == HIT_WALL) emit_sound(id, CHAN_WEAPON, LightSaber_Sounds[random_num(12, 13)], 1.0, ATTN_NORM, 0, PITCH_NORM)
}

public Damage_Stab(id)
{
	id -= TASK_SLASH
	if(!is_user_alive(id)) 
		return
	if(get_user_weapon(id) != CSW_LIGHTSABER || !Get_BitVar(g_Had_LightSaber, id))
		return
		
	static Target; Target = CheckAttack(id, float(RADIUS_ON), 48.0, float(DAMAGE_LIGHTSABER))
	if(Target) emit_sound(id, CHAN_WEAPON, LightSaber_Sounds[random_num(1, 2)], 1.0, ATTN_NORM, 0, PITCH_NORM)
	else if(g_WillBeHit[id] == HIT_WALL) emit_sound(id, CHAN_WEAPON, LightSaber_Sounds[random_num(12, 13)], 1.0, ATTN_NORM, 0, PITCH_NORM)
}

public Damage_OffStab(id)
{
	id -= TASK_SLASH
	if(!is_user_alive(id)) 
		return
	if(get_user_weapon(id) != CSW_LIGHTSABER || !Get_BitVar(g_Had_LightSaber, id))
		return
		
	static Ent; Ent = fm_get_user_weapon_entity(id, get_user_weapon(id))
	if(!pev_valid(Ent)) Ent = 0
	
	static Target; Target = CheckAttack(id, float(RADIUS_OFF), 24.0, float(DAMAGE_ATTACK))
	if(Target) emit_sound(id, CHAN_WEAPON, LightSaber_Sounds[8], 1.0, ATTN_NORM, 0, PITCH_NORM)
}

public CheckAttack(id, Float:Radius, Float:PointDis, Float:Damage)
{
	static Float:Max_Distance, Float:Point[4][3], Float:TB_Distance, Float:Point_Dis
	
	Point_Dis = PointDis
	Max_Distance = Radius
	TB_Distance = Max_Distance / 4.0
	
	static Float:VicOrigin[3], Float:MyOrigin[3]
	pev(id, pev_origin, MyOrigin)
	
	for(new i = 0; i < 4; i++) get_position(id, TB_Distance * (i + 1), 0.0, 0.0, Point[i])
		
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
			do_attack(id, i, ent, Damage)
		}
	}	
	
	if(Have_Victim) return 1
	return 0
}	

public fw_TraceLine(Float:vector_start[3], Float:vector_end[3], ignored_monster, id, handle)
{
	if(!is_user_alive(id))
		return FMRES_IGNORED	
	if(get_user_weapon(id) != CSW_LIGHTSABER || !Get_BitVar(g_Had_LightSaber, id))
		return FMRES_IGNORED
	
	static Float:vecStart[3], Float:vecEnd[3], Float:v_angle[3], Float:v_forward[3], Float:view_ofs[3], Float:fOrigin[3]
	
	pev(id, pev_origin, fOrigin)
	pev(id, pev_view_ofs, view_ofs)
	xs_vec_add(fOrigin, view_ofs, vecStart)
	pev(id, pev_v_angle, v_angle)
	
	engfunc(EngFunc_MakeVectors, v_angle)
	get_global_vector(GL_v_forward, v_forward)

	if(Get_BitVar(g_TempingAttack, id)) xs_vec_mul_scalar(v_forward, (Get_BitVar(g_IsOnMode, id) ? float(RADIUS_ON) : float(RADIUS_OFF)), v_forward)
	else xs_vec_mul_scalar(v_forward, 0.0, v_forward)
	xs_vec_add(vecStart, v_forward, vecEnd)
	
	engfunc(EngFunc_TraceLine, vecStart, vecEnd, ignored_monster, id, handle)
	
	return FMRES_SUPERCEDE
}

public fw_TraceHull(Float:vector_start[3], Float:vector_end[3], ignored_monster, hull, id, handle)
{
	if(!is_user_alive(id))
		return FMRES_IGNORED	
	if(get_user_weapon(id) != CSW_LIGHTSABER || !Get_BitVar(g_Had_LightSaber, id))
		return FMRES_IGNORED
	
	static Float:vecStart[3], Float:vecEnd[3], Float:v_angle[3], Float:v_forward[3], Float:view_ofs[3], Float:fOrigin[3]
	
	pev(id, pev_origin, fOrigin)
	pev(id, pev_view_ofs, view_ofs)
	xs_vec_add(fOrigin, view_ofs, vecStart)
	pev(id, pev_v_angle, v_angle)
	
	engfunc(EngFunc_MakeVectors, v_angle)
	get_global_vector(GL_v_forward, v_forward)
	
	if(Get_BitVar(g_TempingAttack, id)) xs_vec_mul_scalar(v_forward, (Get_BitVar(g_IsOnMode, id) ? float(RADIUS_ON) : float(RADIUS_OFF)), v_forward)
	else xs_vec_mul_scalar(v_forward, 0.0, v_forward)
	xs_vec_add(vecStart, v_forward, vecEnd)
	
	engfunc(EngFunc_TraceHull, vecStart, vecEnd, ignored_monster, hull, id, handle)
	
	return FMRES_SUPERCEDE
}

public fw_TraceAttack(Victim, Attacker, Float:Damage, Float:Direction[3], TraceResult, DamageBits) 
{
	if(!is_user_alive(Attacker))	
		return HAM_IGNORED
	if(!Get_BitVar(g_Had_LightSaber, Attacker) || !Get_BitVar(g_TempingAttack, Attacker))
		return HAM_IGNORED
		
	return HAM_SUPERCEDE
}

public fw_Weapon_WeaponIdle_Post(ent)
{
	static id; id = pev(ent, pev_owner)
	if(!is_user_alive(id))
		return HAM_IGNORED
	if(!Get_BitVar(g_Had_LightSaber, id))
		return HAM_IGNORED
		
	if(get_pdata_float(ent, 48, 4) <= 0.25) 
	{
		set_weapon_anim(id, Get_BitVar(g_IsOnMode, id) ? LS_ANIM_IDLE_ON : LS_ANIM_IDLE_OFF)
		set_pdata_float(ent, 48, 20.0, 4)
	}
	
	return HAM_IGNORED
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

do_attack(Attacker, Victim, Inflictor, Float:fDamage)
{
	fake_player_trace_attack(Attacker, Victim, fDamage)
	fake_take_damage(Attacker, Victim, fDamage, Inflictor)
}

fake_player_trace_attack(iAttacker, iVictim, &Float:fDamage)
{
	// get fDirection
	static Float:fAngles[3], Float:fDirection[3]
	pev(iAttacker, pev_angles, fAngles)
	angle_vector(fAngles, ANGLEVECTOR_FORWARD, fDirection)
	
	// get fStart
	static Float:fStart[3], Float:fViewOfs[3]
	pev(iAttacker, pev_origin, fStart)
	pev(iAttacker, pev_view_ofs, fViewOfs)
	xs_vec_add(fViewOfs, fStart, fStart)
	
	// get aimOrigin
	static iAimOrigin[3], Float:fAimOrigin[3]
	get_user_origin(iAttacker, iAimOrigin, 3)
	IVecFVec(iAimOrigin, fAimOrigin)
	
	// TraceLine from fStart to AimOrigin
	static ptr; ptr = create_tr2() 
	engfunc(EngFunc_TraceLine, fStart, fAimOrigin, DONT_IGNORE_MONSTERS, iAttacker, ptr)
	static pHit; pHit = get_tr2(ptr, TR_pHit)
	static iHitgroup; iHitgroup = get_tr2(ptr, TR_iHitgroup)
	static Float:fEndPos[3]; get_tr2(ptr, TR_vecEndPos, fEndPos)

	// get target & body at aiming
	static iTarget, iBody
	get_user_aiming(iAttacker, iTarget, iBody)
	
	// if aiming find target is iVictim then update iHitgroup
	if (iTarget == iVictim)
	{
		iHitgroup = iBody
	}
	
	// if ptr find target not is iVictim
	else if (pHit != iVictim)
	{
		// get AimOrigin in iVictim
		static Float:fVicOrigin[3], Float:fVicViewOfs[3], Float:fAimInVictim[3]
		pev(iVictim, pev_origin, fVicOrigin)
		pev(iVictim, pev_view_ofs, fVicViewOfs) 
		xs_vec_add(fVicViewOfs, fVicOrigin, fAimInVictim)
		fAimInVictim[2] = fStart[2]
		fAimInVictim[2] += get_distance_f(fStart, fAimInVictim) * floattan( fAngles[0] * 2.0, degrees )
		
		// check aim in size of iVictim
		static iAngleToVictim; iAngleToVictim = get_angle_to_target(iAttacker, fVicOrigin)
		iAngleToVictim = abs(iAngleToVictim)
		static Float:fDis; fDis = 2.0 * get_distance_f(fStart, fAimInVictim) * floatsin( float(iAngleToVictim) * 0.5, degrees )
		static Float:fVicSize[3]
		pev(iVictim, pev_size , fVicSize)
		if ( fDis <= fVicSize[0] * 0.5 )
		{
			// TraceLine from fStart to aimOrigin in iVictim
			static ptr2; ptr2 = create_tr2() 
			engfunc(EngFunc_TraceLine, fStart, fAimInVictim, DONT_IGNORE_MONSTERS, iAttacker, ptr2)
			static pHit2; pHit2 = get_tr2(ptr2, TR_pHit)
			static iHitgroup2; iHitgroup2 = get_tr2(ptr2, TR_iHitgroup)
			
			// if ptr2 find target is iVictim
			if ( pHit2 == iVictim && (iHitgroup2 != HIT_HEAD || fDis <= fVicSize[0] * 0.25) )
			{
				pHit = iVictim
				iHitgroup = iHitgroup2
				get_tr2(ptr2, TR_vecEndPos, fEndPos)
			}
			
			free_tr2(ptr2)
		}
		
		// if pHit still not is iVictim then set default HitGroup
		if (pHit != iVictim)
		{
			// set default iHitgroup
			iHitgroup = HIT_GENERIC
			
			static ptr3; ptr3 = create_tr2() 
			engfunc(EngFunc_TraceLine, fStart, fVicOrigin, DONT_IGNORE_MONSTERS, iAttacker, ptr3)
			get_tr2(ptr3, TR_vecEndPos, fEndPos)
			
			// free ptr3
			free_tr2(ptr3)
		}
	}
	
	// set new Hit & Hitgroup & EndPos
	set_tr2(ptr, TR_pHit, iVictim)
	set_tr2(ptr, TR_iHitgroup, iHitgroup)
	set_tr2(ptr, TR_vecEndPos, fEndPos)

	// hitgroup multi fDamage
	static Float:fMultifDamage 
	switch(iHitgroup)
	{
		case HIT_HEAD: fMultifDamage  = 4.0
		case HIT_STOMACH: fMultifDamage  = 1.25
		case HIT_LEFTLEG: fMultifDamage  = 0.75
		case HIT_RIGHTLEG: fMultifDamage  = 0.75
		default: fMultifDamage  = 1.0
	}
	
	fDamage *= fMultifDamage
	
	// ExecuteHam
	fake_trake_attack(iAttacker, iVictim, fDamage, fDirection, ptr)
	
	// free ptr
	free_tr2(ptr)
}

stock fake_trake_attack(iAttacker, iVictim, Float:fDamage, Float:fDirection[3], iTraceHandle, iDamageBit = (DMG_NEVERGIB | DMG_BULLET))
{
	ExecuteHamB(Ham_TraceAttack, iVictim, iAttacker, fDamage, fDirection, iTraceHandle, iDamageBit)
}

stock fake_take_damage(iAttacker, iVictim, Float:fDamage, iInflictor = 0, iDamageBit = (DMG_NEVERGIB | DMG_BULLET))
{
	ExecuteHamB(Ham_TakeDamage, iVictim, iInflictor, iAttacker, fDamage, iDamageBit)
}

stock get_angle_to_target(id, const Float:fTarget[3], Float:TargetSize = 0.0)
{
	static Float:fOrigin[3], iAimOrigin[3], Float:fAimOrigin[3], Float:fV1[3]
	pev(id, pev_origin, fOrigin)
	get_user_origin(id, iAimOrigin, 3) // end position from eyes
	IVecFVec(iAimOrigin, fAimOrigin)
	xs_vec_sub(fAimOrigin, fOrigin, fV1)
	
	static Float:fV2[3]
	xs_vec_sub(fTarget, fOrigin, fV2)
	
	static iResult; iResult = get_angle_between_vectors(fV1, fV2)
	
	if (TargetSize > 0.0)
	{
		static Float:fTan; fTan = TargetSize / get_distance_f(fOrigin, fTarget)
		static fAngleToTargetSize; fAngleToTargetSize = floatround( floatatan(fTan, degrees) )
		iResult -= (iResult > 0) ? fAngleToTargetSize : -fAngleToTargetSize
	}
	
	return iResult
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

stock set_weapons_timeidle(id, WeaponId ,Float:TimeIdle)
{
	static entwpn; entwpn = fm_get_user_weapon_entity(id, WeaponId)
	if(!pev_valid(entwpn)) 
		return
		
	set_pdata_float(entwpn, 46, TimeIdle, 4)
	set_pdata_float(entwpn, 47, TimeIdle, 4)
	set_pdata_float(entwpn, 48, TimeIdle + 0.5, 4)
}

stock set_weapon_anim(id, anim)
{
	set_pev(id, pev_weaponanim, anim)
	
	message_begin(MSG_ONE_UNRELIABLE, SVC_WEAPONANIM, _, id)
	write_byte(anim)
	write_byte(0)
	message_end()	
}

stock set_player_nextattack(id, Float:NextTime) set_pdata_float(id, 83, NextTime, 5)
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang1033\\ f0\\ fs16 \n\\ par }
*/
