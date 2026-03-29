-- ============================================================
--  DONNÉES DE TEST — Agadir Tsunami-Ready (MySQL)
--  Simulation réaliste région Souss-Massa
-- ============================================================

USE tsunami_ready;

-- ============================================================
--  UTILISATEURS
--  Mots de passe (bcrypt) :
--    admin     → Admin2026!
--    operator  → Operator2026!
--    viewer    → Viewer2026!
--  (hashés dans l'API Flask — ici on insère directement)
-- ============================================================
INSERT INTO users (username, password_hash, role, email, full_name) VALUES
('admin_tsunami',
 '$2b$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMaJqetFpMpM3gS8J2Rb0Ia0HK',
 'admin',    'admin@tsunami-agadir.ma',     'Dr. Hassan Al-Morabit'),
('op_agadir',
 '$2b$12$EixZaYVK1fsbw1ZfbX3OXePaWxn96p36WQoeG6Lruj3vjPGga31lW',
 'operator', 'operateur@tsunami-agadir.ma', 'Fatima Ait Benhaddou'),
('viewer_civil',
 '$2b$12$N9qo8uLOickgx2ZFFWfTtebxKkjyS9bnHfqdK2kmpd9SH0BHCEVTW',
 'viewer',   'civil@protection-agadir.ma',  'Omar Benali');

-- ============================================================
--  CAPTEURS SISMIQUES (positions réelles autour d'Agadir)
-- ============================================================
INSERT INTO seismic_sensors
    (sensor_code, name, latitude, longitude, depth_meters, location_description, status, installed_at, created_by)
VALUES
('SMR-AG-01', 'Capteur Agadir Marina',
 30.427800, -9.598100, 5.0,
 'Zone Marina Agadir, proche côte atlantique', 'ONLINE', '2024-01-15', 1),

('SMR-TG-02', 'Capteur Taghazout',
 30.544200, -9.708000, 8.0,
 'Village Taghazout, côte nord Agadir', 'ONLINE', '2024-02-20', 1),

('SMR-TR-03', 'Capteur Taroudant Intérieur',
 30.470200, -8.877200, 10.0,
 'Zone intérieure Taroudant, failles actives', 'ONLINE', '2024-03-10', 1),

('SMR-TZ-04', 'Capteur Tizi-n-Test',
 30.853300, -8.716200, 15.0,
 'Col Tizi-n-Test, zone sismiquement active', 'ONLINE', '2024-04-05', 1),

('SMR-SF-05', 'Capteur Fonds Marins Agadir',
 30.320000, -9.950000, 50.0,
 'Capteur sous-marin, fosses atlantiques', 'ONLINE', '2024-05-01', 1),

('SMR-IN-06', 'Capteur Inezgane',
 30.354400, -9.533200, 6.0,
 'Zone urbaine Inezgane, densité élevée', 'MAINTENANCE', '2024-06-15', 1),

('SMR-TO-07', 'Capteur Tiznit Sud',
 29.697400, -9.732000, 12.0,
 'Zone sud Tiznit, frontière sismique', 'ONLINE', '2024-07-20', 1);

-- ============================================================
--  ÉVÉNEMENTS SISMIQUES
--  (les triggers s'exécutent automatiquement à chaque INSERT)
-- ============================================================

-- Événements faibles (pas d'alerte)
INSERT INTO seismic_events
    (sensor_id, magnitude, depth_km, latitude, longitude, event_time, duration_seconds, epicenter_description)
VALUES
(1, 2.10, 12.5, 30.380000, -9.610000,
 '2025-09-12 08:23:11', 8,
 'Microséisme Baie d''Agadir — non ressenti'),

(3, 3.40, 18.0, 30.490000, -8.920000,
 '2025-10-05 14:47:33', 15,
 'Secousse légère Taroudant — ressentie par certains habitants'),

(4, 4.20, 25.0, 30.820000, -8.810000,
 '2025-11-18 03:12:55', 22,
 'Séisme modéré Tizi-n-Test — réveil habitants, pas de dégâts'),

-- Magnitude intermédiaire
(2, 5.10, 15.0, 30.500000, -9.720000,
 '2026-01-07 19:35:42', 35,
 'Séisme ressenti Agadir et Taghazout. Légère panique.'),

(5, 5.80, 8.0,  30.280000, -9.980000,
 '2026-02-14 22:08:17', 48,
 'Séisme sous-marin au large. Surveillance côtière déclenchée.'),

-- Événements déclencheurs d'alertes (>= 6.5 → Trigger 1 s'active)
(5, 6.50, 12.0, 30.250000, -10.050000,
 '2026-02-28 07:15:30', 65,
 'SÉISME SIGNIFICATIF — Épicentre Atlantique. Alerte tsunami activée.'),

(1, 7.20, 7.5,  30.310000, -9.880000,
 '2026-03-10 11:44:22', 90,
 'SÉISME MAJEUR — Failles sous-marines actives. Tsunami potentiel.'),

(5, 8.30, 5.0,  30.180000, -10.220000,
 '2026-03-15 04:03:59', 120,
 'SÉISME CATASTROPHIQUE — Atlantique nord Agadir. RISQUE TSUNAMI MAXIMAL.'),

-- Répliques
(1, 4.80, 10.0, 30.320000, -9.900000,
 '2026-03-15 04:15:00', 30,
 'Réplique principale — 11 min après séisme M8.3'),

(2, 3.90, 9.5,  30.450000, -9.750000,
 '2026-03-15 04:28:00', 18,
 'Réplique secondaire — côte nord Agadir');

-- ============================================================
--  MISE À JOUR STATUTS ALERTES (simulation réaliste)
-- ============================================================
-- Alerte M6.5 → résolue
UPDATE alerts
SET status = 'RESOLVED',
    resolved_at = '2026-02-28 09:00:00'
WHERE event_id = (
    SELECT event_id FROM seismic_events
    WHERE magnitude = 6.50 LIMIT 1
);

-- Alerte M7.2 → acquittée par l'opérateur
UPDATE alerts
SET status          = 'ACKNOWLEDGED',
    acknowledged_by = 2,
    acknowledged_at = '2026-03-10 11:50:00'
WHERE event_id = (
    SELECT event_id FROM seismic_events
    WHERE magnitude = 7.20 LIMIT 1
);

-- ============================================================
--  ROUTES D'ÉVACUATION AGADIR
-- ============================================================
INSERT INTO evacuation_routes
    (route_name, start_point, end_point, distance_km, capacity_persons, is_active, last_verified)
VALUES
('Route A — Marina → Colline Oufella',
 'Agadir Marina (niveau mer)',
 'Sommet Colline Oufella +200m',
 2.8, 15000, 1, '2026-01-10'),

('Route B — Centre-ville → Université Ibn Zohr',
 'Place Al Amal (centre)',
 'Université Ibn Zohr (altitude élevée)',
 5.2, 25000, 1, '2026-01-10'),

('Route C — Taghazout → Collines Intérieures',
 'Plage Taghazout',
 'Zone collines Aourir +300m',
 4.1, 8000, 1, '2026-02-05'),

('Route D — Inezgane → Zone Industrielle Haute',
 'Inezgane centre',
 'Zone industrielle altitude sécurisée',
 6.5, 30000, 1, '2026-01-15'),

('Route E — Port → Aéroport (urgence)',
 'Port commercial Agadir',
 'Aéroport Al Massira',
 18.0, 5000, 0, '2025-12-01');

-- ============================================================
--  VÉRIFICATION — À coller dans un onglet SQL phpMyAdmin
-- ============================================================
SELECT 'Capteurs'       AS table_name, COUNT(*) AS total FROM seismic_sensors
UNION ALL
SELECT 'Événements',    COUNT(*) FROM seismic_events
UNION ALL
SELECT 'Alertes',       COUNT(*) FROM alerts
UNION ALL
SELECT 'Logs',          COUNT(*) FROM system_logs
UNION ALL
SELECT 'Routes évac.',  COUNT(*) FROM evacuation_routes;
