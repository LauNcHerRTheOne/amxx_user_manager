#include <amxmodx>
#include <amxmisc>
#include <user_manager>

new g_cv_file;

public plugin_init() {

	register_plugin("Auto Demo Recoder", "1.0.0", "JohanCorn");

	g_cv_file = register_cvar("amx_adr_file", "your_file_name.dem");

	register_dictionary("auto_demo_recorder.txt");
}

public plugin_cfg() {

	AutoExecConfig();
}

public fw_User_Manager_Guest(id) {

	demo(id)
}

public fw_User_Manager_Next(id) {

	demo(id)
}

public demo(id) {

	if ( is_user_bot(id) || is_user_hltv(id) )
		return;

	static file[32]; get_pcvar_string(g_cv_file, file, charsmax(file));

	client_cmd(id, "stop; record ^"%s^"", file);

	client_print_color(id, id, "%L %L", id, "ADR_PREFIX", id, "ADR_STARTED", file);
}