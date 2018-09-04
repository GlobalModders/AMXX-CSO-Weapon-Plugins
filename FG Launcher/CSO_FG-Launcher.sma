#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <cstrike>
#include <fun>

#define PLUGIN "[CSO] FG-Launcher"
#define VERSION "1.0"
#define AUTHOR "Dias"

#define V_MODEL "models/v_fglauncher.mdl"
#define P_MODEL "models/p_fglauncher.mdl"
#define W_MODEL "models/w_fglauncher.mdl"
#define S_MODEL "models/s_oicw.mdl"

new const WeaponSounds[9][] = 
{
	"weapons/fglauncher-1.wav",
	"weapons/firecracker_explode.wav",
	"weapons/firecracker-wick.wav",
	"weapons/fglauncher_draw.wav",
	"weapons/fglauncher_clipin1.wav",
	"weapons/fglauncher_clipin2.wav",
	"weapons/fglauncher_clipin3.wav",
	"weapons/fglauncher_clipout1.wav",
	"weapons/fglauncher_clipout2.wav"
}

new const WeaponResources[6][] = 
{
	"sprites/weapon_fglauncher.txt",
	"sprites/640hud7_2.spr",
	"sprites/640hud86_2.spr",
	"sprites/spark1.spr",
	"sprites/spark2.spr",
	"sprites/spark3.spr"
}

enum
{
	ANIM_IDLE = 0,
	ANIM_SHOOT,
	ANIM_RELOAD,
	ANIM_DRAW
}

#define DAMAGE 75 // 350 for Zombies
#define RADIUS 200

#define CLIP 10
#define BPAMMO 50

#define CSW_FGL CSW_M249
#define weapon_fgl "weapon_m249"

#define WEAPON_SECRETCODE 1182014
#define OLD_W_MODEL "models/w_m249.mdl"
#define WEAPON_ANIMEXT "carbine"

#define GRENADE_CLASSNAME "fgl"

#define TIME_RELOAD 5.0
#define TIME_DELAY 1.0
#define TIME_EXPLOSION 2.0

#define WEAPON_ATTACH_F 30.0
#define WEAPON_ATTACH_R 5.0
#define WEAPON_ATTACH_U -15.0

new g_Had_FGL, g_FGL_Clip[33], g_InTempingAttack
new g_MsgWeaponList, g_MsgCurWeapon, g_MaxPlayers
new g_SmokePuff_SprId, g_Trail_SprId, g_Spark_SprId[3]

// Safety
#define Get_BitVar(%1,%2) (%1 & (1 << (%2 & 31)))
#define Set_BitVar(%1,%2) %1 |= (1 << (%2 & 31))
#define UnSet_BitVar(%1,%2) %1 &= ~(1 << (%2 & 31))

new g_HamBot
new g_IsConnected, g_IsAlive, g_PlayerWeapon[33]

public plugin_init() 
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	Register_SafetyFunc()
	
	register_think(GRENADE_CLASSNAME, "fw_Grenade_Think")
	register_touch(GRENADE_CLASSNAME, "*", "fw_Grenade_Touch")
	
	register_forward(FM_UpdateClientData, "fw_UpdateClientData_Post", 1)	
	register_forward(FM_SetModel, "fw_SetModel")
	register_forward(FM_CmdStart, "fw_CmdStart")
	register_forward(FM_EmitSound, "fw_EmitSound")
	register_forward(FM_TraceLine, "fw_TraceLine")
	register_forward(FM_TraceHull, "fw_TraceHull")	
	
	RegisterHam(Ham_Item_PostFrame, weapon_fgl, "fw_Item_PostFrame")	
	RegisterHam(Ham_Weapon_Reload, weapon_fgl, "fw_Weapon_Reload")
	RegisterHam(Ham_Weapon_Reload, weapon_fgl, "fw_Weapon_Reload_Post", 1)
	RegisterHam(Ham_Item_AddToPlayer, weapon_fgl, "fw_Item_AddToPlayer_Post", 1)	
	RegisterHam(Ham_Item_Deploy, weapon_fgl, "fw_Item_Deploy_Post", 1)	
	
	g_MsgWeaponList = get_user_msgid("WeaponList")
	g_MsgCurWeapon = get_user_msgid("CurWeapon")
	g_MaxPlayers = get_maxplayers()
	
	register_clcmd("weapon_fglauncher", "Hook_Weapon")
	register_clcmd("say /get", "Get_FGLauncher")
}

public plugin_precache()
{
	precache_model(V_MODEL)
	precache_model(P_MODEL)
	precache_model(W_MODEL)
	precache_model(S_MODEL)
	
	for(new i = 0; i < sizeof(WeaponSounds); i++)
		precache_sound(WeaponSounds[i])
		
	precache_generic(WeaponResources[0])
	precache_model(WeaponResources[1])
	precache_model(WeaponResources[2])
	
	g_Spark_SprId[0] = precache_model(WeaponResources[3])
	g_Spark_SprId[1] = precache_model(WeaponResources[4])
	g_Spark_SprId[2] = precache_model(WeaponResources[5])
	
	g_SmokePuff_SprId = engfunc(EngFunc_PrecacheModel, "sprites/smokepuff.spr")
	g_Trail_SprId = engfunc(EngFunc_PrecacheModel, "sprites/laserbeam.spr")
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
}

public client_disconnect(id)
{
	Safety_Disconnected(id)
}

public Get_FGLauncher(id)
{
	if(!is_player(id, 1))
		return
		
	Set_BitVar(g_Had_FGL, id)
	give_item(id, weapon_fgl)
	
	static FGL; FGL = fm_get_user_weapon_entity(id, CSW_FGL)
	if(!pev_valid(FGL)) return
	
	cs_set_weapon_ammo(FGL, CLIP)
	cs_set_user_bpammo(id, CSW_FGL, BPAMMO)
	
	message_begin(MSG_ONE_UNRELIABLE, g_MsgCurWeapon, _, id)
	write_byte(1)
	write_byte(CSW_FGL)
	write_byte(CLIP)
	message_end()
}

public Remove_FGLauncher(id)
{
	UnSet_BitVar(g_Had_FGL, id)
}

public Hook_Weapon(id)
{
	engclient_cmd(id, weapon_fgl)
	return PLUGIN_HANDLED
}

public fw_Grenade_Think(Ent)
{
	if(!pev_valid(Ent))
		return
	if(pev(Ent, pev_fuser1) <= get_gametime())
	{
		Grenade_Explosion(Ent)
		return
	}
		
	static Float:Origin[3]; pev(Ent, pev_origin, Origin)
		
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_SPARKS)
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2])
	message_end()
		
	set_pev(Ent, pev_nextthink, get_gametime() + 0.1)
}

public fw_Grenade_Touch(Ent, Touch)
{
	if(!pev_valid(Ent))
		return
		
	Grenade_Explosion(Ent)
}

public Grenade_Explosion(Ent)
{
	static Float:Origin[3];
	pev(Ent, pev_origin, Origin)
	
	emit_sound(Ent, CHAN_BODY, WeaponSounds[1], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_EXPLOSION)
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2] + 5.0)
	write_short(g_Spark_SprId[0])
	write_byte(5)
	write_byte(30)
	write_byte(TE_EXPLFLAG_NODLIGHTS | TE_EXPLFLAG_NOSOUND)
	message_end()
	
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_EXPLOSION)
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2] + 10.0)
	write_short(g_Spark_SprId[1])
	write_byte(6)
	write_byte(30)
	write_byte(TE_EXPLFLAG_NODLIGHTS | TE_EXPLFLAG_NOSOUND)
	message_end()
	
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_EXPLOSION)
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2] + 50.0)
	write_short(g_Spark_SprId[1])
	write_byte(8)
	write_byte(25)
	write_byte(TE_EXPLFLAG_NODLIGHTS | TE_EXPLFLAG_NOSOUND)
	message_end()

	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_EXPLOSION)
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2] + 100.0)
	write_short(g_Spark_SprId[1])
	write_byte(12)
	write_byte(20)
	write_byte(TE_EXPLFLAG_NODLIGHTS | TE_EXPLFLAG_NOSOUND)
	message_end()
	
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_EXPLOSION)
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2] + 20.0)
	write_short(g_Spark_SprId[2])
	write_byte(6)
	write_byte(30)
	write_byte(TE_EXPLFLAG_NODLIGHTS | TE_EXPLFLAG_NOSOUND)
	message_end()
	
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_EXPLOSION)
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2] + 100.0)
	write_short(g_Spark_SprId[2])
	write_byte(10)
	write_byte(20)
	write_byte(TE_EXPLFLAG_NODLIGHTS | TE_EXPLFLAG_NOSOUND)
	message_end()
	
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_WORLDDECAL)
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2])
	write_byte(random_num(46, 48))
	message_end()	
	
	static id; id = pev(Ent, pev_owner)
	if(!is_player(id, 0))
	{
		remove_entity(Ent)
		return
	}
	
	for(new i = 0; i < g_MaxPlayers; i++)
	{
		if(!is_player(i, 1))
			continue
		if(cs_get_user_team(id) == cs_get_user_team(i))
			continue
		if(entity_range(Ent, i) > float(RADIUS))
			continue

		ExecuteHamB(Ham_TakeDamage, i, 0, id, float(DAMAGE), DMG_SHOCK)
	}
	
	remove_entity(Ent)
}

public fw_UpdateClientData_Post(id, sendweapons, cd_handle)
{
	if(!is_player(id, 1))
		return FMRES_IGNORED	
	if(get_player_weapon(id) == CSW_FGL && Get_BitVar(g_Had_FGL, id))
		set_cd(cd_handle, CD_flNextAttack, get_gametime() + 0.001) 
	
	return FMRES_HANDLED
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
	
	if(equal(model, OLD_W_MODEL))
	{
		static weapon; weapon = fm_find_ent_by_owner(-1, weapon_fgl, entity)
		
		if(!pev_valid(weapon))
			return FMRES_IGNORED;
		
		if(Get_BitVar(g_Had_FGL, iOwner))
		{
			set_pev(weapon, pev_impulse, WEAPON_SECRETCODE)
			engfunc(EngFunc_SetModel, entity, W_MODEL)
			
			Remove_FGLauncher(iOwner)
			
			return FMRES_SUPERCEDE
		}
	}

	return FMRES_IGNORED;
}

public fw_CmdStart(id, uc_handle, seed)
{
	if(!is_player(id,1)) 
		return
	if(get_player_weapon(id) != CSW_FGL || !Get_BitVar(g_Had_FGL, id))
		return
	
	static Ent; Ent = fm_get_user_weapon_entity(id, CSW_FGL)
	if(!pev_valid(Ent))
		return
	
	static CurButton; CurButton = get_uc(uc_handle, UC_Buttons)
	if(CurButton & IN_ATTACK) 
	{
		if(get_pdata_float(id, 83, 5) > 0.0) 
			return
		if(cs_get_weapon_ammo(Ent) <= 0)
			return
			
		CurButton &= ~IN_ATTACK
		set_uc(uc_handle, UC_Buttons, CurButton)

		FGLauncher_Shoot(id, Ent)
	}
}

public fw_EmitSound(id, channel, const sample[], Float:volume, Float:attn, flags, pitch)
{
	if(!is_player(id, 0))
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
	if(!is_player(id, 0))
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
	if(!is_player(id, 0))
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

public fw_Item_PostFrame(Ent)
{
	if(pev_valid(Ent) != 2)
		return
	static id; id = get_pdata_cbase(Ent, 41, 4)
	if(get_pdata_cbase(id, 373) != Ent)
		return
	if(!Get_BitVar(g_Had_FGL, id))
		return	
	
	static Float:flNextAttack; flNextAttack = get_pdata_float(id, 83, 5)
	static bpammo; bpammo = cs_get_user_bpammo(id, CSW_FGL)
	
	static iClip; iClip = get_pdata_int(Ent, 51, 4)
	static fInReload; fInReload = get_pdata_int(Ent, 54, 4)
	
	if(fInReload && flNextAttack <= 0.0)
	{
		static temp1
		temp1 = min(CLIP - iClip, bpammo)

		set_pdata_int(Ent, 51, iClip + temp1, 4)
		cs_set_user_bpammo(id, CSW_FGL, bpammo - temp1)		
		
		set_pdata_int(Ent, 54, 0, 4)
		
		fInReload = 0
	}		
	
	return
}

public fw_Weapon_Reload(Ent)
{
	if(pev_valid(Ent) != 2)
		return HAM_IGNORED
	static id; id = get_pdata_cbase(Ent, 41, 4)
	if(get_pdata_cbase(id, 373) != Ent)
		return HAM_IGNORED
	if(!Get_BitVar(g_Had_FGL, id))
		return HAM_IGNORED

	g_FGL_Clip[id] = -1
		
	static BPAmmo; BPAmmo = cs_get_user_bpammo(id, CSW_FGL)
	static iClip; iClip = get_pdata_int(Ent, 51, 4)
		
	if(BPAmmo <= 0)
		return HAM_SUPERCEDE
	if(iClip >= CLIP)
		return HAM_SUPERCEDE		
			
	g_FGL_Clip[id] = iClip	
	
	return HAM_HANDLED
}

public fw_Weapon_Reload_Post(Ent)
{
	if(pev_valid(Ent) != 2)
		return HAM_IGNORED
	static id; id = get_pdata_cbase(Ent, 41, 4)
	if(get_pdata_cbase(id, 373) != Ent)
		return HAM_IGNORED
	if(!Get_BitVar(g_Had_FGL, id))
		return HAM_IGNORED
		
	if((get_pdata_int(Ent, 54, 4) == 1))
	{ // Reload
		if(g_FGL_Clip[id] == -1)
			return HAM_IGNORED
		
		set_pdata_int(Ent, 51, g_FGL_Clip[id], 4)
		
		Set_WeaponAnim(id, ANIM_RELOAD)
		
		Set_Weapon_Idle(id, CSW_FGL, TIME_RELOAD + 0.5)
		Set_Player_NextAttack(id, TIME_RELOAD)
	}
	
	return HAM_HANDLED
}

public fw_Item_AddToPlayer_Post(ent, id)
{
	if(!pev_valid(ent))
		return HAM_IGNORED
		
	if(pev(ent, pev_impulse) == WEAPON_SECRETCODE)
	{
		Set_BitVar(g_Had_FGL, id)
		set_pev(ent, pev_impulse, 0)
	}		
	
	message_begin(MSG_ONE_UNRELIABLE, g_MsgWeaponList, .player = id)
	write_string(Get_BitVar(g_Had_FGL, id) ? "weapon_fglauncher" : weapon_fgl)
	write_byte(3) // PrimaryAmmoID
	write_byte(200) // PrimaryAmmoMaxAmount
	write_byte(-1) // SecondaryAmmoID
	write_byte(-1) // SecondaryAmmoMaxAmount
	write_byte(0) // SlotID (0...N)
	write_byte(4) // NumberInSlot (1...N)
	write_byte(Get_BitVar(g_Had_FGL, id) ? CSW_FGL : CSW_M249) // WeaponID
	write_byte(0) // Flags
	message_end()

	return HAM_HANDLED	
}

public fw_Item_Deploy_Post(Ent)
{
	if(pev_valid(Ent) != 2)
		return
	static id; id = get_pdata_cbase(Ent, 41, 4)
	if(get_pdata_cbase(id, 373) != Ent)
		return
	if(!Get_BitVar(g_Had_FGL, id))
		return
		
	set_pev(id, pev_viewmodel2, V_MODEL)
	set_pev(id, pev_weaponmodel2, P_MODEL)
	
	set_pdata_string(id, (492) * 4, WEAPON_ANIMEXT, -1 , 20)
	Set_WeaponAnim(id, ANIM_DRAW)
}

public FGLauncher_Shoot(id, FGL)
{
	static Ammo; Ammo = cs_get_weapon_ammo(FGL)
	if(Ammo <= 0)
	{
		Set_Player_NextAttack(id, 1.0)
		return
	}
	
	cs_set_weapon_ammo(FGL, Ammo - 1)
		
	Create_FakeAttack(id)
	
	Set_WeaponAnim(id, ANIM_SHOOT)
	emit_sound(id, CHAN_WEAPON, WeaponSounds[0], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	
	Make_FireSmoke(id)
	Create_Grenade(id, FGL)
	Make_Push(id)
	
	Set_Weapon_Idle(id, CSW_FGL, TIME_DELAY + 0.5)
	Set_Player_NextAttack(id, TIME_DELAY)
}

public Make_FireSmoke(id)
{
	static Float:Origin[3]
	get_position(id, WEAPON_ATTACH_F, WEAPON_ATTACH_R, WEAPON_ATTACH_U, Origin)
	
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY) 
	write_byte(TE_EXPLOSION) 
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2])
	write_short(g_SmokePuff_SprId)
	write_byte(5)
	write_byte(15)
	write_byte(14)
	message_end()
}

public Create_Grenade(id, FGL)
{
	static Ent; Ent = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"))
	if(!pev_valid(Ent)) return
	
	static Float:Origin[3], Float:Angles[3]
	
	get_position(id, WEAPON_ATTACH_F, WEAPON_ATTACH_R + 5.0, WEAPON_ATTACH_U + 5.0, Origin)
	pev(id, pev_angles, Angles)
	
	set_pev(Ent, pev_movetype, MOVETYPE_PUSHSTEP)
	set_pev(Ent, pev_gravity, 1.0)
	set_pev(Ent, pev_solid, SOLID_BBOX)
	set_pev(Ent, pev_nextthink, get_gametime() + 0.1)
	
	set_pev(Ent, pev_classname, GRENADE_CLASSNAME)
	engfunc(EngFunc_SetModel, Ent, S_MODEL)
	set_pev(Ent, pev_mins, Float:{-1.0, -1.0, -1.0})
	set_pev(Ent, pev_maxs, Float:{1.0, 1.0, 1.0})	
	set_pev(Ent, pev_origin, Origin)
	set_pev(Ent, pev_angles, Angles)
	set_pev(Ent, pev_owner, id)
	
	set_pev(Ent, pev_fuser1, get_gametime() + TIME_EXPLOSION)
	
	// Create Velocity
	static Float:Velocity[3], Float:TargetOrigin[3]
	
	fm_get_aim_origin(id, TargetOrigin)
	get_speed_vector(Origin, TargetOrigin, 900.0, Velocity)
	
	set_pev(Ent, pev_velocity, Velocity)

	// Make a Beam
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_BEAMFOLLOW)
	write_short(Ent) // entity
	write_short(g_Trail_SprId) // sprite
	write_byte(20)  // life
	write_byte(3)  // width
	write_byte(255) // r
	write_byte(127);  // g
	write_byte(127);  // b
	write_byte(200); // brightness
	message_end();
	
	emit_sound(Ent, CHAN_BODY, WeaponSounds[2], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
}

public Make_Push(id)
{
	static Float:VirtualVec[3]
	VirtualVec[0] = random_float(-3.5, -7.0)
	VirtualVec[1] = random_float(1.0, -1.0)
	VirtualVec[2] = 0.0	
	
	set_pev(id, pev_punchangle, VirtualVec)		
}

public Create_FakeAttack(id)
{
	static Ent; Ent = fm_get_user_weapon_entity(id, CSW_KNIFE)
	if(!pev_valid(Ent)) return
	
	Set_BitVar(g_InTempingAttack, id)
	ExecuteHamB(Ham_Weapon_PrimaryAttack, Ent)
	
	// Set Real Attack Anim
	static iAnimDesired,  szAnimation[64]

	formatex(szAnimation, charsmax(szAnimation), (pev(id, pev_flags) & FL_DUCKING) ? "crouch_shoot_%s" : "ref_shoot_%s", WEAPON_ANIMEXT)
	if((iAnimDesired = lookup_sequence(id, szAnimation)) == -1)
		iAnimDesired = 0
	
	set_pev(id, pev_sequence, iAnimDesired)
	UnSet_BitVar(g_InTempingAttack, id)
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

stock get_position(id,Float:forw, Float:right, Float:up, Float:vStart[])
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
	if(!is_player(id, 1))
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

public is_player(id, IsAliveCheck)
{
	if(!(1 <= id <= 32))
		return 0
	if(!Get_BitVar(g_IsConnected, id))
		return 0
	if(IsAliveCheck)
	{
		if(Get_BitVar(g_IsAlive, id)) return 1
		else return 0
	}
	
	return 1
}

public get_player_weapon(id)
{
	if(!is_player(id, 1))
		return 0
	
	return g_PlayerWeapon[id]
}

/* ===============================
--------- End of SAFETY ----------
=================================*/
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang1042\\ f0\\ fs16 \n\\ par }
*/
