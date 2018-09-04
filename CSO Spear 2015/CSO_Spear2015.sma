#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <cstrike>
#include <fun>

#define PLUGIN "Speargun"
#define VERSION "1.0"
#define AUTHOR "Dias Pendragon"

#define SPEAR 30
#define SPEAR_SPEED 1500
#define SPEAR_EXP_RADIUS 100
#define SPEAR_DAMAGE 95 // 95: Human | 560: Zombie
#define SPEAR_KNOCK 1000

#define TIME_DRAW 0.75
#define TIME_RELOAD 2.5
#define TIME_EXPLOSION 1.0

#define OLD_WMODEL "models/w_m249.mdl"
#define PLAYER_ANIMEXT "carbine"

#define SPEAR_CLASSNAME "spear"
#define TASK_RELOAD 13320141

#define V_MODEL "models/v_speargun.mdl"
#define P_MODEL "models/p_speargun.mdl"
#define W_MODEL "models/w_speargun.mdl"
#define S_MODEL "models/s_spear.mdl"

new const SpearSounds[4][] = 
{
	"weapons/speargun-1.wav",
	"weapons/speargun_hit.wav",
	"weapons/speargun_draw.wav",
	"weapons/speargun_clipin.wav"
}

new const SpearResources[3][] =
{
	"sprites/weapon_speargun.txt",
	"sprites/640hud12_2.spr",
	"sprites/640hud103_2.spr"
}

new const ExplosionSpr[] = "sprites/spear_exp.spr"
new const ExplosionSpr2[] = "sprites/SpearExp.spr"

enum
{
	SPEAR_ANIM_IDLE = 0, // 30/51
	SPEAR_ANIM_SHOOT, // 30/31
	SPEAR_ANIM_RELOAD, // 30/55
	SPEAR_ANIM_DRAW, // 30/43
	SPEAR_ANIM_DRAW_EMPTY, // 30/43
	SPEAR_ANIM_IDLE_EMPTY // 30/51
}

const pev_user = pev_iuser1
const pev_touched = pev_iuser2
const pev_attached = pev_iuser3
const pev_hitgroup = pev_iuser4
const pev_time = pev_fuser1
const pev_time2 = pev_fuser2

const m_iLastHitGroup = 75

#define CSW_SPEAR CSW_M249
#define weapon_spear "weapon_m249"

// MACROS
#define Get_BitVar(%1,%2) (%1 & (1 << (%2 & 31)))
#define Set_BitVar(%1,%2) %1 |= (1 << (%2 & 31))
#define UnSet_BitVar(%1,%2) %1 &= ~(1 << (%2 & 31))

new g_IsAlive, g_TempAttack, g_HamBot_Register, g_Shoot
new g_Had_Spear, g_Spear[33], Float:CheckDelay[33], g_CurrentSpear[33]
new g_MaxPlayers, g_MsgWeaponList, g_MsgCurWeapon, g_MsgAmmoX, g_CvarFriendlyFire
new g_SprId_LaserBeam, g_SprId_Exp, g_SprId_Exp2

public plugin_init() 
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	register_event("CurWeapon", "Event_CurWeapon", "be", "1=1")
	register_event("DeathMsg", "Event_Death", "a")
	
	register_think(SPEAR_CLASSNAME, "fw_SpearThink")
	register_touch(SPEAR_CLASSNAME, "*", "fw_SpearTouch")
	
	register_forward(FM_UpdateClientData, "fw_UpdateClientData_Post", 1)
	register_forward(FM_CmdStart, "fw_CmdStart")
	register_forward(FM_SetModel, "fw_SetModel")	
	register_forward(FM_EmitSound, "fw_EmitSound")
	register_forward(FM_TraceLine, "fw_TraceLine")
	register_forward(FM_TraceHull, "fw_TraceHull")	
	
	RegisterHam(Ham_Spawn, "player", "fw_PlayerSpawn_Post", 1)
	RegisterHam(Ham_Weapon_WeaponIdle, weapon_spear, "fw_Weapon_WeaponIdle_Post", 1)
	RegisterHam(Ham_Item_Deploy, weapon_spear, "fw_Item_Deploy_Post", 1)	
	RegisterHam(Ham_Item_AddToPlayer, weapon_spear, "fw_Item_AddToPlayer_Post", 1)

	g_MaxPlayers = get_maxplayers()
	g_MsgWeaponList = get_user_msgid("WeaponList")
	g_MsgCurWeapon = get_user_msgid("CurWeapon")
	g_MsgAmmoX = get_user_msgid("AmmoX")
	g_CvarFriendlyFire = get_cvar_pointer("mp_friendlyfire")
	
	register_clcmd("weapon_speargun", "Hook_Weapon")
	register_clcmd("say /spear", "Get_Spear")
}

public plugin_precache()
{
	engfunc(EngFunc_PrecacheModel, V_MODEL)
	engfunc(EngFunc_PrecacheModel, P_MODEL)
	engfunc(EngFunc_PrecacheModel, W_MODEL)
	engfunc(EngFunc_PrecacheModel, S_MODEL)
	
	for(new i = 0; i < sizeof(SpearSounds); i++)
		engfunc(EngFunc_PrecacheSound, SpearSounds[i])
		
	for(new i = 0; i < sizeof(SpearResources); i++)
	{
		if(i == 0) engfunc(EngFunc_PrecacheGeneric, SpearResources[i])
		else engfunc(EngFunc_PrecacheModel, SpearResources[i])
	}	
	
	g_SprId_LaserBeam = engfunc(EngFunc_PrecacheModel, "sprites/laserbeam.spr")
	g_SprId_Exp = engfunc(EngFunc_PrecacheModel, ExplosionSpr)
	g_SprId_Exp2 = engfunc(EngFunc_PrecacheModel, ExplosionSpr2)
}

public client_putinserver(id)
{
	if(is_user_bot(id) && !g_HamBot_Register)
	{
		g_HamBot_Register = 1
		set_task(0.1, "Do_RegisterHamBot", id)
	}
	
	UnSet_BitVar(g_TempAttack, id)
	UnSet_BitVar(g_IsAlive, id)
}

public client_disconnect(id)
{
	UnSet_BitVar(g_TempAttack, id)
	UnSet_BitVar(g_IsAlive, id)
}

public Do_RegisterHamBot(id)
{
	RegisterHamFromEntity(Ham_Spawn, id, "fw_PlayerSpawn_Post", 1)
}

public Get_Spear(id)
{
	Set_BitVar(g_Had_Spear, id)
	UnSet_BitVar(g_Shoot, id)
	g_Spear[id] = SPEAR
	
	give_item(id, weapon_spear)
	
	update_ammo(id, -1, g_Spear[id])
}

public Remove_Spear(id)
{
	UnSet_BitVar(g_Had_Spear, id)
	UnSet_BitVar(g_Shoot, id)
	g_Spear[id] = 0
	
	remove_task(id+TASK_RELOAD)
}

public Hook_Weapon(id)
{
	engclient_cmd(id, weapon_spear)
	return PLUGIN_HANDLED
}

public Event_CurWeapon(id)
{
	if(!Get_BitVar(g_IsAlive, id))
		return
	
	static CSWID; CSWID = read_data(2)
	if(CSWID == CSW_SPEAR && Get_BitVar(g_Had_Spear, id))
		update_ammo(id, -1, g_Spear[id])
}

public Event_Death()
{
	static Victim; Victim = read_data(2)
	UnSet_BitVar(g_IsAlive, Victim)
}

public fw_UpdateClientData_Post(id, sendweapons, cd_handle)
{
	if(!Get_BitVar(g_IsAlive, id))
		return FMRES_IGNORED	
	if(get_user_weapon(id) == CSW_SPEAR && Get_BitVar(g_Had_Spear, id))
		set_cd(cd_handle, CD_flNextAttack, get_gametime() + 0.001) 
	
	return FMRES_HANDLED
}

public fw_SetModel(entity, model[])
{
	if(!pev_valid(entity))
		return FMRES_IGNORED
	
	static Classname[64]
	pev(entity, pev_classname, Classname, sizeof(Classname))
	
	if(!equal(Classname, "weaponbox"))
		return FMRES_IGNORED
	
	static id
	id = pev(entity, pev_owner)
	
	if(equal(model, OLD_WMODEL))
	{
		static weapon
		weapon = fm_get_user_weapon_entity(entity, CSW_SPEAR)
		
		if(!pev_valid(weapon))
			return FMRES_IGNORED
		
		if(Get_BitVar(g_Had_Spear, id))
		{
			UnSet_BitVar(g_Had_Spear, id)
			
			set_pev(weapon, pev_impulse, 1332014)
			set_pev(weapon, pev_iuser4, g_Spear[id])
			
			engfunc(EngFunc_SetModel, entity, W_MODEL)
			Remove_Spear(id)
			
			return FMRES_SUPERCEDE
		}
	}

	return FMRES_IGNORED;
}

public fw_CmdStart(id, UcHandle, Seed)
{
	if(!Get_BitVar(g_IsAlive, id))
		return
	if(get_user_weapon(id) != CSW_SPEAR || !Get_BitVar(g_Had_Spear, id))
		return

	static CurButton; CurButton = get_uc(UcHandle, UC_Buttons)
	if(CurButton & IN_ATTACK)
	{
		if(get_pdata_float(id, 83, 5) > 0.0)
			return
		
		CurButton &= ~IN_ATTACK
		set_uc(UcHandle, UC_Buttons, CurButton)

		if(get_gametime() - TIME_RELOAD > CheckDelay[id])
		{
			Spear_Shooting(id)
			CheckDelay[id] = get_gametime()
		}
	} else if(CurButton & IN_ATTACK2) {
		CurButton &= ~IN_ATTACK2
		set_uc(UcHandle, UC_Buttons, CurButton)
		
		if(!Get_BitVar(g_Shoot, id))
			return
			
		if(pev_valid(g_CurrentSpear[id]))
		{
			SpearExplosion(g_CurrentSpear[id], 1)
			set_pev(g_CurrentSpear[id], pev_flags, FL_KILLME)
			
			UnSet_BitVar(g_Shoot, id)
		}
	}
}

public Spear_Shooting(id)
{
	if(g_Spear[id] <= 0)
		return
		
	Set_BitVar(g_Shoot, id)
		
	Set_BitVar(g_TempAttack, id)
	static Ent; Ent = fm_get_user_weapon_entity(id, CSW_KNIFE)
	if(pev_valid(Ent)) ExecuteHamB(Ham_Weapon_PrimaryAttack, Ent)
	UnSet_BitVar(g_TempAttack, id)
	
	g_Spear[id]--
	update_ammo(id, -1, g_Spear[id])
	
	Set_WeaponAnim(id, SPEAR_ANIM_SHOOT)
	emit_sound(id, CHAN_WEAPON, SpearSounds[0], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)	
	
	Make_FakePunch(id)
	
	// Set Idle
	Set_Player_NextAttack(id, TIME_RELOAD)
	Set_WeaponIdleTime(id, CSW_SPEAR, TIME_RELOAD)
		
	// Spear
	Create_Spear(id)
	
	// Set Task
	set_task(1.0, "Play_ReloadAnim", id+TASK_RELOAD)
}

public Make_FakePunch(id)
{
	static Float:PunchAngles[3]
	PunchAngles[0] = random_float(-3.5, -7.0)
	
	set_pev(id, pev_punchangle, PunchAngles)
}

public Play_ReloadAnim(id)
{
	id -= TASK_RELOAD
	
	if(!Get_BitVar(g_IsAlive, id))
		return
	if(get_user_weapon(id) != CSW_SPEAR || !Get_BitVar(g_Had_Spear, id))
		return
	if(g_Spear[id] <= 0)
		return
		
	Set_WeaponAnim(id, SPEAR_ANIM_RELOAD)
}

public Create_Spear(id)
{
	static Ent; Ent = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"))
	if(!pev_valid(Ent)) return
	
	static Float:Origin[3], Float:Target[3], Float:Angles[3], Float:Velocity[3]
	
	get_weapon_attachment(id, Origin, 0.0)
	//Get_Position(id, 0.0, 9.0, -8.0, Origin)
	Get_Position(id, 1024.0, 0.0, 0.0, Target)
	
	pev(id, pev_v_angle, Angles); Angles[0] *= -1.0

	// Set info for ent
	set_pev(Ent, pev_movetype, MOVETYPE_FLY)
	
	set_pev(Ent, pev_classname, SPEAR_CLASSNAME)
	engfunc(EngFunc_SetModel, Ent, S_MODEL)
	
	set_pev(Ent, pev_mins, Float:{-1.0, -1.0, -1.0})
	set_pev(Ent, pev_maxs, Float:{1.0, 1.0, 1.0})
	
	set_pev(Ent, pev_origin, Origin)
	set_pev(Ent, pev_angles, Angles)
	set_pev(Ent, pev_gravity, 0.01)
	
	set_pev(Ent, pev_solid, SOLID_TRIGGER)
	
	set_pev(Ent, pev_user, id)
	set_pev(Ent, pev_touched, 0)
	set_pev(Ent, pev_time, 0.0)
	set_pev(Ent, pev_time2, get_gametime() + 5.0)
	set_pev(Ent, pev_hitgroup, -1)
	
	set_pev(Ent, pev_nextthink, get_gametime() + 0.01)
	
	Get_SpeedVector(Origin, Target, float(SPEAR_SPEED), Velocity)
	set_pev(Ent, pev_velocity, Velocity)
	
	g_CurrentSpear[id] = Ent

	// Create Beam
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_BEAMFOLLOW)
	write_short(Ent)
	write_short(g_SprId_LaserBeam)
	write_byte(2)
	write_byte(1)
	write_byte(42)
	write_byte(255)
	write_byte(170)
	write_byte(150)
	message_end()
}

public fw_EmitSound(id, channel, const sample[], Float:volume, Float:attn, flags, pitch)
{
	if(!Get_BitVar(g_IsAlive, id))
		return FMRES_IGNORED
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
	if(!Get_BitVar(g_IsAlive, id))
		return FMRES_IGNORED
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
	if(!Get_BitVar(g_IsAlive, id))
		return FMRES_IGNORED
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

public fw_SpearThink(Ent)
{
	if(!pev_valid(Ent))
		return
	if(pev(Ent, pev_flags) == FL_KILLME)
		return
		
	static Victim; Victim = pev(Ent, pev_attached)
	static Owner; Owner = pev(Ent, pev_user)
	
	if(!pev(Ent, pev_touched) && (is_user_connected(Owner) && Get_BitVar(g_IsAlive, Owner)))
	{
		static i, Target; Target = 0
		for(i = 0; i < g_MaxPlayers; i++)
		{
			if(!is_user_connected(i))
				continue
			if(!Get_BitVar(g_IsAlive, i))
				continue
			if(entity_range(Ent, i) > 24.0)
				continue
			
			Target = i
			
			break
		}
	
		if(Get_BitVar(g_IsAlive, Target) && Target != Owner)
		{
			if(!get_pcvar_num(g_CvarFriendlyFire))
			{
				if(cs_get_user_team(Owner) != cs_get_user_team(Target))
				{
					// Check hitgroup
					static Float:HeadOrigin[3], Float:HeadAngles[3];
					engfunc(EngFunc_GetBonePosition, Target, 8, HeadOrigin, HeadAngles);
						
					static Float:EntOrigin[3]
					pev(Ent, pev_origin, EntOrigin)
			
					if(get_distance_f(EntOrigin, HeadOrigin) <= 10.0) set_pev(Ent, pev_hitgroup, HIT_HEAD)
					else set_pev(Ent, pev_hitgroup, HIT_CHEST)
					
					// Handle
					set_pev(Ent, pev_touched, 1)
					set_pev(Ent, pev_time, get_gametime() + TIME_EXPLOSION)
					set_pev(Ent, pev_attached, Target)
				}
			} else {
				// Check hitgroup
				static Float:HeadOrigin[3], Float:HeadAngles[3];
				engfunc(EngFunc_GetBonePosition, Target, 8, HeadOrigin, HeadAngles);
					
				static Float:EntOrigin[3]
				pev(Ent, pev_origin, EntOrigin)
		
				if(get_distance_f(EntOrigin, HeadOrigin) <= 10.0) set_pev(Ent, pev_hitgroup, HIT_HEAD)
				else set_pev(Ent, pev_hitgroup, HIT_CHEST)
				
				// Handle
				set_pev(Ent, pev_touched, 1)
				set_pev(Ent, pev_time, get_gametime() + TIME_EXPLOSION)
				set_pev(Ent, pev_attached, Target)
			}
		}
	}
		
	if(is_user_connected(Victim) && Get_BitVar(g_IsAlive, Victim))
	{
		static Float:Origin[3]; pev(Victim, pev_origin, Origin)
		engfunc(EngFunc_SetOrigin, Ent, Origin)
		
		if(Get_BitVar(g_IsAlive, Owner))
		{
			static Float:OriginA[3]; pev(Owner, pev_origin, OriginA)
			static Float:Velocity[3]; Get_SpeedVector(OriginA, Origin, float(SPEAR_KNOCK), Velocity)
			
			static i
			for(i = 0; i < g_MaxPlayers; i++)
			{
				if(Victim == i)
					continue
				if(!is_user_connected(i))
					continue
				if(!Get_BitVar(g_IsAlive, i))
					continue
				if(entity_range(Victim, i) > 36.0)
					continue
				
				set_pev(i, pev_velocity, Velocity)
			}
			
			set_pev(Victim, pev_velocity, Velocity)
		}
	}
	
	if(pev(Ent, pev_touched) && pev(Ent, pev_time) <= get_gametime())
	{
		SpearExplosion(Ent, 0)
		set_pev(Ent, pev_flags, FL_KILLME)
		
		static Owner; Owner = pev(Ent, pev_user)
		UnSet_BitVar(g_Shoot, Owner)
	}
	
	if(pev(Ent, pev_time2) <= get_gametime())
	{
		set_pev(Ent, pev_flags, FL_KILLME)
		
		static Owner; Owner = pev(Ent, pev_user)
		UnSet_BitVar(g_Shoot, Owner)
	}
	
	set_pev(Ent, pev_nextthink, get_gametime() + 0.01)
}

public fw_SpearTouch(Ent, Touched)
{
	if(!pev_valid(Ent))
		return
		
	static id; id = pev(Ent, pev_user)
	if(!is_user_connected(id))
	{
		remove_entity(Ent)
		return
	}
	if(pev(Ent, pev_touched))
		return
	
	if(!is_user_alive(Touched))
	{
		emit_sound(Ent, CHAN_BODY, SpearSounds[1], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
		
		set_pev(Ent, pev_movetype, MOVETYPE_NONE)
		
		set_pev(Ent, pev_touched, 1)
		set_pev(Ent, pev_time, get_gametime() + TIME_EXPLOSION)
	}
}

public SpearExplosion(Ent, Remote)
{
	static Float:Origin[3]
	pev(Ent, pev_origin, Origin)
	
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_EXPLOSION)
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2])
	write_short(g_SprId_Exp)
	write_byte(20)
	write_byte(150)
	write_byte(TE_EXPLFLAG_NOSOUND)
	message_end()

	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_SPARKS)
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2])
	message_end()

	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_TAREXPLOSION)
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2])
	message_end()
	
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_EXPLOSION)
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2])
	write_short(g_SprId_Exp2)
	write_byte(6)
	write_byte(10)
	write_byte(TE_EXPLFLAG_NODLIGHTS | TE_EXPLFLAG_NOPARTICLES | TE_EXPLFLAG_NOSOUND)
	message_end()
	
	static Id; Id = pev(Ent, pev_user)
	if(is_user_connected(Id)) 
	{
		static Hitgroup; Hitgroup = pev(Ent, pev_hitgroup)
		static Target; Target = pev(Ent, pev_attached)
		
		Check_Damage(Ent, Id, Origin, Target)
		
		if(is_user_alive(Target))
		{
			if(!get_pcvar_flags(g_CvarFriendlyFire))
			{
				if(cs_get_user_team(Id) == cs_get_user_team(Target))
					return
			}
			
			if(Hitgroup == HIT_HEAD) 
			{
				set_pdata_int(Target, m_iLastHitGroup, HIT_HEAD, 5)
				ExecuteHamB(Ham_TakeDamage, Target, 0, Id, float(SPEAR_DAMAGE) * 2.5, DMG_BURN)
			} else {
				set_pdata_int(Target, m_iLastHitGroup, HIT_CHEST, 5)
				ExecuteHamB(Ham_TakeDamage, Target, 0, Id, float(SPEAR_DAMAGE), DMG_BURN)
			}
			
		}
	}
	
	// Extra
	if(Remote) SpearExplosion(Ent, 0)
}

public Check_Damage(Ent, id, Float:Origin[3], Except)
{
	for(new i = 0; i < g_MaxPlayers; i++)
	{
		if(!Get_BitVar(g_IsAlive, i))
			continue
		if(entity_range(Ent, i) > float(SPEAR_EXP_RADIUS))
			continue
		if(Except == i)
			continue
			
		if(id != i) ExecuteHamB(Ham_TakeDamage, i, 0, id, float(SPEAR_DAMAGE) / 3.0, DMG_BURN)
		Check_Knockback(i, Ent, id)
	}
}

public Check_Knockback(id, Ent, Owner)
{
	if(id == Owner)
	{
		static Float:Velocity[3]; pev(id, pev_velocity, Velocity)
		
		Velocity[0] *= 1.0; Velocity[1] *= 1.0; Velocity[2] *= 1.5
		if(Velocity[2] < 0.0) Velocity[2] /= -1.25 
		
		set_pev(id, pev_velocity, Velocity)
	}
}

public fw_PlayerSpawn_Post(id) 
{
	Set_BitVar(g_IsAlive, id)
	Get_Spear(id)
}

public fw_Weapon_WeaponIdle_Post(Ent)
{
	if(pev_valid(Ent) != 2)
		return HAM_IGNORED	
	static Id; Id = get_pdata_cbase(Ent, 41, 4)
	if(get_pdata_cbase(Id, 373) != Ent)
		return HAM_IGNORED	
	if(!Get_BitVar(g_Had_Spear, Id))
		return HAM_IGNORED	
		
	if(get_pdata_float(Ent, 48, 4) <= 0.1) 
	{
		if(g_Spear[Id] > 0) Set_WeaponAnim(Id, SPEAR_ANIM_IDLE)
		else Set_WeaponAnim(Id, SPEAR_ANIM_IDLE_EMPTY)
		
		set_pdata_float(Ent, 48, 20.0, 4)
		set_pdata_string(Id, (492) * 4, PLAYER_ANIMEXT, -1 , 20)
	}
	
	return HAM_IGNORED	
}

public fw_Item_Deploy_Post(Ent)
{
	if(pev_valid(Ent) != 2)
		return
	static Id; Id = get_pdata_cbase(Ent, 41, 4)
	if(get_pdata_cbase(Id, 373) != Ent)
		return
	if(!Get_BitVar(g_Had_Spear, Id))
		return
	
	set_pev(Id, pev_viewmodel2, V_MODEL)
	set_pev(Id, pev_weaponmodel2, P_MODEL)
	
	if(g_Spear[Id] > 0) Set_WeaponAnim(Id, SPEAR_ANIM_DRAW)
	else Set_WeaponAnim(Id, SPEAR_ANIM_DRAW_EMPTY)
	
	set_pdata_string(Id, (492) * 4, PLAYER_ANIMEXT, -1 , 20)
	Set_Player_NextAttack(Id, TIME_DRAW)
	
	remove_task(Id+TASK_RELOAD)
}

public fw_Item_AddToPlayer_Post(Ent, id)
{
	if(!pev_valid(Ent))
		return HAM_IGNORED
		
	if(pev(Ent, pev_impulse) == 1332014)
	{
		Set_BitVar(g_Had_Spear, id)
		set_pev(Ent, pev_impulse, 0)
		
		g_Spear[id] = pev(Ent, pev_iuser4)
	}		
	
	message_begin(MSG_ONE_UNRELIABLE, g_MsgWeaponList, .player = id)
	write_string(Get_BitVar(g_Had_Spear, id) ? "weapon_speargun" : weapon_spear)
	write_byte(3) // PrimaryAmmoID
	write_byte(200) // PrimaryAmmoMaxAmount
	write_byte(-1) // SecondaryAmmoID
	write_byte(-1) // SecondaryAmmoMaxAmount
	write_byte(0) // SlotID (0...N)
	write_byte(4) // NumberInSlot (1...N)
	write_byte(CSW_SPEAR) // WeaponID
	write_byte(0) // Flags
	message_end()

	return HAM_HANDLED	
}

public update_ammo(id, Ammo, BpAmmo)
{
	message_begin(MSG_ONE_UNRELIABLE, g_MsgCurWeapon, _, id)
	write_byte(1)
	write_byte(CSW_SPEAR)
	write_byte(Ammo)
	message_end()
	
	message_begin(MSG_ONE_UNRELIABLE, g_MsgAmmoX, _, id)
	write_byte(10)
	write_byte(BpAmmo)
	message_end()
	
	cs_set_user_bpammo(id, CSW_SPEAR, BpAmmo)
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

stock Set_Player_NextAttack(id, Float:nexttime)
{
	set_pdata_float(id, 83, nexttime, 5)
}

stock Set_WeaponAnim(id, Anim)
{
	set_pev(id, pev_weaponanim, Anim)
	
	message_begin(MSG_ONE_UNRELIABLE, SVC_WEAPONANIM, {0, 0, 0}, id)
	write_byte(Anim)
	write_byte(pev(id, pev_body))
	message_end()
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

stock Get_SpeedVector(const Float:origin1[3],const Float:origin2[3],Float:speed, Float:new_velocity[3])
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

stock Get_Yaw(Float:Start[3], Float:End[3])
{
	static Float:Vec[3], Float:Angles[3]
	Vec = Start
	
	Vec[0] = End[0] - Vec[0]
	Vec[1] = End[1] - Vec[1]
	Vec[2] = End[2] - Vec[2]
	engfunc(EngFunc_VecToAngles, Vec, Angles)
	Angles[0] = Angles[2] = 0.0 
	
	return floatround(Angles[1])
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
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang1042\\ f0\\ fs16 \n\\ par }
*/
