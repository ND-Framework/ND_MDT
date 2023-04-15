CREATE TABLE `nd_mdt_bolos` (
	`id` INT(11) AUTO_INCREMENT,
	`type` VARCHAR(50) DEFAULT NULL,
	`data` LONGTEXT DEFAULT '[]',
	`timestamp` INT(11) DEFAULT unix_timestamp(),
	PRIMARY KEY (`id`) USING BTREE
);

CREATE TABLE `nd_mdt_records` (
	`character` INT(11) DEFAULT NULL,
	`records` LONGTEXT DEFAULT '[]',
	INDEX `character` (`character`) USING BTREE,
	CONSTRAINT `FK_nd_mdt_characters` FOREIGN KEY (`character`) REFERENCES `characters` (`character_id`) ON UPDATE CASCADE ON DELETE CASCADE
);

CREATE TABLE `nd_mdt_reports` (
	`id` INT(11) NOT NULL AUTO_INCREMENT,
	`type` VARCHAR(50) DEFAULT NULL,
	`data` LONGTEXT DEFAULT '[]',
	`timestamp` INT(11) DEFAULT unix_timestamp(),
	PRIMARY KEY (`id`) USING BTREE
);

CREATE TABLE `nd_mdt_weapons` (
	`character` INT(11) DEFAULT NULL,
	`weapon` VARCHAR(50) DEFAULT NULL,
	`serial` VARCHAR(50) DEFAULT NULL,
	`owner_name` VARCHAR(100) DEFAULT NULL,
	`stolen` INT(1) DEFAULT '0',
	INDEX `FK_nd_mdt_weapons_characters` (`character`) USING BTREE,
	CONSTRAINT `FK_nd_mdt_weapons_characters` FOREIGN KEY (`character`) REFERENCES `characters` (`character_id`) ON UPDATE CASCADE ON DELETE CASCADE
);