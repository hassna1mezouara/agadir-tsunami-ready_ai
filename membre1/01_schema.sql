-- ============================================================
--  AGADIR TSUNAMI-READY — Schéma MySQL (3FN)
--  Compatible phpMyAdmin — Copier-coller direct
--  Projet SIBD 2025-2026 | Souss-Massa Resilience
-- ============================================================

CREATE DATABASE IF NOT EXISTS tsunami_ready
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

USE tsunami_ready;

-- ============================================================
--  TABLE 1 : users  (RBAC)
-- ============================================================
CREATE TABLE users (
    user_id       INT            NOT NULL AUTO_INCREMENT,
    username      VARCHAR(50)    NOT NULL,
    password_hash VARCHAR(255)   NOT NULL,
    role          ENUM('admin','operator','viewer') NOT NULL DEFAULT 'viewer',
    email         VARCHAR(100)   NOT NULL,
    full_name     VARCHAR(100),
    is_active     TINYINT(1)     NOT NULL DEFAULT 1,
    created_at    DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    last_login    DATETIME,
    PRIMARY KEY (user_id),
    UNIQUE KEY uq_username (username),
    UNIQUE KEY uq_email    (email)
) ENGINE=InnoDB;

-- ============================================================
--  TABLE 2 : seismic_sensors
-- ============================================================
CREATE TABLE seismic_sensors (
    sensor_id            INT            NOT NULL AUTO_INCREMENT,
    sensor_code          VARCHAR(20)    NOT NULL,
    name                 VARCHAR(100)   NOT NULL,
    latitude             DECIMAL(9,6)   NOT NULL,
    longitude            DECIMAL(9,6)   NOT NULL,
    altitude_m           DECIMAL(8,2),
    depth_meters         DECIMAL(8,2),
    location_description TEXT,
    status               ENUM('ONLINE','OFFLINE','MAINTENANCE','FAULTY') NOT NULL DEFAULT 'ONLINE',
    installed_at         DATE           NOT NULL,
    last_ping            DATETIME,
    created_by           INT,
    PRIMARY KEY  (sensor_id),
    UNIQUE KEY   uq_sensor_code (sensor_code),
    CONSTRAINT   chk_lat  CHECK (latitude  BETWEEN -90  AND 90),
    CONSTRAINT   chk_lon  CHECK (longitude BETWEEN -180 AND 180),
    CONSTRAINT   chk_dep  CHECK (depth_meters >= 0),
    FOREIGN KEY  (created_by) REFERENCES users(user_id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- ============================================================
--  TABLE 3 : seismic_events
-- ============================================================
CREATE TABLE seismic_events (
    event_id              INT            NOT NULL AUTO_INCREMENT,
    sensor_id             INT            NOT NULL,
    magnitude             DECIMAL(4,2)   NOT NULL,
    depth_km              DECIMAL(6,2),
    latitude              DECIMAL(9,6)   NOT NULL,
    longitude             DECIMAL(9,6)   NOT NULL,
    event_time            DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    duration_seconds      INT,
    epicenter_description VARCHAR(250),
    raw_data              JSON,
    processed             TINYINT(1)     NOT NULL DEFAULT 0,
    created_at            DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (event_id),
    CONSTRAINT chk_mag      CHECK (magnitude >= 0 AND magnitude <= 10),
    CONSTRAINT chk_depth_km CHECK (depth_km  >= 0),
    CONSTRAINT chk_dur      CHECK (duration_seconds >= 0),
    FOREIGN KEY (sensor_id) REFERENCES seismic_sensors(sensor_id) ON DELETE RESTRICT
) ENGINE=InnoDB;

-- ============================================================
--  TABLE 4 : alerts
-- ============================================================
CREATE TABLE alerts (
    alert_id             INT            NOT NULL AUTO_INCREMENT,
    event_id             INT            NOT NULL,
    alert_level          ENUM('LOW','MEDIUM','HIGH','CRITICAL') NOT NULL,
    alert_type           VARCHAR(50)    NOT NULL,
    message              TEXT           NOT NULL,
    triggered_at         DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    status               ENUM('ACTIVE','ACKNOWLEDGED','RESOLVED') NOT NULL DEFAULT 'ACTIVE',
    acknowledged_by      INT,
    acknowledged_at      DATETIME,
    resolved_at          DATETIME,
    sirens_activated     TINYINT(1)     NOT NULL DEFAULT 0,
    evacuation_triggered TINYINT(1)     NOT NULL DEFAULT 0,
    PRIMARY KEY (alert_id),
    FOREIGN KEY (event_id)        REFERENCES seismic_events(event_id) ON DELETE RESTRICT,
    FOREIGN KEY (acknowledged_by) REFERENCES users(user_id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- ============================================================
--  TABLE 5 : system_logs
-- ============================================================
CREATE TABLE system_logs (
    log_id       INT            NOT NULL AUTO_INCREMENT,
    action       ENUM('INSERT','UPDATE','DELETE','ALERT_TRIGGERED','LOGIN','LOGOUT','API_CALL') NOT NULL,
    table_name   VARCHAR(50),
    record_id    INT,
    description  TEXT,
    old_data     JSON,
    new_data     JSON,
    performed_by INT,
    ip_address   VARCHAR(45),
    performed_at DATETIME       NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY  (log_id),
    FOREIGN KEY  (performed_by) REFERENCES users(user_id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- ============================================================
--  TABLE 6 : evacuation_routes
-- ============================================================
CREATE TABLE evacuation_routes (
    route_id         INT            NOT NULL AUTO_INCREMENT,
    route_name       VARCHAR(100)   NOT NULL,
    start_point      VARCHAR(200)   NOT NULL,
    end_point        VARCHAR(200)   NOT NULL,
    distance_km      DECIMAL(6,2),
    capacity_persons INT,
    is_active        TINYINT(1)     NOT NULL DEFAULT 1,
    last_verified    DATE,
    PRIMARY KEY (route_id),
    CONSTRAINT chk_dist CHECK (distance_km     > 0),
    CONSTRAINT chk_cap  CHECK (capacity_persons > 0)
) ENGINE=InnoDB;

-- ============================================================
--  INDEX (performances)
-- ============================================================
CREATE INDEX idx_events_sensor    ON seismic_events(sensor_id);
CREATE INDEX idx_events_time      ON seismic_events(event_time);
CREATE INDEX idx_events_magnitude ON seismic_events(magnitude);
CREATE INDEX idx_alerts_event     ON alerts(event_id);
CREATE INDEX idx_alerts_status    ON alerts(status);
CREATE INDEX idx_alerts_time      ON alerts(triggered_at);
CREATE INDEX idx_logs_time        ON system_logs(performed_at);
CREATE INDEX idx_logs_action      ON system_logs(action);
CREATE INDEX idx_sensors_status   ON seismic_sensors(status);
