#include <amxmodx>
#include <engine>
#include <fakemeta>
#include <fakemeta_util>
#include <hamsandwich>
#include <cstrike>
#include <xs>
#include <fun>

#define PLUGIN "[CSO] Vulcanus-5"
#define VERSION "1.0"
#define AUTHOR "Dias 'Pendragon' Leon"

#define DAMAGE 35 // 70 for zombie
#define CLIP 40
#define BPAMMO 200
#define SPEED 0.15

#define TIME_RELOAD 3.0
#define RADIUS_DETECT 2048.0

#define CSW_VULCANUS5 CSW_AUG
#define weapon_vulcanus5 "weapon_aug"

#define MODEL_V "models/v_vulcanus5.mdl"
#define MODEL_P "models/p_vulcanus5.mdl"
#define MODEL_W "models/w_vulcanus5.mdl"
#define MODEL_SA "models/v_VULCANUS5_SightA.mdl"
#define MODEL_SB "models/v_VULCANUS5_SightB.mdl"
#define MODEL_WOLD "models/w_aug.mdl"

new const WeaponSounds[7][] =
{
	"weapons/vulcanus5-1.wav",
	"weapons/vulcanus5_target_start.wav",
	"weapons/vulcanus5_target_on.wav",
	"weapons/vulcanus5_target_loop.wav",
	"weapons/vulcanus5_boltpull.wav",
	"weapons/vulcanus5_clipin.wav",
	"weapons/vulcanus5_clipout.wav"
}

enum
{
	ANIME_IDLE = 0,
	ANIME_RELOAD,
	ANIME_DRAW,
	ANIME_SHOOT1,
	ANIME_SHOOT2,
	ANIME_SHOOT3
}

enum
{
	STATE_NONE = 0,
	STATE_LOCKING1,
	STATE_LOCKING2,
	STATE_LOCKED
}

// Bits
#define Get_BitVar(%1,%2)		(%1 & (1 << (%2 & 31)))
#define Set_BitVar(%1,%2)		(%1 |= (1 << (%2 & 31)));
#define UnSet_BitVar(%1,%2)		(%1 &= ~(1 << (%2 & 31)));

new g_Had_Vulcanus5, Float:g_LoopTime[33], g_Clip[33], g_Zoom[33], g_GunState[33], MyTarget[33]
new g_TargetHud, g_Event_Vulcanus5, g_ShellId, g_SmokePuff_SprId

// Safety
new g_HamBot
new g_IsConnected, g_IsAlive, g_PlayerWeapon[33]

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR)
	
	Register_SafetyFunc()
	
	register_event("DeathMsg", "IHateChineseGovernment", "a")
	register_event("CurWeapon", "ILoveCSOnAnime", "be", "1=1")
	
	// Forward
	register_forward(FM_UpdateClientData, "TokyoJapan", 1)
	register_forward(FM_PlaybackEvent, "RepublicOfVietnam")
	register_forward(FM_SetModel, "VictoriqueGosick")	
	register_forward(FM_AddToFullPack, "KimiGaSukiDakara", 1)
	
	// Ham
	RegisterHam(Ham_Item_Deploy, weapon_vulcanus5, "Suigitou", 1)	
	RegisterHam(Ham_Item_AddToPlayer, weapon_vulcanus5, "Shinku", 1)
	RegisterHam(Ham_Weapon_WeaponIdle, weapon_vulcanus5, "Suiseiseki", 1)
	RegisterHam(Ham_Item_PostFrame, weapon_vulcanus5, "SaigonVietnam")	
	RegisterHam(Ham_Weapon_Reload, weapon_vulcanus5, "HanoiVietnam")
	RegisterHam(Ham_Weapon_Reload, weapon_vulcanus5, "HanoiVietnam_Post", 1)	

	RegisterHam(Ham_TraceAttack, "worldspawn", "NoCommunist")
	RegisterHam(Ham_TraceAttack, "player", "ThisIsCapitalistVietnam")
	
	g_TargetHud = CreateHudSyncObj(16)
	
	register_clcmd("say /get", "Get_Vulcanus5")
}

public plugin_precache()
{
	precache_model(MODEL_V)
	precache_model(MODEL_P)
	precache_model(MODEL_W)
	precache_model(MODEL_SA)
	precache_model(MODEL_SB)
	
	for(new i = 0; i < sizeof(WeaponSounds); i++)
		precache_sound(WeaponSounds[i])
		
	g_ShellId = precache_model("models/rshell_big.mdl")
	g_SmokePuff_SprId = precache_model("sprites/wall_puff1.spr")
	
	register_forward(FM_PrecacheEvent, "fw_PrecacheEvent_Post", 1)
}

public fw_PrecacheEvent_Post(type, const name[])
{
	if(equal("events/aug.sc", name)) g_Event_Vulcanus5 = get_orig_retval()		
}

public client_putinserver(id) 
{
	Safety_Connected(id)
	if(!g_HamBot && is_user_bot(id))
	{
		g_HamBot = 1
		set_task(0.1, "Register_HamBot", id)
	}
}

public Register_HamBot(id) 
{
	Register_SafetyFuncBot(id)
	RegisterHamFromEntity(Ham_TraceAttack, id, "ThisIsCapitalistVietnam")
}

public client_disconnect(id) Safety_Disconnected(id)

public Get_Vulcanus5(id)
{
	Set_BitVar(g_Had_Vulcanus5, id)
	give_item(id, weapon_vulcanus5)
	
	g_Zoom[id] = 1
	g_GunState[id] = 0
	
	static Gun; Gun = fm_get_user_weapon_entity(id, CSW_VULCANUS5)
	if(pev_valid(Gun)) cs_set_weapon_ammo(Gun, CLIP)
	
	cs_set_user_bpammo(id, CSW_VULCANUS5, BPAMMO)
}

public Remove_Vulcanus(id)
{
	UnSet_BitVar(g_Had_Vulcanus5, id)
	
	g_Zoom[id] = 0
	g_GunState[id] = 0
}

public client_PostThink(id)
{
	if(!is_alive(id))
		return
	if(get_player_weapon(id) != CSW_VULCANUS5 || !Get_BitVar(g_Had_Vulcanus5, id))
		return
	if(g_Zoom[id] != 4)
		return
		
	static Float:Time; Time = get_gametime()
	if(Time - 0.5 > g_LoopTime[id])
	{
		static Victim; Victim = -1
		static Float:Origin[3]; pev(id, pev_origin, Origin)
		static Float:Closer; Closer = 4980.0
		static Float:Target[3], TargetID; TargetID = 0
		static Float:XY[2]
	
		while((Victim = find_ent_in_sphere(Victim, Origin, RADIUS_DETECT)) != 0)
		{
			if(Victim == id)
				continue
			if(!is_alive(Victim))
				continue
			if(cs_get_user_team(id) == cs_get_user_team(Victim))
				continue
			pev(Victim, pev_origin, Target)
			if(!is_in_viewcone(id, Target))
				continue
			if(!get_can_see(Origin, Target))
				continue
			if(entity_range(id, Victim) >= Closer)
				continue
				
			TargetID = Victim
		}

		if(is_alive(TargetID))
		{
			pev(TargetID, pev_origin, Target)
			Suigintou_Transformation(id, Target, XY)
			
			if(Is_InScope(XY[0], XY[1]))
			{
				switch(g_GunState[id])
				{
					case STATE_NONE:
					{
						MyTarget[id] = 0
						
						static WeaponURL[64]; pev(id, pev_viewmodel2, WeaponURL, 63)
						if(!equal(WeaponURL, MODEL_SA)) set_pev(id, pev_viewmodel2, MODEL_SA)
						
						set_hudmessage(0, 170, 255, XY[0], XY[1], 0, 0.5, 0.5)
						ShowSyncHudMsg(id, g_TargetHud, "[X]")
						
						emit_sound(id, CHAN_ITEM, WeaponSounds[1], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
						g_GunState[id] = STATE_LOCKING1
					}
					case STATE_LOCKING1:
					{
						MyTarget[id] = 0
						
						set_hudmessage(0, 170, 255, XY[0], XY[1], 0, 0.5, 0.5)
						ShowSyncHudMsg(id, g_TargetHud, "[X]")
						
						emit_sound(id, CHAN_ITEM, WeaponSounds[1], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
						g_GunState[id] = STATE_LOCKING2
					}
					case STATE_LOCKING2:
					{
						MyTarget[id] = 0
						
						set_hudmessage(0, 170, 255, XY[0], XY[1], 0, 0.5, 0.5)
						ShowSyncHudMsg(id, g_TargetHud, "[X]")
						
						emit_sound(id, CHAN_ITEM, WeaponSounds[1], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)	
						g_GunState[id] = STATE_LOCKED
					}	
					case STATE_LOCKED:
					{
						MyTarget[id] = TargetID
						
						static WeaponURL[64]; pev(id, pev_viewmodel2, WeaponURL, 63)
						if(!equal(WeaponURL, MODEL_SB)) set_pev(id, pev_viewmodel2, MODEL_SB)
						
						emit_sound(id, CHAN_ITEM, WeaponSounds[2], VOL_NORM, ATTN_NORM, 0, PITCH_NORM)
					}
				}
			} else {
				g_GunState[id] = STATE_NONE
				
				static WeaponURL[64]; pev(id, pev_viewmodel2, WeaponURL, 63)
				if(!equal(WeaponURL, MODEL_SA)) set_pev(id, pev_viewmodel2, MODEL_SA)
						
			}
		} else {
			g_GunState[id] = STATE_NONE
				
			static WeaponURL[64]; pev(id, pev_viewmodel2, WeaponURL, 63)
			if(!equal(WeaponURL, MODEL_SA)) set_pev(id, pev_viewmodel2, MODEL_SA)
		}
		
		g_LoopTime[id] = Time
	}	
}

public Is_InScope(Float:X, Float:Y)
{
	static Float:TotalX, Float:TotalY
	TotalX = X - 0.5; if(TotalX < 0) TotalX = -TotalX
	TotalY = Y - 0.5; if(TotalY < 0) TotalY = -TotalY
	
	if(TotalX > 0.35 || TotalY > 0.35) return 0
	return 1
}

public IHateChineseGovernment()
{
	static Attacker; Attacker = read_data(1)
	
	if(is_connected(Attacker) && get_user_weapon(Attacker) == CSW_VULCANUS5)
	{
		g_GunState[Attacker] = 0
		MyTarget[Attacker] = 0
	}
}

public ILoveCSOnAnime(id)
{
	static CSW; CSW = read_data(2)
	if(CSW != CSW_VULCANUS5)
		return
	if(!Get_BitVar(g_Had_Vulcanus5, id))	
		return

	if(g_Zoom[id] != cs_get_user_zoom(id))
	{	
		g_Zoom[id] = cs_get_user_zoom(id)
		switch(g_Zoom[id])
		{
			case 1: 
			{
				g_GunState[id] = 1
				MyTarget[id] = 0
				set_pev(id, pev_viewmodel2, MODEL_V)
			}
			case 4: 
			{
				g_GunState[id] = 1
				MyTarget[id] = 0
				SetFov(id, 90)
				set_pev(id, pev_viewmodel2, MODEL_SA)
			}
		}
	}
	
	static Ent; Ent = fm_get_user_weapon_entity(id, CSW_VULCANUS5)
	if(!pev_valid(Ent)) return
	
	set_pdata_float(Ent, 46, SPEED, 4)
	set_pdata_float(Ent, 47, SPEED, 4)
}

public SetFov(id, num)
{
	static MSG; if(!MSG) MSG = get_user_msgid("SetFOV")
	
	message_begin(MSG_ONE_UNRELIABLE, MSG, {0,0,0}, id)
	write_byte(num)
	message_end()
}

public TokyoJapan(id, sendweapons, cd_handle)
{
	if(!is_alive(id))
		return FMRES_IGNORED	
	if(get_player_weapon(id) == CSW_VULCANUS5 && Get_BitVar(g_Had_Vulcanus5, id))
		set_cd(cd_handle, CD_flNextAttack, get_gametime() + 0.001) 
	
	return FMRES_HANDLED
}

public RepublicOfVietnam(flags, invoker, eventid, Float:delay, Float:origin[3], Float:angles[3], Float:fparam1, Float:fparam2, iParam1, iParam2, bParam1, bParam2)
{
	if (!is_connected(invoker))
		return FMRES_IGNORED	
	if(get_player_weapon(invoker) != CSW_VULCANUS5 || !Get_BitVar(g_Had_Vulcanus5, invoker))
		return FMRES_IGNORED
	if(eventid != g_Event_Vulcanus5)
		return FMRES_IGNORED
	
	engfunc(EngFunc_PlaybackEvent, flags | FEV_HOSTONLY, invoker, eventid, delay, origin, angles, fparam1, fparam2, iParam1, iParam2, bParam1, bParam2)

	Set_WeaponAnim(invoker, ANIME_SHOOT1)
	emit_sound(invoker, CHAN_WEAPON, WeaponSounds[0], 1.0, 0.4, 0, 94 + random_num(0, 15))
	if(g_Zoom[invoker] == 1) Eject_Shell(invoker, g_ShellId, 0.01)
	
	return FMRES_SUPERCEDE
}

public VictoriqueGosick(entity, model[])
{
	if(!pev_valid(entity))
		return FMRES_IGNORED
	
	static Classname[32]
	pev(entity, pev_classname, Classname, sizeof(Classname))
	
	if(!equal(Classname, "weaponbox"))
		return FMRES_IGNORED
	
	static iOwner
	iOwner = pev(entity, pev_owner)
	
	if(equal(model, MODEL_WOLD))
	{
		static weapon; weapon = find_ent_by_owner(-1, weapon_vulcanus5, entity)
		
		if(!pev_valid(weapon))
			return FMRES_IGNORED;
		
		if(Get_BitVar(g_Had_Vulcanus5, iOwner))
		{
			set_pev(weapon, pev_impulse, 2782015)
			engfunc(EngFunc_SetModel, entity, MODEL_W)
		
			Remove_Vulcanus(iOwner)
			
			return FMRES_SUPERCEDE
		}
	}

	return FMRES_IGNORED;
}

public KimiGaSukiDakara(es, e, ent, host, hostflags, player, pSet)
{
	if(!player)
		return FMRES_IGNORED
	if(!is_alive(host) || !is_alive(MyTarget[host]) || MyTarget[host] != ent)
		return FMRES_IGNORED
	if(get_player_weapon(host) != CSW_VULCANUS5 || !Get_BitVar(g_Had_Vulcanus5, host))
		return FMRES_IGNORED
		
	static Color[3]
	if(g_GunState[host] != STATE_LOCKED) Color = {0, 170, 255}
	else Color = {255, 127, 42}
	
	set_es(es, ES_RenderFx, kRenderFxGlowShell)
	set_es(es, ES_RenderMode, kRenderNormal)
	set_es(es, ES_RenderColor, Color)
	set_es(es, ES_RenderAmt, 16)
	
	return FMRES_HANDLED
}

public Suigitou(Ent)
{
	if(pev_valid(Ent) != 2)
		return
	static Id; Id = get_pdata_cbase(Ent, 41, 4)
	if(get_pdata_cbase(Id, 373) != Ent)
		return
	if(!Get_BitVar(g_Had_Vulcanus5, Id))
		return
	
	set_pev(Id, pev_viewmodel2, MODEL_V)
	set_pev(Id, pev_weaponmodel2, MODEL_P)
	
	Set_WeaponAnim(Id, ANIME_DRAW)
	MyTarget[Id] = 0
}

public Shinku(Ent, id)
{
	if(!pev_valid(Ent))
		return HAM_IGNORED
		
	if(pev(Ent, pev_impulse) == 2782015)
	{
		Set_BitVar(g_Had_Vulcanus5, id)
		set_pev(Ent, pev_impulse, 0)
	}
	
	return HAM_HANDLED	
}

public SaigonVietnam(ent)
{
	static id; id = pev(ent, pev_owner)
	if(!is_user_alive(id))
		return HAM_IGNORED
	if(!Get_BitVar(g_Had_Vulcanus5, id))
		return HAM_IGNORED	
	
	static Float:flNextAttack; flNextAttack = get_pdata_float(id, 83, 5)
	static bpammo; bpammo = cs_get_user_bpammo(id, CSW_VULCANUS5)
	
	static iClip; iClip = get_pdata_int(ent, 51, 4)
	static fInReload; fInReload = get_pdata_int(ent, 54, 4)
	
	if(fInReload && flNextAttack <= 0.0)
	{
		static temp1
		temp1 = min(CLIP - iClip, bpammo)

		set_pdata_int(ent, 51, iClip + temp1, 4)
		cs_set_user_bpammo(id, CSW_VULCANUS5, bpammo - temp1)		
		
		set_pdata_int(ent, 54, 0, 4)
		
		fInReload = 0
	}		
	
	return HAM_IGNORED
}

public HanoiVietnam(ent)
{
	static id; id = pev(ent, pev_owner)
	if(!is_user_alive(id))
		return HAM_IGNORED
	if(!Get_BitVar(g_Had_Vulcanus5, id))
		return HAM_IGNORED	

	g_Clip[id] = -1
		
	static BPAmmo; BPAmmo = cs_get_user_bpammo(id, CSW_VULCANUS5)
	static iClip; iClip = get_pdata_int(ent, 51, 4)
		
	if(BPAmmo <= 0)
		return HAM_SUPERCEDE
	if(iClip >= CLIP)
		return HAM_SUPERCEDE		
			
	g_Clip[id] = iClip	
	
	return HAM_HANDLED
}

public HanoiVietnam_Post(ent)
{
	static id; id = pev(ent, pev_owner)
	if(!is_user_alive(id))
		return HAM_IGNORED
	if(!Get_BitVar(g_Had_Vulcanus5, id))
		return HAM_IGNORED	
	
	if((get_pdata_int(ent, 54, 4) == 1))
	{ // Reload
		if(g_Clip[id] == -1)
			return HAM_IGNORED
		
		set_pdata_int(ent, 51, g_Clip[id], 4)
		Set_WeaponAnim(id, ANIME_RELOAD)
		
		Set_PlayerNextAttack(id, TIME_RELOAD)
		MyTarget[id] = 0
	}
	
	return HAM_HANDLED
}

public Suiseiseki( iEnt )
{
	if(pev_valid(iEnt) != 2)
		return
	static Id; Id = get_pdata_cbase(iEnt, 41, 4)
	if(get_pdata_cbase(Id, 373) != iEnt)
		return
	if(!Get_BitVar(g_Had_Vulcanus5, Id))
		return
		
	//if(get_pdata_float(iEnt, 48, 4) <= 0.25)
	//{
		//Set_WeaponAnim(Id, g_Ammo[Id] > 0 ? ANIME_IDLE : ANIME_IDLE_EMPTY)
		//set_pdata_float(iEnt, 48, 20.0, 4)
	//}	
}

public NoCommunist(Victim, Attacker, Float:Damage, Float:Direction[3], Ptr, DamageBits)
{
	if(!is_connected(Attacker))
		return HAM_IGNORED	
	if(get_player_weapon(Attacker) != CSW_VULCANUS5 || !Get_BitVar(g_Had_Vulcanus5, Attacker))
		return HAM_IGNORED
		
	static Float:flEnd[3], Float:vecPlane[3]
		
	get_tr2(Ptr, TR_vecEndPos, flEnd)
	get_tr2(Ptr, TR_vecPlaneNormal, vecPlane)	
	
	static ID; ID = MyTarget[Attacker]
			
	if(is_alive(ID))
	{
		static Float:Origin[3]; pev(ID, pev_origin, Origin)
		
		set_tr2(Ptr, TR_vecEndPos, Origin)
		set_tr2(Ptr, TR_pHit, ID)
		
		ExecuteHamB(Ham_TraceAttack, ID, Attacker, Damage, Direction, Ptr, DamageBits)
		return HAM_SUPERCEDE
	} else {		
		Make_BulletHole(Attacker, flEnd, Damage)
		Make_BulletSmoke(Attacker, Ptr)
	
		SetHamParamFloat(3, float(DAMAGE))
	}
	
	return HAM_HANDLED
}

public ThisIsCapitalistVietnam(Victim, Attacker, Float:Damage, Float:Direction[3], Ptr, DamageBits)
{
	if(!is_connected(Attacker))
		return HAM_IGNORED	
	if(get_player_weapon(Attacker) != CSW_VULCANUS5 || !Get_BitVar(g_Had_Vulcanus5, Attacker))
		return HAM_IGNORED

	static ID; ID = MyTarget[Attacker]
	if(is_alive(ID) && Victim != ID)
	{
		static Float:Origin[3]; pev(ID, pev_origin, Origin)
		
		set_tr2(Ptr, TR_vecEndPos, Origin)
		set_tr2(Ptr, TR_pHit, ID)
		
		ExecuteHamB(Ham_TraceAttack, ID, Attacker, Damage, Direction, Ptr, DamageBits)
		return HAM_SUPERCEDE
	}
	
	SetHamParamFloat(3, float(DAMAGE))
	
	return HAM_HANDLED
}

stock get_can_see(Float:ent_origin[3], Float:target_origin[3])
{
	static Float:hit_origin[3]
	trace_line(-1, ent_origin, target_origin, hit_origin)                        

	if(!vector_distance(hit_origin, target_origin)) 
		return 1

	return 0
}

stock Suigintou_Transformation(ent, const Float:origin[3], Float:hudpos[2])
{
	static Float:origin2[3]
	origin2[0] = origin[0]
	origin2[1] = origin[1]
	origin2[2] = origin[2]

	static Float:ent_origin[3]

	pev(ent,pev_origin,ent_origin)

	static Float:ent_angles[3]

	pev(ent,pev_v_angle,ent_angles)

	origin2[0] -= ent_origin[0]
	origin2[1] -= ent_origin[1]
	origin2[2] -= ent_origin[2]

	static Float:v_length
	v_length = vector_length(origin2)

	static Float:aim_vector[3]
	aim_vector[0] = origin2[0] / v_length
	aim_vector[1] = origin2[1] / v_length
	aim_vector[2] = origin2[2] / v_length

	static Float:new_angles[3]
	vector_to_angle(aim_vector,new_angles)

	new_angles[0] *= -1

	if(new_angles[1]>180.0) new_angles[1] -= 360.0
	if(new_angles[1]<-180.0) new_angles[1] += 360.0
	if(new_angles[1]==180.0 || new_angles[1]==-180.0) new_angles[1]=-179.999999

	if(new_angles[0]>180.0) new_angles[0] -= 360.0
	if(new_angles[0]<-180.0) new_angles[0] += 360.0
	if(new_angles[0]==90.0) new_angles[0]=89.999999
	else if(new_angles[0]==-90.0) new_angles[0]=-89.999999

	static Float:fov
	pev(ent,pev_fov,fov)

	if(!fov)
		fov = 90.0

	if(floatabs(ent_angles[0] - new_angles[0]) <= fov/2 && floatabs((180.0 - floatabs(ent_angles[1])) - (180.0 - floatabs(new_angles[1]))) <= fov/2)
	{
		hudpos[1] = 1 - ( ( (ent_angles[0] - new_angles[0]) + fov/2 ) / fov )
		hudpos[0] = ( (ent_angles[1] - new_angles[1]) + fov/2 ) / fov
	}
	else
		return 0;

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

public is_connected(id)
{
	if(!(1 <= id <= 32))
		return 0
	if(!Get_BitVar(g_IsConnected, id))
		return 0

	return 1
}

public is_alive(id)
{
	if(!is_connected(id))
		return 0
	if(!Get_BitVar(g_IsAlive, id))
		return 0
		
	return 1
}

public get_player_weapon(id)
{
	if(!is_alive(id))
		return 0
	
	return g_PlayerWeapon[id]
}


stock Set_WeaponAnim(id, anim)
{
	set_pev(id, pev_weaponanim, anim)
	
	message_begin(MSG_ONE_UNRELIABLE, SVC_WEAPONANIM, {0, 0, 0}, id)
	write_byte(anim)
	write_byte(pev(id, pev_body))
	message_end()
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

stock Eject_Shell(id, Shell_ModelIndex, Float:Time) // By Dias
{
	static Ent; Ent = get_pdata_cbase(id, 373, 5)
	if(!pev_valid(Ent))
		return

        set_pdata_int(Ent, 57, Shell_ModelIndex, 4)
        set_pdata_float(id, 111, get_gametime() + Time)
}
