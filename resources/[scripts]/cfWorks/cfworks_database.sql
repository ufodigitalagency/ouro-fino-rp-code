-- =====================================================
-- SQL para criar tabela do cfWorks (Central de Empregos)
-- Execute este SQL no banco de dados 'vrp' antes de
-- iniciar o servidor pela primeira vez com cfWorks
-- =====================================================

CREATE TABLE IF NOT EXISTS `cfworks` (
    `id` INT(11) NOT NULL AUTO_INCREMENT,
    `user_id` INT(11) NOT NULL,
    `job_id` VARCHAR(50) NOT NULL,
    `xp` INT(11) NOT NULL DEFAULT 0,
    `level` INT(11) NOT NULL DEFAULT 1,
    `earned` INT(11) NOT NULL DEFAULT 0,
    PRIMARY KEY (`id`),
    UNIQUE KEY `user_job` (`user_id`, `job_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
