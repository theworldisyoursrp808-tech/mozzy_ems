CREATE TABLE IF NOT EXISTS `mozzy_ems_profiles` (
    `citizenid` VARCHAR(50) NOT NULL,
    `xp` INT(11) NOT NULL DEFAULT 0,
    `total_calls` INT(11) NOT NULL DEFAULT 0,
    `successful_calls` INT(11) NOT NULL DEFAULT 0,
    `failed_calls` INT(11) NOT NULL DEFAULT 0,
    `patients_saved` INT(11) NOT NULL DEFAULT 0,
    `patients_lost` INT(11) NOT NULL DEFAULT 0,
    PRIMARY KEY (`citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `mozzy_ems_call_history` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `call_type` VARCHAR(50) NOT NULL,
    `priority` TINYINT(2) NOT NULL,
    `medic_citizenid` VARCHAR(50) DEFAULT NULL,
    `medic_name` VARCHAR(100) DEFAULT NULL,
    `outcome` VARCHAR(30) NOT NULL,
    `response_time` INT(11) DEFAULT NULL,
    `treatments_correct` INT(11) DEFAULT 0,
    `treatments_incorrect` INT(11) DEFAULT 0,
    `transported` TINYINT(1) DEFAULT 0,
    `payment` INT(11) DEFAULT 0,
    `created_at` DATETIME NOT NULL,
    PRIMARY KEY (`id`),
    KEY `medic_citizenid` (`medic_citizenid`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

CREATE TABLE IF NOT EXISTS `mozzy_ems_stats` (
    `citizenid` VARCHAR(50) NOT NULL,
    `call_type` VARCHAR(50) NOT NULL,
    `times_completed` INT(11) NOT NULL DEFAULT 0,
    PRIMARY KEY (`citizenid`, `call_type`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
