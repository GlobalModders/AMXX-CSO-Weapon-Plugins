#include <amxmodx>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <cstrike>
#include <fun>

#define PLUGIN "[CSO] Janus-11"
#define VERSION "1.0"
#define AUTHOR "Dias Pendragon"

#define DAMAGE_A 140 // 140 for zombie, 70 for human
#define DAMAGE_B 560 // 560 for zombie, 280 for human

#define CLIP 15
#define BPAMMO 64

#define SPEED_A 0.85
#define SPEED_B 0.5

#define CHARGE_AMMO 15
#define TIME_ACTIVATE 10
#define TIME_USAGE 7

#define V_MODEL "models/v_janus11.mdl"
#define P_MODEL "models/p_janus11.mdl"
#define W_MODEL "models/w_janus11.mdl"

new const WeaponSounds[7][] =
{
	"weapons/janus11-1.wav",
	"weapons/janus11-2.wav",
	"weapons/janus11_draw.wav",
	"weapons/janus11_insert.wav",
	"weapons/janus11_after_reload.wav",
	"weapons/janus11_change1.wav",
	"weapons/janus11_change2.wav"
}

new const WeaponResources[3][] =
{
	"sprites/weapon_janus11.txt",
	"sprites/640hud13_2.spr",
	"sprites/640hud107_2.spr"
}

#define CSW_JANUS11 CSW_M3 
#define weapon_janus11 "weapon_m3"

#define WEAPON_SECRETCODE 1162014
#define OLD_W_MODEL "models/w_m3.mdl"
#define OLD_EVENT "events/m3.sc"

#define TASK_REMOVE 2828

enum
{
	ANIM_IDLE = 0,
	ANIM_ACTIVATE,
	ANIM_SHOOT1,
	ANIM_INSERT,
	ANIM_AFTER,
	ANIM_START,
	ANIM_DRAW, 
	
	ANIM_IDLE2,
	ANIM_SHOOT2,
	ANIM_DRAW2,
	ANIM_UNACTIVATE,
	
	ANIM_IDLE_SIGNAL,
	ANIM_INSERT_SIGNAL,
	ANIM_AFTER_SIGNAL,
	ANIM_START_SIGNAL,
	ANIM_SHOOT_SIGNAL,
	ANIM_DRAW_SIGNAL
}

enum
{
	JANUS_NORMAL = 0,
	JANUS_SIGNAL,
	JANUS_ACTIVATE
}

// MACROS
#define Get_BitVar(%1,%2) (%1 & (1 << (%2 & 31)))
#define Set_BitVar(%1,%2) %1 |= (1 << (%2 & 31))
#define UnSet_BitVar(%1,%2) %1 &= ~(1 << (%2 & 31))

new g_Had_Janus11, g_Janus_Mode[33], g_ChargedAmmo[33], g_OldWeapon[33]
new g_HamBot, g_MsgWeaponList, g_MsgCurWeapon, g_Event_Janus11, g_SmokePuff_Id, m_spriteTexture

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

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)

	register_event("CurWeapon", "Event_CurWeapon", "be", "1=1")
	
	register_forward(FM_SetModel, "fw_SetModel")
	register_forward(FM_CmdStart, "fw_CmdStart")
	register_forward(FM_UpdateClientData, "fw_UpdateClientData_Post", 1)	
	register_forward(FM_PlaybackEvent, "fw_PlaybackEvent")	
	
	// Safety
	Register_SafetyFunc()
	
	RegisterHam(Ham_TraceAttack, "player", "fw_TraceAttack")
	RegisterHam(Ham_TraceAttack, "worldspawn", "fw_TraceAttack")		
	
	RegisterHam(Ham_Item_Deploy, weapon_janus11, "fw_Item_Deploy_Post", 1)	
	RegisterHam(Ham_Item_AddToPlayer, weapon_janus11, "fw_Item_AddToPlayer_Post", 1)
	RegisterHam(Ham_Item_PostFrame, weapon_janus11, "fw_Item_PostFrame")
	RegisterHam(Ham_Weapon_WeaponIdle, weapon_janus11, "fw_Weapon_WeaponIdle")	
	RegisterHam(Ham_Weapon_WeaponIdle, weapon_janus11, "fw_Weapon_WeaponIdle_Post", 1)	
	
	// Cache
	g_MsgWeaponList = get_user_msgid("WeaponList")
	g_MsgCurWeapon = get_user_msgid("CurWeapon")
	
	register_clcmd("weapon_janus11", "Hook_Weapon")
	register_clcmd("say /get", "Get_Janus11")
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
	
	register_forward(FM_PrecacheEvent, "fw_PrecacheEvent_Post", 1)	
	
	m_spriteTexture = precache_model("sprites/laserbeam.spr")
	g_SmokePuff_Id = engfunc(EngFunc_PrecacheModel, "sprites/wall_puff1.spr")
}

public fw_PrecacheEvent_Post(type, const name[])
{
	if(equal(OLD_EVENT, name))
		g_Event_Janus11 = get_orig_retval()
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

public Get_Janus11(id)
{
	Remove_Janus11(id)
	
	Set_BitVar(g_Had_Janus11, id)
	
	g_Janus_Mode[id] = JANUS_NORMAL
	g_ChargedAmmo[id] = 0
	
	give_item(id, weapon_janus11)
	cs_set_user_bpammo(id, CSW_JANUS11, BPAMMO)
	
	static Ent; Ent = fm_get_user_weapon_entity(id, CSW_JANUS11)
	if(pev_valid(Ent)) cs_set_weapon_ammo(Ent, CLIP)
	
	engfunc(EngFunc_MessageBegin, MSG_ONE_UNRELIABLE, g_MsgCurWeapon, {0, 0, 0}, id)
	write_byte(1)
	write_byte(CSW_JANUS11)
	write_byte(CLIP)
	message_end()
}

public Remove_Janus11(id)
{
	UnSet_BitVar(g_Had_Janus11, id)
	
	g_Janus_Mode[id] = JANUS_NORMAL
	g_ChargedAmmo[id] = 0
	
	remove_task(id+TASK_REMOVE)
}

public Hook_Weapon(id)
{
	engclient_cmd(id, weapon_janus11)
	return PLUGIN_HANDLED
}

public Event_CurWeapon(id)
{
	if(!is_player(id, 1))
		return
	
	static CSWID; CSWID = read_data(2)

	if((CSWID == CSW_JANUS11 && g_OldWeapon[id] == CSW_JANUS11) && Get_BitVar(g_Had_Janus11, id)) 
	{
		static Ent; Ent = fm_get_user_weapon_entity(id, CSW_JANUS11)
		if(pev_valid(Ent)) 
		{
			switch(g_Janus_Mode[id])
			{
				case JANUS_NORMAL: 
				{
					set_pdata_float(Ent, 46, get_pdata_float(Ent, 46, 4) * SPEED_A, 4)
					set_pdata_float(Ent, 47, get_pdata_float(Ent, 46, 4) * SPEED_A, 4)
				}
				case JANUS_SIGNAL: 
				{
					set_pdata_float(Ent, 46, get_pdata_float(Ent, 46, 4) * SPEED_A, 4)
					set_pdata_float(Ent, 47, get_pdata_float(Ent, 46, 4) * SPEED_A, 4)
				}
				case JANUS_ACTIVATE: 
				{
					set_pdata_float(Ent, 46, get_pdata_float(Ent, 46, 4) * SPEED_B, 4)
					set_pdata_float(Ent, 47, get_pdata_float(Ent, 46, 4) * SPEED_B, 4)
					
					cs_set_weapon_ammo(Ent, cs_get_weapon_ammo(Ent) + 1)
				}
			}
			
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
		weapon = fm_get_user_weapon_entity(entity, CSW_JANUS11)
		
		if(!pev_valid(weapon))
			return FMRES_IGNORED
		
		if(Get_BitVar(g_Had_Janus11, id))
		{
			set_pev(weapon, pev_impulse, WEAPON_SECRETCODE)
			set_pev(weapon, pev_iuser4, g_ChargedAmmo[id])
			engfunc(EngFunc_SetModel, entity, W_MODEL)
			
			Remove_Janus11(id)
			
			return FMRES_SUPERCEDE
		}
	}

	return FMRES_IGNORED;
}

public fw_CmdStart(id, uc_handle, seed)
{
	if(!is_player(id, 1))
		return
	if(get_player_weapon(id) != CSW_JANUS11 || !Get_BitVar(g_Had_Janus11, id))
		return
		
	static NewButton; NewButton = get_uc(uc_handle, UC_Buttons)
	static OldButton; OldButton = pev(id, pev_oldbuttons)
	
	static Ent; Ent = fm_get_user_weapon_entity(id, CSW_JANUS11)
	
	if(NewButton & IN_RELOAD)
	{
		if(g_Janus_Mode[id] != JANUS_ACTIVATE)
			return
		
		if(pev_valid(Ent)) set_pdata_int(Ent, 54, 0, 4)
		
		NewButton &= ~IN_RELOAD
		set_uc(uc_handle, UC_Buttons, NewButton)
		
		return
	}
	
	if((NewButton & IN_ATTACK2) && !(OldButton & IN_ATTACK2))
	{
		if(g_Janus_Mode[id] != JANUS_SIGNAL)
			return
			
		remove_task(id+TASK_REMOVE)
		g_Janus_Mode[id] = JANUS_ACTIVATE
		
		Set_WeaponAnim(id, ANIM_ACTIVATE)
		
		Set_Player_NextAttack(id, 1.5)
		Set_Weapon_Idle(id, CSW_JANUS11, 1.5)
		
		
		if(pev_valid(Ent) && !cs_get_weapon_ammo(Ent)) cs_set_weapon_ammo(Ent, 1)
	
		set_task(float(TIME_USAGE), "TurnOff_Janus", id+TASK_REMOVE)
	}
}

public fw_UpdateClientData_Post(id, sendweapons, cd_handle)
{
	if(!is_player(id, 1))
		return FMRES_IGNORED	
	if(get_player_weapon(id) == CSW_JANUS11 && Get_BitVar(g_Had_Janus11, id))
		set_cd(cd_handle, CD_flNextAttack, get_gametime() + 0.001) 
	
	return FMRES_HANDLED
}

public fw_PlaybackEvent(flags, invoker, eventid, Float:delay, Float:origin[3], Float:angles[3], Float:fparam1, Float:fparam2, iParam1, iParam2, bParam1, bParam2)
{
	if (!is_player(invoker, 0))
		return FMRES_IGNORED		
	if(get_player_weapon(invoker) == CSW_JANUS11 && Get_BitVar(g_Had_Janus11, invoker) && eventid == g_Event_Janus11)
	{
		engfunc(EngFunc_PlaybackEvent, flags | FEV_HOSTONLY, invoker, eventid, delay, origin, angles, fparam1, fparam2, iParam1, iParam2, bParam1, bParam2)	

		switch(g_Janus_Mode[invoker])
		{
			case JANUS_NORMAL: 
			{
				g_ChargedAmmo[invoker]++
		
				if(g_ChargedAmmo[invoker] >= CHARGE_AMMO)
				{
					Janus11_Signal(invoker)
						
					Set_WeaponAnim(invoker, ANIM_SHOOT_SIGNAL)
					g_ChargedAmmo[invoker] = 0
				} else {
					Set_WeaponAnim(invoker, ANIM_SHOOT1)
				}

				emit_sound(invoker, CHAN_WEAPON, WeaponSounds[0], 1.0, ATTN_NORM, 0, PITCH_LOW)	
			}
			
			case JANUS_SIGNAL: 
			{
				Set_WeaponAnim(invoker, ANIM_SHOOT_SIGNAL)
				emit_sound(invoker, CHAN_WEAPON, WeaponSounds[0], 1.0, ATTN_NORM, 0, PITCH_LOW)	
			}
			case JANUS_ACTIVATE: 
			{
				Set_WeaponAnim(invoker, ANIM_SHOOT2)
				emit_sound(invoker, CHAN_WEAPON, WeaponSounds[1], 1.0, ATTN_NORM, 0, PITCH_LOW)	
			}
		}
	
		return FMRES_SUPERCEDE
	}
	
	return FMRES_HANDLED
}

public Janus11_Signal(id)
{
	g_Janus_Mode[id] = JANUS_SIGNAL
	
	remove_task(id+TASK_REMOVE)
	set_task(float(TIME_ACTIVATE), "TurnOff_Janus", id+TASK_REMOVE)
}

public TurnOff_Janus(id)
{
	id -= TASK_REMOVE
	
	if(!is_player(id, 0))
		return
		
	g_Janus_Mode[id] = JANUS_NORMAL
	if(!is_player(id, 1))
		return
	if(get_player_weapon(id) != CSW_JANUS11 || !Get_BitVar(g_Had_Janus11, id))
		return
		
	Set_WeaponAnim(id, ANIM_UNACTIVATE)
		
	Set_Weapon_Idle(id, CSW_JANUS11, 1.5)
	Set_Player_NextAttack(id, 1.5)
}

public fw_TraceAttack(Ent, Attacker, Float:Damage, Float:Dir[3], ptr, DamageType)
{
	if(!is_player(Attacker, 0))
		return HAM_IGNORED	
	if(get_player_weapon(Attacker) != CSW_JANUS11 || !Get_BitVar(g_Had_Janus11, Attacker))
		return HAM_IGNORED
		
	static Float:flEnd[3], Float:vecPlane[3]
	
	get_tr2(ptr, TR_vecEndPos, flEnd)
	get_tr2(ptr, TR_vecPlaneNormal, vecPlane)		
		
	if(!is_player(Ent, 0))
	{
		make_bullet(Attacker, flEnd)
		fake_smoke(Attacker, ptr)
	}
	
	switch(g_Janus_Mode[Attacker])
	{
		case JANUS_NORMAL: SetHamParamFloat(3, float(DAMAGE_A) / 6.0)
		case JANUS_SIGNAL: SetHamParamFloat(3, float(DAMAGE_A) / 6.0)
		case JANUS_ACTIVATE: 
		{
			static Float:Start[3]
			get_position(Attacker, 30.0, 8.0, -5.0, Start)
			
			message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
			write_byte(TE_BEAMPOINTS)
			write_coord_f(Start[0]) 
			write_coord_f(Start[1]) 
			write_coord_f(Start[2]) 
			write_coord_f(flEnd[0]) 
			write_coord_f(flEnd[1]) 
			write_coord_f(flEnd[2]) 
			write_short(m_spriteTexture)
			write_byte(0) // framerate
			write_byte(0) // framerate
			write_byte(5) // life
			write_byte(7)  // width
			write_byte(0)   // noise
			write_byte(255)   // r, g, b
			write_byte(85)   // r, g, b
			write_byte(0)   // r, g, b
			write_byte(255)	// brightness
			write_byte(0)		// speed 
			message_end()
			
			SetHamParamFloat(3, float(DAMAGE_B) / 6.0)
		}
	}
	
	return HAM_HANDLED	
}

public fw_Item_Deploy_Post(Ent)
{
	if(pev_valid(Ent) != 2)
		return
	static Id; Id = get_pdata_cbase(Ent, 41, 4)
	if(get_pdata_cbase(Id, 373) != Ent)
		return
	if(!Get_BitVar(g_Had_Janus11, Id))
		return

	set_pev(Id, pev_viewmodel2, V_MODEL)
	set_pev(Id, pev_weaponmodel2, P_MODEL)
	
	switch(g_Janus_Mode[Id])
	{
		case JANUS_NORMAL: Set_WeaponAnim(Id, ANIM_DRAW)
		case JANUS_SIGNAL: Set_WeaponAnim(Id, ANIM_DRAW_SIGNAL)
		case JANUS_ACTIVATE: Set_WeaponAnim(Id, ANIM_DRAW2)
	}
}

public fw_Item_AddToPlayer_Post(ent, id)
{
	if(pev(ent, pev_impulse) == WEAPON_SECRETCODE)
	{
		Set_BitVar(g_Had_Janus11, id)
		
		set_pev(ent, pev_impulse, 0)
		g_ChargedAmmo[id] = pev(ent, pev_iuser4)
	}			
	
	message_begin(MSG_ONE_UNRELIABLE, g_MsgWeaponList, _, id)
	write_string(Get_BitVar(g_Had_Janus11, id) ? "weapon_janus11" : weapon_janus11)
	write_byte(5)
	write_byte(32)
	write_byte(-1)
	write_byte(-1)
	write_byte(0)
	write_byte(5)
	write_byte(CSW_JANUS11)
	write_byte(0)
	message_end()
}

public fw_Weapon_WeaponIdle( iEnt )
{
	if(pev_valid(iEnt) != 2)
		return 
	static id; id = get_pdata_cbase(iEnt, m_pPlayer, XTRA_OFS_WEAPON)
	if(get_pdata_cbase(id, 373) != iEnt)
		return
	if(!Get_BitVar(g_Had_Janus11, id))
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
			switch(g_Janus_Mode[id])
			{
				case JANUS_NORMAL: Set_WeaponAnim(id, ANIM_AFTER)
				case JANUS_SIGNAL: Set_WeaponAnim(id, ANIM_AFTER_SIGNAL)
				// case JANUS_ACTIVATE: Set_WeaponAnim(id, ANIM_AFTER2)
			}

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
	if(!Get_BitVar(g_Had_Janus11, id))
		return
		
	static SpecialReload; SpecialReload = get_pdata_int(iEnt, 55, 4)
	if(!SpecialReload && get_pdata_float(iEnt, 48, 4) <= 0.25)
	{
		switch(g_Janus_Mode[id])
		{
			case JANUS_NORMAL: Set_WeaponAnim(id, ANIM_IDLE)
			case JANUS_SIGNAL: Set_WeaponAnim(id, ANIM_IDLE_SIGNAL)
			case JANUS_ACTIVATE: Set_WeaponAnim(id, ANIM_IDLE2)
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
			switch(g_Janus_Mode[id])
			{
				case JANUS_NORMAL: Set_WeaponAnim(id, ANIM_INSERT)
				case JANUS_SIGNAL: Set_WeaponAnim(id, ANIM_INSERT_SIGNAL)
				//case JANUS_ACTIVATE: Set_WeaponAnim(id, ANIM_START2)
			}
			
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
			switch(g_Janus_Mode[id])
			{
				case JANUS_NORMAL: Set_WeaponAnim(id, ANIM_START)
				case JANUS_SIGNAL: Set_WeaponAnim(id, ANIM_START_SIGNAL)
				//case JANUS_ACTIVATE: Set_WeaponAnim(id, ANIM_START2)
			}
		
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
			
			/*
			//emit_sound(id, CHAN_ITEM, random_num(0,1) ? "weapons/reload1.wav" : "weapons/reload3.wav", 1.0, ATTN_NORM, 0, 85 + random_num(0,0x1f))
			switch(g_Janus_Mode[id])
			{
				case JANUS_NORMAL: Set_WeaponAnim(id, ANIM_INSERT)
				case JANUS_SIGNAL: Set_WeaponAnim(id, ANIM_INSERT_SIGNAL)
				//case JANUS_ACTIVATE: Set_WeaponAnim(id, ANIM_START2)
			}*/

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
