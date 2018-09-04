#include <amxmodx>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <cstrike>
#include <fun>

#define PLUGIN "[CSO] Skull-11"
#define VERSION "1.0"
#define AUTHOR "Dias"

#define CSW_GATLING CSW_M3
#define weapon_gatling "weapon_m3"
#define WEAPON_ANIMEXT "m249"
#define DEFAULT_W_MODEL "models/w_m3.mdl"
#define WEAPON_SECRET_CODE 1942
#define old_event "events/m3.sc"

#define DAMAGE 112
#define SPEED 0.35
#define RECOIL 0.75
#define RELOAD_TIME 4.0
#define DEFAULT_CLIP 28
#define DEFAULT_BPAMMO 180

new const WeaponModel[3][] =
{
	"models/v_skull11.mdl", // V
	"models/p_skull11.mdl", // P
	"models/w_skull11.mdl" // W
}

new const WeaponSound[4][] =
{
	"weapons/skull11_shoot1.wav",
	"weapons/skull11_boltpull.wav",
	"weapons/skull11_clipin.wav",
	"weapons/skull11_clipout.wav"
}

enum
{
	GATLING_ANIM_IDLE = 0,
	GATLING_ANIM_SHOOT1,
	GATLING_ANIM_SHOOT2,
	GATLING_ANIM_RELOAD,
	GATLING_ANIM_DRAW
}

const PDATA_SAFE = 2
const OFFSET_LINUX_WEAPONS = 4
const OFFSET_LINUX_PLAYER = 5
const OFFSET_WEAPONOWNER = 41
const m_iClip = 51
const m_fInReload = 54
const m_flNextAttack = 83
const m_szAnimExtention = 492

new g_Gatling
new g_had_gatling[33], Float:g_punchangles[33][3], g_gatling_event, g_smokepuff_id, m_iBlood[2], g_ham_bot
new g_Zoom, Float:g_ZoomTime[33]


// MACROS
#define Get_BitVar(%1,%2) (%1 & (1 << (%2 & 31)))
#define Set_BitVar(%1,%2) %1 |= (1 << (%2 & 31))
#define UnSet_BitVar(%1,%2) %1 &= ~(1 << (%2 & 31))


public plugin_init() 
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	register_event("CurWeapon", "Event_CurWeapon", "be", "1=1")
	
	register_forward(FM_CmdStart, "fw_CmdStart")
	register_forward(FM_SetModel, "fw_SetModel")
	register_forward(FM_UpdateClientData, "fw_UpdateClientData_Post", 1)
	register_forward(FM_PlaybackEvent, "fw_PlaybackEvent")	
	
	RegisterHam(Ham_TraceAttack, "worldspawn", "fw_TraceAttack")
	RegisterHam(Ham_TraceAttack, "player", "fw_TraceAttack")		
	
	RegisterHam(Ham_Item_Deploy, weapon_gatling, "fw_Item_Deploy_Post", 1)
	RegisterHam(Ham_Weapon_Reload, weapon_gatling, "fw_Weapon_Reload_Post", 1)
	RegisterHam(Ham_Item_PostFrame, weapon_gatling, "fw_Item_PostFrame")
	RegisterHam(Ham_Item_AddToPlayer, weapon_gatling, "fw_Item_AddToPlayer_Post", 1)
	RegisterHam(Ham_Weapon_PrimaryAttack, weapon_gatling, "fw_Weapon_PrimaryAttack")
	RegisterHam(Ham_Weapon_PrimaryAttack, weapon_gatling, "fw_Weapon_PrimaryAttack_Post", 1)
	
	register_clcmd("say /get", "get_gatling")
}

public plugin_precache()
{
	new i
	
	for(i = 0; i < sizeof(WeaponModel); i++)
		engfunc(EngFunc_PrecacheModel, WeaponModel[i])
	for(i = 0; i < sizeof(WeaponSound); i++)
		engfunc(EngFunc_PrecacheSound, WeaponSound[i])

	g_smokepuff_id = engfunc(EngFunc_PrecacheModel, "sprites/wall_puff1.spr")
	m_iBlood[0] = engfunc(EngFunc_PrecacheModel, "sprites/blood.spr")
	m_iBlood[1] = engfunc(EngFunc_PrecacheModel, "sprites/bloodspray.spr")		
	
	register_forward(FM_PrecacheEvent, "fw_PrecacheEvent_Post", 1)	
}

public fw_PrecacheEvent_Post(type, const name[])
{
	if(equal(old_event, name))
		g_gatling_event = get_orig_retval()
}

public client_putinserver(id)
{
	if(is_user_bot(id) && !g_ham_bot)
	{
		g_ham_bot = 1
		set_task(0.1, "Do_Register_Ham", id)
	}
}

public Do_Register_Ham(id)
{
	RegisterHamFromEntity(Ham_TraceAttack, id, "fw_TraceAttack")	
}

public zd_weapon_bought(id, ItemID)
{
	if(ItemID == g_Gatling) get_gatling(id)
}

public zd_weapon_remove(id, ItemID)
{
	if(ItemID == g_Gatling) remove_gatling(id)
}

public zd_weapon_addammo(id, ItemID)
{
	if(ItemID == g_Gatling) cs_set_user_bpammo(id, CSW_GATLING, DEFAULT_BPAMMO)
}

public get_gatling(id)
{
	UnSet_BitVar(g_Zoom, id)
	
	g_had_gatling[id] = 1
	give_item(id, weapon_gatling)
	
	// Set Clip
	static ent; ent = fm_get_user_weapon_entity(id, CSW_GATLING)
	if(pev_valid(ent)) cs_set_weapon_ammo(ent, DEFAULT_CLIP)
	
	// Set BpAmmo
	cs_set_user_bpammo(id, CSW_GATLING, DEFAULT_BPAMMO)
	
	// Update Ammo
	update_ammo(id, CSW_GATLING, DEFAULT_CLIP, DEFAULT_BPAMMO)
}

public remove_gatling(id)
{
	g_had_gatling[id] = 0
}

public hook_weapon(id)
{
	client_cmd(id, weapon_gatling)
	return PLUGIN_HANDLED
}

public Event_CurWeapon(id)
{
	if(!is_user_alive(id))
		return
	if(get_user_weapon(id) != CSW_GATLING || !g_had_gatling[id])
		return
		
	// Speed
	static ent; ent = fm_get_user_weapon_entity(id, CSW_GATLING)
	if(!pev_valid(ent)) 
		return
		
	set_pdata_float(ent, 46, get_pdata_float(ent, 46, OFFSET_LINUX_WEAPONS) * SPEED, OFFSET_LINUX_WEAPONS)
}

public fw_CmdStart(id, uc_handle, seed)
{
	if(!is_user_alive(id))
		return
	if(get_user_weapon(id) != CSW_GATLING || !g_had_gatling[id])
		return 

	static CurButton; CurButton = get_uc(uc_handle, UC_Buttons)

	if(CurButton & IN_ATTACK2)
	{
		if(get_gametime() - 0.5 > g_ZoomTime[id])
		{
			if(!Get_BitVar(g_Zoom, id))
			{
				Set_BitVar(g_Zoom, id)
				client_print(id, print_center, "Changed to Slug Mode")
			} else {
				
				UnSet_BitVar(g_Zoom, id)
				client_print(id, print_center, "Changed to Normal Mode")
			}
			
			g_ZoomTime[id] = get_gametime()
		}
	}
	
	if(CurButton & IN_RELOAD)
	{
		CurButton &= ~IN_RELOAD
		set_uc(uc_handle, UC_Buttons, CurButton)
		
		static ent; ent = fm_get_user_weapon_entity(id, CSW_GATLING)
		if(!pev_valid(ent)) return
		
		static fInReload; fInReload = get_pdata_int(ent, m_fInReload, OFFSET_LINUX_WEAPONS)
		static Float:flNextAttack; flNextAttack = get_pdata_float(id, m_flNextAttack, OFFSET_LINUX_PLAYER)
		
		if (flNextAttack > 0.0)
			return
			
		if (fInReload)
		{
			set_weapon_anim(id, GATLING_ANIM_IDLE)
			return
		}
		
		if(cs_get_weapon_ammo(ent) >= DEFAULT_CLIP)
		{
			set_weapon_anim(id, GATLING_ANIM_IDLE)
			return
		}
			
		fw_Weapon_Reload_Post(ent)
	}
}

public fw_SetModel(entity, model[])
{
	if(!pev_valid(entity))
		return FMRES_IGNORED
	
	static szClassName[33]
	pev(entity, pev_classname, szClassName, charsmax(szClassName))
	
	if(!equal(szClassName, "weaponbox"))
		return FMRES_IGNORED
	
	static id
	id = pev(entity, pev_owner)
	
	if(equal(model, DEFAULT_W_MODEL))
	{
		static weapon
		weapon = fm_find_ent_by_owner(-1, weapon_gatling, entity)
		
		if(!pev_valid(weapon))
			return FMRES_IGNORED
		
		if(g_had_gatling[id])
		{
			set_pev(weapon, pev_impulse, WEAPON_SECRET_CODE)
			engfunc(EngFunc_SetModel, entity, WeaponModel[2])
			
			remove_gatling(id)
			
			return FMRES_SUPERCEDE
		}
	}

	return FMRES_IGNORED
}

public fw_TraceAttack(ent, attacker, Float:Damage, Float:fDir[3], ptr, iDamageType)
{
	if(!is_user_alive(attacker))
		return HAM_IGNORED	
	if(get_user_weapon(attacker) != CSW_GATLING || !g_had_gatling[attacker])
		return HAM_IGNORED
		
	if(!is_user_alive(ent))
	{
		static Float:flEnd[3], Float:vecPlane[3]
	
		get_tr2(ptr, TR_vecEndPos, flEnd)
		get_tr2(ptr, TR_vecPlaneNormal, vecPlane)		
		
		if(!Get_BitVar(g_Zoom, attacker))
		{
			make_bullet(attacker, flEnd)
			fake_smoke(attacker, ptr)
		} else {
			static Float:Target[3]; 
			fm_get_aim_origin(attacker, Target)
			
			set_tr2(ptr, TR_vecEndPos, Target)
			
			get_tr2(ptr, TR_vecEndPos, flEnd)
			make_bullet(attacker, flEnd)
			fake_smoke(attacker, ptr)
		}
	}
		
	SetHamParamFloat(3, float(DAMAGE) / 6.0)	

	return HAM_HANDLED
}

public fw_UpdateClientData_Post(id, sendweapons, cd_handle)
{
	if(!is_user_alive(id) || !is_user_connected(id))
		return FMRES_IGNORED
	if(get_user_weapon(id) != CSW_GATLING || !g_had_gatling[id])
		return FMRES_IGNORED
		
	set_cd(cd_handle, CD_flNextAttack, get_gametime() + 0.001) 
	
	return FMRES_HANDLED
}

public fw_PlaybackEvent(flags, invoker, eventid, Float:delay, Float:origin[3], Float:angles[3], Float:fparam1, Float:fparam2, iParam1, iParam2, bParam1, bParam2)
{
	if(!is_user_connected(invoker))
		return FMRES_IGNORED	
		
	if(get_user_weapon(invoker) == CSW_GATLING && g_had_gatling[invoker] && eventid == g_gatling_event)
	{
		engfunc(EngFunc_PlaybackEvent, flags | FEV_HOSTONLY, invoker, eventid, delay, origin, angles, fparam1, fparam2, iParam1, iParam2, bParam1, bParam2)
		Event_Gatling_Shoot(invoker)	

		return FMRES_SUPERCEDE
	}
	
	return FMRES_HANDLED
}

public fw_Item_Deploy_Post(ent)
{
	static id; id = fm_cs_get_weapon_ent_owner(ent)
	if (!pev_valid(id))
		return
	
	static weaponid
	weaponid = cs_get_weapon_id(ent)
	
	if(weaponid != CSW_GATLING)
		return
	if(!g_had_gatling[id])
		return
		
	set_pev(id, pev_viewmodel2, WeaponModel[0])
	set_pev(id, pev_weaponmodel2, WeaponModel[1])
	
	set_weapon_anim(id, GATLING_ANIM_DRAW)
	set_pdata_string(id, m_szAnimExtention * 4, WEAPON_ANIMEXT, -1 , 20)
}

public fw_Weapon_Reload_Post(ent)
{
	static id; id = pev(ent, pev_owner)

	if(g_had_gatling[id])
	{
		static CurBpAmmo; CurBpAmmo = cs_get_user_bpammo(id, CSW_GATLING)
		
		if(CurBpAmmo  <= 0)
			return HAM_IGNORED

		set_pdata_int(ent, 55, 0, OFFSET_LINUX_WEAPONS)
		set_pdata_float(id, 83, RELOAD_TIME, OFFSET_LINUX_PLAYER)
		set_pdata_float(ent, 48, RELOAD_TIME + 0.5, OFFSET_LINUX_WEAPONS)
		set_pdata_float(ent, 46, RELOAD_TIME + 0.25, OFFSET_LINUX_WEAPONS)
		set_pdata_float(ent, 47, RELOAD_TIME + 0.25, OFFSET_LINUX_WEAPONS)
		set_pdata_int(ent, m_fInReload, 1, OFFSET_LINUX_WEAPONS)
		
		set_weapon_anim(id, GATLING_ANIM_RELOAD)			
		
		return HAM_HANDLED
	}
	
	return HAM_IGNORED	
}

public fw_Item_PostFrame(ent)
{
	static id; id = pev(ent, pev_owner)
	if(!g_had_gatling[id]) return

	static iBpAmmo ; iBpAmmo = get_pdata_int(id, 381, OFFSET_LINUX_PLAYER)
	static iClip ; iClip = get_pdata_int(ent, m_iClip, OFFSET_LINUX_WEAPONS)
	static iMaxClip ; iMaxClip = DEFAULT_CLIP

	if(get_pdata_int(ent, m_fInReload, OFFSET_LINUX_WEAPONS) && get_pdata_float(id, m_flNextAttack, OFFSET_LINUX_PLAYER) <= 0.0)
	{
		static j; j = min(iMaxClip - iClip, iBpAmmo)
		set_pdata_int(ent, m_iClip, iClip + j, OFFSET_LINUX_WEAPONS)
		set_pdata_int(id, 381, iBpAmmo-j, OFFSET_LINUX_PLAYER)
		
		set_pdata_int(ent, m_fInReload, 0, OFFSET_LINUX_WEAPONS)
		cs_set_weapon_ammo(ent, DEFAULT_CLIP)
	
		update_ammo(id, CSW_GATLING, cs_get_weapon_ammo(ent), cs_get_user_bpammo(id, CSW_GATLING))
	
		return
	}
}

public fw_Item_AddToPlayer_Post(ent, id)
{
	if(!pev_valid(ent))
		return HAM_IGNORED
		
	if(pev(ent, pev_impulse) == WEAPON_SECRET_CODE)
	{
		remove_gatling(id)
		g_had_gatling[id] = 1
		
		update_ammo(id, CSW_GATLING, cs_get_weapon_ammo(ent), cs_get_user_bpammo(id, CSW_GATLING))
	}
	
	return HAM_IGNORED
}

public fw_Weapon_PrimaryAttack(ent)
{
	static id; id = pev(ent, pev_owner)
	if(!g_had_gatling[id])
		return
		
	pev(id, pev_punchangle, g_punchangles[id])
}

public fw_Weapon_PrimaryAttack_Post(ent)
{
	static id; id = pev(ent, pev_owner)
	if(!g_had_gatling[id])
		return
		
	static Float:push[3]
	pev(id, pev_punchangle, push)
	xs_vec_sub(push, g_punchangles[id], push)
	
	xs_vec_mul_scalar(push, RECOIL, push)
	xs_vec_add(push, g_punchangles[id], push)
	set_pev(id, pev_punchangle, push)	
}

public update_ammo(id, csw_id, clip, bpammo)
{
	if(!is_user_alive(id))
		return
		
	message_begin(MSG_ONE_UNRELIABLE, get_user_msgid("CurWeapon"), _, id)
	write_byte(1)
	write_byte(csw_id)
	write_byte(clip)
	message_end()
	
	message_begin(MSG_ONE_UNRELIABLE, get_user_msgid("AmmoX"), _, id)
	write_byte(3)
	write_byte(bpammo)
	message_end()
}

public Event_Gatling_Shoot(id)
{
	set_weapon_anim(id, random_num(GATLING_ANIM_SHOOT1, GATLING_ANIM_SHOOT2))
	emit_sound(id, CHAN_WEAPON, WeaponSound[0], 1.0, ATTN_NORM, 0, PITCH_NORM)
}

stock fm_cs_get_weapon_ent_owner(ent)
{
	if (pev_valid(ent) != PDATA_SAFE)
		return -1
	
	return get_pdata_cbase(ent, OFFSET_WEAPONOWNER, OFFSET_LINUX_WEAPONS)
}

stock set_weapon_anim(id, anim)
{
	if(!is_user_alive(id))
		return
		
	set_pev(id, pev_weaponanim, anim)
	
	message_begin(MSG_ONE_UNRELIABLE, SVC_WEAPONANIM, _, id)
	write_byte(anim)
	write_byte(0)
	message_end()	
}

stock drop_weapons(id, dropwhat)
{
	static weapons[32], num, i, weaponid
	num = 0
	get_user_weapons(id, weapons, num)
	
	const PRIMARY_WEAPONS_BIT_SUM = (1<<CSW_SCOUT)|(1<<CSW_XM1014)|(1<<CSW_MAC10)|(1<<CSW_MAC10)|(1<<CSW_UMP45)|(1<<CSW_SG550)|(1<<CSW_MAC10)|(1<<CSW_FAMAS)|(1<<CSW_AWP)|(1<<CSW_MP5NAVY)|(1<<CSW_M249)|(1<<CSW_M3)|(1<<CSW_M4A1)|(1<<CSW_TMP)|(1<<CSW_G3SG1)|(1<<CSW_SG552)|(1<<CSW_AK47)|(1<<CSW_P90)
	
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
