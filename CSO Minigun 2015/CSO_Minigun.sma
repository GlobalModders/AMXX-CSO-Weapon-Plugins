#include <amxmodx>
#include <fakemeta>
#include <fakemeta_util>
#include <cstrike>
#include <hamsandwich>

#define HoldCBaseWeapon(%0)	(get_user_weapon(%0) == g_iWeaponID  && g_pWeaponA[ %0 ])
#define IsValidPrivateData(%0)	(pev_valid(%0) == 2)
#define VectorAdd(%1,%2,%3)      (%3[ 0 ] = %1[ 0 ] + %2[ 0 ], %3[ 1 ] = %1[ 1 ] + %2[ 1 ], %3[ 2 ] = %1[ 2 ] + %2[ 2 ])

new const WEAPON_SOUND_FIRE[] = "weapons/m134-1.wav"
new const WEAPON_SOUND_SPINDOWN[] = "weapons/m134_spindown.wav"
new const WEAPON_SOUND_SPINUP[] = "weapons/m134_spinup.wav"
new const SHELL_MODEL[] = "models/shellx.mdl"
new const SHELL2_MODEL[] = "models/shell2x.mdl"

new const WEAPON_LIST[] = "weapon_m134"
new const WEAPON_BASE_NAME[] = "weapon_m249"

const Float: RELOAD_TIME = 5.0

const AMMO_WEAPON = 200
const CLIP_WEAPON = 100
const Float:WEAPON_DAMAGE = 2.0
const Float:WEAPON_SPEED = 0.075 

new const V_MODEL[] = "models/v_m134x.mdl"
new const P_MODEL[] = "models/p_m134x.mdl"
new const W_MODEL[] = "models/w_m134x.mdl"

new const HUD_SPRITES[][] = 
{
	"sprites/640hud26_2.spr",
	"sprites/640hud35_2.spr"
}

new const TRACE_ATTACK[][] = 
{
	"func_breakable", 
	"func_wall", 
	"func_door",
	"func_plat", 
	"func_rotating", 
	"worldspawn" 
}

const OFFSET_WEAPONOWNER = 41
const OFFSET_LINUX = 5
const OFFSET_LINUX_WEAPONS = 4

const WEAP_KEY = 545464464

const m_flNextPrimaryAttack = 46
const m_iClip =	51
const m_flNextAttack = 83
const m_flTimeWeaponIdle = 48
const m_flStartThrow = 30

enum (<<=1)
{
	DROP_PRIMARY = 1,
	DROP_SECONDARY
}

enum (<<=1)
{
	v_angle = 1,
	punchangle,
	angles
};	

enum _:eDataShell
{
	SHELL_1 , 
	SHELL_2
}

const IDLE = 0 
const RELOAD = 1
const DRAW = 2
const SHOOT_1 = 3
const SHOOT_END = 6
const SHOOT_START = 5

new const GUNSHOT_DECALS[] = { 41, 42, 43, 44, 45 }
new g_iForwardIndex, g_pWeaponA[MAX_PLAYERS + 1], g_iWeaponID = 0, g_iShell[eDataShell], bool:g_iRun[MAX_PLAYERS + 1]

const WEAPONS_PRIMARY_BITSUM = (1<<CSW_SCOUT)|(1<<CSW_XM1014)|(1<<CSW_MAC10)|(1<<CSW_AUG)|(1<<CSW_UMP45)|(1<<CSW_SG550)|(1<<CSW_GALIL)|(1<<CSW_FAMAS)|(1<<CSW_AWP)|(1<<CSW_MP5NAVY)|(1<<CSW_M249)|(1<<CSW_M3)|(1<<CSW_M4A1)|(1<<CSW_TMP)|(1<<CSW_G3SG1)|(1<<CSW_SG552)|(1<<CSW_AK47)|(1<<CSW_P90);
const WEAPONS_SECONDARY_BITSUM = (1<<CSW_P228)|(1<<CSW_ELITE)|(1<<CSW_FIVESEVEN)|(1<<CSW_USP)|(1<<CSW_GLOCK18)|(1<<CSW_DEAGLE);
new Float:g_Time[33], g_Heavy, g_M134

public plugin_init()
{
	register_plugin("[CSO] Minigun " , "1.0", "Remade by Dias")
	
	register_forward(FM_CmdStart, "fw_CmdStart")
	register_forward(FM_SetModel, "Forward_SetModel")
	register_forward(FM_UpdateClientData, "Forward_UpdateClientData", 1)
	register_forward(FM_PlayerPreThink , "Forward_PlayerPreThink", 0)
	
	RegisterHam(Ham_Item_AddToPlayer, WEAPON_BASE_NAME, "fw_AddToPlayer_Post" , true);
	RegisterHam(Ham_Item_Deploy, WEAPON_BASE_NAME , "fw_Deploy_Post",  true);
	RegisterHam(Ham_Weapon_PrimaryAttack, WEAPON_BASE_NAME, "fw_PrimaryAttack_Pre" , false)
	RegisterHam(Ham_Item_PostFrame, WEAPON_BASE_NAME, "fw_PostFrame_Pre" , false);
	RegisterHam(Ham_Weapon_Reload, WEAPON_BASE_NAME, "fw_Reload_Pre" , false);
	RegisterHam(Ham_Weapon_WeaponIdle, WEAPON_BASE_NAME,  "fw_Idle_Pre",	false);
	RegisterHam(Ham_TraceAttack, "player", "fw_TraceAttack_Pre", false);
	
	for(new i = 0 ; i < sizeof TRACE_ATTACK; i++)
		 RegisterHam(Ham_TraceAttack, TRACE_ATTACK[i], "fw_TraceAttack_Post", 1)

	g_iWeaponID = get_weaponid(WEAPON_BASE_NAME)	 
		 
	register_clcmd("say /get", "Get_What")
	register_clcmd(WEAPON_LIST, "Weapon_Hook")
}

public plugin_precache()
{
	precache_model(V_MODEL)
	precache_model(P_MODEL)
	precache_model(W_MODEL)
	PRECACHE_SOUNDS_FROM_MODEL(V_MODEL)
	
	g_iShell[SHELL_1] = precache_model(SHELL_MODEL)
	g_iShell[SHELL_2] = precache_model(SHELL2_MODEL)
	
	precache_sound(WEAPON_SOUND_SPINDOWN)
	precache_sound(WEAPON_SOUND_FIRE)
	precache_sound(WEAPON_SOUND_SPINUP)
	
	for(new iFile = 0 ; iFile < sizeof HUD_SPRITES; iFile++) 
		precache_generic(HUD_SPRITES[iFile])
	
	static szFile [128]; formatex(szFile, charsmax(szFile) , "sprites/%s.txt" , WEAPON_LIST)
	precache_generic(szFile)
}

public Get_What(id)
{
	 DropWeapons(id, DROP_PRIMARY)
	 
	 g_pWeaponA[id]  = true
	 static Ent; Ent = fm_give_item(id , WEAPON_BASE_NAME)
	 if(Ent > 0) cs_set_weapon_ammo(Ent, CLIP_WEAPON)
	 
	 cs_set_user_bpammo(id, g_iWeaponID, AMMO_WEAPON)
	 WeaponList(id, WEAPON_LIST, 3, AMMO_WEAPON, -1, -1, 0, 4, g_iWeaponID, 0)
}

public Weapon_Hook(id) 
{
	engclient_cmd(id, WEAPON_BASE_NAME)
	return PLUGIN_HANDLED
}

public zeli_user_infected(id, ClassID) g_pWeaponA[id] = false
public zeli_user_spawned(id, ClassID) g_pWeaponA[id] = false
public client_disconnect(id) g_pWeaponA[id]  = false;

public zeli_weapon_selected(id, ItemID, ClassID)
{
	if(ItemID == g_M134) Get_What(id)
}

public zeli_weapon_removed(id, ItemID)
{
	if(ItemID == g_M134)  g_pWeaponA[id]  = false
}

public Forward_SetModel(Ent, const pModel[])
{
	if(!pev_valid(Ent)) 
		return FMRES_IGNORED
	
	static szClassName[33]
	pev(Ent, pev_classname, szClassName, charsmax(szClassName))
		
	if(!equal(szClassName, "weaponbox"))
		return FMRES_IGNORED;
	
	static pOwner, pModel
	pModel = fm_find_ent_by_owner(-1, WEAPON_BASE_NAME, Ent)
	pOwner = pev(Ent, pev_owner)
	
	if(g_pWeaponA[pOwner] && pev_valid(pModel))
	{
		set_pev(pModel, pev_impulse, WEAP_KEY)
		engfunc(EngFunc_SetModel, Ent, W_MODEL)
		
		g_pWeaponA[pOwner] = false
		return FMRES_SUPERCEDE
	}

	return FMRES_IGNORED
}

public Forward_UpdateClientData(id , SendWeapons, CD_Handle)
{
	if (!HoldCBaseWeapon(id))
		return HAM_IGNORED

	static Float:fGametime; fGametime = get_gametime()
	set_cd(CD_Handle, CD_flNextAttack, fGametime + 0.001)

	return FMRES_HANDLED
}

public Forward_PlayBackEvent(flags, invoker, eventindex, Float:delay, Float:origin[3], Float:fvangles[3], Float:fparam1, Float:fparam2, iParam1, iParam2, bParam1, bParam2)
{
	return FMRES_SUPERCEDE
} 

public Forward_PlayerPreThink(pId)
{
	if(!is_user_alive(pId) || zp_get_user_zombie(pId) || !HoldCBaseWeapon(pId))
		return FMRES_IGNORED
	
	return FMRES_IGNORED
}

public fw_AddToPlayer_Post(Ent , id)
{
	if(!pev_valid(Ent) && !is_user_connected(id)) 
		 return HAM_IGNORED
	
	if(pev(Ent, pev_impulse) == WEAP_KEY)
	{
		g_pWeaponA[id] = true
		WeaponList(id, WEAPON_LIST, 3 , AMMO_WEAPON , -1 , -1 , 0 , 4  , g_iWeaponID , 0)

		return HAM_IGNORED  ;
	} else {
		WeaponList(id, WEAPON_BASE_NAME , 3 , AMMO_WEAPON , -1 , -1 , 0 , 4  , g_iWeaponID , 0)
	}	

	return HAM_IGNORED
}

public fw_Deploy_Post(Ent)
{
	if(!IsValidPrivateData(Ent))
	{
                return HAM_IGNORED;
	}
	
	static pId ;
	pId = get_pdata_cbase(Ent , OFFSET_WEAPONOWNER , OFFSET_LINUX_WEAPONS);
	
	if (!g_pWeaponA[ pId ])
	{
		return HAM_IGNORED;
	}	
	
	set_pev(pId, pev_viewmodel2, V_MODEL);
	set_pev(pId, pev_weaponmodel2, P_MODEL);
	
	set_pdata_float(pId, m_flNextAttack, 1.0, OFFSET_LINUX);
	set_pdata_float(Ent, m_flTimeWeaponIdle, 1.0 , OFFSET_LINUX_WEAPONS);
	set_pdata_float(Ent , m_flStartThrow , 0.0 , OFFSET_LINUX_WEAPONS);
	
	SendWeaponAnim(pId, DRAW);
	
	return HAM_IGNORED ;
}

public fw_CmdStart(id, uc_handle, seed)
{
	static CurButton; CurButton = get_uc(uc_handle, UC_Buttons)
	
	if((CurButton & IN_ATTACK))
		return
	if(!(CurButton & IN_ATTACK2))
		return
		
	if(get_gametime() - 0.05 <= g_Time[id])
		return
		
	g_Time[id] = get_gametime()
		
	static Ent; Ent = fm_get_user_weapon_entity(id, CSW_M249)
	if(!IsValidPrivateData(Ent))
		return

	static 	pId  ; pId = get_pdata_cbase(Ent , OFFSET_WEAPONOWNER , OFFSET_LINUX_WEAPONS);
	static iClip ; iClip = get_pdata_int(Ent, m_iClip, OFFSET_LINUX_WEAPONS);
	static Float:i_mSpinTime ;i_mSpinTime  = get_pdata_float(Ent ,m_flStartThrow , OFFSET_LINUX_WEAPONS);

	if (!HoldCBaseWeapon(pId))
		return
	
	g_iForwardIndex = register_forward(FM_PlaybackEvent, "Forward_PlayBackEvent" , false);
	
	if(iClip <= 0)
	{
		if(i_mSpinTime)
		{
			emit_sound(pId , CHAN_WEAPON , WEAPON_SOUND_SPINDOWN , 1.0 , ATTN_NORM , 0 , PITCH_NORM) ;
			
			SendWeaponAnim(pId , SHOOT_END);
			set_pdata_float(Ent ,m_flStartThrow , 0.0 , OFFSET_LINUX_WEAPONS);
			
			g_iRun[ pId ]	=	false ;
		}
		
		return 
	}
	
	if(i_mSpinTime <= 0.0)
	{
		emit_sound(pId , CHAN_WEAPON , WEAPON_SOUND_SPINUP , 1.0 , ATTN_NORM , 0 , PITCH_NORM) ;
		
		SendWeaponAnim(pId ,SHOOT_START);
		i_mSpinTime += 0.1;
	}
	else if(i_mSpinTime <= 1.1)
	{
		i_mSpinTime += 0.1;
	}
	else if(i_mSpinTime > 1.1)
	{
		/*
		ExecuteHam(Ham_Weapon_PrimaryAttack, Ent);

		emit_sound(pId, CHAN_WEAPON, WEAPON_SOUND_FIRE, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
		SendWeaponAnim(pId, SHOOT_1);
		EjectBrass(pId, g_iShell[ SHELL_1 ] , -9.0, 17.0, -3.0 , -10.0 , -50.0);
		EjectBrass(pId, g_iShell[ SHELL_2 ] , -9.0, 17.0, 8.0 , 10.0 , 50.0);
		
		UTIL_ScreenShake(pId, (1 << 12) * 1, (1 << 12) * 1, (1 << 12) * 1);*/
		SendWeaponAnim(pId, 6);
		emit_sound(pId , CHAN_WEAPON , WEAPON_SOUND_SPINUP , 1.0 , ATTN_NORM , 0 , PITCH_NORM) ;
		g_iRun[ pId ]	=	true 
	}
	
	set_pdata_float(Ent , m_flStartThrow , i_mSpinTime , OFFSET_LINUX_WEAPONS);
	set_pdata_float(Ent, m_flNextPrimaryAttack , WEAPON_SPEED , OFFSET_LINUX_WEAPONS);
	set_pdata_float(Ent, m_flTimeWeaponIdle, WEAPON_SPEED   , OFFSET_LINUX_WEAPONS);
	
	unregister_forward(FM_PlaybackEvent, g_iForwardIndex , false);
}

public fw_PrimaryAttack_Pre(Ent)
{
	if(!IsValidPrivateData(Ent))
	{
		return HAM_IGNORED;
	}

	static 	pId  ; pId = get_pdata_cbase(Ent , OFFSET_WEAPONOWNER , OFFSET_LINUX_WEAPONS);
	static iClip ; iClip = get_pdata_int(Ent, m_iClip, OFFSET_LINUX_WEAPONS);
	static Float:i_mSpinTime ;i_mSpinTime  = get_pdata_float(Ent ,m_flStartThrow , OFFSET_LINUX_WEAPONS);

	if (!HoldCBaseWeapon(pId))
	{
		return HAM_IGNORED;
	}
	
	g_iForwardIndex = register_forward(FM_PlaybackEvent, "Forward_PlayBackEvent" , false);
	
	if(iClip <= 0)
	{
		if(i_mSpinTime)
		{
			emit_sound(pId , CHAN_WEAPON , WEAPON_SOUND_SPINDOWN , 1.0 , ATTN_NORM , 0 , PITCH_NORM) ;
			
			SendWeaponAnim(pId , SHOOT_END);
			set_pdata_float(Ent ,m_flStartThrow , 0.0 , OFFSET_LINUX_WEAPONS);
			
			g_iRun[ pId ]	=	false ;
		}
		
		return HAM_IGNORED;
	}
	
	if(i_mSpinTime <= 0.0)
	{
		emit_sound(pId , CHAN_WEAPON , WEAPON_SOUND_SPINUP , 1.0 , ATTN_NORM , 0 , PITCH_NORM) ;
		
		SendWeaponAnim(pId ,SHOOT_START);
		i_mSpinTime += 0.1;
	}
	else if(i_mSpinTime <= 1.1)
	{
		i_mSpinTime += 0.1;
	}
	else if(i_mSpinTime > 1.1)
	{
		ExecuteHam(Ham_Weapon_PrimaryAttack, Ent);

		emit_sound(pId, CHAN_WEAPON, WEAPON_SOUND_FIRE, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
		SendWeaponAnim(pId, SHOOT_1);
		EjectBrass(pId, g_iShell[ SHELL_1 ] , -9.0, 17.0, -3.0 , -10.0 , -50.0);
		EjectBrass(pId, g_iShell[ SHELL_2 ] , -9.0, 17.0, 8.0 , 10.0 , 50.0);
		
		UTIL_ScreenShake(pId, (1 << 12) * 1, (1 << 12) * 1, (1 << 12) * 1);
		
		g_iRun[ pId ]	=	true ;
	}
	
	set_pdata_float(Ent , m_flStartThrow , i_mSpinTime , OFFSET_LINUX_WEAPONS);
	set_pdata_float(Ent, m_flNextPrimaryAttack , WEAPON_SPEED , OFFSET_LINUX_WEAPONS);
	set_pdata_float(Ent, m_flTimeWeaponIdle, WEAPON_SPEED   , OFFSET_LINUX_WEAPONS);
	
	unregister_forward(FM_PlaybackEvent, g_iForwardIndex , false);
	
	return HAM_SUPERCEDE ;
}

public fw_SecondaryAttack_Pre(Ent)
{
	if(!IsValidPrivateData(Ent))
	{
		return HAM_IGNORED;
	}

	static 	pId  ; pId = get_pdata_cbase(Ent , OFFSET_WEAPONOWNER , OFFSET_LINUX_WEAPONS);
	static iClip ; iClip = get_pdata_int(Ent, m_iClip, OFFSET_LINUX_WEAPONS);
	static Float:i_mSpinTime ;i_mSpinTime  = get_pdata_float(Ent ,m_flStartThrow , OFFSET_LINUX_WEAPONS);

	if (!HoldCBaseWeapon(pId))
	{
		return HAM_IGNORED;
	}
	
	g_iForwardIndex = register_forward(FM_PlaybackEvent, "Forward_PlayBackEvent" , false);
	
	if(iClip <= 0)
	{
		if(i_mSpinTime)
		{
			emit_sound(pId , CHAN_WEAPON , WEAPON_SOUND_SPINDOWN , 1.0 , ATTN_NORM , 0 , PITCH_NORM) ;
			
			SendWeaponAnim(pId , SHOOT_END);
			set_pdata_float(Ent ,m_flStartThrow , 0.0 , OFFSET_LINUX_WEAPONS);
			
			g_iRun[ pId ]	=	false ;
		}
		
		return HAM_IGNORED;
	}
	
	if(i_mSpinTime <= 0.0)
	{
		emit_sound(pId , CHAN_WEAPON , WEAPON_SOUND_SPINUP , 1.0 , ATTN_NORM , 0 , PITCH_NORM) ;
		
		SendWeaponAnim(pId ,SHOOT_START);
		i_mSpinTime += 0.1;
	}
	else if(i_mSpinTime <= 1.1)
	{
		i_mSpinTime += 0.1;
	}
	else if(i_mSpinTime > 1.1)
	{
		ExecuteHam(Ham_Weapon_PrimaryAttack, Ent);

		emit_sound(pId, CHAN_WEAPON, WEAPON_SOUND_FIRE, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
		SendWeaponAnim(pId, SHOOT_1);
		EjectBrass(pId, g_iShell[ SHELL_1 ] , -9.0, 17.0, -3.0 , -10.0 , -50.0);
		EjectBrass(pId, g_iShell[ SHELL_2 ] , -9.0, 17.0, 8.0 , 10.0 , 50.0);
		
		UTIL_ScreenShake(pId, (1 << 12) * 1, (1 << 12) * 1, (1 << 12) * 1);
		
		g_iRun[ pId ]	=	true ;
	}
	
	set_pdata_float(Ent , m_flStartThrow , i_mSpinTime , OFFSET_LINUX_WEAPONS);
	set_pdata_float(Ent, m_flNextPrimaryAttack , WEAPON_SPEED , OFFSET_LINUX_WEAPONS);
	set_pdata_float(Ent, m_flTimeWeaponIdle, WEAPON_SPEED   , OFFSET_LINUX_WEAPONS);
	
	unregister_forward(FM_PlaybackEvent, g_iForwardIndex , false);
	
	return HAM_SUPERCEDE ;
}

public fw_PostFrame_Pre(Ent) 
{
	if(!IsValidPrivateData(Ent))
	{
                return HAM_IGNORED;
	}

	static pId;
	pId = get_pdata_cbase(Ent , OFFSET_WEAPONOWNER , OFFSET_LINUX_WEAPONS);

	if (!is_user_connected(pId) && !HoldCBaseWeapon(pId))
	{
		return HAM_IGNORED;
	}
	
	static fInReload ; fInReload = get_pdata_int(Ent, 54, OFFSET_LINUX_WEAPONS);
	static Float:flNextAttack ; flNextAttack = get_pdata_float(pId, m_flNextAttack, OFFSET_LINUX_WEAPONS);
	static iClip ; iClip = get_pdata_int(Ent, m_iClip, OFFSET_LINUX_WEAPONS);
	static iAmmoType ; iAmmoType = 376 + get_pdata_int(Ent, 49, OFFSET_LINUX_WEAPONS);
	static iBpAmmo ; iBpAmmo  = get_pdata_int(pId, iAmmoType, OFFSET_LINUX);
	
	if (fInReload && flNextAttack <= RELOAD_TIME)
	{
		static  j ; j = min(CLIP_WEAPON  - iClip, iBpAmmo);
	
		set_pdata_int(Ent, m_iClip, iClip + j, OFFSET_LINUX_WEAPONS);
		set_pdata_int(pId, iAmmoType, iBpAmmo-j, OFFSET_LINUX);
		set_pdata_int(Ent, 54, 0, OFFSET_LINUX_WEAPONS);
	}	 
	
	return HAM_IGNORED;
}

public fw_Reload_Pre(Ent) 
{
	if(!IsValidPrivateData(Ent))
	{
		return HAM_IGNORED;
	}

	static pId;
	pId = get_pdata_cbase(Ent , OFFSET_WEAPONOWNER , OFFSET_LINUX_WEAPONS);
	
	static iAmmoType ; iAmmoType = 376 + get_pdata_int(Ent, 49, OFFSET_LINUX_WEAPONS);
	static iBpAmmo ; iBpAmmo = get_pdata_int(pId, iAmmoType, OFFSET_LINUX);
	static iClip ; iClip = get_pdata_int(Ent, m_iClip, OFFSET_LINUX);
	
	if (iBpAmmo <= 0 || iClip >= CLIP_WEAPON)
	{
	    return HAM_SUPERCEDE;
	} 
	
	set_pdata_int(Ent, m_iClip, 0, OFFSET_LINUX_WEAPONS);
	ExecuteHam(Ham_Weapon_Reload, Ent	);
	set_pdata_int(Ent, m_iClip, iClip, OFFSET_LINUX_WEAPONS);

	if (!is_user_connected(pId) || !HoldCBaseWeapon(pId))
	{
		return HAM_IGNORED;
	}
	
	set_pdata_float(pId, m_flNextAttack, RELOAD_TIME , OFFSET_LINUX);
	set_pdata_float(Ent, m_flTimeWeaponIdle, RELOAD_TIME , OFFSET_LINUX_WEAPONS);
	set_pdata_float(Ent , m_flStartThrow , 0.0 , OFFSET_LINUX_WEAPONS);
	
	SendWeaponAnim(pId, RELOAD);
	
	return HAM_SUPERCEDE;
}

public fw_Idle_Pre(Ent)
{
	if(!IsValidPrivateData(Ent))
	{
				return HAM_IGNORED;
	}

	static pId;
	pId = get_pdata_cbase(Ent , OFFSET_WEAPONOWNER , OFFSET_LINUX_WEAPONS);
	
	if (get_pdata_int(Ent, m_flTimeWeaponIdle, OFFSET_LINUX_WEAPONS) > 0.0)
	{
		return HAM_IGNORED;
	}

	if (!HoldCBaseWeapon(pId))
	{
		return HAM_IGNORED;
	}
	
	if(get_pdata_float(Ent , m_flStartThrow, OFFSET_LINUX_WEAPONS))
	{
		emit_sound(pId , CHAN_WEAPON , WEAPON_SOUND_SPINDOWN , 1.0 , ATTN_NORM , 0 , PITCH_NORM) ;
		
		SendWeaponAnim (pId, SHOOT_END);
		set_pdata_float(Ent ,m_flStartThrow , 0.0 , OFFSET_LINUX_WEAPONS);
		set_pdata_float(Ent, m_flTimeWeaponIdle, 0.6 , OFFSET_LINUX_WEAPONS);
		
		set_pdata_float(pId , m_flNextAttack , 0.6 , OFFSET_LINUX) ;
		
		g_iRun[ pId ]	=	false ;
		
		return HAM_IGNORED ;
	}

	SendWeaponAnim (pId, IDLE);
	set_pdata_float(Ent, m_flTimeWeaponIdle, random_float(5.0 , 10.0) , OFFSET_LINUX_WEAPONS);

	return HAM_SUPERCEDE  ;
}

public fw_TraceAttack_Pre(iEntity,  iAttacker,  Float: flDamage)
{
	if (is_user_connected(iAttacker) && HoldCBaseWeapon(iAttacker))
	{
		SetHamParamFloat(3 , flDamage * WEAPON_DAMAGE);
		
		return HAM_IGNORED ; 
	}
	
	return HAM_IGNORED;
}

public fw_TraceAttack_Post(Ent, iAttacker, Float:flDamage, Float:fDir[3], ptr, iDamageType)
{
	if (!is_user_connected(iAttacker) || !HoldCBaseWeapon(iAttacker) || !iAttacker)
	{
		return HAM_HANDLED;
	}
	

	new iDecal = GUNSHOT_DECALS[ random_num(0 , sizeof(GUNSHOT_DECALS) - 1) ];
	new Float:vecEnd[3];
   
	get_tr2(ptr, TR_vecEndPos, vecEnd);

	message_begin(MSG_BROADCAST, SVC_TEMPENTITY);
	write_byte(TE_GUNSHOTDECAL);
	engfunc(EngFunc_WriteCoord, vecEnd[0]);
	engfunc(EngFunc_WriteCoord, vecEnd[1]);
	engfunc(EngFunc_WriteCoord, vecEnd[2] - 10.0);
	write_short(Ent);
	write_byte(iDecal);
	message_end();

	return HAM_IGNORED;
}

stock DropWeapons(id, bitsDropType)
{
	static weapons[32], num, i, weaponid;
	num = 0 ;
	get_user_weapons(id, weapons, num);
	
	for (i = 0; i < num; i++)
	{
		weaponid = weapons[i];
		
		if ((bitsDropType == DROP_PRIMARY && ((1<<weaponid) & WEAPONS_PRIMARY_BITSUM)) || (bitsDropType == DROP_SECONDARY && ((1<<weaponid) & WEAPONS_SECONDARY_BITSUM)))
		{
			static wname[32];
			get_weaponname(weaponid, wname, charsmax(wname));
			
			engclient_cmd(id, "drop", wname);
		}
	}
}

stock SendWeaponAnim(const id, const Sequence)
{
	set_pev(id, pev_weaponanim, Sequence);
	
	message_begin(MSG_ONE_UNRELIABLE, SVC_WEAPONANIM, .player = id);
	write_byte(Sequence);
	write_byte(pev(id, pev_body));
	message_end();
}

stock WeaponList(id, const szWeapon[ ], int, int2, int3, int4, int5, int6, int7, int8)
{
	message_begin(MSG_ONE_UNRELIABLE, get_user_msgid("WeaponList") , _, id);
	write_string(szWeapon);
	write_byte(int);
	write_byte(int2);
	write_byte(int3);
	write_byte(int4);
	write_byte(int5);
	write_byte(int6);
	write_byte(int7);
	write_byte(int8);
	message_end();
}

PRECACHE_SOUNDS_FROM_MODEL(const szModelPath[])
{
	new iFile;
	
	if ((iFile = fopen(szModelPath, "rt")))
	{
		new szSoundPath[64];
		
		new iNumSeq, iSeqIndex;
		new iEvent, iNumEvents, iEventIndex;
		
		fseek(iFile, 164, SEEK_SET);
		fread(iFile, iNumSeq, BLOCK_INT);
		fread(iFile, iSeqIndex, BLOCK_INT);
		
		for (new k, i = 0; i < iNumSeq; i++)
		{
			fseek(iFile, iSeqIndex + 48 + 176 * i, SEEK_SET);
			fread(iFile, iNumEvents, BLOCK_INT);
			fread(iFile, iEventIndex, BLOCK_INT);
			fseek(iFile, iEventIndex + 176 * i, SEEK_SET);

			for (k = 0; k < iNumEvents; k++)
			{
				fseek(iFile, iEventIndex + 4 + 76 * k, SEEK_SET);
				fread(iFile, iEvent, BLOCK_INT);
				fseek(iFile, 4, SEEK_CUR);
				
				if (iEvent != 5004)
				{
					continue;
				}

				fread_blocks(iFile, szSoundPath, 64, BLOCK_CHAR);
				
				if (strlen(szSoundPath))
				{
					strtolower(szSoundPath);
					precache_sound(szSoundPath);
				}
			}
		}
	}
	
	fclose(iFile);
}

stock UTIL_ScreenShake(id, sAmplitude = 0, sDuration = 0, sFrequency = 0)
{
	message_begin(MSG_ONE_UNRELIABLE, get_user_msgid("ScreenShake"), .player = id);
	write_short(sAmplitude);
	write_short(sDuration);
	write_short(sFrequency);
	message_end();
}	

public EjectBrass(Player, iShellModelIndex, Float:upScale, Float:fwScale, Float:rgScale , Float:rgKoord1 , Float:rgKoord2)
{
	UTIL_MakeVectors(Player, v_angle + punchangle);
	
	static Float:vVel[ 3 ], Float:vAngle[ 3 ], Float:vOrigin[ 3 ], Float:vViewOfs[ 3 ],
	i, Float:vShellOrigin[ 3 ],  Float:vShellVelocity[ 3 ], Float:vRight[ 3 ], 
	Float:vUp[ 3 ], Float:vForward[ 3 ];
	pev(Player, pev_velocity, vVel);
	pev(Player, pev_view_ofs, vViewOfs);
	pev(Player, pev_angles, vAngle);
	pev(Player, pev_origin, vOrigin);
	global_get(glb_v_right, vRight);
	global_get(glb_v_up, vUp);
	global_get(glb_v_forward, vForward);
	
	for(i = 0; i < 3; i++)
	{
		vShellOrigin[ i ] = vOrigin[ i ] + vViewOfs[ i ] + vUp[ i ] * upScale + vForward[ i ] * fwScale + vRight[ i ] * rgScale;
		vShellVelocity[ i ] = vVel[ i ] + vRight[ i ] * random_float(rgKoord1, rgKoord2) + vUp[ i ] * random_float(100.0, 150.0) + vForward[ i ] * 25.0;
	}
	
	engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, vShellOrigin, 0);
	write_byte(TE_MODEL);
	engfunc(EngFunc_WriteCoord, vShellOrigin[ 0 ]);
	engfunc(EngFunc_WriteCoord, vShellOrigin[ 1 ]);
	engfunc(EngFunc_WriteCoord, vShellOrigin[ 2 ]);	
	engfunc(EngFunc_WriteCoord, vShellVelocity[ 0 ]);
	engfunc(EngFunc_WriteCoord,  vShellVelocity[ 1 ]);
	engfunc(EngFunc_WriteCoord,  vShellVelocity[ 2 ]);
	engfunc(EngFunc_WriteAngle, vAngle[ 1 ]);
	write_short(iShellModelIndex);
	write_byte(1);
	write_byte(15); // 2.5 seconds
	message_end();
	
}

stock UTIL_MakeVectors(id, bitsAngleType)
{
	static Float:vPunchAngle[ 3 ], Float:vAngle[ 3 ];
	
	if(bitsAngleType & v_angle)    
		pev(id, pev_v_angle, vAngle);
	if(bitsAngleType & punchangle) 
		pev(id, pev_punchangle, vPunchAngle);
	
	VectorAdd(vAngle, vPunchAngle, vAngle);
	engfunc(EngFunc_MakeVectors, vAngle);
}

public zp_get_user_zombie(id)
{
	return 0
} 
