#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <cstrike>
#include <fun>

#define PLUGIN "[CSO] Papin (2015)"
#define VERSION "1.0"
#define AUTHOR "Dias Pendragon"

#define DAMAGE_A 60 // 240 for Zombie
#define DAMAGE_B 180 // 480 for Zombie

#define SLASH_RADIUS 72.0
#define PUNCH_RADIUS 86.0

#define SLASH_NEXTATK 0.7
#define SLASH_NEXTATK_HIT 0.35

#define PUNCH_NEXTATK 1.0

#define MODEL_V "models/v_spknife.mdl"
#define MODEL_P "models/p_spknife.mdl"

new const Papin_Sounds[12][] = 
{
	"weapons/spknife_draw.wav", // 0
	"weapons/spknife_hit1.wav",
	"weapons/spknife_hit2.wav",
	"weapons/spknife_hitwall.wav",
	"weapons/spknife_idlea.wav",
	"weapons/spknife_slasha1_1.wav", // 5
	"weapons/spknife_slasha1_2.wav",
	"weapons/spknife_slasha2_1.wav",
	"weapons/spknife_slasha2_2.wav",
	"weapons/spknife_slashb3_1.wav",
	"weapons/spknife_slashb3_2.wav", // 10
	"weapons/spknife_steam.wav"
}

enum
{
	ANIM_IDLE_A = 0,
	ANIM_IDLE_B,
	ANIM_SLASH_A1_1,
	ANIM_SLASH_A1_2,
	ANIM_SLASH_B1_1,
	ANIM_SLASH_B1_2,
	ANIM_SLASH_A2_1,
	ANIM_SLASH_A2_2,
	ANIM_SLASH_B2_1,
	ANIM_SLASH_B2_2,
	ANIM_SLASH_B3_1,
	ANIM_SLASH_B3_2,
	ANIM_DRAW_A,
	ANIM_DRAW_B,
	ANIM_SLASH_A3_1,
	ANIM_SLASH_A3_2
}

#define CSW_PAPIN CSW_KNIFE
#define weapon_papin "weapon_knife"

enum
{
	HIT_NOTHING = 0,
	HIT_ENEMY,
	HIT_WALL
}

// MACROS
#define Get_BitVar(%1,%2) (%1 & (1 << (%2 & 31)))
#define Set_BitVar(%1,%2) %1 |= (1 << (%2 & 31))
#define UnSet_BitVar(%1,%2) %1 &= ~(1 << (%2 & 31))

new g_Had_Papin, g_PapinCharged, g_TempingAttack, g_SwitchHand
new g_WillBeHit[33], g_SteamPower[33]
new g_MaxPlayers, g_MsgStatusIcon
new g_SmokePuff_SprId

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
	
	RegisterHam(Ham_Item_Deploy, weapon_papin, "fw_Item_Deploy_Post", 1)	
	RegisterHam(Ham_Weapon_WeaponIdle, weapon_papin, "fw_Weapon_WeaponIdle_Post", 1)
	
	g_MaxPlayers = get_maxplayers()
	g_MsgStatusIcon = get_user_msgid("StatusIcon")
	
	register_clcmd("say /get", "Get_Papin")
}

public plugin_precache()
{
	precache_model(MODEL_V)
	precache_model(MODEL_P)
	
	for(new i = 0; i < sizeof(Papin_Sounds); i++)
		precache_sound(Papin_Sounds[i])
		
	g_SmokePuff_SprId = engfunc(EngFunc_PrecacheModel, "sprites/smokepuff.spr")
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

public Get_Papin(id)
{
	Set_BitVar(g_Had_Papin, id)
	UnSet_BitVar(g_TempingAttack, id)
	UnSet_BitVar(g_PapinCharged, id)
	UnSet_BitVar(g_SwitchHand, id)
	
	g_WillBeHit[id] = HIT_NOTHING
	g_SteamPower[id] = 0
	
	Update_SpecialAmmo(id, 0, 0)
	
	if(get_user_weapon(id) == CSW_KNIFE)
	{
		set_pev(id, pev_viewmodel2, MODEL_V)
		set_pev(id, pev_weaponmodel2, MODEL_P)	

		Set_WeaponAnim(id, ANIM_DRAW_A)
	} else {
		engclient_cmd(id, weapon_papin)
	}	
}

public Remove_Papin(id)
{
	if(is_user_connected(id)) Update_SpecialAmmo(id, g_SteamPower[id], 0)
	
	g_SteamPower[id] = 0
	
	UnSet_BitVar(g_Had_Papin, id)
	UnSet_BitVar(g_SwitchHand, id)
}

public fw_UpdateClientData_Post(id, sendweapons, cd_handle)
{
	if(!is_alive(id))
		return FMRES_IGNORED	
	if(get_player_weapon(id) == CSW_PAPIN && Get_BitVar(g_Had_Papin, id))
		set_cd(cd_handle, CD_flNextAttack, get_gametime() + 0.001) 
	
	return FMRES_HANDLED
}

public fw_EmitSound(id, channel, const sample[], Float:volume, Float:attn, flags, pitch)
{
	if(!is_connected(id))
		return FMRES_IGNORED
	if(get_player_weapon(id) != CSW_PAPIN || !Get_BitVar(g_Had_Papin, id))
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
	if(get_player_weapon(id) != CSW_PAPIN || !Get_BitVar(g_Had_Papin, id))
		return FMRES_IGNORED
	
	static Float:vecStart[3], Float:vecEnd[3], Float:v_angle[3], Float:v_forward[3], Float:view_ofs[3], Float:fOrigin[3]
	
	pev(id, pev_origin, fOrigin)
	pev(id, pev_view_ofs, view_ofs)
	xs_vec_add(fOrigin, view_ofs, vecStart)
	pev(id, pev_v_angle, v_angle)
	
	engfunc(EngFunc_MakeVectors, v_angle)
	get_global_vector(GL_v_forward, v_forward)

	if(!Get_BitVar(g_TempingAttack, id)) xs_vec_mul_scalar(v_forward, SLASH_RADIUS, v_forward)
	else xs_vec_mul_scalar(v_forward, 0.0, v_forward)
	xs_vec_add(vecStart, v_forward, vecEnd)
	
	engfunc(EngFunc_TraceLine, vecStart, vecEnd, ignored_monster, id, handle)
	
	return FMRES_SUPERCEDE
}

public fw_TraceHull(Float:vector_start[3], Float:vector_end[3], ignored_monster, hull, id, handle)
{
	if(!is_alive(id))
		return FMRES_IGNORED	
	if(get_player_weapon(id) != CSW_PAPIN || !Get_BitVar(g_Had_Papin, id))
		return FMRES_IGNORED
	
	static Float:vecStart[3], Float:vecEnd[3], Float:v_angle[3], Float:v_forward[3], Float:view_ofs[3], Float:fOrigin[3]
	
	pev(id, pev_origin, fOrigin)
	pev(id, pev_view_ofs, view_ofs)
	xs_vec_add(fOrigin, view_ofs, vecStart)
	pev(id, pev_v_angle, v_angle)
	
	engfunc(EngFunc_MakeVectors, v_angle)
	get_global_vector(GL_v_forward, v_forward)

	if(!Get_BitVar(g_TempingAttack, id)) xs_vec_mul_scalar(v_forward, SLASH_RADIUS, v_forward)
	else xs_vec_mul_scalar(v_forward, 0.0, v_forward)
	xs_vec_add(vecStart, v_forward, vecEnd)
	
	engfunc(EngFunc_TraceHull, vecStart, vecEnd, ignored_monster, hull, id, handle)
	
	return FMRES_SUPERCEDE
}

public fw_CmdStart(id, uc_handle, seed)
{
	if(!is_alive(id)) 
		return
	if(get_player_weapon(id) != CSW_PAPIN || !Get_BitVar(g_Had_Papin, id))
		return
	
	static Ent; Ent = fm_get_user_weapon_entity(id, CSW_PAPIN)
	if(!pev_valid(Ent))
		return
	if(get_pdata_float(id, 83, 5) > 0.0) 
		return
	
	static CurButton; CurButton = get_uc(uc_handle, UC_Buttons)
	if(CurButton & IN_ATTACK)
	{
		CurButton &= ~IN_ATTACK
		set_uc(uc_handle, UC_Buttons, CurButton)

		static Ent; Ent = fm_get_user_weapon_entity(id, CSW_PAPIN)
		if(!pev_valid(Ent)) return
	
		Set_BitVar(g_TempingAttack, id)
		ExecuteHamB(Ham_Weapon_PrimaryAttack, Ent)
		UnSet_BitVar(g_TempingAttack, id)
		
		Set_Weapon_Idle(id, CSW_PAPIN, SLASH_NEXTATK + 0.5)
		Set_Player_NextAttack(id, SLASH_NEXTATK)
		
		static Duck; Duck = (pev(id, pev_flags) & FL_DUCKING)
		static Float:PunchAngles[3]
		
		Check_SteamPower(id)
		
		if(Duck) 
		{
			if(!Get_BitVar(g_SwitchHand, id))
			{
				PunchAngles[0] = random_float(-0.5, -1.0)
				PunchAngles[1] = random_float(1.0, 2.0)
				
				Set_BitVar(g_SwitchHand, id)
				if(Get_BitVar(g_PapinCharged, id)) Set_WeaponAnim(id, ANIM_SLASH_B1_1)
				else Set_WeaponAnim(id, ANIM_SLASH_A1_1)
			} else {
				PunchAngles[0] = random_float(-0.5, -1.0)
				PunchAngles[1] = random_float(1.0, -2.0)
				
				UnSet_BitVar(g_SwitchHand, id)
				if(Get_BitVar(g_PapinCharged, id)) Set_WeaponAnim(id, ANIM_SLASH_B1_2)
				else Set_WeaponAnim(id, ANIM_SLASH_A1_2)
			}
		} else {
			if(!Get_BitVar(g_SwitchHand, id))
			{
				PunchAngles[0] = random_float(-0.5, -1.5)
				PunchAngles[1] = random_float(1.0, 3.0)
				
				Set_BitVar(g_SwitchHand, id)
				if(Get_BitVar(g_PapinCharged, id)) Set_WeaponAnim(id, ANIM_SLASH_B2_1)
				else Set_WeaponAnim(id, ANIM_SLASH_A2_1)
			} else {
				PunchAngles[0] = random_float(-0.5, -1.5)
				PunchAngles[1] = random_float(1.0, -3.0)
				
				UnSet_BitVar(g_SwitchHand, id)
				if(Get_BitVar(g_PapinCharged, id)) Set_WeaponAnim(id, ANIM_SLASH_B2_2)
				else Set_WeaponAnim(id, ANIM_SLASH_A2_2)
			}
		}
		
		set_pev(id, pev_punchangle, PunchAngles)
		Papin_SlashDamage(id)
	} 
	
	if(CurButton & IN_ATTACK2) 
	{
		CurButton &= ~IN_ATTACK2
		set_uc(uc_handle, UC_Buttons, CurButton)
		
		static Ent; Ent = fm_get_user_weapon_entity(id, CSW_PAPIN)
		if(!pev_valid(Ent)) return
		
		if(g_SteamPower[id] - 3 < 0)
			return
			
		Update_SpecialAmmo(id, g_SteamPower[id], 0)
		g_SteamPower[id] -= 3
		
		if(g_SteamPower[id] > 0) Update_SpecialAmmo(id, g_SteamPower[id], 1)
		else Update_SpecialAmmo(id, g_SteamPower[id], 0)
		
		if(g_SteamPower[id] >= 3) Set_BitVar(g_PapinCharged, id)
		else UnSet_BitVar(g_PapinCharged, id)
		
		Set_BitVar(g_TempingAttack, id)
		ExecuteHamB(Ham_Weapon_PrimaryAttack, Ent)
		UnSet_BitVar(g_TempingAttack, id)	
			
		Set_Weapon_Idle(id, CSW_PAPIN, PUNCH_NEXTATK + 0.3)
		Set_Player_NextAttack(id, PUNCH_NEXTATK)
		
		static Float:PunchAngles[3]
		if(!Get_BitVar(g_SwitchHand, id))
		{
			PunchAngles[0] = random_float(-0.5, -1.0)
			PunchAngles[1] = 0.0
			
			Set_BitVar(g_SwitchHand, id)
			if(Get_BitVar(g_PapinCharged, id)) Set_WeaponAnim(id, ANIM_SLASH_B3_1)
			else Set_WeaponAnim(id, ANIM_SLASH_A3_1)
			
			emit_sound(id, CHAN_WEAPON, Papin_Sounds[9], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
			PlaySound(id, Papin_Sounds[11])
		} else {
			PunchAngles[0] = random_float(-0.5, -1.0)
			PunchAngles[1] = 0.0
			
			UnSet_BitVar(g_SwitchHand, id)
			if(Get_BitVar(g_PapinCharged, id)) Set_WeaponAnim(id, ANIM_SLASH_B3_2)
			else Set_WeaponAnim(id, ANIM_SLASH_A3_2)
			
			emit_sound(id, CHAN_WEAPON, Papin_Sounds[10], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
			PlaySound(id, Papin_Sounds[11])
		}	
		
		Make_SteamSmoke(id)
		
		set_pev(id, pev_punchangle, PunchAngles)
		Papin_PunchDamage(id)
	}
}

public Check_SteamPower(id)
{
	if(g_SteamPower[id] < 9)
	{
		g_SteamPower[id]++
		
		if(g_SteamPower[id] - 1 >= 0) Update_SpecialAmmo(id, g_SteamPower[id] - 1, 0)
		Update_SpecialAmmo(id, g_SteamPower[id], 1)
		
		if(g_SteamPower[id] >= 3) Set_BitVar(g_PapinCharged, id)
		else UnSet_BitVar(g_PapinCharged, id)
	}
}

public Make_SteamSmoke(id)
{
	static Float:Origin[3]
	get_position(id, 40.0, 0.0, -10.0, Origin)
	
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY) 
	write_byte(TE_EXPLOSION) 
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2])
	write_short(g_SmokePuff_SprId)
	write_byte(20)
	write_byte(15)
	write_byte(14)
	message_end()
}

public Papin_SlashDamage(id)
{
	static Float:Max_Distance, Float:Point[4][3], Float:TB_Distance, Float:Point_Dis
	
	Point_Dis = SLASH_RADIUS / 2.0
	Max_Distance = SLASH_RADIUS
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
		emit_sound(id, CHAN_ITEM, Papin_Sounds[random_num(1, 2)], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
		
		Set_Weapon_Idle(id, CSW_PAPIN, SLASH_NEXTATK_HIT + 0.5)
		Set_Player_NextAttack(id, SLASH_NEXTATK_HIT)
	} else {
		static Float:StartOrigin[3], Float:EndOrigin[3]
		get_position(id, 0.0, 0.0, 26.0, StartOrigin)
		get_position(id, SLASH_RADIUS, 0.0, 26.0, EndOrigin)
		
		if(is_wall_between_points(StartOrigin, EndOrigin, id)) 
		{
			emit_sound(id, CHAN_ITEM, Papin_Sounds[3], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
			
			Set_Weapon_Idle(id, CSW_PAPIN, SLASH_NEXTATK_HIT + 0.5)
			Set_Player_NextAttack(id, SLASH_NEXTATK_HIT)
		} else {
			if(Get_BitVar(g_SwitchHand, id)) PlaySound(id, Papin_Sounds[5])
			else PlaySound(id, Papin_Sounds[6])
		}
	}
	
	return 1
}

public Papin_PunchDamage(id)
{
	static Float:Max_Distance, Float:Point[4][3], Float:TB_Distance, Float:Point_Dis
	
	Point_Dis = PUNCH_RADIUS / 1.5
	Max_Distance = PUNCH_RADIUS
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
		}
	}	
	
	if(Have_Victim) emit_sound(id, CHAN_STATIC, Papin_Sounds[random_num(1, 2)], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	
	return 1
}

public Update_SpecialAmmo(id, Ammo, On)
{
	static AmmoSprites[33], Color[3]
	format(AmmoSprites, sizeof(AmmoSprites), "number_%d", Ammo)

	switch(Ammo)
	{
		case 1..3: { Color[0] = 0; Color[1] = 200; Color[2] = 0; }
		case 4..5: { Color[0] = 200; Color[1] = 200; Color[2] = 0; }
		case 6..10: { Color[0] = 200; Color[1] = 0; Color[2] = 0; }
	}
	
	message_begin(MSG_ONE_UNRELIABLE, g_MsgStatusIcon, {0,0,0}, id)
	write_byte(On)
	write_string(AmmoSprites)
	write_byte(Color[0]) // red
	write_byte(Color[1]) // green
	write_byte(Color[2]) // blue
	message_end()
}

public fw_Item_Deploy_Post(Ent)
{
	if(pev_valid(Ent) != 2)
		return
	static Id; Id = get_pdata_cbase(Ent, 41, 4)
	if(get_pdata_cbase(Id, 373) != Ent)
		return
	if(!Get_BitVar(g_Had_Papin, Id))
		return
		
	set_pev(Id, pev_viewmodel2, MODEL_V)
	set_pev(Id, pev_weaponmodel2, MODEL_P)
	
	Set_WeaponAnim(Id, Get_BitVar(g_PapinCharged, Id) ? ANIM_DRAW_B : ANIM_DRAW_A)
	if(g_SteamPower[Id] > 0) Update_SpecialAmmo(Id, g_SteamPower[Id], 1)
}

public fw_Weapon_WeaponIdle_Post(Ent)
{
	if(pev_valid(Ent) != 2)
		return HAM_IGNORED
	static Id; Id = get_pdata_cbase(Ent, 41, 4)
	if(get_pdata_cbase(Id, 373) != Ent)
		return HAM_IGNORED
	if(!Get_BitVar(g_Had_Papin, Id))
		return HAM_IGNORED
		
	if(get_pdata_float(Ent, 48, 4) <= 0.25) 
	{
		Set_WeaponAnim(Id, Get_BitVar(g_PapinCharged, Id) ? ANIM_IDLE_B : ANIM_IDLE_A)
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
