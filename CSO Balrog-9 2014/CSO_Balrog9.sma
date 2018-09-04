#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <cstrike>
#include <fun>

#define PLUGIN "[CSO] Balrog-XI (9)"
#define VERSION "1.0"
#define AUTHOR "Dias Pendragon"

#define CSW_BALROG9 CSW_KNIFE
#define weapon_balrog9 "weapon_knife"

#define ANIM_EXT "knife"

#define DAMAGE_A 45 // 250 for Zombie
#define DAMAGE_B 50 // 350 for Zombie
#define DAMAGE_EXP 200 // 250 for Zombie

#define RANGE_A 48.0
#define RANGE_B 64.0
#define RADIUS_B 100.0

#define TIME_NEXTATK_A1 0.5
#define TIME_NEXTATK_A2 0.3

#define V_MODEL "models/v_balrog9n.mdl"
#define P_MODEL "models/p_balrog9n.mdl"

new const WeaponSounds[12][] = 
{
	"weapons/balrog9_charge_attack2.wav",
	"weapons/balrog9_charge_finish1.wav",
	"weapons/balrog9_charge_start1.wav",
	"weapons/balrog9_draw.wav",
	"weapons/balrog9_hit1.wav",
	"weapons/balrog9_hit2.wav",
	"weapons/balrog9_slash1.wav",
	"weapons/balrog9_slash2.wav",
	"weapons/balrog9_slash3.wav",
	"weapons/balrog9_slash4.wav",
	"weapons/balrog9_slash5.wav",
	"weapons/skullaxe_hit_wall.wav"
}

new const Balrog_ExplosionSpr[] = "sprites/balrog5stack.spr"

enum
{
	ANIM_IDLE = 0,
	ANIM_SLASH_L1,
	ANIM_SLASH_R1,
	ANIM_SLASH_L2,
	ANIM_SLASH_R2,
	ANIM_SLASH_R3,
	ANIM_DRAW,
	ANIM_CHARGE_START,
	ANIM_CHARGE_FINISH,
	ANIM_CHARGE_IDLE1,
	ANIM_CHARGE_IDLE2,
	ANIM_CHARGE_ATTACK1,
	ANIM_CHARGE_ATTACK2
}

enum
{
	CHARGE_START = 0,
	CHARGE_CHARGING,
	CHARGE_END,
	CHARGE_IDLE
}

new g_Had_Balrog9, g_Player_AttackAnim[33], g_AttackCharge, g_Balrog9_ChargeStatus[33]
new g_Exp_SprId, g_MaxPlayers

// Safety
#define Get_BitVar(%1,%2) (%1 & (1 << (%2 & 31)))
#define Set_BitVar(%1,%2) %1 |= (1 << (%2 & 31))
#define UnSet_BitVar(%1,%2) %1 &= ~(1 << (%2 & 31))

new g_HamBot
new g_IsConnected, g_IsAlive, g_PlayerWeapon[33]

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	Register_SafetyFunc()
	
	register_forward(FM_UpdateClientData, "fw_UpdateClientData_Post", 1)
	register_forward(FM_CmdStart, "fw_CmdStart")
	register_forward(FM_EmitSound, "fw_EmitSound")
	register_forward(FM_TraceLine, "fw_TraceLine")
	register_forward(FM_TraceHull, "fw_TraceHull")		
	
	RegisterHam(Ham_TakeDamage, "player", "fw_Player_TakeDamage")
	
	RegisterHam(Ham_Item_Deploy, weapon_balrog9, "fw_Item_Deploy_Post", 1)	
	RegisterHam(Ham_Weapon_WeaponIdle, weapon_balrog9, "fw_Weapon_WeaponIdle_Post", 1)
	
	g_MaxPlayers = get_maxplayers()
	
	register_clcmd("say /get", "Get_Balrog9")
}

public plugin_precache()
{
	engfunc(EngFunc_PrecacheModel, V_MODEL)
	engfunc(EngFunc_PrecacheModel, P_MODEL)
	
	for(new i = 0; i < sizeof(WeaponSounds); i++)
		engfunc(EngFunc_PrecacheSound, WeaponSounds[i])
		
	g_Exp_SprId = engfunc(EngFunc_PrecacheModel, Balrog_ExplosionSpr)
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
	
	RegisterHamFromEntity(Ham_TakeDamage, id, "fw_Player_TakeDamage")
}

public client_disconnect(id)
{
	Safety_Disconnected(id)
}

public Get_Balrog9(id)
{
	if(!is_player(id, 1))
		return
	
	g_Player_AttackAnim[id] = 0
	g_Balrog9_ChargeStatus[id] = CHARGE_START
	
	UnSet_BitVar(g_AttackCharge, id)
	Set_BitVar(g_Had_Balrog9, id)
	
	give_item(id, weapon_balrog9)
	
	if(get_user_weapon(id) == CSW_BALROG9)
	{
		set_pev(id, pev_viewmodel2, V_MODEL)
		set_pev(id, pev_weaponmodel2, P_MODEL)	

		Set_WeaponAnim(id, ANIM_DRAW)
	} else {
		engclient_cmd(id, weapon_balrog9)
	}	
}

public fw_UpdateClientData_Post(id, sendweapons, cd_handle)
{
	if(!is_player(id, 1))
		return FMRES_IGNORED	
	if(get_player_weapon(id) == CSW_BALROG9 && Get_BitVar(g_Had_Balrog9, id))
	{
		switch(g_Balrog9_ChargeStatus[id])
		{
			case CHARGE_START..CHARGE_IDLE: set_cd(cd_handle, CD_flNextAttack, get_gametime() + 0.001) 
		}
		
	}
	
	return FMRES_HANDLED
}

public fw_CmdStart(id, uc_handle, seed)
{
	if(!is_player(id,1)) 
		return
	if(get_player_weapon(id) != CSW_BALROG9 || !Get_BitVar(g_Had_Balrog9, id))
		return
	
	static Ent; Ent = fm_get_user_weapon_entity(id, CSW_BALROG9)
	if(!pev_valid(Ent))
		return
	
	static CurButton; CurButton = get_uc(uc_handle, UC_Buttons)
	if(CurButton & IN_ATTACK2) 
	{
		if(get_pdata_float(id, 83, 5) > 0.0) 
			return
			
		CurButton &= ~IN_ATTACK2
		set_uc(uc_handle, UC_Buttons, CurButton)

		static Ent; Ent = fm_get_user_weapon_entity(id, CSW_BALROG9)
		if(!pev_valid(Ent)) return
		
		switch(g_Balrog9_ChargeStatus[id])
		{
			case CHARGE_START: 
			{
				g_Balrog9_ChargeStatus[id] = CHARGE_CHARGING
				
				Set_Weapon_Idle(id, CSW_BALROG9, 0.65)
				Set_Player_NextAttack(id, 0.65)
				
				Set_WeaponAnim(id, ANIM_CHARGE_START)
			}
			case CHARGE_CHARGING: 
			{
				g_Balrog9_ChargeStatus[id] = CHARGE_END
				
				Set_Weapon_Idle(id, CSW_BALROG9, 1.0)
				Set_Player_NextAttack(id, 1.0)
				
				Set_WeaponAnim(id, ANIM_CHARGE_IDLE1)
			}
			case CHARGE_END:
			{
				g_Balrog9_ChargeStatus[id] = CHARGE_IDLE
				
				Set_Weapon_Idle(id, CSW_BALROG9, 0.25)
				Set_Player_NextAttack(id, 0.25)
				
				static Float:Origin[3]
				pev(id, pev_origin, Origin)
				
				// Effect
				message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
				write_byte(TE_DLIGHT)
				engfunc(EngFunc_WriteCoord, Origin[0])
				engfunc(EngFunc_WriteCoord, Origin[1])
				engfunc(EngFunc_WriteCoord, Origin[2])
				write_byte(floatround(RADIUS_B) / 8) // radius
				write_byte(255) // r
				write_byte(0) // g
				write_byte(0) // b
				write_byte(100) // life <<<<<<<<
				write_byte(10) // decay rate
				message_end()
				
				Set_WeaponAnim(id, ANIM_CHARGE_FINISH)
			}
			case CHARGE_IDLE:
			{
				Set_WeaponAnim(id, ANIM_CHARGE_IDLE2)
				
				Set_Weapon_Idle(id, CSW_BALROG9, 0.25)
				Set_Player_NextAttack(id, 0.25)
			}
		}
	} else if(CurButton & IN_ATTACK) {
		if(get_pdata_float(id, 83, 5) > 0.0) 
			return
		
		CurButton &= ~IN_ATTACK
		set_uc(uc_handle, UC_Buttons, CurButton)
		
		static Ent; Ent = fm_get_user_weapon_entity(id, CSW_BALROG9)
		if(!pev_valid(Ent)) return
		
		g_Balrog9_ChargeStatus[id] = CHARGE_START
		
		UnSet_BitVar(g_AttackCharge, id)
		ExecuteHamB(Ham_Weapon_PrimaryAttack, Ent)
		
		if(g_Player_AttackAnim[id] > 5 || g_Player_AttackAnim[id] < 0)
			g_Player_AttackAnim[id] = 0
		
		switch(g_Player_AttackAnim[id])
		{
			case 0: Set_WeaponAnim(id, ANIM_SLASH_L1)
			case 1: Set_WeaponAnim(id, ANIM_SLASH_R1)
			case 2: Set_WeaponAnim(id, ANIM_SLASH_L2)
			case 3: Set_WeaponAnim(id, ANIM_SLASH_R2)
			case 4: Set_WeaponAnim(id, ANIM_SLASH_L2)
			case 5: Set_WeaponAnim(id, ANIM_SLASH_R3)
		}
		
		g_Player_AttackAnim[id]++
	} else {
		switch(g_Balrog9_ChargeStatus[id])
		{
			case CHARGE_CHARGING:
			{
				if(get_pdata_float(id, 83, 5) > 0.0) 
					return
				
				g_Balrog9_ChargeStatus[id] = CHARGE_START
				
				static Ent; Ent = fm_get_user_weapon_entity(id, CSW_BALROG9)
				if(!pev_valid(Ent)) return
				
				UnSet_BitVar(g_AttackCharge, id)
				ExecuteHamB(Ham_Weapon_PrimaryAttack, Ent)
				
				Set_Weapon_Idle(id, CSW_BALROG9, 1.5)
				Set_Player_NextAttack(id, 1.0)
			
				Set_WeaponAnim(id, ANIM_CHARGE_ATTACK1)
			}
			case CHARGE_IDLE:
			{
				if(get_pdata_float(id, 83, 5) > 0.0) 
					return
				
				g_Balrog9_ChargeStatus[id] = CHARGE_START
				
				static Ent; Ent = fm_get_user_weapon_entity(id, CSW_BALROG9)
				if(!pev_valid(Ent)) return
				
				Set_BitVar(g_AttackCharge, id)
				ExecuteHamB(Ham_Weapon_SecondaryAttack, Ent)
				Balrog_Explosion(id)
				
				Set_Weapon_Idle(id, CSW_BALROG9, 1.5)
				Set_Player_NextAttack(id, 1.0)
			
				Set_WeaponAnim(id, ANIM_CHARGE_ATTACK2)
			}
			case CHARGE_END:
			{
				g_Balrog9_ChargeStatus[id] = CHARGE_START
				
				static Ent; Ent = fm_get_user_weapon_entity(id, CSW_BALROG9)
				if(!pev_valid(Ent)) return
				
				UnSet_BitVar(g_AttackCharge, id)
				ExecuteHamB(Ham_Weapon_PrimaryAttack, Ent)
				
				Set_Weapon_Idle(id, CSW_BALROG9, 1.5)
				Set_Player_NextAttack(id, 1.0)
			
				Set_WeaponAnim(id, ANIM_CHARGE_ATTACK1)
			}
		}
	}
}

public Fake_Punch(id)
{
	static Float:Punch[3]
	
	Punch[0] = random_float(-1.0, -2.5)
	Punch[1] = random_float(0.25, -0.25)
	Punch[2] = 0.0

	set_pev(id, pev_punchangle, Punch)	
}

public fw_EmitSound(id, channel, const sample[], Float:volume, Float:attn, flags, pitch)
{
	if(!is_player(id, 0))
		return FMRES_IGNORED
	if(get_player_weapon(id) != CSW_BALROG9 || !Get_BitVar(g_Had_Balrog9, id))
		return FMRES_IGNORED
		
	if(sample[8] == 'k' && sample[9] == 'n' && sample[10] == 'i')
	{
		if(sample[14] == 's' && sample[15] == 'l' && sample[16] == 'a')
		{
			Set_Weapon_Idle(id, CSW_BALROG9, TIME_NEXTATK_A1 + 0.5)
			Set_Player_NextAttack(id, TIME_NEXTATK_A1)	
		
			return FMRES_IGNORED
		}
		if (sample[14] == 'h' && sample[15] == 'i' && sample[16] == 't')
		{
			Set_Weapon_Idle(id, CSW_BALROG9, TIME_NEXTATK_A2 + 0.5)
			Set_Player_NextAttack(id, TIME_NEXTATK_A2)	

			if (sample[17] == 'w') // wall
			{
				if(!Get_BitVar(g_AttackCharge, id)) 
				{
					emit_sound(id, channel, WeaponSounds[11], volume, attn, flags, pitch)
					Fake_Punch(id)
				}
				return FMRES_SUPERCEDE
			} else {
				static Sound
				switch(g_Player_AttackAnim[id])
				{
					case 0: Sound = 4
					case 1: Sound = 5
					case 2: Sound = 4
					case 3: Sound = 5
					case 4: Sound = 4
					case 5: Sound = 5
				}
				
				if(!Get_BitVar(g_AttackCharge, id)) 
				{
					emit_sound(id, channel, WeaponSounds[Sound], volume, attn, flags, pitch)
					Fake_Punch(id)
				}
				return FMRES_SUPERCEDE
			}
		}
		if (sample[14] == 's' && sample[15] == 't' && sample[16] == 'a')
			return FMRES_IGNORED
	}
	
	return FMRES_IGNORED
}

public fw_TraceLine(Float:vector_start[3], Float:vector_end[3], ignored_monster, id, handle)
{
	if(!is_player(id, 1))
		return FMRES_IGNORED	
	if(get_player_weapon(id) != CSW_BALROG9 || !Get_BitVar(g_Had_Balrog9, id))
		return FMRES_IGNORED
	
	static Float:vecStart[3], Float:vecEnd[3], Float:v_angle[3], Float:v_forward[3], Float:view_ofs[3], Float:fOrigin[3]
	
	pev(id, pev_origin, fOrigin)
	pev(id, pev_view_ofs, view_ofs)
	xs_vec_add(fOrigin, view_ofs, vecStart)
	pev(id, pev_v_angle, v_angle)
	
	engfunc(EngFunc_MakeVectors, v_angle)
	get_global_vector(GL_v_forward, v_forward)

	xs_vec_mul_scalar(v_forward, Get_BitVar(g_AttackCharge, id) ? RANGE_B : RANGE_A, v_forward)
	xs_vec_add(vecStart, v_forward, vecEnd)
	
	engfunc(EngFunc_TraceLine, vecStart, vecEnd, ignored_monster, id, handle)
	
	return FMRES_SUPERCEDE
}

public fw_TraceHull(Float:vector_start[3], Float:vector_end[3], ignored_monster, hull, id, handle)
{
	if(!is_player(id, 1))
		return FMRES_IGNORED	
	if(get_player_weapon(id) != CSW_BALROG9 || !Get_BitVar(g_Had_Balrog9, id))
		return FMRES_IGNORED
	
	static Float:vecStart[3], Float:vecEnd[3], Float:v_angle[3], Float:v_forward[3], Float:view_ofs[3], Float:fOrigin[3]
	
	pev(id, pev_origin, fOrigin)
	pev(id, pev_view_ofs, view_ofs)
	xs_vec_add(fOrigin, view_ofs, vecStart)
	pev(id, pev_v_angle, v_angle)
	
	engfunc(EngFunc_MakeVectors, v_angle)
	get_global_vector(GL_v_forward, v_forward)
	
	xs_vec_mul_scalar(v_forward, Get_BitVar(g_AttackCharge, id) ? RANGE_B : RANGE_A, v_forward)
	xs_vec_add(vecStart, v_forward, vecEnd)
	
	engfunc(EngFunc_TraceHull, vecStart, vecEnd, ignored_monster, hull, id, handle)
	
	return FMRES_SUPERCEDE
}

public fw_Player_TakeDamage(Victim, Inflictor, Attacker, Float:Damage, DamageBits)
{
	if(!is_player(Victim, 0) || !is_player(Attacker, 0))
		return HAM_IGNORED
	if(get_player_weapon(Attacker) != CSW_BALROG9 || !Get_BitVar(g_Had_Balrog9, Attacker))
		return HAM_IGNORED
	if(Damage == float(DAMAGE_EXP))
		return HAM_IGNORED

	if(Get_BitVar(g_AttackCharge, Attacker)) SetHamParamFloat(4, float(DAMAGE_B))
	else SetHamParamFloat(4, float(DAMAGE_A))
	
	return HAM_HANDLED
}

public Balrog_Explosion(Attacker)
{
	static Float:ExpOrigin[3]
	get_position(Attacker, 48.0, 0.0, 0.0, ExpOrigin)
	
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_EXPLOSION)
	engfunc(EngFunc_WriteCoord, ExpOrigin[0])
	engfunc(EngFunc_WriteCoord, ExpOrigin[1])
	engfunc(EngFunc_WriteCoord, ExpOrigin[2])
	write_short(g_Exp_SprId)
	write_byte(10)
	write_byte(20)
	write_byte(4) 
	message_end()
	
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_DLIGHT)
	engfunc(EngFunc_WriteCoord, ExpOrigin[0])
	engfunc(EngFunc_WriteCoord, ExpOrigin[1])
	engfunc(EngFunc_WriteCoord, ExpOrigin[2])
	write_byte(floatround(RADIUS_B) / 6) // radius
	write_byte(255) // r
	write_byte(0) // g
	write_byte(0) // b
	write_byte(100) // life <<<<<<<<
	write_byte(10) // decay rate
	message_end()
	
	emit_sound(Attacker, CHAN_WEAPON, WeaponSounds[0], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	
	for(new i = 0; i < g_MaxPlayers; i++)
	{
		if(!is_player(i, 1))
			continue
		if(cs_get_user_team(Attacker) == cs_get_user_team(i))
			continue
		if(entity_range(Attacker, i) > RADIUS_B)
			continue

		ExecuteHamB(Ham_TakeDamage, i, 0, Attacker, float(DAMAGE_EXP), DMG_BLAST)
	}
}

public fw_Item_Deploy_Post(Ent)
{
	if(pev_valid(Ent) != 2)
		return
	static Id; Id = get_pdata_cbase(Ent, 41, 4)
	if(get_pdata_cbase(Id, 373) != Ent)
		return
	if(!Get_BitVar(g_Had_Balrog9, Id))
		return
		
	set_pev(Id, pev_viewmodel2, V_MODEL)
	set_pev(Id, pev_weaponmodel2, P_MODEL)
	
	set_pdata_string(Id, (492) * 4, ANIM_EXT, -1 , 20)
	Set_WeaponAnim(Id, ANIM_DRAW)
	
	g_Balrog9_ChargeStatus[Id] = CHARGE_START
	UnSet_BitVar(g_AttackCharge, Id)
}

public fw_Weapon_WeaponIdle_Post(Ent)
{
	if(pev_valid(Ent) != 2)
		return HAM_IGNORED
	static Id; Id = get_pdata_cbase(Ent, 41, 4)
	if(get_pdata_cbase(Id, 373) != Ent)
		return HAM_IGNORED
	if(!Get_BitVar(g_Had_Balrog9, Id))
		return HAM_IGNORED
		
	if(get_pdata_float(Ent, 48, 4) <= 0.25) 
	{
		Set_WeaponAnim(Id, ANIM_IDLE)
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