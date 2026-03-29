-- phpMyAdmin SQL Dump
-- version 5.2.1
-- https://www.phpmyadmin.net/
--
-- Hôte : 127.0.0.1
-- Généré le : dim. 29 mars 2026 à 09:44
-- Version du serveur : 10.4.32-MariaDB
-- Version de PHP : 8.0.30

SET SQL_MODE = "NO_AUTO_VALUE_ON_ZERO";
START TRANSACTION;
SET time_zone = "+00:00";


/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!40101 SET NAMES utf8mb4 */;

--
-- Base de données : `tsunami_ready`
--

DELIMITER $$
--
-- Procédures
--
CREATE DEFINER=`root`@`localhost` PROCEDURE `calculate_risk_level` (IN `p_magnitude` DECIMAL(4,2))   BEGIN
    -- Validation
    IF p_magnitude < 0 OR p_magnitude > 10 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Magnitude invalide (doit être entre 0 et 10).';
    END IF;

    IF p_magnitude < 2.0 THEN
        SELECT
            'NÉGLIGEABLE'                                        AS risk_level,
            'Micro-séisme imperceptible, détectable seulement par instruments.' AS description,
            'Surveillance automatique standard. Aucune action humaine requise.'  AS recommended_action,
            '#6B7280'                                            AS color_code;

    ELSEIF p_magnitude < 3.5 THEN
        SELECT
            'TRÈS FAIBLE'                                        AS risk_level,
            'Légère vibration. Perceptible par certaines personnes au repos.'    AS description,
            'Notification équipe de veille. Vérification capteurs.'              AS recommended_action,
            '#10B981'                                            AS color_code;

    ELSEIF p_magnitude < 5.0 THEN
        SELECT
            'MODÉRÉ'                                             AS risk_level,
            'Secousse notable. Objets peuvent tomber. Dommages mineurs possibles.' AS description,
            'Alerte préventive équipes terrain. Inspection structures vulnérables.' AS recommended_action,
            '#F59E0B'                                            AS color_code;

    ELSEIF p_magnitude < 6.5 THEN
        SELECT
            'ÉLEVÉ'                                              AS risk_level,
            'Dommages significatifs dans un rayon de 50 km. Structures à risque.' AS description,
            'Activation protocole urgence. Mobilisation Protection Civile. Pré-alerte tsunami.' AS recommended_action,
            '#F97316'                                            AS color_code;

    ELSEIF p_magnitude < 7.5 THEN
        SELECT
            'CRITIQUE'                                           AS risk_level,
            'Séisme destructeur. Risque tsunami élevé pour les zones côtières d''Agadir.' AS description,
            'ÉVACUATION IMMÉDIATE zones côtières. Activation sirènes. Cellule de crise nationale.' AS recommended_action,
            '#EF4444'                                            AS color_code;

    ELSE
        SELECT
            'CATASTROPHIQUE'                                     AS risk_level,
            'Séisme majeur. Tsunami quasi-certain. Destruction massive possible.' AS description,
            'ÉVACUATION TOTALE. ALERTE MAXIMALE. Coordination internationale PTWC.' AS recommended_action,
            '#7C3AED'                                            AS color_code;
    END IF;

END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `evaluate_tsunami_risk` (IN `p_event_id` INT)   BEGIN
    DECLARE v_magnitude   DECIMAL(4,2);
    DECLARE v_depth_km    DECIMAL(6,2);
    DECLARE v_lat         DECIMAL(9,6);
    DECLARE v_lon         DECIMAL(9,6);
    DECLARE v_score       DECIMAL(6,2) DEFAULT 0;
    DECLARE v_dist_coast  DECIMAL(10,4);
    DECLARE v_wave_time   INT;
    DECLARE v_category    VARCHAR(20);
    DECLARE v_message     TEXT;
    DECLARE v_should      TINYINT(1);

    -- Coordonnées côte Agadir (approximation)
    DECLARE AGADIR_LAT DECIMAL(9,6) DEFAULT 30.420000;
    DECLARE AGADIR_LON DECIMAL(9,6) DEFAULT -9.600000;

    -- Récupération événement
    SELECT magnitude, depth_km, latitude, longitude
    INTO   v_magnitude, v_depth_km, v_lat, v_lon
    FROM   seismic_events
    WHERE  event_id = p_event_id;

    IF v_magnitude IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Événement sismique introuvable.';
    END IF;

    -- ── FACTEUR 1 : Magnitude (0–50 pts) ─────────────────
    SET v_score = v_score + LEAST(50, POW(v_magnitude / 10.0, 1.5) * 50);

    -- ── FACTEUR 2 : Profondeur (0–30 pts) ────────────────
    IF v_depth_km IS NULL OR v_depth_km < 30 THEN
        SET v_score = v_score + 30;
    ELSEIF v_depth_km < 70 THEN
        SET v_score = v_score + 20;
    ELSEIF v_depth_km < 150 THEN
        SET v_score = v_score + 10;
    ELSE
        SET v_score = v_score + 5;
    END IF;

    -- ── FACTEUR 3 : Distance côte (0–20 pts) ─────────────
    -- Distance approx. en km (1° ≈ 111 km)
    SET v_dist_coast = SQRT(
        POW((v_lat - AGADIR_LAT) * 111, 2) +
        POW((v_lon - AGADIR_LON) * 111 * COS(RADIANS(v_lat)), 2)
    );

    IF v_dist_coast < 50 THEN
        SET v_score = v_score + 20;
    ELSEIF v_dist_coast < 150 THEN
        SET v_score = v_score + 12;
    ELSEIF v_dist_coast < 300 THEN
        SET v_score = v_score + 6;
    END IF;

    -- ── Temps d'arrivée estimé (700 km/h en haute mer) ───
    SET v_wave_time = GREATEST(5, ROUND(v_dist_coast / (700.0 / 60.0)));

    -- ── Décision et message ───────────────────────────────
    IF v_score >= 70 THEN
        SET v_category = 'CATASTROPHIQUE';
        SET v_should   = 1;
        SET v_message  = CONCAT(
            '🚨 TSUNAMI IMMINENT — Score: ', ROUND(v_score,1),
            '/100 | M', v_magnitude,
            ' prof. ', IFNULL(v_depth_km, 0), ' km | ',
            'Vague estimée dans ~', v_wave_time, ' min | ÉVACUATION TOTALE.'
        );
    ELSEIF v_score >= 50 THEN
        SET v_category = 'CRITIQUE';
        SET v_should   = 1;
        SET v_message  = CONCAT(
            '⚠️ RISQUE TSUNAMI ÉLEVÉ — Score: ', ROUND(v_score,1),
            '/100 | M', v_magnitude,
            ' | Évacuation côtière dans les ', v_wave_time, ' min.'
        );
    ELSEIF v_score >= 30 THEN
        SET v_category = 'SURVEILLANCE';
        SET v_should   = 0;
        SET v_message  = CONCAT(
            '🔶 Risque modéré — Score: ', ROUND(v_score,1),
            '/100 | M', v_magnitude,
            ' | Surveillance renforcée. Équipes en standby.'
        );
    ELSE
        SET v_category = 'FAIBLE';
        SET v_should   = 0;
        SET v_message  = CONCAT(
            'ℹ️ Risque faible — Score: ', ROUND(v_score,1),
            '/100 | M', v_magnitude,
            ' | Surveillance standard maintenue.'
        );
    END IF;

    IF v_magnitude >= 6.5 THEN
        SET v_should = 1;
    END IF;

    -- ── Résultat ──────────────────────────────────────────
    SELECT
        v_should          AS should_trigger_alert,
        ROUND(v_score, 2) AS risk_score,
        v_category        AS risk_category,
        v_message         AS alert_message,
        ROUND(v_dist_coast, 1) AS distance_coast_km,
        v_wave_time       AS estimated_wave_time_min;

END$$

CREATE DEFINER=`root`@`localhost` PROCEDURE `get_seismic_report` (IN `p_days` INT)   BEGIN
    SELECT
        CONCAT('Derniers ', p_days, ' jours')     AS period_label,
        COUNT(DISTINCT e.event_id)                AS total_events,
        ROUND(AVG(e.magnitude), 2)                AS avg_magnitude,
        MAX(e.magnitude)                          AS max_magnitude,
        COUNT(DISTINCT a.alert_id)                AS total_alerts,
        SUM(CASE WHEN a.alert_level = 'CRITICAL' THEN 1 ELSE 0 END) AS critical_alerts,
        (
            SELECT s.name
            FROM seismic_sensors s
            JOIN seismic_events ev ON ev.sensor_id = s.sensor_id
            WHERE ev.event_time >= DATE_SUB(NOW(), INTERVAL p_days DAY)
            GROUP BY s.name
            ORDER BY COUNT(*) DESC
            LIMIT 1
        )                                          AS most_active_sensor
    FROM seismic_events e
    LEFT JOIN alerts a ON a.event_id = e.event_id
    WHERE e.event_time >= DATE_SUB(NOW(), INTERVAL p_days DAY);
END$$

DELIMITER ;

-- --------------------------------------------------------

--
-- Structure de la table `alerts`
--

CREATE TABLE `alerts` (
  `alert_id` int(11) NOT NULL,
  `event_id` int(11) NOT NULL,
  `alert_level` enum('LOW','MEDIUM','HIGH','CRITICAL') NOT NULL,
  `alert_type` varchar(50) NOT NULL,
  `message` text NOT NULL,
  `triggered_at` datetime NOT NULL DEFAULT current_timestamp(),
  `status` enum('ACTIVE','ACKNOWLEDGED','RESOLVED') NOT NULL DEFAULT 'ACTIVE',
  `acknowledged_by` int(11) DEFAULT NULL,
  `acknowledged_at` datetime DEFAULT NULL,
  `resolved_at` datetime DEFAULT NULL,
  `sirens_activated` tinyint(1) NOT NULL DEFAULT 0,
  `evacuation_triggered` tinyint(1) NOT NULL DEFAULT 0
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Déchargement des données de la table `alerts`
--

INSERT INTO `alerts` (`alert_id`, `event_id`, `alert_level`, `alert_type`, `message`, `triggered_at`, `status`, `acknowledged_by`, `acknowledged_at`, `resolved_at`, `sirens_activated`, `evacuation_triggered`) VALUES
(1, 6, 'MEDIUM', 'SEISMIC', '⚠️ ALERTE MOYENNE — Séisme M6.50 enregistré par capteur #5. Surveillance tsunami activée. Équipes terrain en alerte.', '2026-03-25 22:33:04', 'RESOLVED', NULL, NULL, '2026-02-28 09:00:00', 0, 0),
(2, 7, 'HIGH', 'TSUNAMI', '⚠️ ALERTE HAUTE — Séisme M7.20. RISQUE TSUNAMI PROBABLE. Zones côtières : Marina, Port, Taghazout. Sirènes activées. Évacuation immédiate.', '2026-03-25 22:33:04', 'ACKNOWLEDGED', 2, '2026-03-10 11:50:00', NULL, 1, 1),
(3, 8, 'CRITICAL', 'TSUNAMI', '🚨 ALERTE MAXIMALE — Séisme M8.30 prof. 5.00 km. RISQUE TSUNAMI CERTAIN. Évacuation totale zones côtières. Sirènes activées. Coordination nationale.', '2026-03-25 22:33:04', 'ACTIVE', NULL, NULL, NULL, 1, 1),
(4, 11, 'MEDIUM', 'SEISMIC', '⚠️ ALERTE MOYENNE — Séisme M6.50 enregistré par capteur #5. Surveillance tsunami activée. Équipes terrain en alerte.', '2026-03-26 13:08:09', 'ACTIVE', NULL, NULL, NULL, 0, 0),
(5, 12, 'HIGH', 'TSUNAMI', '⚠️ ALERTE HAUTE — Séisme M7.20. RISQUE TSUNAMI PROBABLE. Zones côtières : Marina, Port, Taghazout. Sirènes activées. Évacuation immédiate.', '2026-03-26 13:08:09', 'ACTIVE', NULL, NULL, NULL, 1, 1),
(6, 13, 'CRITICAL', 'TSUNAMI', '🚨 ALERTE MAXIMALE — Séisme M8.30 prof. 5.00 km. RISQUE TSUNAMI CERTAIN. Évacuation totale zones côtières. Sirènes activées. Coordination nationale.', '2026-03-26 13:08:09', 'ACTIVE', NULL, NULL, NULL, 1, 1);

--
-- Déclencheurs `alerts`
--
DELIMITER $$
CREATE TRIGGER `trg_log_alert` AFTER INSERT ON `alerts` FOR EACH ROW BEGIN
    INSERT INTO system_logs (
        action, table_name, record_id, description, new_data
    ) VALUES (
        'ALERT_TRIGGERED',
        'alerts',
        NEW.alert_id,
        CONCAT(
            'ALERTE ', NEW.alert_type,
            ' | Niveau: ', NEW.alert_level,
            ' | Évacuation: ', NEW.evacuation_triggered,
            ' | Sirènes: ', NEW.sirens_activated,
            ' | Événement #', NEW.event_id
        ),
        JSON_OBJECT(
            'alert_id',            NEW.alert_id,
            'event_id',            NEW.event_id,
            'alert_level',         NEW.alert_level,
            'alert_type',          NEW.alert_type,
            'sirens_activated',    NEW.sirens_activated,
            'evacuation_triggered',NEW.evacuation_triggered
        )
    );
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Structure de la table `alert_routes`
--

CREATE TABLE `alert_routes` (
  `alert_id` int(11) NOT NULL,
  `route_id` int(11) NOT NULL,
  `activated_at` datetime DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- --------------------------------------------------------

--
-- Structure de la table `evacuation_routes`
--

CREATE TABLE `evacuation_routes` (
  `route_id` int(11) NOT NULL,
  `route_name` varchar(100) NOT NULL,
  `start_point` varchar(200) NOT NULL,
  `end_point` varchar(200) NOT NULL,
  `distance_km` decimal(6,2) DEFAULT NULL,
  `capacity_persons` int(11) DEFAULT NULL,
  `is_active` tinyint(1) NOT NULL DEFAULT 1,
  `last_verified` date DEFAULT NULL
) ;

--
-- Déchargement des données de la table `evacuation_routes`
--

INSERT INTO `evacuation_routes` (`route_id`, `route_name`, `start_point`, `end_point`, `distance_km`, `capacity_persons`, `is_active`, `last_verified`) VALUES
(1, 'Route A — Marina → Colline Oufella', 'Agadir Marina (niveau mer)', 'Sommet Colline Oufella +200m', 2.80, 15000, 1, '2026-01-10'),
(2, 'Route B — Centre-ville → Université Ibn Zohr', 'Place Al Amal (centre)', 'Université Ibn Zohr (altitude élevée)', 5.20, 25000, 1, '2026-01-10'),
(3, 'Route C — Taghazout → Collines Intérieures', 'Plage Taghazout', 'Zone collines Aourir +300m', 4.10, 8000, 1, '2026-02-05'),
(4, 'Route D — Inezgane → Zone Industrielle Haute', 'Inezgane centre', 'Zone industrielle altitude sécurisée', 6.50, 30000, 1, '2026-01-15'),
(5, 'Route E — Port → Aéroport (urgence)', 'Port commercial Agadir', 'Aéroport Al Massira', 18.00, 5000, 0, '2025-12-01');

-- --------------------------------------------------------

--
-- Structure de la table `seismic_events`
--

CREATE TABLE `seismic_events` (
  `event_id` int(11) NOT NULL,
  `sensor_id` int(11) NOT NULL,
  `magnitude` decimal(4,2) NOT NULL,
  `depth_km` decimal(6,2) DEFAULT NULL,
  `latitude` decimal(9,6) NOT NULL,
  `longitude` decimal(9,6) NOT NULL,
  `event_time` datetime NOT NULL DEFAULT current_timestamp(),
  `duration_seconds` int(11) DEFAULT NULL,
  `epicenter_description` varchar(250) DEFAULT NULL,
  `raw_data` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`raw_data`)),
  `processed` tinyint(1) NOT NULL DEFAULT 0,
  `created_at` datetime NOT NULL DEFAULT current_timestamp()
) ;

--
-- Déchargement des données de la table `seismic_events`
--

INSERT INTO `seismic_events` (`event_id`, `sensor_id`, `magnitude`, `depth_km`, `latitude`, `longitude`, `event_time`, `duration_seconds`, `epicenter_description`, `raw_data`, `processed`, `created_at`) VALUES
(1, 1, 2.10, 12.50, 30.380000, -9.610000, '2025-09-12 08:23:11', 8, 'Microséisme Baie d\'Agadir — non ressenti', NULL, 0, '2026-03-25 22:33:04'),
(2, 3, 3.40, 18.00, 30.490000, -8.920000, '2025-10-05 14:47:33', 15, 'Secousse légère Taroudant — ressentie par certains habitants', NULL, 0, '2026-03-25 22:33:04'),
(3, 4, 4.20, 25.00, 30.820000, -8.810000, '2025-11-18 03:12:55', 22, 'Séisme modéré Tizi-n-Test — réveil habitants, pas de dégâts', NULL, 0, '2026-03-25 22:33:04'),
(4, 2, 5.10, 15.00, 30.500000, -9.720000, '2026-01-07 19:35:42', 35, 'Séisme ressenti Agadir et Taghazout. Légère panique.', NULL, 0, '2026-03-25 22:33:04'),
(5, 5, 5.80, 8.00, 30.280000, -9.980000, '2026-02-14 22:08:17', 48, 'Séisme sous-marin au large. Surveillance côtière déclenchée.', NULL, 0, '2026-03-25 22:33:04'),
(6, 5, 6.50, 12.00, 30.250000, -10.050000, '2026-02-28 07:15:30', 65, 'SÉISME SIGNIFICATIF — Épicentre Atlantique. Alerte tsunami activée.', NULL, 0, '2026-03-25 22:33:04'),
(7, 1, 7.20, 7.50, 30.310000, -9.880000, '2026-03-10 11:44:22', 90, 'SÉISME MAJEUR — Failles sous-marines actives. Tsunami potentiel.', NULL, 0, '2026-03-25 22:33:04'),
(8, 5, 8.30, 5.00, 30.180000, -10.220000, '2026-03-15 04:03:59', 120, 'SÉISME CATASTROPHIQUE — Atlantique nord Agadir. RISQUE TSUNAMI MAXIMAL.', NULL, 0, '2026-03-25 22:33:04'),
(9, 1, 4.80, 10.00, 30.320000, -9.900000, '2026-03-15 04:15:00', 30, 'Réplique principale — 11 min après séisme M8.3', NULL, 0, '2026-03-25 22:33:04'),
(10, 2, 3.90, 9.50, 30.450000, -9.750000, '2026-03-15 04:28:00', 18, 'Réplique secondaire — côte nord Agadir', NULL, 0, '2026-03-25 22:33:04'),
(11, 5, 6.50, 12.00, 30.250000, -10.050000, '2026-03-26 13:08:09', 65, 'SÉISME SIGNIFICATIF — Épicentre Atlantique. Alerte tsunami activée.', NULL, 0, '2026-03-26 13:08:09'),
(12, 1, 7.20, 7.50, 30.310000, -9.880000, '2026-03-26 13:08:09', 90, 'SÉISME MAJEUR — Failles sous-marines actives. Tsunami potentiel.', NULL, 0, '2026-03-26 13:08:09'),
(13, 5, 8.30, 5.00, 30.180000, -10.220000, '2026-03-26 13:08:09', 120, 'SÉISME CATASTROPHIQUE — Atlantique nord Agadir. RISQUE TSUNAMI MAXIMAL.', NULL, 0, '2026-03-26 13:08:09');

--
-- Déclencheurs `seismic_events`
--
DELIMITER $$
CREATE TRIGGER `trg_auto_alert` AFTER INSERT ON `seismic_events` FOR EACH ROW BEGIN
    DECLARE v_level          VARCHAR(10);
    DECLARE v_type           VARCHAR(50);
    DECLARE v_message        TEXT;
    DECLARE v_sirens         TINYINT(1) DEFAULT 0;
    DECLARE v_evacuation     TINYINT(1) DEFAULT 0;

    -- Seuil minimal : 6.5
    IF NEW.magnitude >= 6.5 THEN

        -- Niveau CRITICAL (>= 8.0)
        IF NEW.magnitude >= 8.0 THEN
            SET v_level      = 'CRITICAL';
            SET v_type       = 'TSUNAMI';
            SET v_sirens     = 1;
            SET v_evacuation = 1;
            SET v_message    = CONCAT(
                '? ALERTE MAXIMALE — Séisme M', NEW.magnitude,
                ' prof. ', IFNULL(NEW.depth_km, 0), ' km. ',
                'RISQUE TSUNAMI CERTAIN. Évacuation totale zones côtières. ',
                'Sirènes activées. Coordination nationale.'
            );

        -- Niveau HIGH (>= 7.0)
        ELSEIF NEW.magnitude >= 7.0 THEN
            SET v_level      = 'HIGH';
            SET v_type       = 'TSUNAMI';
            SET v_sirens     = 1;
            SET v_evacuation = 1;
            SET v_message    = CONCAT(
                '⚠️ ALERTE HAUTE — Séisme M', NEW.magnitude,
                '. RISQUE TSUNAMI PROBABLE. ',
                'Zones côtières : Marina, Port, Taghazout. ',
                'Sirènes activées. Évacuation immédiate.'
            );

        -- Niveau MEDIUM (>= 6.5)
        ELSE
            SET v_level      = 'MEDIUM';
            SET v_type       = 'SEISMIC';
            SET v_sirens     = 0;
            SET v_evacuation = 0;
            SET v_message    = CONCAT(
                '⚠️ ALERTE MOYENNE — Séisme M', NEW.magnitude,
                ' enregistré par capteur #', NEW.sensor_id,
                '. Surveillance tsunami activée. Équipes terrain en alerte.'
            );
        END IF;

        INSERT INTO alerts (
            event_id, alert_level, alert_type, message,
            sirens_activated, evacuation_triggered
        ) VALUES (
            NEW.event_id, v_level, v_type, v_message,
            v_sirens, v_evacuation
        );

    END IF;
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `trg_log_seismic_event` AFTER INSERT ON `seismic_events` FOR EACH ROW BEGIN
    INSERT INTO system_logs (
        action, table_name, record_id, description, new_data
    ) VALUES (
        'INSERT',
        'seismic_events',
        NEW.event_id,
        CONCAT(
            'Nouvel événement sismique | M', NEW.magnitude,
            ' | Capteur #', NEW.sensor_id,
            ' | ', NEW.event_time,
            ' | Lat:', NEW.latitude,
            ' Lon:', NEW.longitude
        ),
        JSON_OBJECT(
            'event_id',    NEW.event_id,
            'sensor_id',   NEW.sensor_id,
            'magnitude',   NEW.magnitude,
            'depth_km',    NEW.depth_km,
            'latitude',    NEW.latitude,
            'longitude',   NEW.longitude,
            'event_time',  CAST(NEW.event_time AS CHAR)
        )
    );
END
$$
DELIMITER ;
DELIMITER $$
CREATE TRIGGER `trg_validate_event` BEFORE INSERT ON `seismic_events` FOR EACH ROW BEGIN
    DECLARE v_sensor_status VARCHAR(20);

    -- ── Magnitude négative ──────────────────────────────
    IF NEW.magnitude < 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'DONNÉE ABERRANTE : magnitude négative rejetée.';
    END IF;

    -- ── Magnitude impossible > 10 ───────────────────────
    IF NEW.magnitude > 10 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'DONNÉE ABERRANTE : magnitude > 10 impossible.';
    END IF;

    -- ── Profondeur négative ──────────────────────────────
    IF NEW.depth_km IS NOT NULL AND NEW.depth_km < 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'DONNÉE ABERRANTE : profondeur négative rejetée.';
    END IF;

    -- ── Durée négative ───────────────────────────────────
    IF NEW.duration_seconds IS NOT NULL AND NEW.duration_seconds < 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'DONNÉE ABERRANTE : durée négative rejetée.';
    END IF;

    -- ── Vérification existence et état du capteur ────────
    SELECT status INTO v_sensor_status
    FROM seismic_sensors
    WHERE sensor_id = NEW.sensor_id;

    IF v_sensor_status IS NULL THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'SÉCURITÉ : capteur inconnu — insertion bloquée.';
    END IF;

    -- ── Mise à jour last_ping du capteur ─────────────────
    UPDATE seismic_sensors
    SET last_ping = NOW()
    WHERE sensor_id = NEW.sensor_id;
END
$$
DELIMITER ;

-- --------------------------------------------------------

--
-- Structure de la table `seismic_sensors`
--

CREATE TABLE `seismic_sensors` (
  `sensor_id` int(11) NOT NULL,
  `sensor_code` varchar(20) NOT NULL,
  `name` varchar(100) NOT NULL,
  `latitude` decimal(9,6) NOT NULL,
  `longitude` decimal(9,6) NOT NULL,
  `altitude_m` decimal(8,2) DEFAULT NULL,
  `depth_meters` decimal(8,2) DEFAULT NULL,
  `location_description` text DEFAULT NULL,
  `status` enum('ONLINE','OFFLINE','MAINTENANCE','FAULTY') NOT NULL DEFAULT 'ONLINE',
  `installed_at` date NOT NULL,
  `last_ping` datetime DEFAULT NULL,
  `created_by` int(11) DEFAULT NULL
) ;

--
-- Déchargement des données de la table `seismic_sensors`
--

INSERT INTO `seismic_sensors` (`sensor_id`, `sensor_code`, `name`, `latitude`, `longitude`, `altitude_m`, `depth_meters`, `location_description`, `status`, `installed_at`, `last_ping`, `created_by`) VALUES
(1, 'SMR-AG-01', 'Capteur Agadir Marina', 30.427800, -9.598100, NULL, 5.00, 'Zone Marina Agadir, proche côte atlantique', 'ONLINE', '2024-01-15', '2026-03-26 13:08:09', NULL),
(2, 'SMR-TG-02', 'Capteur Taghazout', 30.544200, -9.708000, NULL, 8.00, 'Village Taghazout, côte nord Agadir', 'ONLINE', '2024-02-20', '2026-03-25 22:33:04', NULL),
(3, 'SMR-TR-03', 'Capteur Taroudant Intérieur', 30.470200, -8.877200, NULL, 10.00, 'Zone intérieure Taroudant, failles actives', 'ONLINE', '2024-03-10', '2026-03-25 22:33:04', NULL),
(4, 'SMR-TZ-04', 'Capteur Tizi-n-Test', 30.853300, -8.716200, NULL, 15.00, 'Col Tizi-n-Test, zone sismiquement active', 'ONLINE', '2024-04-05', '2026-03-25 22:33:04', NULL),
(5, 'SMR-SF-05', 'Capteur Fonds Marins Agadir', 30.320000, -9.950000, NULL, 50.00, 'Capteur sous-marin, fosses atlantiques', 'ONLINE', '2024-05-01', '2026-03-26 13:08:09', NULL),
(6, 'SMR-IN-06', 'Capteur Inezgane', 30.354400, -9.533200, NULL, 6.00, 'Zone urbaine Inezgane, densité élevée', 'MAINTENANCE', '2024-06-15', NULL, NULL),
(7, 'SMR-TO-07', 'Capteur Tiznit Sud', 29.697400, -9.732000, NULL, 12.00, 'Zone sud Tiznit, frontière sismique', 'ONLINE', '2024-07-20', NULL, NULL);

-- --------------------------------------------------------

--
-- Structure de la table `system_logs`
--

CREATE TABLE `system_logs` (
  `log_id` int(11) NOT NULL,
  `action` enum('INSERT','UPDATE','DELETE','ALERT_TRIGGERED','LOGIN','LOGOUT','API_CALL','NORMAL_EVENT_SKIPPED') NOT NULL,
  `table_name` varchar(50) DEFAULT NULL,
  `record_id` int(11) DEFAULT NULL,
  `description` text DEFAULT NULL,
  `old_data` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`old_data`)),
  `new_data` longtext CHARACTER SET utf8mb4 COLLATE utf8mb4_bin DEFAULT NULL CHECK (json_valid(`new_data`)),
  `performed_by` int(11) DEFAULT NULL,
  `ip_address` varchar(45) DEFAULT NULL,
  `performed_at` datetime NOT NULL DEFAULT current_timestamp()
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Déchargement des données de la table `system_logs`
--

INSERT INTO `system_logs` (`log_id`, `action`, `table_name`, `record_id`, `description`, `old_data`, `new_data`, `performed_by`, `ip_address`, `performed_at`) VALUES
(1, 'INSERT', 'seismic_events', 1, 'Nouvel événement sismique | M2.10 | Capteur #1 | 2025-09-12 08:23:11 | Lat:30.380000 Lon:-9.610000', NULL, '{\"event_id\": 1, \"sensor_id\": 1, \"magnitude\": 2.10, \"depth_km\": 12.50, \"latitude\": 30.380000, \"longitude\": -9.610000, \"event_time\": \"2025-09-12 08:23:11\"}', NULL, NULL, '2026-03-25 22:33:04'),
(2, 'INSERT', 'seismic_events', 2, 'Nouvel événement sismique | M3.40 | Capteur #3 | 2025-10-05 14:47:33 | Lat:30.490000 Lon:-8.920000', NULL, '{\"event_id\": 2, \"sensor_id\": 3, \"magnitude\": 3.40, \"depth_km\": 18.00, \"latitude\": 30.490000, \"longitude\": -8.920000, \"event_time\": \"2025-10-05 14:47:33\"}', NULL, NULL, '2026-03-25 22:33:04'),
(3, 'INSERT', 'seismic_events', 3, 'Nouvel événement sismique | M4.20 | Capteur #4 | 2025-11-18 03:12:55 | Lat:30.820000 Lon:-8.810000', NULL, '{\"event_id\": 3, \"sensor_id\": 4, \"magnitude\": 4.20, \"depth_km\": 25.00, \"latitude\": 30.820000, \"longitude\": -8.810000, \"event_time\": \"2025-11-18 03:12:55\"}', NULL, NULL, '2026-03-25 22:33:04'),
(4, 'INSERT', 'seismic_events', 4, 'Nouvel événement sismique | M5.10 | Capteur #2 | 2026-01-07 19:35:42 | Lat:30.500000 Lon:-9.720000', NULL, '{\"event_id\": 4, \"sensor_id\": 2, \"magnitude\": 5.10, \"depth_km\": 15.00, \"latitude\": 30.500000, \"longitude\": -9.720000, \"event_time\": \"2026-01-07 19:35:42\"}', NULL, NULL, '2026-03-25 22:33:04'),
(5, 'INSERT', 'seismic_events', 5, 'Nouvel événement sismique | M5.80 | Capteur #5 | 2026-02-14 22:08:17 | Lat:30.280000 Lon:-9.980000', NULL, '{\"event_id\": 5, \"sensor_id\": 5, \"magnitude\": 5.80, \"depth_km\": 8.00, \"latitude\": 30.280000, \"longitude\": -9.980000, \"event_time\": \"2026-02-14 22:08:17\"}', NULL, NULL, '2026-03-25 22:33:04'),
(6, 'ALERT_TRIGGERED', 'alerts', 1, 'ALERTE SEISMIC | Niveau: MEDIUM | Évacuation: 0 | Sirènes: 0 | Événement #6', NULL, '{\"alert_id\": 1, \"event_id\": 6, \"alert_level\": \"MEDIUM\", \"alert_type\": \"SEISMIC\", \"sirens_activated\": 0, \"evacuation_triggered\": 0}', NULL, NULL, '2026-03-25 22:33:04'),
(7, 'INSERT', 'seismic_events', 6, 'Nouvel événement sismique | M6.50 | Capteur #5 | 2026-02-28 07:15:30 | Lat:30.250000 Lon:-10.050000', NULL, '{\"event_id\": 6, \"sensor_id\": 5, \"magnitude\": 6.50, \"depth_km\": 12.00, \"latitude\": 30.250000, \"longitude\": -10.050000, \"event_time\": \"2026-02-28 07:15:30\"}', NULL, NULL, '2026-03-25 22:33:04'),
(8, 'ALERT_TRIGGERED', 'alerts', 2, 'ALERTE TSUNAMI | Niveau: HIGH | Évacuation: 1 | Sirènes: 1 | Événement #7', NULL, '{\"alert_id\": 2, \"event_id\": 7, \"alert_level\": \"HIGH\", \"alert_type\": \"TSUNAMI\", \"sirens_activated\": 1, \"evacuation_triggered\": 1}', NULL, NULL, '2026-03-25 22:33:04'),
(9, 'INSERT', 'seismic_events', 7, 'Nouvel événement sismique | M7.20 | Capteur #1 | 2026-03-10 11:44:22 | Lat:30.310000 Lon:-9.880000', NULL, '{\"event_id\": 7, \"sensor_id\": 1, \"magnitude\": 7.20, \"depth_km\": 7.50, \"latitude\": 30.310000, \"longitude\": -9.880000, \"event_time\": \"2026-03-10 11:44:22\"}', NULL, NULL, '2026-03-25 22:33:04'),
(10, 'ALERT_TRIGGERED', 'alerts', 3, 'ALERTE TSUNAMI | Niveau: CRITICAL | Évacuation: 1 | Sirènes: 1 | Événement #8', NULL, '{\"alert_id\": 3, \"event_id\": 8, \"alert_level\": \"CRITICAL\", \"alert_type\": \"TSUNAMI\", \"sirens_activated\": 1, \"evacuation_triggered\": 1}', NULL, NULL, '2026-03-25 22:33:04'),
(11, 'INSERT', 'seismic_events', 8, 'Nouvel événement sismique | M8.30 | Capteur #5 | 2026-03-15 04:03:59 | Lat:30.180000 Lon:-10.220000', NULL, '{\"event_id\": 8, \"sensor_id\": 5, \"magnitude\": 8.30, \"depth_km\": 5.00, \"latitude\": 30.180000, \"longitude\": -10.220000, \"event_time\": \"2026-03-15 04:03:59\"}', NULL, NULL, '2026-03-25 22:33:04'),
(12, 'INSERT', 'seismic_events', 9, 'Nouvel événement sismique | M4.80 | Capteur #1 | 2026-03-15 04:15:00 | Lat:30.320000 Lon:-9.900000', NULL, '{\"event_id\": 9, \"sensor_id\": 1, \"magnitude\": 4.80, \"depth_km\": 10.00, \"latitude\": 30.320000, \"longitude\": -9.900000, \"event_time\": \"2026-03-15 04:15:00\"}', NULL, NULL, '2026-03-25 22:33:04'),
(13, 'INSERT', 'seismic_events', 10, 'Nouvel événement sismique | M3.90 | Capteur #2 | 2026-03-15 04:28:00 | Lat:30.450000 Lon:-9.750000', NULL, '{\"event_id\": 10, \"sensor_id\": 2, \"magnitude\": 3.90, \"depth_km\": 9.50, \"latitude\": 30.450000, \"longitude\": -9.750000, \"event_time\": \"2026-03-15 04:28:00\"}', NULL, NULL, '2026-03-25 22:33:04'),
(14, 'NORMAL_EVENT_SKIPPED', 'seismic_events', NULL, 'Import JSON — Evenement ignore (M2.1 < 6.5) | Capteur #1', NULL, '{\"source\": \"import-json\", \"sensor_id\": 1, \"magnitude\": 2.1, \"latitude\": 30.38, \"longitude\": -9.61}', NULL, '127.0.0.1', '2026-03-26 13:08:09'),
(15, 'NORMAL_EVENT_SKIPPED', 'seismic_events', NULL, 'Import JSON — Evenement ignore (M3.4 < 6.5) | Capteur #3', NULL, '{\"source\": \"import-json\", \"sensor_id\": 3, \"magnitude\": 3.4, \"latitude\": 30.49, \"longitude\": -8.92}', NULL, '127.0.0.1', '2026-03-26 13:08:09'),
(16, 'NORMAL_EVENT_SKIPPED', 'seismic_events', NULL, 'Import JSON — Evenement ignore (M5.1 < 6.5) | Capteur #2', NULL, '{\"source\": \"import-json\", \"sensor_id\": 2, \"magnitude\": 5.1, \"latitude\": 30.5, \"longitude\": -9.72}', NULL, '127.0.0.1', '2026-03-26 13:08:09'),
(17, 'ALERT_TRIGGERED', 'alerts', 4, 'ALERTE SEISMIC | Niveau: MEDIUM | Évacuation: 0 | Sirènes: 0 | Événement #11', NULL, '{\"alert_id\": 4, \"event_id\": 11, \"alert_level\": \"MEDIUM\", \"alert_type\": \"SEISMIC\", \"sirens_activated\": 0, \"evacuation_triggered\": 0}', NULL, NULL, '2026-03-26 13:08:09'),
(18, 'INSERT', 'seismic_events', 11, 'Nouvel événement sismique | M6.50 | Capteur #5 | 2026-03-26 13:08:09 | Lat:30.250000 Lon:-10.050000', NULL, '{\"event_id\": 11, \"sensor_id\": 5, \"magnitude\": 6.50, \"depth_km\": 12.00, \"latitude\": 30.250000, \"longitude\": -10.050000, \"event_time\": \"2026-03-26 13:08:09\"}', NULL, NULL, '2026-03-26 13:08:09'),
(19, 'ALERT_TRIGGERED', 'alerts', 5, 'ALERTE TSUNAMI | Niveau: HIGH | Évacuation: 1 | Sirènes: 1 | Événement #12', NULL, '{\"alert_id\": 5, \"event_id\": 12, \"alert_level\": \"HIGH\", \"alert_type\": \"TSUNAMI\", \"sirens_activated\": 1, \"evacuation_triggered\": 1}', NULL, NULL, '2026-03-26 13:08:09'),
(20, 'INSERT', 'seismic_events', 12, 'Nouvel événement sismique | M7.20 | Capteur #1 | 2026-03-26 13:08:09 | Lat:30.310000 Lon:-9.880000', NULL, '{\"event_id\": 12, \"sensor_id\": 1, \"magnitude\": 7.20, \"depth_km\": 7.50, \"latitude\": 30.310000, \"longitude\": -9.880000, \"event_time\": \"2026-03-26 13:08:09\"}', NULL, NULL, '2026-03-26 13:08:09'),
(21, 'ALERT_TRIGGERED', 'alerts', 6, 'ALERTE TSUNAMI | Niveau: CRITICAL | Évacuation: 1 | Sirènes: 1 | Événement #13', NULL, '{\"alert_id\": 6, \"event_id\": 13, \"alert_level\": \"CRITICAL\", \"alert_type\": \"TSUNAMI\", \"sirens_activated\": 1, \"evacuation_triggered\": 1}', NULL, NULL, '2026-03-26 13:08:09'),
(22, 'INSERT', 'seismic_events', 13, 'Nouvel événement sismique | M8.30 | Capteur #5 | 2026-03-26 13:08:09 | Lat:30.180000 Lon:-10.220000', NULL, '{\"event_id\": 13, \"sensor_id\": 5, \"magnitude\": 8.30, \"depth_km\": 5.00, \"latitude\": 30.180000, \"longitude\": -10.220000, \"event_time\": \"2026-03-26 13:08:09\"}', NULL, NULL, '2026-03-26 13:08:09');

-- --------------------------------------------------------

--
-- Structure de la table `users`
--

CREATE TABLE `users` (
  `user_id` int(11) NOT NULL,
  `username` varchar(50) NOT NULL,
  `password_hash` varchar(255) NOT NULL,
  `role` enum('admin','operator','viewer') NOT NULL DEFAULT 'viewer',
  `email` varchar(100) NOT NULL,
  `full_name` varchar(100) DEFAULT NULL,
  `is_active` tinyint(1) NOT NULL DEFAULT 1,
  `created_at` datetime NOT NULL DEFAULT current_timestamp(),
  `last_login` datetime DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

--
-- Déchargement des données de la table `users`
--

INSERT INTO `users` (`user_id`, `username`, `password_hash`, `role`, `email`, `full_name`, `is_active`, `created_at`, `last_login`) VALUES
(2, 'op_agadir', '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeG6Lruj3vjPGga31lW', 'operator', 'operateur@tsunami-agadir.ma', 'Fatima Ait Benhaddou', 1, '2026-03-25 22:33:04', NULL),
(3, 'viewer_civil', '$2b$12$N9qo8uLOickgx2ZFFWfTtebxKkjyS9bnHfqdK2kmpd9SH0BHCEVTW', 'viewer', 'civil@protection-agadir.ma', 'Omar Benali', 1, '2026-03-25 22:33:04', NULL),
(4, 'admin_tsunami', '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMaJqetFpMpM3gS8J2Rb0Ia0HK', 'admin', 'admin@tsunami-agadir.ma', 'Dr. Hassan Al-Morabit', 1, '2026-03-25 23:25:31', NULL);

--
-- Index pour les tables déchargées
--

--
-- Index pour la table `alerts`
--
ALTER TABLE `alerts`
  ADD PRIMARY KEY (`alert_id`),
  ADD KEY `acknowledged_by` (`acknowledged_by`),
  ADD KEY `idx_alerts_event` (`event_id`),
  ADD KEY `idx_alerts_status` (`status`),
  ADD KEY `idx_alerts_time` (`triggered_at`);

--
-- Index pour la table `alert_routes`
--
ALTER TABLE `alert_routes`
  ADD PRIMARY KEY (`alert_id`,`route_id`),
  ADD KEY `route_id` (`route_id`);

--
-- Index pour la table `evacuation_routes`
--
ALTER TABLE `evacuation_routes`
  ADD PRIMARY KEY (`route_id`);

--
-- Index pour la table `seismic_events`
--
ALTER TABLE `seismic_events`
  ADD PRIMARY KEY (`event_id`),
  ADD KEY `idx_events_sensor` (`sensor_id`),
  ADD KEY `idx_events_time` (`event_time`),
  ADD KEY `idx_events_magnitude` (`magnitude`);

--
-- Index pour la table `seismic_sensors`
--
ALTER TABLE `seismic_sensors`
  ADD PRIMARY KEY (`sensor_id`),
  ADD UNIQUE KEY `uq_sensor_code` (`sensor_code`),
  ADD KEY `created_by` (`created_by`),
  ADD KEY `idx_sensors_status` (`status`);

--
-- Index pour la table `system_logs`
--
ALTER TABLE `system_logs`
  ADD PRIMARY KEY (`log_id`),
  ADD KEY `performed_by` (`performed_by`),
  ADD KEY `idx_logs_time` (`performed_at`),
  ADD KEY `idx_logs_action` (`action`);

--
-- Index pour la table `users`
--
ALTER TABLE `users`
  ADD PRIMARY KEY (`user_id`),
  ADD UNIQUE KEY `uq_username` (`username`),
  ADD UNIQUE KEY `uq_email` (`email`);

--
-- AUTO_INCREMENT pour les tables déchargées
--

--
-- AUTO_INCREMENT pour la table `alerts`
--
ALTER TABLE `alerts`
  MODIFY `alert_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=7;

--
-- AUTO_INCREMENT pour la table `evacuation_routes`
--
ALTER TABLE `evacuation_routes`
  MODIFY `route_id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT pour la table `seismic_events`
--
ALTER TABLE `seismic_events`
  MODIFY `event_id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT pour la table `seismic_sensors`
--
ALTER TABLE `seismic_sensors`
  MODIFY `sensor_id` int(11) NOT NULL AUTO_INCREMENT;

--
-- AUTO_INCREMENT pour la table `system_logs`
--
ALTER TABLE `system_logs`
  MODIFY `log_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=23;

--
-- AUTO_INCREMENT pour la table `users`
--
ALTER TABLE `users`
  MODIFY `user_id` int(11) NOT NULL AUTO_INCREMENT, AUTO_INCREMENT=5;

--
-- Contraintes pour les tables déchargées
--

--
-- Contraintes pour la table `alerts`
--
ALTER TABLE `alerts`
  ADD CONSTRAINT `alerts_ibfk_1` FOREIGN KEY (`event_id`) REFERENCES `seismic_events` (`event_id`),
  ADD CONSTRAINT `alerts_ibfk_2` FOREIGN KEY (`acknowledged_by`) REFERENCES `users` (`user_id`) ON DELETE SET NULL;

--
-- Contraintes pour la table `alert_routes`
--
ALTER TABLE `alert_routes`
  ADD CONSTRAINT `alert_routes_ibfk_1` FOREIGN KEY (`alert_id`) REFERENCES `alerts` (`alert_id`),
  ADD CONSTRAINT `alert_routes_ibfk_2` FOREIGN KEY (`route_id`) REFERENCES `evacuation_routes` (`route_id`);

--
-- Contraintes pour la table `seismic_events`
--
ALTER TABLE `seismic_events`
  ADD CONSTRAINT `seismic_events_ibfk_1` FOREIGN KEY (`sensor_id`) REFERENCES `seismic_sensors` (`sensor_id`);

--
-- Contraintes pour la table `seismic_sensors`
--
ALTER TABLE `seismic_sensors`
  ADD CONSTRAINT `seismic_sensors_ibfk_1` FOREIGN KEY (`created_by`) REFERENCES `users` (`user_id`) ON DELETE SET NULL;

--
-- Contraintes pour la table `system_logs`
--
ALTER TABLE `system_logs`
  ADD CONSTRAINT `system_logs_ibfk_1` FOREIGN KEY (`performed_by`) REFERENCES `users` (`user_id`) ON DELETE SET NULL;
COMMIT;

/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
