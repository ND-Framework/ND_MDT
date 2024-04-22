CREATE TABLE IF NOT EXISTS `nd_mdt_weapons` (
	`character` VARCHAR(60) DEFAULT NULL,
	`weapon` VARCHAR(50) DEFAULT NULL,
	`serial` VARCHAR(50) DEFAULT NULL,
	`owner_name` VARCHAR(100) DEFAULT NULL,
	`stolen` INT(1) DEFAULT '0',
	INDEX `FK_nd_mdt_weapons_characters` (`character`) USING BTREE,
	CONSTRAINT `FK_nd_mdt_weapons_characters` FOREIGN KEY (`character`) REFERENCES `nd_characters` (`charid`) ON UPDATE CASCADE ON DELETE CASCADE
);
