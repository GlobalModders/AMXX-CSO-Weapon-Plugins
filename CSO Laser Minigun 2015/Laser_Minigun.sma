#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <cstrike>
#include <xs>
#include <fun>

#define PLUGIN "[CSO] Laser Minigun"
#define VERSION "1.0"
#define AUTHOR "Dias Pendragon"

#define DAMAGE_A 33 // 66 for Zombie
#define DAMAGE_B 90 // 180 for Zombie - This is base damage (level 1)
#define CLIP 120
#define BPAMMO 240
#define SPEED 0.06
#define RECOIL 0.5

#define PLAYER_SPEED 230.0
#define TIME_RELOAD 5.0
#define TIME_DRAW 2.0

#define CSW_LM CSW_M249
#define weapon_lm "weapon_m249"

#define MODEL_V "models/v_laserminigun.mdl"
#define MODEL_PA "models/p_laserminiguna.mdl"
#define MODEL_PB "models/p_laserminigunb.mdl"
#define MODEL_W "models/w_laserminigun.mdl"
#define MODEL_W_OLD "models/w_m249.mdl"

#define ANIM_EXT "m249"
#define HIKARI_CLASSNAME "hikari"
#define HIKARI_SPEED 2560.0
#define HIKARI_RADIUS 160.0

new const WeaponSounds[15][] =
{
	"weapons/laserminigun-1.wav",
	"weapons/laserminigun_exp1.wav",
	"weapons/laserminigun_exp2.wav",
	"weapons/laserminigun_exp3.wav",
	"weapons/laserminigun-charge_loop.wav", // Auto
	"weapons/laserminigun-charge_origin.wav",
	"weapons/laserminigun-charge_shoot.wav",
	"weapons/laserminigun-charge_start.wav",
	"weapons/laserminigun_change_end.wav", // Auto
	"weapons/laserminigun_idle.wav", // Auto
	"weapons/laserminigun_draw.wav", // Auto
	"weapons/laserminigun_clipin1.wav", // Auto
	"weapons/laserminigun_clipin2.wav", // Auto
	"weapons/laserminigun_clipout1.wav", // Auto
	"weapons/laserminigun_clipout2.wav" // Auto
}

new const WeaponResources[7][] = 
{
	"sprites/weapon_laserminigun.txt",
	"sprites/640hud14_2.spr",
	"sprites/640hud133_2.spr",
	"sprites/laserminigun_hit.spr",
	"sprites/laserminigun_hit1.spr",
	"sprites/laserminigun_hit2.spr",
	"sprites/laserminigun_hit3.spr"
}

new const WeaponResources2[4][] =
{
	"sprites/muzzleflash38.spr",
	"sprites/laserminigun1.spr",
	"sprites/laserminigun2.spr",
	"sprites/laserminigun3.spr"
}

enum
{
	STATE_NONE = 0,
	STATE_STARTING,
	STATE_CHARGING1,
	STATE_CHARGING2,
	STATE_CHARGING3,
	STATE_CHARGED,
	STATE_CHARGED2,
}

enum
{
	ANIME_IDLE = 0,
	ANIME_CHARGE_ORIGIN,
	ANIME_CHARGE_START,
	ANIME_CHARGE_LOOP,
	ANIME_CHARGE_SHOOT,
	ANIME_RELOAD,
	ANIME_DRAW,
	ANIME_SHOOT1,
	ANIME_SHOOT2,
	ANIME_SHOOT3,
	ANIME_CHARGE_END
}

// MACROS
#define Get_BitVar(%1,%2) (%1 & (1 << (%2 & 31)))
#define Set_BitVar(%1,%2) %1 |= (1 << (%2 & 31))
#define UnSet_BitVar(%1,%2) %1 &= ~(1 << (%2 & 31))

// Vars
new g_Had_LM, g_Clip[33], Float:g_Recoil[33][3], g_WeaponState[33], g_MyHikari[33]
new g_Event_LM, g_SmokePuff_SprId, g_Exp1, g_Exp2, g_Exp3
new g_MsgWeaponList, g_MsgCurWeapon, g_MaxPlayers

new g_Muzzleflash_Ent, g_Muzzleflash

// Safety
new g_IsConnected, g_IsAlive, g_PlayerWeapon[33], g_HamBot

public plugin_init() 
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	// Safety
	Register_SafetyFunc()
	register_event("HLTV", "Event_NewRound", "a", "1=0", "2=0")
	register_event("CurWeapon", "Event_CurWeapon", "be", "1=1")
	
	// Forward
	register_forward(FM_UpdateClientData, "fw_UpdateClientData_Post", 1)
	register_forward(FM_PlaybackEvent, "fw_PlaybackEvent")
	register_forward(FM_CmdStart, "fw_CmdStart")
	register_forward(FM_SetModel, "fw_SetModel")	
	register_forward(FM_AddToFullPack, "fw_AddToFullPack_post", 1)
	register_forward(FM_CheckVisibility, "fw_CheckVisibility")
	
	register_touch(HIKARI_CLASSNAME, "*", "fw_TouchHikari")
	
	// Ham
	RegisterHam(Ham_Item_Deploy, weapon_lm, "fw_Item_Deploy_Post", 1)	
	RegisterHam(Ham_Item_AddToPlayer, weapon_lm, "fw_Item_AddToPlayer_Post", 1)
	RegisterHam(Ham_Weapon_WeaponIdle, weapon_lm, "fw_Weapon_WeaponIdle_Post", 1)
	RegisterHam(Ham_Item_PostFrame, weapon_lm, "fw_Item_PostFrame")	
	RegisterHam(Ham_Weapon_Reload, weapon_lm, "fw_Weapon_Reload")
	RegisterHam(Ham_Weapon_Reload, weapon_lm, "fw_Weapon_Reload_Post", 1)	
	RegisterHam(Ham_Weapon_PrimaryAttack, weapon_lm, "fw_Weapon_PrimaryAttack")
	RegisterHam(Ham_Weapon_PrimaryAttack, weapon_lm, "fw_Weapon_PrimaryAttack_Post", 1)
	
	RegisterHam(Ham_TraceAttack, "worldspawn", "fw_TraceAttack_World")
	RegisterHam(Ham_TraceAttack, "player", "fw_TraceAttack_Player")	

	g_MsgCurWeapon = get_user_msgid("CurWeapon")
	g_MsgWeaponList = get_user_msgid("WeaponList")
	g_MaxPlayers = get_maxplayers()
	
	register_clcmd("say /get", "Get_LM")
	register_clcmd("weapon_laserminigun", "Hook_Weapon")
}

public plugin_precache()
{
	precache_model(MODEL_V)
	precache_model(MODEL_PA)
	precache_model(MODEL_PB)
	precache_model(MODEL_W)

	for(new i = 0; i < sizeof(WeaponSounds); i++)
		precache_sound(WeaponSounds[i])
	
	precache_generic(WeaponResources[0])
	precache_model(WeaponResources[1])
	precache_model(WeaponResources[2])
	precache_model(WeaponResources[3])
	g_Exp1 = precache_model(WeaponResources[4])
	g_Exp2 = precache_model(WeaponResources[5])
	g_Exp3 = precache_model(WeaponResources[6])
	
	for(new i = 0; i < sizeof(WeaponResources2); i++)
		precache_model(WeaponResources2[i])

	g_SmokePuff_SprId = engfunc(EngFunc_PrecacheModel, WeaponResources[3])
	register_forward(FM_PrecacheEvent, "fw_PrecacheEvent_Post", 1)
	
	// Muzzleflash
	g_Muzzleflash_Ent = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"))
	
	engfunc(EngFunc_SetModel, g_Muzzleflash_Ent, WeaponResources2[0])
	set_pev(g_Muzzleflash_Ent, pev_scale, 0.1)
	
	set_pev(g_Muzzleflash_Ent, pev_rendermode, kRenderTransTexture)
	set_pev(g_Muzzleflash_Ent, pev_renderamt, 0.0)
}

public fw_PrecacheEvent_Post(type, const name[])
{
	if(equal("events/m249.sc", name)) g_Event_LM = get_orig_retval()		
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
	RegisterHamFromEntity(Ham_TraceAttack, id, "fw_TraceAttack_Player")	
}

public client_disconnect(id)
{
	Safety_Disconnected(id)
	
	if(pev_valid(g_MyHikari[id]))
	{
		set_pev(g_MyHikari[id], pev_nextthink, get_gametime() + 0.1)
		set_pev(g_MyHikari[id], pev_flags, FL_KILLME)
	}
}

public Get_LM(id)
{
	g_WeaponState[id] = STATE_NONE
	
	Set_BitVar(g_Had_LM, id)
	give_item(id, weapon_lm)
	
	// Check Light
	if(pev_valid(g_MyHikari[id]) == 2) 
	{
		set_pev(g_MyHikari[id], pev_nextthink, get_gametime() + 0.1)
		set_pev(g_MyHikari[id], pev_flags, FL_KILLME)
	}
	
	// Clip & Ammo
	static Ent; Ent = fm_get_user_weapon_entity(id, CSW_LM)
	if(!pev_valid(Ent)) return
	
	cs_set_weapon_ammo(Ent, CLIP)
	cs_set_user_bpammo(id, CSW_LM, BPAMMO)
	
	message_begin(MSG_ONE_UNRELIABLE, g_MsgCurWeapon, _, id)
	write_byte(1)
	write_byte(CSW_LM)
	write_byte(CLIP)
	message_end()
}

public Remove_LM(id)
{
	UnSet_BitVar(g_Had_LM, id)
}

public Hook_Weapon(id)
{
	engclient_cmd(id, weapon_lm)
	return PLUGIN_HANDLED
}

public Event_NewRound()
{
	remove_entity_name(HIKARI_CLASSNAME)
} 

public Event_CurWeapon(id)
{
	static CSW; CSW = read_data(2)
	if(CSW != CSW_LM)
		return
	if(!Get_BitVar(g_Had_LM, id))	
		return 
		
	static Ent; Ent = fm_get_user_weapon_entity(id, CSW_LM)
	if(!pev_valid(Ent)) return
	
	set_pdata_float(Ent, 46, SPEED, 4)
	set_pdata_float(Ent, 47, SPEED, 4)
}

public fw_UpdateClientData_Post(id, sendweapons, cd_handle)
{
	if(!is_alive(id))
		return FMRES_IGNORED	
	if(get_player_weapon(id) == CSW_LM && Get_BitVar(g_Had_LM, id))
		set_cd(cd_handle, CD_flNextAttack, get_gametime() + 0.001) 
	
	return FMRES_HANDLED
}

public fw_PlaybackEvent(flags, invoker, eventid, Float:delay, Float:origin[3], Float:angles[3], Float:fparam1, Float:fparam2, iParam1, iParam2, bParam1, bParam2)
{
	if (!is_connected(invoker))
		return FMRES_IGNORED	
	if(get_player_weapon(invoker) != CSW_LM || !Get_BitVar(g_Had_LM, invoker))
		return FMRES_IGNORED
		
	if(eventid == g_Event_LM)
	{
		engfunc(EngFunc_PlaybackEvent, flags | FEV_HOSTONLY, invoker, eventid, delay, origin, angles, fparam1, fparam2, iParam1, iParam2, bParam1, bParam2)
		Set_WeaponAnim(invoker, ANIME_SHOOT1)
		emit_sound(invoker, CHAN_WEAPON, WeaponSounds[0], 1.0, 0.4, 0, 94 + random_num(0, 15))

		//Play_AttackAnimation(invoker, 0)

		return FMRES_SUPERCEDE
	}
	
	return FMRES_IGNORED
}

/*public Play_AttackAnimation(id, Right)
{
	static iAnimDesired, szAnimation[64]
	static iFlags; iFlags = pev(id, pev_flags)

	if(!Right)
	{	
		formatex(szAnimation, charsmax(szAnimation), iFlags & FL_DUCKING ? "crouch_shoot_%s" : "ref_shoot_%s", ANIM_EXT);
	} else {
		formatex(szAnimation, charsmax(szAnimation), iFlags & FL_DUCKING ? "crouch_shoot2_%s" : "ref_shoot2_%s", ANIM_EXT);
	}
	
	if((iAnimDesired = lookup_sequence(id, szAnimation)) == -1)
		iAnimDesired = 0;
	
	set_pev(id, pev_sequence, iAnimDesired)
}*/

public fw_CmdStart(id, uc_handle, seed)
{
	if(!is_alive(id))
		return
	if(get_player_weapon(id) != CSW_LM || !Get_BitVar(g_Had_LM, id))
		return
	
	static Button; Button = get_uc(uc_handle, UC_Buttons)
	static OldButton; OldButton = pev(id, pev_oldbuttons)
	static Ent; Ent = fm_get_user_weapon_entity(id, CSW_LM)
	
	if(!pev_valid(Ent))
		return
		
	if(Button & IN_ATTACK2)
	{
		if(get_pdata_float(id, 83, 5) > 0.0) 
			return
		if(cs_get_weapon_ammo(Ent) < 5)
			return
			
		switch(g_WeaponState[id])
		{
			case STATE_STARTING: 
			{
				Set_PlayerNextAttack(id, 0.5)
				Set_WeaponAnim(id, ANIME_CHARGE_ORIGIN)
				
				Light_Handle(id, 0)
				emit_sound(id, CHAN_WEAPON, WeaponSounds[5], 1.0, 0.4, 0, 94 + random_num(0, 15))
				
				g_WeaponState[id] = STATE_CHARGING1
			}
			case STATE_CHARGING1:
			{
				Set_PlayerNextAttack(id, 1.0)
				Set_WeaponAnim(id, ANIME_CHARGE_START)
				
				Light_Handle(id, 1)
				emit_sound(id, CHAN_WEAPON, WeaponSounds[7], 1.0, 0.4, 0, 94 + random_num(0, 15))
				
				g_WeaponState[id] = STATE_CHARGING2
			}
			case STATE_CHARGING2:
			{
				Set_PlayerNextAttack(id, 1.0)
				g_WeaponState[id] = STATE_CHARGING3
				
				Light_Handle(id, 2)
			}
			case STATE_CHARGING3:
			{
				Set_PlayerNextAttack(id, 0.75)
				g_WeaponState[id] = STATE_CHARGED
				
				Light_Handle(id, 3)
			}
			case STATE_CHARGED:
			{
				Set_PlayerNextAttack(id, 0.1)
				g_WeaponState[id] = STATE_CHARGED2
				
				Light_Handle(id, 4)
			}
			case STATE_CHARGED2:
			{
				Set_WeaponAnim(id, ANIME_CHARGE_LOOP)
				Set_PlayerNextAttack(id, 1.0)
				
				Light_Handle(id, 4)
			}
			default:
			{
				Set_PlayerNextAttack(id, 0.25)
				g_WeaponState[id] = STATE_STARTING
			}
		}
	} else {
		if(OldButton & IN_ATTACK2)
		{
			switch(g_WeaponState[id])
			{
				case STATE_STARTING: 
				{
					Set_PlayerNextAttack(id, 0.25)
					Set_WeaponAnim(id, ANIME_CHARGE_END)
				}
				case STATE_CHARGING1:
				{
					Set_PlayerNextAttack(id, 0.25)
					Set_WeaponAnim(id, ANIME_CHARGE_END)
					
					Light_Handle(id, -1)
				}
				case STATE_CHARGING2:
				{
					Set_PlayerNextAttack(id, 1.0)
					Set_WeaponAnim(id, ANIME_CHARGE_SHOOT)
					
					ChargedShot(id, 1)
				}
				case STATE_CHARGING3:
				{
					Set_PlayerNextAttack(id, 1.0)
					Set_WeaponAnim(id, ANIME_CHARGE_SHOOT)
					
					ChargedShot(id, 1)
				}
				case STATE_CHARGED:
				{
					Set_WeaponAnim(id, ANIME_CHARGE_SHOOT)
					Set_PlayerNextAttack(id, 1.0)
					
					ChargedShot(id, 2)
				}
				case STATE_CHARGED2:
				{
					Set_WeaponAnim(id, ANIME_CHARGE_SHOOT)
					Set_PlayerNextAttack(id, 1.0)
					
					ChargedShot(id, 3)
				}
			}
			
			g_WeaponState[id] = STATE_NONE
		}
	}
}

public Light_Handle(id, Code)
{
	static Ent, Ammo; Ent = fm_get_user_weapon_entity(id, CSW_LM)
	if(!pev_valid(Ent)) return
	Ammo = cs_get_weapon_ammo(Ent)
	
	switch(Code)
	{
		case 0:
		{
			g_MyHikari[id] = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "env_sprite"))
			
			engfunc(EngFunc_SetModel, g_MyHikari[id], WeaponResources2[1])
			set_pev(g_MyHikari[id], pev_scale, 0.0)
			set_pev(g_MyHikari[id], pev_impulse, 1125)
			
			set_pev(g_MyHikari[id], pev_rendermode, kRenderTransTexture)
			set_pev(g_MyHikari[id], pev_renderamt, 0.0)
		}
		case 1:
		{
			if(pev_valid(g_MyHikari[id]) == 2)
			{
				engfunc(EngFunc_SetModel, g_MyHikari[id], WeaponResources2[1])
				set_pev(g_MyHikari[id], pev_scale, 0.1)
				
				set_pev(id, pev_weaponmodel2, MODEL_PB)
			}
		}
		case 2:
		{
			if(pev_valid(g_MyHikari[id]) == 2)
			{
				set_pev(g_MyHikari[id], pev_frame, float(random_num(0, 8)))
				engfunc(EngFunc_SetModel, g_MyHikari[id], WeaponResources2[1])
				set_pev(g_MyHikari[id], pev_scale, 0.15)
			}
		}
		case 3:
		{
			if(pev_valid(g_MyHikari[id]) == 2)
			{
				if(Ammo >= 20) engfunc(EngFunc_SetModel, g_MyHikari[id], WeaponResources2[2])
				set_pev(g_MyHikari[id], pev_frame, float(random_num(0, 8)))
				set_pev(g_MyHikari[id], pev_scale, 0.225)
			}
		}
		case 4:
		{
			if(pev_valid(g_MyHikari[id]) == 2)
			{
				if(Ammo >= 30) engfunc(EngFunc_SetModel, g_MyHikari[id], WeaponResources2[3])
				set_pev(g_MyHikari[id], pev_frame, float(random_num(0, 8)))
				set_pev(g_MyHikari[id], pev_scale, 0.3)
			}
		}
		default:
		{
			if(pev_valid(g_MyHikari[id]) == 2)
			{
				set_pev(g_MyHikari[id], pev_nextthink, get_gametime() + 0.1)
				set_pev(g_MyHikari[id], pev_flags, FL_KILLME)
				
				set_pev(id, pev_weaponmodel2, MODEL_PA)
			}
		}
	}
}

public ChargedShot(id, Level)
{
	set_pev(id, pev_weaponmodel2, MODEL_PA)
	
	static LM, Ammo; LM = fm_get_user_weapon_entity(id, CSW_LM)
	if(!pev_valid(LM)) return
	Ammo = cs_get_weapon_ammo(LM)
	
	emit_sound(id, CHAN_WEAPON, WeaponSounds[6], 1.0, 0.4, 0, 94 + random_num(0, 15))
	
	// Create Ammo
	static Float:StartOrigin[3], Float:TargetOrigin[3], Float:MyVelocity[3], Float:VecLength
	
	get_position(id, 48.0, 10.0, -5.0, StartOrigin)
	get_position(id, 1024.0, 0.0, 0.0, TargetOrigin)
	
	pev(id, pev_velocity, MyVelocity)
	VecLength = vector_length(MyVelocity)
	
	if(VecLength) 
	{
		TargetOrigin[0] += random_float(-16.0, 16.0); TargetOrigin[1] += random_float(-16.0, 16.0); TargetOrigin[2] += random_float(-16.0, 16.0)
	} else {
		TargetOrigin[0] += random_float(-8.0, 8.0); TargetOrigin[1] += random_float(-8.0, 8.0); TargetOrigin[2] += random_float(-8.0, 8.0)
	}
	
	static Ent; Ent = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "env_sprite"))
	if(!pev_valid(Ent)) return
	
	// Set info for ent
	set_pev(Ent, pev_movetype, MOVETYPE_FLY)
	set_pev(Ent, pev_rendermode, kRenderTransAdd)
	set_pev(Ent, pev_renderamt, 255.0)
	set_pev(Ent, pev_iuser1, id) // Better than pev_owner
	set_pev(Ent, pev_iuser2, get_user_team(id))

	entity_set_string(Ent, EV_SZ_classname, HIKARI_CLASSNAME)
	
	switch(Level)
	{
		case 1:
		{
			cs_set_weapon_ammo(LM, max(Ammo - 10, 1))
			set_pev(Ent, pev_scale, 0.25)
			set_pev(Ent, pev_iuser3, 1)
			engfunc(EngFunc_SetModel, Ent, WeaponResources2[1])
		}
		case 2:
		{
			if(Ammo >= 20) 
			{
				cs_set_weapon_ammo(LM, max(Ammo - 20, 1))
				set_pev(Ent, pev_scale, 0.5)
				set_pev(Ent, pev_iuser3, 2)
				engfunc(EngFunc_SetModel, Ent, WeaponResources2[2])
			} else {
				cs_set_weapon_ammo(LM, max(Ammo - 10, 1))
				set_pev(Ent, pev_scale, 0.25)
				set_pev(Ent, pev_iuser3, 1)
				engfunc(EngFunc_SetModel, Ent, WeaponResources2[1])
			}
		}
		case 3:
		{
			if(Ammo >= 30)
			{
				cs_set_weapon_ammo(LM, max(Ammo - 30, 1))
				set_pev(Ent, pev_scale, 0.75)
				set_pev(Ent, pev_iuser3, 3)
				engfunc(EngFunc_SetModel, Ent, WeaponResources2[3])
			} else if(Ammo >= 20) {
				cs_set_weapon_ammo(LM, max(Ammo - 20, 1))
				set_pev(Ent, pev_scale, 0.5)
				set_pev(Ent, pev_iuser3, 2)
				engfunc(EngFunc_SetModel, Ent, WeaponResources2[2])
			} else {
				cs_set_weapon_ammo(LM, max(Ammo - 10, 1))
				set_pev(Ent, pev_scale, 0.25)
				set_pev(Ent, pev_iuser3, 1)
				engfunc(EngFunc_SetModel, Ent, WeaponResources2[1])
			}
		}
	}
	
	set_pev(Ent, pev_mins, Float:{-1.0, -1.0, -1.0})
	set_pev(Ent, pev_maxs, Float:{1.0, 1.0, 1.0})
	set_pev(Ent, pev_origin, StartOrigin)
	set_pev(Ent, pev_gravity, 0.01)
	set_pev(Ent, pev_solid, SOLID_TRIGGER)
	set_pev(Ent, pev_frame, 0.0)
	
	set_pev(Ent, pev_nextthink, halflife_time() + 0.1)
	
	static Float:Velocity[3]
	get_speed_vector(StartOrigin, TargetOrigin, HIKARI_SPEED, Velocity)
	set_pev(Ent, pev_velocity, Velocity)
}

public fw_TouchHikari(Ent, Id)
{
	if(!pev_valid(Ent))
		return
		
	// Exp Sprite
	static Float:Origin[3]/*, Team*/, id, Level, Float:Damage; 
	pev(Ent, pev_origin, Origin)
	
	id = pev(Ent, pev_iuser1)
	//Team = pev(Ent, pev_iuser2)
	Level = pev(Ent, pev_iuser3)
	Damage = float(DAMAGE_B)
	
	switch(Level)
	{
		case 2: {
			message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
			write_byte(TE_EXPLOSION)
			engfunc(EngFunc_WriteCoord, Origin[0])
			engfunc(EngFunc_WriteCoord, Origin[1])
			engfunc(EngFunc_WriteCoord, Origin[2])
			write_short(g_Exp2)
			write_byte(20)
			write_byte(15)
			write_byte(4)
			message_end()	
			
			Damage *= 2.0
			
			emit_sound(Ent, CHAN_WEAPON, WeaponSounds[2], 1.0, 0.4, 0, 94 + random_num(0, 15))
		}
		case 3: {
			message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
			write_byte(TE_EXPLOSION)
			engfunc(EngFunc_WriteCoord, Origin[0])
			engfunc(EngFunc_WriteCoord, Origin[1])
			engfunc(EngFunc_WriteCoord, Origin[2])
			write_short(g_Exp3)
			write_byte(30)
			write_byte(15)
			write_byte(4)
			message_end()	
			
			Damage *= 3.0
			
			emit_sound(Ent, CHAN_WEAPON, WeaponSounds[3], 1.0, 0.4, 0, 94 + random_num(0, 15))
		}
		default: {
			message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
			write_byte(TE_EXPLOSION)
			engfunc(EngFunc_WriteCoord, Origin[0])
			engfunc(EngFunc_WriteCoord, Origin[1])
			engfunc(EngFunc_WriteCoord, Origin[2])
			write_short(g_Exp1)
			write_byte(10)
			write_byte(15)
			write_byte(4)
			message_end()	
			
			Damage *= 1.0
			
			emit_sound(Ent, CHAN_WEAPON, WeaponSounds[1], 1.0, 0.4, 0, 94 + random_num(0, 15))
		}
		
	}
	static Float:MyOrigin[3]
	if(is_connected(id))
	{
		// Damage
		for(new i = 0; i < g_MaxPlayers; i++)
		{
			if(!is_alive(i))
				continue
			//if(Team == get_user_team(i))
			//	continue
			if(id == i)
				continue
			if(entity_range(Ent, i) > HIKARI_RADIUS)
				continue
				
			pev(i, pev_origin, MyOrigin)
				
			engfunc(EngFunc_MessageBegin, MSG_PAS, SVC_TEMPENTITY, MyOrigin, 0)
			write_byte(TE_EXPLOSION)
			engfunc(EngFunc_WriteCoord, MyOrigin[0])
			engfunc(EngFunc_WriteCoord, MyOrigin[1])
			engfunc(EngFunc_WriteCoord, MyOrigin[2])
			write_short(g_SmokePuff_SprId)
			write_byte(3)
			write_byte(20)
			write_byte(4)
			message_end()
				
			ExecuteHamB(Ham_TakeDamage, i, 0, id, i != Id ? Damage : Damage * 2.0, DMG_SHOCK)
		}
	}
	
	// Remove Ent
	set_pev(Ent, pev_flags, FL_KILLME)
}

public fw_SetModel(entity, model[])
{
	if(!pev_valid(entity))
		return FMRES_IGNORED
	
	static Classname[32]
	pev(entity, pev_classname, Classname, sizeof(Classname))
	
	if(!equal(Classname, "weaponbox"))
		return FMRES_IGNORED
	
	static iOwner
	iOwner = pev(entity, pev_owner)
	
	if(equal(model, MODEL_W_OLD))
	{
		static weapon; weapon = fm_find_ent_by_owner(-1, weapon_lm, entity)
		
		if(!pev_valid(weapon))
			return FMRES_IGNORED;
		
		if(Get_BitVar(g_Had_LM, iOwner))
		{
			Remove_LM(iOwner)
			
			set_pev(weapon, pev_impulse, 1992015)
			engfunc(EngFunc_SetModel, entity, MODEL_W)
			
			return FMRES_SUPERCEDE
		}
	}

	return FMRES_IGNORED;
}

public fw_AddToFullPack_post(esState, iE, iEnt, iHost, iHostFlags, iPlayer, pSet)
{
	if(iEnt == g_Muzzleflash_Ent)
	{
		if(Get_BitVar(g_Muzzleflash, iHost))
		{
			set_es(esState, ES_Frame, float(random_num(0, 2)))
				
			set_es(esState, ES_RenderMode, kRenderTransAdd)
			set_es(esState, ES_RenderAmt, 255.0)
			
			UnSet_BitVar(g_Muzzleflash, iHost)
		}
			
		set_es(esState, ES_Skin, iHost)
		set_es(esState, ES_Body, 1)
		set_es(esState, ES_AimEnt, iHost)
		set_es(esState, ES_MoveType, MOVETYPE_FOLLOW)
	} else {
		if(is_alive(iHost) && get_player_weapon(iHost) == CSW_LM && Get_BitVar(g_Had_LM, iHost))
		{
			if(g_WeaponState[iHost] < STATE_CHARGING2)
				return
			if(g_MyHikari[iHost] == iEnt)
			{
				set_es(esState, ES_Frame, float(random_num(0, 8)))
					
				set_es(esState, ES_RenderMode, kRenderTransAdd)
				set_es(esState, ES_RenderAmt, 255.0)
				
				set_es(esState, ES_Skin, iHost)
				set_es(esState, ES_Body, 1)
				set_es(esState, ES_AimEnt, iHost)
				set_es(esState, ES_MoveType, MOVETYPE_FOLLOW)
			}
		} 
	}
}

public fw_CheckVisibility(iEntity, pSet)
{
	if(iEntity == g_Muzzleflash_Ent)
	{
		forward_return(FMV_CELL, 1)
		return FMRES_SUPERCEDE
	} else if(pev(iEntity, pev_impulse) == 1125) {
		forward_return(FMV_CELL, 1)
		return FMRES_SUPERCEDE
	}
	
	return FMRES_IGNORED
}

public fw_Item_Deploy_Post(Ent)
{
	if(pev_valid(Ent) != 2)
		return
	static Id; Id = get_pdata_cbase(Ent, 41, 4)
	if(get_pdata_cbase(Id, 373) != Ent)
		return
	if(!Get_BitVar(g_Had_LM, Id))
		return
		
	g_WeaponState[Id] = STATE_NONE

	set_pev(Id, pev_viewmodel2, MODEL_V)
	set_pev(Id, pev_weaponmodel2, MODEL_PA)

	set_pdata_string(Id, (492) * 4, ANIM_EXT, -1 , 20)
	set_pev(Id, pev_maxspeed, PLAYER_SPEED)
	
	Set_PlayerNextAttack(Id, TIME_DRAW)
	Set_WeaponIdleTime(Id, CSW_LM, TIME_DRAW + 0.25)
	
	// Check Light
	if(pev_valid(g_MyHikari[Id]) == 2)
	{
		set_pev(g_MyHikari[Id], pev_nextthink, get_gametime() + 0.1)
		set_pev(g_MyHikari[Id], pev_flags, FL_KILLME)
	}
	
	Set_WeaponAnim(Id, ANIME_DRAW)
}

public fw_Item_AddToPlayer_Post(Ent, id)
{
	if(!pev_valid(Ent))
		return HAM_IGNORED
		
	if(pev(Ent, pev_impulse) == 1992015)
	{
		Set_BitVar(g_Had_LM, id)
		set_pev(Ent, pev_impulse, 0)
	}
	
	if(Get_BitVar(g_Had_LM, id))
	{
		message_begin(MSG_ONE_UNRELIABLE, g_MsgWeaponList, _, id)
		write_string("weapon_laserminigun")
		write_byte(3)
		write_byte(240)
		write_byte(-1)
		write_byte(-1)
		write_byte(0)
		write_byte(4)
		write_byte(CSW_LM)
		write_byte(0)
		message_end()
	}
	
	return HAM_HANDLED	
}

public fw_Item_PostFrame(ent)
{
	static id; id = pev(ent, pev_owner)
	if(!is_user_alive(id))
		return HAM_IGNORED
	if(!Get_BitVar(g_Had_LM, id))
		return HAM_IGNORED	
	
	static Float:flNextAttack; flNextAttack = get_pdata_float(id, 83, 5)
	static bpammo; bpammo = cs_get_user_bpammo(id, CSW_LM)
	
	static iClip; iClip = get_pdata_int(ent, 51, 4)
	static fInReload; fInReload = get_pdata_int(ent, 54, 4)
	
	if(fInReload && flNextAttack <= 0.0)
	{
		static temp1
		temp1 = min(CLIP - iClip, bpammo)

		set_pdata_int(ent, 51, iClip + temp1, 4)
		cs_set_user_bpammo(id, CSW_LM, bpammo - temp1)		
		
		set_pdata_int(ent, 54, 0, 4)
		fInReload = 0
	}		
	
	return HAM_IGNORED
}

public fw_Weapon_Reload(ent)
{
	static id; id = pev(ent, pev_owner)
	if(!is_user_alive(id))
		return HAM_IGNORED
	if(!Get_BitVar(g_Had_LM, id))
		return HAM_IGNORED	

	g_Clip[id] = -1
		
	static BPAmmo; BPAmmo = cs_get_user_bpammo(id, CSW_LM)
	static iClip; iClip = get_pdata_int(ent, 51, 4)
		
	if(BPAmmo <= 0)
		return HAM_SUPERCEDE
	if(iClip >= CLIP)
		return HAM_SUPERCEDE		
			
	g_Clip[id] = iClip	
	
	return HAM_HANDLED
}

public fw_Weapon_Reload_Post(ent)
{
	static id; id = pev(ent, pev_owner)
	if(!is_user_alive(id))
		return HAM_IGNORED
	if(!Get_BitVar(g_Had_LM, id))
		return HAM_IGNORED	
	
	if((get_pdata_int(ent, 54, 4) == 1))
	{ // Reload
		if(g_Clip[id] == -1)
			return HAM_IGNORED
		
		set_pdata_int(ent, 51, g_Clip[id], 4)
		Set_WeaponAnim(id, ANIME_RELOAD)
		
		Set_PlayerNextAttack(id, TIME_RELOAD)
	}
	
	return HAM_HANDLED
}

public fw_Weapon_WeaponIdle_Post( iEnt )
{
	if(pev_valid(iEnt) != 2)
		return
	static Id; Id = get_pdata_cbase(iEnt, 41, 4)
	if(get_pdata_cbase(Id, 373) != iEnt)
		return
	if(!Get_BitVar(g_Had_LM, Id))
		return
		
	if(get_pdata_float(iEnt, 48, 4) <= 0.25)
	{
		Set_WeaponAnim(Id, ANIME_IDLE)
		set_pdata_float(iEnt, 48, 20.0, 4)
	}	
}

public fw_Weapon_PrimaryAttack(Ent)
{
	static id; id = pev(Ent, pev_owner)
	pev(id, pev_punchangle, g_Recoil[id])
	
	return HAM_IGNORED
}

public fw_Weapon_PrimaryAttack_Post(Ent)
{
	static id; id = pev(Ent, pev_owner)
	
	if(Get_BitVar(g_Had_LM, id) && cs_get_weapon_ammo(Ent) > 0)
	{
		static Float:Push[3]
		pev(id, pev_punchangle, Push)
		xs_vec_sub(Push, g_Recoil[id], Push)
		
		xs_vec_mul_scalar(Push, RECOIL, Push)
		xs_vec_add(Push, g_Recoil[id], Push)
		set_pev(id, pev_punchangle, Push)
		
		set_pdata_float(Ent, 62 , 0.1, 4)
		Set_BitVar(g_Muzzleflash, id)
	}
}

public fw_TraceAttack_World(Victim, Attacker, Float:Damage, Float:Direction[3], Ptr, DamageBits)
{
	if(!is_connected(Attacker))
		return HAM_IGNORED	
	if(get_player_weapon(Attacker) != CSW_LM || !Get_BitVar(g_Had_LM, Attacker))
		return HAM_IGNORED
		
	static Float:flEnd[3], Float:vecPlane[3]
		
	get_tr2(Ptr, TR_vecEndPos, flEnd)
	get_tr2(Ptr, TR_vecPlaneNormal, vecPlane)		
			
	Make_BulletHole(Attacker, flEnd, Damage)
	Make_BulletSmoke(Attacker, Ptr)

	SetHamParamFloat(3, float(DAMAGE_A))
	
	return HAM_HANDLED
}

public fw_TraceAttack_Player(Victim, Attacker, Float:Damage, Float:Direction[3], Ptr, DamageBits)
{
	if(!is_connected(Attacker))
		return HAM_IGNORED	
	if(get_player_weapon(Attacker) != CSW_LM || !Get_BitVar(g_Had_LM, Attacker))
		return HAM_IGNORED

	static Float:flEnd[3]
	get_tr2(Ptr, TR_vecEndPos, flEnd)
		
	engfunc(EngFunc_MessageBegin, MSG_PAS, SVC_TEMPENTITY, flEnd, 0)
	write_byte(TE_EXPLOSION)
	engfunc(EngFunc_WriteCoord, flEnd[0])
	engfunc(EngFunc_WriteCoord, flEnd[1])
	engfunc(EngFunc_WriteCoord, flEnd[2])
	write_short(g_SmokePuff_SprId)
	write_byte(5)
	write_byte(30)
	write_byte(TE_EXPLFLAG_NODLIGHTS | TE_EXPLFLAG_NOSOUND | TE_EXPLFLAG_NOPARTICLES)
	message_end()
		
	SetHamParamFloat(3, float(DAMAGE_A))
	
	return HAM_HANDLED
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

stock Set_WeaponAnim(id, anim)
{
	set_pev(id, pev_weaponanim, anim)
	
	message_begin(MSG_ONE_UNRELIABLE, SVC_WEAPONANIM, {0, 0, 0}, id)
	write_byte(anim)
	write_byte(pev(id, pev_body))
	message_end()
}

stock Make_BulletHole(id, Float:Origin[3], Float:Damage)
{
	// Find target
	static Decal; Decal = random_num(41, 45)
	static LoopTime; 
	
	if(Damage > 100.0) LoopTime = 2
	else LoopTime = 1
	
	for(new i = 0; i < LoopTime; i++)
	{
		// Put decal on "world" (a wall)
		message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
		write_byte(TE_WORLDDECAL)
		engfunc(EngFunc_WriteCoord, Origin[0])
		engfunc(EngFunc_WriteCoord, Origin[1])
		engfunc(EngFunc_WriteCoord, Origin[2])
		write_byte(Decal)
		message_end()
		
		// Show sparcles
		message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
		write_byte(TE_GUNSHOTDECAL)
		engfunc(EngFunc_WriteCoord, Origin[0])
		engfunc(EngFunc_WriteCoord, Origin[1])
		engfunc(EngFunc_WriteCoord, Origin[2])
		write_short(id)
		write_byte(Decal)
		message_end()
	}
}

stock Make_BulletSmoke(id, TrResult)
{
	static Float:vecSrc[3], Float:vecEnd[3], TE_FLAG
	
	get_weapon_attachment(id, vecSrc)
	global_get(glb_v_forward, vecEnd)
    
	xs_vec_mul_scalar(vecEnd, 8192.0, vecEnd)
	xs_vec_add(vecSrc, vecEnd, vecEnd)

	get_tr2(TrResult, TR_vecEndPos, vecSrc)
	get_tr2(TrResult, TR_vecPlaneNormal, vecEnd)
    
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
	write_short(g_SmokePuff_SprId)
	write_byte(2)
	write_byte(50)
	write_byte(TE_FLAG)
	message_end()
}

stock get_weapon_attachment(id, Float:output[3], Float:fDis = 40.0)
{ 
	static Float:vfEnd[3], viEnd[3] 
	get_user_origin(id, viEnd, 3)  
	IVecFVec(viEnd, vfEnd) 
	
	static Float:fOrigin[3], Float:fAngle[3]
	
	pev(id, pev_origin, fOrigin) 
	pev(id, pev_view_ofs, fAngle)
	
	xs_vec_add(fOrigin, fAngle, fOrigin) 
	
	static Float:fAttack[3]
	
	xs_vec_sub(vfEnd, fOrigin, fAttack)
	xs_vec_sub(vfEnd, fOrigin, fAttack) 
	
	static Float:fRate
	
	fRate = fDis / vector_length(fAttack)
	xs_vec_mul_scalar(fAttack, fRate, fAttack)
	
	xs_vec_add(fOrigin, fAttack, output)
}

stock get_position(id,Float:forw, Float:right, Float:up, Float:vStart[])
{
	new Float:vOrigin[3], Float:vAngle[3], Float:vForward[3], Float:vRight[3], Float:vUp[3]
	
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

stock get_speed_vector(const Float:origin1[3],const Float:origin2[3],Float:speed, Float:new_velocity[3])
{
	new_velocity[0] = origin2[0] - origin1[0]
	new_velocity[1] = origin2[1] - origin1[1]
	new_velocity[2] = origin2[2] - origin1[2]
	new Float:num = floatsqroot(speed*speed / (new_velocity[0]*new_velocity[0] + new_velocity[1]*new_velocity[1] + new_velocity[2]*new_velocity[2]))
	new_velocity[0] *= num
	new_velocity[1] *= num
	new_velocity[2] *= num
	
	return 1;
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


stock Get_Position(id,Float:forw, Float:right, Float:up, Float:vStart[])
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

stock Eject_Shell(id, Shell_ModelIndex, Float:Time) // By Dias
{
	static Ent; Ent = get_pdata_cbase(id, 373, 5)
	if(!pev_valid(Ent))
		return

        set_pdata_int(Ent, 57, Shell_ModelIndex, 4)
        set_pdata_float(id, 111, get_gametime() + Time)
}


public Eject_Shell2(id, ShellID, Right)
{
	static Float:player_origin[3], Float:origin[3], Float:origin2[3], Float:gunorigin[3], Float:oldangles[3], Float:v_forward[3], Float:v_forward2[3], Float:v_up[3], Float:v_up2[3], Float:v_right[3], Float:v_right2[3], Float:viewoffsets[3];
	
	pev(id,pev_v_angle, oldangles); pev(id,pev_origin,player_origin); pev(id, pev_view_ofs, viewoffsets);

	engfunc(EngFunc_MakeVectors, oldangles)
	
	global_get(glb_v_forward, v_forward); global_get(glb_v_up, v_up); global_get(glb_v_right, v_right);
	global_get(glb_v_forward, v_forward2); global_get(glb_v_up, v_up2); global_get(glb_v_right, v_right2);
	
	xs_vec_add(player_origin, viewoffsets, gunorigin);
	
	if(!Right)
	{
		xs_vec_mul_scalar(v_forward, 9.0, v_forward); xs_vec_mul_scalar(v_right, -5.0, v_right);
		xs_vec_mul_scalar(v_up, -3.7, v_up);
		xs_vec_mul_scalar(v_forward2, 8.9, v_forward2); xs_vec_mul_scalar(v_right2, -4.9, v_right2);
		xs_vec_mul_scalar(v_up2, -4.0, v_up2);
	} else {
		xs_vec_mul_scalar(v_forward, 9.0, v_forward); xs_vec_mul_scalar(v_right, 5.0, v_right);
		xs_vec_mul_scalar(v_up, -3.7, v_up);
		xs_vec_mul_scalar(v_forward2, 8.9, v_forward2); xs_vec_mul_scalar(v_right2, 4.9, v_right2);
		xs_vec_mul_scalar(v_up2, -4.0, v_up2);
	}
	
	xs_vec_add(gunorigin, v_forward, origin);
	xs_vec_add(gunorigin, v_forward2, origin2);
	xs_vec_add(origin, v_right, origin);
	xs_vec_add(origin2, v_right2, origin2);
	xs_vec_add(origin, v_up, origin);
	xs_vec_add(origin2, v_up2, origin2);

	static Float:velocity[3]
	get_speed_vector(origin2, origin, random_float(140.0, 160.0), velocity)

	static angle; angle = random_num(0, 360)

	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_MODEL)
	engfunc(EngFunc_WriteCoord, origin[0])
	engfunc(EngFunc_WriteCoord,origin[1])
	engfunc(EngFunc_WriteCoord,origin[2])
	engfunc(EngFunc_WriteCoord,velocity[0])
	engfunc(EngFunc_WriteCoord,velocity[1])
	engfunc(EngFunc_WriteCoord,velocity[2])
	write_angle(angle)
	write_short(ShellID)
	write_byte(1)
	write_byte(20)
	message_end()
}
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang1042\\ f0\\ fs16 \n\\ par }
*/
