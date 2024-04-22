CREATE TABLE IF NOT EXISTS `nd_mdt_records` (
	`character` INT(11) DEFAULT NULL,
	`records` LONGTEXT DEFAULT '[]',
	INDEX `character` (`character`) USING BTREE,
	CONSTRAINT `FK_nd_mdt_characters` FOREIGN KEY (`character`) REFERENCES `nd_characters` (`charid`) ON UPDATE CASCADE ON DELETE CASCADE
);
