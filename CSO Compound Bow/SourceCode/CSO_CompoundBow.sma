#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <cstrike>

#define PLUGIN "[CSO] Weapon: Compound Bow"
#define VERSION "1.0"
#define AUTHOR "Dias Leon"

// =========== Resources Config
#define V_MODEL "models/v_bow.mdl"
#define P_MODEL "models/p_bow.mdl"
#define P_MODEL_EMPTY "models/p_bow_empty.mdl"
#define W_MODEL "models/w_bow.mdl"

#define ARROW_MODEl "models/arrow.mdl"

new const WeaponSounds[7][] =
{
	"weapons/bow_shoot1.wav",
	"weapons/bow_charge_shoot1_empty.wav",
	"weapons/bow_charge_shoot2.wav",
	"weapons/bow_draw.wav",
	"weapons/bow_charge_start1.wav",
	"weapons/bow_charge_start2.wav",
	"weapons/bow_charge_finish1.wav"
}

new const WeaponResources[3][] =
{
	"sprites/weapon_bow.txt",
	"sprites/640hud12_2.spr",
	"sprites/640hud98_2.spr"
}

enum
{
	BOW_ANIM_IDLE = 0,
	BOW_ANIM_IDLE_EMPTY,
	BOW_ANIM_SHOOT1, // 0.45
	BOW_ANIM_SHOOT1_EMPTY,
	BOW_ANIM_DRAW,
	BOW_ANIM_DRAW_EMPTY,
	BOW_ANIM_CHARGE_START, // 0.5
	BOW_ANIM_CHARGE_FINISH, // 0.35
	BOW_ANIM_CHARGE_IDLE1, // 0.35
	BOW_ANIM_CHARGE_IDLE2, // 0.35
	BOW_ANIM_CHARGE_SHOOT1, // 1.3
	BOW_ANIM_CHARGE_SHOOT1_EMPTY, // 0.6
	BOW_ANIM_CHARGE_SHOOT2, // 1.3
	BOW_ANIM_CHARGE_SHOOT2_EMPTY // 0.6
}

// =========== Main Config
#define CSW_BOW CSW_M4A1
#define weapon_bow "weapon_m4a1"
#define BOW_AMMOID 4

#define ARROW_DEFAULT 60
#define ARROW_CLASSNAME "arrow"
#define ARROW_SPEED 2000.0

#define TIME_DRAW 0.75
#define TIME_RELOADA 0.45
#define TIME_RELOADB 1.25
#define TIME_CHARGE 0.5

#define DAMAGE_A 70
#define DAMAGE_B 140

#define WEAPON_SECRETCODE 3102013 // Create Date
#define WEAPON_ANIMEXT "carbine"
#define WEAPON_OLDWMODEL "models/w_m4a1.mdl"

// =========== WeaponList Config
#define WL_NAME "weapon_bow"
#define WL_PRIAMMOID 4
#define WL_PRIAMMOMAX 60 // 30
#define WL_SECAMMOID -1
#define WL_SECAMMOIDMAX -1
#define WL_SLOTID 0
#define WL_NUMINSLOT 6
#define WL_FLAG 0

// MACROS
#define Get_BitVar(%1,%2) (%1 & (1 << (%2 & 31)))
#define Set_BitVar(%1,%2) %1 |= (1 << (%2 & 31))
#define UnSet_BitVar(%1,%2) %1 &= ~(1 << (%2 & 31))

enum
{
	TEAM_T = 1,
	TEAM_CT
}

enum
{
	WEAPON_NONE = 0,
	WEAPON_STARTCHARGING,
	WEAPON_WAITCHARGING,
	WEAPON_CHARGING,
	WEAPON_FINISHCHARGING
}

// Vars
new g_Had_CompoundBow, g_InTempingAttack, g_BowArrow[33], g_WeaponState[33], Float:g_TimeCharge[33]
new g_MsgCurWeapon, g_MsgAmmoX, g_MsgWeaponList
new g_SprId_LaserBeam

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	register_event("CurWeapon", "Event_CurWeapon", "be", "1=1")
	
	register_think(ARROW_CLASSNAME, "fw_Think_Arrow")
	register_touch(ARROW_CLASSNAME, "*", "fw_Touch_Arrow")
	
	register_forward(FM_UpdateClientData, "fw_UpdateClientData_Post", 1)
	register_forward(FM_CmdStart, "fw_CmdStart")
	register_forward(FM_SetModel, "fw_SetModel")	
	register_forward(FM_EmitSound, "fw_EmitSound")
	register_forward(FM_TraceLine, "fw_TraceLine")
	register_forward(FM_TraceHull, "fw_TraceHull")		
	
	RegisterHam(Ham_Item_AddToPlayer, weapon_bow, "fw_Item_AddToPlayer_Post", 1)
	RegisterHam(Ham_Item_Deploy, weapon_bow, "fw_Item_Deploy_Post", 1)
	RegisterHam(Ham_Weapon_WeaponIdle, weapon_bow, "fw_Weapon_WeaponIdle_Post", 1)
	
	g_MsgCurWeapon = get_user_msgid("CurWeapon")
	g_MsgAmmoX = get_user_msgid("AmmoX")
	g_MsgWeaponList = get_user_msgid("WeaponList")
	
	register_clcmd("admin_get_bow", "Get_CompoundBow")
	register_clcmd(WL_NAME, "WeaponList_Hook")
}

public plugin_precache()
{
	engfunc(EngFunc_PrecacheModel, V_MODEL)
	engfunc(EngFunc_PrecacheModel, P_MODEL)
	engfunc(EngFunc_PrecacheModel, P_MODEL_EMPTY)
	engfunc(EngFunc_PrecacheModel, W_MODEL)
	engfunc(EngFunc_PrecacheModel, ARROW_MODEl)
	
	new i
	for(i = 0; i < sizeof(WeaponSounds); i++)
		engfunc(EngFunc_PrecacheSound, WeaponSounds[i])
	for(i = 0; i < sizeof(WeaponResources); i++)
	{
		if(i == 0) engfunc(EngFunc_PrecacheGeneric, WeaponResources[i])
		else engfunc(EngFunc_PrecacheModel, WeaponResources[i])
	}
	
	g_SprId_LaserBeam = engfunc(EngFunc_PrecacheModel, "sprites/laserbeam.spr")
}

public Get_CompoundBow(id)
{
	if(!is_user_alive(id))
		return
		
	Set_BitVar(g_Had_CompoundBow, id)
	g_BowArrow[id] = ARROW_DEFAULT
	g_WeaponState[id] = WEAPON_NONE
	
	fm_give_item(id, weapon_bow)
	UpdateAmmo(id, CSW_BOW, BOW_AMMOID, -1, g_BowArrow[id])
}

public Remove_CompoundBow(id)
{
	UnSet_BitVar(g_Had_CompoundBow, id)
	g_BowArrow[id] = 0
}

public WeaponList_Hook(id)
{
	engclient_cmd(id, weapon_bow)
	return PLUGIN_HANDLED
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
	if(CSWID != CSW_BOW) return
	if(!Get_BitVar(g_Had_CompoundBow, id)) return
	
	UpdateAmmo(id, CSW_BOW, BOW_AMMOID, -1, g_BowArrow[id])
}

public fw_Think_Arrow(Ent)
{
	if(!pev_valid(Ent))
		return
	if(pev(Ent, pev_iuser4))
	{
		engfunc(EngFunc_RemoveEntity, Ent)
		return
	}
	static Id; Id = pev(Ent, pev_iuser1)
	if(!is_user_connected(Id))	
		return

	if(!pev(Ent, pev_iuser3))
	{
		if(entity_range(Ent, Id) < 250.0)
		{
			set_pev(Ent, pev_nextthink, get_gametime() + 0.1)
			return
		}

		message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
		write_byte(TE_BEAMFOLLOW)
		write_short(Ent)
		write_short(g_SprId_LaserBeam)
		write_byte(10)
		write_byte(2)
		write_byte(255)
		write_byte(127)
		write_byte(127)
		write_byte(127)
		message_end()
		
		message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
		write_byte(TE_BEAMFOLLOW)
		write_short(Ent)
		write_short(g_SprId_LaserBeam)
		write_byte(10)
		write_byte(2)
		write_byte(255)
		write_byte(255)
		write_byte(255)
		write_byte(127)
		message_end()
		
		set_pev(Ent, pev_iuser3, 1)
	}
		
	set_pev(Ent, pev_nextthink, get_gametime() + 0.1)
}

public fw_Touch_Arrow(Ent, Id)
{
	if(!pev_valid(Ent))
		return
	if(pev(Ent, pev_movetype) == MOVETYPE_NONE)
		return
		
	// Remove Ent
	set_pev(Ent, pev_movetype, MOVETYPE_NONE)
	set_pev(Ent, pev_solid, SOLID_NOT)
		
	if(!is_user_alive(Id)) // Wall
	{
		set_pev(Ent, pev_iuser4, 1)
		set_pev(Ent, pev_nextthink, get_gametime() + 3.0)
		
		static Float:Origin[3]; pev(Ent, pev_origin, Origin)
		MakeBulletDecal(Origin)
	} else { // Player
		static Attacker; Attacker = pev(Ent, pev_iuser1)
		if(!is_user_connected(Attacker) || Attacker == Id)
		{
			engfunc(EngFunc_RemoveEntity, Ent)
			return
		}
			
		do_attack(Attacker, Id, 0, float(DAMAGE_A) * 1.5)
		engfunc(EngFunc_RemoveEntity, Ent)
	}
}

public fw_UpdateClientData_Post(id, sendweapons, cd_handle)
{
	if(get_user_weapon(id) != CSW_BOW || !Get_BitVar(g_Had_CompoundBow, id))
		return FMRES_IGNORED
	
	set_cd(cd_handle, CD_flNextAttack, get_gametime() + 0.001) 
	
	return FMRES_HANDLED
}

public fw_CmdStart(id, uc_handle, seed)
{
	if(get_user_weapon(id) != CSW_BOW || !Get_BitVar(g_Had_CompoundBow, id))
		return
	
	static CurButton; CurButton = get_uc(uc_handle, UC_Buttons)
	if(CurButton & IN_ATTACK)
	{
		CurButton &= ~IN_ATTACK
		set_uc(uc_handle, UC_Buttons, CurButton)
		
		Bow_NormalAttackHandle(id, 0)
	}
	
	static Ent; Ent = fm_get_user_weapon_entity(id, CSW_BOW)
	if(!pev_valid(Ent)) return
	
	if(CurButton & IN_ATTACK2) 
	{
		CurButton &= ~IN_ATTACK2
		set_uc(uc_handle, UC_Buttons, CurButton)
		
		if(get_pdata_float(Ent, 46, 4) > 0.0 || get_pdata_float(Ent, 47, 4) > 0.0) 
			return
		if(!g_BowArrow[id])
			return
			
		switch(g_WeaponState[id])
		{
			case WEAPON_NONE: 
			{
				Set_Weapon_Anim(id, BOW_ANIM_CHARGE_START)
				Set_Weapon_TimeIdle(id, CSW_BOW, 0.5)
				Set_Player_NextAttack(id, 0.5)
				
				g_WeaponState[id] = WEAPON_STARTCHARGING
			}
			case WEAPON_STARTCHARGING:
			{
				Set_Weapon_Anim(id, BOW_ANIM_CHARGE_IDLE1)
				Set_Weapon_TimeIdle(id, CSW_BOW, 0.35)
				Set_Player_NextAttack(id, 0.35)
				
				g_TimeCharge[id] = get_gametime()
				g_WeaponState[id] = WEAPON_WAITCHARGING
			}
			case WEAPON_WAITCHARGING:
			{
				Set_Weapon_Anim(id, BOW_ANIM_CHARGE_IDLE1)
				Set_Weapon_TimeIdle(id, CSW_BOW, 0.35)
				Set_Player_NextAttack(id, 0.35)
				
				g_WeaponState[id] = WEAPON_WAITCHARGING
				
				if(get_gametime() >= (g_TimeCharge[id] + TIME_CHARGE))
				{
					Set_Weapon_Anim(id, BOW_ANIM_CHARGE_FINISH)
					Set_Weapon_TimeIdle(id, CSW_BOW, 0.35)
					Set_Player_NextAttack(id, 0.35)
					
					g_WeaponState[id] = WEAPON_FINISHCHARGING
				}
			}
			case WEAPON_FINISHCHARGING:
			{
				Set_Weapon_Anim(id, BOW_ANIM_CHARGE_IDLE2)
				Set_Weapon_TimeIdle(id, CSW_BOW, 0.35)
				Set_Player_NextAttack(id, 0.35)
				
				g_WeaponState[id] = WEAPON_FINISHCHARGING
			}
		}
	} else {
		static OldButton; OldButton = pev(id, pev_oldbuttons)
		if(OldButton & IN_ATTACK2)
		{
			if(g_WeaponState[id] == WEAPON_WAITCHARGING)
			{
				set_pdata_float(id, 83, 0.0, 5)
				Bow_NormalAttackHandle(id, 1)
			} else if(g_WeaponState[id] == WEAPON_FINISHCHARGING) {
				Bow_ChargeAttackHandle(id)
			}
		} else {
			if(get_pdata_float(Ent, 46, 4) > 0.0 || get_pdata_float(Ent, 47, 4) > 0.0) 
				return
			
			if(g_WeaponState[id] == WEAPON_STARTCHARGING)
			{
				set_pdata_float(id, 83, 0.0, 5)
				Bow_NormalAttackHandle(id, 1)
			}
			
			g_WeaponState[id] = WEAPON_NONE
		}
	}
	
	return 
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
		weapon = fm_find_ent_by_owner(-1, weapon_bow, entity)
		
		if(!pev_valid(weapon))
			return FMRES_IGNORED
		
		if(Get_BitVar(g_Had_CompoundBow, id))
		{
			set_pev(weapon, pev_impulse, WEAPON_SECRETCODE)
			set_pev(weapon, pev_iuser1, g_BowArrow[id])
			
			engfunc(EngFunc_SetModel, entity, W_MODEL)
			Remove_CompoundBow(id)
			
			return FMRES_SUPERCEDE
		}
	}

	return FMRES_IGNORED
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

public Bow_NormalAttackHandle(id, UnCharge)
{
	if(get_pdata_float(id, 83, 5) > 0.0)
		return
	if(!g_BowArrow[id])
	{
		set_pdata_float(id, 83, 1.0, 5)
		Set_Weapon_Anim(id, BOW_ANIM_IDLE_EMPTY)
		
		return
	}
		
	g_BowArrow[id]--
	UpdateAmmo(id, CSW_BOW, BOW_AMMOID, -1, g_BowArrow[id])

	Create_FakeAttack(id)
	
	Set_Weapon_Anim(id, UnCharge ? BOW_ANIM_CHARGE_SHOOT1 : BOW_ANIM_SHOOT1)
	emit_sound(id, CHAN_WEAPON, WeaponSounds[UnCharge ? 1 : 0], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	
	Create_ArrowA(id)
	Make_Push(id)
	
	Set_Player_NextAttack(id, UnCharge ? TIME_RELOADB : TIME_RELOADA)
	Set_Weapon_TimeIdle(id, CSW_BOW, UnCharge ? TIME_RELOADB : TIME_RELOADA)
	
	g_WeaponState[id] = WEAPON_NONE
}

public Bow_ChargeAttackHandle(id)
{
	if(!g_BowArrow[id])
	{
		set_pdata_float(id, 83, 1.0, 5)
		Set_Weapon_Anim(id, BOW_ANIM_IDLE_EMPTY)
		
		return
	}
		
	g_BowArrow[id]--
	UpdateAmmo(id, CSW_BOW, BOW_AMMOID, -1, g_BowArrow[id])

	Create_FakeAttack(id)
	
	Set_Weapon_Anim(id, BOW_ANIM_CHARGE_SHOOT2)
	emit_sound(id, CHAN_WEAPON, WeaponSounds[2], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	
	ChargedShoot(id)
	Make_Push(id)
	
	Set_Player_NextAttack(id, TIME_RELOADB)
	Set_Weapon_TimeIdle(id, CSW_BOW, TIME_RELOADB)	
	
	g_WeaponState[id] = WEAPON_NONE
}

public ChargedShoot(id)
{
	static Float:StartOrigin[3], Float:EndOrigin[3], Float:EndOrigin2[3]
	
	Get_Position(id, 40.0, 0.0, 0.0, StartOrigin)
	Get_Position(id, 4096.0, 0.0, 0.0, EndOrigin)
	
	static TrResult; TrResult = create_tr2()
	engfunc(EngFunc_TraceLine, StartOrigin, EndOrigin, IGNORE_MONSTERS, id, TrResult) 
	get_tr2(TrResult, TR_vecEndPos, EndOrigin2)
	free_tr2(TrResult)
	
	message_begin(MSG_BROADCAST ,SVC_TEMPENTITY)
	write_byte(TE_BEAMPOINTS)
	engfunc(EngFunc_WriteCoord, StartOrigin[0])
	engfunc(EngFunc_WriteCoord, StartOrigin[1])
	engfunc(EngFunc_WriteCoord, StartOrigin[2])
	engfunc(EngFunc_WriteCoord, EndOrigin2[0])
	engfunc(EngFunc_WriteCoord, EndOrigin2[1])
	engfunc(EngFunc_WriteCoord, EndOrigin2[2])
	write_short(g_SprId_LaserBeam)	// sprite index
	write_byte(0)	// starting frame
	write_byte(0)	// frame rate in 0.1's
	write_byte(20)	// life in 0.1's
	write_byte(10)	// line width in 0.1's
	write_byte(0)	// noise amplitude in 0.01's
	write_byte(255)	// Red
	write_byte(127)	// Green
	write_byte(127)	// Blue
	write_byte(127)	// brightness
	write_byte(0)	// scroll speed in 0.1's
	message_end()
	
	message_begin(MSG_BROADCAST ,SVC_TEMPENTITY)
	write_byte(TE_BEAMPOINTS)
	engfunc(EngFunc_WriteCoord, StartOrigin[0])
	engfunc(EngFunc_WriteCoord, StartOrigin[1])
	engfunc(EngFunc_WriteCoord, StartOrigin[2])
	engfunc(EngFunc_WriteCoord, EndOrigin2[0])
	engfunc(EngFunc_WriteCoord, EndOrigin2[1])
	engfunc(EngFunc_WriteCoord, EndOrigin2[2])
	write_short(g_SprId_LaserBeam)	// sprite index
	write_byte(0)	// starting frame
	write_byte(0)	// frame rate in 0.1's
	write_byte(20)	// life in 0.1's
	write_byte(10)	// line width in 0.1's
	write_byte(0)	// noise amplitude in 0.01's
	write_byte(255)	// Red
	write_byte(255)	// Green
	write_byte(255)	// Blue
	write_byte(127)	// brightness
	write_byte(0)	// scroll speed in 0.1's
	message_end()
	
	ChargedDamage(id, StartOrigin, EndOrigin2)
}

public ChargedDamage(id, Float:Start[3], Float:End[3])
{
	static TrResult; TrResult = create_tr2()
	
	// Trace First Time
	engfunc(EngFunc_TraceLine, Start, End, DONT_IGNORE_MONSTERS, id, TrResult) 
	static pHit1; pHit1 = get_tr2(TrResult, TR_pHit)
	static Float:End1[3]; get_tr2(TrResult, TR_vecEndPos, End1)
	
	if(is_user_alive(pHit1)) 
	{
		do_attack(id, pHit1, 0, float(DAMAGE_B) * 1.5)
		engfunc(EngFunc_TraceLine, End1, End, DONT_IGNORE_MONSTERS, pHit1, TrResult) 
	} else engfunc(EngFunc_TraceLine, End1, End, DONT_IGNORE_MONSTERS, -1, TrResult) 
	
	// Trace Second Time
	static pHit2; pHit2 = get_tr2(TrResult, TR_pHit)
	static Float:End2[3]; get_tr2(TrResult, TR_vecEndPos, End2)
	
	if(is_user_alive(pHit2)) 
	{
		do_attack(id, pHit2, 0, float(DAMAGE_B) * 1.5)
		engfunc(EngFunc_TraceLine, End2, End, DONT_IGNORE_MONSTERS, pHit2, TrResult) 
	} else engfunc(EngFunc_TraceLine, End2, End, DONT_IGNORE_MONSTERS, -1, TrResult) 
	
	// Trace Third Time
	static pHit3; pHit3 = get_tr2(TrResult, TR_pHit)
	static Float:End3[3]; get_tr2(TrResult, TR_vecEndPos, End3)
	
	if(is_user_alive(pHit3)) 
	{
		do_attack(id, pHit3, 0, float(DAMAGE_B) * 1.5)
		engfunc(EngFunc_TraceLine, End3, End, DONT_IGNORE_MONSTERS, pHit3, TrResult) 
	} else engfunc(EngFunc_TraceLine, End3, End, DONT_IGNORE_MONSTERS, -1, TrResult) 
	
	// Trace Fourth Time
	static pHit4; pHit4 = get_tr2(TrResult, TR_pHit)
	if(is_user_alive(pHit4)) do_attack(id, pHit4, 0, float(DAMAGE_B) * 1.5)

	free_tr2(TrResult)
}

public Create_ArrowA(id)
{
	static Float:StartOrigin[3], Float:EndOrigin[3], Float:Angles[3]
	
	Get_Position(id, 40.0, 0.0, 0.0, StartOrigin)
	Get_Position(id, 4096.0, 0.0, 0.0, EndOrigin)
	pev(id, pev_v_angle, Angles)
	
	Angles[0] *= -1
	
	static Arrow; Arrow = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "env_sprite"))
	if(!pev_valid(Arrow)) return
	
	set_pev(Arrow, pev_movetype, MOVETYPE_FLY)
	set_pev(Arrow, pev_iuser1, id) // Better than pev_owner
	set_pev(Arrow, pev_iuser2, Get_SpecialTeam(id, cs_get_user_team(id)))
	set_pev(Arrow, pev_iuser3, 0)
	set_pev(Arrow, pev_iuser4, 0)
	
	entity_set_string(Arrow, EV_SZ_classname, ARROW_CLASSNAME)
	engfunc(EngFunc_SetModel, Arrow, ARROW_MODEl)
	set_pev(Arrow, pev_mins, Float:{-1.0, -1.0, -1.0})
	set_pev(Arrow, pev_maxs, Float:{1.0, 1.0, 1.0})
	set_pev(Arrow, pev_origin, StartOrigin)
	set_pev(Arrow, pev_angles, Angles)
	set_pev(Arrow, pev_gravity, 0.01)
	set_pev(Arrow, pev_solid, SOLID_BBOX)
	
	set_pev(Arrow, pev_nextthink, get_gametime() + 0.1)
	
	static Float:Velocity[3]
	get_speed_vector(StartOrigin, EndOrigin, ARROW_SPEED, Velocity)
	set_pev(Arrow, pev_velocity, Velocity)
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
	VirtualVec[0] = random_float(-1.0, -2.0)
	VirtualVec[1] = random_float(1.0, -1.0)
	VirtualVec[2] = 0.0	
	
	set_pev(id, pev_punchangle, VirtualVec)		
}

public fw_Item_AddToPlayer_Post(Ent, Id)
{
	if(pev(Ent, pev_impulse) == WEAPON_SECRETCODE)
	{
		Set_BitVar(g_Had_CompoundBow, Id)
		
		g_BowArrow[Id] = pev(Ent, pev_iuser1)
		UpdateAmmo(Id, CSW_BOW, BOW_AMMOID, -1, g_BowArrow[Id])
		
		set_pev(Ent, pev_impulse, 0)
	}			
	
	g_WeaponState[Id] = WEAPON_NONE
	
	message_begin(MSG_ONE_UNRELIABLE, g_MsgWeaponList, _, Id)
	write_string((Get_BitVar(g_Had_CompoundBow, Id) ? WL_NAME : weapon_bow))
	write_byte(WL_PRIAMMOID)
	write_byte(WL_PRIAMMOMAX)
	write_byte(WL_SECAMMOID)
	write_byte(WL_SECAMMOIDMAX)
	write_byte(WL_SLOTID)
	write_byte(WL_NUMINSLOT)
	write_byte(CSW_BOW)
	write_byte(WL_FLAG)
	message_end()
}

public fw_Item_Deploy_Post(Ent)
{
	if(!pev_valid(Ent))
		return
		
	static Id; Id = get_pdata_cbase(Ent, 41, 4)
	if(!Get_BitVar(g_Had_CompoundBow, Id))
		return
		
	set_pev(Id, pev_viewmodel2, V_MODEL)
	set_pev(Id, pev_weaponmodel2, g_BowArrow[Id] ? P_MODEL : P_MODEL_EMPTY)
	
	set_pdata_string(Id, (492) * 4, WEAPON_ANIMEXT, -1 , 20)
	
	Set_Weapon_TimeIdle(Id, CSW_BOW, TIME_DRAW)
	Set_Player_NextAttack(Id, TIME_DRAW)
	
	Set_Weapon_Anim(Id, g_BowArrow[Id] ? BOW_ANIM_DRAW : BOW_ANIM_DRAW_EMPTY)
}

public fw_Weapon_WeaponIdle_Post(Ent)
{
	if(!pev_valid(Ent))
		return
		
	static Id; Id = get_pdata_cbase(Ent, 41, 4)
	if(!Get_BitVar(g_Had_CompoundBow, Id))
		return
		
	if(get_pdata_float(Ent, 48, 4) <= 0.1) 
	{
		Set_Weapon_Anim(Id, g_BowArrow[Id] ? BOW_ANIM_IDLE : BOW_ANIM_IDLE_EMPTY)
		set_pdata_float(Ent, 48, 20.0, 4)
	}
	
	return
}

public Get_SpecialTeam(Ent, CsTeams:Team)
{
	if(Team == CS_TEAM_T) return TEAM_T
	else if(Team == CS_TEAM_CT) return TEAM_CT
	
	return 0
}

public CsTeams:Get_ArrowTeam(Ent)
{
	if(pev(Ent, pev_iuser2) == TEAM_T) return CS_TEAM_T
	else if(pev(Ent, pev_iuser2) == TEAM_CT) return CS_TEAM_CT
	
	return CS_TEAM_UNASSIGNED
}

stock MakeBulletDecal(Float:Origin[3])
{
	// Find target
	static decal; decal = random_num(41, 45)
	
	// Put decal on "world" (a wall)
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_WORLDDECAL)
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2])
	write_byte(decal)
	message_end()
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

do_attack(Attacker, Victim, Inflictor, Float:fDamage)
{
	fake_player_trace_attack(Attacker, Victim, fDamage)
	fake_take_damage(Attacker, Victim, fDamage, Inflictor)
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
	static iHitgroup; iHitgroup = get_tr2(ptr, TR_iHitgroup)
	static Float:fEndPos[3]
	get_tr2(ptr, TR_vecEndPos, fEndPos)

	// get target & body at aiming
	static iTarget, iBody
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
		static Float:fVicOrigin[3], Float:fVicViewOfs[3], Float:fAimInVictim[3]
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
			
			static ptr3; ptr3 = create_tr2() 
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
}
