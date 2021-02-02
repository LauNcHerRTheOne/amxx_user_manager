SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
SET time_zone = "+00:00";

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;


DELIMITER $$
CREATE PROCEDURE `auth_user` (IN `p_username` VARCHAR(32), IN `p_password` VARCHAR(32), IN `p_name` VARCHAR(32), IN `p_steam_id` VARCHAR(32), IN `p_ip_address` VARCHAR(32))  NO SQL
BEGIN

SET @USER_ID = (SELECT `id` FROM `um_users` WHERE `username` LIKE
p_username AND `password` LIKE MD5(CONCAT(p_password, `password_salt`)) LIMIT 1);
            
IF ( @USER_ID IS NOT NULL ) THEN
            
	CALL `login_user` (@USER_ID, p_name, p_steam_id, p_ip_address);
            
END IF;
            
END$$

CREATE PROCEDURE `login_user` (IN `p_id` INT, IN `p_name` VARCHAR(32), IN `p_steam_id` VARCHAR(32), IN `p_ip_address` VARCHAR(32))  NO SQL
BEGIN

SELECT `id`, `last_used_at`, IF(`username` IS NULL, FALSE, TRUE) AS `completed` FROM `um_users` WHERE `id` = p_id LIMIT 1;

UPDATE `um_users` SET `last_used_name` = p_name, `last_used_steam_id` = p_steam_id, `last_used_ip_address` = p_ip_address WHERE `id` = p_id;

INSERT INTO `um_logins` (`user_id`, `name`, `steam_id`, `ip_address`) VALUES (p_id, p_name, p_steam_id, p_ip_address);

END$$

CREATE PROCEDURE `password` (IN `p_id` INT, IN `p_new_password` VARCHAR(32), IN `p_password` VARCHAR(32))  NO SQL
BEGIN

SET @MD5 = (SELECT `password` FROM `um_users` WHERE `id` = p_id LIMIT 1);

SET @SALT = (SELECT `password_salt` FROM `um_users` WHERE `id` = p_id LIMIT 1);

IF ((@MD5 LIKE MD5(CONCAT(p_password, @SALT))) OR (p_password IS NULL)) THEN

	UPDATE `um_users` SET `password` = MD5(CONCAT(p_new_password, `password_salt`)) WHERE `id` = p_id;
    
    INSERT INTO `um_passwords` (`user_id`) VALUES (p_id);
    
    SELECT p_id AS `id`;
    
END IF;

END$$

CREATE PROCEDURE `putinserver` (IN `p_username` VARCHAR(32), IN `p_name` VARCHAR(32), IN `p_steam_id` VARCHAR(32), IN `p_ip_address` VARCHAR(32))  NO SQL
BEGIN

SET @USER_ID = (SELECT `user_id` FROM `um_auto` WHERE `steam_id` LIKE p_steam_id LIMIT 1);

IF (@USER_ID IS NOT NULL) THEN
    
    CALL `login_user` (@USER_ID, p_name, p_steam_id, p_ip_address);

ELSE 
    
   	SET @USER_ID = (SELECT `id` FROM `um_users` WHERE `first_used_steam_id` LIKE p_steam_id LIMIT 1);
        
    IF (@USER_ID IS NULL) THEN
        
        CALL `register_user` (NULL, NULL, p_name, p_steam_id, p_ip_address, TRUE);
        
    END IF;

END IF;

END$$

CREATE PROCEDURE `register_user` (IN `p_username` VARCHAR(32), IN `p_password` VARCHAR(32), IN `p_name` VARCHAR(32), IN `p_steam_id` VARCHAR(32), IN `p_ip_address` VARCHAR(32), IN `p_auto` BOOLEAN)  NO SQL
BEGIN

SET @USER_ID = (SELECT `id` FROM `um_users` WHERE `username` LIKE p_username LIMIT 1);

IF (@USER_ID IS NULL) THEN
    
    SET @SALT = LEFT(UUID(), 8);

    INSERT IGNORE INTO `um_users` (`username`, `password`, `password_salt`, `first_used_steam_id`, `first_used_ip_address`, `last_used_name`, `last_used_steam_id`, `last_used_ip_address`) VALUES (p_username, IF(p_password IS NOT NULL, MD5(CONCAT(p_password, @SALT)), NULL), @SALT, p_steam_id, p_ip_address, p_name, p_steam_id, p_ip_address);
    
    SET @USER_ID = LAST_INSERT_ID();
    
    IF ( p_auto ) THEN
    
    	INSERT IGNORE INTO `um_auto` (`steam_id`, `user_id`) VALUES (p_steam_id, @USER_ID);
        
    END IF;
    
    CALL `login_user` (@USER_ID, p_name, p_steam_id, p_ip_address);

END IF;

END$$

CREATE PROCEDURE `remake_user` (IN `p_id` INT, IN `p_username` VARCHAR(32), IN `p_password` VARCHAR(32))  NO SQL
BEGIN

SET @USER_ID = (SELECT `id` FROM `um_users` WHERE `username` LIKE p_username LIMIT 1);

IF ( @USER_ID IS NULL ) THEN 

	UPDATE `um_users` SET `username` = p_username WHERE `id` = p_id;
    
    CALL `password` (p_id, p_password, NULL);
    
END IF;

END$$

CREATE PROCEDURE `steam` (IN `p_id` INT, IN `p_steam_id` VARCHAR(32))  NO SQL
BEGIN

SET @STEAM_ID = (SELECT `steam_id` FROM `um_auto` WHERE `steam_id` LIKE p_steam_id LIMIT 1);

SET @USER_ID = (SELECT `user_id` FROM `um_auto` WHERE `user_id` = p_id LIMIT 1);
  
IF ((@STEAM_ID IS NOT NULL) AND (@USER_ID = p_id)) THEN
                 
   	DELETE FROM `um_auto` WHERE `steam_id` LIKE p_steam_id;
    
    SELECT TRUE AS `deleted`;
                 
ELSE 
       
    INSERT INTO `um_auto` (`steam_id`, `user_id`) VALUES (p_steam_id, p_id) ON DUPLICATE KEY UPDATE `user_id` = p_id;
    
    SELECT FALSE AS `deleted`;
                 
END IF;

END$$

DELIMITER ;

CREATE TABLE `um_auto` (
  `steam_id` varchar(32) NOT NULL,
  `user_id` int(11) NOT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `um_logins` (
  `id` int(11) NOT NULL,
  `user_id` int(11) DEFAULT NULL,
  `name` varchar(32) NOT NULL,
  `steam_id` varchar(32) NOT NULL,
  `ip_address` varchar(32) NOT NULL,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `um_passwords` (
  `id` int(11) NOT NULL,
  `user_id` int(11) NOT NULL,
  `create_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE `um_users` (
  `id` int(11) NOT NULL,
  `username` varchar(32) DEFAULT NULL,
  `password` varchar(32) DEFAULT NULL,
  `password_salt` varchar(8) NOT NULL,
  `first_used_steam_id` varchar(32) NOT NULL,
  `first_used_ip_address` varchar(32) NOT NULL,
  `last_used_name` varchar(32) NOT NULL,
  `last_used_steam_id` varchar(32) NOT NULL,
  `last_used_ip_address` varchar(32) NOT NULL,
  `last_used_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
  `created_at` datetime NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;


ALTER TABLE `um_auto`
  ADD PRIMARY KEY (`steam_id`);

ALTER TABLE `um_logins`
  ADD PRIMARY KEY (`id`),
  ADD KEY `user_id` (`user_id`);

ALTER TABLE `um_passwords`
  ADD PRIMARY KEY (`id`),
  ADD KEY `user_id` (`user_id`);

ALTER TABLE `um_users`
  ADD PRIMARY KEY (`id`);


ALTER TABLE `um_logins`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;
ALTER TABLE `um_passwords`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;
ALTER TABLE `um_users`
  MODIFY `id` int(11) NOT NULL AUTO_INCREMENT;

ALTER TABLE `um_logins`
  ADD CONSTRAINT `um_logins_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `um_users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE `um_passwords`
  ADD CONSTRAINT `um_passwords_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `um_users` (`id`) ON DELETE CASCADE ON UPDATE CASCADE;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
