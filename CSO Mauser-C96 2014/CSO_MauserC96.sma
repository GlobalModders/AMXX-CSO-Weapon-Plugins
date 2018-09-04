#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <cstrike>
#include <fun>
#include <xs>

#define PLUGIN "[CSO] Mauser C94"
#define VERSION "1.0"
#define AUTHOR "Dias"

#define DAMAGE 24
#define RECOIL 0.25
#define DEFAULT_CLIP 10

#define WP_BASEON CSW_FIVESEVEN
#define wp_baseon_classname "weapon_fiveseven"
#define WP_KEY 221132

#define TASK_BURST 123123

new const wp_model[3][] = {
	"models/v_mauserc96.mdl",
	"models/p_mauserc96.mdl",
	"models/w_mauserc96.mdl"
}

new const wp_sound[6][] = {
	"weapons/mauser96_boltpull.wav",
	"weapons/mauser96_clipin.wav",
	"weapons/mauser96_clipout.wav",
	"weapons/mauser96_draw.wav",
	"weapons/mauser96_empty_boltpull.wav",
	"weapons/mauser96-1.wav"
}

enum
{
	ANIM_IDLE = 0,
	ANIM_IDLE_EMPTY,
	ANIM_SHOOT,
	ANIM_SHOOT_EMPTY,
	ANIM_RELOAD,
	ANIM_RELOAD_EMPTY,
	ANIM_DRAW,
	ANIM_DRAW_EMPTY
}

// HardCode
new g_had_wp[33], m_iBlood[2], Float:g_recoil[33], g_clip[33]
new g_wp, g_smokepuff_id, g_Event_FS

const PRIMARY_WEAPONS_BIT_SUM = (1<<CSW_SCOUT)|(1<<CSW_XM1014)|(1<<CSW_MAC10)|(1<<CSW_MAC10)|(1<<CSW_UMP45)|(1<<CSW_SG550)|(1<<CSW_MAC10)|(1<<CSW_FAMAS)|(1<<CSW_AWP)|(1<<CSW_MP5NAVY)|(1<<CSW_M249)|(1<<CSW_M3)|(1<<CSW_M4A1)|(1<<CSW_TMP)|(1<<CSW_G3SG1)|(1<<CSW_SG552)|(1<<CSW_AK47)|(1<<CSW_P90)

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)

	register_event("CurWeapon", "Event_CurWeapon", "be", "1=1")
	
	register_forward(FM_UpdateClientData, "fw_UpdateClientData_Post", 1)
	register_forward(FM_CmdStart, "fw_CmdStart")
	register_forward(FM_SetModel, "fw_SetModel")
	register_forward(FM_PlaybackEvent, "fw_PlaybackEvent")	

	RegisterHam(Ham_Item_AddToPlayer, wp_baseon_classname, "ham_add_wp", 1)
	RegisterHam(Ham_Item_PostFrame, wp_baseon_classname, "ham_item_postframe")
	RegisterHam(Ham_TraceAttack, "worldspawn", "ham_traceattack", 1)
	RegisterHam(Ham_TraceAttack, "player", "ham_traceattack", 1)
	
	RegisterHam(Ham_Weapon_WeaponIdle, wp_baseon_classname, "fw_Weapon_WeaponIdle_Post", 1)
	RegisterHam(Ham_Item_Deploy, wp_baseon_classname, "fw_Item_Deploy_Post", 1)	
	RegisterHam(Ham_Item_PostFrame, wp_baseon_classname, "fw_PostFrame")	
	RegisterHam(Ham_Weapon_Reload, wp_baseon_classname, "fw_Reload")	
	RegisterHam(Ham_Weapon_Reload, wp_baseon_classname, "fw_Reload_Post", 1)		
	RegisterHam(Ham_Weapon_PrimaryAttack, wp_baseon_classname, "fw_PrimaryAttack")
	RegisterHam(Ham_Weapon_PrimaryAttack, wp_baseon_classname, "fw_PrimaryAttack_Post", 1)
	
	register_clcmd("say /get", "get_weapon", ADMIN_KICK)
}

public plugin_precache()
{
	for(new i = 0; i < sizeof(wp_model); i++)
		engfunc(EngFunc_PrecacheModel, wp_model[i])
	for(new i = 0; i < sizeof(wp_sound); i++)
		engfunc(EngFunc_PrecacheSound, wp_sound[i])	

	m_iBlood[0] = precache_model("sprites/blood.spr")
	m_iBlood[1] = precache_model("sprites/bloodspray.spr")	
	g_smokepuff_id = engfunc(EngFunc_PrecacheModel, "sprites/wall_puff1.spr")
	
	register_forward(FM_PrecacheEvent, "fw_PrecacheEvent_Post", 1)
}

public fw_PrecacheEvent_Post(type, const name[])
{
	if(equal("events/fiveseven.sc", name)) g_Event_FS = get_orig_retval()		
}

public zd_weapon_bought(id, itemid)
{
	if(itemid != g_wp)
		return PLUGIN_HANDLED
	
	get_weapon(id)
	
	return PLUGIN_HANDLED
}

public zd_weapon_remove(id, itemid)
{
	if(itemid != g_wp)
		return PLUGIN_HANDLED
	
	remove_weapon(id)
	
	return PLUGIN_HANDLED
}

public zd_weapon_addammo(id, itemid)
{
	if(itemid != g_wp)
		return PLUGIN_HANDLED
	
	cs_set_user_bpammo(id, CSW_FIVESEVEN, 200)
	
	return PLUGIN_HANDLED
}

public get_weapon(id)
{
	g_had_wp[id] = 1

	give_item(id, wp_baseon_classname)
	
	static ent; ent = fm_get_user_weapon_entity(id, CSW_FIVESEVEN)
	if(pev_valid(ent)) cs_set_weapon_ammo(ent, DEFAULT_CLIP)
	
	cs_set_user_bpammo(id, CSW_FIVESEVEN, 90)
	
	engfunc(EngFunc_MessageBegin, MSG_ONE_UNRELIABLE, get_user_msgid("CurWeapon"), {0, 0, 0}, id)
	write_byte(1)
	write_byte(CSW_FIVESEVEN)
	write_byte(DEFAULT_CLIP)
	message_end()	
}

public remove_weapon(id)
{
	g_had_wp[id] = 0
}

public hook_change(id)
{
	engclient_cmd(id, wp_baseon_classname)
	return PLUGIN_HANDLED
}

public event_checkweapon(id)
{
	if(!is_user_alive(id))
		return PLUGIN_HANDLED
	//if(zp_get_user_zombie(id) || zp_get_user_survivor(id))
	//	return PLUGIN_HANDLED
	if(get_user_weapon(id) != WP_BASEON || !g_had_wp[id])
		return PLUGIN_HANDLED
		
	set_pev(id, pev_viewmodel2, wp_model[0])
	set_pev(id, pev_weaponmodel2, wp_model[1])

	return PLUGIN_HANDLED
}

public fw_UpdateClientData_Post(id, sendweapons, cd_handle)
{
	if(!is_user_alive(id) || !is_user_connected(id))
		return FMRES_IGNORED
	//if(zp_get_user_zombie(id) || zp_get_user_survivor(id))
	//	return FMRES_IGNORED
	if(get_user_weapon(id) != WP_BASEON || !g_had_wp[id])
		return FMRES_IGNORED
	
	set_cd(cd_handle, CD_flNextAttack, halflife_time() + 0.001) 
	
	return FMRES_HANDLED
}

public fw_CmdStart(id, uc_handle, seed)
{
	if(!is_user_alive(id) || !is_user_connected(id))
		return FMRES_HANDLED
	//if(zp_get_user_zombie(id) || zp_get_user_survivor(id))
	//	return FMRES_HANDLED
	if(get_user_weapon(id) != WP_BASEON || !g_had_wp[id])
		return FMRES_HANDLED
	
	static CurButton
	CurButton = get_uc(uc_handle, UC_Buttons)
		
	return FMRES_HANDLED
}

public fw_SetModel(ent, const model[])
{
	if(!is_valid_ent(ent))
		return FMRES_IGNORED
	
	static szClassName[33]
	entity_get_string(ent, EV_SZ_classname, szClassName, charsmax(szClassName))
	
	if(!equal(szClassName, "weaponbox"))
		return FMRES_IGNORED
	
	static iOwner
	iOwner = entity_get_edict(ent, EV_ENT_owner)
	
	if(equal(model, "models/w_fiveseven.mdl"))
	{
		static at4cs
		at4cs = find_ent_by_owner(-1, "weapon_fiveseven", ent)
		
		if(!is_valid_ent(at4cs))
			return FMRES_IGNORED;
		
		if(g_had_wp[iOwner])
		{
			entity_set_int(at4cs, EV_INT_impulse, WP_KEY)
			g_had_wp[iOwner] = 0
			entity_set_model(ent, wp_model[2])
			
			return FMRES_SUPERCEDE
		}
	}
	
	return FMRES_IGNORED
}


public Event_CurWeapon(id)
{
	if(!is_user_alive(id) || !is_user_connected(id))
		return FMRES_HANDLED
	//if(zp_get_user_zombie(id) || zp_get_user_survivor(id))
	//	return FMRES_HANDLED
	if(get_user_weapon(id) != WP_BASEON || !g_had_wp[id])
		return FMRES_HANDLED

	static Float:Delay, Float:Delay2
	static Ent; Ent = fm_get_user_weapon_entity(id, CSW_FIVESEVEN)
	if(!pev_valid(Ent)) return
	
	Delay = get_pdata_float(Ent, 46, 4) * 0.75
	Delay2 = get_pdata_float(Ent, 47, 4) * 0.75
	
	if(Delay > 0.0)
	{
		set_pdata_float(Ent, 46, Delay, 4)
		set_pdata_float(Ent, 47, Delay2, 4)
	}
}


public fw_Weapon_WeaponIdle_Post(Ent)
{
	if(pev_valid(Ent) != 2)
		return HAM_IGNORED	
	static Id; Id = get_pdata_cbase(Ent, 41, 4)
	if(get_pdata_cbase(Id, 373) != Ent)
		return HAM_IGNORED	
	if(!g_had_wp[Id])
		return HAM_IGNORED	
		
	if(get_pdata_float(Ent, 48, 4) <= 0.1) 
	{
		if(cs_get_weapon_ammo(Ent) > 0) set_weapon_anim(Id, ANIM_IDLE)
		else set_weapon_anim(Id, ANIM_IDLE_EMPTY)
	}
	
	return HAM_IGNORED	
}

public fw_Item_Deploy_Post(Ent)
{
	if(pev_valid(Ent) != 2)
		return
	static Id; Id = get_pdata_cbase(Ent, 41, 4)
	if(get_pdata_cbase(Id, 373) != Ent)
		return
	if(!g_had_wp[Id])
		return
	
	set_pev(Id, pev_viewmodel2, wp_model[0])
	set_pev(Id, pev_weaponmodel2, wp_model[1])
	
	if(cs_get_weapon_ammo(Ent) > 0) set_weapon_anim(Id, ANIM_DRAW)
	else set_weapon_anim(Id, ANIM_DRAW_EMPTY)
}

public fw_PlaybackEvent(flags, invoker, eventid, Float:delay, Float:origin[3], Float:angles[3], Float:fparam1, Float:fparam2, iParam1, iParam2, bParam1, bParam2)
{
	if (!is_user_connected(invoker))
		return FMRES_IGNORED	
	if(get_user_weapon(invoker) != CSW_FIVESEVEN || !g_had_wp[invoker])
		return FMRES_IGNORED
	if(eventid != g_Event_FS)
		return FMRES_IGNORED
	
	engfunc(EngFunc_PlaybackEvent, flags | FEV_HOSTONLY, invoker, eventid, delay, origin, angles, fparam1, fparam2, iParam1, iParam2, bParam1, bParam2)
		
	set_weapon_anim(invoker, ANIM_SHOOT)
	emit_sound(invoker, CHAN_WEAPON, wp_sound[5], 1.0, ATTN_NORM, 0, PITCH_NORM)
	
	return FMRES_IGNORED
}

public ham_add_wp(ent, id)
{
	if(entity_get_int(ent, EV_INT_impulse) == WP_KEY)
	{
		g_had_wp[id] = 1
	}			
}

public ham_item_postframe(iEnt)
{
	if (!pev_valid(iEnt)) return HAM_IGNORED
	
	new id = pev(iEnt, pev_owner)
	
	if(!is_user_alive(id) || !is_user_connected(id))
		return HAM_IGNORED
	//if(zp_get_user_zombie(id) || zp_get_user_survivor(id))
	//	return HAM_IGNORED
	if(get_user_weapon(id) != WP_BASEON || !g_had_wp[id])
		return HAM_IGNORED		
	
	return HAM_IGNORED
}

public ham_traceattack(ent, attacker, Float:Damage, Float:fDir[3], ptr, iDamageType)
{
	if(!is_user_alive(attacker) || !is_user_connected(attacker))
		return HAM_IGNORED
	//if(zp_get_user_zombie(id) || zp_get_user_survivor(id))
	//	return HAM_IGNORED
	if(get_user_weapon(attacker) != WP_BASEON || !g_had_wp[attacker])
		return HAM_IGNORED
	
	static Float:flEnd[3], Float:vecPlane[3]
	
	get_tr2(ptr, TR_vecEndPos, flEnd)
	get_tr2(ptr, TR_vecPlaneNormal, vecPlane)		
		
	if(!is_user_alive(ent))
	{
		make_bullet(attacker, flEnd)
		fake_smoke(attacker, ptr)
	} else {
		static Float:flEnd[3]
		get_tr2(ptr, TR_vecEndPos, flEnd)

		create_blood(flEnd)
	}
		
	SetHamParamFloat(3, float(DAMAGE))		
	
	return HAM_HANDLED
}

public fw_PrimaryAttack(ent)
{
	static id; id = pev(ent, pev_owner)
	
	set_pdata_int( ent, 64, -1)
	pev(id, pev_punchangle, g_recoil[id])
	
	return HAM_IGNORED	
}

public fw_PrimaryAttack_Post(ent)
{
	static id; id = pev(ent,pev_owner)
	if(g_had_wp[id])
	{
		/*
		static Float:push[3]
		pev(id,pev_punchangle,push)
		xs_vec_sub(push, g_recoil[id],push)
		
		push[1] += random_float(-1.5, 1.5)
		xs_vec_mul_scalar(push, RECOIL,push)
		xs_vec_add(push, g_recoil[id], push)
		set_pev(id, pev_punchangle, push)*/
		
		
	}
	
	return HAM_IGNORED
}


public fw_PostFrame(ent)
{
	if(!pev_valid(ent))
		return HAM_IGNORED
	
	static id
	id = pev(ent, pev_owner)
	
	if(is_user_alive(id) && is_user_connected(id) && g_had_wp[id])
	{	
		static Float:flNextAttack; flNextAttack = get_pdata_float(id, 83, 5)
		
		static bpammo
		bpammo = cs_get_user_bpammo(id, CSW_FIVESEVEN)
		
		static iClip; iClip = get_pdata_int(ent, 51, 4)
		static fInReload; fInReload = get_pdata_int(ent, 54, 4)
		
		if(fInReload && flNextAttack <= 0.0)
		{
			static temp1
			temp1 = min(DEFAULT_CLIP - iClip, bpammo)

			set_pdata_int(ent, 51, iClip + temp1, 4)
			cs_set_user_bpammo(id, CSW_FIVESEVEN, bpammo - temp1)		
			
			set_pdata_int(ent, 54, 0, 4)
			
			fInReload = 0
		}		
	}
	
	return HAM_IGNORED	
}

public fw_Reload(ent)
{
	if(!pev_valid(ent))
		return HAM_IGNORED
	
	static id
	id = pev(ent, pev_owner)
	
	if(is_user_alive(id) && is_user_connected(id) && g_had_wp[id])
	{		
		g_clip[id] = -1
		
		static bpammo
		bpammo = cs_get_user_bpammo(id, CSW_FIVESEVEN)
		
		static iClip; iClip = get_pdata_int(ent, 51, 4)
		
		if (bpammo <= 0)
			return HAM_SUPERCEDE
		
		if(iClip >= DEFAULT_CLIP)
			return HAM_SUPERCEDE		
			
		
		g_clip[id] = iClip
	}
	
	return HAM_IGNORED
}

public fw_Reload_Post(ent)
{
	if(!pev_valid(ent))
		return HAM_IGNORED
	
	static id
	id = pev(ent, pev_owner)
	
	if(is_user_alive(id) && is_user_connected(id) && g_had_wp[id])
	{	
		if (g_clip[id] == -1)
			return HAM_IGNORED
		
		static Float:reload_time
		reload_time = 2.2
		
		set_pdata_int(ent, 51, g_clip[id], 4)
		set_pdata_float(ent, 48, reload_time, 4)
		set_pdata_float(id, 83, reload_time, 5)
		set_pdata_int(ent, 54, 1, 4)

		if(g_clip[id] > 0) set_weapon_anim(id, 4)
		else set_weapon_anim(id, 5)
	}
	
	return HAM_IGNORED
}

stock set_weapon_anim(id, anim)
{
	set_pev(id, pev_weaponanim, anim)

	message_begin(MSG_ONE_UNRELIABLE, SVC_WEAPONANIM, _, id)
	write_byte(anim)
	write_byte(pev(id,pev_body))
	message_end()
}

stock drop_weapons(id, dropwhat)
{
	static weapons[32], num, i, weaponid
	num = 0
	get_user_weapons(id, weapons, num)
	
	for (i = 0; i < num; i++)
	{
		weaponid = weapons[i]
		
		if (dropwhat == 1 && ((1<<weaponid) & PRIMARY_WEAPONS_BIT_SUM))
		{
			static wname[32]
			get_weaponname(weaponid, wname, sizeof wname - 1)
			engclient_cmd(id, "drop", wname)
		}
	}
}

stock make_bullet(id, Float:Origin[3])
{
	// Find target
	new decal = random_num(41, 45)
	const loop_time = 2
	
	static Body, Target
	get_user_aiming(id, Target, Body, 999999)
	
	if(is_user_connected(Target))
		return
	
	for(new i = 0; i < loop_time; i++)
	{
		// Put decal on "world" (a wall)
		message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
		write_byte(TE_WORLDDECAL)
		engfunc(EngFunc_WriteCoord, Origin[0])
		engfunc(EngFunc_WriteCoord, Origin[1])
		engfunc(EngFunc_WriteCoord, Origin[2])
		write_byte(decal)
		message_end()
		
		// Show sparcles
		message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
		write_byte(TE_GUNSHOTDECAL)
		engfunc(EngFunc_WriteCoord, Origin[0])
		engfunc(EngFunc_WriteCoord, Origin[1])
		engfunc(EngFunc_WriteCoord, Origin[2])
		write_short(id)
		write_byte(decal)
		message_end()
	}
}

public fake_smoke(id, trace_result)
{
	static Float:vecSrc[3], Float:vecEnd[3], TE_FLAG
	
	get_weapon_attachment(id, vecSrc)
	global_get(glb_v_forward, vecEnd)
    
	xs_vec_mul_scalar(vecEnd, 8192.0, vecEnd)
	xs_vec_add(vecSrc, vecEnd, vecEnd)

	get_tr2(trace_result, TR_vecEndPos, vecSrc)
	get_tr2(trace_result, TR_vecPlaneNormal, vecEnd)
    
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
	write_short(g_smokepuff_id)
	write_byte(2)
	write_byte(50)
	write_byte(TE_FLAG)
	message_end()
}


stock get_weapon_attachment(id, Float:output[3], Float:fDis = 40.0)
{ 
	new Float:vfEnd[3], viEnd[3] 
	get_user_origin(id, viEnd, 3)  
	IVecFVec(viEnd, vfEnd) 
	
	new Float:fOrigin[3], Float:fAngle[3]
	
	pev(id, pev_origin, fOrigin) 
	pev(id, pev_view_ofs, fAngle)
	
	xs_vec_add(fOrigin, fAngle, fOrigin) 
	
	new Float:fAttack[3]
	
	xs_vec_sub(vfEnd, fOrigin, fAttack)
	xs_vec_sub(vfEnd, fOrigin, fAttack) 
	
	new Float:fRate
	
	fRate = fDis / vector_length(fAttack)
	xs_vec_mul_scalar(fAttack, fRate, fAttack)
	
	xs_vec_add(fOrigin, fAttack, output)
}


stock create_blood(const Float:origin[3])
{
	// Show some blood :)
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY) 
	write_byte(TE_BLOODSPRITE)
	engfunc(EngFunc_WriteCoord, origin[0])
	engfunc(EngFunc_WriteCoord, origin[1])
	engfunc(EngFunc_WriteCoord, origin[2])
	write_short(m_iBlood[1])
	write_short(m_iBlood[0])
	write_byte(75)
	write_byte(5)
	message_end()
}
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang1042\\ f0\\ fs16 \n\\ par }
*/
