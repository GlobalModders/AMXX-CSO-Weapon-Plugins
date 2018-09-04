#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <cstrike>
#include <fun>

#define PLUGIN "[CSO] Wild Wing"
#define VERSION "1.0"
#define AUTHOR "2015"

#define DAMAGE 182
#define AMMO 10

#define MODEL_V "models/v_catapult.mdl"
#define MODEL_P "models/p_catapult.mdl"
#define MODEL_W "models/w_catapult.mdl"

#define WILDWING_OLDMODEL "models/w_deagle.mdl"

new const WildWing_Sounds[4][] = 
{
	"weapons/catapult_draw1.wav",
	"weapons/catapult_shootidle1.wav",
	"weapons/catapult-1.wav",
	"weapons/catapult-2.wav"
}

enum
{
	ANIM_IDLE = 0,
	ANIM_IDLE_E,
	ANIM_IDLE_R,
	ANIM_READY,
	ANIM_SHOOT,
	ANIM_SHOOT_L,
	ANIM_DRAW,
	ANIM_DRAW_E
}

#define CSW_WILDWING CSW_DEAGLE
#define weapon_wildwing "weapon_deagle"

const PRIMARY_WEAPONS_BIT_SUM = (1<<CSW_SCOUT)|(1<<CSW_XM1014)|(1<<CSW_MAC10)|(1<<CSW_AUG)|(1<<CSW_UMP45)|(1<<CSW_SG550)|(1<<CSW_GALIL)|(1<<CSW_FAMAS)|(1<<CSW_AWP)|(1<<CSW_MP5NAVY)|(1<<CSW_M249)|(1<<CSW_M3)|(1<<CSW_M4A1)|(1<<CSW_TMP)|(1<<CSW_G3SG1)|(1<<CSW_SG552)|(1<<CSW_AK47)|(1<<CSW_P90)
const SECONDARY_WEAPONS_BIT_SUM = (1<<CSW_P228)|(1<<CSW_ELITE)|(1<<CSW_FIVESEVEN)|(1<<CSW_USP)|(1<<CSW_GLOCK18)|(1<<CSW_DEAGLE)

// MACROS
#define Get_BitVar(%1,%2) (%1 & (1 << (%2 & 31)))
#define Set_BitVar(%1,%2) %1 |= (1 << (%2 & 31))
#define UnSet_BitVar(%1,%2) %1 &= ~(1 << (%2 & 31))

// Vars
new g_Had_WildWing, g_TempingAttack, g_Holding, g_Shoot
new g_Ammo[33], g_MsgCurWeapon, g_MsgAmmoX
new g_OldWeapon[33], g_SmokePuff_SprId

// Safety
new g_IsConnected, g_IsAlive, g_PlayerWeapon[33], g_HamBot

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	// Safety
	Register_SafetyFunc()
	
	// Code
	register_event("CurWeapon", "Event_CurWeapon", "be", "1=1")
	
	register_forward(FM_UpdateClientData, "fw_UpdateClientData_Post", 1)
	register_forward(FM_SetModel, "fw_SetModel")	
	register_forward(FM_CmdStart, "fw_CmdStart")
	register_forward(FM_EmitSound, "fw_EmitSound")
	register_forward(FM_TraceLine, "fw_TraceLine")
	register_forward(FM_TraceHull, "fw_TraceHull")		
	
	RegisterHam(Ham_Item_Deploy, weapon_wildwing, "fw_Item_Deploy_Post", 1)	
	RegisterHam(Ham_Weapon_WeaponIdle, weapon_wildwing, "fw_Weapon_WeaponIdle_Post", 1)
	RegisterHam(Ham_Item_AddToPlayer, weapon_wildwing, "fw_Item_AddToPlayer_Post", 1)
	
	g_MsgCurWeapon = get_user_msgid("CurWeapon")
	g_MsgAmmoX = get_user_msgid("AmmoX")

	register_clcmd("say /get", "Get_WildWing")
}

public plugin_precache()
{
	precache_model(MODEL_V)
	precache_model(MODEL_P)
	precache_model(MODEL_W)
	
	for(new i = 0; i < sizeof(WildWing_Sounds); i++)
		precache_sound(WildWing_Sounds[i])
		
	g_SmokePuff_SprId = precache_model("sprites/wall_puff1.spr")
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

public Do_Register_HamBot(id) Register_SafetyFuncBot(id)
public client_disconnect(id)
{
	Safety_Disconnected(id)
}

public Get_WildWing(id)
{
	drop_weapons(id, 2)
	
	Set_BitVar(g_Had_WildWing, id)
	UnSet_BitVar(g_TempingAttack, id)
	UnSet_BitVar(g_Holding, id)
	UnSet_BitVar(g_Shoot, id)
	
	g_Ammo[id] = AMMO
	give_item(id, weapon_wildwing)
	
	update_ammo(id, -1, g_Ammo[id])
}

public Remove_WildWing(id)
{
	UnSet_BitVar(g_Had_WildWing, id)
	UnSet_BitVar(g_TempingAttack, id)
	UnSet_BitVar(g_Holding, id)
	UnSet_BitVar(g_Shoot, id)
}

public Event_CurWeapon(id)
{
	if(!is_alive(id))
		return
		
	static CSWID; CSWID = read_data(2)
	if((CSWID == CSW_WILDWING && g_OldWeapon[id] != CSW_WILDWING) && Get_BitVar(g_Had_WildWing, id))
	{
		update_ammo(id, -1, g_Ammo[id])
	} else if((CSWID == CSW_WILDWING && g_OldWeapon[id] == CSW_WILDWING) && Get_BitVar(g_Had_WildWing, id)) {
		update_ammo(id, -1, g_Ammo[id])
	}
	
	g_OldWeapon[id] = CSWID
}

public fw_UpdateClientData_Post(id, sendweapons, cd_handle)
{
	if(!is_alive(id))
		return FMRES_IGNORED	
	if(get_player_weapon(id) == CSW_WILDWING && Get_BitVar(g_Had_WildWing, id))
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
	
	if(equal(model, WILDWING_OLDMODEL))
	{
		static weapon; weapon = find_ent_by_owner(-1, weapon_wildwing, entity)
		
		if(!pev_valid(weapon))
			return FMRES_IGNORED;
		
		if(Get_BitVar(g_Had_WildWing, iOwner))
		{
			set_pev(weapon, pev_impulse, 2512015)
			set_pev(weapon, pev_iuser4, g_Ammo[iOwner])
			
			engfunc(EngFunc_SetModel, entity, MODEL_W)
			
			Remove_WildWing(iOwner)
			
			return FMRES_SUPERCEDE
		}
	}

	return FMRES_IGNORED;
}

public fw_EmitSound(id, channel, const sample[], Float:volume, Float:attn, flags, pitch)
{
	if(!is_connected(id))
		return FMRES_IGNORED
	if(get_player_weapon(id) != CSW_WILDWING || !Get_BitVar(g_Had_WildWing, id))
		return FMRES_IGNORED
		
	if(sample[8] == 'k' && sample[9] == 'n' && sample[10] == 'i')
	{
		if(sample[14] == 's' && sample[15] == 'l' && sample[16] == 'a')
		{
			return FMRES_SUPERCEDE
		}
		if (sample[14] == 'h' && sample[15] == 'i' && sample[16] == 't')
		{
			if (sample[17] == 'w') // wall
			{
				return FMRES_SUPERCEDE
			} else {
				return FMRES_SUPERCEDE
			}
		}
		if (sample[14] == 's' && sample[15] == 't' && sample[16] == 'a')
			return FMRES_SUPERCEDE;
	}
	
	return FMRES_IGNORED
}

public fw_TraceLine(Float:vector_start[3], Float:vector_end[3], ignored_monster, id, handle)
{
	if(!is_alive(id))
		return FMRES_IGNORED	
	if(get_player_weapon(id) != CSW_WILDWING || !Get_BitVar(g_Had_WildWing, id))
		return FMRES_IGNORED
	if(!Get_BitVar(g_TempingAttack, id)) 
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
	if(!is_alive(id))
		return FMRES_IGNORED	
	if(get_player_weapon(id) != CSW_WILDWING || !Get_BitVar(g_Had_WildWing, id))
		return FMRES_IGNORED
	if(!Get_BitVar(g_TempingAttack, id)) 
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

public fw_CmdStart(id, uc_handle, seed)
{
	if(!is_alive(id)) 
		return
	if(get_player_weapon(id) != CSW_WILDWING || !Get_BitVar(g_Had_WildWing, id))
		return
	
	static Ent; Ent = fm_get_user_weapon_entity(id, CSW_WILDWING)
	if(!pev_valid(Ent))
		return
		
	static CurButton; CurButton = get_uc(uc_handle, UC_Buttons)
	static OldButton; OldButton = pev(id, pev_oldbuttons)
		
	if(g_Ammo[id] <= 0)
	{
		if(get_pdata_float(id, 83, 5) > 0.0) 
			return
		
		if(CurButton & IN_ATTACK)
		{
			CurButton &= ~IN_ATTACK
			set_uc(uc_handle, UC_Buttons, CurButton)
		}
		
		Set_Weapon_Idle(id, CSW_WILDWING, 1.0 + 0.3)
		Set_Player_NextAttack(id, 1.0)
	}
		
	if(CurButton & IN_ATTACK)
	{
		if(get_pdata_float(id, 83, 5) > 0.0) 
			return
		
		CurButton &= ~IN_ATTACK
		set_uc(uc_handle, UC_Buttons, CurButton)
		
		static Ent; Ent = fm_get_user_weapon_entity(id, CSW_WILDWING)
		if(!pev_valid(Ent)) return
		
		if(!Get_BitVar(g_Holding, id))
		{
			Set_Weapon_Idle(id, CSW_WILDWING, 0.45 + 0.3)
			Set_Player_NextAttack(id, 0.45)
			
			Set_WeaponAnim(id, ANIM_READY)
			Set_BitVar(g_Holding, id)
		} else {
			Set_Weapon_Idle(id, CSW_WILDWING, 1.0 + 0.3)
			Set_Player_NextAttack(id, 1.0)
			
			Set_WeaponAnim(id, ANIM_IDLE_R)
			Set_BitVar(g_Shoot, id)
		}
	} else {
		if(get_pdata_float(id, 83, 5) > 0.0) 
		{
			if(Get_BitVar(g_Shoot, id))
			{
				Set_Weapon_Idle(id, CSW_WILDWING, 1.75 + 0.3)
				Set_Player_NextAttack(id, 1.75)
				
				FireInTheHole(id)
				
				UnSet_BitVar(g_Shoot, id)
				UnSet_BitVar(g_Holding, id)
			}
			
			return
		}
		
		if(Get_BitVar(g_Holding, id))
		{
			Set_Weapon_Idle(id, CSW_WILDWING, 1.75 + 0.3)
			Set_Player_NextAttack(id, 1.75)
			
			FireInTheHole(id)
			
			UnSet_BitVar(g_Shoot, id)
			UnSet_BitVar(g_Holding, id)
		}
	}
}

public FireInTheHole(id)
{
	static Ent; Ent = fm_get_user_weapon_entity(id, CSW_WILDWING)
	if(!pev_valid(Ent)) return		
	
	// fake
	Set_BitVar(g_TempingAttack, id)
	ExecuteHamB(Ham_Weapon_PrimaryAttack, Ent)
	UnSet_BitVar(g_TempingAttack, id)
	
	g_Ammo[id]--
	update_ammo(id, -1, g_Ammo[id])
	
	if(g_Ammo[id]) Set_WeaponAnim(id, ANIM_SHOOT)
	else Set_WeaponAnim(id, ANIM_SHOOT_L)
	
	// Fake Punch
	static Float:VirtualVec[3]
	VirtualVec[0] = random_float(-5.0, -10.0)
	VirtualVec[1] = random_float(1.0, -1.0)
	VirtualVec[2] = 0.0	
	
	set_pev(id, pev_punchangle, VirtualVec)	
	
	// Sound
	emit_sound(id, CHAN_WEAPON, WildWing_Sounds[2], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	
	// Create
	CreateShot(id)
}

public CreateShot(id)
{
	new Trace = create_tr2()
	
	static Float:StartOrigin[3], Float:EndOrigin[3]
	pev(id, pev_origin, StartOrigin); StartOrigin[2] += 26.0
	get_position(id, 4096.0, 0.0, 0.0, EndOrigin)
	
	engfunc(EngFunc_TraceLine, StartOrigin, EndOrigin, DONT_IGNORE_MONSTERS, id, Trace) 
	
	// Get Hit
	static Target; Target = get_tr2(Trace, TR_pHit)
	if(is_alive(Target)) 
	{
		ExecuteHamB(Ham_TakeDamage, Target, 0, id, float(DAMAGE), DMG_BULLET)
	} else {
		static Float:flEnd[3]
		get_tr2(Trace, TR_vecEndPos, flEnd)

		Make_BulletHole(id, flEnd, float(DAMAGE))
		Make_BulletSmoke(id, Trace)
	}
	
	// Free it
	free_tr2(Trace)
}

public fw_Item_Deploy_Post(Ent)
{
	if(pev_valid(Ent) != 2)
		return
	static Id; Id = get_pdata_cbase(Ent, 41, 4)
	if(get_pdata_cbase(Id, 373) != Ent)
		return
	if(!Get_BitVar(g_Had_WildWing, Id))
		return
		
	set_pev(Id, pev_viewmodel2, MODEL_V)
	set_pev(Id, pev_weaponmodel2, MODEL_P)
	
	Set_WeaponAnim(Id, g_Ammo[Id] > 0 ? ANIM_DRAW : ANIM_DRAW_E)
	update_ammo(Id, -1, g_Ammo[Id])
}

public fw_Weapon_WeaponIdle_Post(Ent)
{
	if(pev_valid(Ent) != 2)
		return HAM_IGNORED
	static Id; Id = get_pdata_cbase(Ent, 41, 4)
	if(get_pdata_cbase(Id, 373) != Ent)
		return HAM_IGNORED
	if(!Get_BitVar(g_Had_WildWing, Id))
		return HAM_IGNORED
		
	if(get_pdata_float(Ent, 48, 4) <= 0.25) 
	{
		if(Get_BitVar(g_Holding, Id)) Set_WeaponAnim(Id, ANIM_IDLE_R)
		else Set_WeaponAnim(Id, g_Ammo[Id] > 0 ? ANIM_IDLE : ANIM_IDLE_E)
		
		update_ammo(Id, -1, g_Ammo[Id])
		set_pdata_float(Ent, 48, 20.0, 4)
	}
	
	return HAM_IGNORED
}

public fw_Item_AddToPlayer_Post(Ent, id)
{
	if(!pev_valid(Ent))
		return HAM_IGNORED
		
	if(pev(Ent, pev_impulse) == 2512015)
	{
		Set_BitVar(g_Had_WildWing, id)
		set_pev(Ent, pev_impulse, 0)
		
		g_Ammo[id] = pev(Ent, pev_iuser4)
		update_ammo(id, -1, g_Ammo[id])
	}

	return HAM_HANDLED	
}

public update_ammo(id, Ammo, BpAmmo)
{
	message_begin(MSG_ONE_UNRELIABLE, g_MsgCurWeapon, _, id)
	write_byte(1)
	write_byte(CSW_WILDWING)
	write_byte(Ammo)
	message_end()
	
	message_begin(MSG_ONE_UNRELIABLE, g_MsgAmmoX, _, id)
	write_byte(8)
	write_byte(BpAmmo)
	message_end()
	
	cs_set_user_bpammo(id, CSW_WILDWING, BpAmmo)
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
stock PlaySound(id, const sound[])
{
	if(equal(sound[strlen(sound)-4], ".mp3")) client_cmd(id, "mp3 play ^"sound/%s^"", sound)
	else client_cmd(id, "spk ^"%s^"", sound)
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

public is_connected(id)
{
	if(!(1 <= id <= 32))
		return 0
	if(!Get_BitVar(g_IsConnected, id))
		return 0
	
	return 1
}

public is_alive(id)
{
	if(!(1 <= id <= 32))
		return 0
	if(!Get_BitVar(g_IsConnected, id))
		return 0
	if(Get_BitVar(g_IsAlive, id)) return 1
	else return 0
	
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
