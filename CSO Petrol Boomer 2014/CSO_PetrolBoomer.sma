#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <cstrike>
#include <fun>
#include <maths>

#define PLUGIN "[CSO] Weapon: Petrol Boomer"
#define VERSION "1.0"
#define AUTHOR "Dias"

#define CSW_PETROLBOOMER CSW_M249
#define weapon_petrolboomer "weapon_m249"

#define MAGAZINE 20
#define MOLOTOV_SPEED 750.0

#define WEAPON_ANIMEXT "rifle"
#define WEAPON_OLDWMODEL "models/w_m249.mdl"
#define WEAPON_SECRETCODE 1972014

#define DAMAGE_EXPLOSION 200 // 500 for Zombie
#define DAMAGE_BURN 20 // 100 for Zombie
#define DAMAGE_RADIUS 100.0

#define TIME_DRAW 0.75
#define TIME_RELOAD 4.0

#define FIRE_CLASSNAME "petrolfire"
#define FIRE2_CLASSNAME "smallfire"
#define MOLOTOV_CLASSNAME "molotov"

#define MODEL_V "models/v_petrolboomer.mdl"
#define MODEL_P "models/p_petrolboomer.mdl"
#define MODEL_W "models/w_petrolboomer.mdl"
#define MODEL_S "models/s_petrolboomer.mdl"

new const WeaponSounds[6][] = 
{
	"weapons/petrolboomer_shoot.wav",
	"weapons/petrolboomer_explosion.wav",
	"weapons/petrolboomer_idle.wav",
	"weapons/petrolboomer_reload.wav",
	"weapons/petrolboomer_draw.wav",
	"weapons/petrolboomer_draw_empty.wav"
}

new const WeaponResources[6][] = 
{
	"sprites/flame.spr",
	"sprites/640hud13_2.spr",
	"sprites/640hud108_2.spr",
	"sprites/640hud109_2.spr",
	"sprites/scope_grenade.spr",
	"sprites/weapon_petrolboomer.txt"
}

enum
{
	ANIM_IDLE = 0,
	ANIM_SHOOT,
	ANIM_RELOAD,
	ANIM_DRAW,
	ANIM_DRAW_EMPTY,
	ANIM_IDLE_EMPTY
}

enum
{
	TEAM_T = 1,
	TEAM_CT
}

// MACROS
#define Get_BitVar(%1,%2) (%1 & (1 << (%2 & 31)))
#define Set_BitVar(%1,%2) %1 |= (1 << (%2 & 31))
#define UnSet_BitVar(%1,%2) %1 &= ~(1 << (%2 & 31))

new g_Had_PB
new g_Molotov[33], g_FireEnt[33], g_InTempingAttack
new g_MsgCurWeapon, g_MsgAmmoX, g_MsgWeaponList
new g_ExpSprId, g_MaxPlayers, spr_trail

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	register_event("CurWeapon", "Event_CurWeapon", "be", "1=1")
	
	register_forward(FM_SetModel, "fw_SetModel")
	register_forward(FM_UpdateClientData, "fw_UpdateClientData_Post", 1)
	register_forward(FM_CmdStart, "fw_CmdStart")	
	register_forward(FM_EmitSound, "fw_EmitSound")
	register_forward(FM_TraceLine, "fw_TraceLine")
	register_forward(FM_TraceHull, "fw_TraceHull")			
	
	register_think(FIRE_CLASSNAME, "fw_FireThink")
	register_think(FIRE2_CLASSNAME, "fw_Fire2Think")
	register_touch(MOLOTOV_CLASSNAME, "*", "fw_Touch_Molotov")
	
	RegisterHam(Ham_Item_AddToPlayer, weapon_petrolboomer, "fw_Item_AddToPlayer_Post", 1)
	RegisterHam(Ham_Item_Deploy, weapon_petrolboomer, "fw_Item_Deploy_Post", 1)
	RegisterHam(Ham_Weapon_WeaponIdle, weapon_petrolboomer, "fw_Weapon_WeaponIdle_Post", 1)
	
	g_MsgCurWeapon = get_user_msgid("CurWeapon")
	g_MsgAmmoX = get_user_msgid("AmmoX")
	g_MsgWeaponList = get_user_msgid("WeaponList")
	
	g_MaxPlayers = get_maxplayers()

	register_clcmd("say /get", "Get_PB")
}

public plugin_precache()
{
	precache_model(MODEL_V)
	precache_model(MODEL_P)
	precache_model(MODEL_W)
	precache_model(MODEL_S)
	
	for(new i = 0; i < sizeof(WeaponSounds); i++)
		precache_sound(WeaponSounds[i])
	for(new i = 0; i < sizeof(WeaponResources); i++)
	{
		if(i == 5) precache_generic(WeaponResources[i])
		else precache_model(WeaponResources[i])
	}
	
	g_ExpSprId = precache_model("sprites/zerogxplode.spr")
	spr_trail = engfunc(EngFunc_PrecacheModel, "sprites/laserbeam.spr")
}

public Get_PB(id)
{
	Set_BitVar(g_Had_PB, id)
	g_Molotov[id] = MAGAZINE
	
	give_item(id, weapon_petrolboomer)
	UpdateAmmo(id, CSW_PETROLBOOMER, 3, -1, g_Molotov[id])
}

public Remove_PB(id)
{
	UnSet_BitVar(g_Had_PB, id)
	g_Molotov[id] = 0
}

public UpdateAmmo(id, CSWID, AmmoID, Ammo, BpAmmo)
{
	message_begin(MSG_ONE_UNRELIABLE, g_MsgCurWeapon, _, id)
	write_byte(1)
	write_byte(CSWID)
	write_byte(Ammo)
	message_end()
	
	message_begin(MSG_ONE_UNRELIABLE, g_MsgAmmoX, _, id)
	write_byte(AmmoID)
	write_byte(BpAmmo)
	message_end()
	
	cs_set_user_bpammo(id, CSWID, BpAmmo)
}

public Event_CurWeapon(id)
{
	static CSWID; CSWID = read_data(2)
	if(CSWID != CSW_PETROLBOOMER) 
	{
		if(pev_valid(g_FireEnt[id])) set_pev(g_FireEnt[id], pev_renderamt, 0.0)
		return
	}
	if(!Get_BitVar(g_Had_PB, id)) return
	
	UpdateAmmo(id, CSW_PETROLBOOMER, 3, -1, g_Molotov[id])
}

public fw_SetModel(entity, model[])
{
	if(!pev_valid(entity))
		return FMRES_IGNORED
	
	static szClassName[33]
	pev(entity, pev_classname, szClassName, charsmax(szClassName))
	
	if(!equal(szClassName, "weaponbox"))
		return FMRES_IGNORED
	
	static id; id = pev(entity, pev_owner)
	
	if(equal(model, WEAPON_OLDWMODEL))
	{
		static weapon
		weapon = fm_find_ent_by_owner(-1, weapon_petrolboomer, entity)
		
		if(!pev_valid(weapon))
			return FMRES_IGNORED
		
		if(Get_BitVar(g_Had_PB, id))
		{
			set_pev(weapon, pev_impulse, WEAPON_SECRETCODE)
			set_pev(weapon, pev_iuser1, g_Molotov[id])
			
			engfunc(EngFunc_SetModel, entity, MODEL_W)
			Remove_PB(id)
			
			return FMRES_SUPERCEDE
		}
	}

	return FMRES_IGNORED
}

public fw_UpdateClientData_Post(id, sendweapons, cd_handle)
{
	if(get_user_weapon(id) != CSW_PETROLBOOMER || !Get_BitVar(g_Had_PB, id))
		return FMRES_IGNORED
	
	set_cd(cd_handle, CD_flNextAttack, get_gametime() + 0.001) 
	
	return FMRES_HANDLED
}

public fw_CmdStart(id, uc_handle, seed)
{
	if(get_user_weapon(id) != CSW_PETROLBOOMER || !Get_BitVar(g_Had_PB, id))
		return
	
	static CurButton; CurButton = get_uc(uc_handle, UC_Buttons)
	if(CurButton & IN_ATTACK)
	{
		CurButton &= ~IN_ATTACK
		set_uc(uc_handle, UC_Buttons, CurButton)
		
		PetrolBoomer_AttackHandle(id)
	}
	
	return 
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

public fw_Touch_Molotov(Ent, Id)
{
	if(!pev_valid(Ent))
		return
	if(pev(Ent, pev_movetype) == MOVETYPE_NONE)
		return
		
	// Remove Ent
	set_pev(Ent, pev_movetype, MOVETYPE_NONE)
	set_pev(Ent, pev_solid, SOLID_NOT)
	
	engfunc(EngFunc_SetModel, Ent, "")
	emit_sound(Ent, CHAN_BODY, WeaponSounds[1], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	
	Create_GroundFire(Ent)
	set_task(1.5, "Remove_Entity", Ent)	
	
	if(is_user_alive(Id)) // Wall
	{ // Player
		static Attacker; Attacker = pev(Ent, pev_iuser1)
		if(!is_user_connected(Attacker) || Attacker == Id)
		{
			engfunc(EngFunc_RemoveEntity, Ent)
			return
		}
		
		if(cs_get_user_team(Id) == Get_ArrowTeam(Ent))
			return
			
		ExecuteHamB(Ham_TakeDamage, Id, 0, pev(Ent, pev_owner), float(DAMAGE_EXPLOSION), DMG_BLAST)
	}
}

public Create_GroundFire(Ent)
{
	static Float:Origin[3]; pev(Ent, pev_origin, Origin)
	
	message_begin(MSG_BROADCAST ,SVC_TEMPENTITY)
	write_byte(TE_EXPLOSION)
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2])
	write_short(g_ExpSprId)	// sprite index
	write_byte(30)	// scale in 0.1's
	write_byte(30)	// framerate
	write_byte(0)	// flags
	message_end()
	
	// Put decal on "world" (a wall)
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_WORLDDECAL)
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2])
	write_byte(random_num(46, 48))
	message_end()	
	
	static Float:FireOrigin[12][3]
	
	get_position(Ent, 64.0, 0.0, 0.0, FireOrigin[0])
	get_position(Ent, 0.0, 0.0, 0.0, FireOrigin[1])
	get_position(Ent, -64.0, 0.0, 0.0, FireOrigin[2])
	
	get_position(Ent, 32.0, 16.0, 0.0, FireOrigin[3])
	get_position(Ent, 0.0, 32.0, 0.0, FireOrigin[4])
	get_position(Ent, -32.0, 16.0, 0.0, FireOrigin[5])
	
	get_position(Ent, 16.0, -16.0, 0.0, FireOrigin[6])
	get_position(Ent, 0.0, -32.0, 0.0, FireOrigin[7])
	get_position(Ent, -16.0, -16.0, 0.0, FireOrigin[8])
	
	get_position(Ent, 8.0, -16.0, 0.0, FireOrigin[9])
	get_position(Ent, 0.0, -32.0, 0.0, FireOrigin[10])
	get_position(Ent, -8.0, -16.0, 0.0, FireOrigin[11])	
	
	for(new i = 0; i < 12; i++)
		Create_SmallFire(FireOrigin[i], Ent)
}

public Create_SmallFire(Float:Origin[3], Master)
{
	static Ent; Ent = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "env_sprite"))
	if(!pev_valid(Ent)) return

	// Set info for ent
	set_pev(Ent, pev_movetype, MOVETYPE_PUSHSTEP)
	set_pev(Ent, pev_rendermode, kRenderTransAdd)
	set_pev(Ent, pev_renderamt, 100.0)
	set_pev(Ent, pev_scale, random_float(0.75, 1.75))
	set_pev(Ent, pev_nextthink, get_gametime() + 0.05)
	
	set_pev(Ent, pev_classname, FIRE2_CLASSNAME)
	engfunc(EngFunc_SetModel, Ent, WeaponResources[0])
	
	set_pev(Ent, pev_mins, Float:{-16.0, -16.0, -6.0})
	set_pev(Ent, pev_maxs, Float:{16.0, 16.0, 36.0})
	
	set_pev(Ent, pev_origin, Origin)
	set_pev(Ent, pev_iuser2, pev(Master, pev_iuser2))
	
	set_pev(Ent, pev_gravity, 1.0)
	set_pev(Ent, pev_solid, SOLID_TRIGGER)
	set_pev(Ent, pev_frame, 0.0)
	
	set_pev(Ent, pev_fuser1, get_gametime() + 10.0)
}

public Remove_Entity(Ent)
{
	if(pev_valid(Ent)) remove_entity(Ent)
}

public PetrolBoomer_AttackHandle(id)
{
	if(get_pdata_float(id, 83, 5) > 0.0)
		return
	if(!g_Molotov[id])
	{
		set_pdata_float(id, 83, 1.0, 5)
		Set_Weapon_Anim(id, ANIM_IDLE_EMPTY)
		
		return
	}
		
	g_Molotov[id]--
	UpdateAmmo(id, CSW_PETROLBOOMER, 3, -1, g_Molotov[id])

	Create_FakeAttack(id)
	
	Set_Weapon_Anim(id, ANIM_SHOOT)
	set_task(0.5, "ReloadAnim", id)
	
	emit_sound(id, CHAN_WEAPON, WeaponSounds[0], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	
	if(pev_valid(g_FireEnt[id])) set_pev(g_FireEnt[id], pev_renderamt, 0.0)
	
	Create_Molotov(id)
	Make_Push(id)
	
	Set_Player_NextAttack(id, TIME_RELOAD)
	Set_Weapon_TimeIdle(id, CSW_PETROLBOOMER, TIME_RELOAD)
}

public ReloadAnim(id)
{
	Set_Weapon_Anim(id, ANIM_RELOAD)
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

public Make_Push(id)
{
	static Float:VirtualVec[3]
	VirtualVec[0] = random_float(-4.0, -7.0)
	VirtualVec[1] = random_float(1.0, -1.0)
	VirtualVec[2] = 0.0	
	
	set_pev(id, pev_punchangle, VirtualVec)		
}

public Create_Molotov(id)
{
	static Float:StartOrigin[3], Float:EndOrigin[3], Float:Angles[3]
	
	get_position(id, 48.0, 8.0, 5.0, StartOrigin)
	get_position(id, 1024.0, 0.0, 0.0, EndOrigin)
	pev(id, pev_v_angle, Angles)
	
	Angles[0] *= -1
	
	static Molotov; Molotov = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "env_sprite"))
	if(!pev_valid(Molotov)) return
	
	set_pev(Molotov, pev_movetype, MOVETYPE_PUSHSTEP)
	set_pev(Molotov, pev_iuser1, id) // Better than pev_owner
	set_pev(Molotov, pev_iuser2, Get_SpecialTeam(id, cs_get_user_team(id)))
	set_pev(Molotov, pev_iuser3, 0)
	set_pev(Molotov, pev_iuser4, 0)
	
	entity_set_string(Molotov, EV_SZ_classname, MOLOTOV_CLASSNAME)
	engfunc(EngFunc_SetModel, Molotov, MODEL_S)
	set_pev(Molotov, pev_mins, Float:{-1.0, -1.0, -1.0})
	set_pev(Molotov, pev_maxs, Float:{1.0, 1.0, 1.0})
	set_pev(Molotov, pev_origin, StartOrigin)
	set_pev(Molotov, pev_angles, Angles)
	set_pev(Molotov, pev_gravity, 1.0)
	set_pev(Molotov, pev_solid, SOLID_BBOX)
	
	set_pev(Molotov, pev_nextthink, get_gametime() + 0.1)
	set_pev(g_FireEnt[id], pev_iuser3, 1)
	
	set_pev(g_FireEnt[id], pev_movetype, MOVETYPE_FOLLOW)
	set_pev(g_FireEnt[id], pev_aiment, Molotov)
	set_pev(g_FireEnt[id], pev_renderamt, 100.0)
	
	static Float:Velocity[3]
	get_speed_vector(StartOrigin, EndOrigin, MOLOTOV_SPEED, Velocity)
	set_pev(Molotov, pev_velocity, Velocity)
	
	// Make a Beam
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_BEAMFOLLOW)
	write_short(Molotov) // entity
	write_short(spr_trail) // sprite
	write_byte(20)  // life
	write_byte(4)  // width
	write_byte(200) // r
	write_byte(200);  // g
	write_byte(200);  // b
	write_byte(200); // brightness
	message_end();
}

public Get_SpecialTeam(Ent, CsTeams:Team)
{
	if(Team == CS_TEAM_T) return TEAM_T
	else if(Team == CS_TEAM_CT) return TEAM_CT
	
	return 0
}

public fw_FireThink(iEnt)
{
	if(!pev_valid(iEnt)) 
		return
	
	static Owner; Owner = pev(iEnt, pev_owner)
	if(!is_user_alive(Owner)) 
	{
		set_pev(iEnt, pev_renderamt, 100.0)
		return
	}
	
	static Float:fFrame; pev(iEnt, pev_frame, fFrame)

	fFrame += random_float(0.5, 1.0)
	if(fFrame >= 14.0) fFrame = 0.0

	set_pev(iEnt, pev_frame, fFrame)
	set_pev(iEnt, pev_nextthink, halflife_time() + 0.05)
	
	if(!pev(iEnt, pev_iuser3))
	{
		static Float:Origin[3]
		get_position(Owner, 48.0, 8.0, 5.0, Origin)
		
		set_pev(iEnt, pev_origin, Origin)
	}
}

public fw_Fire2Think(iEnt)
{
	if(!pev_valid(iEnt)) 
		return
	
	static Float:fFrame; pev(iEnt, pev_frame, fFrame)

	fFrame += random_float(0.5, 1.0)
	if(fFrame >= 14.0) fFrame = 0.0

	set_pev(iEnt, pev_frame, fFrame)
	set_pev(iEnt, pev_nextthink, halflife_time() + 0.05)
	
	static NewHealth
	if(get_gametime() - 1.0 > pev(iEnt, pev_fuser2))
	{
		for(new i = 0; i < g_MaxPlayers; i++)
		{
			if(!is_user_alive(i))
				continue
			if(entity_range(iEnt, i) > DAMAGE_RADIUS)
				continue
			if(cs_get_user_team(i) == Get_ArrowTeam(iEnt))
				continue

			NewHealth = get_user_health(i) - (DAMAGE_BURN / 5)
			set_user_health(i, NewHealth)
		}
		
		set_pev(iEnt, pev_fuser2, get_gametime())
	}	
	
	if(get_gametime() >= pev(iEnt, pev_fuser1))
	{
		remove_entity(iEnt)
	}
}

public fw_Item_AddToPlayer_Post(Ent, Id)
{
	if(pev(Ent, pev_impulse) == WEAPON_SECRETCODE)
	{
		Set_BitVar(g_Had_PB, Id)
		
		g_Molotov[Id] = pev(Ent, pev_iuser1)
		UpdateAmmo(Id, CSW_PETROLBOOMER, 3, -1, g_Molotov[Id])
		
		set_pev(Ent, pev_impulse, 0)
	}			
	
	message_begin(MSG_ONE_UNRELIABLE, g_MsgWeaponList, _, Id)
	write_string((Get_BitVar(g_Had_PB, Id) ? "weapon_petrolboomer" : weapon_petrolboomer))
	write_byte(3)
	write_byte(200)
	write_byte(-1)
	write_byte(-1)
	write_byte(0)
	write_byte(4)
	write_byte(CSW_PETROLBOOMER)
	write_byte(0)
	message_end()
}

public fw_Item_Deploy_Post(Ent)
{
	if(!pev_valid(Ent))
		return
		
	static Id; Id = get_pdata_cbase(Ent, 41, 4)
	if(!Get_BitVar(g_Had_PB, Id))
		return
		
	set_pev(Id, pev_viewmodel2, MODEL_V)
	set_pev(Id, pev_weaponmodel2, MODEL_P)
	
	set_pdata_string(Id, (492) * 4, WEAPON_ANIMEXT, -1 , 20)
	
	Set_Weapon_TimeIdle(Id, CSW_PETROLBOOMER, TIME_DRAW + 0.5)
	Set_Player_NextAttack(Id, TIME_DRAW)
	
	Set_Weapon_Anim(Id, g_Molotov[Id] ? ANIM_DRAW : ANIM_DRAW_EMPTY)
	UpdateAmmo(Id, CSW_PETROLBOOMER, 3, -1, g_Molotov[Id])
	
	if(!pev_valid(g_FireEnt[Id])) // Create
	{
		static Ent; Ent = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "env_sprite"))
		if(!pev_valid(Ent)) return
		
		g_FireEnt[Id] = Ent
		
		static Float:Origin[3], Float:Angles[3]
		engfunc(EngFunc_GetAttachment, Id, 0, Origin, Angles)
		
		// Set info for ent
		set_pev(Ent, pev_movetype, MOVETYPE_FLY)
		set_pev(Ent, pev_rendermode, kRenderTransAdd)
		set_pev(Ent, pev_renderamt, 0.0)
		set_pev(Ent, pev_scale, 0.25)
		set_pev(Ent, pev_nextthink, get_gametime() + 0.05)
		
		set_pev(Ent, pev_classname, FIRE_CLASSNAME)
		engfunc(EngFunc_SetModel, Ent, WeaponResources[0])
		
		set_pev(Ent, pev_mins, Float:{-1.0, -1.0, -1.0})
		set_pev(Ent, pev_maxs, Float:{1.0, 1.0, 1.0})
		
		set_pev(Ent, pev_origin, Origin)
		
		set_pev(Ent, pev_gravity, 0.01)
		set_pev(Ent, pev_solid, SOLID_NOT)
		set_pev(Ent, pev_frame, 0.0)
		set_pev(Ent, pev_owner, Id)
	} else { // Activate
		static Ent; Ent = g_FireEnt[Id]
		set_pev(Ent, pev_renderamt, 0.0)
	}
}

public fw_Weapon_WeaponIdle_Post(Ent)
{
	if(!pev_valid(Ent))
		return
		
	static Id; Id = get_pdata_cbase(Ent, 41, 4)
	if(!Get_BitVar(g_Had_PB, Id))
		return
		
	if(get_pdata_float(Ent, 48, 4) <= 0.1) 
	{
		Set_Weapon_Anim(Id, g_Molotov[Id] ? ANIM_IDLE : ANIM_IDLE_EMPTY)
		set_pdata_float(Ent, 48, 20.0, 4)
		
		if(pev_valid(g_FireEnt[Id])) 
		{
			set_pev(g_FireEnt[Id], pev_iuser3, 0)
			set_pev(g_FireEnt[Id], pev_movetype, MOVETYPE_FLY)
			set_pev(g_FireEnt[Id], pev_aiment, 0)
			
			if(g_Molotov[Id]) set_pev(g_FireEnt[Id], pev_renderamt, 100.0)
			else set_pev(g_FireEnt[Id], pev_renderamt, 0.0)
		}
	}
	
	return
}

public CsTeams:Get_ArrowTeam(Ent)
{
	if(pev(Ent, pev_iuser2) == TEAM_T) return CS_TEAM_T
	else if(pev(Ent, pev_iuser2) == TEAM_CT) return CS_TEAM_CT
	
	return CS_TEAM_UNASSIGNED
}

stock get_speed_vector(const Float:origin1[3],const Float:origin2[3],Float:speed, Float:new_velocity[3])
{
	new_velocity[0] = origin2[0] - origin1[0]
	new_velocity[1] = origin2[1] - origin1[1]
	new_velocity[2] = origin2[2] - origin1[2]
	static Float:num; num = floatsqroot(speed*speed / (new_velocity[0]*new_velocity[0] + new_velocity[1]*new_velocity[1] + new_velocity[2]*new_velocity[2]))
	new_velocity[0] *= num
	new_velocity[1] *= num
	new_velocity[2] *= num
	
	return 1;
}

stock Set_Weapon_Anim(id, WeaponAnim)
{
	set_pev(id, pev_weaponanim, WeaponAnim)
	
	message_begin(MSG_ONE_UNRELIABLE, SVC_WEAPONANIM, {0, 0, 0}, id)
	write_byte(WeaponAnim)
	write_byte(pev(id, pev_body))
	message_end()
}

stock Set_Weapon_TimeIdle(id, WeaponId ,Float:TimeIdle)
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
