CREATE TABLE `nd_mdt_records` (
	`character` INT(11) DEFAULT NULL,
	`records` LONGTEXT DEFAULT '[]',
	INDEX `character` (`character`) USING BTREE,
	CONSTRAINT `FK_nd_mdt_characters` FOREIGN KEY (`character`) REFERENCES `characters` (`character_id`) ON UPDATE CASCADE ON DELETE CASCADE
);
