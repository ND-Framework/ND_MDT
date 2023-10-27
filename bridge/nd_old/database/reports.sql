CREATE TABLE IF NOT EXISTS `nd_mdt_reports` (
	`id` INT(11) NOT NULL AUTO_INCREMENT,
	`type` VARCHAR(50) DEFAULT NULL,
	`data` LONGTEXT DEFAULT '[]',
	`timestamp` INT(11) DEFAULT unix_timestamp(),
	PRIMARY KEY (`id`) USING BTREE
);
