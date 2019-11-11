-- Version 1573410822 - UP
CREATE TABLE IF NOT EXISTS `admin_options`
(
    `id`           int(11) unsigned NOT NULL AUTO_INCREMENT,
    `option_value` text             NOT NULL,
    PRIMARY KEY (`id`)
) ENGINE = InnoDB
  DEFAULT CHARSET = utf8;
