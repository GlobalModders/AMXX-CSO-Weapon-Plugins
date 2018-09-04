#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <cstrike>
#include <fun>

#define PLUGIN "Thunderbolt"
#define VERSION "2014"
#define AUTHOR "Dias"

#define DAMAGE 550
#define DEFAULT_AMMO 20
#define RELOAD_TIME 2.67

#define CSW_THUNDERBOLT CSW_AWP
#define weapon_thunderbolt "weapon_awp"
#define old_event "events/awp.sc"
#define old_w_model "models/w_awp.mdl"
#define WEAPON_SECRETCODE 4234234

#define V_MODEL "models/v_sfsniperF.mdl"
#define P_MODEL "models/p_sfsniper.mdl"
#define W_MODEL "models/w_sfsniper.mdl"

#define SNIP_MODEL_R "models/v_sfsightR.mdl"
#define SNIP_MODEL_B "models/v_sfsightB.mdl"

new const WeaponSounds[5][] = 
{
	"weapons/sfsniper-1.wav",
	"weapons/sfsniper_insight1.wav",
	"weapons/sfsniper_zoom.wav",
	"weapons/sfsniper_idle.wav",
	"weapons/sfsniper_draw.wav"
}

new const WeaponResources[4][] = 
{
	"sprites/weapon_sfsniperF.txt",
	"sprites/640hud2_2.spr",
	"sprites/640hud10_2.spr",
	"sprites/640hud81_2.spr"
}

enum
{
	TB_ANIM_IDLE = 0,
	TB_ANIM_SHOOT,
	TB_ANIM_DRAW
}

enum
{
	ZOOM_NONE = 0,
	ZOOM_ACT
}

// MACROS
#define Get_BitVar(%1,%2) (%1 & (1 << (%2 & 31)))
#define Set_BitVar(%1,%2) %1 |= (1 << (%2 & 31))
#define UnSet_BitVar(%1,%2) %1 &= ~(1 << (%2 & 31))

new g_Had_Thunderbolt, g_Zoom[33]
new g_IsAlive
new Float:CheckDelay[33], Float:CheckDelay2[33], Float:CheckDelay3[33], g_TempAttack
new g_Msg_CurWeapon, g_Msg_AmmoX, g_Msg_WeaponList
new g_Beam_SprId, g_HamBot_Register, g_Event_Thunderbolt

public plugin_init() 
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	register_event("CurWeapon", "Event_CurWeapon", "be", "1=1")
	register_event("DeathMsg", "Event_Death", "a")
	
	register_forward(FM_UpdateClientData, "fw_UpdateClientData_Post", 1)	
	register_forward(FM_PlaybackEvent, "fw_PlaybackEvent")		
	register_forward(FM_SetModel, "fw_SetModel")	
	register_forward(FM_CmdStart, "fw_CmdStart")
	register_forward(FM_EmitSound, "fw_EmitSound")
	register_forward(FM_TraceLine, "fw_TraceLine")
	register_forward(FM_TraceHull, "fw_TraceHull")
	
	RegisterHam(Ham_Spawn, "player", "fw_PlayerSpawn_Post", 1)
	RegisterHam(Ham_Item_AddToPlayer, weapon_thunderbolt, "fw_AddToPlayer_Post", 1)
	RegisterHam(Ham_Item_Deploy, weapon_thunderbolt, "fw_Item_Deploy_Post", 1)	
	RegisterHam(Ham_Weapon_WeaponIdle, weapon_thunderbolt, "fw_Weapon_WeaponIdle_Post", 1)
	RegisterHam(Ham_Weapon_SecondaryAttack, "weapon_awp", "fw_Weapon_SecondaryAttack")
	
	g_Msg_CurWeapon = get_user_msgid("CurWeapon")
	g_Msg_AmmoX = get_user_msgid("AmmoX")	
	g_Msg_WeaponList = get_user_msgid("WeaponList")
	
	register_clcmd("weapon_sfsniperF", "CLCMD_HookWeapon")
	register_clcmd("say tb", "Get_Thunderbolt")
}

public plugin_precache()
{
	precache_model(V_MODEL)
	precache_model(P_MODEL)
	precache_model(W_MODEL)
	
	precache_model(SNIP_MODEL_R)
	precache_model(SNIP_MODEL_B)
	
	for(new i = 0; i < sizeof(WeaponSounds); i++) 
		engfunc(EngFunc_PrecacheSound, WeaponSounds[i])
	for(new i = 0; i < sizeof(WeaponResources); i++)
	{
		if(i == 0) engfunc(EngFunc_PrecacheGeneric, WeaponResources[0])
		else engfunc(EngFunc_PrecacheModel, WeaponResources[i])
	}
	
	g_Beam_SprId =  engfunc(EngFunc_PrecacheModel, "sprites/laserbeam.spr")
}

public client_putinserver(id)
{
	if(is_user_bot(id) && !g_HamBot_Register)
	{
		g_HamBot_Register = 1
		set_task(0.1, "Do_RegisterHamBot", id)
	}
	
	UnSet_BitVar(g_TempAttack, id)
	UnSet_BitVar(g_IsAlive, id)
}

public Do_RegisterHamBot(id)
{
	RegisterHamFromEntity(Ham_Spawn, id, "fw_PlayerSpawn_Post", 1)
}

public fw_PrecacheEvent_Post(type, const name[])
{
	if(equal(old_event, name)) g_Event_Thunderbolt = get_orig_retval()
}

public Get_Thunderbolt(id)
{
	g_Zoom[id] = ZOOM_NONE
	Set_BitVar(g_Had_Thunderbolt, id)
	
	give_item(id, weapon_thunderbolt)
	
	static weapon_ent; weapon_ent = fm_find_ent_by_owner(-1, weapon_thunderbolt, id)
	if(pev_valid(weapon_ent)) cs_set_weapon_ammo(weapon_ent, 10)
	
	cs_set_user_bpammo(id, CSW_THUNDERBOLT, DEFAULT_AMMO)
}

public Remove_Thunderbolt(id)
{
	g_Zoom[id] = ZOOM_NONE
	UnSet_BitVar(g_Had_Thunderbolt, id)
}

public Event_CurWeapon(id)
{
	static CSWID; CSWID = read_data(2)
	if(CSWID != CSW_THUNDERBOLT || !Get_BitVar(g_Had_Thunderbolt, id))
		return
		
	/*
	if(cs_get_user_zoom(id) > 1) // Zoom
	{
		emit_sound(id, CHAN_WEAPON, WeaponSounds[2], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
		if(!Get_BitVar(g_Zoomed, id))
		{
			//set_pev(id, pev_viewmodel2, SNIP_MODEL
			Set_BitVar(g_Zoomed, id)
		}
	} else { // Not Zoom
		emit_sound(id, CHAN_WEAPON, WeaponSounds[2], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
		set_pev(id, pev_viewmodel2, V_MODEL)
		UnSet_BitVar(g_Zoomed, id)
	}*/
	
	UpdateAmmo(id, -1, cs_get_user_bpammo(id, CSW_THUNDERBOLT))
}

public Event_Death()
{
	static Victim; Victim = read_data(2)
	UnSet_BitVar(g_IsAlive, Victim)
}

public CLCMD_HookWeapon(id)
{
	engclient_cmd(id, weapon_thunderbolt)
	return
}

public fw_UpdateClientData_Post(id, sendweapons, cd_handle)
{
	if(!Get_BitVar(g_IsAlive, id))
		return FMRES_IGNORED	
	if(get_user_weapon(id) == CSW_THUNDERBOLT && Get_BitVar(g_Had_Thunderbolt, id))
		set_cd(cd_handle, CD_flNextAttack, get_gametime() + 0.001) 
	
	return FMRES_HANDLED
}

public fw_PlaybackEvent(flags, invoker, eventid, Float:delay, Float:origin[3], Float:angles[3], Float:fparam1, Float:fparam2, iParam1, iParam2, bParam1, bParam2)
{
	if(eventid != g_Event_Thunderbolt)
		return FMRES_IGNORED
	if(!Get_BitVar(g_IsAlive, invoker))
		return FMRES_IGNORED		
	if(get_user_weapon(invoker) != CSW_THUNDERBOLT || !Get_BitVar(g_Had_Thunderbolt, invoker))
		return FMRES_IGNORED
	
	engfunc(EngFunc_PlaybackEvent, flags | FEV_HOSTONLY, invoker, eventid, delay, origin, angles, fparam1, fparam2, iParam1, iParam2, bParam1, bParam2)

	return FMRES_SUPERCEDE
}

public fw_SetModel(entity, model[])
{
	if(!pev_valid(entity))
		return FMRES_IGNORED
	
	static Classname[64]
	pev(entity, pev_classname, Classname, sizeof(Classname))
	
	if(!equal(Classname, "weaponbox"))
		return FMRES_IGNORED
	
	static id
	id = pev(entity, pev_owner)
	
	if(equal(model, old_w_model))
	{
		static weapon
		weapon = fm_get_user_weapon_entity(entity, CSW_THUNDERBOLT)
		
		if(!pev_valid(weapon))
			return FMRES_IGNORED
		
		if(Get_BitVar(g_Had_Thunderbolt, id))
		{
			UnSet_BitVar(g_Had_Thunderbolt, id)
			
			set_pev(weapon, pev_impulse, WEAPON_SECRETCODE)
			set_pev(weapon, pev_iuser4, cs_get_user_bpammo(id, CSW_THUNDERBOLT))
			
			engfunc(EngFunc_SetModel, entity, W_MODEL)
			
			return FMRES_SUPERCEDE
		}
	}

	return FMRES_IGNORED;
}

public fw_CmdStart(id, UcHandle, Seed)
{
	if(!Get_BitVar(g_IsAlive, id))
		return
	if(get_user_weapon(id) != CSW_THUNDERBOLT || !Get_BitVar(g_Had_Thunderbolt, id))
		return
	if(get_pdata_float(id, 83, 5) > 0.0)
		return
	
	static CurButton; CurButton = get_uc(UcHandle, UC_Buttons)
	if(CurButton & IN_ATTACK)
	{
		CurButton &= ~IN_ATTACK
		set_uc(UcHandle, UC_Buttons, CurButton)
		
		if(get_gametime() - RELOAD_TIME > CheckDelay[id])
		{
			Thunderbolt_Shooting(id)
			
			CheckDelay[id] = get_gametime()
		}
	}
	
	if(CurButton & IN_ATTACK2)
	{
		//CurButton &= ~IN_ATTACK2
		//set_uc(UcHandle, UC_Buttons, CurButton)
		//cs_set_user_
		//cs_set_user_zoom(id, CS_SET_NO_ZOOM, 1)
		
		if(get_gametime() - 0.5 > CheckDelay3[id])
		{
			switch(g_Zoom[id])
			{
				case ZOOM_NONE: Activate_Zoom(id, ZOOM_ACT)
				case ZOOM_ACT: Activate_Zoom(id, ZOOM_NONE)
				default: Activate_Zoom(id, ZOOM_NONE)
			}
			
			CheckDelay3[id] = get_gametime()
		}
	}
	
	if(get_gametime() - 0.25 > CheckDelay2[id])
	{
		static Body, Target; get_user_aiming(id, Target, Body, 99999)
		
		if(g_Zoom[id] == ZOOM_ACT)
		{
			if(Get_BitVar(g_IsAlive, Target))  
			{
				emit_sound(id, CHAN_WEAPON, WeaponSounds[1], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
				set_pev(id, pev_viewmodel2, SNIP_MODEL_R)
			} else {
				set_pev(id, pev_viewmodel2, SNIP_MODEL_B)
			}
		}
		
		CheckDelay2[id] = get_gametime()
	}
}

public Activate_Zoom(id, Level)
{
	switch(Level)
	{
		case ZOOM_NONE:
		{
			g_Zoom[id] = Level
			set_pev(id, pev_viewmodel2, V_MODEL)
		}
		case ZOOM_ACT:
		{
			g_Zoom[id] = Level
			
			set_pev(id, pev_viewmodel2, SNIP_MODEL_B)
			emit_sound(id, CHAN_WEAPON, WeaponSounds[2], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
		}
		default:
		{
			g_Zoom[id] = ZOOM_NONE
			Set_UserFov(id, 90)
			
			set_pev(id, pev_viewmodel2, V_MODEL)
		}
	}
}

public fw_EmitSound(id, channel, const sample[], Float:volume, Float:attn, flags, pitch)
{
	if(!Get_BitVar(g_IsAlive, id))
		return FMRES_IGNORED
	if(!Get_BitVar(g_TempAttack, id))
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
	if(!Get_BitVar(g_IsAlive, id))
		return FMRES_IGNORED
	if(!Get_BitVar(g_TempAttack, id))
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
	if(!Get_BitVar(g_IsAlive, id))
		return FMRES_IGNORED
	if(!Get_BitVar(g_TempAttack, id))
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

public fw_PlayerSpawn_Post(id) Set_BitVar(g_IsAlive, id)
public fw_AddToPlayer_Post(ent, id)
{
	if(pev(ent, pev_impulse) == WEAPON_SECRETCODE)
	{
		Set_BitVar(g_Had_Thunderbolt, id)
		cs_set_user_bpammo(id, CSW_THUNDERBOLT, pev(ent, pev_iuser4))
		
		set_pev(ent, pev_impulse, 0)
	}			
	
	message_begin(MSG_ONE_UNRELIABLE, g_Msg_WeaponList, _, id)
	write_string((Get_BitVar(g_Had_Thunderbolt, id) ? "weapon_sfsniperF" : "weapon_awp"))
	write_byte(1)
	write_byte(30)
	write_byte(-1)
	write_byte(-1)
	write_byte(0)
	write_byte(2)
	write_byte(CSW_THUNDERBOLT)
	write_byte(0)
	message_end()
}

public fw_Item_Deploy_Post(Ent)
{
	if(pev_valid(Ent) != 2)
		return
	static Id; Id = get_pdata_cbase(Ent, 41, 4)
	if(get_pdata_cbase(Id, 373) != Ent)
		return
	if(!Get_BitVar(g_Had_Thunderbolt, Id))
		return
	
	set_pev(Id, pev_viewmodel2, V_MODEL)
	set_pev(Id, pev_weaponmodel2, P_MODEL)
	
	Set_WeaponAnim(Id, TB_ANIM_DRAW)
	remove_task(Id+111)
}

public fw_Weapon_WeaponIdle_Post(Ent)
{
	if(pev_valid(Ent) != 2)
		return HAM_IGNORED	
	static Id; Id = get_pdata_cbase(Ent, 41, 4)
	if(get_pdata_cbase(Id, 373) != Ent)
		return HAM_IGNORED	
	if(!Get_BitVar(g_Had_Thunderbolt, Id))
		return HAM_IGNORED	

	if(get_pdata_float(Ent, 48, 4) <= 0.1) 
	{
		Set_WeaponAnim(Id, TB_ANIM_IDLE)
		set_pdata_float(Ent, 48, 20.0, 4)
	}
	
	return HAM_IGNORED	
}

public fw_Weapon_SecondaryAttack(Ent)
{
	static Id; Id = get_pdata_cbase(Ent, 41, 4)
	//if(get_pdata_cbase(Id, 373) != Ent)
		//return HAM_IGNORED	
	if(!Get_BitVar(g_Had_Thunderbolt, Id))
		return HAM_IGNORED	
		
	return HAM_SUPERCEDE
}

public Thunderbolt_Shooting(id)
{
	if(cs_get_user_bpammo(id, CSW_THUNDERBOLT) <= 0)
		return
		
	Set_BitVar(g_TempAttack, id)
	static Ent; Ent = fm_get_user_weapon_entity(id, CSW_KNIFE)
	if(pev_valid(Ent)) ExecuteHamB(Ham_Weapon_PrimaryAttack, Ent)
	UnSet_BitVar(g_TempAttack, id)
	
	cs_set_user_bpammo(id, CSW_THUNDERBOLT, cs_get_user_bpammo(id, CSW_THUNDERBOLT) - 1)
	set_pev(id, pev_viewmodel2, V_MODEL)
	
	set_task(RELOAD_TIME - 0.15, "Set_SniperModel", id+111)
	
	Set_WeaponAnim(id, TB_ANIM_SHOOT)
	emit_sound(id, CHAN_WEAPON, WeaponSounds[0], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)	
	
	Make_FakePunch(id)
	
	// Set Idle
	Ent = fm_get_user_weapon_entity(id, CSW_THUNDERBOLT)
	if(pev_valid(Ent)) 
	{
		set_pdata_float(id, 83, RELOAD_TIME, 5)
		
		set_pdata_float(Ent, 46, RELOAD_TIME, 4)
		set_pdata_float(Ent, 47, RELOAD_TIME, 4)
		set_pdata_float(Ent, 48, RELOAD_TIME + 0.25, 4)
	}
		
	Check_Damage(id)
		
	// Set Bullet reject
	set_pdata_float(id, 111, 0.0)
}

public Set_SniperModel(id)
{
	id -= 111
	if(!is_user_alive(id))
		return
	if(!Get_BitVar(g_Had_Thunderbolt, id))
		return
	if(g_Zoom[id] != ZOOM_ACT)
		return
		
	g_Zoom[id] = ZOOM_ACT
	set_pev(id, pev_viewmodel2, SNIP_MODEL_B)
}

public Make_FakePunch(id)
{
	static Float:PunchAngles[3]
	PunchAngles[0] = random_float(-3.5, -7.0)
	
	set_pev(id, pev_punchangle, PunchAngles)
}

public Check_Damage(id)
{
	static Float:StartOrigin[3], Float:EndOrigin[3], Float:EndOrigin2[3]
	
	Stock_Get_Postion(id, 40.0, 7.5, -5.0, StartOrigin)
	Stock_Get_Postion(id, 4096.0, 0.0, 0.0, EndOrigin)
	
	static TrResult; TrResult = create_tr2()
	engfunc(EngFunc_TraceLine, StartOrigin, EndOrigin, IGNORE_MONSTERS, id, TrResult) 
	get_tr2(TrResult, TR_vecEndPos, EndOrigin2)
	free_tr2(TrResult)
	
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_BEAMPOINTS)
	engfunc(EngFunc_WriteCoord, StartOrigin[0])
	engfunc(EngFunc_WriteCoord, StartOrigin[1])
	engfunc(EngFunc_WriteCoord, StartOrigin[2])
	engfunc(EngFunc_WriteCoord, EndOrigin2[0])
	engfunc(EngFunc_WriteCoord, EndOrigin2[1])
	engfunc(EngFunc_WriteCoord, EndOrigin2[2])
	write_short(g_Beam_SprId)
	write_byte(0)
	write_byte(0)
	write_byte(10)
	write_byte(25)
	write_byte(0)
	write_byte(0)
	write_byte(0)
	write_byte(200)
	write_byte(200)
	write_byte(0)
	message_end()	

	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_SPARKS) //TE_SPARKS
	engfunc(EngFunc_WriteCoord, EndOrigin2[0])
	engfunc(EngFunc_WriteCoord, EndOrigin2[1])
	engfunc(EngFunc_WriteCoord, EndOrigin2[2])
	message_end()	
	
	DealDamage(id, StartOrigin, EndOrigin2)	
}

public DealDamage(id, Float:Start[3], Float:End[3])
{
	static TrResult; TrResult = create_tr2()
	
	// Trace First Time
	engfunc(EngFunc_TraceLine, Start, End, DONT_IGNORE_MONSTERS, id, TrResult) 
	new pHit1; pHit1 = get_tr2(TrResult, TR_pHit)
	static Float:End1[3]; get_tr2(TrResult, TR_vecEndPos, End1)
	
	if(is_user_alive(pHit1)) 
	{
		do_attack(id, pHit1, 0, float(DAMAGE) * 1.5)
		engfunc(EngFunc_TraceLine, End1, End, DONT_IGNORE_MONSTERS, pHit1, TrResult) 
	} else engfunc(EngFunc_TraceLine, End1, End, DONT_IGNORE_MONSTERS, -1, TrResult) 
	
	// Trace Second Time
	new pHit2; pHit2 = get_tr2(TrResult, TR_pHit)
	static Float:End2[3]; get_tr2(TrResult, TR_vecEndPos, End2)
	
	if(is_user_alive(pHit2)) 
	{
		do_attack(id, pHit2, 0, float(DAMAGE) * 1.5)
		engfunc(EngFunc_TraceLine, End2, End, DONT_IGNORE_MONSTERS, pHit2, TrResult) 
	} else engfunc(EngFunc_TraceLine, End2, End, DONT_IGNORE_MONSTERS, -1, TrResult) 
	
	// Trace Third Time
	new pHit3; pHit3 = get_tr2(TrResult, TR_pHit)
	static Float:End3[3]; get_tr2(TrResult, TR_vecEndPos, End3)
	
	if(is_user_alive(pHit3)) 
	{
		do_attack(id, pHit3, 0, float(DAMAGE) * 1.5)
		engfunc(EngFunc_TraceLine, End3, End, DONT_IGNORE_MONSTERS, pHit3, TrResult) 
	} else engfunc(EngFunc_TraceLine, End3, End, DONT_IGNORE_MONSTERS, -1, TrResult) 
	
	// Trace Fourth Time
	new pHit4; pHit4 = get_tr2(TrResult, TR_pHit)
	if(is_user_alive(pHit4)) do_attack(id, pHit4, 0, float(DAMAGE) * 1.5)

	free_tr2(TrResult)
}

public UpdateAmmo(Id, Ammo, BpAmmo)
{
	static weapon_ent; weapon_ent = fm_get_user_weapon_entity(Id, CSW_THUNDERBOLT)
	if(pev_valid(weapon_ent))
	{
		if(BpAmmo > 0) cs_set_weapon_ammo(weapon_ent, 1)
		else cs_set_weapon_ammo(weapon_ent, 0)
	}
	
	engfunc(EngFunc_MessageBegin, MSG_ONE_UNRELIABLE, g_Msg_CurWeapon, {0, 0, 0}, Id)
	write_byte(1)
	write_byte(CSW_THUNDERBOLT)
	write_byte(-1)
	message_end()
	
	message_begin(MSG_ONE_UNRELIABLE, g_Msg_AmmoX, _, Id)
	write_byte(1)
	write_byte(BpAmmo)
	message_end()
	
	cs_set_user_bpammo(Id, CSW_THUNDERBOLT, BpAmmo)
}

stock Set_WeaponAnim(id, anim)
{
	set_pev(id, pev_weaponanim, anim)
	
	message_begin(MSG_ONE_UNRELIABLE, SVC_WEAPONANIM, {0, 0, 0}, id)
	write_byte(anim)
	write_byte(pev(id, pev_body))
	message_end()
}

stock Stock_Get_Postion(id,Float:forw,Float:right, Float:up,Float:vStart[])
{
	static Float:vOrigin[3], Float:vAngle[3], Float:vForward[3], Float:vRight[3], Float:vUp[3]
	
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
	new ptr; ptr = create_tr2() 
	engfunc(EngFunc_TraceLine, fStart, fAimOrigin, DONT_IGNORE_MONSTERS, iAttacker, ptr)
	new pHit; pHit = get_tr2(ptr, TR_pHit)
	new iHitgroup; iHitgroup = get_tr2(ptr, TR_iHitgroup)
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
		new iAngleToVictim; iAngleToVictim = get_angle_to_target(iAttacker, fVicOrigin)
		iAngleToVictim = abs(iAngleToVictim)
		new Float:fDis; fDis = 2.0 * get_distance_f(fStart, fAimInVictim) * floatsin( float(iAngleToVictim) * 0.5, degrees )
		new Float:fVicSize[3]
		pev(iVictim, pev_size , fVicSize)
		if ( fDis <= fVicSize[0] * 0.5 )
		{
			// TraceLine from fStart to aimOrigin in iVictim
			new ptr2; ptr2 = create_tr2() 
			engfunc(EngFunc_TraceLine, fStart, fAimInVictim, DONT_IGNORE_MONSTERS, iAttacker, ptr2)
			new pHit2; pHit2 = get_tr2(ptr2, TR_pHit)
			new iHitgroup2; iHitgroup2 = get_tr2(ptr2, TR_iHitgroup)
			
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
			
			new ptr3; ptr3 = create_tr2() 
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

	// ExecuteHam
	fake_trake_attack(iAttacker, iVictim, fDamage, fDirection, ptr)
	
	// free ptr
	free_tr2(ptr)
}

stock fake_trake_attack(iAttacker, iVictim, Float:fDamage, Float:fDirection[3], iTraceHandle, iDamageBit = (DMG_NEVERGIB | DMG_BULLET))
{
	ExecuteHamB(Ham_TraceAttack, iVictim, iAttacker, fDamage, fDirection, iTraceHandle, iDamageBit)
}

stock fake_take_damage(iAttacker, iVictim, Float:fDamage, iInflictor, iDamageBit = (DMG_NEVERGIB | DMG_BULLET))
{
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
	
	new iResult; iResult = get_angle_between_vectors(fV1, fV2)
	
	if (TargetSize > 0.0)
	{
		new Float:fTan; fTan = TargetSize / get_distance_f(fOrigin, fTarget)
		new fAngleToTargetSize; fAngleToTargetSize = floatround( floatatan(fTan, degrees) )
		iResult -= (iResult > 0) ? fAngleToTargetSize : -fAngleToTargetSize
	}
	
	return iResult
}

stock get_angle_between_vectors(const Float:fV1[3], const Float:fV2[3])
{
	new Float:fA1[3], Float:fA2[3]
	engfunc(EngFunc_VecToAngles, fV1, fA1)
	engfunc(EngFunc_VecToAngles, fV2, fA2)
	
	new iResult; iResult = floatround(fA1[1] - fA2[1])
	iResult = iResult % 360
	iResult = (iResult > 180) ? (iResult - 360) : iResult
	
	return iResult
}

stock Set_UserFov(id, FOV)
{
	if(!is_user_connected(id))
		return
		
	set_pdata_int(id, 363, FOV, 5)
	set_pev(id, pev_fov, FOV)
}
