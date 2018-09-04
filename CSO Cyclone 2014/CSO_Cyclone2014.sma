#include <amxmodx>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <cstrike>
#include <fun>

#define PLUGIN "[CSO] Weapon: Cyclone"
#define VERSION "1.0"
#define AUTHOR "Dias Pendragon"

#define CSW_CYCLONE CSW_DEAGLE
#define weapon_cyclone "weapon_deagle"

#define OLD_W_MODEL "models/w_deagle.mdl"
#define WEAPON_SECRETCODE 20042014

#define V_MODEL "models/v_sfpistol.mdl"
#define P_MODEL "models/p_sfpistol.mdl"
#define W_MODEL "models/w_sfpistol.mdl"

#define DAMAGE 18
#define CLIP 50
#define BPAMMO 200

#define TIME_DRAW 0.75
#define TIME_RELOAD 2.5
#define TIME_ATTACKDELAY 0.025 // 0.085
#define TIME_ATTACKEND 0.5

new const WeaponSounds[7][] =
{
	"weapons/sfpistol_shoot1.wav",
	"weapons/sfpistol_shoot_start.wav",
	"weapons/sfpistol_shoot_end.wav",
	"weapons/sfpistol_idle.wav",
	"weapons/sfpistol_draw.wav",
	"weapons/sfpistol_clipin.wav",
	"weapons/sfpistol_clipout.wav"
}

new const WeaponResources[4][] =
{
	"sprites/weapon_sfpistol.txt",
	"sprites/640hud12_2.spr",
	"sprites/640hud104_2.spr",
	"sprites/ef_smoke_poison.spr"
}

enum
{
	CYCLONE_ANIM_IDLE = 0,
	CYCLONE_ANIM_SHOOT,
	CYCLONE_ANIM_SHOOT_END,
	CYCLONE_ANIM_RELOAD,
	CYCLONE_ANIM_DRAW
}

enum
{
	CYCLONE_STATE_IDLE = 0,
	CYCLONE_STATE_ATTACKING,
	CYCLONE_STATE_ENDING
}

// MACROS
#define Get_BitVar(%1,%2) (%1 & (1 << (%2 & 31)))
#define Set_BitVar(%1,%2) %1 |= (1 << (%2 & 31))
#define UnSet_BitVar(%1,%2) %1 &= ~(1 << (%2 & 31))

new g_Had_Cyclone, g_Beam_SprId, g_Burn_SprId
new g_Clip[33], g_WeaponState[33], Float:g_AttackSound[33], Float:g_CheckAmmo[33]
new g_MsgWeaponList, g_MsgCurWeapon

public plugin_init() 
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	register_forward(FM_UpdateClientData, "fw_UpdateClientData_Post", 1)		
	register_forward(FM_CmdStart, "fw_CmdStart")	
	register_forward(FM_SetModel, "fw_SetModel")

	RegisterHam(Ham_Item_Deploy, weapon_cyclone, "fw_Item_Deploy_Post", 1)	
	RegisterHam(Ham_Item_AddToPlayer, weapon_cyclone, "fw_Item_AddToPlayer_Post", 1)
	RegisterHam(Ham_Item_PostFrame, weapon_cyclone, "fw_Item_PostFrame")	
	RegisterHam(Ham_Weapon_Reload, weapon_cyclone, "fw_Weapon_Reload")
	RegisterHam(Ham_Weapon_Reload, weapon_cyclone, "fw_Weapon_Reload_Post", 1)		
	
	g_MsgWeaponList = get_user_msgid("WeaponList")
	g_MsgCurWeapon = get_user_msgid("CurWeapon")
	
	register_clcmd("admin_get_cyclone", "Get_Cyclone", ADMIN_KICK)
	register_clcmd("weapon_sfpistol", "Weapon_Hook")
}

public plugin_precache()
{
	engfunc(EngFunc_PrecacheModel, V_MODEL)
	engfunc(EngFunc_PrecacheModel, P_MODEL)
	engfunc(EngFunc_PrecacheModel, W_MODEL)
	
	for(new i = 0; i < sizeof(WeaponSounds); i++)
		engfunc(EngFunc_PrecacheSound, WeaponSounds[i])
	for(new i = 0; i < sizeof(WeaponResources); i++)
	{
		if(i == 0) engfunc(EngFunc_PrecacheGeneric, WeaponResources[i])
		else if(i == 3) g_Burn_SprId = engfunc(EngFunc_PrecacheModel, WeaponResources[i])
		else engfunc(EngFunc_PrecacheModel, WeaponResources[i])

	}
	
	g_Beam_SprId =  engfunc(EngFunc_PrecacheModel, "sprites/laserbeam.spr")
}

public Get_Cyclone(id)
{
	g_WeaponState[id] = CYCLONE_STATE_IDLE
	Set_BitVar(g_Had_Cyclone, id)
	
	give_item(id, weapon_cyclone)
	
	static Ent; Ent = fm_get_user_weapon_entity(id, CSW_CYCLONE)
	if(pev_valid(Ent)) cs_set_weapon_ammo(Ent, CLIP)
	
	cs_set_user_bpammo(id, CSW_CYCLONE, BPAMMO)
	
	engfunc(EngFunc_MessageBegin, MSG_ONE_UNRELIABLE, g_MsgCurWeapon, {0, 0, 0}, id)
	write_byte(1)
	write_byte(CSW_CYCLONE)
	write_byte(CLIP)
	message_end()
}

public Weapon_Hook(id)
{
	engclient_cmd(id, weapon_cyclone)
	return PLUGIN_HANDLED
}

public fw_UpdateClientData_Post(id, sendweapons, cd_handle)
{
	if(!is_user_alive(id))
		return FMRES_IGNORED	
	if(get_user_weapon(id) == CSW_CYCLONE && Get_BitVar(g_Had_Cyclone, id))
		set_cd(cd_handle, CD_flNextAttack, get_gametime() + 0.001) 

	return FMRES_HANDLED
}

public fw_CmdStart(id, uc_handle, seed)
{
	if(!is_user_alive(id))
		return FMRES_IGNORED	
	if(get_user_weapon(id) != CSW_CYCLONE || !Get_BitVar(g_Had_Cyclone, id))	
		return FMRES_IGNORED
		
	static NewButton; NewButton = get_uc(uc_handle, UC_Buttons)
	static OldButton; OldButton = pev(id, pev_oldbuttons)
	if(NewButton & IN_ATTACK)
	{
		NewButton &= ~IN_ATTACK
		set_uc(uc_handle, UC_Buttons, NewButton)
		
		if(get_pdata_float(id, 83, 5) > 0.0)
			return FMRES_IGNORED
			
		Cyclone_AttackHandle(id, 0)
	} else {
		if((OldButton & IN_ATTACK))
		{
			if(g_WeaponState[id] == CYCLONE_STATE_ATTACKING)
			{
				g_WeaponState[id] = CYCLONE_STATE_ENDING
				Cyclone_AttackHandle(id, 1)
			}
		}
	}
	
	return FMRES_IGNORED
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
		static weapon; weapon = fm_find_ent_by_owner(-1, weapon_cyclone, entity)
		
		if(!pev_valid(weapon))
			return FMRES_IGNORED;
		
		if(Get_BitVar(g_Had_Cyclone, iOwner))
		{
			UnSet_BitVar(g_Had_Cyclone, iOwner)
		
			set_pev(weapon, pev_impulse, WEAPON_SECRETCODE)
			engfunc(EngFunc_SetModel, entity, W_MODEL)
			
			return FMRES_SUPERCEDE
		}
	}

	return FMRES_IGNORED;
}

public fw_Item_Deploy_Post(Ent)
{
	if(pev_valid(Ent) != 2)
		return
	static Id; Id = get_pdata_cbase(Ent, 41, 4)
	if(get_pdata_cbase(Id, 373) != Ent)
		return
	if(!Get_BitVar(g_Had_Cyclone, Id))
		return
	
	set_pev(Id, pev_viewmodel2, V_MODEL)
	set_pev(Id, pev_weaponmodel2, P_MODEL)
	
	Set_WeaponAnim(Id, CYCLONE_ANIM_DRAW)
	set_pdata_float(Id, 83, TIME_DRAW, 5)
}

public fw_Item_AddToPlayer_Post(ent, id)
{
	if(!pev_valid(ent))
		return HAM_IGNORED
		
	if(pev(ent, pev_impulse) == WEAPON_SECRETCODE)
	{
		Set_BitVar(g_Had_Cyclone, id)
		set_pev(ent, pev_impulse, 0)
	}		
	
	message_begin(MSG_ONE_UNRELIABLE, g_MsgWeaponList, _, id)
	write_string(Get_BitVar(g_Had_Cyclone, id) ? "weapon_sfpistol" : weapon_cyclone)
	write_byte(8)
	write_byte(200)
	write_byte(-1)
	write_byte(-1)
	write_byte(1)
	write_byte(1)
	write_byte(CSW_CYCLONE)
	write_byte(0)
	message_end()	

	return HAM_HANDLED	
}

public fw_Item_PostFrame(ent)
{
	static id; id = pev(ent, pev_owner)
	if(!is_user_alive(id))
		return HAM_IGNORED
	if(!Get_BitVar(g_Had_Cyclone, id))
		return HAM_IGNORED	
	
	static Float:flNextAttack; flNextAttack = get_pdata_float(id, 83, 5)
	static bpammo; bpammo = cs_get_user_bpammo(id, CSW_CYCLONE)
	
	static iClip; iClip = get_pdata_int(ent, 51, 4)
	static fInReload; fInReload = get_pdata_int(ent, 54, 4)
	
	if(fInReload && flNextAttack <= 0.0)
	{
		static temp1
		temp1 = min(CLIP - iClip, bpammo)

		set_pdata_int(ent, 51, iClip + temp1, 4)
		cs_set_user_bpammo(id, CSW_CYCLONE, bpammo - temp1)		
		
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
	if(!Get_BitVar(g_Had_Cyclone, id))
		return HAM_IGNORED

	g_Clip[id] = -1
		
	static BPAmmo; BPAmmo = cs_get_user_bpammo(id, CSW_CYCLONE)
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
	if(!Get_BitVar(g_Had_Cyclone, id))
		return HAM_IGNORED
		
	if((get_pdata_int(ent, 54, 4) == 1))
	{ // Reload
		if(g_Clip[id] == -1)
			return HAM_IGNORED
		
		set_pdata_int(ent, 51, g_Clip[id], 4)
		Set_WeaponAnim(id, CYCLONE_ANIM_RELOAD)
		
		set_pdata_float(id, 83, TIME_RELOAD, 5)
		set_pdata_float(ent, 48, TIME_RELOAD + 1.0, 4)
	}
	
	return HAM_HANDLED
}

public Cyclone_AttackHandle(id, Pass)
{
	static Ent; Ent = fm_get_user_weapon_entity(id, CSW_CYCLONE)
	if(!pev_valid(Ent)) return
	
	if(!Pass)
	{
		if(cs_get_weapon_ammo(Ent) <= 0)
		{
			if(g_WeaponState[id] == CYCLONE_STATE_IDLE)
			{
				set_pdata_float(id, 83, 1.0, 5)
				return
			} else if(g_WeaponState[id] == CYCLONE_STATE_ATTACKING) {
				Set_WeaponAnim(id, CYCLONE_ANIM_SHOOT_END)
				emit_sound(id, CHAN_WEAPON, WeaponSounds[2], 1.0, ATTN_NORM, 0, PITCH_NORM)
				
				g_WeaponState[id] = CYCLONE_STATE_IDLE
				
				// Reload
				Set_WeaponAnim(id, CYCLONE_ANIM_RELOAD)
				set_pdata_int(Ent, 54, 1, 4)
				set_pdata_float(id, 83, TIME_RELOAD, 5)
				set_pdata_float(Ent, 48, TIME_RELOAD + 1.0, 4)
				
				return
			}
		}
			
		if(get_gametime() - 0.085 > g_CheckAmmo[id])
		{
			cs_set_weapon_ammo(Ent, cs_get_weapon_ammo(Ent) - 1)
			g_CheckAmmo[id] = get_gametime()
		}
		set_pdata_float(id, 83, TIME_ATTACKDELAY, 5)
	}
	
	// Main Event
	switch(g_WeaponState[id])
	{
		case CYCLONE_STATE_IDLE: 
		{
			Set_WeaponAnim(id, CYCLONE_ANIM_SHOOT)
			emit_sound(id, CHAN_WEAPON, WeaponSounds[1], 1.0, ATTN_NORM, 0, PITCH_NORM)
			
			g_WeaponState[id] = CYCLONE_STATE_ATTACKING
			g_AttackSound[id] = get_gametime() - 5.0
		}
		case CYCLONE_STATE_ATTACKING:
		{
			Set_WeaponAnim(id, CYCLONE_ANIM_SHOOT)
			
			if(get_gametime() - 4.0 > g_AttackSound[id])
			{
				emit_sound(id, CHAN_WEAPON, WeaponSounds[0], 1.0, ATTN_NORM, 0, PITCH_NORM)
				g_AttackSound[id] = get_gametime()
			}
			
			Create_Laser(id, Ent)
		}
		case CYCLONE_STATE_ENDING:
		{
			Set_WeaponAnim(id, CYCLONE_ANIM_SHOOT_END)
			emit_sound(id, CHAN_WEAPON, WeaponSounds[2], 1.0, ATTN_NORM, 0, PITCH_NORM)
			
			g_WeaponState[id] = CYCLONE_STATE_IDLE
			set_pdata_float(id, 83, TIME_ATTACKEND, 5)
		}
	}
}

public Create_Laser(id, Ent)
{
	static Float:StartOrigin[3], Float:EndOrigin[3], Float:EndOrigin2[3]
	
	Stock_Get_Postion(id, 40.0, 7.5, -5.0, StartOrigin)
	Stock_Get_Postion(id, 4096.0, 0.0, 0.0, EndOrigin)
	
	static TrResult; TrResult = create_tr2()
	engfunc(EngFunc_TraceLine, StartOrigin, EndOrigin, DONT_IGNORE_MONSTERS, id, TrResult) 
	
	// Calc
	get_weapon_attachment(id, EndOrigin)
	global_get(glb_v_forward, EndOrigin2)
    
	xs_vec_mul_scalar(EndOrigin2, 1024.0, EndOrigin2)
	xs_vec_add(EndOrigin, EndOrigin2, EndOrigin2)

	get_tr2(TrResult, TR_vecEndPos, EndOrigin)
	get_tr2(TrResult, TR_vecPlaneNormal, EndOrigin2)
	
	// Create Laser
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_BEAMENTPOINT)
	write_short(id | 0x1000)
	engfunc(EngFunc_WriteCoord, EndOrigin[0])
	engfunc(EngFunc_WriteCoord, EndOrigin[1])
	engfunc(EngFunc_WriteCoord, EndOrigin[2])
	write_short(g_Beam_SprId)
	write_byte(0)
	write_byte(0)
	write_byte(1)
	write_byte(10)
	write_byte(0)
	write_byte(41)
	write_byte(164)
	write_byte(0)
	write_byte(255)
	write_byte(0)
	message_end()		
    
	xs_vec_mul_scalar(EndOrigin2, 2.5, EndOrigin2)
	xs_vec_add(EndOrigin, EndOrigin2, EndOrigin2)

	// Create Burn Effect
	message_begin(MSG_BROADCAST ,SVC_TEMPENTITY)
	write_byte(TE_EXPLOSION)
	engfunc(EngFunc_WriteCoord, EndOrigin2[0])
	engfunc(EngFunc_WriteCoord, EndOrigin2[1])
	engfunc(EngFunc_WriteCoord, EndOrigin2[2])
	write_short(g_Burn_SprId)	// sprite index
	write_byte(2)	// scale in 0.1's
	write_byte(30)	// framerate
	write_byte(TE_EXPLFLAG_NODLIGHTS | TE_EXPLFLAG_NOPARTICLES | TE_EXPLFLAG_NOSOUND)	// flags
	message_end()
	
	// Take Damage
	static Hit; Hit = get_tr2(TrResult, TR_pHit)
	if(is_user_alive(Hit)) do_attack(id, Hit, 0, float(DAMAGE))
	
	// Free
	free_tr2(TrResult)
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

stock Set_WeaponAnim(id, Anim)
{
	set_pev(id, pev_weaponanim, Anim)
	
	message_begin(MSG_ONE_UNRELIABLE, SVC_WEAPONANIM, {0, 0, 0}, id)
	write_byte(Anim)
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
