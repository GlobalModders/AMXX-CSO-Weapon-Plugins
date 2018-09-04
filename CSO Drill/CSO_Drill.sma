#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <xs>

#define PLUGIN "Drill Gun"
#define VERSION "1.0"
#define AUTHOR "pham.bien10@gmail.com"

#define DRILL_ID CSW_M249
#define DRILL_CN "weapon_m249"
#define DRILL_AI 3

#define DRILL_MA 20
#define DRILL_ST 1.035
#define DRILL_RT 2.035
#define DRILL_IT 1.7

#define NAIL_CN "drillgun"

#define NAIL_SPEED 2000.0
#define NAIL_DAMAGE 500.0

#define NAIL_MODEL "models/drillgun_nail.mdl"

#define V_MODEL "models/v_drillgun.mdl"
#define P_MODEL "models/p_drillgun.mdl"
#define W_MODEL "models/w_drillgun.mdl"

#define SHOOT_SOUND "weapons/drillgun-1.wav"
#define DRAW_SOUND "weapons/drillgun_draw.wav"
#define RELOAD_SOUND "weapons/drillgun_reload.wav"

#define ORIG_W_MODEL "models/w_m249.mdl"

#define Get_BitVar(%1,%2) (%1 & (1 << (%2 & 31)))
#define Set_BitVar(%1,%2) %1 |= (1 << (%2 & 31))
#define UnSet_BitVar(%1,%2) %1 &= ~(1 << (%2 & 31))

#define CheckPlayer(%1,%2) if (%1 < 1 || %1 > 32) return %2; \
			   if (!is_user_connected(%1)) return %2
			   
new const Float:g_vecZero[3] = { 0.0, 0.0, 0.0 };
new const PRIMARY_WEAPONS_BITSUM  = ((1<<CSW_SCOUT)|(1<<CSW_XM1014)|(1<<CSW_MAC10)|(1<<CSW_AUG)|(1<<CSW_UMP45)|(1<<CSW_SG550)|(1<<CSW_GALIL)|(1<<CSW_FAMAS)|(1<<CSW_AWP)|(1<<CSW_MP5NAVY)|(1<<CSW_M249)|(1<<CSW_M3)|(1<<CSW_M4A1)|(1<<CSW_TMP)|(1<<CSW_G3SG1)|(1<<CSW_SG552)|(1<<CSW_AK47)|(1<<CSW_P90));
new const WEAPONENTNAMES[][] =
{
	"", "weapon_p228", "", "weapon_scout", "weapon_hegrenade", "weapon_xm1014", "weapon_c4", "weapon_mac10",
	"weapon_aug", "weapon_smokegrenade", "weapon_elite", "weapon_fiveseven", "weapon_ump45", "weapon_sg550",
	"weapon_galil", "weapon_famas", "weapon_usp", "weapon_glock18", "weapon_awp", "weapon_mp5navy", "weapon_m249",
	"weapon_m3", "weapon_m4a1", "weapon_tmp", "weapon_g3sg1", "weapon_flashbang", "weapon_deagle", "weapon_sg552",
	"weapon_ak47", "weapon_knife", "weapon_p90"
};
			   
new g_fHasWeapon = 0;
new g_TempAttack;
new g_SprId_LaserBeam
			   
public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	
	register_clcmd("say /drill", "clcmd_buydrill");

	register_clcmd("weapon_drillgun", "clcmd_weapon_drillgun");
	
	register_message(get_user_msgid("AmmoX"), "Message_AmmoX");
	register_message(get_user_msgid("CurWeapon"), "Message_CurWeapon");
	
	register_forward(FM_EmitSound, "fw_EmitSound");
	register_forward(FM_TraceLine, "fw_TraceLine");
	register_forward(FM_TraceHull, "fw_TraceHull");	
	
	register_forward(FM_UpdateClientData, "fw_FM_UpdateClientData_Post", 1);
	register_forward(FM_SetModel, "fw_FM_SetModel");
	
	RegisterHam(Ham_Weapon_WeaponIdle, DRILL_CN, "fw_Ham_Weapon_WeaponIdle");
	RegisterHam(Ham_Weapon_PrimaryAttack, DRILL_CN, "fw_Ham_Weapon_PrimaryAttack");
	RegisterHam(Ham_Weapon_Reload, DRILL_CN, "fw_Ham_Weapon_Reload");
	RegisterHam(Ham_Item_Deploy, DRILL_CN, "fw_Ham_Item_Deploy_Post", 1);
	RegisterHam(Ham_Item_PostFrame, DRILL_CN, "fw_Ham_Item_PostFrame");
	RegisterHam(Ham_Item_AddToPlayer, DRILL_CN, "fw_Ham_Item_AddToPlayer_Post", 1);
	RegisterHam(Ham_Think, "info_target", "fw_Ham_Think");
	RegisterHam(Ham_Touch, "info_target", "fw_Ham_Touch");
}

public plugin_precache()
{
	engfunc(EngFunc_PrecacheModel, NAIL_MODEL);

	engfunc(EngFunc_PrecacheModel, V_MODEL);
	engfunc(EngFunc_PrecacheModel, P_MODEL);
	engfunc(EngFunc_PrecacheModel, W_MODEL);
	
	engfunc(EngFunc_PrecacheSound, SHOOT_SOUND);
	engfunc(EngFunc_PrecacheSound, DRAW_SOUND);
	engfunc(EngFunc_PrecacheSound, RELOAD_SOUND);
	
	precache_model("sprites/640hud3_2.spr")
	precache_model("sprites/640hud100_2.spr")
	precache_generic("sprites/weapon_drillgun.txt")
	
	g_SprId_LaserBeam = engfunc(EngFunc_PrecacheModel, "sprites/laserbeam.spr")
}

public Message_AmmoX(iMsgId, iMsgDest, iMsgEnt)
{
	CheckPlayer(iMsgEnt, PLUGIN_CONTINUE);
	
	if (get_msg_arg_int(1) != DRILL_AI || !(g_fHasWeapon & (1 << iMsgEnt))) return PLUGIN_CONTINUE;
	
	return PLUGIN_HANDLED;
}

public Message_CurWeapon(iMsgId, iMsgDest, iMsgEnt)
{
	CheckPlayer(iMsgEnt, PLUGIN_CONTINUE);

	if (!get_msg_arg_int(1) || get_msg_arg_int(2) != DRILL_ID) return PLUGIN_CONTINUE;
	
	if (g_fHasWeapon & (1 << iMsgEnt)) 
	{
		message_begin(MSG_ONE_UNRELIABLE, get_user_msgid("AmmoX"), _, iMsgEnt);
		write_byte(DRILL_AI);
		write_byte(get_msg_arg_int(3));
		message_end();
		
		set_msg_arg_int(3, ARG_BYTE, -1);
	}
	else
	{
		message_begin(MSG_ONE_UNRELIABLE, get_user_msgid("AmmoX"), _, iMsgEnt);
		write_byte(DRILL_AI);
		write_byte(get_pdata_int(iMsgEnt, 376 + DRILL_AI));
		message_end();
	}
	
	return PLUGIN_CONTINUE;
}

public client_putinserver(id)
{
	g_fHasWeapon &= ~(1 << id);
}

public clcmd_buydrill(id)
{
	CheckPlayer(id, PLUGIN_HANDLED);
	
	if (!is_user_alive(id)) return PLUGIN_HANDLED;
	
	DropAllPrimary(id);
	
	g_fHasWeapon |= (1 << id);
	
	fm_give_item(id, DRILL_CN);
	
	new iEnt = fm_find_ent_by_owner(-1, DRILL_CN, id);
	
	if (!pev_valid(iEnt)) return PLUGIN_HANDLED;
	
	set_pdata_int(iEnt, 51, DRILL_MA, 4, 4);
	
	return PLUGIN_HANDLED;
}

public clcmd_weapon_drillgun(id)
{
	client_cmd(id, DRILL_CN);
}

public fw_EmitSound(id, channel, const sample[], Float:volume, Float:attn, flags, pitch)
{
	CheckPlayer(id, FMRES_IGNORED);
	
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
	CheckPlayer(id, FMRES_IGNORED);
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
	CheckPlayer(id, FMRES_IGNORED);
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

public fw_FM_UpdateClientData_Post(id, iSendWeapons, cd_handle)
{
	CheckPlayer(id, FMRES_IGNORED);
	
	if (!is_user_alive(id) || !(g_fHasWeapon & (1 << id))) return FMRES_IGNORED;	
	
	if (get_player_curweapon(id) != DRILL_ID) return FMRES_IGNORED;
	
	new Float:flTime;
	global_get(glb_time, flTime);
	set_cd(cd_handle, CD_flNextAttack, flTime + 9999.0);
	
	return FMRES_IGNORED;
}

public fw_FM_SetModel(iEnt, const szModel[])
{
	if (!pev_valid(iEnt)) return FMRES_IGNORED;
	
	new szClassname[32];
	pev(iEnt, pev_classname, szClassname, 31);
		
	if (!equal(szClassname, "weaponbox")) return FMRES_IGNORED;
	
	if (equal(szModel, ORIG_W_MODEL))
	{
		new pPlayer = pev(iEnt, pev_owner);
		if (g_fHasWeapon & (1 << pPlayer))
		{
			g_fHasWeapon &= ~(1 << pPlayer);
			
			new iWeapon = fm_find_ent_by_owner(-1, DRILL_CN, iEnt);
			
			if (!pev_valid(iWeapon)) return FMRES_IGNORED;
			
			set_pev(iWeapon, pev_iuser4, 310197);
			
			engfunc(EngFunc_SetModel, iEnt, W_MODEL);
						
			return FMRES_SUPERCEDE;
		}
	}
	
	return FMRES_IGNORED;
}

public fw_Ham_Weapon_WeaponIdle(this)
{
	if (!pev_valid(this)) return HAM_IGNORED;
	
	if (get_pdata_int(this, 43, 4, 4) != DRILL_ID) return HAM_IGNORED;
	
	new pPlayer = get_pdata_cbase(this, 41, 4, 4);
	
	CheckPlayer(pPlayer, HAM_IGNORED);
	
	if (!is_user_alive(pPlayer) || !(g_fHasWeapon & (1 << pPlayer))) return HAM_IGNORED;	
	
	set_pdata_int(this, 44, 1, 4, 4);
	
	new Float:m_flTimeWeaponIdle = get_pdata_float(this, 48, 4, 4);
	
	if (m_flTimeWeaponIdle < 0.0)
	{
		if (get_pdata_int(this, 55, 4, 4))
		{
			UTIL_SendWeaponAnim(pPlayer, 2);
			
			set_pdata_int(this, 55, 0, 4, 4);
		
			m_flTimeWeaponIdle = DRILL_RT + 1.0;
		}
		else
		{
			UTIL_SendWeaponAnim(pPlayer, (!get_pdata_int(this, 51, 4, 4)) ? 5 : 0);
		
			m_flTimeWeaponIdle = DRILL_IT;
		}
		
		set_pdata_string(pPlayer, (492) * 4, "carbine", -1 , 20)
	}
	
	set_pdata_float(this, 48, m_flTimeWeaponIdle, 4, 4);
	
	return HAM_SUPERCEDE;
}

public fw_Ham_Weapon_PrimaryAttack(this)
{
	if (!pev_valid(this)) return HAM_IGNORED;
	
	if (get_pdata_int(this, 43, 4, 4) != DRILL_ID) return HAM_IGNORED;
	
	new pPlayer = get_pdata_cbase(this, 41, 4, 4);
	
	CheckPlayer(pPlayer, HAM_IGNORED);
	
	if (!is_user_alive(pPlayer) || !(g_fHasWeapon & (1 << pPlayer))) return HAM_IGNORED;
	
	Set_BitVar(g_TempAttack, pPlayer)
	static Ent; Ent = fm_get_user_weapon_entity(pPlayer, CSW_KNIFE)
	if(pev_valid(Ent)) ExecuteHamB(Ham_Weapon_PrimaryAttack, Ent)
	UnSet_BitVar(g_TempAttack, pPlayer)
	
	new m_iClip = get_pdata_int(this, 51, 4, 4);
	
	if (!m_iClip) return HAM_SUPERCEDE;
	
	m_iClip--;
	set_pdata_int(this, 51, m_iClip, 4, 4);
	
	new Float:vV_Angle[3], Float:vPunchangle[3];
	pev(pPlayer, pev_v_angle, vV_Angle);
	pev(pPlayer, pev_punchangle, vPunchangle);
	
	new Float:anglesAim[3];
	xs_vec_add(vV_Angle, vPunchangle, anglesAim);
	UTIL_MakeVectors(anglesAim);
	
	new Float:vecSrc[3], Float:vecDir[3], Float:vVelocity[3];
	anglesAim[0] = -anglesAim[0];
	global_get(glb_v_up, vecSrc);
	xs_vec_mul_scalar(vecSrc, 2.0, vecSrc);
	GetGunPosition(pPlayer, vecDir);
	xs_vec_sub(vecDir, vecSrc, vecSrc);
	global_get(glb_v_forward, vecDir);
	
	new iEnt = CreateNail(pPlayer);
	
	if (pev_valid(iEnt))
	{
		set_pev(iEnt, pev_origin, vecSrc);
		set_pev(iEnt, pev_angles, anglesAim);
		set_pev(iEnt, pev_vuser1, anglesAim);
		
		xs_vec_mul_scalar(vecDir, NAIL_SPEED, vVelocity);
		set_pev(iEnt, pev_velocity, vVelocity);
		set_pev(iEnt, pev_vuser2, vVelocity);
		
		set_pev(iEnt, pev_speed, NAIL_SPEED);
		
		pev(iEnt, pev_avelocity, vVelocity);
		vVelocity[2] = 10.0;
		set_pev(iEnt, pev_avelocity, vVelocity);
		
		// Create Beam
		message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
		write_byte(TE_BEAMFOLLOW)
		write_short(iEnt)
		write_short(g_SprId_LaserBeam)
		write_byte(2)
		write_byte(1)
		write_byte(42)
		write_byte(255)
		write_byte(170)
		write_byte(150)
		message_end()
	}
	
	set_pdata_float(this, 46, DRILL_ST + DRILL_RT, 4, 4);
	
	set_pdata_float(this, 48, DRILL_ST, 4, 4);
	
	if (m_iClip > 0) set_pdata_int(this, 55, 1, 4, 4);
	
	UTIL_SendWeaponAnim(pPlayer, 1);
	
	emit_sound(pPlayer, CHAN_WEAPON, SHOOT_SOUND, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
	
	
	return HAM_SUPERCEDE;
}

public fw_Ham_Weapon_Reload(this)
{
	if (!pev_valid(this)) return HAM_IGNORED;
	
	if (get_pdata_int(this, 43, 4, 4) != DRILL_ID) return HAM_IGNORED;
	
	new pPlayer = get_pdata_cbase(this, 41, 4, 4);
	
	CheckPlayer(pPlayer, HAM_IGNORED);
	
	if (!is_user_alive(pPlayer) || !(g_fHasWeapon & (1 << pPlayer))) return HAM_IGNORED;
	
	return HAM_SUPERCEDE;
}

public fw_Ham_Item_Deploy_Post(this)
{
	if (!pev_valid(this)) return HAM_IGNORED;
	
	if (get_pdata_int(this, 43, 4, 4) != DRILL_ID) return HAM_IGNORED;
	
	new pPlayer = get_pdata_cbase(this, 41, 4, 4);
	
	CheckPlayer(pPlayer, HAM_IGNORED);
	
	if (!is_user_alive(pPlayer) || !(g_fHasWeapon & (1 << pPlayer))) return HAM_IGNORED;
	
	set_pev(pPlayer, pev_viewmodel2, V_MODEL);
	set_pev(pPlayer, pev_weaponmodel2, P_MODEL);
	
	set_pdata_int(this, 55, 0, 4, 4);
	
	UTIL_SendWeaponAnim(pPlayer, (!get_pdata_int(this, 51, 4, 4)) ? 4 : 3);
	
	return HAM_IGNORED;
}

public fw_Ham_Item_PostFrame(this)
{
	if (!pev_valid(this)) return HAM_IGNORED;
	
	if (get_pdata_int(this, 43, 4, 4) != DRILL_ID) return HAM_IGNORED;
	
	new pPlayer = get_pdata_cbase(this, 41, 4, 4);
	
	CheckPlayer(pPlayer, HAM_IGNORED);
	
	if (!is_user_alive(pPlayer) || !(g_fHasWeapon & (1 << pPlayer))) return HAM_IGNORED;
	
	fw_Ham_Weapon_WeaponIdle(this);
	
	return HAM_IGNORED;
}

public fw_Ham_Item_AddToPlayer_Post(this, pPlayer)
{
	if (!pev_valid(this)) return HAM_IGNORED;
	
	if (get_pdata_int(this, 43, 4, 4) != DRILL_ID) return HAM_IGNORED;
	
	new pPlayer = get_pdata_cbase(this, 41, 4, 4);
	
	CheckPlayer(pPlayer, HAM_IGNORED);
	
	if (!is_user_alive(pPlayer)) return HAM_IGNORED;
	
	if (pev(this, pev_iuser4) == 310197 || (g_fHasWeapon & (1 << pPlayer)))
	{
		g_fHasWeapon |= (1 << pPlayer);
		
		message_begin(MSG_ONE_UNRELIABLE, get_user_msgid("WeaponList"), _, pPlayer);
		write_string("weapon_drillgun");
		write_byte(DRILL_AI);
		write_byte(DRILL_MA);
		write_byte(-1);
		write_byte(-1);
		write_byte(0);
		write_byte(1);
		write_byte(DRILL_ID);
		write_byte(0);
		message_end();
	}
	else
	{
		message_begin(MSG_ONE_UNRELIABLE, get_user_msgid("WeaponList"), _, pPlayer);
		write_string(DRILL_CN);
		write_byte(DRILL_AI);
		write_byte(DRILL_MA);
		write_byte(-1);
		write_byte(-1);
		write_byte(0);
		write_byte(1);
		write_byte(DRILL_ID);
		write_byte(0);
		message_end();	
	}
	
	return HAM_IGNORED;
}

public fw_Ham_Think(this)
{
	if (!pev_valid(this)) return HAM_IGNORED;
	
	new szClassname[32];
	pev(this, pev_classname, szClassname, 31);
		
	if (!equal(szClassname, NAIL_CN)) return HAM_IGNORED;
	
	set_pev(this, pev_flags, pev(this, pev_flags) | FL_KILLME);
	set_pev(this, pev_targetname, "");
	
	return HAM_IGNORED;
}

public fw_Ham_Touch(this, iOther)
{
	if (!pev_valid(this)) return HAM_IGNORED;
	
	new szClassname[32];
	pev(this, pev_classname, szClassname, 31);
		
	if (!equal(szClassname, NAIL_CN)) return HAM_IGNORED;
	
	new Float:vVelocity[3], Float:vecDir[3], Float:vOrigin[3];
	pev(this, pev_velocity, vVelocity);
	xs_vec_normalize(vVelocity, vecDir);
	pev(this, pev_origin, vOrigin);
	
	if (pev_valid(iOther))
	{
		if (iOther == pev(this, pev_iuser1)) return HAM_IGNORED;
		
		if (pev(iOther, pev_takedamage))
		{
			//new tr = create_tr2();
			
			/*new Float:vEnd[3];
			xs_vec_mul_scalar(vecDir, 8192.0, vEnd);
			xs_vec_add(vOrigin, vEnd, vEnd);
			
			fm_trace_line_tr(tr, this, vOrigin, vEnd);*/
			
			new pOwner = pev(this, pev_owner);
			
			//ExecuteHamB(Ham_TraceAttack, iOther, pOwner, NAIL_DAMAGE, vecDir, tr, DMG_BULLET | DMG_NEVERGIB);
			
			ExecuteHamB(Ham_TakeDamage, iOther, this, pOwner, NAIL_DAMAGE * DamageMultiply(get_tr2(0, TR_iHitgroup)), DMG_BULLET | DMG_NEVERGIB);
			
			//free_tr2(tr);
			
			set_pev(this, pev_iuser1, iOther);
			
			return HAM_IGNORED;
		}
	}

	new Float:flTime;
	global_get(glb_time, flTime);
	set_pev(this, pev_nextthink, flTime + 3.0);
	
	new Float:vAngles[3];
	vector_to_angle(vecDir, vAngles);
	set_pev(this, pev_angles, vAngles);
	
	set_pev(this, pev_solid, SOLID_NOT);
	set_pev(this, pev_movetype, MOVETYPE_FLY);
	set_pev(this, pev_velocity, g_vecZero);
	
	pev(this, pev_avelocity, vVelocity);
	vVelocity[2] = 0.0;
	set_pev(this, pev_avelocity, vVelocity);
	
	DecalGunshot(vOrigin, iOther);
	
	return HAM_IGNORED;
}

CreateNail(iOwner)
{
	new iEnt = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"));
	
	if (!pev_valid(iEnt)) return -1;
	
	set_pev(iEnt, pev_classname, NAIL_CN);
	set_pev(iEnt, pev_movetype, MOVETYPE_FLY);
	set_pev(iEnt, pev_solid, SOLID_TRIGGER);
	set_pev(iEnt, pev_gravity, 0.5);
	set_pev(iEnt, pev_owner, iOwner);
	set_pev(iEnt, pev_iuser1, iOwner);
	
	engfunc(EngFunc_SetModel, iEnt, NAIL_MODEL);
	
	new Float:vOrigin[3];
	pev(iEnt, pev_origin, vOrigin);
	engfunc(EngFunc_SetOrigin, iEnt, vOrigin);
	
	engfunc(EngFunc_SetSize, iEnt, g_vecZero, g_vecZero);
	
	return iEnt;
}

stock DropAllPrimary(id)
{
	new weapons[32], num;
	get_user_weapons(id, weapons, num);
	for (new i = 0; i < num; i++)
		if (PRIMARY_WEAPONS_BITSUM & (1 << weapons[i])) client_cmd(id, "drop %s", WEAPONENTNAMES[weapons[i]]);
}

stock Float:DamageMultiply(iHitGroup)
{
	switch (iHitGroup)
	{
	case HIT_GENERIC: return 1.0;
	case HIT_HEAD: return 4.0;
	case HIT_CHEST: return 1.0;
	case HIT_STOMACH: return 1.25;
	case HIT_LEFTARM: return 1.0;
	case HIT_RIGHTARM: return 1.0;
	case HIT_LEFTLEG: return 0.75;
	case HIT_RIGHTLEG: return 0.75;
	default: return 1.0;
	}
	
	return 1.0;
}

stock GetGunPosition(id, Float:out[3])
{
	new Float:origin[3], Float:view_ofs[3];
	pev(id, pev_origin, origin);
	pev(id, pev_view_ofs, view_ofs);
	xs_vec_add(origin, view_ofs, out);
}

stock UTIL_MakeVectors(Float:vecAngles[3])
{
	engfunc(EngFunc_MakeVectors, vecAngles);
}

stock UTIL_SendWeaponAnim(id, iAnim)
{
	set_pev(id, pev_weaponanim, iAnim);
	
	message_begin(MSG_ONE_UNRELIABLE, SVC_WEAPONANIM, _, id);
	write_byte(iAnim);
	write_byte(0);
	message_end();
}

stock DecalGunshot(Float:vecEndPos[3], pHit)
{
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
	write_byte(TE_GUNSHOTDECAL);
	engfunc(EngFunc_WriteCoord, vecEndPos[0]);
	engfunc(EngFunc_WriteCoord, vecEndPos[1]);
	engfunc(EngFunc_WriteCoord, vecEndPos[2]);
	write_short(pHit);
	write_byte(random_num(41,45));
	message_end();
}

stock get_player_curweapon(id)
{
	return (get_pdata_int(get_pdata_cbase(id, 373), 43, 4, 4));
}
