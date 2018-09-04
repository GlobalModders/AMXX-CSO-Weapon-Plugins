#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <cstrike>
#include <fun>

#define PLUGIN "[CSO] Pumpkin"
#define VERSION "1.0"
#define AUTHOR "Dias"

#define IMPACT_EXPLOSION 0

#define PUMPKIN_DAMAGE 500.0
#define PUMPKIN_RADIUS 180.0
#define PUMPKIN_SECRETCODE 10525

#define CSW_HOLYBOMB CSW_HEGRENADE
#define weapon_holybomb "weapon_hegrenade"

new const WeaponModel[3][] =
{
	"models/v_pumpkin.mdl",
	"models/p_pumpkin.mdl",
	"models/w_pumpkin.mdl"
}

new const WeaponSounds[4][] =
{
	"weapons/pumpkin_exp.wav",
	"weapons/pump_deploy.wav",
	"weapons/pump_in.wav",
	"weapons/pump_throw.wav"
}

new const WeaponExpSpr[] = "sprites/pumpkin_exp.spr"

enum
{
	TEAM_NONE = 0,
	TEAM_T,
	TEAM_CT
}

// OFFSET
const PDATA_SAFE = 2
const OFFSET_LINUX_WEAPONS = 4
const OFFSET_WEAPONOWNER = 41

new g_had_holybomb[33]
new g_Exp_SprId, g_MaxPlayers

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	register_forward(FM_SetModel, "fw_SetModel")
	RegisterHam(Ham_Touch, "grenade", "fw_GrenadeTouch")
	RegisterHam(Ham_Think, "grenade", "fw_GrenadeThink")
	
	RegisterHam(Ham_Item_Deploy, weapon_holybomb, "fw_Item_Deploy_Post", 1)
	
	g_MaxPlayers = get_maxplayers()
	register_clcmd("say /pk", "get_holybomb", ADMIN_KICK)
}

public plugin_precache()
{
	new i
	
	for(i = 0; i < sizeof(WeaponModel); i++)
		engfunc(EngFunc_PrecacheModel, WeaponModel[i])
	for(i = 0; i < sizeof(WeaponSounds); i++)
		engfunc(EngFunc_PrecacheSound, WeaponSounds[i])
		
	g_Exp_SprId = engfunc(EngFunc_PrecacheModel, WeaponExpSpr)
}

public get_holybomb(id)
{
	if(!is_user_alive(id))
		return
		
	g_had_holybomb[id] = 1
	fm_give_item(id, weapon_holybomb)
}

public hook_weapon(id)
{
	client_cmd(id, weapon_holybomb)
	return PLUGIN_HANDLED
}

public fw_SetModel(ent, const Model[])
{
	if(!pev_valid(ent))
		return FMRES_IGNORED
		
	static Classname[32]; pev(ent, pev_classname, Classname, sizeof(Classname))
	if(equal(Model, "models/w_hegrenade.mdl"))
	{
		static id; id = pev(ent, pev_owner)
		
		if(g_had_holybomb[id])
		{
			engfunc(EngFunc_SetModel, ent, WeaponModel[2])
			
			set_pev(ent, pev_iuser1, get_player_team(id))
			set_pev(ent, pev_bInDuck, PUMPKIN_SECRETCODE)
			
			g_had_holybomb[id] = 0
			
			return FMRES_SUPERCEDE
		}
	}
	return FMRES_IGNORED	
}

public fw_GrenadeTouch(Ent, Touched)
{
	if(!pev_valid(Ent) || pev(Ent, pev_bInDuck) != PUMPKIN_SECRETCODE) 
		return HAM_IGNORED
	
	static Impact; Impact = IMPACT_EXPLOSION
	if(Impact) set_pev(Ent, pev_dmgtime, get_gametime())
	
	return HAM_IGNORED
}

public fw_GrenadeThink(Ent)
{
	if(!pev_valid(Ent) || pev(Ent, pev_bInDuck) != PUMPKIN_SECRETCODE) 
		return HAM_IGNORED
	
	static Float:DMGTime; pev(Ent, pev_dmgtime, DMGTime)
	if(DMGTime > get_gametime()) 
		return HAM_IGNORED
	
	static Float:Origin[3]
	pev(Ent, pev_origin, Origin)

	HolyBomb_Exp(Ent, Origin, pev(Ent, pev_owner), pev(Ent, pev_iuser1))
	
	engfunc(EngFunc_RemoveEntity, Ent)
	
	return HAM_SUPERCEDE
}

public fw_Item_Deploy_Post(ent)
{
	static id; id = fm_cs_get_weapon_ent_owner(ent)
	if (!pev_valid(id))
		return
	
	if(!g_had_holybomb[id])
		return
		
	set_pev(id, pev_viewmodel2, WeaponModel[0])
	set_pev(id, pev_weaponmodel2, WeaponModel[1])
}

public HolyBomb_Exp(Ent, Float:Origin[3], Owner, Team)
{
	// Do Effect
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_EXPLOSION)
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2] + 16.0)
	write_short(g_Exp_SprId)
	write_byte(20)	// scale in 0.1's
	write_byte(30)	// framerate
	write_byte(4)	// flags
	message_end()  
	
	// Play Sound
	emit_sound(Ent, CHAN_BODY, WeaponSounds[0], 1.0, ATTN_NORM, 0, PITCH_NORM)

	static Float:PlayerOrigin[3]
	for(new i = 0; i < g_MaxPlayers; i++)
	{
		if(!is_user_alive(i))
			continue
		if(get_player_team(i) == Team)
			continue
		pev(i, pev_origin, PlayerOrigin)
		if(get_distance_f(Origin, PlayerOrigin) > PUMPKIN_RADIUS)
			continue
			
		if(!is_user_connected(Owner)) Owner = i
		ExecuteHamB(Ham_TakeDamage, i, "grenade", Owner, PUMPKIN_DAMAGE, DMG_CRUSH)
	}
}

stock get_player_team(id)
{
	if(!is_user_alive(id))
		return TEAM_NONE
		
	if(cs_get_user_team(id) == CS_TEAM_T) return TEAM_T
	else if(cs_get_user_team(id) == CS_TEAM_CT) return TEAM_CT
	
	return TEAM_NONE
}

stock fm_cs_get_weapon_ent_owner(ent)
{
	if (pev_valid(ent) != PDATA_SAFE)
		return -1
	
	return get_pdata_cbase(ent, OFFSET_WEAPONOWNER, OFFSET_LINUX_WEAPONS)
}
