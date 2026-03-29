# 🌊 Agadir Tsunami-Ready — Système d'Alerte & Évacuation Côtière

> **Projet SIBD 2025-2026** | Souss-Massa Resilience Prototype 2026  
> **Équipe 8** | École Nationale Supérieure de l'IA et Sciences des Données — Taroudant  
> **Encadrant :** Pr. S. EL-ATEIF  
> **Thématique :** Sujet 8 — Agadir Tsunami-Ready (Évacuation côtière)

---

## 📋 Table des matières

- [Vision du projet](#-vision-du-projet)
- [Équipe et rôles](#-équipe-et-rôles)
- [Architecture générale](#-architecture-générale)
- [Stack technique](#-stack-technique)
- [Structure des fichiers](#-structure-des-fichiers)
- [Modèle de données (MCD)](#-modèle-de-données-mcd)
- [Base de données MySQL](#-base-de-données-mysql)
- [Triggers MySQL](#-triggers-mysql)
- [Procédures stockées](#-procédures-stockées)
- [API REST Flask](#-api-rest-flask)
- [Import JSON — Fonctionnalité clé](#-import-json--fonctionnalité-clé)
- [Sécurité](#-sécurité)
- [Installation pas à pas](#-installation-pas-à-pas)
- [Tests et QA](#-tests-et-qa)
- [Rapport de transparence IA](#-rapport-de-transparence-ia)

---

## 🎯 Vision du projet

**Agadir Tsunami-Ready** est un système d'information critique qui surveille l'activité sismique marine autour de la région d'Agadir (Souss-Massa, Maroc) et déclenche automatiquement des alertes tsunami avec gestion des routes d'évacuation côtière.

### Objectifs métier
- Détecter en temps réel les séismes via un réseau de **7 capteurs géolocalisés**
- Évaluer automatiquement le risque tsunami via un **score pondéré** (magnitude + profondeur + distance côte)
- Déclencher des **alertes graduées** (MEDIUM / HIGH / CRITICAL) avec activation des sirènes
- Gérer **5 routes d'évacuation** d'Agadir vers les zones en altitude
- Assurer une **traçabilité complète** via journalisation automatique

### Périmètre géographique
> Côte atlantique d'Agadir · Marina · Taghazout · Inezgane · Taroudant · Tizi-n-Test · Fonds marins atlantiques

---

## 👥 Équipe et rôles

| Sous-unité | Membres | Mission |
|---|---|---|
| **Architects** (Modélisation manuelle) | Lamrani Alaoui Houda, Latlassi Abdelmaoula, Mazzine Omar | MCD MERISE, schéma 3FN, procédures stockées |
| **Augmenteds** (IA/Prompt Engineering) | Merizak Yousra, Mezouara Hassna, Mouhaddab Oumaima | Génération de code via IA, API Flask, import JSON |
| **Red Team** (Attaque) | Miftah N., Mohhi Aya | Tests d'intrusion, SQLi, Man-in-the-Middle |
| **Blue Team** (Défense) | Mourabit Ikram, M'rak Abdellah | RBAC, CORS, paramètres bindés, bcrypt |
| **QA Engineer** | Najy Omar, Negry Aya | Scénarios de test, temps de réponse < 1s |

---

## 🏗️ Architecture générale

```
┌─────────────────────────────────────────────────────────┐
│              CLIENTS EXTERNES                           │
│   Frontend JS (port 8080) │ Postman │ phpMyAdmin        │
└──────────────┬────────────┴─────────┴──────────────────-┘
               │ HTTP/REST
               ▼
┌─────────────────────────────────────────────────────────┐
│           API FLASK — port 5000                         │
│   CORS actif · Anti-SQLi · Validation Python            │
│   11 routes REST · Import JSON · PyMySQL                │
└──────────────────────────┬──────────────────────────────┘
                           │ PyMySQL (paramètres bindés)
                           ▼
┌─────────────────────────────────────────────────────────┐
│        BASE DE DONNÉES MySQL — tsunami_ready            │
│                                                         │
│  users ──────────────────────────────┐                  │
│                                      ▼                  │
│  seismic_sensors ──► seismic_events ──► alerts          │
│                            │               │            │
│                       system_logs ◄────────┘            │
│                                                         │
│  alert_routes ◄──── alerts ────────► evacuation_routes  │
│                                                         │
│  4 Triggers · 3 Procédures stockées · 9 Index           │
└─────────────────────────────────────────────────────────┘
```

---

## 🛠️ Stack technique

| Composant | Technologie | Version |
|---|---|---|
| Base de données | MySQL / MariaDB | 10.4+ |
| Interface admin BD | phpMyAdmin | 5.2+ |
| Backend API | Python Flask | 3.x |
| Connecteur MySQL | PyMySQL | latest |
| Sécurité mots de passe | bcrypt | cost 12 |
| CORS | flask-cors | latest |
| Frontend | JavaScript vanilla + Leaflet | - |

---

## 📁 Structure des fichiers

```
tsunami_mysql/
├── 📄 01_schema.sql          # Tables 3FN + contraintes CHECK + 9 index
├── 📄 02_triggers.sql        # 4 triggers MySQL (validation + alertes + logs)
├── 📄 03_procedures.sql      # 3 procédures stockées (risque + tsunami + rapport)
├── 📄 04_seed_data.sql       # Données réalistes Agadir (7 capteurs, 10 séismes)
├── 📄 tsunami_ready.sql      # Dump complet phpMyAdmin (tout-en-un)
├── 🐍 05_app.py              # API Flask complète (11 routes, CORS, import JSON)
├── 📦 events_import.json     # Fichier d'import de test (6 événements sismiques)
└── 📖 README.md              # Ce fichier
```

---

## 🗃️ Modèle de données (MCD)

Le schéma respecte la **3ème forme normale (3FN)** — aucune dépendance transitive.

### Entités principales

| Entité | Clé | Attributs clés | Description |
|---|---|---|---|
| `users` | `user_id` | role ENUM(admin/operator/viewer) | Gestion RBAC |
| `seismic_sensors` | `sensor_id` | latitude, longitude, status | 7 capteurs géolocalisés |
| `seismic_events` | `event_id` | magnitude, depth_km, event_time | Séismes détectés |
| `alerts` | `alert_id` | alert_level, sirens_activated | Alertes auto-générées |
| `system_logs` | `log_id` | action ENUM, new_data JSON | Journal d'audit |
| `evacuation_routes` | `route_id` | distance_km, capacity_persons | 5 routes Agadir |
| `alert_routes` | (alert_id, route_id) | activated_at | **Table N:N** alerte ↔ route |

### Relations et cardinalités MERISE

```
UTILISATEUR (0,N) ──── CREE ──── (0,1) CAPTEUR_SISMIQUE
CAPTEUR_SISMIQUE (1,N) ── ENREGISTRE ── (1,1) EVENEMENT_SISMIQUE
EVENEMENT_SISMIQUE (0,1) ── GENERE [si M≥6.5] ── (1,1) ALERTE
UTILISATEUR (0,N) ── ACQUITTE [date_ack] ── (0,1) ALERTE
ALERTE (0,N) ─── RECOMMANDE [activated_at] ─── (0,N) ROUTE_EVACUATION
EVENEMENT+ALERTE (1,N) ── JOURNALISE [auto/trigger] ── (1,1) JOURNAL_SYSTEME
```

> La liaison **ALERTE ↔ ROUTE_EVACUATION** est matérialisée par la table `alert_routes`  
> avec PK composite `(alert_id, route_id)` et attribut `activated_at`.

---

## 🗄️ Base de données MySQL

### Installation

```sql
-- Étape 1 : Créer la base (phpMyAdmin → onglet Importer)
-- Importer : 01_schema.sql

-- OU tout-en-un depuis le dump complet :
-- Importer : tsunami_ready.sql
```

### Tables et cardinalités

```sql
-- Vérification après import
SELECT 'Utilisateurs'    AS table_name, COUNT(*) AS total FROM users
UNION ALL
SELECT 'Capteurs',       COUNT(*) FROM seismic_sensors
UNION ALL
SELECT 'Événements',     COUNT(*) FROM seismic_events
UNION ALL
SELECT 'Alertes',        COUNT(*) FROM alerts
UNION ALL
SELECT 'Logs',           COUNT(*) FROM system_logs
UNION ALL
SELECT 'Routes évac.',   COUNT(*) FROM evacuation_routes
UNION ALL
SELECT 'Liaisons alerte-routes', COUNT(*) FROM alert_routes;
```

**Résultat attendu :** 3 · 7 · 10 · 3 · 22 · 5 · 0 (alert_routes vide initialement)

### Index de performance (9 index)

```sql
idx_events_sensor    -- Jointures capteur → événements
idx_events_time      -- Tri chronologique
idx_events_magnitude -- Filtrage par magnitude
idx_alerts_event     -- Jointures événement → alertes
idx_alerts_status    -- Filtrage ACTIVE/ACKNOWLEDGED/RESOLVED
idx_alerts_time      -- Tri chronologique alertes
idx_logs_time        -- Audit chronologique
idx_logs_action      -- Filtrage par type d'action
idx_sensors_status   -- Monitoring capteurs ONLINE/OFFLINE
```

---

## ⚡ Triggers MySQL

### Vue d'ensemble

| # | Trigger | Événement | Rôle |
|---|---|---|---|
| 1 | `trg_validate_event` | BEFORE INSERT seismic_events | Rejette les données aberrantes |
| 2 | `trg_auto_alert` | AFTER INSERT seismic_events | Génère alerte si M ≥ 6.5 |
| 3 | `trg_log_seismic_event` | AFTER INSERT seismic_events | Log JSON automatique |
| 4 | `trg_log_alert` | AFTER INSERT alerts | Log de chaque alerte |

### Trigger 1 — Validation (BEFORE INSERT)

```sql
-- trg_validate_event bloque les données aberrantes :
-- ✗ magnitude < 0 ou > 10
-- ✗ depth_km < 0
-- ✗ duration_seconds < 0
-- ✗ sensor_id inexistant dans seismic_sensors
-- ✓ Met à jour last_ping du capteur si valide
```

### Trigger 2 — Alerte automatique (AFTER INSERT)

```sql
-- Seuils de déclenchement :
-- M ≥ 6.5 → MEDIUM  (SEISMIC  · sirènes=0 · évacuation=0)
-- M ≥ 7.0 → HIGH    (TSUNAMI  · sirènes=1 · évacuation=1)
-- M ≥ 8.0 → CRITICAL(TSUNAMI  · sirènes=1 · évacuation=1 · coordination nationale)
```

### Test des triggers

```sql
-- Test 1 : Données valides (M ≥ 6.5 → alerte HIGH générée automatiquement)
INSERT INTO seismic_events (sensor_id, magnitude, depth_km, latitude, longitude)
VALUES (1, 7.2, 8.0, 30.31, -9.88);

-- Vérifier l'alerte créée :
SELECT * FROM alerts ORDER BY alert_id DESC LIMIT 1;

-- Test 2 : Données aberrantes (doit être rejeté par trg_validate_event)
INSERT INTO seismic_events (sensor_id, magnitude, depth_km, latitude, longitude)
VALUES (1, -5.0, 10.0, 30.31, -9.88);
-- → ERROR: DONNÉE ABERRANTE : magnitude négative rejetée.

-- Test 3 : Capteur inconnu (doit être rejeté)
INSERT INTO seismic_events (sensor_id, magnitude, depth_km, latitude, longitude)
VALUES (999, 4.0, 10.0, 30.31, -9.88);
-- → ERROR: SÉCURITÉ : capteur inconnu — insertion bloquée.
```

---

## 🔄 Procédures stockées

### Procédure 1 — Niveau de risque par magnitude

```sql
-- Retourne : risk_level, description, recommended_action, color_code
CALL calculate_risk_level(7.2);

-- Niveaux :
-- M < 2.0  → NÉGLIGEABLE (gris)
-- M < 3.5  → TRÈS FAIBLE  (vert)
-- M < 5.0  → MODÉRÉ       (jaune)
-- M < 6.5  → ÉLEVÉ        (orange)
-- M < 7.5  → CRITIQUE     (rouge)
-- M ≥ 7.5  → CATASTROPHIQUE (violet)
```

### Procédure 2 — Évaluation tsunami (score pondéré)

```sql
-- Score = Magnitude(0-50pts) + Profondeur(0-30pts) + Distance côte Agadir(0-20pts)
-- Retourne : should_trigger_alert, risk_score, risk_category, alert_message,
--            distance_coast_km, estimated_wave_time_min
CALL evaluate_tsunami_risk(7);  -- event_id = 7

-- Catégories :
-- Score ≥ 70 → CATASTROPHIQUE (tsunami imminent)
-- Score ≥ 50 → CRITIQUE       (évacuation côtière)
-- Score ≥ 30 → SURVEILLANCE   (équipes en standby)
-- Score < 30 → FAIBLE         (surveillance standard)
```

### Procédure 3 — Rapport statistique

```sql
-- Retourne les KPIs des N derniers jours
CALL get_seismic_report(30);

-- Résultats : total_events, avg_magnitude, max_magnitude,
--             total_alerts, critical_alerts, most_active_sensor
```

---

## 🌐 API REST Flask

### Démarrage du serveur

```bash
# Installation des dépendances
pip install flask flask-cors PyMySQL bcrypt

# Variables d'environnement (optionnel)
set DB_HOST=localhost
set DB_PORT=3306
set DB_NAME=tsunami_ready
set DB_USER=root
set DB_PASSWORD=votre_mot_de_passe

# Lancement
python 05_app.py
# → Running on http://0.0.0.0:5000
```

### Tableau complet des routes

| Méthode | Route | Description | Auth |
|---|---|---|---|
| `POST` | `/auth/login` | Authentification utilisateur | — |
| `GET` | `/sensors` | Liste des 7 capteurs sismiques | — |
| `POST` | `/events` | Ajouter un événement sismique | — |
| `GET` | `/events` | Lister les événements (filtrable par magnitude) | — |
| `GET` | `/seismic-events/latest` | Dernier événement enregistré | — |
| `GET` | `/alerts` | Lister les alertes actives/résolues | — |
| `PUT` | `/alerts/<id>/acknowledge` | Acquitter une alerte | — |
| `GET` | `/risk/<magnitude>` | Niveau de risque pour une magnitude | — |
| `GET` | `/tsunami-eval/<event_id>` | Évaluation complète d'un événement | — |
| `GET` | `/report?days=30` | Rapport statistique sur N jours | — |
| `GET` | `/logs?limit=100` | Journal système complet | — |
| `POST` | `/events/import-json` | **Import en masse depuis fichier JSON** | — |
| `GET` | `/sirens/status` | État des 8 sirènes (lié aux alertes actives) | — |

### Exemples de requêtes (curl / Postman)

```bash
# Vérifier que l'API tourne
curl http://localhost:5000/sensors

# Ajouter un événement sismique
curl -X POST http://localhost:5000/events \
  -H "Content-Type: application/json" \
  -d '{"sensor_id":5,"magnitude":7.2,"depth_km":8.0,"latitude":30.31,"longitude":-9.88}'

# Niveau de risque pour M=7.2
curl http://localhost:5000/risk/7.2

# Évaluation tsunami pour l'événement #7
curl http://localhost:5000/tsunami-eval/7

# Rapport des 30 derniers jours
curl http://localhost:5000/report?days=30

# Import depuis fichier JSON
curl -X POST http://localhost:5000/events/import-json \
  -H "Content-Type: application/json" \
  -d '{"file_path":"C:/tsunami_mysql/events_import.json"}'
```

---

## 📥 Import JSON — Fonctionnalité clé

La route `POST /events/import-json` permet d'importer en masse des événements sismiques depuis un fichier JSON.

### Format du fichier JSON

```json
{
  "events": [
    {
      "sensor_id": 1,
      "magnitude": 4.2,
      "depth_km": 12.5,
      "latitude": 30.3800,
      "longitude": -9.6100,
      "duration_seconds": 8,
      "epicenter_description": "Microséisme Baie Agadir"
    },
    {
      "sensor_id": 5,
      "magnitude": 7.1,
      "depth_km": 8.0,
      "latitude": 30.2500,
      "longitude": -10.0500,
      "duration_seconds": 90,
      "epicenter_description": "SÉISME MAJEUR — Tsunami potentiel"
    }
  ]
}
```

### Logique de traitement

```
Pour chaque événement dans le fichier JSON :
│
├── Validation Python (magnitude, coordonnées GPS, sensor_id)
│
├── magnitude < 6.5 ?
│   └── OUI → NE PAS insérer en base
│             → LOG dans system_logs : action = 'NORMAL_EVENT_SKIPPED'
│
└── magnitude ≥ 6.5 ?
    └── OUI → INSERT dans seismic_events
              → Triggers MySQL s'activent automatiquement :
                  • trg_validate_event (BEFORE INSERT)
                  • trg_auto_alert     (AFTER INSERT) → crée alerte
                  • trg_log_seismic_event (AFTER INSERT) → log JSON
```

### Réponse de l'API

```json
{
  "success": true,
  "file_processed": "/chemin/vers/events_import.json",
  "total_events": 6,
  "summary": {
    "inserted": 3,
    "skipped": 3,
    "errors": 0
  },
  "results": [
    {"index": 0, "status": "SKIPPED",  "magnitude": 2.1, "reason": "Magnitude < 6.5"},
    {"index": 3, "status": "INSERTED", "magnitude": 6.5, "event_id": 11},
    {"index": 4, "status": "INSERTED", "magnitude": 7.2, "event_id": 12},
    {"index": 5, "status": "INSERTED", "magnitude": 8.3, "event_id": 13}
  ]
}
```

### Prérequis — Migration schéma

```sql
-- À exécuter UNE FOIS dans phpMyAdmin avant d'utiliser import-json :
ALTER TABLE system_logs
  MODIFY COLUMN action
  ENUM('INSERT','UPDATE','DELETE','ALERT_TRIGGERED',
       'LOGIN','LOGOUT','API_CALL','NORMAL_EVENT_SKIPPED')
  NOT NULL;
```

---

## 🔐 Sécurité

### Mécanismes implémentés

| Mécanisme | Implémentation | Niveau |
|---|---|---|
| **Anti-SQLi** | Paramètres `%s` bindés PyMySQL — 0 concaténation | Obligatoire |
| **CORS** | `flask-cors` — autorise le frontend cross-port | Configuré |
| **Validation** | Fonctions Python avant tout INSERT (magnitude, GPS, sensor_id) | Double couche |
| **Triggers BD** | `trg_validate_event` bloque les données aberrantes côté MySQL | Double couche |
| **bcrypt** | Mots de passe hashés cost 12 — jamais stockés en clair | Obligatoire |
| **Path traversal** | `Path.resolve()` + extension `.json` forcée pour import | Sécurisé |
| **Taille limite** | Import JSON limité à 5 Mo et 500 événements max | Protégé |

### Comptes de test

| Utilisateur | Mot de passe | Rôle | Permissions |
|---|---|---|---|
| `admin_tsunami` | `Admin2026!` | admin | Lecture + écriture + logs + rapport |
| `op_agadir` | `Operator2026!` | operator | Lecture + acquittement alertes |
| `viewer_civil` | `Viewer2026!` | viewer | Lecture seule |

### Points d'audit Red Team

```
✗ Tentatives à tester :
  - Injection SQL dans /events (body JSON)
  - Path traversal dans /events/import-json
  - Insertion de magnitude négative ou > 10
  - Sensor_id inexistant
  - Fichier JSON > 5 Mo
  - Man-in-the-Middle sur les signaux d'alerte
  - DoS : 500 requêtes simultanées sur /events
```

---

## 🚀 Installation pas à pas

### Prérequis

- XAMPP / WAMP (MySQL + phpMyAdmin)
- Python 3.8+
- pip

### Étape 1 — Base de données

```
1. Ouvrir phpMyAdmin → http://localhost/phpmyadmin
2. Onglet "Importer"
3. Sélectionner tsunami_ready.sql → Exécuter
   (Contient : schéma + triggers + procédures + données de test)

4. Appliquer la migration ENUM :
   Onglet SQL → coller :
   ALTER TABLE system_logs
     MODIFY COLUMN action
     ENUM('INSERT','UPDATE','DELETE','ALERT_TRIGGERED',
          'LOGIN','LOGOUT','API_CALL','NORMAL_EVENT_SKIPPED')
     NOT NULL;
```

### Étape 2 — API Flask

```bash
# Cloner le dépôt
git clone https://github.com/votre-equipe/agadir-tsunami-ready.git
cd agadir-tsunami-ready

# Installer les dépendances
pip install flask flask-cors PyMySQL bcrypt

# Configurer la connexion MySQL (si mot de passe différent de vide)
set DB_PASSWORD=votre_mdp_mysql

# Lancer l'API
python 05_app.py
```

### Étape 3 — Vérification

```bash
# L'API répond correctement ?
curl http://localhost:5000/sensors
# → {"count": 7, "sensors": [...]}

# Les capteurs sont listés ?
curl http://localhost:5000/events
# → {"count": 10, "events": [...]}

# Les alertes existent ?
curl http://localhost:5000/alerts
# → {"count": 3, "alerts": [...]}
```

### Étape 4 — Frontend (Membre 3)

```bash
# Ouvrir le dossier du frontend
cd tsunami-ready/

# Copier api.js mis à jour (pointe vers port 5000)
# cp api_updated.js src/services/api.js

# Ouvrir dans le navigateur
python -m http.server 8080
# → http://localhost:8080
```

---

## 🧪 Tests et QA

### Scénarios de test QA

#### Test 1 — Temps de réponse < 1 seconde (exigence cahier des charges)

```bash
# Mesurer le temps de réponse pour une alerte critique
time curl http://localhost:5000/alerts
# Attendu : < 1000ms
```

#### Test 2 — Import JSON (cas normaux et critiques)

```bash
curl -X POST http://localhost:5000/events/import-json \
  -H "Content-Type: application/json" \
  -d '{"file_path":"C:/tsunami_mysql/events_import.json"}'

# Résultat attendu :
# - 3 événements SKIPPED (M < 6.5)
# - 3 événements INSERTED (M ≥ 6.5) + alertes auto-créées
```

#### Test 3 — Trigger de validation (données aberrantes)

```sql
-- Dans phpMyAdmin → SQL :
INSERT INTO seismic_events (sensor_id, magnitude, depth_km, latitude, longitude)
VALUES (1, 15.0, 10.0, 30.31, -9.88);
-- Attendu : ERROR 1644 - DONNÉE ABERRANTE : magnitude > 10 impossible.
```

#### Test 4 — Procédure stockée

```sql
CALL calculate_risk_level(7.2);
-- Attendu : risk_level = 'CRITIQUE', color_code = '#EF4444'

CALL evaluate_tsunami_risk(8);
-- Attendu : risk_score ≥ 70, risk_category = 'CATASTROPHIQUE'
```

#### Test 5 — Vérification des alertes après import

```sql
SELECT alert_level, COUNT(*) AS total
FROM alerts
GROUP BY alert_level
ORDER BY FIELD(alert_level, 'CRITICAL', 'HIGH', 'MEDIUM', 'LOW');

SELECT * FROM system_logs
WHERE action = 'NORMAL_EVENT_SKIPPED'
ORDER BY performed_at DESC;
```

### Capteurs de test (données seed)

| Code | Nom | Latitude | Longitude | Statut |
|---|---|---|---|---|
| SMR-AG-01 | Agadir Marina | 30.4278 | -9.5981 | ONLINE |
| SMR-TG-02 | Taghazout | 30.5442 | -9.7080 | ONLINE |
| SMR-TR-03 | Taroudant Intérieur | 30.4702 | -8.8772 | ONLINE |
| SMR-TZ-04 | Tizi-n-Test | 30.8533 | -8.7162 | ONLINE |
| SMR-SF-05 | Fonds Marins Agadir | 30.3200 | -9.9500 | ONLINE |
| SMR-IN-06 | Inezgane | 30.3544 | -9.5332 | **MAINTENANCE** |
| SMR-TO-07 | Tiznit Sud | 29.6974 | -9.7320 | ONLINE |

---

## 📝 Rapport de transparence IA

Conformément aux exigences du cahier des charges (Section 5 — Méthodologie : L'Expérimentation IA).

### Prompts utilisés et résultats

| # | Prompt | Outil IA | Résultat | Correction apportée |
|---|---|---|---|---|
| 1 | "Génère un schéma MySQL 3FN pour un système d'alerte tsunami" | Claude | Schéma complet avec FK et CHECK | Ajout de l'index `idx_events_magnitude` manquant |
| 2 | "Crée un trigger AFTER INSERT qui génère une alerte si magnitude >= 6.5" | Claude | `trg_auto_alert` fonctionnel | Correction du DELIMITER phpMyAdmin |
| 3 | "Génère une procédure stockée de score pondéré tsunami" | Claude | `evaluate_tsunami_risk` avec 3 facteurs | Ajustement des poids (50/30/20 pts) |
| 4 | "Crée une route Flask POST /events/import-json" | Claude | Route complète avec validation | Ajout de la protection path-traversal |
| 5 | "Connecte le frontend JavaScript à l'API Flask" | Claude | `api.js` mis à jour port 5000 | Ajout CORS côté Flask |

### Hallucinations détectées et corrigées

| Hallucination | Impact | Correction |
|---|---|---|
| L'IA a utilisé `DELIMITER` directement dans phpMyAdmin SQL | Erreur de syntaxe | Utiliser l'onglet "Importer" à la place |
| L'IA a proposé `source fichier.sql` dans phpMyAdmin | Erreur SQL | `source` = commande terminal, pas phpMyAdmin |
| L'IA a oublié `fill="none"` sur les `<path>` SVG | Rendu noir | Ajout systématique de l'attribut |

### Comparaison Architects vs Augmenteds

| Critère | Architects (Manuel) | Augmenteds (IA) |
|---|---|---|
| Temps de conception MCD | 4 heures | 30 minutes |
| Qualité MERISE | Cardinalités précises | Quelques approximations corrigées |
| Temps de codage API | Non évalué | 2 heures (10 routes) |
| Sécurité générée | Analyse manuelle | RBAC + anti-SQLi inclus automatiquement |
| Bugs trouvés | 0 (conception) | 3 (correction path-traversal, DELIMITER, CORS) |

---

## 📊 Grille de conformité projet

| Critère | Requis | Implémenté |
|---|---|---|
| Base de données 3FN | ✅ | ✅ 6 tables normalisées |
| Minimum 3 Triggers | ✅ | ✅ 4 triggers |
| Minimum 2 Procédures stockées | ✅ | ✅ 3 procédures |
| RBAC | ✅ | ✅ 3 rôles (admin/operator/viewer) |
| Anti-injection SQL | ✅ | ✅ Paramètres bindés PyMySQL |
| Interface Web | ✅ | ✅ Frontend JS + Leaflet (Membre 3) |
| Données réalistes (Data Mocking) | ✅ | ✅ 7 capteurs + 10 séismes + 5 routes |
| Rapport de transparence IA | ✅ | ✅ Section dédiée dans ce README |
| README professionnel | ✅ | ✅ Ce fichier |

---

## 🔗 Liens utiles

- **phpMyAdmin :** http://localhost/phpmyadmin
- **API Flask :** http://localhost:5000
- **Frontend :** http://localhost:8080
- **Capteurs (API) :** http://localhost:5000/sensors
- **Alertes (API) :** http://localhost:5000/alerts
- **Rapport 30j (API) :** http://localhost:5000/report

---

## 📜 Licence

Projet académique — École Nationale Supérieure de l'IA et Sciences des Données, Taroudant.  
Projet SIBD 2025-2026 | Pr. S. EL-ATEIF | Équipe 8 — Agadir Tsunami-Ready.

---

*Dernière mise à jour : 29 mars 2026 — Souss-Massa Resilience Prototype 2026*
