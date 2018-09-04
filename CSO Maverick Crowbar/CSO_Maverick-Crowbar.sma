#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <cstrike>
#include <fun>

#define PLUGIN "[CSO] Maverick: Crowbar"
#define VERSION "1.0"
#define AUTHOR "Joseph Rias de Dias"

#define DISTANCE 69.0
#define DAMAGE_MULTI 3.0 // 12.0 for zombie

#define MODEL_V "models/v_crowbarcraft.mdl"
#define MODEL_P "models/p_crowbarcraft.mdl"

new const WeaponSounds[7][] = 
{
	"weapons/crowbarcraft_draw.wav",
	"weapons/crowbarcraft_slash1.wav",
	"weapons/crowbarcraft_slash2.wav",
	"weapons/crowbarcraft_stab.wav",
	"weapons/crowbarcraft_stab_miss.wav",
	"weapons/janus9_stone1.wav",
	"weapons/katanad_stab.wav"
}

new g_Had_Crowbar[33], g_Stab[33]

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	register_forward(FM_CmdStart, "fw_CmdStart")
	
	register_forward(FM_EmitSound, "fw_EmitSound")
	register_forward(FM_TraceLine, "fw_TraceLine")
	register_forward(FM_TraceHull, "fw_TraceHull")	
	
	RegisterHam(Ham_Item_Deploy, "weapon_knife", "fw_Item_Deploy_Post", 1)	
	RegisterHam(Ham_TakeDamage, "player", "fw_PlayerTakeDamage")
	
	register_clcmd("say /get", "Get_Crowbar")
}

public plugin_precache()
{
	precache_model(MODEL_V)
	precache_model(MODEL_P)
	
	for(new i = 0; i < sizeof(WeaponSounds); i++)
		precache_sound(WeaponSounds[i])
	
}

public Get_Crowbar(id)
{
	g_Had_Crowbar[id] = 1
	g_Stab[id] = 0
	
	if(get_user_weapon(id) == CSW_KNIFE)
	{
		set_pev(id, pev_viewmodel2, MODEL_V)
		set_pev(id, pev_weaponmodel2, MODEL_P)
		
		Set_WeaponAnim(id, 3)
		set_pdata_float(id, 83, 0.75, 5)
	} else {
		engclient_cmd(id, "weapon_knife")
	}
}

public Remove_Crowbar(id) g_Had_Crowbar[id] = g_Stab[id] = 0

public fw_Item_Deploy_Post(Ent)
{
	if(pev_valid(Ent) != 2)
		return
	static Id; Id = get_pdata_cbase(Ent, 41, 4)
	if(get_pdata_cbase(Id, 373) != Ent)
		return
	if(!g_Had_Crowbar[Id])
		return
	
	set_pev(Id, pev_viewmodel2, MODEL_V)
	set_pev(Id, pev_weaponmodel2, MODEL_P)
}

public fw_CmdStart(id, uc_handle, seed)
{
	if(!is_user_alive(id))
		return
	
	static Button; Button = get_uc(uc_handle, UC_Buttons)
	if(Button & IN_ATTACK) g_Stab[id] = 0
	if(Button & IN_ATTACK2) g_Stab[id] = 1
}

public fw_EmitSound(id, channel, const sample[], Float:volume, Float:attn, flags, pitch)
{
	if(!is_user_connected(id))
		return FMRES_IGNORED
	if(!g_Had_Crowbar[id])
		return FMRES_IGNORED
		
	if(sample[8] == 'k' && sample[9] == 'n' && sample[10] == 'i')
	{
		if(sample[14] == 's' && sample[15] == 'l' && sample[16] == 'a')
		{
			emit_sound(id, channel, WeaponSounds[random_num(1, 2)], volume, attn, flags, pitch)
			set_pdata_float(id, 83, 0.5, 5)
			
			return FMRES_SUPERCEDE
		}
		if (sample[14] == 'h' && sample[15] == 'i' && sample[16] == 't')
		{
			if (sample[17] == 'w') // wall
			{
				if(g_Stab[id]) emit_sound(id, channel, WeaponSounds[3], volume, attn, flags, pitch)
				else {
					emit_sound(id, channel, WeaponSounds[5], volume, attn, flags, pitch)
					set_pdata_float(id, 83, 0.5, 5)
				}
				
				return FMRES_SUPERCEDE
			} else {
				emit_sound(id, channel, WeaponSounds[6], volume, attn, flags, pitch)
				set_pdata_float(id, 83, 0.5, 5)
				
				return FMRES_SUPERCEDE
			}
		}
		if (sample[14] == 's' && sample[15] == 't' && sample[16] == 'a')
		{
			emit_sound(id, channel, WeaponSounds[3], volume, attn, flags, pitch)
			return FMRES_SUPERCEDE;
		}
	}
	
	return FMRES_IGNORED
}

public fw_TraceLine(Float:vector_start[3], Float:vector_end[3], ignored_monster, id, handle)
{
	if (!is_user_alive(id))
		return FMRES_IGNORED	
	if (get_user_weapon(id) != CSW_KNIFE || !g_Had_Crowbar[id])
		return FMRES_IGNORED

	static Float:vecStart[3], Float:vecEnd[3], Float:v_angle[3], Float:v_forward[3], Float:view_ofs[3], Float:fOrigin[3]
	
	pev(id, pev_origin, fOrigin)
	pev(id, pev_view_ofs, view_ofs)
	xs_vec_add(fOrigin, view_ofs, vecStart)
	pev(id, pev_v_angle, v_angle)
	
	engfunc(EngFunc_MakeVectors, v_angle)
	get_global_vector(GL_v_forward, v_forward)

	xs_vec_mul_scalar(v_forward, DISTANCE, v_forward)
	xs_vec_add(vecStart, v_forward, vecEnd)
	
	engfunc(EngFunc_TraceLine, vecStart, vecEnd, ignored_monster, id, handle)
	
	return FMRES_SUPERCEDE
}

public fw_TraceHull(Float:vector_start[3], Float:vector_end[3], ignored_monster, hull, id, handle)
{
	if (!is_user_alive(id))
		return FMRES_IGNORED	
	if (get_user_weapon(id) != CSW_KNIFE || !g_Had_Crowbar[id])
		return FMRES_IGNORED

	static Float:vecStart[3], Float:vecEnd[3], Float:v_angle[3], Float:v_forward[3], Float:view_ofs[3], Float:fOrigin[3]
	
	pev(id, pev_origin, fOrigin)
	pev(id, pev_view_ofs, view_ofs)
	xs_vec_add(fOrigin, view_ofs, vecStart)
	pev(id, pev_v_angle, v_angle)
	
	engfunc(EngFunc_MakeVectors, v_angle)
	get_global_vector(GL_v_forward, v_forward)
	
	xs_vec_mul_scalar(v_forward, DISTANCE, v_forward)
	xs_vec_add(vecStart, v_forward, vecEnd)
	
	engfunc(EngFunc_TraceHull, vecStart, vecEnd, ignored_monster, hull, id, handle)
	
	return FMRES_SUPERCEDE
}

public fw_PlayerTakeDamage(Victim, Inflictor, Attacker, Float:Damage, DamageBits)
{
	if(!is_user_connected(Attacker))
		return HAM_IGNORED
	if(get_user_weapon(Attacker) != CSW_KNIFE || !g_Had_Crowbar[Attacker])
		return HAM_IGNORED
		
	SetHamParamFloat(4, Damage * DAMAGE_MULTI)
	
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
