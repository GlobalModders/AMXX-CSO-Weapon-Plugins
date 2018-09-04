#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <cstrike>
#include <xs>
#include <fun>

#define PLUGIN "[CSO] Mount Gun"
#define VERSION "1.0"
#define AUTHOR "Jedi Master no Dias Leon"

#define DEFAULT_AMMO 250

#define MODEL_V "models/v_mountgun.mdl"
#define MODEL_P "models/p_mountgun.mdl"
#define MODEL_W "models/mountgun.mdl"

#define MOUNTGUN_CLASSNAME "hongkong"
#define MAP_MOUNTGUN_CLASSNAME "mountgun"
#define WEAPON_ANIMEXT "carbine"

#define SHOT_DISTANCE_POSSIBLE 2048.0

new const WeaponSounds[2][] =
{
	"weapons/mountgun_1.wav",
	"weapons/mountgun_empty.wav"
}

new const WeaponResources[3][] =
{
	"sprites/weapon_mountgun.txt",
	"sprites/640hud7_2.spr",
	"sprites/640hud72_2.spr"
}

enum
{
	ANIME_IDLE = 0,
	ANIME_SHOOT1,
	ANIME_SHOOT2,
	ANIME_SHOOT_EMPTY
}

#define Get_BitVar(%1,%2) (%1 & (1 << (%2 & 31)))
#define Set_BitVar(%1,%2) %1 |= (1 << (%2 & 31))
#define UnSet_BitVar(%1,%2) %1 &= ~(1 << (%2 & 31))

const pev_using = pev_iuser1
const pev_user = pev_iuser2
const pev_ammo = pev_iuser3

new Float:PressingTime[33], g_MountingGun[33]
new g_MsgWeaponList, g_SmokePuff_SprId, g_InTempingAttack

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	register_forward(FM_CmdStart, "fw_CmdStart")
	register_forward(FM_EmitSound, "fw_EmitSound")
	register_forward(FM_TraceLine, "fw_TraceLine")
	register_forward(FM_TraceHull, "fw_TraceHull")
	
	register_touch(MOUNTGUN_CLASSNAME, "player", "fw_Touch")
	register_think(MOUNTGUN_CLASSNAME, "fw_Think")
	
	RegisterHam(Ham_Item_Deploy, "weapon_c4", "fw_Item_Deploy_Post", 1)	
	RegisterHam(Ham_Item_Holster, "weapon_c4", "fw_Item_Holster_Post", 1)	
	RegisterHam(Ham_Item_AddToPlayer, "weapon_c4", "fw_Item_AddToPlayer_Post", 1)
	
	g_MsgWeaponList = get_user_msgid("WeaponList")
	set_task(1.0, "Weapon_Locations")
	
	register_clcmd("drop", "CMD_Drop")
}

public plugin_precache()
{
	precache_model(MODEL_V)
	precache_model(MODEL_P)
	precache_model(MODEL_W)
	
	for(new i = 0; i < sizeof(WeaponSounds); i++)
		precache_sound(WeaponSounds[i])
	
	precache_generic(WeaponResources[0])
	precache_model(WeaponResources[1])
	precache_model(WeaponResources[2])
	
	g_SmokePuff_SprId = engfunc(EngFunc_PrecacheModel, "sprites/wall_puff1.spr")
}

public Weapon_Locations()
{
	new iEnt, i = 0, iEnts[64]
	while((iEnt = engfunc(EngFunc_FindEntityByString, iEnt, "classname", "info_target")) != 0)
	{
		iEnts[i] = iEnt
		i++
	}
	
	new szTargetName[32]
	for(new j = 0; j < i; j++)
	{
		pev(iEnts[j], pev_targetname, szTargetName, 31)
		
		if(equal(szTargetName, MAP_MOUNTGUN_CLASSNAME))
		{
			static Float:Origin[3], Float:Angles[3]
			pev(iEnts[j], pev_origin, Origin)
			pev(iEnts[j], pev_angles, Angles)
			
			Spawn_Mountgun(Origin, Angles)
		}
	}
}

public Forward_NewRound() // add this function to your 'Event_NewRound'
{
	static Classname[64]
	for(new i = 0; i < entity_count(); i++)
	{
		if(!pev_valid(i))
			continue
		pev(i, pev_classname, Classname, 63)
		
		if(equal(Classname, MOUNTGUN_CLASSNAME))
			Reset_MountGun(i)
	}
}

public Forward_PlayerSpawn_Die(id) // add this function to your 'fw_PlayerSpawn_Post' and 'PlayerKilled' or 'Event_Death'
{
	g_MountingGun[id] = 0
}

public Spawn_Mountgun(Float:Origin[3], Float:Angles[3])
{
	new Gun = create_entity("info_target")
	
	// set info for ent
	entity_set_string(Gun, EV_SZ_classname, MOUNTGUN_CLASSNAME)
	engfunc(EngFunc_SetModel, Gun, MODEL_W)
	
	set_pev(Gun, pev_mins, Float:{-26.0, -26.0, 0.0})
	set_pev(Gun, pev_maxs, Float:{26.0, 26.0, 32.0})
	set_pev(Gun, pev_origin, Origin)
	set_pev(Gun, pev_angles, Angles)
	set_pev(Gun, pev_gravity, 1.0)
	set_pev(Gun, pev_movetype, MOVETYPE_PUSHSTEP)
	set_pev(Gun, pev_solid, SOLID_TRIGGER)
	set_pev(Gun, pev_using, 0)
	set_pev(Gun, pev_user, 0)
	set_pev(Gun, pev_ammo, DEFAULT_AMMO)
	
	set_pev(Gun, pev_nextthink, get_gametime() + 0.1)
}

public CMD_Drop(id)
{
	if(!is_user_alive(id))
		return PLUGIN_CONTINUE
	if(get_user_weapon(id) == CSW_C4 && pev_valid(g_MountingGun[id]))
		return PLUGIN_HANDLED
	
	return PLUGIN_CONTINUE
}

public Reset_Player(id)
{
	if(is_user_alive(id)) ham_strip_weapon(id, "weapon_c4")
	g_MountingGun[id] = 0
}

public Reset_MountGun(Ent)
{
	if(!pev_valid(Ent))
		return
	
	set_pev(Ent, pev_using, 0)
	set_pev(Ent, pev_user, 0)
	
	set_entity_visibility(Ent, 1)
}

public fw_CmdStart(id, uc_handle, seed)
{
	if(!is_user_alive(id))
		return
	if(get_user_weapon(id) != CSW_C4 || !g_MountingGun[id])
		return
	
	static Button; Button = get_uc(uc_handle, UC_Buttons)
	if(Button & IN_ATTACK)
	{
		Button &= ~IN_ATTACK
		set_uc(uc_handle, UC_Buttons, Button)
		
		Mountgun_ShootHandle(id)
	}
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
	if(!is_user_connected(id))
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
	if(!is_user_connected(id))
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

public Mountgun_ShootHandle(id)
{
	if(get_pdata_float(id, 83, 5) > 0.0)
		return
	
	static Gun; Gun = g_MountingGun[id]
	if(!pev_valid(Gun)) return
	
	static Ammo; Ammo = cs_get_user_bpammo(id, CSW_C4)
	if(Ammo <= 0) return
	
	Create_FakeAttack(id)
	
	if(Ammo - 1 > 0) Set_WeaponAnim(id, ANIME_SHOOT1)
	else {
		Set_WeaponAnim(id, ANIME_SHOOT_EMPTY)
		
		remove_task(id+146)
		set_task(0.5, "GunOut", id+146)
	}
	
	Ammo--; cs_set_user_bpammo(id, CSW_C4, Ammo)
	emit_sound(id, CHAN_WEAPON, WeaponSounds[0], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	
	// Punch
	static Float:OldP[3]; pev(id, pev_punchangle, OldP)
	static Float:Punch[3]
	Punch[0] = random_float(-0.5, -1.5)
	Punch[1] = random_float(-0.5, 0.5)
	
	xs_vec_add(OldP, Punch, Punch)
	set_pev(id, pev_punchangle, Punch)
	
	// Damage
	MountGun_Shoot(id, 25)
	
	// Next
	Set_PlayerNextAttack(id, 0.1)
	Set_WeaponIdleTime(id, CSW_C4, 1.0)
}

public GunOut(id)
{
	id -= 146
	
	if(!is_user_alive(id))
		return
	if(get_user_weapon(id) != CSW_C4 || !g_MountingGun[id])
		return
	
	static Ent; Ent = g_MountingGun[id]
	if(!pev_valid(Ent)) return
	
	// Set Gun
	set_pev(Ent, pev_using, 0)
	set_pev(Ent, pev_user, 0)
	
	set_entity_visibility(Ent, 1)
	
	// User
	static Float:Origin[3]; pev(Ent, pev_origin, Origin); Origin[2] += 36.0
	static Float:Back[3]; get_position(Ent, -100.0, 0.0, 0.0, Back)
	
	set_pev(id, pev_origin, Origin)
	Hook_The_Fucking_Ent(id, Back, 250.0)
	
	// Player Weapon
	set_pev(Ent, pev_ammo, cs_get_user_bpammo(id, CSW_C4))
	
	ham_strip_weapon(id, "weapon_c4")
	g_MountingGun[id] = 0
}

public fw_Think(Ent)
{
	if(!pev_valid(Ent))
		return
	if(!pev(Ent, pev_using))
	{
		static User; User = pev(Ent, pev_user)
		if(is_user_alive(User))
		{
			set_pev(Ent, pev_using, 0)
			set_pev(Ent, pev_user, 0)
		} 
		} else {
		static User; User = pev(Ent, pev_user)
		if(!is_user_alive(User))
		{
			set_pev(Ent, pev_using, 0)
			set_pev(Ent, pev_user, 0)
			} else {
			if(entity_range(Ent, User) >= 16.0)
			{
				static Float:Origin[3]; 
				pev(Ent, pev_origin, Origin)
				
				Origin[2] += 30.0
				set_pev(User, pev_origin, Origin)
			}
		}
	}
	
	set_pev(Ent, pev_nextthink, get_gametime() + 0.1)
	
}

public fw_Touch(Ent, Id)
{
	if(!pev_valid(Ent))
		return
	
	static Button; Button = get_user_button(Id)
	if(Button & IN_USE)
	{
		if(get_gametime() - 1.0 > PressingTime[Id])
		{
			if(!pev(Ent, pev_using))
			{
				// Set Gun
				set_pev(Ent, pev_using, 1)
				set_pev(Ent, pev_user, Id)
				
				set_entity_visibility(Ent, 0)
				
				// User
				static Float:Origin[3]; pev(Ent, pev_origin, Origin); Origin[2] += 30.0
				static Float:Angles[3]; pev(Ent, pev_angles, Angles)
				
				set_pev(Id, pev_origin, Origin)
				set_pev(Id, pev_v_angle, Angles)
				set_pev(Id, pev_fixangle, 1)
				set_pev(Id, pev_velocity, {0.0, 0.0, 0.0})
				
				// Player Weapon
				g_MountingGun[Id] = Ent
				give_item(Id, "weapon_c4")
				engclient_cmd(Id, "weapon_c4")
				
				cs_set_user_bpammo(Id, CSW_C4, pev(Ent, pev_ammo))
				
				if(pev(Ent, pev_ammo) <= 0) 
				{
					remove_task(Id+146)
					set_task(0.5, "GunOut", Id+146)
				}
				} else {
				// Set Gun
				set_pev(Ent, pev_using, 0)
				set_pev(Ent, pev_user, 0)
				
				set_entity_visibility(Ent, 1)
				
				// User
				static Float:Origin[3]; pev(Ent, pev_origin, Origin); Origin[2] += 36.0
				static Float:Back[3]; get_position(Ent, -100.0, 0.0, 0.0, Back)
				
				set_pev(Id, pev_origin, Origin)
				Hook_The_Fucking_Ent(Id, Back, 250.0)
				
				// Player Weapon
				set_pev(Ent, pev_ammo, cs_get_user_bpammo(Id, CSW_C4))
				
				ham_strip_weapon(Id, "weapon_c4")
				g_MountingGun[Id] = 0
			}
			
			PressingTime[Id] = get_gametime()
		}
	} 
}

public fw_Item_Holster_Post(Ent)
{
	if(pev_valid(Ent) != 2)
		return
	static Id; Id = get_pdata_cbase(Ent, 41, 4)
	if(get_pdata_cbase(Id, 373) != Ent)
		return
	if(!g_MountingGun[Id])
		return
	static Gun; Gun = g_MountingGun[Id]
	if(!pev_valid(Gun))
		return
	
	if(pev(Gun, pev_using))
	{
		// Set Gun
		set_pev(Gun, pev_using, 0)
		set_pev(Gun, pev_user, 0)
		
		set_entity_visibility(Gun, 1)
		
		// User
		static Float:Origin[3]; pev(Gun, pev_origin, Origin); Origin[2] += 36.0
		static Float:Back[3]; get_position(Gun, -100.0, 0.0, 0.0, Back)
		
		set_pev(Id, pev_origin, Origin)
		Hook_The_Fucking_Ent(Id, Back, 250.0)
		
		// Player Weapon
		set_pev(Gun, pev_ammo, cs_get_user_bpammo(Id, CSW_C4))
		
		ham_strip_weapon(Id, "weapon_c4")
		g_MountingGun[Id] = 0
	}
}

public fw_Item_Deploy_Post(Ent)
{
	if(pev_valid(Ent) != 2)
		return
	static Id; Id = get_pdata_cbase(Ent, 41, 4)
	if(get_pdata_cbase(Id, 373) != Ent)
		return
	if(!g_MountingGun[Id])
		return
	
	set_pev(Id, pev_viewmodel2, MODEL_V)
	set_pev(Id, pev_weaponmodel2, MODEL_P)
	
	set_pdata_string(Id, (492) * 4, WEAPON_ANIMEXT, -1 , 20)
	Set_WeaponAnim(Id, ANIME_IDLE)
}

public fw_Item_AddToPlayer_Post(Ent, id)
{
	if(!pev_valid(Ent))
		return HAM_IGNORED
	
	if(g_MountingGun[id])
	{
		message_begin(MSG_ONE_UNRELIABLE, g_MsgWeaponList, _, id)
		write_string("weapon_mountgun")
		write_byte(14)
		write_byte(1)
		write_byte(-1)
		write_byte(-1)
		write_byte(4)
		write_byte(3)
		write_byte(CSW_C4)
		write_byte(24)
		message_end()	
	}
	
	return HAM_HANDLED	
}

public MountGun_Shoot(id, Damage)
{
	new Float:angles[3], Float:start[3], Float:end[3], Float:direction[3], Float:fakeend[3]
	
	// Turn the angles in a true vector
	pev(id, pev_angles, angles)
	angle_vector(angles, ANGLEVECTOR_FORWARD, direction)
	
	// We make this as a normal shot!
	xs_vec_mul_scalar(direction, SHOT_DISTANCE_POSSIBLE, fakeend)
	
	// Start origin
	pev(id, pev_origin, start)
	pev(id, pev_view_ofs, end)
	xs_vec_add(end, start, start)
	
	// Obtain the end shot origin
	xs_vec_add(start, fakeend, end)
	fm_get_aim_origin(id, fakeend)
	
	// From now this is how these variables will be used
	// origin - start place (will remain constant!)
	// end - end place (will remain constant!)
	// angles - no use
	// fakeend - dynamic start origin
	// direction - will be used in the forwards (will remain constant!)
	
	new ptr = create_tr2()
	
	// Trace to the first entity
	engfunc(EngFunc_TraceLine, start, end, DONT_IGNORE_MONSTERS, id, ptr)
	
	new hit = get_tr2(ptr, TR_pHit)
	//get_tr2(ptr, TR_vecEndPos, fakeend)
	
	if(pev_valid(hit) == 2) ExecuteHamB(Ham_TakeDamage, hit, 0, id, float(Damage), DMG_BULLET)
	else {
		Make_BulletHole(id, fakeend, float(Damage))
		//Make_BulletSmoke(id, ptr)
	}
	
	free_tr2(ptr)
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
	
	vAngle[0] = 0.0
	
	angle_vector(vAngle,ANGLEVECTOR_FORWARD,vForward) //or use EngFunc_AngleVectors
	angle_vector(vAngle,ANGLEVECTOR_RIGHT,vRight)
	angle_vector(vAngle,ANGLEVECTOR_UP,vUp)
	
	vStart[0] = vOrigin[0] + vForward[0] * forw + vRight[0] * right + vUp[0] * up
	vStart[1] = vOrigin[1] + vForward[1] * forw + vRight[1] * right + vUp[1] * up
	vStart[2] = vOrigin[2] + vForward[2] * forw + vRight[2] * right + vUp[2] * up
}

stock Hook_The_Fucking_Ent(ent, Float:TargetOrigin[3], Float:Speed)
{
	static Float:fl_Velocity[3], Float:EntOrigin[3], Float:distance_f, Float:fl_Time
	
	pev(ent, pev_origin, EntOrigin)
	
	distance_f = get_distance_f(EntOrigin, TargetOrigin)
	fl_Time = distance_f / Speed
	
	pev(ent, pev_velocity, fl_Velocity)
	
	fl_Velocity[0] = (TargetOrigin[0] - EntOrigin[0]) / fl_Time
	fl_Velocity[1] = (TargetOrigin[1] - EntOrigin[1]) / fl_Time
	fl_Velocity[2] = (TargetOrigin[2] - EntOrigin[2]) / fl_Time
	
	set_pev(ent, pev_velocity, fl_Velocity)
}

// takes a weapon from a player efficiently
stock ham_strip_weapon(id, weapon[])
{
	if(!equal(weapon,"weapon_",7)) return 0;
	
	new wId = get_weaponid(weapon);
	if(!wId) return 0;
	
	new wEnt;
	while((wEnt = engfunc(EngFunc_FindEntityByString,wEnt,"classname",weapon)) && pev(wEnt,pev_owner) != id) {}
	if(!wEnt) return 0;
	
	if(get_user_weapon(id) == wId) ExecuteHamB(Ham_Weapon_RetireWeapon,wEnt);
	
	if(!ExecuteHamB(Ham_RemovePlayerItem,id,wEnt)) return 0;
	ExecuteHamB(Ham_Item_Kill,wEnt);
	
	set_pev(id,pev_weapons,pev(id,pev_weapons) & ~(1<<wId));
	
	if(wId == CSW_C4)
	{
		cs_set_user_plant(id, 0, 0)
		cs_set_user_bpammo(id, CSW_C4, 0)
	} else if(wId == CSW_SMOKEGRENADE || wId == CSW_FLASHBANG || wId == CSW_HEGRENADE)
	cs_set_user_bpammo(id, wId, 0)
	
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

stock Set_WeaponAnim(id, anim)
{
	set_pev(id, pev_weaponanim, anim)
	
	message_begin(MSG_ONE_UNRELIABLE, SVC_WEAPONANIM, {0, 0, 0}, id)
	write_byte(anim)
	write_byte(pev(id, pev_body))
	message_end()
}
