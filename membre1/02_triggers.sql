-- ============================================================
--  TRIGGERS MySQL — Agadir Tsunami-Ready
--  ⚠️  Dans phpMyAdmin : coller UN trigger à la fois
--      (ou coller le fichier entier dans l'onglet SQL)
-- ============================================================

USE tsunami_ready;

DELIMITER $$

-- ============================================================
--  TRIGGER 1 : Alerte automatique si magnitude >= 6.5
--  AFTER INSERT sur seismic_events
-- ============================================================
CREATE TRIGGER trg_auto_alert
AFTER INSERT ON seismic_events
FOR EACH ROW
BEGIN
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
                '🚨 ALERTE MAXIMALE — Séisme M', NEW.magnitude,
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
END$$


-- ============================================================
--  TRIGGER 2 : Validation AVANT insertion — rejette données aberrantes
--  BEFORE INSERT sur seismic_events
-- ============================================================
CREATE TRIGGER trg_validate_event
BEFORE INSERT ON seismic_events
FOR EACH ROW
BEGIN
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
END$$


-- ============================================================
--  TRIGGER 3 : Log automatique de chaque événement sismique
--  AFTER INSERT sur seismic_events
-- ============================================================
CREATE TRIGGER trg_log_seismic_event
AFTER INSERT ON seismic_events
FOR EACH ROW
BEGIN
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
END$$


-- ============================================================
--  TRIGGER 4 : Log de chaque alerte générée
--  AFTER INSERT sur alerts
-- ============================================================
CREATE TRIGGER trg_log_alert
AFTER INSERT ON alerts
FOR EACH ROW
BEGIN
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
END$$

DELIMITER ;
