#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <fakemeta_util>
#include <fun>
#include <hamsandwich>
#include <xs>
#include <cstrike>

#define M32_CLIP 6
#define M32_BPAMMO 32
#define M32_DAMAGE 250.0

#define MODEL_V "models/v_M32.mdl"
#define MODEL_P "models/v_M32.mdl"
#define MODEL_W "models/v_M32.mdl"
 
#define GRENADE_MODEL "models/grenade.mdl"
 
#define ENG_NULLENT -1
#define EV_INT_WEAPONKEY EV_INT_impulse
#define M32_WEAPONKEY 11515

new const FIRE_SOUND[][] = { "weapons/M32-1.wav" }
new const GRENADE_TRAIL[] = "sprites/laserbeam.spr"
new const GRENADE_EXPLOSION[] = "sprites/zerogxplode.spr"

const PRIMARY_WEAPONS_BIT_SUM = (1<<CSW_SCOUT)|(1<<CSW_XM1014)|(1<<CSW_P90)|(1<<CSW_P90)|(1<<CSW_P90)|(1<<CSW_SG550)|(1<<CSW_P90)|(1<<CSW_FAMAS)|(1<<CSW_AWP)|(1<<CSW_P90)|(1<<CSW_M249)|(1<<CSW_M3)|(1<<CSW_M4A1)|(1<<CSW_TMP)|(1<<CSW_M3)|(1<<CSW_P90)|(1<<CSW_AK47)|(1<<CSW_P90)

new in_zoom[33], g_reload[33], sTrail, sExplo, g_has_M32[33]
new g_MsgWeaponList, g_MaxPlayers, g_orig_event_M32

public plugin_init()
{
	register_plugin("Grenade Launcher M32", "3.0", "Remade by Dias")
	
	register_event("CurWeapon","CurrentWeapon","be","1=1")
	
	register_forward(FM_CmdStart, "fw_CmdStart")
	register_forward(FM_SetModel, "fw_SetModel")
	register_forward(FM_UpdateClientData, "fw_UpdateClientData_Post", 1)
	register_forward(FM_PlaybackEvent, "fw_PlaybackEvent")
	
	RegisterHam(Ham_Item_AddToPlayer, "weapon_m3", "fw_AddToPlayer")
	RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_m3", "fw_PrimaryAttack")
	RegisterHam(Ham_Weapon_PrimaryAttack, "weapon_m3", "fw_PrimaryAttackp", 1)
	RegisterHam(Ham_Item_Deploy,"weapon_m3", "fw_Item_Deploy_Post", 1)
	RegisterHam(Ham_Weapon_Reload, "weapon_m3", "fw_r")
	RegisterHam(Ham_Weapon_Reload, "weapon_m3", "fw_reload")
	
	register_message(get_user_msgid("DeathMsg"), "Message_DeathMsg")
	
	g_MsgWeaponList = get_user_msgid("WeaponList")
	g_MaxPlayers = get_maxplayers()
	
	register_clcmd("say /get", "Get_M32")
	register_clcmd("weapon_M32", "Hook_Select")
}
	
public plugin_precache()
{
	precache_model(MODEL_V)
	precache_model(MODEL_P)
	precache_model(MODEL_W)
	precache_model(GRENADE_MODEL)
	precache_sound(FIRE_SOUND[0])	
	
	sTrail = precache_model(GRENADE_TRAIL)
	sExplo = precache_model(GRENADE_EXPLOSION)
	
	// Extra Sound
	precache_sound("weapons/M32_after_reload.wav")
	precache_sound("weapons/M32_insert.wav")
	precache_sound("weapons/M32_start_reload.wav")
	
	// WeaponList
	precache_generic("sprites/weapon_m32.txt")
	precache_generic("sprites/640hud75_2.spr")
	precache_generic("sprites/640hud7_2.spr")

	register_forward(FM_PrecacheEvent, "fwPrecacheEvent_Post", 1)
}

public Hook_Select(id)
{
	engclient_cmd(id, "weapon_m3")
	return PLUGIN_HANDLED
}

public fwPrecacheEvent_Post(type, const name[])
{
	if (equal("events/m3.sc", name))
	{
		g_orig_event_M32 = get_orig_retval()
		return FMRES_HANDLED
	}
	
	return FMRES_IGNORED
}

public fw_SetModel(entity, model[])
{
	if(!is_valid_ent(entity))
		return FMRES_IGNORED;
	
	static szClassName[33]
	entity_get_string(entity, EV_SZ_classname, szClassName, charsmax(szClassName))
	
	if(!equal(szClassName, "weaponbox"))
		return FMRES_IGNORED;
	
	static iOwner
	iOwner = entity_get_edict(entity, EV_ENT_owner)
	
	if(equal(model, "models/w_m3.mdl"))
	{
		static iStoredAugID; iStoredAugID = find_ent_by_owner(-1, "weapon_m3", entity)
		
		if(!is_valid_ent(iStoredAugID))
			return FMRES_IGNORED;
		
		if(g_has_M32[iOwner])
		{
			entity_set_int(iStoredAugID, EV_INT_impulse, M32_WEAPONKEY)
			
			g_has_M32[iOwner] = false
			g_reload[iOwner]=0
			
			if(in_zoom[iOwner])
			{
				set_zoom(iOwner,0)
				return PLUGIN_CONTINUE
			
			}
			
			entity_set_model(entity, MODEL_W)
			
			return FMRES_SUPERCEDE;
		}
	}
	
	return FMRES_IGNORED;
}

public Get_M32(id)
{
	drop_weapons(id, 1)
	new iWep2 = give_item(id,"weapon_m3")
	if(iWep2 > 0)
	{
		cs_set_weapon_ammo(iWep2, M32_CLIP)
		cs_set_user_bpammo(id, CSW_M3, M32_BPAMMO)
	}

	if(in_zoom[id])
	{ 
		cs_set_user_zoom(id, CS_RESET_ZOOM, 1)
		in_zoom[id] = 0
	}
	
	message_begin(MSG_ONE_UNRELIABLE, g_MsgWeaponList, {0,0,0}, id)
	write_string("weapon_m32")
	write_byte(5)
	write_byte(32)
	write_byte(-1)
	write_byte(-1)
	write_byte(0)
	write_byte(5)
	write_byte(21)
	write_byte(0)
	message_end()
	
	set_zoom(id,0)
	
	g_reload[id]=0
	g_has_M32[id] = true
}
 
public fw_AddToPlayer(M32, id)
{
	if(!is_valid_ent(M32) || !is_user_connected(id)) return HAM_IGNORED
        
	if(entity_get_int(M32, EV_INT_WEAPONKEY) == M32_WEAPONKEY)
	{
		g_has_M32[id] = true
		g_reload[id]=0
		
		set_zoom(id,0)
		entity_set_int(M32, EV_INT_WEAPONKEY, 0)
		
		message_begin(MSG_ONE_UNRELIABLE, g_MsgWeaponList, {0,0,0}, id)
		write_string("weapon_m32")
		write_byte(5)
		write_byte(32)
		write_byte(-1)
		write_byte(-1)
		write_byte(0)
		write_byte(5)
		write_byte(21)
		write_byte(0)
		message_end()
		
		return HAM_HANDLED
	}
	if(entity_get_int(M32, EV_INT_WEAPONKEY) != M32_WEAPONKEY) 
	{
		message_begin(MSG_ONE_UNRELIABLE, g_MsgWeaponList, {0,0,0}, id)
		write_string("weapon_m3")
		write_byte(5)
		write_byte(32)
		write_byte(-1)
		write_byte(-1)
		write_byte(0)
		write_byte(5)
		write_byte(21)
		write_byte(0)
		message_end()
	}
	
	return HAM_IGNORED
}
 
public fw_Item_Deploy_Post(weapon_ent)
{
	new owner = pev(weapon_ent,pev_owner)
	if(is_user_alive(owner) && get_user_weapon(owner) == CSW_M3)
		set_zoom(owner,0)
	
	static weaponid; weaponid = cs_get_weapon_id(weapon_ent)
	if(is_user_alive(owner)) replace_weapon_models(owner, weaponid)
}

public CurrentWeapon(id)
{
	if(read_data(2) != CSW_M3) 
	{
		if(g_reload[id]) 
		{
			g_reload[id] = false
			remove_task(id + 1331)
		}
	}
	
	replace_weapon_models(id, read_data(2))
	remove_task(id)
} 
 
replace_weapon_models(id, weaponid)
{
	switch(weaponid)
	{
		case CSW_M3:
		{
			if(g_has_M32[id] && is_user_alive(id))
			{

				set_pev(id, pev_viewmodel2, MODEL_V)
				set_pev(id, pev_weaponmodel2, MODEL_P)
			}
		}
	}
}
 
public fw_UpdateClientData_Post(Player, SendWeapons, CD_Handle)
{
	if(!is_user_alive(Player) || (get_user_weapon(Player) != CSW_M3) || !g_has_M32[Player]) return FMRES_IGNORED
        
	set_cd(CD_Handle, CD_flNextAttack, halflife_time () + 0.00001)
	return FMRES_HANDLED
}

public fw_CmdStart(id, uc_handle, seed) 
{
	new ammo, clip, weapon = get_user_weapon(id, clip, ammo)
	if (!g_has_M32[id] || weapon != CSW_M3 || !is_user_alive(id))
		return

	if((get_uc(uc_handle, UC_Buttons) & IN_ATTACK2) && !(pev(id, pev_oldbuttons) & IN_ATTACK2)) {
		if(!in_zoom[id] && !g_reload[id]) set_zoom(id,1)
		else set_zoom(id,0)
	}
}

public fw_PrimaryAttack(wpn) 
{
	if(g_has_M32[ pev(wpn, pev_owner) ]) return HAM_SUPERCEDE
	return HAM_IGNORED
}

public fw_PrimaryAttackp(wpn) 
{
	new id = pev(wpn, pev_owner), clip, bpammo
	get_user_weapon(id, clip, bpammo)
	if(g_has_M32[id]) 
	{
		if(clip > 0) 
		{
			if(g_reload[id])
			{
				UTIL_PlayWeaponAnimation(id, 4)
				set_pdata_float(id, 83, 1.0)
				remove_task(id + 1331)
				g_reload[id] = false
				return
			}

			UTIL_PlayWeaponAnimation(id,random_num(1,2))
			emit_sound(id, CHAN_WEAPON, FIRE_SOUND[0], 1.0, ATTN_NORM, 0, PITCH_NORM)
			FireGrenade(id)
			MakeRecoil(id)

			set_pdata_float(id, 83, 0.6)
		}
	}
}

public MakeRecoil(id)
{
	if(!is_user_alive(id))
		return;
	if(zp_get_user_zombie(id))
		return;

	if(!g_has_M32[id])
		return;

	static Float:punchAngle[3];
	punchAngle[0] = float(random_num(-1 * 400, 400)) / 100.0;
	punchAngle[1] = float(random_num(-1 * 700, 700)) / 100.0;
	punchAngle[2] = 0.0;
	
	set_pev(id, pev_punchangle, punchAngle);
}

public FireGrenade(id)
{
	new ammo, clip
	get_user_weapon(id, clip, ammo)
	static wep
	wep = find_ent_by_owner(-1, "weapon_m3", id)
	cs_set_weapon_ammo(wep,clip-1)
	new Float:origin[3],Float:velocity[3],Float:angles[3]
	engfunc(EngFunc_GetAttachment, id, 0, origin,angles)
	pev(id,pev_angles,angles)
	new ent = create_entity("info_target") 
	set_pev(ent, pev_classname, "M32_grenade")
	set_pev(ent, pev_solid, SOLID_BBOX)
	set_pev(ent, pev_movetype, MOVETYPE_TOSS)
	set_pev(ent, pev_mins, { -0.1, -0.1, -0.1 })
	set_pev(ent, pev_maxs, { 0.1, 0.1, 0.1 })
	entity_set_model(ent, GRENADE_MODEL)
	set_pev(ent, pev_origin, origin)
	set_pev(ent, pev_angles, angles)
	set_pev(ent, pev_owner, id)
	velocity_by_aim(id, in_zoom[id]? 1400 : 1000 , velocity)
	set_pev(ent, pev_velocity, velocity)
	message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
	write_byte(TE_BEAMFOLLOW) // Temporary entity ID
	write_short(ent) // Entity
	write_short(sTrail) // Sprite index
	write_byte(10) // Life
	write_byte(3) // Line width
	write_byte(255) // Red
	write_byte(255) // Green
	write_byte(255) // Blue
	write_byte(255) // Alpha
	message_end() 
	return PLUGIN_CONTINUE
}	



// We hit something!!!
public pfn_touch(ptr, ptd)
{
	// If ent is valid
	if (pev_valid(ptr))
	{	
		// Get classnames
		static classname[32]
		pev(ptr, pev_classname, classname, 31)
		
		// Our ent
		if(equal(classname, "M32_grenade"))
		{
			// Get it's origin
			new Float:originF[3]
			pev(ptr, pev_origin, originF)
			engfunc(EngFunc_MessageBegin, MSG_PAS, SVC_TEMPENTITY, originF, 0)
			write_byte(TE_WORLDDECAL)
			engfunc(EngFunc_WriteCoord, originF[0])
			engfunc(EngFunc_WriteCoord, originF[1])
			engfunc(EngFunc_WriteCoord, originF[2])
			write_byte(engfunc(EngFunc_DecalIndex,"{scorch3"))
			message_end()
			// Draw explosion
			message_begin(MSG_BROADCAST, SVC_TEMPENTITY)
			write_byte(TE_EXPLOSION) // Temporary entity ID
			engfunc(EngFunc_WriteCoord, originF[0]) // engfunc because float
			engfunc(EngFunc_WriteCoord, originF[1])
			engfunc(EngFunc_WriteCoord, originF[2]+30.0)
			write_short(sExplo) // Sprite index
			write_byte(25) // Scale
			write_byte(25) // Framerate
			write_byte(0) // Flags
			message_end()
			
			// Get owner
			new owner = pev(ptr, pev_owner)
			// Alive...
			new a = FM_NULLENT
			// Get distance between victim and epicenter
			while((a = find_ent_in_sphere(a,originF,300.0)) != 0) {
				if(a!=owner&& a!=ptr&&pev(a,pev_takedamage)!=DAMAGE_NO) ExecuteHamB(Ham_TakeDamage, a ,owner ,owner,  M32_DAMAGE, DMG_BULLET)
				set_pev(ptr, pev_flags, FL_KILLME)
			}
		}
	}
		
}	
 
public fw_PlaybackEvent(flags, invoker, eventid, Float:delay, Float:origin[3], Float:angles[3], Float:fparam1, Float:fparam2, iParam1, iParam2, bParam1, bParam2)
{
	if ((eventid != g_orig_event_M32)) return FMRES_IGNORED
	if (!(1 <= invoker <= g_MaxPlayers)) return FMRES_IGNORED

	playback_event(flags | FEV_HOSTONLY, invoker, eventid, delay, origin, angles, fparam1, fparam2, iParam1, iParam2, bParam1, bParam2)
	return FMRES_SUPERCEDE
}


public Message_DeathMsg(msg_id, msg_dest, id)
{
	static szTruncatedWeapon[33], iAttacker, iVictim
        
	get_msg_arg_string(4, szTruncatedWeapon, charsmax(szTruncatedWeapon))
        
	iAttacker = get_msg_arg_int(1)
	iVictim = get_msg_arg_int(2)
        
	if(!is_user_connected(iAttacker) || iAttacker == iVictim) return PLUGIN_CONTINUE
        
	if(get_user_weapon(iAttacker) == CSW_M3)
	{
		if(g_has_M32[iAttacker])
			set_msg_arg_string(4, "grenade")
	}
                
	return PLUGIN_CONTINUE
}
 
stock UTIL_PlayWeaponAnimation(const Player, const Sequence)
{
	set_pev(Player, pev_weaponanim, Sequence)
        
	message_begin(MSG_ONE_UNRELIABLE, SVC_WEAPONANIM, .player = Player)
	write_byte(Sequence)
	write_byte(2)
	message_end()
}

 
public fw_r(wpn) {
	if(g_has_M32[ pev(wpn, pev_owner) ]) {
		fw_reload(wpn)
		return HAM_SUPERCEDE
	}
	return HAM_IGNORED
}

public fw_reload(weapon) {
	new id = pev(weapon, pev_owner)
	new clip, bpammo
	get_user_weapon(id, clip, bpammo)
	if(g_has_M32[ id ] && clip < 6 && bpammo > 0) {
		if(!task_exists(id+1331)) set_task(0.1, "reload", id+1331)
		}
	if(in_zoom[id])
	{
		cs_set_user_zoom(id, CS_RESET_ZOOM, 1)
		in_zoom[id] = 0
	}
	return HAM_IGNORED
}

public reload(id) {
	id -= 1331
	new clip, bpammo, weapon = find_ent_by_owner(-1, "weapon_m3", id)
	get_user_weapon(id, clip, bpammo)
	if(!g_reload[id]) {
			set_zoom(id,0)
			UTIL_PlayWeaponAnimation(id, 5)
			g_reload[ id ] = 1
			set_pdata_float(id, 83, 1.0, 5)
			set_task(1.0, "reload", id+1331)
			return
	}

	if(in_zoom[id])
	{
		cs_set_user_zoom(id, CS_RESET_ZOOM, 1)
		in_zoom[id] = 0
	}
	
	if(clip > 5 || bpammo < 1) {
		UTIL_PlayWeaponAnimation(id, 4)
		g_reload[ id ] = 0
		set_pdata_float(id, 83, 1.5, 5)
		return
	}
	cs_set_user_bpammo(id, CSW_M3, bpammo - 1)
	cs_set_weapon_ammo(weapon, clip + 1)
	set_pdata_float(id, 83, 1.0, 5)
	UTIL_PlayWeaponAnimation(id, 3)
	set_task(1.0, "reload", id+1331)
}
 
stock drop_weapons(id, dropwhat)
{
	static weapons[32], num, i, weaponid
	num = 0
	get_user_weapons(id, weapons, num)
	
	for (i = 0; i < num; i++)
	{
		weaponid = weapons[i]
		
		if (dropwhat == 1 && ((1<<weaponid) & PRIMARY_WEAPONS_BIT_SUM))
		{
			static wname[32]
			get_weaponname(weaponid, wname, sizeof wname - 1)
			engclient_cmd(id, "drop", wname)
		}
	}
}

stock set_zoom(index,type){
	if(type==0){
		if(in_zoom[index]==1){
			cs_set_user_zoom(index, CS_SET_AUGSG552_ZOOM, 1)

			in_zoom[index]=0
			emit_sound(index, CHAN_ITEM, "weapons/zoom.wav", 0.20, 2.40, 0, 100)
		}
	}
	if(type==1){
		if(in_zoom[index]==0){
			cs_set_user_zoom(index, CS_RESET_ZOOM, 1)

			in_zoom[index]=1
			emit_sound(index, CHAN_ITEM, "weapons/zoom.wav", 0.20, 2.40, 0, 100)
		}
	}
}

public zp_get_user_zombie(id)
{
	return 1
}
/* AMXX-Studio Notes - DO NOT MODIFY BELOW HERE
*{\\ rtf1\\ ansi\\ deff0{\\ fonttbl{\\ f0\\ fnil Tahoma;}}\n\\ viewkind4\\ uc1\\ pard\\ lang1049\\ f0\\ fs16 \n\\ par }
*/
