#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <cstrike>
#include <fun>

#define PLUGIN "[CSO] Thanatos-11"
#define VERSION "1.0"
#define AUTHOR "Dias Pendragon"

#define DAMAGE_A 140 // 140 for zombie, 70 for human
#define DAMAGE_B 560 // 560 for zombie, 280 for human

#define CLIP 15
#define BPAMMO 64

#define SPEED 0.85
#define SCYTHE_RELOAD 5.0 // Reload Time per one
#define SCYTHE_MAX 3 // Max Ammo

#define SCYTHE_CLASSNAME "scythe11"

#define V_MODEL "models/v_thanatos11_fix.mdl"
#define P_MODEL "models/p_thanatos11.mdl"
#define W_MODEL "models/w_thanatos11.mdl"
#define S_MODEL "models/thanatos11_scythe.mdl"

new const WeaponSounds[16][] =
{
	"weapons/thanatos11-1.wav",
	"weapons/thanatos11_shootb.wav",
	"weapons/thanatos11_shootb_empty.wav",
	"weapons/thanatos11_shootb_hit.wav",
	"weapons/thanatos11_after_reload.wav",
	"weapons/thanatos11_changea.wav",
	"weapons/thanatos11_changea_empty.wav",
	"weapons/thanatos11_changeb.wav",
	"weapons/thanatos11_changeb_empty.wav",
	"weapons/thanatos11_count.wav",
	"weapons/thanatos11_count_start.wav",
	"weapons/thanatos11_explode.wav",
	"weapons/thanatos11_idleb_reload.wav",
	"weapons/thanatos11_idleb1.wav",
	"weapons/thanatos11_idleb2.wav",
	"weapons/thanatos11_insert_reload.wav"
}

#define SCYTHE_HEAD "sprites/thanatos11_scythe.spr"
#define SCYTHE_CIRCLE "sprites/circle.spr"
#define SCYTHE_DEATH "sprites/thanatos11_fire.spr"

#define CSW_THANATOS11 CSW_M3 
#define weapon_thanatos11 "weapon_m3"

#define WEAPON_SECRETCODE 2122015
#define OLD_W_MODEL "models/w_m3.mdl"
#define OLD_EVENT "events/m3.sc"

#define TASK_CHANGE 23332

enum
{
	T11_ANIM_IDLEA = 0, // 0
	T11_ANIM_IDLEB1,
	T11_ANIM_IDLEB2,
	T11_ANIM_INSERT,
	T11_ANIM_AFTER,
	T11_ANIM_START, // 5
	T11_ANIM_IDLEB_EMPTY,
	T11_ANIM_SHOOTA,
	T11_ANIM_SHOOTB,
	T11_ANIM_SHOOTB_EMPTY,
	T11_ANIM_CHANGEA, // 10
	T11_ANIM_CHANGEA_EMPTY,
	T11_ANIM_CHANGEB,
	T11_ANIM_CHANGEB_EMPTY,
	T11_ANIM_DRAW,
	T11_ANIM_IDLEB_RELOAD // 15
}

enum
{
	T11_MODE_NORMAL = 0,
	T11_MODE_THANATOS
}

// MACROS
#define Get_BitVar(%1,%2) (%1 & (1 << (%2 & 31)))
#define Set_BitVar(%1,%2) %1 |= (1 << (%2 & 31))
#define UnSet_BitVar(%1,%2) %1 &= ~(1 << (%2 & 31))

new g_Had_Thanatos11, g_Thanatos11_Mode[33], g_ChargedAmmo2[33], g_OldWeapon[33], Float:ReloadTime[33]
new g_HamBot, g_MsgCurWeapon, g_Event_Thanatos11, g_SmokePuff_Id, m_spriteTexture
new g_Msg_StatusIcon, g_InTempingAttack, g_ScytheDeath

// Safety
new g_IsConnected, g_IsAlive, g_PlayerWeapon[33]

// ==========================================================
enum _:ShotGuns {
	m3,
	xm1014
}

const NOCLIP_WPN_BS	= ((1<<CSW_HEGRENADE)|(1<<CSW_SMOKEGRENADE)|(1<<CSW_FLASHBANG)|(1<<CSW_KNIFE)|(1<<CSW_C4))
const SHOTGUNS_BS	= ((1<<CSW_M3)|(1<<CSW_XM1014))

// weapons offsets
#define XTRA_OFS_WEAPON			4
#define m_pPlayer				41
#define m_iId					43
#define m_fKnown				44
#define m_flNextPrimaryAttack		46
#define m_flNextSecondaryAttack	47
#define m_flTimeWeaponIdle		48
#define m_iPrimaryAmmoType		49
#define m_iClip				51
#define m_fInReload				54
#define m_fInSpecialReload		55
#define m_fSilent				74

// players offsets
#define XTRA_OFS_PLAYER		5
#define m_flNextAttack		83
#define m_rgAmmo_player_Slot0	376

stock const g_iDftMaxClip[CSW_P90+1] = {
	-1,  13, -1, 10,  1,  7,    1, 30, 30,  1,  30, 
		20, 25, 30, 35, 25,   12, 20, 10, 30, 100, 
		8 , 30, 30, 20,  2,    7, 30, 30, -1,  50}

stock const Float:g_fDelay[CSW_P90+1] = {
	0.00, 2.70, 0.00, 2.00, 0.00, 0.55,   0.00, 3.15, 3.30, 0.00, 4.50, 
		 2.70, 3.50, 3.35, 2.45, 3.30,   2.70, 2.20, 2.50, 2.63, 4.70, 
		 0.55, 3.05, 2.12, 3.50, 0.00,   2.20, 3.00, 2.45, 0.00, 3.40
}

stock const g_iReloadAnims[CSW_P90+1] = {
	-1,  5, -1, 3, -1,  6,   -1, 1, 1, -1, 14, 
		4,  2, 3,  1,  1,   13, 7, 4,  1,  3, 
		6, 11, 1,  3, -1,    4, 1, 1, -1,  1}
		
new Float:g_PostFrame[33]

// Attachment

#define MAX_CHANNEL 4
#define ATTACHMENT_CLASSNAME "hattach"

const pev_user = pev_iuser1
const pev_livetime = pev_fuser1
const pev_totalframe = pev_fuser2

new g_MyAttachment[33][MAX_CHANNEL+1]

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)

	register_event("CurWeapon", "Event_CurWeapon", "be", "1=1")
	
	register_forward(FM_SetModel, "fw_SetModel")
	register_forward(FM_CmdStart, "fw_CmdStart")
	register_forward(FM_UpdateClientData, "fw_UpdateClientData_Post", 1)	
	register_forward(FM_PlaybackEvent, "fw_PlaybackEvent")	
	register_forward(FM_EmitSound, "fw_EmitSound")
	register_forward(FM_TraceLine, "fw_TraceLine")
	register_forward(FM_TraceHull, "fw_TraceHull")		
	
	register_touch(SCYTHE_CLASSNAME, "*", "fw_Scythe_Touch")
	register_think(SCYTHE_CLASSNAME, "fw_Scythe_Think")
	
	// Safety
	Register_SafetyFunc()
	
	RegisterHam(Ham_TraceAttack, "player", "fw_TraceAttack")
	RegisterHam(Ham_TraceAttack, "worldspawn", "fw_TraceAttack")		
	
	RegisterHam(Ham_Item_Deploy, weapon_thanatos11, "fw_Item_Deploy_Post", 1)	
	RegisterHam(Ham_Item_AddToPlayer, weapon_thanatos11, "fw_Item_AddToPlayer_Post", 1)
	RegisterHam(Ham_Item_PostFrame, weapon_thanatos11, "fw_Item_PostFrame")
	RegisterHam(Ham_Weapon_WeaponIdle, weapon_thanatos11, "fw_Weapon_WeaponIdle")	
	RegisterHam(Ham_Weapon_WeaponIdle, weapon_thanatos11, "fw_Weapon_WeaponIdle_Post", 1)	
	
	// Cache
	g_Msg_StatusIcon = get_user_msgid("StatusIcon")
	g_MsgCurWeapon = get_user_msgid("CurWeapon")
	
	register_clcmd("say /get", "Get_Thanatos11")
	
	// Attach
	register_event("HLTV", "Event_NewRound", "a", "1=0", "2=0")
	register_think(ATTACHMENT_CLASSNAME, "fw_Think")
}

public plugin_precache()
{
	precache_model(V_MODEL)
	precache_model(P_MODEL)
	precache_model(W_MODEL)
	precache_model(S_MODEL)
	g_ScytheDeath = precache_model(SCYTHE_DEATH)
	
	precache_model(SCYTHE_HEAD)
	precache_model(SCYTHE_CIRCLE)
	
	for(new i = 0; i < sizeof(WeaponSounds); i++)
		precache_sound(WeaponSounds[i])

	register_forward(FM_PrecacheEvent, "fw_PrecacheEvent_Post", 1)	
	
	m_spriteTexture = precache_model("sprites/laserbeam.spr")
	g_SmokePuff_Id = engfunc(EngFunc_PrecacheModel, "sprites/wall_puff1.spr")
}

public fw_PrecacheEvent_Post(type, const name[])
{
	if(equal(OLD_EVENT, name))
		g_Event_Thanatos11 = get_orig_retval()
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
	RegisterHamFromEntity(Ham_TraceAttack, id, "fw_TraceAttack")
}

public client_disconnect(id)
{
	Safety_Disconnected(id)
}

public Get_Thanatos11(id)
{
	Remove_Thanatos11(id)
	
	Set_BitVar(g_Had_Thanatos11, id)
	g_Thanatos11_Mode[id] = T11_MODE_NORMAL
	g_ChargedAmmo2[id] = 0
	
	give_item(id, weapon_thanatos11)
	cs_set_user_bpammo(id, CSW_THANATOS11, BPAMMO)
	
	static Ent; Ent = fm_get_user_weapon_entity(id, CSW_THANATOS11)
	if(pev_valid(Ent)) cs_set_weapon_ammo(Ent, CLIP)
	
	engfunc(EngFunc_MessageBegin, MSG_ONE_UNRELIABLE, g_MsgCurWeapon, {0, 0, 0}, id)
	write_byte(1)
	write_byte(CSW_THANATOS11)
	write_byte(CLIP)
	message_end()
	
	update_specialammo(id, g_ChargedAmmo2[id], 0)
}

public Remove_Thanatos11(id)
{
	update_specialammo(id, g_ChargedAmmo2[id], 0)
	
	UnSet_BitVar(g_Had_Thanatos11, id)
	g_Thanatos11_Mode[id] = T11_MODE_NORMAL
	g_ChargedAmmo2[id] = 0
}

public Hook_Weapon(id)
{
	engclient_cmd(id, weapon_thanatos11)
	return PLUGIN_HANDLED
}

public Event_CurWeapon(id)
{
	if(!is_player(id, 1))
		return
	
	static CSWID; CSWID = read_data(2)

	if((CSWID == CSW_THANATOS11 && g_OldWeapon[id] == CSW_THANATOS11) && Get_BitVar(g_Had_Thanatos11, id)) 
	{
		static Ent; Ent = fm_get_user_weapon_entity(id, CSW_THANATOS11)
		if(pev_valid(Ent)) 
		{
			set_pdata_float(Ent, 46, get_pdata_float(Ent, 46, 4) * SPEED, 4)
			set_pdata_float(Ent, 47, get_pdata_float(Ent, 46, 4) * SPEED, 4)	
		}
	}
	
	g_OldWeapon[id] = CSWID
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
	
	if(equal(model, OLD_W_MODEL))
	{
		static weapon
		weapon = fm_get_user_weapon_entity(entity, CSW_THANATOS11)
		
		if(!pev_valid(weapon))
			return FMRES_IGNORED
		
		if(Get_BitVar(g_Had_Thanatos11, id))
		{
			set_pev(weapon, pev_impulse, WEAPON_SECRETCODE)
			set_pev(weapon, pev_iuser4, g_ChargedAmmo2[id])
			engfunc(EngFunc_SetModel, entity, W_MODEL)
			
			Remove_Thanatos11(id)
			
			return FMRES_SUPERCEDE
		}
	}

	return FMRES_IGNORED;
}

public fw_CmdStart(id, uc_handle, seed)
{
	if(!is_player(id, 1))
		return
	if(!Get_BitVar(g_Had_Thanatos11, id))
		return
		
	if(get_gametime() - SCYTHE_RELOAD > ReloadTime[id])
	{
		if(g_ChargedAmmo2[id] < SCYTHE_MAX)
		{
			update_specialammo(id, g_ChargedAmmo2[id], 0)
			g_ChargedAmmo2[id]++
			if(g_ChargedAmmo2[id] == 1 && g_Thanatos11_Mode[id] == T11_MODE_THANATOS) 
				Set_WeaponAnim(id, T11_ANIM_IDLEB_RELOAD)
			
			emit_sound(id, CHAN_ITEM, WeaponSounds[9], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
			
			update_specialammo(id, g_ChargedAmmo2[id], 1)
		}
		
		ReloadTime[id] = get_gametime()
	}
	
	if(get_player_weapon(id) != CSW_THANATOS11)
		return
		
	static PressedButton
	PressedButton = get_uc(uc_handle, UC_Buttons)
	
	if(PressedButton & IN_RELOAD)
	{
		if(get_pdata_float(id, 83, 5) > 0.0)
			return 
	
		if(g_Thanatos11_Mode[id] == T11_MODE_THANATOS)
		{
			PressedButton &= ~IN_RELOAD
			set_uc(uc_handle, UC_Buttons, PressedButton)
		}
	}
	
	if(PressedButton & IN_ATTACK)
	{
		if(get_pdata_float(id, 83, 5) > 0.0)
			return 
	
		if(g_Thanatos11_Mode[id] == T11_MODE_THANATOS)
		{
			PressedButton &= ~IN_ATTACK
			set_uc(uc_handle, UC_Buttons, PressedButton)
			
			Shoot_Scythe(id)
		}
	}
	
	if(PressedButton & IN_ATTACK2)
	{
		if(get_pdata_float(id, 83, 5) > 0.0)
			return 
	
		switch(g_Thanatos11_Mode[id])
		{
			case T11_MODE_NORMAL:
			{
				if(g_ChargedAmmo2[id] > 0) Set_WeaponAnim(id, T11_ANIM_CHANGEA)
				else Set_WeaponAnim(id, T11_ANIM_CHANGEA_EMPTY)
				
				set_pdata_float(id, 83, 2.5, 5)
				
				remove_task(id+TASK_CHANGE)
				set_task(2.35, "Complete_Reload", id+TASK_CHANGE)
			}
			case T11_MODE_THANATOS:
			{
				if(g_ChargedAmmo2[id] > 0) Set_WeaponAnim(id, T11_ANIM_CHANGEB)
				else Set_WeaponAnim(id, T11_ANIM_CHANGEB_EMPTY)
				
				set_pdata_float(id, 83, 2.5, 5)
				
				remove_task(id+TASK_CHANGE)
				set_task(2.35, "Complete_Reload", id+TASK_CHANGE)
			}
		}
	}
}

public Complete_Reload(id)
{
	id -= TASK_CHANGE
	
	if(!is_user_alive(id))
		return
	if(get_user_weapon(id) != CSW_THANATOS11 || !Get_BitVar(g_Had_Thanatos11, id))
		return
		
	switch(g_Thanatos11_Mode[id])
	{
		case T11_MODE_NORMAL:
		{
			g_Thanatos11_Mode[id] = T11_MODE_THANATOS
		}
		case T11_MODE_THANATOS:
		{
			g_Thanatos11_Mode[id] = T11_MODE_NORMAL
		}
	}
}

public Shoot_Scythe(id)
{
	if(g_ChargedAmmo2[id] <= 0)
		return

	Create_FakeAttackAnim(id)
	update_specialammo(id, g_ChargedAmmo2[id], 0)
	g_ChargedAmmo2[id]--
	
	if(g_ChargedAmmo2[id]) 
	{	
		Set_WeaponAnim(id, T11_ANIM_SHOOTB)
		update_specialammo(id, g_ChargedAmmo2[id], 1)
		
		emit_sound(id, CHAN_WEAPON, WeaponSounds[1], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	} else {
		Set_WeaponAnim(id, T11_ANIM_SHOOTB_EMPTY)
		
		emit_sound(id, CHAN_WEAPON, WeaponSounds[2], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	}
	
	set_pdata_float(id, 83, 1.0, 5)
	
	// Fake Punch
	static Float:Origin[3]
	Origin[0] = random_float(-2.5, -5.0)
	
	set_pev(id, pev_punchangle, Origin)
	
	// Scythe
	Create_Scythe(id)
}

public Create_Scythe(id)
{
	new iEnt = create_entity("info_target")
	
	static Float:Origin[3], Float:Angles[3], Float:TargetOrigin[3], Float:Velocity[3]
	
	get_weapon_attachment(id, Origin, 40.0)
	get_position(id, 1024.0, 0.0, 0.0, TargetOrigin)
	
	pev(id, pev_v_angle, Angles)
	Angles[0] *= -1.0

	// set info for ent
	set_pev(iEnt, pev_movetype, MOVETYPE_FLY)
	entity_set_string(iEnt, EV_SZ_classname, SCYTHE_CLASSNAME)
	engfunc(EngFunc_SetModel, iEnt, S_MODEL)
	
	set_pev(iEnt, pev_mins, Float:{-6.0, -6.0, -6.0})
	set_pev(iEnt, pev_maxs, Float:{6.0, 6.0, 6.0})
	set_pev(iEnt, pev_origin, Origin)
	set_pev(iEnt, pev_gravity, 0.01)
	set_pev(iEnt, pev_angles, Angles)
	set_pev(iEnt, pev_solid, SOLID_TRIGGER)
	set_pev(iEnt, pev_owner, id)	
	set_pev(iEnt, pev_iuser1, get_user_team(id))
	set_pev(iEnt, pev_iuser2, 0)
	set_pev(iEnt, pev_fuser1, get_gametime() + 10.0)
	
	get_speed_vector(Origin, TargetOrigin, 1600.0, Velocity)
	set_pev(iEnt, pev_velocity, Velocity)	
	
	set_pev(iEnt, pev_nextthink, get_gametime() + 0.1)
	
	// Animation
	set_pev(iEnt, pev_animtime, get_gametime())
	set_pev(iEnt, pev_framerate, 2.0)
	set_pev(iEnt, pev_sequence, 0)
	
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_BEAMFOLLOW)
	write_short(iEnt)
	write_short(m_spriteTexture)
	write_byte(10)
	write_byte(3)
	write_byte(0)
	write_byte(85)
	write_byte(255)
	write_byte(255)
	message_end()
}

public fw_Scythe_Touch(Ent, id)
{
	if(!pev_valid(Ent))
		return
		
	if(is_user_alive(id))
	{
		static Owner; Owner = pev(Ent, pev_owner)
		if(!is_user_connected(Owner) || (get_user_team(id) == pev(Ent, pev_iuser1)))
			return
			
		ThanatosBladeSystem(id, Owner)
			
		set_pev(Ent, pev_movetype, MOVETYPE_NONE)
		set_pev(Ent, pev_velocity, {0.0, 0.0, 0.0})
		
		set_pev(Ent, pev_flags, FL_KILLME)
		set_pev(Ent, pev_nextthink, get_gametime() + 0.1)
	} else {
		set_pev(Ent, pev_movetype, MOVETYPE_NONE)
		set_pev(Ent, pev_velocity, {0.0, 0.0, 0.0})
		
		set_pev(Ent, pev_flags, FL_KILLME)
		set_pev(Ent, pev_nextthink, get_gametime() + 0.1)
		
		return
	}
}

public ThanatosBladeSystem(id, attacker)
{
	Show_Attachment(id, SCYTHE_HEAD, 3.0, 1.0, 1.0, 6)
	Show_Attachment(id, SCYTHE_CIRCLE, 3.0, 1.0, 0.1, 10)
	
	emit_sound(id, CHAN_ITEM, WeaponSounds[3], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	
	static ArraySuck[2]
	ArraySuck[0] = id
	ArraySuck[1] = attacker
	
	set_task(3.0, "Explosion", id+2122, ArraySuck, 2)
}

public Explosion(ArraySuck[], taskid)
{
	static id, attacker;
	id = ArraySuck[0]
	attacker = ArraySuck[1]
	
	if(!is_user_alive(id) || !is_user_connected(attacker))
		return
	if(get_user_team(id) == get_user_team(attacker))
		return
		
	emit_sound(id, CHAN_ITEM, WeaponSounds[11], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
	
	static Float:Origin[3];
	pev(id, pev_origin, Origin)
	
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_EXPLOSION)
	engfunc(EngFunc_WriteCoord, Origin[0])
	engfunc(EngFunc_WriteCoord, Origin[1])
	engfunc(EngFunc_WriteCoord, Origin[2])
	write_short(g_ScytheDeath)
	write_byte(10)
	write_byte(15)
	write_byte(TE_EXPLFLAG_NOSOUND)  
	message_end()
	
	ExecuteHamB(Ham_TakeDamage, id, fm_get_user_weapon_entity(attacker, CSW_THANATOS11), attacker, float(DAMAGE_B), DMG_BULLET)
}

public fw_Scythe_Think(Ent)
{
	if(!pev_valid(Ent))
		return
		
	static Float:Time; pev(Ent, pev_fuser1, Time)
	
	if(Time <= get_gametime())
	{
		set_pev(Ent, pev_flags, FL_KILLME)
		set_pev(Ent, pev_nextthink, get_gametime() + 0.1)
		
		return
	}
	
	set_pev(Ent, pev_nextthink, get_gametime() + 0.1)
}


public fw_UpdateClientData_Post(id, sendweapons, cd_handle)
{
	if(!is_player(id, 1))
		return FMRES_IGNORED	
	if(get_player_weapon(id) == CSW_THANATOS11 && Get_BitVar(g_Had_Thanatos11, id))
		set_cd(cd_handle, CD_flNextAttack, get_gametime() + 0.001) 
	
	return FMRES_HANDLED
}

public fw_PlaybackEvent(flags, invoker, eventid, Float:delay, Float:origin[3], Float:angles[3], Float:fparam1, Float:fparam2, iParam1, iParam2, bParam1, bParam2)
{
	if (!is_player(invoker, 0))
		return FMRES_IGNORED		
	if(get_player_weapon(invoker) == CSW_THANATOS11 && Get_BitVar(g_Had_Thanatos11, invoker) && eventid == g_Event_Thanatos11)
	{
		engfunc(EngFunc_PlaybackEvent, flags | FEV_HOSTONLY, invoker, eventid, delay, origin, angles, fparam1, fparam2, iParam1, iParam2, bParam1, bParam2)
		Set_WeaponAnim(invoker, T11_ANIM_SHOOTA)

		emit_sound(invoker, CHAN_WEAPON, WeaponSounds[0], 1.0, ATTN_NORM, 0, PITCH_LOW)	
			
		return FMRES_SUPERCEDE
	}
	
	return FMRES_HANDLED
}

public fw_TraceAttack(Ent, Attacker, Float:Damage, Float:Dir[3], ptr, DamageType)
{
	if(!is_player(Attacker, 0))
		return HAM_IGNORED	
	if(get_player_weapon(Attacker) != CSW_THANATOS11 || !Get_BitVar(g_Had_Thanatos11, Attacker))
		return HAM_IGNORED
		
	static Float:flEnd[3], Float:vecPlane[3]
	
	get_tr2(ptr, TR_vecEndPos, flEnd)
	get_tr2(ptr, TR_vecPlaneNormal, vecPlane)		
		
	if(!is_player(Ent, 0))
	{
		make_bullet(Attacker, flEnd)
		fake_smoke(Attacker, ptr)
	}
	
	SetHamParamFloat(3, float(DAMAGE_A) / 6.0)
	
	return HAM_HANDLED	
}

public fw_Item_Deploy_Post(Ent)
{
	if(pev_valid(Ent) != 2)
		return
	static Id; Id = get_pdata_cbase(Ent, 41, 4)
	if(get_pdata_cbase(Id, 373) != Ent)
		return
	if(!Get_BitVar(g_Had_Thanatos11, Id))
		return

	g_Thanatos11_Mode[Id] = T11_MODE_NORMAL
		
	set_pev(Id, pev_viewmodel2, V_MODEL)
	set_pev(Id, pev_weaponmodel2, P_MODEL)
	
	Set_WeaponAnim(Id, T11_ANIM_DRAW)
}

public fw_Item_AddToPlayer_Post(ent, id)
{
	if(pev(ent, pev_impulse) == WEAPON_SECRETCODE)
	{
		Set_BitVar(g_Had_Thanatos11, id)
		
		set_pev(ent, pev_impulse, 0)
		g_ChargedAmmo2[id] = pev(ent, pev_iuser4)
		
		update_specialammo(id, g_ChargedAmmo2[id], 1)
	}			
}

public update_specialammo(id, Ammo, On)
{
	static AmmoSprites[33]
	format(AmmoSprites, sizeof(AmmoSprites), "number_%d", Ammo)
  	
	message_begin(MSG_ONE_UNRELIABLE, g_Msg_StatusIcon, {0,0,0}, id)
	write_byte(On)
	write_string(AmmoSprites)
	write_byte(0) // red
	write_byte(85) // green
	write_byte(255) // blue
	message_end()	
}

public fw_Weapon_WeaponIdle( iEnt )
{
	if(pev_valid(iEnt) != 2)
		return 
	static id; id = get_pdata_cbase(iEnt, m_pPlayer, XTRA_OFS_WEAPON)
	if(get_pdata_cbase(id, 373) != iEnt)
		return
	if(!Get_BitVar(g_Had_Thanatos11, id))
		return
	
	if( get_pdata_float(iEnt, m_flTimeWeaponIdle, XTRA_OFS_WEAPON) > 0.0 )
	{
		return
	}
	
	static iId ; iId = get_pdata_int(iEnt, m_iId, XTRA_OFS_WEAPON)
	static iMaxClip ; iMaxClip = CLIP

	static iClip ; iClip = get_pdata_int(iEnt, m_iClip, XTRA_OFS_WEAPON)
	static fInSpecialReload ; fInSpecialReload = get_pdata_int(iEnt, m_fInSpecialReload, XTRA_OFS_WEAPON)

	if( !iClip && !fInSpecialReload )
	{
		return
	}

	if( fInSpecialReload )
	{
		static iBpAmmo ; iBpAmmo = get_pdata_int(id, 381, XTRA_OFS_PLAYER)
		static iDftMaxClip ; iDftMaxClip = g_iDftMaxClip[iId]

		if( iClip < iMaxClip && iClip == iDftMaxClip && iBpAmmo )
		{
			Shotgun_Reload(iEnt, iId, iMaxClip, iClip, iBpAmmo, id)
			return
		}
		else if( iClip == iMaxClip && iClip != iDftMaxClip )
		{
			Set_WeaponAnim(id, T11_ANIM_AFTER)
			
			set_pdata_int(iEnt, m_fInSpecialReload, 0, XTRA_OFS_WEAPON)
			set_pdata_float(iEnt, m_flTimeWeaponIdle, 1.5, XTRA_OFS_WEAPON)
		}
	}
	
	return
}

public fw_Weapon_WeaponIdle_Post( iEnt )
{
	if(pev_valid(iEnt) != 2)
		return 
	static id; id = get_pdata_cbase(iEnt, m_pPlayer, XTRA_OFS_WEAPON)
	if(get_pdata_cbase(id, 373) != iEnt)
		return
	if(!Get_BitVar(g_Had_Thanatos11, id))
		return
		
	static SpecialReload; SpecialReload = get_pdata_int(iEnt, 55, 4)
	if(!SpecialReload && get_pdata_float(iEnt, 48, 4) <= 0.25)
	{
		switch(g_Thanatos11_Mode[id])
		{
			case T11_MODE_NORMAL: Set_WeaponAnim(id, T11_ANIM_IDLEA)
			case T11_MODE_THANATOS: 
			{
				if(g_ChargedAmmo2[id] > 0) Set_WeaponAnim(id, T11_ANIM_IDLEB1)
				else Set_WeaponAnim(id, T11_ANIM_IDLEB_EMPTY)
			}
		}
		
		set_pdata_float(iEnt, 48, 20.0, 4)
	}	
}

public fw_Item_PostFrame( iEnt )
{
	static id ; id = get_pdata_cbase(iEnt, m_pPlayer, XTRA_OFS_WEAPON)	

	static iBpAmmo ; iBpAmmo = get_pdata_int(id, 381, XTRA_OFS_PLAYER)
	static iClip ; iClip = get_pdata_int(iEnt, m_iClip, XTRA_OFS_WEAPON)
	static iId ; iId = get_pdata_int(iEnt, m_iId, XTRA_OFS_WEAPON)
	static iMaxClip ; iMaxClip = CLIP

	// Support for instant reload (used for example in my plugin "Reloaded Weapons On New Round")
	// It's possible in default cs
	if( get_pdata_int(iEnt, m_fInReload, XTRA_OFS_WEAPON) && get_pdata_float(id, m_flNextAttack, 5) <= 0.0 )
	{
		new j = min(iMaxClip - iClip, iBpAmmo)
		set_pdata_int(iEnt, m_iClip, iClip + j, XTRA_OFS_WEAPON)
		set_pdata_int(id, 381, iBpAmmo-j, XTRA_OFS_PLAYER)
		
		set_pdata_int(iEnt, m_fInReload, 0, XTRA_OFS_WEAPON)
		return
	}

	static iButton ; iButton = pev(id, pev_button)
	if( iButton & IN_ATTACK && get_pdata_float(iEnt, m_flNextPrimaryAttack, XTRA_OFS_WEAPON) <= 0.0 )
	{
		return
	}
	
	if( iButton & IN_RELOAD  )
	{
		if( iClip >= iMaxClip )
		{
			set_pev(id, pev_button, iButton & ~IN_RELOAD) // still this fucking animation
			set_pdata_float(iEnt, m_flNextPrimaryAttack, 0.5, XTRA_OFS_WEAPON)  // Tip ?
		}

		else if( iClip == g_iDftMaxClip[iId] )
		{
			if( iBpAmmo )
			{
				Shotgun_Reload(iEnt, iId, iMaxClip, iClip, iBpAmmo, id)
			}
		}
	}
	
	if(get_pdata_int(iEnt, 55, 4) == 1)
	{
		static Float:CurTime
		CurTime = get_gametime()
		
		if(CurTime - 0.35 > g_PostFrame[id])
		{
			Set_WeaponAnim(id, T11_ANIM_INSERT)
			g_PostFrame[id] = CurTime
		}
	}
}

Shotgun_Reload(iEnt, iId, iMaxClip, iClip, iBpAmmo, id)
{
	if(iBpAmmo <= 0 || iClip == iMaxClip)
		return

	if(get_pdata_int(iEnt, m_flNextPrimaryAttack, XTRA_OFS_WEAPON) > 0.0)
		return

	switch( get_pdata_int(iEnt, m_fInSpecialReload, XTRA_OFS_WEAPON) )
	{
		case 0:
		{
			Set_WeaponAnim(id, T11_ANIM_START)
		
			set_pdata_int(iEnt, m_fInSpecialReload, 1, XTRA_OFS_WEAPON)
			set_pdata_float(id, m_flNextAttack, 0.55, 5)
			set_pdata_float(iEnt, m_flTimeWeaponIdle, 0.55, XTRA_OFS_WEAPON)
			set_pdata_float(iEnt, m_flNextPrimaryAttack, 0.55, XTRA_OFS_WEAPON)
			set_pdata_float(iEnt, m_flNextSecondaryAttack, 0.55, XTRA_OFS_WEAPON)
			return
		}
		case 1:
		{
			if( get_pdata_float(iEnt, m_flTimeWeaponIdle, XTRA_OFS_WEAPON) > 0.0 )
			{
				return
			}
			set_pdata_int(iEnt, m_fInSpecialReload, 2, XTRA_OFS_WEAPON)
			set_pdata_float(iEnt, m_flTimeWeaponIdle, iId == CSW_XM1014 ? 0.30 : 0.45, XTRA_OFS_WEAPON)
		}
		default:
		{
			set_pdata_int(iEnt, m_iClip, iClip + 1, XTRA_OFS_WEAPON)
			set_pdata_int(id, 381, iBpAmmo-1, XTRA_OFS_PLAYER)
			set_pdata_int(iEnt, m_fInSpecialReload, 1, XTRA_OFS_WEAPON)
		}
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

public Event_NewRound() remove_entity_name(ATTACHMENT_CLASSNAME)
public Show_Attachment(id, const Sprite[],  Float:Time, Float:Scale, Float:FrameRate, TotalFrame)
{
	if(!is_user_alive(id))
		return

	static channel; channel = 0
	for(new i = 0; i < MAX_CHANNEL; i++)
	{
		if(pev_valid(g_MyAttachment[id][i])) channel++
		else {
			channel = i
			break
		}
	}
	if(channel >= MAX_CHANNEL) return
	if(!pev_valid(g_MyAttachment[id][channel]))
		g_MyAttachment[id][channel] = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "env_sprite"))
	if(!pev_valid(g_MyAttachment[id][channel]))
		return
	
	// Set Properties
	set_pev(g_MyAttachment[id][channel], pev_takedamage, DAMAGE_NO)
	set_pev(g_MyAttachment[id][channel], pev_solid, SOLID_NOT)
	set_pev(g_MyAttachment[id][channel], pev_movetype, MOVETYPE_FOLLOW)
	
	// Set Sprite
	set_pev(g_MyAttachment[id][channel], pev_classname, ATTACHMENT_CLASSNAME)
	engfunc(EngFunc_SetModel, g_MyAttachment[id][channel], Sprite)
	
	// Set Rendering
	set_pev(g_MyAttachment[id][channel], pev_renderfx, kRenderFxNone)
	set_pev(g_MyAttachment[id][channel], pev_rendermode, kRenderTransAdd)
	set_pev(g_MyAttachment[id][channel], pev_renderamt, 200.0)
	
	// Set other
	set_pev(g_MyAttachment[id][channel], pev_user, id)
	set_pev(g_MyAttachment[id][channel], pev_scale, Scale)
	set_pev(g_MyAttachment[id][channel], pev_livetime, get_gametime() + Time)
	set_pev(g_MyAttachment[id][channel], pev_totalframe, float(TotalFrame))
	
	// Set Origin
	static Float:Origin[3]; pev(id, pev_origin, Origin)
	if(!(pev(id, pev_flags) & FL_DUCKING)) Origin[2] += 25.0
	else Origin[2] += 20.0
	
	engfunc(EngFunc_SetOrigin, g_MyAttachment[id][channel], Origin)
	
	// Allow animation of sprite ?
	if(TotalFrame && FrameRate > 0.0)
	{
		set_pev(g_MyAttachment[id][channel], pev_animtime, get_gametime())
		set_pev(g_MyAttachment[id][channel], pev_framerate, FrameRate + 9.0)
		
		set_pev(g_MyAttachment[id][channel], pev_spawnflags, SF_SPRITE_STARTON)
		dllfunc(DLLFunc_Spawn, g_MyAttachment[id][channel])
	}	
	
	// Force Think
	set_pev(g_MyAttachment[id][channel], pev_nextthink, get_gametime() + 0.05)
}

public fw_Think(Ent)
{
	if(!pev_valid(Ent))
		return
		
	static Owner; Owner = pev(Ent, pev_user)
	if(!is_user_alive(Owner))
	{
		engfunc(EngFunc_RemoveEntity, Ent)
		return
	}
	if(get_gametime() >= pev(Ent, pev_livetime))
	{
		if(pev(Ent, pev_renderamt) > 0.0)
		{
			static Float:AMT; pev(Ent, pev_renderamt, AMT)
			static Float:RealAMT; 
			
			AMT -= 10.0
			RealAMT = float(max(floatround(AMT), 0))
			
			set_pev(Ent, pev_renderamt, RealAMT)
		} else {
			engfunc(EngFunc_RemoveEntity, Ent)
			return
		}
	}
	if(pev(Ent, pev_frame) >= pev(Ent, pev_totalframe)) 
		set_pev(Ent, pev_frame, 0.0)
	
	// Set Attachment
	static Float:Origin[3]; pev(Owner, pev_origin, Origin)
	
	if(!(pev(Owner, pev_flags) & FL_DUCKING)) Origin[2] += 36.0
	else Origin[2] += 26.0
	
	engfunc(EngFunc_SetOrigin, Ent, Origin)
	
	// Force Think
	set_pev(Ent, pev_nextthink, get_gametime() + 0.05)
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
stock make_bullet(id, Float:Origin[3])
{
	// Find target
	new decal = random_num(41, 45)
	const loop_time = 2
	
	static Body, Target
	get_user_aiming(id, Target, Body, 999999)
	
	if(is_user_connected(Target))
		return
	
	for(new i = 0; i < loop_time; i++)
	{
		// Put decal on "world" (a wall)
		message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
		write_byte(TE_WORLDDECAL)
		engfunc(EngFunc_WriteCoord, Origin[0])
		engfunc(EngFunc_WriteCoord, Origin[1])
		engfunc(EngFunc_WriteCoord, Origin[2])
		write_byte(decal)
		message_end()
		
		// Show sparcles
		message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
		write_byte(TE_GUNSHOTDECAL)
		engfunc(EngFunc_WriteCoord, Origin[0])
		engfunc(EngFunc_WriteCoord, Origin[1])
		engfunc(EngFunc_WriteCoord, Origin[2])
		write_short(id)
		write_byte(decal)
		message_end()
	}
}

stock fake_smoke(id, trace_result)
{
	static Float:vecSrc[3], Float:vecEnd[3], TE_FLAG
	
	get_weapon_attachment(id, vecSrc)
	global_get(glb_v_forward, vecEnd)
    
	xs_vec_mul_scalar(vecEnd, 8192.0, vecEnd)
	xs_vec_add(vecSrc, vecEnd, vecEnd)

	get_tr2(trace_result, TR_vecEndPos, vecSrc)
	get_tr2(trace_result, TR_vecPlaneNormal, vecEnd)
    
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
	write_short(g_SmokePuff_Id)
	write_byte(2)
	write_byte(50)
	write_byte(TE_FLAG)
	message_end()
}

stock get_weapon_attachment(id, Float:output[3], Float:fDis = 40.0)
{ 
	new Float:vfEnd[3], viEnd[3] 
	get_user_origin(id, viEnd, 3)  
	IVecFVec(viEnd, vfEnd) 
	
	new Float:fOrigin[3], Float:fAngle[3]
	
	pev(id, pev_origin, fOrigin) 
	pev(id, pev_view_ofs, fAngle)
	
	xs_vec_add(fOrigin, fAngle, fOrigin) 
	
	new Float:fAttack[3]
	
	xs_vec_sub(vfEnd, fOrigin, fAttack)
	xs_vec_sub(vfEnd, fOrigin, fAttack) 
	
	new Float:fRate
	
	fRate = fDis / vector_length(fAttack)
	xs_vec_mul_scalar(fAttack, fRate, fAttack)
	
	xs_vec_add(fOrigin, fAttack, output)
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
