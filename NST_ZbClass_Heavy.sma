#include <amxmodx>
#include <amxmisc>
#include <fakemeta>
#include <hamsandwich>
#include <engine>
#include <nst_zombie>

#define PLUGIN "NST Zombie Class Heavy"
#define VERSION "1.0"
#define AUTHOR "NST"

// Zombie Attributes
new const zclass_name[] = "Heavy Zombie (Dat Bay2)" // name
new const zclass_model[] = "heavy_zombi" // model
const zclass_health = 3000 // health
const Float:zclass_speed = 270.0 // speed
const Float:zclass_gravity = 1.2 // gravity
const Float:zclass_knockback = 1.0 // knockback
const zclass_sex = 1
const zclass_modelindex = 3
new const zclass_hurt1[] = "nst_zombie/zombi_hurt_heavy_1.wav"
new const zclass_hurt2[] = "nst_zombie/zombi_hurt_heavy_2.wav"
new const zclass_death1[] = "nst_zombie/zombi_death_1.wav"
new const zclass_death2[] = "nst_zombie/zombi_death_2.wav"
new const zclass_heal[] = "nst_zombie/zombi_heal_heavy.wav"
new const zclass_evolution[] = "nst_zombie/zombi_evolution.wav"
new const model_trap[] = "models/nst_zombie/zombitrap.mdl"
new const sound_trapsetup[] = "nst_zombie/zombi_trapsetup.wav"
new const sound_trapped[] = "nst_zombie/zombi_trapped.wav"
new const sprites_trap[] = "sprites/nst_zombie/trap.spr"

const MAX_TRAP = 30
const MAX_TRAP_SLOTS = MAX_TRAP + 1
new const trap_classname[] = "nst_zb_traps"

// Class IDs
new g_zclass_heavy
new g_zb_mod

// Cvars
new trap_total, trap_timewait, trapped_time, trap_timesetup, trap_invisible

// Vars
new g_total_traps[33], g_msgScreenShake, g_msgStatusIcon, g_trapping[33], g_player_trapped[33]
new g_waitsetup[33], g_trap_icon_shown[33], TrapOrigins[33][MAX_TRAP_SLOTS][4], idsprites_trap
// Task offsets
enum (+= 100)
{
	TASK_TRAPSETUP = 2000,
	TASK_REMOVETRAP,
	TASK_REMOVE_TIMEWAIT,
	TASK_BOT_USE_SKILL
}
// IDs inside tasks
#define ID_TRAPSETUP (taskid - TASK_TRAPSETUP)
#define ID_REMOVETRAP (taskid - TASK_REMOVETRAP)
#define ID_REMOVE_TIMEWAIT (taskid - TASK_REMOVE_TIMEWAIT)
#define ID_BOT_USE_SKILL (taskid - TASK_BOT_USE_SKILL)

public plugin_init()
{
	register_plugin("[ZBU] Zombie Class: Heavy", "1.0", "Dias")
	
	// Msg
	g_msgScreenShake = get_user_msgid("ScreenShake")
	g_msgStatusIcon = get_user_msgid("StatusIcon")
	
	// Events
	register_logevent("logevent_round_start",2, "1=Round_Start")
	register_event("HLTV", "event_round_start", "a", "1=0", "2=0")
	register_event("DeathMsg", "Death", "a")
	register_forward(FM_PlayerPreThink, "fw_PlayerPreThink")
	register_forward(FM_CmdStart, "fw_CmdStart")
	
	// Cvars
	trap_total = register_cvar("nst_zb_zheavy_trap_total", "3")
	trap_timewait = register_cvar("nst_zb_zheavy_trap_timewait", "10.0")
	trap_timesetup = register_cvar("nst_zb_zheavy_trap_timesetup", "2.0")
	trap_invisible = register_cvar("nst_zb_zheavy_trap_invisible", "10")
	trapped_time = register_cvar("nst_zb_zheavy_trapped_time", "8.0")
	
	// Client Cmd
	register_clcmd("drop", "cmd_setuptrap")
}

public plugin_precache()
{
	engfunc(EngFunc_PrecacheModel, model_trap)
	engfunc(EngFunc_PrecacheSound, sound_trapsetup)
	engfunc(EngFunc_PrecacheSound, sound_trapped)
	idsprites_trap = engfunc(EngFunc_PrecacheModel, sprites_trap)
	g_zb_mod = nst_zb_get_mod()

	switch (g_zb_mod)
	{
		case NSTZB_ZB3:
		{
			g_zclass_heavy = nst_zb3_register_zombie_class(zclass_name, zclass_model, zclass_gravity,
			zclass_speed, zclass_knockback, zclass_death1, zclass_death2,
			zclass_hurt1, zclass_hurt2, zclass_heal, zclass_evolution, zclass_sex, zclass_modelindex)
		}
		default:
		{
			g_zclass_heavy = nst_zbu_register_zombie_class(zclass_name, zclass_model, zclass_health,
			zclass_gravity, zclass_speed, zclass_knockback, zclass_death1, zclass_death2,
			zclass_hurt1, zclass_hurt2, zclass_heal, zclass_sex, zclass_modelindex)
		}
	}
}

public nst_zb_user_infected(id, infector)
{
    if (is_valid_player_id(id))
    {
        remove_setuptrap(id);

        if (task_exists(id + TASK_REMOVE_TIMEWAIT))
            remove_task(id + TASK_REMOVE_TIMEWAIT);

        g_waitsetup[id] = 0;
    }

    remove_trapped_when_infected(id);
    clear_trap_icon(id);
}

public event_round_start()
{
	for (new id=1; id<33; id++)
	{
		if (!is_user_connected(id)) continue;
		
		reset_value_player(id)
	}
	
	// remove trap
	remove_traps()
}
public logevent_round_start()
{
	for (new id=1; id<33; id++)
	{
		if (!is_user_connected(id)) continue;
		if (is_user_bot(id))
		{
			if (task_exists(id+TASK_BOT_USE_SKILL)) remove_task(id+TASK_BOT_USE_SKILL)
			set_task(float(random_num(5,15)), "bot_use_skill", id+TASK_BOT_USE_SKILL)
		}
	}
}
public Death()
{
    new victim = read_data(2);

    if (is_valid_player_id(victim))
    {
        remove_setuptrap(victim);

        if (task_exists(victim + TASK_REMOVE_TIMEWAIT))
            remove_task(victim + TASK_REMOVE_TIMEWAIT);

        g_waitsetup[victim] = 0;
    }

    remove_trapped_when_infected(victim);
    clear_trap_icon(victim);
}

public client_connect(id)
{
	reset_value_player(id)
}
public client_disconnect(id)
{
	reset_value_player(id)
}
reset_value_player(id)
{
	if (task_exists(id+TASK_TRAPSETUP)) remove_task(id+TASK_TRAPSETUP)
	if (task_exists(id+TASK_REMOVETRAP)) remove_task(id+TASK_REMOVETRAP)
	if (task_exists(id+TASK_REMOVE_TIMEWAIT)) remove_task(id+TASK_REMOVE_TIMEWAIT)
	if (task_exists(id+TASK_BOT_USE_SKILL)) remove_task(id+TASK_BOT_USE_SKILL)
	
	g_total_traps[id] = 0
	g_trapping[id] = 0
	g_player_trapped[id] = 0
	clear_trap_icon(id)
	
	remove_traps_player(id)
}
// bot use skill
public bot_use_skill(taskid)
{
	new id = ID_BOT_USE_SKILL
	if (!is_user_bot(id)) return;

	cmd_setuptrap(id)

	if (task_exists(taskid)) remove_task(taskid)
	set_task(float(random_num(5,15)), "bot_use_skill", id+TASK_BOT_USE_SKILL)
}
public fw_CmdStart(id, uc_handle, seed)
{
	if (!is_user_alive(id)) return;
	
	// icon help
	if (nst_zb_get_user_zombie(id) && nst_zb_get_user_zombie_class(id) == g_zclass_heavy)
	{
		// check trapping
		if (g_trapping[id])
		{
			// remove setup trap if player move
			static Float:velocity[3]
			pev(id, pev_velocity, velocity)
			if (velocity[0] || velocity[1] || velocity[2])
			{
				remove_setuptrap(id)
			}
		}

	}
	
	// player pickup trap
	new ent_trap = g_player_trapped[id]
	if (ent_trap && pev_valid(ent_trap))
	{
		// sequence of trap model
		static classname[32]
		pev(ent_trap, pev_classname, classname, charsmax(classname))
		if (equal(classname, trap_classname))
		{
			if (pev(ent_trap, pev_sequence) != 1)
			{
				set_pev(ent_trap, pev_sequence, 1)
				set_pev(ent_trap, pev_frame, 0.0)
			}
			else
			{
				if (pev(ent_trap, pev_frame) > 230)
					set_pev(ent_trap, pev_frame, 20.0)
				else
					set_pev(ent_trap, pev_frame, pev(ent_trap, pev_frame) + 1.0)
			}
			//client_print(0, print_chat, "[%i][%i]", pev(ent_trap, pev_sequence), pev(ent_trap, pev_frame))
		}
		//client_print(0, print_chat, "[%s]", classname)
	}
	
	return;
}
// don't move when traped
public fw_PlayerPreThink(id)
{
	if (!is_user_alive(id)) return;
	
	new ent_trap = g_player_trapped[id]
	if (ent_trap && pev_valid(ent_trap))
	{
		set_pev(id, pev_maxspeed, 0.01)
	}
}
// trapped
public pfn_touch(ptr, ptd)
{
	if(pev_valid(ptr))
	{
		new classname[32]
		pev(ptr, pev_classname, classname, charsmax(classname))
		//client_print(ptd, print_chat, "[%s][%i]", classname, ptr)
		
		if(equal(classname, trap_classname))
		{
			new victim = ptd
			new attacker = pev(ptr, pev_owner)
			if (is_user_alive(victim) && (get_user_team(attacker) != get_user_team(victim)) && victim != attacker && !g_player_trapped[victim])
			//if (is_user_alive(victim) && !nst_zb_get_user_zombie(victim) && g_player_trapped[victim] != ptr)
			{
				Trapped(victim, ptr)
			}
		}
	}
}
// #################### TRAP PUBLIC ####################
// show icon drap
public client_PostThink(id)
{
    if (id < 1 || id > 32) return;
    if (!is_user_alive(id)) return;

    if (nst_zb_get_user_zombie(id) && nst_zb_get_user_zombie_class(id) == g_zclass_heavy)
    {
        show_trap_icon(id);
    }
    else
    {
        clear_trap_icon(id);
        return;
    }

    if (g_total_traps[id] <= 0) return;

	// if counter is corrupted, clear data to prevent potential abuse and other issues.
    if (g_total_traps[id] > MAX_TRAP)
    {
        clear_trap_data(id);
        return;
    }

    for (new i = 1; i <= g_total_traps[id]; i++)
    {
        DrawSprite(id, i);
    }
}

// cmd use skill
public cmd_setuptrap(id)
{
	if (!is_user_alive(id) || !nst_zb_get_take_damage()) return PLUGIN_CONTINUE

	if (nst_zb_get_user_zombie(id) && nst_zb_get_user_zombie_class(id) == g_zclass_heavy)
	{
		// check setupping
		if (g_trapping[id] || g_waitsetup[id]) return PLUGIN_HANDLED
		
		// check total trap
		new level = nst_zb_get_user_level(id)
			new max_traps = get_pcvar_num(trap_total)
			if (level==1) max_traps = max_traps/2
			if (max_traps > MAX_TRAP) max_traps = MAX_TRAP
			if (g_total_traps[id]>=max_traps)
			{
			new message[100]
				new prefix[24]
				get_mod_prefix(prefix, charsmax(prefix))
				format(message, charsmax(message), "^x04%s^x01 %L", prefix, LANG_PLAYER, "CLASS_NOTICE_MAXTRAP", max_traps)
				nst_zb_color_saytext(id, message)
				return PLUGIN_HANDLED
			}
		 
		// set trapping
		g_trapping[id] = 1
		bartime(id, FloatToNum(get_pcvar_float(trap_timesetup)))
		
		// set task
		if (task_exists(id+TASK_TRAPSETUP)) remove_task(id+TASK_TRAPSETUP)
		set_task(get_pcvar_float(trap_timesetup), "TrapSetup", id+TASK_TRAPSETUP)
		
		//client_print(id, print_chat, "[%i]", fnFloatToNum(time_invi))
		return PLUGIN_HANDLED
	}
	
	return PLUGIN_CONTINUE
}
public TrapSetup(taskid)
{
    new id = ID_TRAPSETUP;

    if (!is_valid_heavy_zombie(id))
    {
        if (is_valid_player_id(id))
            remove_setuptrap(id);

        if (task_exists(taskid))
            remove_task(taskid);

        return;
    }

    remove_setuptrap(id);

    new result = create_w_class(id);
    if (result <= 0)
    {
        if (task_exists(taskid))
            remove_task(taskid);

        return;
    }

    PlayEmitSound(id, sound_trapsetup);

    if (task_exists(taskid))
        remove_task(taskid);

    g_waitsetup[id] = 1;

    if (task_exists(id + TASK_REMOVE_TIMEWAIT))
        remove_task(id + TASK_REMOVE_TIMEWAIT);

    set_task(get_pcvar_float(trap_timewait), "RemoveTimeWait", id + TASK_REMOVE_TIMEWAIT);
}
public RemoveTimeWait(taskid)
{
	new id = ID_REMOVE_TIMEWAIT
	g_waitsetup[id] = 0
	if (task_exists(taskid)) remove_task(taskid)
}
remove_setuptrap(id)
{
	g_trapping[id] = 0
	bartime(id, 0)
	if (task_exists(id+TASK_TRAPSETUP)) remove_task(id+TASK_TRAPSETUP)
}
Trapped(id, ent_trap)
{
	// check trapped
	for (new i=1; i<33; i++)
	{
		if (is_user_connected(i) && g_player_trapped[i]==ent_trap) return;
	}
	
	// set ent trapped of player
	g_player_trapped[id] = ent_trap
	
	// set screen shake
	user_screen_shake(id, 4, 2, 5)

	// stop move
	//if (!(user_flags & FL_FROZEN)) set_pev(id, pev_flags, (user_flags | FL_FROZEN))
			
	// play sound
	PlayEmitSound(id, sound_trapped)
	
	// reset invisible model trapped
	fm_set_rendering(ent_trap)

	// set task remove trap
	if (task_exists(id+TASK_REMOVETRAP)) remove_task(id+TASK_REMOVETRAP)
	set_task(get_pcvar_float(trapped_time), "RemoveTrap", id+TASK_REMOVETRAP)
	
	// update TrapOrigins
	UpdateTrap(ent_trap)
}
UpdateTrap(ent_trap)
{
	//new id = entity_get_int(ent_trap, EV_INT_iuser1)
	new id = pev(ent_trap, pev_owner)

	new total, TrapOrigins_new[MAX_TRAP_SLOTS][4]
	new trap_count = g_total_traps[id]
	if (trap_count > MAX_TRAP) trap_count = MAX_TRAP
	for (new i = 1; i <= trap_count; i++)
	{
		if (TrapOrigins[id][i][0] != ent_trap)
		{
			total += 1
			if (total > MAX_TRAP) break
			TrapOrigins_new[total][0] = TrapOrigins[id][i][0]
			TrapOrigins_new[total][1] = TrapOrigins[id][i][1]
			TrapOrigins_new[total][2] = TrapOrigins[id][i][2]
			TrapOrigins_new[total][3] = TrapOrigins[id][i][3]
		}
	}
	TrapOrigins[id] = TrapOrigins_new
	g_total_traps[id] = total
}
public RemoveTrap(taskid)
{
	new id = ID_REMOVETRAP
	
	// set speed for player
	//set_pev(id, pev_flags, (pev(id, pev_flags) & ~FL_FROZEN))
	
	// remove trap
	remove_trapped_when_infected(id)
	
	if (task_exists(taskid)) remove_task(taskid)
}
remove_trapped_when_infected(id)
{
	new p_trapped = g_player_trapped[id]
	if (p_trapped)
	{
		// remove trap
		if (pev_valid(p_trapped)) engfunc(EngFunc_RemoveEntity, p_trapped)
		
		// reset value of player
		g_player_trapped[id] = 0
	}
}
show_trap_icon(id)
{
	if (!is_user_connected(id) || g_trap_icon_shown[id]) return;

	g_trap_icon_shown[id] = 1
	message_begin(MSG_ONE, g_msgStatusIcon, _, id)
	write_byte(1)
	write_string("g_trap")
	write_byte(255)
	write_byte(240)
	write_byte(161)
	message_end()
}
clear_trap_icon(id)
{
	if (!g_trap_icon_shown[id]) return;

	g_trap_icon_shown[id] = 0
	if (!is_user_connected(id)) return;

	message_begin(MSG_ONE, g_msgStatusIcon, _, id)
	write_byte(0)
	write_string("g_trap")
	write_byte(0)
	write_byte(0)
	write_byte(0)
	message_end()
}
create_w_class(id)
{
    if (!is_valid_heavy_zombie(id)) return 0;

    if (g_total_traps[id] < 0)
        g_total_traps[id] = 0;

    // Keep this as MAX_TRAP, not MAX_TRAP - 1.
    if (g_total_traps[id] >= MAX_TRAP)
        return 0;

    new user_flags = pev(id, pev_flags);
    if (!(user_flags & FL_ONGROUND))
        return 0;

    new Float:origin[3];
    pev(id, pev_origin, origin);

    new ent = engfunc(EngFunc_CreateNamedEntity, engfunc(EngFunc_AllocString, "info_target"));
    if (!pev_valid(ent))
        return 0;

    set_pev(ent, pev_classname, trap_classname);
    set_pev(ent, pev_solid, SOLID_TRIGGER);
    set_pev(ent, pev_movetype, 6);
    set_pev(ent, pev_sequence, 0);
    set_pev(ent, pev_frame, 0.0);
    set_pev(ent, pev_owner, id);

    new Float:mins[3] = { -20.0, -20.0, 0.0 };
    new Float:maxs[3] = { 20.0, 20.0, 30.0 };
    engfunc(EngFunc_SetSize, ent, mins, maxs);

    engfunc(EngFunc_SetModel, ent, model_trap);
    set_pev(ent, pev_origin, origin);

    fm_set_rendering(ent, kRenderFxGlowShell, 0, 0, 0, kRenderTransAlpha, get_pcvar_num(trap_invisible));

    g_total_traps[id] += 1;

    if (g_total_traps[id] < 1 || g_total_traps[id] > MAX_TRAP)
    {
        g_total_traps[id] = MAX_TRAP;

        if (pev_valid(ent))
            engfunc(EngFunc_RemoveEntity, ent);

        return 0;
    }

    new slot = g_total_traps[id];

    TrapOrigins[id][slot][0] = ent;
    TrapOrigins[id][slot][1] = floatround(origin[0]);
    TrapOrigins[id][slot][2] = floatround(origin[1]);
    TrapOrigins[id][slot][3] = floatround(origin[2]);

    return ent;
}
PlayEmitSound(id, const sound[])
{
	emit_sound(id, CHAN_VOICE, sound, 1.0, ATTN_NORM, 0, PITCH_NORM)
}
fm_set_rendering(entity, fx = kRenderFxNone, r = 255, g = 255, b = 255, render = kRenderNormal, amount = 16) 
{
	new Float:RenderColor[3];
	RenderColor[0] = float(r);
	RenderColor[1] = float(g);
	RenderColor[2] = float(b);

	set_pev(entity, pev_renderfx, fx);
	set_pev(entity, pev_rendercolor, RenderColor);
	set_pev(entity, pev_rendermode, render);
	set_pev(entity, pev_renderamt, float(amount));

	return 1;
}

FloatToNum(Float:floatn)
{
	new str[64], num
	float_to_str(floatn, str, 63)
	num = str_to_num(str)
	
	return num
}
stock get_mod_prefix(prefix[], len)
{
	if (g_zb_mod == NSTZB_ZB3)
	{
		formatex(prefix, len, "[Zombie Mod 3]")
		return;
	}

	formatex(prefix, len, "[Zombie United]")
}
bartime(id, time_run)
{
	message_begin(MSG_ONE, get_user_msgid("BarTime"), _, id)
	write_short(time_run)
	message_end()
}
DrawSprite(id, idtrap)
{
    if (id < 1 || id > 32) return;
    if (!is_user_connected(id)) return;
    if (idtrap < 1 || idtrap > MAX_TRAP) return;

    if (g_total_traps[id] < 1) return;
    if (g_total_traps[id] > MAX_TRAP)
    {
        g_total_traps[id] = 0;
        return;
    }

    if (idtrap > g_total_traps[id]) return;

    new ent = TrapOrigins[id][idtrap][0];

    // IMPORTANT: sanity check raw entity number before pev_valid/is_valid_ent
    if (ent <= 0 || ent > global_get(glb_maxEntities))
    {
        TrapOrigins[id][idtrap][0] = 0;
        TrapOrigins[id][idtrap][1] = 0;
        TrapOrigins[id][idtrap][2] = 0;
        TrapOrigins[id][idtrap][3] = 0;
        return;
    }

    if (!pev_valid(ent))
    {
        TrapOrigins[id][idtrap][0] = 0;
        TrapOrigins[id][idtrap][1] = 0;
        TrapOrigins[id][idtrap][2] = 0;
        TrapOrigins[id][idtrap][3] = 0;
        return;
    }

    if (idsprites_trap <= 0) return;

    new x = TrapOrigins[id][idtrap][1];
    new y = TrapOrigins[id][idtrap][2];
    new z = TrapOrigins[id][idtrap][3];

    // Avoid sending insane corrupted coords.
    if (x < -32768 || x > 32767) return;
    if (y < -32768 || y > 32767) return;
    if (z < -32768 || z > 32767) return;

    message_begin(MSG_ONE_UNRELIABLE, SVC_TEMPENTITY, _, id);
    write_byte(TE_SPRITE);
    write_coord(x);
    write_coord(y);
    write_coord(z);
    write_short(idsprites_trap);
    write_byte(2);
    write_byte(30);
    message_end();
}
remove_traps()
{
    new nextitem = find_ent_by_class(-1, trap_classname);
    while (nextitem)
    {
        remove_entity(nextitem);
        nextitem = find_ent_by_class(-1, trap_classname);
    }

    for (new id = 1; id <= 32; id++)
    {
        g_total_traps[id] = 0;

        for (new i = 0; i <= MAX_TRAP; i++)
        {
            TrapOrigins[id][i][0] = 0;
            TrapOrigins[id][i][1] = 0;
            TrapOrigins[id][i][2] = 0;
            TrapOrigins[id][i][3] = 0;
        }
    }
}
remove_traps_player(id)
{
    if (id < 1 || id > 32) return;

    new trap_count = g_total_traps[id];
    if (trap_count > MAX_TRAP) trap_count = MAX_TRAP;

    for (new i = 1; i <= trap_count; i++)
    {
        new trap_ent = TrapOrigins[id][i][0];

        if (trap_ent > 0 && trap_ent <= global_get(glb_maxEntities) && pev_valid(trap_ent))
            engfunc(EngFunc_RemoveEntity, trap_ent);
    }

    clear_trap_data(id);
}
user_screen_shake(id, amplitude = 4, duration = 2, frequency = 10)
{
	message_begin(MSG_ONE_UNRELIABLE, g_msgScreenShake, _, id)
	write_short((1<<12)*amplitude) // ??
	write_short((1<<12)*duration) // ??
	write_short((1<<12)*frequency) // ??
	message_end()
}


stock bool:is_valid_player_id(id)
{
    return (1 <= id <= 32);
}

stock bool:is_valid_heavy_zombie(id)
{
    if (!is_valid_player_id(id)) return false;
    if (!is_user_connected(id)) return false;
    if (!is_user_alive(id)) return false;
    if (!nst_zb_get_take_damage()) return false;
    if (!nst_zb_get_user_zombie(id)) return false;
    if (nst_zb_get_user_zombie_class(id) != g_zclass_heavy) return false;

    return true;
}


stock clear_trap_data(id)
{
    if (id < 1 || id > 32) return;

    g_total_traps[id] = 0;

    for (new i = 0; i <= MAX_TRAP; i++)
    {
        TrapOrigins[id][i][0] = 0;
        TrapOrigins[id][i][1] = 0;
        TrapOrigins[id][i][2] = 0;
        TrapOrigins[id][i][3] = 0;
    }
}
