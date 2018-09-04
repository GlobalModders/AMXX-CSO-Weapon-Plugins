#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <cstrike>
#include <fun>

#define PLUGIN "[CSO] Aeolis"
#define VERSION "1.0"
#define AUTHOR "Dias no Pendragon"

#define DAMAGE_A 30 // 45 for zombie
#define DAMAGE_B 35 // 60 for zombie

#define CLIP 100

#define FIRE_AMMO 100
#define FIRE_INCBY 2
#define FIRE_DECBY 1
#define FIRE_SPEED 750.0
#define FIRE_CLASSNAME "aeolis_fire"

#define V_MODEL "models/v_spmg.mdl"
#define P_MODEL "models/p_spmg.mdl"
#define W_MODEL "models/w_spmg.mdl"

new const WeaponSounds[9][] =
{
	"weapons/spmg-1.wav",
	"weapons/spmg-2.wav",
	"weapons/steam.wav",
	"weapons/spmg_idle2.wav",
	"weapons/spmg_draw.wav",
	"weapons/spmg_clipin1.wav",
	"weapons/spmg_clipin2.wav",
	"weapons/spmg_clipin3.wav",
	"weapons/spmg_clipout1.wav"
}

new const WeaponResources[4][] =
{
	"sprites/weapon_spmg.txt",
	"sprites/aeolis_fire.spr",
	"sprites/640hud7_2.spr",
	"sprites/640hud106_2.spr"
}

enum
{
	ANIM_IDLE = 0,
	ANIM_SHOOT1,
	ANIM_SHOOT2,
	ANIM_RELOAD,
	ANIM_DRAW
	
}

#define CSW_AEOLIS CSW_M249
#define weapon_aeolis "weapon_m249"

// Fire Start
#define WEAPON_ATTACH_F 40.0
#define WEAPON_ATTACH_R 5.0
#define WEAPON_ATTACH_U -15.0

#define AVALANCHE_OLDMODEL "models/w_m249.mdl"

const PRIMARY_WEAPONS_BIT_SUM = (1<<CSW_SCOUT)|(1<<CSW_XM1014)|(1<<CSW_MAC10)|(1<<CSW_AUG)|(1<<CSW_UMP45)|(1<<CSW_SG550)|(1<<CSW_GALIL)|(1<<CSW_FAMAS)|(1<<CSW_AWP)|(1<<CSW_MP5NAVY)|(1<<CSW_M249)|(1<<CSW_M3)|(1<<CSW_M4A1)|(1<<CSW_TMP)|(1<<CSW_G3SG1)|(1<<CSW_SG552)|(1<<CSW_AK47)|(1<<CSW_P90)
const SECONDARY_WEAPONS_BIT_SUM = (1<<CSW_P228)|(1<<CSW_ELITE)|(1<<CSW_FIVESEVEN)|(1<<CSW_USP)|(1<<CSW_GLOCK18)|(1<<CSW_DEAGLE)

// MACROS
#define Get_BitVar(%1,%2) (%1 & (1 << (%2 & 31)))
#define Set_BitVar(%1,%2) %1 |= (1 << (%2 & 31))
#define UnSet_BitVar(%1,%2) %1 &= ~(1 << (%2 & 31))

new g_Had_Aeolis, g_FireAmmo[33], g_CurrentAmmo[33], Float:g_SoundAttack[33], g_Aeolis_Clip[33]
new g_MsgWeaponList, g_MsgCurWeapon, g_MsgStatusIcon, g_InTempingAttack
new g_Event_Aeolis, g_ShellId, g_SmokePuff_SprId, g_SmokePuff_SprId2, g_HamBot

public plugin_init() 
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	register_forward(FM_UpdateClientData,"fw_UpdateClientData_Post", 1)	
	register_forward(FM_PlaybackEvent, "fw_PlaybackEvent")	
	register_forward(FM_SetModel, "fw_SetModel")		
	register_forward(FM_CmdStart, "fw_CmdStart")
	register_forward(FM_EmitSound, "fw_EmitSound")
	register_forward(FM_TraceLine, "fw_TraceLine")
	register_forward(FM_TraceHull, "fw_TraceHull")	
	
	register_think(FIRE_CLASSNAME, "fw_Fire_Think")
	register_touch(FIRE_CLASSNAME, "*", "fw_Fire_Touch")	
	
	RegisterHam(Ham_Item_Deploy, weapon_aeolis, "fw_Item_Deploy_Post", 1)	
	RegisterHam(Ham_Item_AddToPlayer, weapon_aeolis, "fw_Item_AddToPlayer_Post", 1)
	RegisterHam(Ham_Item_PostFrame, weapon_aeolis, "fw_Item_PostFrame")	
	RegisterHam(Ham_Weapon_Reload, weapon_aeolis, "fw_Weapon_Reload")
	RegisterHam(Ham_Weapon_Reload, weapon_aeolis, "fw_Weapon_Reload_Post", 1)		
	
	RegisterHam(Ham_TraceAttack, "worldspawn", "fw_TraceAttack_World")
	RegisterHam(Ham_TraceAttack, "player", "fw_TraceAttack_Player")	
	
	g_MsgWeaponList = get_user_msgid("WeaponList")
	g_MsgCurWeapon = get_user_msgid("CurWeapon")
	g_MsgStatusIcon = get_user_msgid("StatusIcon")
	
	register_clcmd("admin_get_aeolis", "Get_Aeolis", ADMIN_KICK)
	register_clcmd("weapon_spmg", "Hook_Weapon")
}

public plugin_precache()
{
	precache_model(V_MODEL)
	precache_model(P_MODEL)
	precache_model(W_MODEL)
	
	for(new i = 0; i < sizeof(WeaponSounds); i++)
		precache_sound(WeaponSounds[i])
	for(new i = 0; i < sizeof(WeaponResources); i++)
	{
		if(i == 0) precache_generic(WeaponResources[i])
		else precache_model(WeaponResources[i])
	}
	
	g_ShellId = precache_model("models/rshell.mdl")
	g_SmokePuff_SprId = precache_model("sprites/wall_puff1.spr")
	g_SmokePuff_SprId2 = engfunc(EngFunc_PrecacheModel, "sprites/smokepuff.spr")
	
	register_forward(FM_PrecacheEvent, "fw_PrecacheEvent_Post", 1)
}

public fw_PrecacheEvent_Post(type, const name[])
{
	if(equal("events/m249.sc", name)) g_Event_Aeolis = get_orig_retval()		
}

public client_putinserver(id)
{
	if(!g_HamBot && is_user_bot(id))
	{
		g_HamBot = 1
		set_task(0.1, "Do_Register_HamBot", id)
	}
}

public Do_Register_HamBot(id)
{
	RegisterHamFromEntity(Ham_TraceAttack, id, "fw_TraceAttack_Player")
}

public Get_Aeolis(id)
{
	drop_weapons(id, 1)
	
	g_FireAmmo[id] = 0
	g_CurrentAmmo[id] = 0
	
	Set_BitVar(g_Had_Aeolis, id)
	give_item(id, weapon_aeolis)
	
	static Ent; Ent = fm_get_user_weapon_entity(id, CSW_AEOLIS)
	if(pev_valid(Ent)) cs_set_weapon_ammo(Ent, CLIP)
	
	Update_Ammo(id, CLIP)
	Update_SpecialAmmo(id, 0, 0)
	
	cs_set_user_bpammo(id, CSW_AEOLIS, 250)
}

public Remove_Aeolis(id)
{
	if(is_user_connected(id)) 
		Update_SpecialAmmo(id, g_CurrentAmmo[id], 0)
	
	g_FireAmmo[id] = 0
	g_CurrentAmmo[id] = 0
	
	UnSet_BitVar(g_Had_Aeolis, id)
}

public Hook_Weapon(id)
{
	engclient_cmd(id, weapon_aeolis)
	return PLUGIN_HANDLED
}

public Update_Ammo(id, Ammo)
{
	if(!is_user_alive(id))
		return
	
	engfunc(EngFunc_MessageBegin, MSG_ONE_UNRELIABLE, g_MsgCurWeapon, {0, 0, 0}, id)
	write_byte(1)
	write_byte(CSW_AEOLIS)
	write_byte(Ammo)
	message_end()
}

public fw_UpdateClientData_Post(id, sendweapons, cd_handle)
{
	if(!is_user_alive(id))
		return FMRES_IGNORED	
	if(get_user_weapon(id) == CSW_AEOLIS && Get_BitVar(g_Had_Aeolis, id))
		set_cd(cd_handle, CD_flNextAttack, get_gametime() + 0.001) 
	
	return FMRES_HANDLED
}

public fw_PlaybackEvent(flags, invoker, eventid, Float:delay, Float:origin[3], Float:angles[3], Float:fparam1, Float:fparam2, iParam1, iParam2, bParam1, bParam2)
{
	if (!is_user_connected(invoker))
		return FMRES_IGNORED	
	if(get_user_weapon(invoker) != CSW_AEOLIS || !Get_BitVar(g_Had_Aeolis, invoker))
		return FMRES_IGNORED
	if(eventid != g_Event_Aeolis)
		return FMRES_IGNORED
	
	engfunc(EngFunc_PlaybackEvent, flags | FEV_HOSTONLY, invoker, eventid, delay, origin, angles, fparam1, fparam2, iParam1, iParam2, bParam1, bParam2)
	
	Set_WeaponAnim(invoker, ANIM_SHOOT1)
	emit_sound(invoker, CHAN_WEAPON, WeaponSounds[0], 1.0, ATTN_NORM, 0, PITCH_NORM)
	
	Eject_Shell(invoker, g_ShellId, 0.01)
	
	if(g_FireAmmo[invoker] < FIRE_AMMO)
	{
		g_FireAmmo[invoker] = min(g_FireAmmo[invoker] + FIRE_INCBY, FIRE_AMMO)
		Check_FireAmmoHud(invoker, 1, 0)
	}

	return FMRES_IGNORED
}

public Check_FireAmmoHud(id, Active, Shooting)
{
	static Ammo; Ammo = g_FireAmmo[id] / 10
	
	if(g_FireAmmo[id] >= 10) 
	{
		if(min(Ammo, 9) > g_CurrentAmmo[id])
		{
			static OK; OK = 0
			switch(Ammo)
			{
				case 1: OK = 1
				case 4: OK = 1
				case 6: OK = 1
				case 9: OK = 1
			}
			if(OK) 
			{
				emit_sound(id, CHAN_ITEM, WeaponSounds[2], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
				Make_SteamSmoke(id)
			}
		
		}
				
		g_CurrentAmmo[id] = min(Ammo, 9)
		
		if(!Shooting) Update_SpecialAmmo(id, g_CurrentAmmo[id] - 1, 0)
		else Update_SpecialAmmo(id, g_CurrentAmmo[id] + 1, 0)
		Update_SpecialAmmo(id, g_CurrentAmmo[id], 1)
	}
}

public Make_SteamSmoke(id)
{
	static Float:Origin[3]
	get_position(id, WEAPON_ATTACH_F, WEAPON_ATTACH_R, WEAPON_ATTACH_U, Origin)
	
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY) 
	write_byte(TE_EXPLOSION) 
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2])
	write_short(g_SmokePuff_SprId2)
	write_byte(10)
	write_byte(15)
	write_byte(14)
	message_end()
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
	
	if(equal(model, AVALANCHE_OLDMODEL))
	{
		static weapon; weapon = find_ent_by_owner(-1, weapon_aeolis, entity)
		
		if(!pev_valid(weapon))
			return FMRES_IGNORED;
		
		if(Get_BitVar(g_Had_Aeolis, iOwner))
		{
			set_pev(weapon, pev_impulse, 562014)
			set_pev(weapon, pev_iuser3, g_FireAmmo[iOwner])
			set_pev(weapon, pev_iuser4, g_CurrentAmmo[iOwner])
			
			engfunc(EngFunc_SetModel, entity, W_MODEL)
			
			Remove_Aeolis(iOwner)
			
			return FMRES_SUPERCEDE
		}
	}

	return FMRES_IGNORED;
}

public fw_CmdStart(id, uc_handle, seed)
{
	if(!is_user_alive(id))
		return FMRES_IGNORED
	if(get_user_weapon(id) != CSW_AEOLIS || !Get_BitVar(g_Had_Aeolis, id))
		return FMRES_IGNORED
		
	static PressedButton
	PressedButton = get_uc(uc_handle, UC_Buttons)
	
	if(PressedButton & IN_ATTACK2)
	{
		if(get_pdata_float(id, 83, 5) > 0.0)
			return FMRES_IGNORED
		if(g_FireAmmo[id] <= 0)
			return FMRES_IGNORED

		if(get_gametime() - 0.9 > g_SoundAttack[id])
		{
			emit_sound(id, CHAN_WEAPON, WeaponSounds[1], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
			
			Create_FakeAttackAnim(id)
			Set_WeaponAnim(id, ANIM_SHOOT2)
			
			g_SoundAttack[id] = get_gametime()
		}
		
		g_FireAmmo[id]--
		Check_FireAmmoHud(id, 0, 1)
		
		if(!g_FireAmmo[id]) Update_SpecialAmmo(id, 1, 0)
		Create_Fire(id)
		
		set_pdata_float(id, 83, 0.1, 5)
	}
		
	return FMRES_HANDLED
}


public fw_EmitSound(id, channel, const sample[], Float:volume, Float:attn, flags, pitch)
{
	if(!is_user_connected(id))
		return FMRES_IGNORED
	if(!Get_BitVar(g_InTempingAttack, id))
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
	if(!is_user_alive(id))
		return FMRES_IGNORED	
	if(!Get_BitVar(g_InTempingAttack, id))
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
	if(!is_user_alive(id))
		return FMRES_IGNORED	
	if(!Get_BitVar(g_InTempingAttack, id))
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

public Create_FakeAttackAnim(id)
{
	Set_BitVar(g_InTempingAttack, id)
	
	static Ent; Ent = fm_get_user_weapon_entity(id, CSW_KNIFE)
	if(pev_valid(Ent)) ExecuteHamB(Ham_Weapon_PrimaryAttack, Ent)
	
	UnSet_BitVar(g_InTempingAttack, id)
}

public fw_Item_Deploy_Post(Ent)
{
	if(pev_valid(Ent) != 2)
		return
	static Id; Id = get_pdata_cbase(Ent, 41, 4)
	if(get_pdata_cbase(Id, 373) != Ent)
		return
	if(!Get_BitVar(g_Had_Aeolis, Id))
		return
	
	set_pev(Id, pev_viewmodel2, V_MODEL)
	set_pev(Id, pev_weaponmodel2, P_MODEL)
}

public fw_Item_AddToPlayer_Post(Ent, id)
{
	if(!pev_valid(Ent))
		return HAM_IGNORED
		
	if(pev(Ent, pev_impulse) == 562014)
	{
		Set_BitVar(g_Had_Aeolis, id)
		set_pev(Ent, pev_impulse, 0)
		
		g_FireAmmo[id] = pev(Ent, pev_iuser3)
		g_CurrentAmmo[id] = pev(Ent, pev_iuser4)
		
		Update_SpecialAmmo(id, g_CurrentAmmo[id], 1)
	}		
	
	message_begin(MSG_ONE_UNRELIABLE, g_MsgWeaponList, .player = id)
	write_string(Get_BitVar(g_Had_Aeolis, id) ? "weapon_spmg" : "weapon_m249")
	write_byte(3) // PrimaryAmmoID
	write_byte(200) // PrimaryAmmoMaxAmount
	write_byte(-1) // SecondaryAmmoID
	write_byte(-1) // SecondaryAmmoMaxAmount
	write_byte(0) // SlotID (0...N)
	write_byte(4) // NumberInSlot (1...N)
	write_byte(Get_BitVar(g_Had_Aeolis, id) ? CSW_AEOLIS : CSW_M249) // WeaponID
	write_byte(0) // Flags
	message_end()

	return HAM_HANDLED	
}

public fw_TraceAttack_World(Victim, Attacker, Float:Damage, Float:Direction[3], Ptr, DamageBits)
{
	if(!is_user_connected(Attacker))
		return HAM_IGNORED	
	if(get_user_weapon(Attacker) != CSW_AEOLIS || !Get_BitVar(g_Had_Aeolis, Attacker))
		return HAM_IGNORED
		
	static Float:flEnd[3], Float:vecPlane[3]
		
	get_tr2(Ptr, TR_vecEndPos, flEnd)
	get_tr2(Ptr, TR_vecPlaneNormal, vecPlane)		
			
	Make_BulletHole(Attacker, flEnd, Damage)
	Make_BulletSmoke(Attacker, Ptr)

	SetHamParamFloat(3, float(DAMAGE_A))
	
	return HAM_IGNORED
}

public fw_TraceAttack_Player(Victim, Attacker, Float:Damage, Float:Direction[3], Ptr, DamageBits)
{
	if(!is_user_connected(Attacker))
		return HAM_IGNORED	
	if(get_user_weapon(Attacker) != CSW_AEOLIS || !Get_BitVar(g_Had_Aeolis, Attacker))
		return HAM_IGNORED
		
	SetHamParamFloat(3, float(DAMAGE_A))
	
	return HAM_IGNORED
}

public fw_Item_PostFrame(ent)
{
	static id; id = pev(ent, pev_owner)
	if(!is_user_alive(id))
		return HAM_IGNORED
	if(!Get_BitVar(g_Had_Aeolis, id))
		return HAM_IGNORED	
	
	static Float:flNextAttack; flNextAttack = get_pdata_float(id, 83, 5)
	static bpammo; bpammo = cs_get_user_bpammo(id, CSW_AEOLIS)
	
	static iClip; iClip = get_pdata_int(ent, 51, 4)
	static fInReload; fInReload = get_pdata_int(ent, 54, 4)
	
	if(fInReload && flNextAttack <= 0.0)
	{
		static temp1
		temp1 = min(CLIP - iClip, bpammo)

		set_pdata_int(ent, 51, iClip + temp1, 4)
		cs_set_user_bpammo(id, CSW_AEOLIS, bpammo - temp1)		
		
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
	if(!Get_BitVar(g_Had_Aeolis, id))
		return HAM_IGNORED	

	g_Aeolis_Clip[id] = -1
		
	static BPAmmo; BPAmmo = cs_get_user_bpammo(id, CSW_AEOLIS)
	static iClip; iClip = get_pdata_int(ent, 51, 4)
		
	if(BPAmmo <= 0)
		return HAM_SUPERCEDE
	if(iClip >= CLIP)
		return HAM_SUPERCEDE		
			
	g_Aeolis_Clip[id] = iClip	
	
	return HAM_HANDLED
}

public fw_Weapon_Reload_Post(ent)
{
	static id; id = pev(ent, pev_owner)
	if(!is_user_alive(id))
		return HAM_IGNORED
	if(!Get_BitVar(g_Had_Aeolis, id))
		return HAM_IGNORED	
		
	if((get_pdata_int(ent, 54, 4) == 1))
	{ // Reload
		if(g_Aeolis_Clip[id] == -1)
			return HAM_IGNORED
		
		set_pdata_int(ent, 51, g_Aeolis_Clip[id], 4)
		Set_WeaponAnim(id, ANIM_RELOAD)
	}
	
	return HAM_HANDLED
}

public Create_Fire(id)
{
	static Float:Origin[3], Float:TargetOrigin[3]
	
	get_position(id, WEAPON_ATTACH_F, WEAPON_ATTACH_R, WEAPON_ATTACH_U + 10.0, Origin)
	get_position(id, WEAPON_ATTACH_F * 100.0, WEAPON_ATTACH_R, WEAPON_ATTACH_U + 10.0, TargetOrigin)
	
	Create_FireEntity(id, Origin, TargetOrigin, FIRE_SPEED)
}

public Create_FireEntity(id, Float:Origin[3], Float:TargetOrigin[3], Float:Speed)
{
	new iEnt = create_entity("env_sprite")
	static Float:vfAngle[3], Float:MyOrigin[3], Float:Velocity[3]
	
	pev(id, pev_angles, vfAngle)
	pev(id, pev_origin, MyOrigin)
	
	vfAngle[2] = float(random(18) * 20)

	// set info for ent
	set_pev(iEnt, pev_movetype, MOVETYPE_FLY)
	set_pev(iEnt, pev_rendermode, kRenderTransAdd)
	set_pev(iEnt, pev_renderamt, 150.0)
	set_pev(iEnt, pev_fuser1, get_gametime() + 1.0)	// time remove
	set_pev(iEnt, pev_scale, 0.25)
	set_pev(iEnt, pev_nextthink, get_gametime() + 0.05)
	
	entity_set_string(iEnt, EV_SZ_classname, FIRE_CLASSNAME)
	engfunc(EngFunc_SetModel, iEnt, WeaponResources[1])
	set_pev(iEnt, pev_mins, Float:{-1.0, -1.0, -1.0})
	set_pev(iEnt, pev_maxs, Float:{1.0, 1.0, 1.0})
	set_pev(iEnt, pev_origin, Origin)
	set_pev(iEnt, pev_gravity, 0.01)
	set_pev(iEnt, pev_angles, vfAngle)
	set_pev(iEnt, pev_solid, SOLID_TRIGGER)
	set_pev(iEnt, pev_owner, id)	
	set_pev(iEnt, pev_frame, 0.0)
	set_pev(iEnt, pev_iuser2, get_user_team(id))

	get_speed_vector(Origin, TargetOrigin, Speed, Velocity)
	set_pev(iEnt, pev_velocity, Velocity)	
}


public fw_Fire_Think(iEnt)
{
	if(!pev_valid(iEnt)) 
		return
	
	new Float:fFrame, Float:fScale, Float:fNextThink
	pev(iEnt, pev_frame, fFrame)
	pev(iEnt, pev_scale, fScale)

	// effect exp
	new iMoveType = pev(iEnt, pev_movetype)
	if (iMoveType == MOVETYPE_NONE)
	{
		fNextThink = 0.015
		fFrame += 1.0
		fScale = floatmax(fScale, 1.75)
		
		if (fFrame > 21.0)
		{
			engfunc(EngFunc_RemoveEntity, iEnt)
			return
		}
	}
	
	// effect normal
	else
	{
		fNextThink = 0.045
		fFrame += 1.0
		fFrame = floatmin(21.0, fFrame)
		fScale += 0.15
		fScale = floatmin(fScale, 1.75)
	}

	set_pev(iEnt, pev_frame, fFrame)
	set_pev(iEnt, pev_scale, fScale)
	set_pev(iEnt, pev_nextthink, get_gametime() + fNextThink)
	
	// time remove
	static Float:fTimeRemove
	pev(iEnt, pev_fuser1, fTimeRemove)
	if (get_gametime() >= fTimeRemove)
	{
		engfunc(EngFunc_RemoveEntity, iEnt)
		return;
	}
}

public fw_Fire_Touch(ent, id)
{
	if(!pev_valid(ent))
		return
		
	if(pev_valid(id))
	{
		static Classname[32]
		pev(id, pev_classname, Classname, sizeof(Classname))
		
		if(equal(Classname, FIRE_CLASSNAME)) return
		else if(is_user_alive(id)) 
		{
			ExecuteHamB(Ham_TakeDamage, id, 0, pev(ent, pev_owner), float(DAMAGE_B), DMG_BURN)
		}
	}
		
	set_pev(ent, pev_movetype, MOVETYPE_NONE)
	set_pev(ent, pev_solid, SOLID_NOT)
}


// Drop primary/secondary weapons
stock drop_weapons(id, dropwhat)
{
	// Get user weapons
	static weapons[32], num, i, weaponid
	num = 0 // reset passed weapons count (bugfix)
	get_user_weapons(id, weapons, num)
	
	// Loop through them and drop primaries or secondaries
	for (i = 0; i < num; i++)
	{
		// Prevent re-indexing the array
		weaponid = weapons[i]
		
		if ((dropwhat == 1 && ((1<<weaponid) & PRIMARY_WEAPONS_BIT_SUM)) || (dropwhat == 2 && ((1<<weaponid) & SECONDARY_WEAPONS_BIT_SUM)))
		{
			// Get weapon entity
			static wname[32]; get_weaponname(weaponid, wname, charsmax(wname))
			engclient_cmd(id, "drop", wname)
		}
	}
}

stock Set_WeaponAnim(id, anim)
{
	set_pev(id, pev_weaponanim, anim)
	
	message_begin(MSG_ONE_UNRELIABLE, SVC_WEAPONANIM, {0, 0, 0}, id)
	write_byte(anim)
	write_byte(pev(id, pev_body))
	message_end()
}

stock Eject_Shell(id, Shell_ModelIndex, Float:Time) // By Dias
{
	static Ent; Ent = get_pdata_cbase(id, 373, 5)
	if(!pev_valid(Ent))
		return

        set_pdata_int(Ent, 57, Shell_ModelIndex, 4)
        set_pdata_float(id, 111, get_gametime() + Time)
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

