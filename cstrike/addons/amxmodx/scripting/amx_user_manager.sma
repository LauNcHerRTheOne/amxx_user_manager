#include <amxmodx>
#include <amxmisc>
#include <reapi>
#include <query_manager>

new g_query[1024], g_msg_screenfade, g_msg_bartime, g_forward_next, g_forward_leave, g_forward_guest, g_ip[32];
new g_id[33], g_username[33][32], g_password[33][32], g_new_password[33][32], g_page[33], g_status[33], g_message[33][64], g_second[33];
new g_cv_auto_join, g_cv_black_screen, g_cv_auto_guest, g_cv_auto_menu, g_cv_auto_login, g_cv_password, g_cv_steam;
new g_qm_putinserver, g_qm_register_user, g_qm_auth_user, g_qm_remake_user, g_qm_password, g_qm_steam;
new bool: g_completed[33], bool: g_steam[33], bool: g_first[33], bool: g_selected[33];
new g_user_requirement = 1, g_completed_user_requirement[33];

enum _: PAGES {

	PG_MAIN,
	PG_REGISTER,
	PG_LOGIN,
	PG_EDIT,
	PG_PASSWORD
}

enum _: STATUSES {

	ST_NONE,
	ST_PENDING_REGISTER,
	ST_PENDING_LOGIN,
	ST_COMPLETED,
	ST_REMAKE,
	ST_PASSWORD,
	ST_STEAM,
}

public plugin_init() {
	
	register_plugin("User Manager", "1.0.0", "JohanCorn");

	register_clcmd("Username", "cmd_username");
	register_clcmd("Pass", "cmd_password");
	register_clcmd("NewPass", "cmd_new_password");

	register_clcmd("chooseteam", "cmd_chooseteam");

	register_clcmd("jointeam 1", "cmd_join");
	register_clcmd("jointeam 2", "cmd_join");
	register_clcmd("jointeam 3", "cmd_join");
	register_clcmd("jointeam 4", "cmd_join");
	register_clcmd("jointeam 5", "cmd_join");
	register_clcmd("jointeam 6", "cmd_join");
	
	register_clcmd("joinclass 1", "cmd_join");
	register_clcmd("joinclass 2", "cmd_join");
	register_clcmd("joinclass 3", "cmd_join");
	register_clcmd("joinclass 4", "cmd_join");
	register_clcmd("joinclass 5", "cmd_join");
	register_clcmd("joinclass 6", "cmd_join");

	register_clcmd("say /reg", "cmd_reg");
	register_clcmd("say_team /reg", "cmd_reg");

	register_message(get_user_msgid("ShowMenu"), "message_showmenu");
	register_message(get_user_msgid("VGUIMenu"), "message_vguimenu");

	register_menu("user_menu", 1023, "menu_user");

	g_qm_register_user = qm_register_type(_, "register_user");
	g_qm_auth_user = qm_register_type(_, "auth_user");
	g_qm_putinserver = qm_register_type(_, "putinserver");
	g_qm_remake_user = qm_register_type(_, "remake_user");
	g_qm_password = qm_register_type(_, "password");
	g_qm_steam = qm_register_type(_, "steam");

	g_msg_screenfade = get_user_msgid("ScreenFade");
	g_msg_bartime = get_user_msgid("BarTime");

	g_cv_auto_menu = register_cvar("amx_um_auto_menu", "1");
	g_cv_auto_join = register_cvar("amx_um_auto_join", "1");
	g_cv_auto_login = register_cvar("amx_um_auto_login", "1");
	g_cv_black_screen = register_cvar("amx_um_black_screen", "0");
	g_cv_auto_guest = register_cvar("amx_um_auto_gest", "0");
	g_cv_password = register_cvar("amx_um_password", "1");
	g_cv_steam = register_cvar("amx_um_steam", "1");

	register_dictionary("user_manager.txt");

	g_forward_next = CreateMultiForward("fw_User_Manager_Next", ET_CONTINUE, FP_CELL);
	g_forward_leave = CreateMultiForward("fw_User_Manager_Leave", ET_CONTINUE, FP_CELL);
	g_forward_guest = CreateMultiForward("fw_User_Manager_Guest", ET_CONTINUE, FP_CELL);

	get_user_ip(0, g_ip, charsmax(g_ip));
}

public plugin_cfg() {

	AutoExecConfig();

	set_task_ex(0.5, "def");
}

public def() {

	new players[32], pnum, id;
	get_players_ex(players, pnum, GetPlayers_ExcludeBots|GetPlayers_ExcludeHLTV);

	for ( new i; i < pnum; i ++ ) {

		id = players[i];

		if ( g_status[id] != ST_PENDING_REGISTER && g_status[id] != ST_PENDING_LOGIN )
			continue;

		create_or_login_user_if_true(id, g_status[id] == ST_PENDING_REGISTER);
	}
}

public plugin_natives() {

	register_library("user_manager");

	register_native("um_get_user_id", "native_get_user_id", 1);
	register_native("um_register_user_requirement", "native_register_user_requirement", 1);
	register_native("um_complete_user_requirement", "native_complete_user_requirement", 1);
	register_native("um_is_user_requirements_completed", "native_is_user_requirements_completed", 1);
}

public native_get_user_id(id) {

	return g_id[id];
}

public native_register_user_requirement() {

	g_user_requirement ++;
}

public native_complete_user_requirement(id) {

	complete_user_requirement(id);
}

public native_is_user_requirements_completed(id) {

	return g_completed_user_requirement[id] == g_user_requirement;
}

public complete_user_requirement(id) {

	g_completed_user_requirement[id] ++;

	if ( g_completed_user_requirement[id] != g_user_requirement )
		return;

	g_selected[id] = true;

	show_menu(id, 1023, "^n");
	fade_screen(id, false);
	time_bar(id, 0);
	remove_task(id);

	if ( !get_user_team(id) )
		client_cmd(id, get_pcvar_bool(g_cv_auto_join) ? "jointeam 5" : "chooseteam");

	static name[32];
	get_user_name(id, name, charsmax(name));

	client_print_color(id, id, "%L %L", id, "UM_PREFIX", id, "UM_HI", name, g_id[id]);
}

public mysql_putinserver(id) {

	if ( !qm_is_preload_completed() )
			return;

	if ( g_status[id] == ST_PENDING_REGISTER || g_status[id] == ST_PENDING_LOGIN )
		return;

	static username_fix[64];
	SQL_QuoteString(Empty_Handle, username_fix, charsmax(username_fix), g_username[id]);

	static name[32], name_fix[64];
	get_user_name(id, name, charsmax(name));
	SQL_QuoteString(Empty_Handle, name_fix, charsmax(name_fix), name);

	static steam_id[32], steam_id_fix[64];
	get_user_authid(id, steam_id, charsmax(steam_id));
	SQL_QuoteString(Empty_Handle, steam_id_fix, charsmax(steam_id_fix), steam_id);

	static ip_address[32], ip_address_fix[64];
	get_user_ip(id, ip_address, charsmax(ip_address), 1);
	SQL_QuoteString(Empty_Handle, ip_address_fix, charsmax(ip_address_fix), ip_address);

	if ( g_username[id][0] != EOS )
		format(g_query, charsmax(g_query), "CALL `putinserver` ('%s', '%s', '%s', '%s', '%s');", username_fix, name_fix, steam_id_fix, ip_address_fix, g_ip);
	else
		format(g_query, charsmax(g_query), "CALL `putinserver` (NULL, '%s', '%s', '%s', '%s');", name_fix, steam_id_fix, ip_address_fix, g_ip);

	qm_create_query(g_qm_putinserver, g_query, id);
}

public client_putinserver(id) {

	static username[32];
	get_user_info(id, "hk_username", username, charsmax(username));

	if ( username[0] != EOS && strlen(username) >= 4 )
		copy(g_username[id], 31, username);

	if ( !get_pcvar_bool(g_cv_auto_login) || !get_pcvar_bool(g_cv_steam) )
		return;

	if ( !is_user_steam(id) )
		return;

	mysql_putinserver(id);
}

public client_disconnected(id) {

	if ( g_status[id] >= ST_COMPLETED ) {

		static result;
		ExecuteForward(g_forward_leave, result, id);
	}

	g_id[id] = 0;
	g_username[id][0] = EOS;
	g_password[id][0] = EOS;
	g_completed[id] = false;
	g_steam[id] = false;
	g_first[id] = false;
	g_selected[id] = false;
	g_page[id] = PG_MAIN;
	g_status[id] = ST_NONE;
	g_completed_user_requirement[id] = 0;

	remove_task(id);
}

public cmd_username(id) {
	
	if ( !is_user_connected(id) || g_status[id] == ST_PENDING_REGISTER || g_status[id] == ST_PENDING_LOGIN )
		return PLUGIN_HANDLED;
	
	read_args(g_username[id], 31);
	remove_quotes(g_username[id]);

	show_user_menu(id);

	return PLUGIN_HANDLED;
}

public cmd_password(id) {
	
	if ( !is_user_connected(id) || g_status[id] == ST_PENDING_REGISTER || g_status[id] == ST_PENDING_LOGIN )
		return PLUGIN_HANDLED;
	
	read_args(g_password[id], 31);
	remove_quotes(g_password[id]);

	show_user_menu(id);
	
	return PLUGIN_HANDLED;
}

public cmd_new_password(id) {
	
	if ( !is_user_connected(id) )
		return PLUGIN_HANDLED;
	
	read_args(g_new_password[id], 31);
	remove_quotes(g_new_password[id]);

	show_user_menu(id);
	
	return PLUGIN_HANDLED;
}

public cmd_chooseteam(id) {
	
	if ( !is_user_connected(id) )
		return PLUGIN_HANDLED;

	if ( !g_selected[id] ) {

		show_user_menu(id);

		return PLUGIN_HANDLED;
	}

	return PLUGIN_CONTINUE;
}

public cmd_join(id) {

	if ( !g_selected[id] )
		return PLUGIN_HANDLED;

	return PLUGIN_CONTINUE;
}

public cmd_reg(id) {

	g_page[id] = g_id[id] ? PG_EDIT : PG_MAIN;

	show_user_menu(id);
}

public message_showmenu(msg_id, msg_dest, msg_entity) {

	static text[32];
	get_msg_arg_string(4, text, charsmax(text));

	if ( equal(text, "#Terrorist_Select") || equal(text, "#CT_Select") ) {

		client_cmd(msg_entity, "joinclass 5");

		return PLUGIN_HANDLED;
	}

	if ( !equal(text, "#Team_Select") && !equal(text, "#Team_Select_Spect") && !equal(text, "#IG_Team_Select") && !equal(text, "#IG_Team_Select_Spect") )
		return PLUGIN_CONTINUE;

	if ( !g_first[msg_entity] ) {

		g_first[msg_entity] = true;

		start_progress(msg_entity);

		if ( get_pcvar_bool(g_cv_auto_menu) )
			show_user_menu(msg_entity);

		return PLUGIN_HANDLED;
	}

	if ( g_status[msg_entity] >= ST_COMPLETED )
		return PLUGIN_CONTINUE;

	return PLUGIN_HANDLED;
}

public message_vguimenu(msg_id, msg_dest, msg_entity) {
	
	static menu_id; menu_id = get_msg_arg_int(1);

	if ( menu_id == 26 || menu_id == 27 ) {

		client_cmd(msg_entity, "joinclass 5");

		return PLUGIN_HANDLED;
	}

	if ( menu_id != 2 )
		return PLUGIN_CONTINUE;

	if ( !g_first[msg_entity] ) {

		g_first[msg_entity] = true;

		start_progress(msg_entity);

		if ( get_pcvar_bool(g_cv_auto_menu) )
			show_user_menu(msg_entity);

		return PLUGIN_HANDLED;
	}

	if ( g_status[msg_entity] >= ST_COMPLETED )
		return PLUGIN_CONTINUE;

	return PLUGIN_CONTINUE;
}

public show_user_menu(id) {

	if ( g_status[id] == ST_PENDING_REGISTER || g_status[id] == ST_PENDING_LOGIN )
		copy(g_message[id], 63, g_status[id] == ST_PENDING_REGISTER ? "UM_WAIT_REGISTRATION" : "UM_WAIT_LOGIN");

	user_menu(id);
}

public user_menu(id) {
	
	static text[512], len; len = 0;
	static none[32]; format(none, charsmax(none), "%L", id, "UM_NOT_SPECIFIED");
	static keys; keys = MENU_KEY_0;

	if ( g_page[id] == PG_MAIN ) {

		static team; team = get_user_team(id);

		len += formatex(text[len], charsmax(text) - len, "\y%L^n", id, "UM_TITLE");
		len += formatex(text[len], charsmax(text) - len, "^n");
		len += formatex(text[len], charsmax(text) - len, "\r1.\w %L^n", id, "UM_REGISTER_NEW_ACCOUNT");
		len += formatex(text[len], charsmax(text) - len, "\r2.\w %L^n", id, "UM_LOGIN_TO_ACCOUNT");
		len += formatex(text[len], charsmax(text) - len, "^n");
		
		if ( !team )
			len += formatex(text[len], charsmax(text) - len, "\r4.\y %L^n", id, "UM_PLAY_WITHOUT_LOGIN");
		else
			len += formatex(text[len], charsmax(text) - len, "\y%L^n", id, "UM_YOU_ARE_NOT_LOGGED_IN");

		keys = keys|MENU_KEY_1|MENU_KEY_2|MENU_KEY_4;
	}
	else if ( g_page[id] == PG_EDIT ) {

		if ( !g_completed[id] ) {

			len += formatex(text[len], charsmax(text) - len, "\y%L^n", id, "UM_TITLE_COMPLETE");
			len += formatex(text[len], charsmax(text) - len, "^n");
			len += formatex(text[len], charsmax(text) - len, "\r1.\w %L:\r %s^n", id, "UM_USERNAME", g_username[id][0] != EOS ? g_username[id] : none);
			len += formatex(text[len], charsmax(text) - len, "\r2.\w %L:\r %s^n", id, "UM_PASSWORD", g_password[id][0] != EOS ? g_password[id] : none);
			len += formatex(text[len], charsmax(text) - len, "^n");
			len += formatex(text[len], charsmax(text) - len, "\r4.\y %L^n", id, "UM_SAVE");

			keys = keys|MENU_KEY_1|MENU_KEY_2|MENU_KEY_4;
		}
		else {

			if ( !get_pcvar_bool(g_cv_password) && !get_pcvar_bool(g_cv_steam) ) {

				client_print_color(id, id, "%L %L", id, "UM_PREFIX", id, "UM_ALREADY_LOGGED_IN");

				return PLUGIN_HANDLED;
			}

			len += formatex(text[len], charsmax(text) - len, "\y%L^n", id, "UM_TITLE_EDIT");
			len += formatex(text[len], charsmax(text) - len, "^n");
			len += formatex(text[len], charsmax(text) - len, "\r1.%s %L^n", get_pcvar_bool(g_cv_password) ? "\w" : "\d", id, "UM_CHANGE_PASSWORD");
			len += formatex(text[len], charsmax(text) - len, "\r2.%s %L^n", is_user_steam(id) && get_pcvar_bool(g_cv_steam) ? "\w" : "\d", id, !g_steam[id] ? "UM_STEAM_UPDATE" : "UM_STEAM_DELETE");

			keys = keys|MENU_KEY_1|MENU_KEY_2;
		}
	}
	else if ( g_page[id] == PG_PASSWORD ) {

		len += formatex(text[len], charsmax(text) - len, "\y%L^n", id, "UM_CHANGE_PASSWORD");
		len += formatex(text[len], charsmax(text) - len, "^n");
		len += formatex(text[len], charsmax(text) - len, "\r1.\w %L:\r %s^n", id, "UM_NEW_PASSWORD", g_new_password[id][0] != EOS ? g_new_password[id] : none);
		len += formatex(text[len], charsmax(text) - len, "\r2.\w %L:\r %s^n", id, "UM_PASSWORD", g_password[id][0] != EOS ? g_password[id] : none);
		len += formatex(text[len], charsmax(text) - len, "^n");
		len += formatex(text[len], charsmax(text) - len, "\r4.\y %L^n", id, "UM_SAVE");

		keys = keys|MENU_KEY_1|MENU_KEY_2|MENU_KEY_4;
	}
	else {

		len += formatex(text[len], charsmax(text) - len, "\y%L^n", id, g_page[id] == PG_REGISTER ? "UM_TITLE_REGISTER" : "UM_TITLE_LOGIN");
		len += formatex(text[len], charsmax(text) - len, "^n");
		len += formatex(text[len], charsmax(text) - len, "\r1.\w %L:\r %s^n", id, "UM_USERNAME", g_username[id][0] != EOS ? g_username[id] : none);
		len += formatex(text[len], charsmax(text) - len, "\r2.\w %L:\r %s^n", id, "UM_PASSWORD", g_password[id][0] != EOS ? g_password[id] : none);
		len += formatex(text[len], charsmax(text) - len, "^n");
		len += formatex(text[len], charsmax(text) - len, "\r4.\y %L^n", id, g_page[id] == PG_REGISTER ? "UM_REGISTER" : "UM_LOGIN");
		
		keys = keys|MENU_KEY_1|MENU_KEY_2|MENU_KEY_4;
	}

	if ( (g_page[id] != PG_MAIN && g_page[id] != PG_EDIT) || (g_page[id] == PG_EDIT && !g_completed[id]) ) {

		if ( g_message[id][0] != EOS )
			len += formatex(text[len], charsmax(text) - len, "^n\w%L^n", id, g_message[id]);
		else
			len += formatex(text[len], charsmax(text) - len, "^n^n");
	}

	if ( g_page[id] == PG_MAIN ) {

		len += formatex(text[len], charsmax(text) - len, "^n");
		len += formatex(text[len], charsmax(text) - len, "\r8.\w %L^n", id, "UM_LANGUAGE");
		len += formatex(text[len], charsmax(text) - len, "^n");
		len += formatex(text[len], charsmax(text) - len, "\d%L^n", id, "UM_NOTICE");

		keys = keys|MENU_KEY_8;
	}

	len += formatex(text[len], charsmax(text) - len, "^n");
	len += formatex(text[len], charsmax(text) - len, "\r0.\w %L", id, "UM_EXIT");
	
	show_menu(id, keys, text, -1, "user_menu");
	
	return PLUGIN_HANDLED;
}

public menu_user(id, key_id) {
	
	if ( !is_user_connected(id) )
		return PLUGIN_HANDLED;

	g_message[id][0] = EOS;

	if ( g_page[id] == PG_MAIN ) {

		if ( !key_id || key_id == 1 )
			g_page[id] = key_id + 1;
		else if ( key_id == 3 )
			guest(id);
		else if ( key_id == 7 )
			next_language(id);
			
		if ( key_id != 9 )
			show_user_menu(id);
	}
	else if ( g_page[id] == PG_EDIT ) {

		if ( !g_completed[id] ) {

			if ( !key_id || key_id == 1 )
				client_cmd(id, "messagemode %s", !key_id ? "Username" : "Pass");
			else if ( key_id == 3 )
				remake(id);
		}
		else {

			if ( !key_id ) {

				if ( !get_pcvar_bool(g_cv_password) )
					client_print_color(id, id, "%L %L", id, "UM_PREFIX", id, "UM_PASSWORD_DISABLED");
				else
					g_page[id] = PG_PASSWORD;
			}
			else if ( key_id == 1 ) {

				if ( !get_pcvar_bool(g_cv_steam) )
					client_print_color(id, id, "%L %L", id, "UM_PREFIX", id, "UM_STEAM_DISABLED");
				else
					steam(id);
			}
		}

		if ( key_id != 9 )
			show_user_menu(id);
	}
	else if ( g_page[id] == PG_PASSWORD ) {

		if ( !key_id || key_id == 1)
			client_cmd(id, "messagemode %s", !key_id ? "NewPass" : "Pass");
		else if ( key_id == 3 )
			password(id);	

		if ( key_id == 9 )
			g_page[id] = PG_EDIT;

		show_user_menu(id);
	}
	else {

		if ( !key_id || key_id == 1 )
			client_cmd(id, "messagemode %s", !key_id ? "Username" : "Pass");
		else if ( key_id == 3 )
			create_or_login_user_if_true(id, g_page[id] == PG_REGISTER);
		else if ( key_id == 7 )
			next_language(id);
		else if ( key_id == 9 )
			g_page[id] = PG_MAIN;

		show_user_menu(id);
	}
	
	return PLUGIN_HANDLED;
}

public create_or_login_user_if_true(id, bool: create) {

	if ( g_status[id] == ST_COMPLETED )
		return;

	if ( g_status[id] == ST_PENDING_REGISTER || g_status[id] == ST_PENDING_LOGIN ) {

		show_user_menu(id);

		return;
	}

	if ( strlen(g_username[id]) < 4 )
		copy(g_message[id], 63, create ? "UM_MIN_USERNAME" : "UM_INVALID_USERNAME_OR_PWD");
	else if ( strlen(g_username[id]) > 32 )
		copy(g_message[id], 63, create ? "UM_MAX_USERNAME" : "UM_INVALID_USERNAME_OR_PWD");
	else if ( strlen(g_password[id]) < 4 )
		copy(g_message[id], 63, create ? "UM_MIN_PASSWORD" : "UM_INVALID_USERNAME_OR_PWD");
	else if ( strlen(g_password[id]) > 32 )
		copy(g_message[id], 63, create ? "UM_MAX_PASSWORD" : "UM_INVALID_USERNAME_OR_PWD");
	else {
	
		g_status[id] = create ? ST_PENDING_REGISTER : ST_PENDING_LOGIN;

		if ( !qm_is_preload_completed() )
			return;

		static username_fix[64];
		SQL_QuoteString(Empty_Handle, username_fix, charsmax(username_fix), g_username[id]);

		static password_fix[64];
		SQL_QuoteString(Empty_Handle, password_fix, charsmax(password_fix), g_password[id]);

		static name[32], name_fix[64];
		get_user_name(id, name, charsmax(name));
		SQL_QuoteString(Empty_Handle, name_fix, charsmax(name_fix), name);

		static steam_id[32], steam_id_fix[64];
		get_user_authid(id, steam_id, charsmax(steam_id));
		SQL_QuoteString(Empty_Handle, steam_id_fix, charsmax(steam_id_fix), steam_id);

		static ip_address[32], ip_address_fix[64];
		get_user_ip(id, ip_address, charsmax(ip_address), 1);
		SQL_QuoteString(Empty_Handle, ip_address_fix, charsmax(ip_address_fix), ip_address);

		if ( create ) {

			format(g_query, charsmax(g_query), "CALL `register_user` ('%s', '%s', '%s', '%s', '%s', '%i', '%s');", username_fix, password_fix, name_fix, steam_id_fix, ip_address_fix, is_user_steam(id), g_ip);
			qm_create_query(g_qm_register_user, g_query, id);
		}
		else {

			format(g_query, charsmax(g_query), "CALL `auth_user` ('%s', '%s', '%s', '%s', '%s', '%s');", username_fix, password_fix, name_fix, steam_id_fix, ip_address_fix, g_ip);
			qm_create_query(g_qm_auth_user, g_query, id);
		}
	}

	show_user_menu(id);
}

public remake(id) {

	if ( g_status[id] == ST_REMAKE ) {

		show_user_menu(id);

		return;
	}

	if ( strlen(g_username[id]) < 4 )
		copy(g_message[id], 63, "UM_MIN_USERNAME");
	else if ( strlen(g_username[id]) > 32 )
		copy(g_message[id], 63, "UM_MAX_USERNAME");
	else if ( strlen(g_password[id]) < 4 )
		copy(g_message[id], 63, "UM_MIN_PASSWORD");
	else if ( strlen(g_password[id]) > 32 )
		copy(g_message[id], 63, "UM_MAX_PASSWORD");
	else {

		static username_fix[64];
		SQL_QuoteString(Empty_Handle, username_fix, charsmax(username_fix), g_username[id]);

		static password_fix[64];
		SQL_QuoteString(Empty_Handle, password_fix, charsmax(password_fix), g_password[id]);

		format(g_query, charsmax(g_query), "CALL `remake_user` ('%i', '%s', '%s');", g_id[id], username_fix, password_fix);
		qm_create_query(g_qm_remake_user, g_query, id);

		copy(g_message[id], 63, "UM_WAIT_REGISTRATION");

		g_status[id] = ST_REMAKE;
	}

	show_user_menu(id);
}

public password(id) {

	if ( g_status[id] == ST_PASSWORD ) {

		show_user_menu(id);

		return;
	}

	if ( strlen(g_new_password[id]) < 4 )
		copy(g_message[id], 63, "UM_MIN_NEW_PASSWORD");
	else if ( strlen(g_new_password[id]) > 32 )
		copy(g_message[id], 63, "UM_MAX_NEW_PASSWORD");
	else {

		static password_fix[64];
		SQL_QuoteString(Empty_Handle, password_fix, charsmax(password_fix), g_password[id]);

		static new_password_fix[64];
		SQL_QuoteString(Empty_Handle, new_password_fix, charsmax(new_password_fix), g_new_password[id]);

		format(g_query, charsmax(g_query), "CALL `password` ('%i', '%s', '%s');", g_id[id], new_password_fix, password_fix);
		qm_create_query(g_qm_password, g_query, id);

		copy(g_message[id], 63, "UM_WAIT_PASSWORD");

		g_status[id] = ST_PASSWORD;
	}

	show_user_menu(id);
}

public steam(id) {

	if ( !is_user_steam(id) ) {

		client_print_color(id, id, "%L %L", id, "UM_PREFIX", id, "UM_STEAM_NONE");

		return;
	}

	if ( g_status[id] == ST_STEAM ) {

		show_user_menu(id);

		return;
	}

	static steam_id[32], steam_id_fix[64];
	get_user_authid(id, steam_id, charsmax(steam_id));
	SQL_QuoteString(Empty_Handle, steam_id_fix, charsmax(steam_id_fix), steam_id);

	format(g_query, charsmax(g_query), "CALL `steam` ('%i', '%s');", g_id[id], steam_id_fix);
	qm_create_query(g_qm_steam, g_query, id);

	copy(g_message[id], 63, "UM_WAIT_STEAM");

	g_status[id] = ST_STEAM;

	show_user_menu(id);
}

public next_language(id) {

	static lang[3];
	get_user_info(id, "lang", lang, charsmax(lang));
	set_user_info(id, "lang", equal(lang, "hu") ? "en" : "hu");

	client_print_color(id, id, "%L %L", id, "UM_PREFIX", id, "UM_LANGUAGE_CHANGED");
}

public fade_screen(id, bool: fade) {

	message_begin(MSG_ONE_UNRELIABLE, g_msg_screenfade, _, id);
	write_short(0);
	write_short(0);
	write_short(fade ? 4 : 1);
	write_byte(0);
	write_byte(0);
	write_byte(0);
	write_byte(fade ? 255 : 0);
	message_end();
}

public time_bar(id, time) {

	message_begin(MSG_ONE_UNRELIABLE, g_msg_bartime, _, id);
	write_byte(time);
	write_byte(0);
	message_end();
}

public guest(id) {

	if ( g_status[id] != ST_NONE )
		return;

	g_selected[id] = true;

	show_menu(id, 1023, "^n");
	fade_screen(id, false);
	time_bar(id, 0);
	remove_task(id);

	client_cmd(id, get_pcvar_bool(g_cv_auto_join) ? "jointeam 5" : "chooseteam");

	static name[64];
	get_user_name(id, name, charsmax(name));

	client_print_color(id, id, "%L %L", id, "UM_PREFIX", id, "UM_HI_GUEST", name);

	static result;
	ExecuteForward(g_forward_guest, result, id);
}

public start_progress(id) {

	if ( g_status[id] >= ST_COMPLETED )
		return;

	if ( get_pcvar_bool(g_cv_black_screen) )
		fade_screen(id, true);

	g_second[id] = 0;

	static auto_gest; auto_gest = get_pcvar_num(g_cv_auto_guest);

	if ( !auto_gest )
		return;

	set_task_ex(1.0, "task_dhud", id, _, _, SetTask_Repeat);
}

public task_dhud(id) {

	if ( !is_user_connected(id) || is_user_bot(id) )
		return;

	if ( g_status[id] >= ST_COMPLETED )
		return;

	static auto_gest; auto_gest = get_pcvar_num(g_cv_auto_guest);
	static left; left = auto_gest - g_second[id];

	static name[32];
	get_user_name(id, name, charsmax(name));

	set_dhudmessage(200, 100, 0, -1.0, -1.0, 0, 0.0, 1.0, 0.1, 0.0);
	show_dhudmessage(id, "%L", id, "UM_DHUD", name, left);

	if ( !g_second[id] )
		time_bar(id, left);

	if ( g_second[id] != auto_gest )
		g_second[id] ++;
	else
		guest(id);
}

public fw_Query_Completed(query_data[QUERY_DATA]) {

	new id = query_data[QD_USER_ID];

	if ( !id || get_user_userid(id) != query_data[QD_USER_USERID] )
		return;

	if ( query_data[QD_TYPE_ID] == g_qm_register_user || query_data[QD_TYPE_ID] == g_qm_auth_user || query_data[QD_TYPE_ID] == g_qm_putinserver ) {

		if ( g_status[id] >= ST_COMPLETED )
			return;

		if ( SQL_NumRows(query_data[QD_MYSQL]) ) {

			if ( query_data[QD_TYPE_ID] == g_qm_register_user )
				client_print_color(id, id, "%L %L", id, "UM_PREFIX", id, "UM_REGISTERED", g_username[id], g_password[id]);

			if ( query_data[QD_TYPE_ID] == g_qm_putinserver )
				g_steam[id] = true;

			g_status[id] = ST_COMPLETED;
			g_username[id][0] = EOS;
			g_password[id][0] = EOS;
			g_message[id][0] = EOS;
			g_id[id] = SQL_ReadResult(query_data[QD_MYSQL], SQL_FieldNameToNum(query_data[QD_MYSQL], "id"));
			g_completed[id] = SQL_ReadResult(query_data[QD_MYSQL], SQL_FieldNameToNum(query_data[QD_MYSQL], "completed")) ? true : false;

			client_cmd(id, "setinfo ^"%s^" ^"%s^"", "hk_username", g_username[id]);

			set_user_info(id, "hk_username", g_username[id]);

			complete_user_requirement(id);

			static result;
			ExecuteForward(g_forward_next, result, id);
		}
		else {

			g_status[id] = ST_NONE;

			if ( query_data[QD_TYPE_ID] != g_qm_putinserver )
				copy(g_message[id], 63, query_data[QD_TYPE_ID] == g_qm_register_user ? "UM_ALREADY_IN_USE" : "UM_INVALID_USERNAME_OR_PWD");

			show_user_menu(id);
		}
	}
	else if ( query_data[QD_TYPE_ID] == g_qm_password ) {

		if ( SQL_NumRows(query_data[QD_MYSQL]) ) {

			client_print_color(id, id, "%L %L", id, "UM_PREFIX", id, "UM_PASSWORD_CHANGED", g_new_password[id]);

			g_password[id][0] = EOS;
			g_new_password[id][0] = EOS;

			show_menu(id, 1023, "^n");
		}
		else {

			copy(g_message[id], 63, "UM_INVALID_PASSWORD");

			show_user_menu(id);
		}

		g_message[id][0] = EOS;
		g_status[id] = ST_COMPLETED;
	}
	else if ( query_data[QD_TYPE_ID] == g_qm_remake_user ) {

		if ( SQL_NumRows(query_data[QD_MYSQL]) ) {

			client_print_color(id, id, "%L %L", id, "UM_PREFIX", id, "UM_REGISTERED", g_username[id], g_password[id]);

			client_cmd(id, "setinfo ^"%s^" ^"%s^"", "hk_username", g_username[id]);

			set_user_info(id, "hk_username", g_username[id]);

			g_username[id][0] = EOS;
			g_password[id][0] = EOS;
			g_completed[id] = true;

			show_menu(id, 1023, "^n");
		}
		else {

			copy(g_message[id], 63, "UM_ALREADY_IN_USE");

			show_user_menu(id);
		}

		g_message[id][0] = EOS;
		g_status[id] = ST_COMPLETED;
	}
	else if ( query_data[QD_TYPE_ID] == g_qm_steam ) {

		if ( SQL_NumRows(query_data[QD_MYSQL]) ) {

			g_password[id][0] = EOS;
			g_steam[id] = !SQL_ReadResult(query_data[QD_MYSQL], SQL_FieldNameToNum(query_data[QD_MYSQL], "deleted"));

			client_print_color(id, id, "%L %L", id, "UM_PREFIX", id, g_steam[id] ? "UM_STEAM_UPDATED" : "UM_STEAM_DELETED");

			show_menu(id, 1023, "^n");
		}

		g_message[id][0] = EOS;
		g_status[id] = ST_COMPLETED;
	}
}