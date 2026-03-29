-- ============================================================
--  PROCÉDURES STOCKÉES MySQL — Agadir Tsunami-Ready
--  Compatible phpMyAdmin
-- ============================================================

USE tsunami_ready;

DELIMITER $$

-- ============================================================
--  PROCÉDURE 1 : Calculer le niveau de risque
--  Appel : CALL calculate_risk_level(7.2);
-- ============================================================
CREATE PROCEDURE calculate_risk_level(IN p_magnitude DECIMAL(4,2))
BEGIN
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


-- ============================================================
--  PROCÉDURE 2 : Évaluation complète du risque tsunami
--  Score pondéré sur 3 facteurs :
--    - Magnitude  (0–50 points)
--    - Profondeur (0–30 points)
--    - Proximité côte Agadir (0–20 points)
--  Appel : CALL evaluate_tsunami_risk(7);
-- ============================================================
CREATE PROCEDURE evaluate_tsunami_risk(IN p_event_id INT)
BEGIN
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


-- ============================================================
--  PROCÉDURE 3 : Rapport statistique sur N jours
--  Appel : CALL get_seismic_report(30);
-- ============================================================
CREATE PROCEDURE get_seismic_report(IN p_days INT)
BEGIN
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
