#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <cstrike>
#include <xs>
#include <fun>

#define PLUGIN "[CSO] THANATOS-9"
#define VERSION "1.0"
#define AUTHOR "Joseph Rias de Dias"

#define DAMAGE_A 1000
#define DAMAGE_B 500

#define RADIUS 100.0
#define SLASH_DELAY 0.9

#define FALLEN_GALVATRON_TIME 5.0

#define CHANGE_TIME_MEGATRON 5.0
#define CHANGE_TIME_GALVATRON 3.5

#define MODEL_V "models/v_thanatos9.mdl"
#define MODEL_PA "models/p_thanatos9a.mdl"
#define MODEL_PB "models/p_thanatos9b.mdl"
#define MODEL_PC "models/p_thanatos9c.mdl"

#define CSW_THANATOS9 CSW_KNIFE
#define weapon_thanatos9 "weapon_knife"

#define WEAPON_ANIMEXTA "knife"
#define WEAPON_ANIMEXTB "m249"

new const WeaponSounds[13][] =
{
	"weapons/thanatos9_shoota1.wav",
	"weapons/thanatos9_shoota2.wav",
	"weapons/thanatos9_shootb_end.wav",
	"weapons/thanatos9_shootb_loop.wav",
	"weapons/thanatos9_drawa.wav",
	"weapons/thanatos9_changea_1.wav",
	"weapons/thanatos9_changea_2.wav",
	"weapons/thanatos9_changea_3.wav",
	"weapons/thanatos9_changea_4.wav",
	"weapons/thanatos9_changeb_1.wav",
	"weapons/thanatos9_changeb_2.wav",
	"weapons/skullaxe_hit.wav",
	"weapons/skullaxe_hit_wall.wav"
}

new const WeaponResources[3][] = 
{
	"sprites/knife_thanatos9.txt",
	"sprites/640hud79.spr",
	"sprites/smoke_thanatos9.spr"
}

enum
{
	ANIME_DRAW_A = 0,
	ANIME_SHOOT_B_LOOP,
	ANIME_SHOOT_B_START,
	ANIME_SHOOT_B_END,
	ANIME_IDLE_B,
	ANIME_IDLE_A,
	ANIME_DRAW_B,
	ANIME_SHOOT_A1,
	ANIME_SHOOT_A2,
	ANIME_CHANGE_TO_MEGATRON,
	ANIME_CHANGE_TO_GALVATRON
}

#define TASK_SLASHING 29411
#define TASK_CHANGING 29412

// MACROS
#define Get_BitVar(%1,%2) (%1 & (1 << (%2 & 31)))
#define Set_BitVar(%1,%2) %1 |= (1 << (%2 & 31))
#define UnSet_BitVar(%1,%2) %1 &= ~(1 << (%2 & 31))

new g_Had_Thanatos9, g_MegatronMode, g_FallenGalvatron, g_DarthVader, g_Changing, Float:CheckDamage[33]
new g_HamBot, g_MsgWeaponList, g_MaxPlayers, g_SmokePuff_SprId

// Safety
new g_IsConnected, g_IsAlive, g_PlayerWeapon[33]

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	// Safety
	Register_SafetyFunc()
	
	// Forward
	register_forward(FM_EmitSound, "fw_EmitSound")
	register_forward(FM_CmdStart, "fw_CmdStart")
	register_forward(FM_TraceLine, "fw_TraceLine")
	register_forward(FM_TraceHull, "fw_TraceHull")	
	
	// Hams
	RegisterHam(Ham_TraceAttack, "player", "fw_PlayerTraceAttack")
	RegisterHam(Ham_Item_Deploy, weapon_thanatos9, "fw_Item_Deploy_Post", 1)	
	RegisterHam(Ham_Item_AddToPlayer, weapon_thanatos9, "fw_Item_AddToPlayer_Post", 1)
	RegisterHam(Ham_Weapon_WeaponIdle, weapon_thanatos9, "fw_Weapon_WeaponIdle_Post", 1)
	
	// Cache
	g_MaxPlayers = get_maxplayers();
	g_MsgWeaponList = get_user_msgid("WeaponList")
	
	// CMD
	register_clcmd("knife_thanatos9", "Hook_Thanatos9")
	register_clcmd("say /get", "Get_Thanatos9")
}

public plugin_precache()
{
	precache_model(MODEL_V)
	precache_model(MODEL_PA)
	precache_model(MODEL_PB)
	precache_model(MODEL_PC)
	
	for(new i = 0; i < sizeof(WeaponSounds); i++)
		precache_sound(WeaponSounds[i])
	
	precache_generic(WeaponResources[0])
	precache_model(WeaponResources[1])
	g_SmokePuff_SprId = precache_model(WeaponResources[2])
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
	RegisterHamFromEntity(Ham_TraceAttack, id, "fw_PlayerTraceAttack")
}

public client_disconnect(id)
{
	Safety_Disconnected(id)
}

public Get_Thanatos9(id)
{
	remove_task(id+TASK_SLASHING)
	remove_task(id+TASK_CHANGING)
	
	Set_BitVar(g_Had_Thanatos9, id)
	UnSet_BitVar(g_MegatronMode, id)
	UnSet_BitVar(g_FallenGalvatron, id)
	UnSet_BitVar(g_DarthVader, id)
	UnSet_BitVar(g_Changing, id)
			
	if(get_user_weapon(id) == CSW_KNIFE)
	{
		set_pev(id, pev_viewmodel2, MODEL_V)
		set_pev(id, pev_weaponmodel2, MODEL_PA)
		Set_WeaponAnim(id, ANIME_DRAW_A)
		
		set_pdata_string(id, (492) * 4, WEAPON_ANIMEXTA, -1 , 20)
		Set_PlayerNextAttack(id, 0.75)
	}
	
	// Update Hud
	message_begin(MSG_ONE_UNRELIABLE, g_MsgWeaponList, _, id)
	write_string("knife_thanatos9")
	write_byte(-1)
	write_byte(-1)
	write_byte(-1)
	write_byte(-1)
	write_byte(2)
	write_byte(1)
	write_byte(CSW_THANATOS9)
	write_byte(0)
	message_end()	
}

public Remove_Thanatos9(id)
{
	remove_task(id+TASK_SLASHING)
	remove_task(id+TASK_CHANGING)
	
	UnSet_BitVar(g_Had_Thanatos9, id)
	UnSet_BitVar(g_MegatronMode, id)
	UnSet_BitVar(g_FallenGalvatron, id)
	UnSet_BitVar(g_DarthVader, id)
	UnSet_BitVar(g_Changing, id)
}

public Hook_Thanatos9(id)
{
	engclient_cmd(id, weapon_thanatos9)
	return PLUGIN_HANDLED
}

public fw_EmitSound(id, channel, const sample[], Float:volume, Float:attn, flags, pitch)
{
	if(!is_connected(id))
		return FMRES_IGNORED
	if(get_player_weapon(id) != CSW_THANATOS9 || !Get_BitVar(g_Had_Thanatos9, id))
		return FMRES_IGNORED
	if(!Get_BitVar(g_FallenGalvatron, id))
		return FMRES_IGNORED
		
	if(sample[8] == 'k' && sample[9] == 'n' && sample[10] == 'i')
	{
		if(sample[14] == 's' && sample[15] == 'l' && sample[16] == 'a')
			return FMRES_SUPERCEDE
		if (sample[14] == 'h' && sample[15] == 'i' && sample[16] == 't')
		{
			if (sample[17] == 'w') // wall
			{
				return FMRES_SUPERCEDE
			} else {
				emit_sound(id, CHAN_BODY, sample, volume, attn, flags, pitch)
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
	if(!is_alive(id)) 
		return
		
	if(get_player_weapon(id) != CSW_THANATOS9)
	{
		if(Get_BitVar(g_FallenGalvatron, id))
		{
			UnSet_BitVar(g_FallenGalvatron, id)
			emit_sound(id, CHAN_WEAPON, WeaponSounds[4], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
		}
		if(Get_BitVar(g_Changing, id))
			UnSet_BitVar(g_Changing, id)
		return
	}
	if(!Get_BitVar(g_Had_Thanatos9, id))
		return 
	
	static Ent; Ent = fm_get_user_weapon_entity(id, CSW_THANATOS9)
	if(!pev_valid(Ent))
		return
	
	//if(get_pdata_float(Ent, 46, OFFSET_LINUX_WEAPONS) > 0.0 || get_pdata_float(Ent, 47, OFFSET_LINUX_WEAPONS) > 0.0) 
	//	return
	
	static CurButton; CurButton = get_uc(uc_handle, UC_Buttons)
	
	if(Get_BitVar(g_FallenGalvatron, id))
	{
		if(get_gametime() - 0.085 > CheckDamage[id])
		{
			ExecuteHamB(Ham_Weapon_PrimaryAttack, Ent)
			
			emit_sound(id, CHAN_WEAPON, WeaponSounds[3], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
			if(pev(id, pev_weaponanim) != ANIME_SHOOT_B_LOOP)
				Set_WeaponAnim(id, ANIME_SHOOT_B_LOOP)
			
			CheckDamage[id] = get_gametime()
		}
		
		if(CurButton & IN_ATTACK) set_uc(uc_handle, UC_Buttons, CurButton & ~IN_ATTACK)
		else if (CurButton & IN_ATTACK2) set_uc(uc_handle, UC_Buttons, CurButton & ~IN_ATTACK2)
	}
	
	if(get_pdata_float(id, 83, 5) > 0.0)
		return
	
	if(CurButton & IN_ATTACK)
	{
		set_uc(uc_handle, UC_Buttons, CurButton & ~IN_ATTACK)
		
		if(!Get_BitVar(g_MegatronMode, id))
		{
			Set_WeaponIdleTime(id, CSW_THANATOS9, SLASH_DELAY + 0.25)
			Set_PlayerNextAttack(id, SLASH_DELAY + 0.25)
			
			if(!Get_BitVar(g_DarthVader, id))
			{
				Set_WeaponAnim(id, ANIME_SHOOT_A1)
				emit_sound(id, CHAN_WEAPON, WeaponSounds[0], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
				
				Set_BitVar(g_DarthVader, id)
			} else {
				Set_WeaponAnim(id, ANIME_SHOOT_A2)
				emit_sound(id, CHAN_WEAPON, WeaponSounds[1], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
				
				UnSet_BitVar(g_DarthVader, id)
			}
			
			remove_task(id+TASK_SLASHING)
			set_task(SLASH_DELAY, "Check_Slashing", id+TASK_SLASHING)
		} else {
			if(!Get_BitVar(g_FallenGalvatron, id))
			{
				Set_WeaponIdleTime(id, CSW_THANATOS9, 0.5)
				Set_PlayerNextAttack(id, 0.5)
				
				Set_WeaponAnim(id, ANIME_SHOOT_B_START)
				set_task(0.45, "Activate_FallenGalvatron", id+TASK_CHANGING)
			} else {
				
			}
		}
	} else if (CurButton & IN_ATTACK2) {
		set_uc(uc_handle, UC_Buttons, CurButton & ~IN_ATTACK2)
		
		if(Get_BitVar(g_Changing, id))
			return
			
		Set_BitVar(g_Changing, id)
		CheckDamage[id] = get_gametime() + 0.75
			
		if(!Get_BitVar(g_MegatronMode, id))
		{
			remove_task(id+TASK_CHANGING)

			Set_WeaponIdleTime(id, CSW_THANATOS9, CHANGE_TIME_MEGATRON + 0.25)
			Set_PlayerNextAttack(id, CHANGE_TIME_MEGATRON)
			
			Set_WeaponAnim(id, ANIME_CHANGE_TO_MEGATRON)
			
			set_task(0.75, "Create_Smoke", id+TASK_CHANGING)
			set_task(3.0, "Remove_Smoke", id+TASK_CHANGING)
		} else {
			remove_task(id+TASK_CHANGING)
			
			Set_WeaponIdleTime(id, CSW_THANATOS9, CHANGE_TIME_GALVATRON + 0.25)
			Set_PlayerNextAttack(id, CHANGE_TIME_GALVATRON)
			
			Set_WeaponAnim(id, ANIME_CHANGE_TO_GALVATRON)
			
			set_task(0.75, "Create_Smoke", id+TASK_CHANGING)
			set_task(CHANGE_TIME_GALVATRON - 0.25, "Change_Thanatos9", id+TASK_CHANGING)
		}
	}
}

public Create_Smoke(id)
{
	id -= TASK_CHANGING
	
	if(!is_alive(id))
		return
	if(get_player_weapon(id) != CSW_THANATOS9 || !Get_BitVar(g_Had_Thanatos9, id))
		return
		
	static Float:Origin[3]; get_position(id, 25.0, 15.0, 0.0, Origin)
	
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY) 
	write_byte(TE_EXPLOSION) 
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2])
	write_short(g_SmokePuff_SprId)
	write_byte(1)
	write_byte(30)
	write_byte(14)
	message_end()
	
	set_task(0.5, "Create_Smoke", id+TASK_CHANGING)
}

public Remove_Smoke(id)
{
	id -= TASK_CHANGING
	
	if(!is_alive(id))
		return
		
	remove_task(id+TASK_CHANGING)
	set_task(CHANGE_TIME_MEGATRON - 3.25, "Change_Thanatos9", id+TASK_CHANGING)
}

public Activate_FallenGalvatron(id)
{
	id -= TASK_CHANGING
	
	if(!is_alive(id)) 
		return
	if(get_player_weapon(id) != CSW_THANATOS9 || !Get_BitVar(g_Had_Thanatos9, id))
		return 
	if(!Get_BitVar(g_MegatronMode, id))
		return
		
	UnSet_BitVar(g_MegatronMode, id)
	Set_BitVar(g_FallenGalvatron, id)
	
	set_pev(id, pev_weaponmodel2, MODEL_PC)
	
	Set_WeaponIdleTime(id, CSW_THANATOS9, FALLEN_GALVATRON_TIME)
	Set_PlayerNextAttack(id, FALLEN_GALVATRON_TIME)
	
	Set_WeaponAnim(id, ANIME_SHOOT_B_LOOP)
	
	remove_task(id+TASK_CHANGING)
	set_task(FALLEN_GALVATRON_TIME, "Deactivate_FallenGalvatron", id+TASK_CHANGING)
}

public Deactivate_FallenGalvatron(id)
{
	id -= TASK_CHANGING
	
	if(!is_alive(id)) 
		return
	if(get_player_weapon(id) != CSW_THANATOS9 || !Get_BitVar(g_Had_Thanatos9, id))
		return 
	if(!Get_BitVar(g_FallenGalvatron, id))
		return
		
	UnSet_BitVar(g_FallenGalvatron, id)
	UnSet_BitVar(g_MegatronMode, id)
	
	set_pev(id, pev_weaponmodel2, MODEL_PB)
	
	Set_WeaponIdleTime(id, CSW_THANATOS9, 0.7 + CHANGE_TIME_GALVATRON)
	Set_PlayerNextAttack(id, 0.7 + CHANGE_TIME_GALVATRON)
	
	Set_WeaponAnim(id, ANIME_SHOOT_B_END)
	emit_sound(id, CHAN_WEAPON, WeaponSounds[4], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	
	remove_task(id+TASK_CHANGING)
	set_task(0.65, "Deactivate_MegatronMode", id+TASK_CHANGING)
}

public Deactivate_MegatronMode(id)
{
	id -= TASK_CHANGING
	
	if(!is_alive(id)) 
		return
	if(get_player_weapon(id) != CSW_THANATOS9 || !Get_BitVar(g_Had_Thanatos9, id))
		return 

	set_pev(id, pev_weaponmodel2, MODEL_PA)
	set_pdata_string(id, (492) * 4, WEAPON_ANIMEXTA, -1 , 20)
	
	set_task(0.75, "Create_Smoke", id+TASK_CHANGING)
	set_task(3.0, "Remove_Smoke", id+TASK_CHANGING)
	
	Set_WeaponAnim(id, ANIME_CHANGE_TO_GALVATRON)
}

public Change_Thanatos9(id)
{
	id -= TASK_CHANGING
	
	remove_task(id+TASK_CHANGING)
	
	if(!is_alive(id)) 
		return
	if(get_player_weapon(id) != CSW_THANATOS9 || !Get_BitVar(g_Had_Thanatos9, id))
		return 
	if(!Get_BitVar(g_Changing, id))
		return
		
	UnSet_BitVar(g_Changing, id)
			
	if(!Get_BitVar(g_MegatronMode, id))
	{
		set_pev(id, pev_weaponmodel2, MODEL_PB)
		
		Set_BitVar(g_MegatronMode, id)
		Set_WeaponAnim(id, ANIME_IDLE_B)
		
		set_pdata_string(id, (492) * 4, WEAPON_ANIMEXTB, -1 , 20)
	} else {
		set_pev(id, pev_weaponmodel2, MODEL_PA)
		
		UnSet_BitVar(g_MegatronMode, id)
		Set_WeaponAnim(id, ANIME_IDLE_A)
		
		set_pdata_string(id, (492) * 4, WEAPON_ANIMEXTA, -1 , 20)
	}
}

public Check_Slashing(id)
{
	id -= TASK_SLASHING
	
	if(!is_alive(id)) 
		return
	if(get_player_weapon(id) != CSW_THANATOS9 || !Get_BitVar(g_Had_Thanatos9, id))
		return 	
		
	Set_WeaponIdleTime(id, CSW_THANATOS9, 1.0)
	Set_PlayerNextAttack(id, 0.75)

	Damage_Slashing(id)
}

public Damage_Slashing(id)
{
	static Float:Max_Distance, Float:Point[4][3], Float:TB_Distance, Float:Point_Dis
	
	Point_Dis = 80.0
	Max_Distance = RADIUS
	TB_Distance = Max_Distance / 4.0
	
	static Float:VicOrigin[3], Float:MyOrigin[3]
	pev(id, pev_origin, MyOrigin)
	
	for(new i = 0; i < 4; i++) get_position(id, TB_Distance * (i + 1), 0.0, 0.0, Point[i])
		
	static Have_Victim; Have_Victim = 0
	static ent
	ent = fm_get_user_weapon_entity(id, get_user_weapon(id))
		
	if(!pev_valid(ent))
		return
		
	for(new i = 0; i < g_MaxPlayers; i++)
	{
		if(!is_alive(i))
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
			do_attack(id, i, ent, float(DAMAGE_A))
		}
	}

	if(Have_Victim) emit_sound(id, CHAN_STATIC, WeaponSounds[11], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	else {
		MyOrigin[2] += 26.0
		get_position(id, RADIUS - 5.0, 0.0, 0.0, Point[0])
		
		if(is_wall_between_points(MyOrigin, Point[0], id))
			emit_sound(id, CHAN_STATIC, WeaponSounds[12], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	}
}

public fw_TraceLine(Float:vector_start[3], Float:vector_end[3], ignored_monster, id, handle)
{
	if(!is_alive(id))
		return FMRES_IGNORED	
	if(get_player_weapon(id) != CSW_THANATOS9 || !Get_BitVar(g_Had_Thanatos9, id))
		return FMRES_IGNORED
	
	static Float:vecStart[3], Float:vecEnd[3], Float:v_angle[3], Float:v_forward[3], Float:view_ofs[3], Float:fOrigin[3]
	
	pev(id, pev_origin, fOrigin)
	pev(id, pev_view_ofs, view_ofs)
	xs_vec_add(fOrigin, view_ofs, vecStart)
	pev(id, pev_v_angle, v_angle)
	
	engfunc(EngFunc_MakeVectors, v_angle)
	get_global_vector(GL_v_forward, v_forward)

	if(!Get_BitVar(g_FallenGalvatron, id)) xs_vec_mul_scalar(v_forward, 0.0, v_forward)
	else xs_vec_mul_scalar(v_forward, RADIUS, v_forward)
	xs_vec_add(vecStart, v_forward, vecEnd)
	
	engfunc(EngFunc_TraceLine, vecStart, vecEnd, ignored_monster, id, handle)
	
	return FMRES_SUPERCEDE
}

public fw_TraceHull(Float:vector_start[3], Float:vector_end[3], ignored_monster, hull, id, handle)
{
	if(!is_alive(id))
		return FMRES_IGNORED	
	if(get_player_weapon(id) != CSW_THANATOS9 || !Get_BitVar(g_Had_Thanatos9, id))
		return FMRES_IGNORED
	
	static Float:vecStart[3], Float:vecEnd[3], Float:v_angle[3], Float:v_forward[3], Float:view_ofs[3], Float:fOrigin[3]
	
	pev(id, pev_origin, fOrigin)
	pev(id, pev_view_ofs, view_ofs)
	xs_vec_add(fOrigin, view_ofs, vecStart)
	pev(id, pev_v_angle, v_angle)
	
	engfunc(EngFunc_MakeVectors, v_angle)
	get_global_vector(GL_v_forward, v_forward)
	
	if(!Get_BitVar(g_FallenGalvatron, id)) xs_vec_mul_scalar(v_forward, 0.0, v_forward)
	else xs_vec_mul_scalar(v_forward, RADIUS, v_forward)
	xs_vec_add(vecStart, v_forward, vecEnd)
	
	engfunc(EngFunc_TraceHull, vecStart, vecEnd, ignored_monster, hull, id, handle)
	
	return FMRES_SUPERCEDE
}

public fw_PlayerTraceAttack(Victim, Attacker, Float:Damage, Float:Direction[3], TraceResult, DamageBits) 
{
	if(!is_alive(Attacker))	
		return HAM_IGNORED
	if(!Get_BitVar(g_Had_Thanatos9, Attacker) || !Get_BitVar(g_FallenGalvatron, Attacker))
		return HAM_IGNORED
		
	SetHamParamFloat(3, float(DAMAGE_B))
		
	return HAM_IGNORED
}

public fw_Item_Deploy_Post(Ent)
{
	if(pev_valid(Ent) != 2)
		return
	static Id; Id = get_pdata_cbase(Ent, 41, 4)
	if(get_pdata_cbase(Id, 373) != Ent)
		return
	if(!Get_BitVar(g_Had_Thanatos9, Id))
		return
	
	remove_task(Id+TASK_CHANGING)
	UnSet_BitVar(g_Changing, Id)
	UnSet_BitVar(g_FallenGalvatron, Id)
	
	set_pev(Id, pev_viewmodel2, MODEL_V)

	if(!Get_BitVar(g_MegatronMode, Id))
	{
		set_pev(Id, pev_weaponmodel2, MODEL_PA)
		Set_WeaponAnim(Id, ANIME_DRAW_A)
		
		set_pdata_string(Id, (492) * 4, WEAPON_ANIMEXTA, -1 , 20)
	} else {
		set_pev(Id, pev_weaponmodel2, MODEL_PB)
		Set_WeaponAnim(Id, ANIME_DRAW_B)
		
		set_pdata_string(Id, (492) * 4, WEAPON_ANIMEXTB, -1 , 20)
	}
}

public fw_Item_AddToPlayer_Post(Ent, id)
{
	if(!pev_valid(Ent))
		return HAM_IGNORED
	
	if(Get_BitVar(g_Had_Thanatos9, id))
	{
		message_begin(MSG_ONE_UNRELIABLE, g_MsgWeaponList, _, id)
		write_string("knife_thanatos9")
		write_byte(-1)
		write_byte(-1)
		write_byte(-1)
		write_byte(-1)
		write_byte(2)
		write_byte(1)
		write_byte(CSW_THANATOS9)
		write_byte(0)
		message_end()		
	} 
	
	return HAM_HANDLED	
}

public fw_Weapon_WeaponIdle_Post(iEnt)
{
	if(pev_valid(iEnt) != 2)
		return
	static Id; Id = get_pdata_cbase(iEnt, 41, 4)
	//if(get_pdata_cbase(Id, 373) != iEnt)
	//	/return
	if(!Get_BitVar(g_Had_Thanatos9, Id))
		return
		
	if(get_pdata_float(iEnt, 48, 4) <= 0.25)
	{
		if(Get_BitVar(g_FallenGalvatron, Id)) Set_WeaponAnim(Id, ANIME_SHOOT_B_LOOP)
		else if(Get_BitVar(g_MegatronMode, Id)) Set_WeaponAnim(Id, ANIME_IDLE_B)
		else Set_WeaponAnim(Id, ANIME_IDLE_A)
		
		set_pdata_float(iEnt, 48, 20.0, 4)
	}	
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


do_attack(Attacker, Victim, Inflictor, Float:fDamage)
{
	fake_player_trace_attack(Attacker, Victim, fDamage)
	fake_take_damage(Attacker, Victim, fDamage, Inflictor)
}

fake_player_trace_attack(iAttacker, iVictim, &Float:fDamage)
{
	// get fDirection
	new Float:fAngles[3], Float:fDirection[3]
	pev(iAttacker, pev_angles, fAngles)
	angle_vector(fAngles, ANGLEVECTOR_FORWARD, fDirection)
	
	// get fStart
	new Float:fStart[3], Float:fViewOfs[3]
	pev(iAttacker, pev_origin, fStart)
	pev(iAttacker, pev_view_ofs, fViewOfs)
	xs_vec_add(fViewOfs, fStart, fStart)
	
	// get aimOrigin
	new iAimOrigin[3], Float:fAimOrigin[3]
	get_user_origin(iAttacker, iAimOrigin, 3)
	IVecFVec(iAimOrigin, fAimOrigin)
	
	// TraceLine from fStart to AimOrigin
	new ptr = create_tr2() 
	engfunc(EngFunc_TraceLine, fStart, fAimOrigin, DONT_IGNORE_MONSTERS, iAttacker, ptr)
	new pHit = get_tr2(ptr, TR_pHit)
	new iHitgroup = get_tr2(ptr, TR_iHitgroup)
	new Float:fEndPos[3]
	get_tr2(ptr, TR_vecEndPos, fEndPos)

	// get target & body at aiming
	new iTarget, iBody
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
		new Float:fVicOrigin[3], Float:fVicViewOfs[3], Float:fAimInVictim[3]
		pev(iVictim, pev_origin, fVicOrigin)
		pev(iVictim, pev_view_ofs, fVicViewOfs) 
		xs_vec_add(fVicViewOfs, fVicOrigin, fAimInVictim)
		fAimInVictim[2] = fStart[2]
		fAimInVictim[2] += get_distance_f(fStart, fAimInVictim) * floattan( fAngles[0] * 2.0, degrees )
		
		// check aim in size of iVictim
		new iAngleToVictim = get_angle_to_target(iAttacker, fVicOrigin)
		iAngleToVictim = abs(iAngleToVictim)
		new Float:fDis = 2.0 * get_distance_f(fStart, fAimInVictim) * floatsin( float(iAngleToVictim) * 0.5, degrees )
		new Float:fVicSize[3]
		pev(iVictim, pev_size , fVicSize)
		if ( fDis <= fVicSize[0] * 0.5 )
		{
			// TraceLine from fStart to aimOrigin in iVictim
			new ptr2 = create_tr2() 
			engfunc(EngFunc_TraceLine, fStart, fAimInVictim, DONT_IGNORE_MONSTERS, iAttacker, ptr2)
			new pHit2 = get_tr2(ptr2, TR_pHit)
			new iHitgroup2 = get_tr2(ptr2, TR_iHitgroup)
			
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
			
			new ptr3 = create_tr2() 
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
	new Float:fMultifDamage 
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
	iInflictor = (!iInflictor) ? iAttacker : iInflictor
	ExecuteHamB(Ham_TakeDamage, iVictim, iInflictor, iAttacker, fDamage, iDamageBit)
}

stock get_angle_to_target(id, const Float:fTarget[3], Float:TargetSize = 0.0)
{
	new Float:fOrigin[3], iAimOrigin[3], Float:fAimOrigin[3], Float:fV1[3]
	pev(id, pev_origin, fOrigin)
	get_user_origin(id, iAimOrigin, 3) // end position from eyes
	IVecFVec(iAimOrigin, fAimOrigin)
	xs_vec_sub(fAimOrigin, fOrigin, fV1)
	
	new Float:fV2[3]
	xs_vec_sub(fTarget, fOrigin, fV2)
	
	new iResult = get_angle_between_vectors(fV1, fV2)
	
	if (TargetSize > 0.0)
	{
		new Float:fTan = TargetSize / get_distance_f(fOrigin, fTarget)
		new fAngleToTargetSize = floatround( floatatan(fTan, degrees) )
		iResult -= (iResult > 0) ? fAngleToTargetSize : -fAngleToTargetSize
	}
	
	return iResult
}

stock get_angle_between_vectors(const Float:fV1[3], const Float:fV2[3])
{
	new Float:fA1[3], Float:fA2[3]
	engfunc(EngFunc_VecToAngles, fV1, fA1)
	engfunc(EngFunc_VecToAngles, fV2, fA2)
	
	new iResult = floatround(fA1[1] - fA2[1])
	iResult = iResult % 360
	iResult = (iResult > 180) ? (iResult - 360) : iResult
	
	return iResult
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

public is_alive(id)
{
	if(!(1 <= id <= 32))
		return 0
	if(!Get_BitVar(g_IsConnected, id))
		return 0
	if(!Get_BitVar(g_IsAlive, id)) 
		return 0
	
	return 1
}

public is_connected(id)
{
	if(!(1 <= id <= 32))
		return 0
	if(!Get_BitVar(g_IsConnected, id))
		return 0
	
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
