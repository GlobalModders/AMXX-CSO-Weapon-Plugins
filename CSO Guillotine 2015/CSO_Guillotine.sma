#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <cstrike>
#include <xs>
#include <fun>

#define PLUGIN "[CSO] Guillotine"
#define VERSION "1.0"
#define AUTHOR "Joseph Rias de Dias Pendragon"

#define DAMAGE 35 // 35: Human | 200: Zombie
#define AMMO 10

#define MAX_RADIUS 700.0
#define FLYING_SPEED 1000.0
#define KNOCKBACK 3000.0
#define DAMAGE_DELAY 0.2
#define GUILLOTINE_HITTIME 5.0

#define MODEL_V "models/v_guillotine.mdl"
#define MODEL_P "models/p_guillotine.mdl"
#define MODEL_W "models/w_guillotine.mdl"

#define MODEL_S "models/guillotine_projectile.mdl"
#define MODEL_GIB "models/gibs_guilotine.mdl"

new const Weapon_Sounds[7][] =
{
	"weapons/guillotine_catch2.wav",
	"weapons/guillotine_draw.wav",
	"weapons/guillotine_draw_empty.wav",
	"weapons/guillotine_explode.wav",
	"weapons/guillotine_red.wav",
	"weapons/guillotine-1.wav",
	"weapons/guillotine_wall.wav"
}

new const Weapon_Resources[4][] = 
{
	"sprites/weapon_guillotine.txt",
	"sprites/640hud13_2.spr",
	"sprites/640hud120_2.spr",
	"sprites/guillotine_lost.spr"
}

enum
{
	ANIM_IDLE = 0, // 1.96
	ANIM_IDLE_EMPTY, // 1.96
	ANIM_SHOOT, // 0.67
	ANIM_DRAW, // 1.13
	ANIM_DRAW_EMPTY, // 1.13
	ANIM_EXPECT, // 1.96
	ANIM_EXPECT_FX, // 1.96
	ANIM_CATCH, // 0.967
	ANIM_LOST // 1.3
}

#define CSW_GUILLOTINE CSW_M249
#define weapon_guillotine "weapon_m249"

#define GUILLOTINE_OLDMODEL "models/w_m249.mdl"
#define WEAPON_ANIMEXT "grenade"
#define WEAPON_ANIMEXT2 "knife"

#define GUILLOTINE_CLASSNAME "guillotine"
#define TASK_RESET 14220151

const m_iLastHitGroup = 75

// MACROS
#define Get_BitVar(%1,%2) (%1 & (1 << (%2 & 31)))
#define Set_BitVar(%1,%2) %1 |= (1 << (%2 & 31))
#define UnSet_BitVar(%1,%2) %1 &= ~(1 << (%2 & 31))

const pev_eteam = pev_iuser1
const pev_return = pev_iuser2
const pev_extra = pev_iuser3

new g_Had_Guillotine, g_InTempingAttack, g_CanShoot, g_Hit, g_Ammo[33], g_MyGuillotine[33], Float:g_DamageTimeA[33], Float:g_DamageTimeB[33]
new g_MsgCurWeapon, g_MsgAmmoX, g_MsgWeaponList, g_CvarFriendlyFire
new g_HamBot, g_ExpSprID, g_GibModelID

// Safety
new g_IsConnected, g_IsAlive, g_PlayerWeapon[33]

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	// Safety
	Register_SafetyFunc()
	
	register_event("CurWeapon", "Event_CurWeapon", "be", "1=1")
	
	register_forward(FM_UpdateClientData, "fw_UpdateClientData_Post", 1)
	register_forward(FM_CmdStart, "fw_CmdStart")
	register_forward(FM_SetModel, "fw_SetModel")	
	register_forward(FM_EmitSound, "fw_EmitSound")
	register_forward(FM_TraceLine, "fw_TraceLine")
	register_forward(FM_TraceHull, "fw_TraceHull")
	
	register_touch(GUILLOTINE_CLASSNAME, "*", "fw_Guillotine_Touch")
	register_think(GUILLOTINE_CLASSNAME, "fw_Guillotine_Think")
	
	RegisterHam(Ham_Item_Deploy, weapon_guillotine, "fw_Item_Deploy_Post", 1)	
	RegisterHam(Ham_Item_AddToPlayer, weapon_guillotine, "fw_Item_AddToPlayer_Post", 1)
	RegisterHam(Ham_Weapon_WeaponIdle, weapon_guillotine, "fw_Weapon_WeaponIdle_Post", 1)
	
	g_MsgCurWeapon = get_user_msgid("CurWeapon")
	g_MsgAmmoX = get_user_msgid("AmmoX")
	g_MsgWeaponList = get_user_msgid("WeaponList")
	g_CvarFriendlyFire = get_cvar_pointer("mp_friendlyfire")
	
	register_clcmd("say /guillotine", "Get_Guillotine")
	register_clcmd("weapon_guillotine", "HookWeapon")
}

public plugin_precache()
{
	precache_model(MODEL_V)
	precache_model(MODEL_P)
	precache_model(MODEL_W)
	
	precache_model(MODEL_S)
	g_GibModelID = precache_model(MODEL_GIB)
	
	for(new i = 0; i < sizeof(Weapon_Sounds); i++)
		precache_sound(Weapon_Sounds[i])
	for(new i = 0; i < sizeof(Weapon_Resources); i++)
	{
		if(!i) precache_generic(Weapon_Resources[i])
		else if(i == 3) g_ExpSprID = precache_model(Weapon_Resources[i])
		else precache_model(Weapon_Resources[i])
	}
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

public Get_Guillotine(id)
{
	Set_BitVar(g_Had_Guillotine, id)
	Set_BitVar(g_CanShoot, id)
	UnSet_BitVar(g_InTempingAttack, id)
	UnSet_BitVar(g_Hit, id)
	
	g_Ammo[id] = AMMO
	g_MyGuillotine[id] = 0
	
	give_item(id, weapon_guillotine)
	update_ammo(id, -1, AMMO)
}

public Remove_Guillotine(id)
{
	UnSet_BitVar(g_Had_Guillotine, id)
	UnSet_BitVar(g_CanShoot, id)
	UnSet_BitVar(g_InTempingAttack, id)
	UnSet_BitVar(g_Hit, id)
	
	/*
	if(is_user_connected(id) && pev_valid(g_MyGuillotine[id]))
	{
		static Classname[64]; pev(g_MyGuillotine[id], pev_classname, Classname, 63)
		if(equal(Classname, GUILLOTINE_CLASSNAME)) remove_entity(g_MyGuillotine[id])
	}*/

	g_Ammo[id] = 0
}

public HookWeapon(id)
{
	engclient_cmd(id, weapon_guillotine)
	return PLUGIN_HANDLED
}

public Event_CurWeapon(id)
{
	if(!is_alive(id))
		return
		
	static CSWID; CSWID = read_data(2)
	if(CSWID == CSW_GUILLOTINE && Get_BitVar(g_Had_Guillotine, id))
		update_ammo(id, -1, g_Ammo[id])
}

public update_ammo(id, Ammo, BpAmmo)
{
	message_begin(MSG_ONE_UNRELIABLE, g_MsgCurWeapon, _, id)
	write_byte(1)
	write_byte(CSW_GUILLOTINE)
	write_byte(Ammo)
	message_end()
	
	message_begin(MSG_ONE_UNRELIABLE, g_MsgAmmoX, _, id)
	write_byte(10)
	write_byte(BpAmmo)
	message_end()
	
	cs_set_user_bpammo(id, CSW_GUILLOTINE, BpAmmo)
}

public client_PostThink(id)
{
	if(!is_alive(id))
		return
	if(get_player_weapon(id) != CSW_GUILLOTINE || !Get_BitVar(g_Had_Guillotine, id))
		return
	
	if(!Get_BitVar(g_CanShoot, id) && !pev_valid(g_MyGuillotine[id]))
	{
		// Reset Player
		Set_PlayerNextAttack(id, 1.0)
		Set_WeaponIdleTime(id, CSW_GUILLOTINE, 1.0)
		
		Set_WeaponAnim(id, ANIM_LOST)
		Set_BitVar(g_CanShoot, id)
		UnSet_BitVar(g_Hit, id)
		
		set_task(0.95, "Reset_Guillotine", id+TASK_RESET)
	}
}

public fw_UpdateClientData_Post(id, sendweapons, cd_handle)
{
	if(!is_alive(id))
		return FMRES_IGNORED
	if(get_player_weapon(id) != CSW_GUILLOTINE || !Get_BitVar(g_Had_Guillotine, id))
		return FMRES_IGNORED
	
	set_cd(cd_handle, CD_flNextAttack, get_gametime() + 0.001) 
	
	return FMRES_HANDLED
}

public fw_CmdStart(id, uc_handle, seed)
{
	if(!is_alive(id))
		return FMRES_IGNORED
	if(get_player_weapon(id) != CSW_GUILLOTINE || !Get_BitVar(g_Had_Guillotine, id))
		return FMRES_IGNORED
	
	static CurButton; CurButton = get_uc(uc_handle, UC_Buttons)
	
	if(CurButton & IN_ATTACK)
	{
		CurButton &= ~IN_ATTACK
		set_uc(uc_handle, UC_Buttons, CurButton)
		
		HandleShot_Guillotine(id)
	}
	
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
	
	if(equal(model, GUILLOTINE_OLDMODEL))
	{
		static weapon; weapon = find_ent_by_owner(-1, weapon_guillotine, entity)
		
		if(!pev_valid(weapon))
			return FMRES_IGNORED;
		
		if(Get_BitVar(g_Had_Guillotine, iOwner))
		{
			set_pev(weapon, pev_impulse, 1422015)
			set_pev(weapon, pev_iuser1, g_Ammo[iOwner])
			
			engfunc(EngFunc_SetModel, entity, MODEL_W)
			
			Remove_Guillotine(iOwner)
			
			return FMRES_SUPERCEDE
		}
	}

	return FMRES_IGNORED;
}

public fw_EmitSound(id, channel, const sample[], Float:volume, Float:attn, flags, pitch)
{
	if(!is_connected(id))
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
	if(!is_alive(id))
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
	if(!is_alive(id))
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

public fw_Guillotine_Touch(Ent, Touched)
{
	if(!pev_valid(Ent))
		return
		
	static id; id = pev(Ent, pev_owner)
	if(!is_alive(id))
	{
		Guillotine_Broken(Ent)
		return
	}
		
	if(is_connected(Touched))
	{ // Touch Human
		if(!is_alive(Touched))
			return
		if(Get_BitVar(g_Hit, id))
			return
		if(Touched == id)
			return
		if(!get_pcvar_num(g_CvarFriendlyFire))
		{
			if(cs_get_user_team(Touched) == cs_get_user_team(id))
				return
		}
				
		static Float:HeadOrigin[3], Float:HeadAngles[3];
		engfunc(EngFunc_GetBonePosition, Touched, 8, HeadOrigin, HeadAngles);		
				
		static Float:EntOrigin[3]; pev(Ent, pev_origin, EntOrigin)
		
		if(get_distance_f(EntOrigin, HeadOrigin) <= 16.0)
		{
			if(!pev(Ent, pev_return))
			{
				// Set
				Set_BitVar(g_Hit, id)
				Set_WeaponAnim(id, ANIM_EXPECT_FX)
				
				set_pev(Ent, pev_enemy, Touched)
				set_pev(Ent, pev_return, 1)
				set_pev(Ent, pev_movetype, MOVETYPE_FOLLOW)
				set_pev(Ent, pev_velocity, {0.0, 0.0, 0.0})
				set_pev(Ent, pev_fuser1, get_gametime() + GUILLOTINE_HITTIME)
				
				// Animation
				set_pev(Ent, pev_animtime, get_gametime())
				set_pev(Ent, pev_framerate, 5.0)
				set_pev(Ent, pev_sequence, 1)
			} else {
				if(get_gametime() - DAMAGE_DELAY > g_DamageTimeA[id])
				{	
					ExecuteHamB(Ham_TakeDamage, Touched, fm_get_user_weapon_entity(id, CSW_KNIFE), id, float(DAMAGE), DMG_SLASH)
					g_DamageTimeA[id] = get_gametime()
				}
			}
		} else {
			if(get_gametime() - DAMAGE_DELAY > g_DamageTimeA[id])
			{	
				ExecuteHamB(Ham_TakeDamage, Touched, fm_get_user_weapon_entity(id, CSW_KNIFE), id, float(DAMAGE), DMG_SLASH)
				
				// Knockback
				static Float:OriginA[3]; pev(id, pev_origin, OriginA)
				static Float:Origin[3]; pev(Touched, pev_origin, Origin)
				static Float:Velocity[3]; Get_SpeedVector(OriginA, Origin, KNOCKBACK, Velocity)
			
				set_pev(Touched, pev_velocity, Velocity)
				
				g_DamageTimeA[id] = get_gametime()
			}
		}	
	} else { // Touch Wall
		if(!pev(Ent, pev_return))
		{
			set_pev(Ent, pev_velocity, {0.0, 0.0, 0.0})
			
			set_pev(Ent, pev_return, 1)
			emit_sound(Ent, CHAN_BODY, Weapon_Sounds[6], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
			
			// Reset Angles
			static Float:Angles[3]
			pev(id, pev_v_angle, Angles)
			
			Angles[0] *= -1.0
			set_pev(Ent, pev_angles, Angles)
			
			// Check Damage
			static Float:TakeDamage; pev(Touched, pev_takedamage, TakeDamage)
			if(TakeDamage == DAMAGE_YES) ExecuteHamB(Ham_TakeDamage, Touched, fm_get_user_weapon_entity(id, CSW_KNIFE), id, float(DAMAGE), DMG_SLASH)
		} else {
			static Classname[32];
			pev(Touched, pev_classname, Classname, 31)
			
			if(!Get_BitVar(g_Hit, id) && !equal(Classname, "weaponbox")) Guillotine_Broken(Ent)
			return
		}
	}
}

public fw_Guillotine_Think(Ent)
{
	if(!pev_valid(Ent))
		return
		
	static id; id = pev(Ent, pev_owner)
	if(!is_alive(id))
	{
		Guillotine_Broken(Ent)
		return
	}
	if(!Get_BitVar(g_Had_Guillotine, id))
	{
		Guillotine_Broken(Ent)
		return
	}
	
	static Float:LiveTime
	pev(Ent, pev_fuser2, LiveTime)
			
	if(get_gametime() >= LiveTime)
	{
		Guillotine_Broken(Ent)
		return
	}
	
	if(pev(Ent, pev_return)) // Returning to the owner
	{
		static Target; Target = pev(Ent, pev_enemy)
		if(!is_alive(Target))
		{
			UnSet_BitVar(g_Hit, id)
			
			if(pev(Ent, pev_sequence) != 0) set_pev(Ent, pev_sequence, 0)
			if(pev(Ent, pev_movetype) != MOVETYPE_FLY) set_pev(Ent, pev_movetype, MOVETYPE_FLY)
			set_pev(Ent, pev_aiment, 0)
			
			if(entity_range(Ent, id) > 100.0)
			{
				static Float:Origin[3]; pev(id, pev_origin, Origin)
				Hook_The_Fucking_Ent(Ent, Origin, FLYING_SPEED)
			} else {
				Guillotine_Catch(id, Ent)
				return
			}
		} else {
			static Float:fTimeRemove
			pev(Ent, pev_fuser1, fTimeRemove)
			
			if(get_gametime() >= fTimeRemove)
			{
				set_pev(Ent, pev_enemy, 0)
			} else {
				static Float:HeadOrigin[3], Float:HeadAngles[3];
				engfunc(EngFunc_GetBonePosition, Target, 8, HeadOrigin, HeadAngles);
				
				static Float:Velocity[3];
				pev(Ent, pev_velocity, Velocity)

				set_pev(Ent, pev_velocity, {0.0, 0.0, 0.0})
				set_pev(Ent, pev_angles, HeadAngles)
				
				static Float:EnemyOrigin[3]; pev(Target, pev_origin, EnemyOrigin)
				if(get_distance_f(EnemyOrigin, HeadOrigin) <= 24.0) engfunc(EngFunc_SetOrigin, Ent, HeadOrigin)
				else engfunc(EngFunc_SetOrigin, Ent, EnemyOrigin)
	
				if(get_gametime() - DAMAGE_DELAY > g_DamageTimeB[id])
				{	
					// Animation
					if(!pev(Ent, pev_sequence))
					{
						set_pev(Ent, pev_animtime, get_gametime())
						set_pev(Ent, pev_framerate, 5.0)
						set_pev(Ent, pev_sequence, 1)
					}

					set_pdata_int(Target, m_iLastHitGroup, HIT_HEAD, 5)
					ExecuteHamB(Ham_TakeDamage, Target, fm_get_user_weapon_entity(id, CSW_KNIFE), id, float(DAMAGE), DMG_SLASH)
		
					g_DamageTimeB[id] = get_gametime()
				}
				
				// Knockback
				static Float:OriginA[3]; pev(id, pev_origin, OriginA)
				static Float:Origin[3]; pev(Target, pev_origin, Origin)
				static Float:VelocityA[3]; Get_SpeedVector(OriginA, Origin, KNOCKBACK / 5.0, VelocityA)
			
				set_pev(Target, pev_velocity, VelocityA)
			}
		}
	} else {
		if(entity_range(Ent, id) >= MAX_RADIUS)
		{
			set_pev(Ent, pev_velocity, {0.0, 0.0, 0.0})
			set_pev(Ent, pev_return, 1)
		}
	}
	
	set_pev(Ent, pev_nextthink, get_gametime() + 0.05)
}

public Guillotine_Broken(Ent)
{
	static Float:Origin[3];
	
	emit_sound(Ent, CHAN_BODY, Weapon_Sounds[3], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	pev(Ent, pev_origin, Origin)
	
	remove_entity(Ent)

	// Effect
	message_begin(MSG_BROADCAST ,SVC_TEMPENTITY)
	write_byte(TE_EXPLOSION)
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2])
	write_short(g_ExpSprID)	// sprite index
	write_byte(5)	// scale in 0.1's
	write_byte(30)	// framerate
	write_byte(TE_EXPLFLAG_NOSOUND)	// flags
	message_end()
	
	message_begin(MSG_BROADCAST,SVC_TEMPENTITY);
	write_byte(TE_BREAKMODEL)
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2])
	write_coord(64); // size x
	write_coord(64); // size y
	write_coord(64); // size z
	write_coord(random_num(-64,64)); // velocity x
	write_coord(random_num(-64,64)); // velocity y
	write_coord(25); // velocity z
	write_byte(10); // random velocity
	write_short(g_GibModelID); // model index that you want to break
	write_byte(32); // count
	write_byte(25); // life
	write_byte(0x01); // flags: BREAK_GLASS
	message_end();  	
}

public Reset_Guillotine(id)
{
	id -= TASK_RESET
	
	if(!is_alive(id))
		return
	if(!Get_BitVar(g_Had_Guillotine, id))
		return
	Set_BitVar(g_CanShoot, id)
	if(get_player_weapon(id) != CSW_GUILLOTINE)
		return
	
	Set_PlayerNextAttack(id, 0.75)
	Set_WeaponIdleTime(id, CSW_GUILLOTINE, 0.75)
	
	if(g_Ammo[id]) 
	{	
		Set_WeaponAnim(id, ANIM_DRAW)
		PlaySound(id, Weapon_Sounds[0])
	}
}

public Guillotine_Catch(id, Ent)
{
	// Remove Entity
	remove_entity(Ent)
	g_MyGuillotine[id] = -1
	
	// Reset Player
	if(get_player_weapon(id) == CSW_GUILLOTINE && Get_BitVar(g_Had_Guillotine, id))
	{
		g_Ammo[id] = min(g_Ammo[id] + 1, AMMO)
		update_ammo(id, -1, g_Ammo[id])
		
		Create_FakeAttack(id)
		
		Set_PlayerNextAttack(id, 1.0)
		Set_WeaponIdleTime(id, CSW_GUILLOTINE, 1.0)
		
		Set_WeaponAnim(id, ANIM_CATCH)
		Set_BitVar(g_CanShoot, id)
		UnSet_BitVar(g_Hit, id)

		emit_sound(id, CHAN_WEAPON, Weapon_Sounds[0], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	} else {
		emit_sound(id, CHAN_WEAPON, Weapon_Sounds[3], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
		Set_BitVar(g_CanShoot, id)
		UnSet_BitVar(g_Hit, id)
	}
}

public fw_Item_Deploy_Post(Ent)
{
	if(pev_valid(Ent) != 2)
		return
	static Id; Id = get_pdata_cbase(Ent, 41, 4)
	if(get_pdata_cbase(Id, 373) != Ent)
		return
	if(!Get_BitVar(g_Had_Guillotine, Id))
		return
	
	set_pev(Id, pev_viewmodel2, MODEL_V)
	set_pev(Id, pev_weaponmodel2, MODEL_P)
	
	static Valid; Valid = pev_valid(g_MyGuillotine[Id])
	if(g_Ammo[Id]) 
	{	
		Set_WeaponAnim(Id, ANIM_DRAW)
		if(!Valid) PlaySound(Id, Weapon_Sounds[0])
	} else Set_WeaponAnim(Id, ANIM_DRAW_EMPTY)
	
	if(!Valid) Set_BitVar(g_CanShoot, Id)
	else Set_WeaponAnim(Id, ANIM_DRAW_EMPTY)
		
	set_pdata_string(Id, (492) * 4, WEAPON_ANIMEXT, -1 , 20)
}

public fw_Item_AddToPlayer_Post(Ent, id)
{
	if(!pev_valid(Ent))
		return HAM_IGNORED
		
	if(pev(Ent, pev_impulse) == 1422015)
	{
		Set_BitVar(g_Had_Guillotine, id)
		Set_BitVar(g_CanShoot, id)
		
		set_pev(Ent, pev_impulse, 0)
		g_Ammo[id] = pev(Ent, pev_iuser1)
	}
	
	message_begin(MSG_ONE_UNRELIABLE, g_MsgWeaponList, _, id)
	write_string(Get_BitVar(g_Had_Guillotine, id) ? "weapon_guillotine" : "weapon_m249")
	write_byte(3)
	write_byte(200)
	write_byte(-1)
	write_byte(-1)
	write_byte(0)
	write_byte(4)
	write_byte(Get_BitVar(g_Had_Guillotine, id) ? CSW_GUILLOTINE : CSW_M249)
	write_byte(0)
	message_end()			
	
	return HAM_HANDLED	
}

public fw_Weapon_WeaponIdle_Post(iEnt)
{
	if(pev_valid(iEnt) != 2)
		return
	static Id; Id = get_pdata_cbase(iEnt, 41, 4)
	//if(get_pdata_cbase(Id, 373) != iEnt)
	//	/return
	if(!Get_BitVar(g_Had_Guillotine, Id))
		return
		
	if(get_pdata_float(iEnt, 48, 4) <= 0.25)
	{
		if(g_Ammo[Id]) 
		{	
			if(Get_BitVar(g_CanShoot, Id)) Set_WeaponAnim(Id, ANIM_IDLE)
			else {
				if(Get_BitVar(g_Hit, Id)) Set_WeaponAnim(Id, ANIM_EXPECT_FX)
				else Set_WeaponAnim(Id, ANIM_EXPECT)
			}
		} else Set_WeaponAnim(Id, ANIM_IDLE_EMPTY)
		
		set_pdata_float(iEnt, 48, 20.0, 4)
	}	
}

public HandleShot_Guillotine(id)
{
	if(get_pdata_float(id, 83, 5) > 0.0)
		return
	if(g_Ammo[id] <= 0)
		return
	if(!Get_BitVar(g_CanShoot, id))
		return
		
	static Ent; Ent = fm_get_user_weapon_entity(id, CSW_GUILLOTINE)
	if(!pev_valid(Ent)) return		
	
	UnSet_BitVar(g_CanShoot, id)
	Create_FakeAttack(id)
	
	Set_WeaponAnim(id, ANIM_SHOOT)
	emit_sound(id, CHAN_WEAPON, Weapon_Sounds[5], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	
	Create_Guillotine(id)

	Set_PlayerNextAttack(id, 0.5)
	Set_WeaponIdleTime(id, CSW_GUILLOTINE, 0.5)
	
	g_Ammo[id]--
	update_ammo(id, -1, g_Ammo[id])
}

public Create_Guillotine(id)
{
	new iEnt = create_entity("info_target")
	
	static Float:Origin[3], Float:TargetOrigin[3], Float:Velocity[3], Float:Angles[3]
	
	get_weapon_attachment(id, Origin, 0.0)
	Origin[2] -= 10.0
	get_position(id, 1024.0, 0.0, 0.0, TargetOrigin)
	
	pev(id, pev_v_angle, Angles)
	Angles[0] *= -1.0
	
	// set info for ent
	set_pev(iEnt, pev_movetype, MOVETYPE_FLY)
	entity_set_string(iEnt, EV_SZ_classname, GUILLOTINE_CLASSNAME)
	engfunc(EngFunc_SetModel, iEnt, MODEL_S)
	
	set_pev(iEnt, pev_mins, Float:{-1.0, -1.0, -1.0})
	set_pev(iEnt, pev_maxs, Float:{1.0, 1.0, 1.0})
	set_pev(iEnt, pev_origin, Origin)
	set_pev(iEnt, pev_angles, Angles)
	set_pev(iEnt, pev_gravity, 0.01)
	set_pev(iEnt, pev_solid, SOLID_TRIGGER)
	set_pev(iEnt, pev_owner, id)	
	set_pev(iEnt, pev_eteam, get_user_team(id))
	set_pev(iEnt, pev_return, 0)
	set_pev(iEnt, pev_extra, 0)
	set_pev(iEnt, pev_enemy, 0)
	set_pev(iEnt, pev_fuser2, get_gametime() + 8.0)
	
	get_speed_vector(Origin, TargetOrigin, FLYING_SPEED, Velocity)
	set_pev(iEnt, pev_velocity, Velocity)	
	
	set_pev(iEnt, pev_nextthink, get_gametime() + 0.1)
	
	g_MyGuillotine[id] = iEnt
	
	// Animation
	set_pev(iEnt, pev_animtime, get_gametime())
	set_pev(iEnt, pev_framerate, 2.0)
	set_pev(iEnt, pev_sequence, 0)
}

public Create_FakeAttack(id)
{
	static Ent; Ent = fm_get_user_weapon_entity(id, CSW_KNIFE)
	if(!pev_valid(Ent)) return
	
	Set_BitVar(g_InTempingAttack, id)
	ExecuteHamB(Ham_Weapon_PrimaryAttack, Ent)
	
	// Set Real Attack Anim
	static iAnimDesired,  szAnimation[64]

	formatex(szAnimation, charsmax(szAnimation), (pev(id, pev_flags) & FL_DUCKING) ? "crouch_shoot_%s" : "ref_shoot_%s", WEAPON_ANIMEXT2)
	if((iAnimDesired = lookup_sequence(id, szAnimation)) == -1)
		iAnimDesired = 0
	
	set_pev(id, pev_sequence, iAnimDesired)
	UnSet_BitVar(g_InTempingAttack, id)
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

stock PlaySound(id, const sound[])
{
	if(equal(sound[strlen(sound)-4], ".mp3")) client_cmd(id, "mp3 play ^"sound/%s^"", sound)
	else client_cmd(id, "spk ^"%s^"", sound)
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

/*
do_attack(Attacker, Victim, Inflictor, Float:fDamage)
{
	fake_player_trace_attack(Attacker, Victim, fDamage)
	fake_take_damage(Attacker, Victim, fDamage, Inflictor, DMG_SLASH)
}

fake_player_trace_attack(iAttacker, iVictim, &Float:fDamage)
{
	// get fDirection
	static Float:fAngles[3], Float:fDirection[3]
	pev(iAttacker, pev_angles, fAngles)
	angle_vector(fAngles, ANGLEVECTOR_FORWARD, fDirection)
	
	// get fStart
	static Float:fStart[3], Float:fViewOfs[3]
	pev(iAttacker, pev_origin, fStart)
	pev(iAttacker, pev_view_ofs, fViewOfs)
	xs_vec_add(fViewOfs, fStart, fStart)
	
	// get aimOrigin
	static iAimOrigin[3], Float:fAimOrigin[3]
	get_user_origin(iAttacker, iAimOrigin, 3)
	IVecFVec(iAimOrigin, fAimOrigin)
	
	// TraceLine from fStart to AimOrigin
	static ptr; ptr = create_tr2() 
	engfunc(EngFunc_TraceLine, fStart, fAimOrigin, DONT_IGNORE_MONSTERS, iAttacker, ptr)
	static pHit; pHit = get_tr2(ptr, TR_pHit)
	//static iHitgroup; iHitgroup = get_tr2(ptr, TR_iHitgroup)
	static Float:fEndPos[3]
	get_tr2(ptr, TR_vecEndPos, fEndPos)

	// get target & body at aiming
	static iTarget, iBody
	get_user_aiming(iAttacker, iTarget, iBody)
	iBody = HIT_HEAD
	
	
	// if aiming find target is iVictim then update iHitgroup
	if(iTarget == iVictim)
	{
		//iHitgroup = iBody
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
		static iAngleToVictim; iAngleToVictim = get_angle_to_target(iAttacker, fVicOrigin)
		iAngleToVictim = abs(iAngleToVictim)
		static Float:fDis; fDis = 2.0 * get_distance_f(fStart, fAimInVictim) * floatsin( float(iAngleToVictim) * 0.5, degrees )
		static Float:fVicSize[3]
		pev(iVictim, pev_size , fVicSize)
		if ( fDis <= fVicSize[0] * 0.5 )
		{
			// TraceLine from fStart to aimOrigin in iVictim
			static ptr2; ptr2 = create_tr2() 
			engfunc(EngFunc_TraceLine, fStart, fAimInVictim, DONT_IGNORE_MONSTERS, iAttacker, ptr2)
			static pHit2; pHit2 = get_tr2(ptr2, TR_pHit)
			static iHitgroup2; iHitgroup2 = get_tr2(ptr2, TR_iHitgroup)
			
			// if ptr2 find target is iVictim
			if ( pHit2 == iVictim && (iHitgroup2 != HIT_HEAD || fDis <= fVicSize[0] * 0.25) )
			{
				pHit = iVictim
				//iHitgroup = iHitgroup2
				get_tr2(ptr2, TR_vecEndPos, fEndPos)
			}
			
			free_tr2(ptr2)
		}
		
		// if pHit still not is iVictim then set default HitGroup
		if (pHit != iVictim)
		{
			// set default iHitgroup
			//iHitgroup = HIT_GENERIC
			
			static ptr3; ptr3 = create_tr2() 
			engfunc(EngFunc_TraceLine, fStart, fVicOrigin, DONT_IGNORE_MONSTERS, iAttacker, ptr3)
			get_tr2(ptr3, TR_vecEndPos, fEndPos)
			
			// free ptr3
			free_tr2(ptr3)
		}
	}
	
	static Float:HeadOrigin[3], Float:HeadAngles[3];
	engfunc(EngFunc_GetBonePosition, iVictim, 8, HeadOrigin, HeadAngles)
	
	// set new Hit & Hitgroup & EndPos
	set_tr2(ptr, TR_pHit, iVictim)
	set_tr2(ptr, TR_iHitgroup, HIT_HEAD)
	set_tr2(ptr, TR_vecEndPos, HeadOrigin)

	// ExecuteHam
	fake_trake_attack(iAttacker, iVictim, fDamage, fDirection, ptr, DMG_SLASH)
	
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
	static Float:fOrigin[3], iAimOrigin[3], Float:fAimOrigin[3], Float:fV1[3]
	pev(id, pev_origin, fOrigin)
	get_user_origin(id, iAimOrigin, 3) // end position from eyes
	IVecFVec(iAimOrigin, fAimOrigin)
	xs_vec_sub(fAimOrigin, fOrigin, fV1)
	
	static Float:fV2[3]
	xs_vec_sub(fTarget, fOrigin, fV2)
	
	static iResult; iResult = get_angle_between_vectors(fV1, fV2)
	
	if (TargetSize > 0.0)
	{
		static Float:fTan; fTan = TargetSize / get_distance_f(fOrigin, fTarget)
		static fAngleToTargetSize; fAngleToTargetSize = floatround( floatatan(fTan, degrees) )
		iResult -= (iResult > 0) ? fAngleToTargetSize : -fAngleToTargetSize
	}
	
	return iResult
}

stock get_angle_between_vectors(const Float:fV1[3], const Float:fV2[3])
{
	static Float:fA1[3], Float:fA2[3]
	engfunc(EngFunc_VecToAngles, fV1, fA1)
	engfunc(EngFunc_VecToAngles, fV2, fA2)
	
	static iResult; iResult = floatround(fA1[1] - fA2[1])
	iResult = iResult % 360
	iResult = (iResult > 180) ? (iResult - 360) : iResult
	
	return iResult
}*/

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
