#if defined _user_manager_included
	#endinput
#endif
#define user_manager_included

/**
 * Returns a player's accountID.
 *
 * Note: This ID will be set after login and generated after registration.
 *
 * @param id			Player ID.
 *
 * @return				AccountID.
 */
native um_get_user_id(id);

/**
 * Registers a player requirement.
 */
native um_register_user_requirement();

/**
 * Complete a player requirement.
 */
native um_complete_user_requirement(id);

/**
 * Returns if a player's all requirements are completed.
 *
 * Note: If registered user requirement count equal with completed user requirement.
 *
 * @param id			Player ID.
 *
 * @return				True if completed, false otherwise.
 */
native um_is_user_requirements_completed(id);

/**
 * Called when a player's all requirements are completed.
 *
 * @param id			Player ID.
 */
forward fw_User_Manager_Next(id);

/**
 * Called when an account authorized player left.
 *
 * Note: Can be used to save before disconnect. (Called before account ID is reseted.)
 *
 * @param id			Player ID.
 */
forward fw_User_Manager_Leave(id);

/**
 * Called when guest appeared.
 *
 * @param id			Player ID.
 */
forward fw_User_Manager_Guest(id);