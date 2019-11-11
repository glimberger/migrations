-- Version 1573409523 - UP
CREATE TABLE IF NOT EXISTS `admin_phone`
(
    `person_id` int(11) unsigned NOT NULL,
    `phone`     varchar(32)      NOT NULL,
    PRIMARY KEY (`person_id`),
    UNIQUE KEY `phone` (`phone`)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8;
