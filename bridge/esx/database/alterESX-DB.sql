ALTER TABLE `users`
    ADD COLUMN `phonnumber` VARCHAR(15) NULL DEFAULT NULL,
    ADD COLUMN `image` LONGTEXT NULL DEFAULT NULL;

ALTER TABLE `user_licenses`
	ADD COLUMN `status` VARCHAR(10) NOT NULL DEFAULT 'valid' AFTER `owner`,
	ADD COLUMN `issued` TIMESTAMP NOT NULL DEFAULT current_timestamp() AFTER `type`,
	ADD COLUMN `identifier` VARCHAR(50) NOT NULL DEFAULT UUID_SHORT() AFTER `issued`,
	ADD UNIQUE INDEX `identifier` (`identifier`);

ALTER TABLE `users`
    ADD COLUMN `stolen` INT(11) DEFAULT '0';