# Agadir Tsunami-Ready — Membre 3 : Frontend & Carte
## Système de gestion des routes d'évacuation et des sirènes d'alerte

---

## Structure du projet

```
tsunami-ready/
├── index.html
└── src/
    ├── styles/
    │   └── main.css                 ← Thème sombre côtier
    ├── utils/
    │   └── evacuation.js            ← ★ ALGORITHME routes d'évacuation
    ├── services/
    │   ├── api.js                   ← REST → Membre 1
    │   └── websocket.js             ← WS  → Membre 2
    ├── store/
    │   └── state.js                 ← État global
    └── components/
        ├── map.js                   ← Carte Leaflet interactive
        ├── charts.js                ← Graphiques Chart.js
        ├── sirens.js                ← ★ TRIGGER sirènes
        ├── assembly.js              ← Points de hauteur
        ├── dashboard.js             ← KPIs
        └── app.js                   ← Orchestrateur
```

---

## Fonctionnalités réalisées (Membre 3)

### ★ Algorithme : Route d'évacuation la plus rapide (`evacuation.js`)
- Formule **Haversine** pour la distance GPS réelle
- **Score composite** = distance × 0.5 + (1/altitude) × 20 + occupation% × 0.3 + pénalité_inondation
- Détecte si le citoyen est dans une **zone inondable côtière** (4 zones prédéfinies Agadir)
- Ajuste la vitesse de marche (4 km/h normal, 2.5 km/h en zone risquée)
- Calcule les **3 meilleures alternatives** pour chaque citoyen
- **6 points de rassemblement en hauteur** (75m à 140m d'altitude)

### ★ Trigger sirènes automatique (`sirens.js` + `app.js`)
- Si **secousse marine > 6.5** → activation automatique de **toutes les sirènes**
- Bandeau d'alerte rouge animé en haut de l'écran
- Notification navigateur (si permission accordée)
- Test manuel possible depuis l'interface

### Carte interactive (`map.js`)
- Routes d'évacuation en temps réel (vert = sûr, orange = zone risquée)
- Positions GPS des citoyens (points bleus)
- Zones inondables côtières (cercles rouges hachurés)
- Points de rassemblement en hauteur (marqueurs violets)
- Basculement de couches (citoyens / routes / hauteurs / zones)

### Dashboard (`dashboard.js`)
- Dernière secousse marine détectée
- Nombre de sirènes actives
- Citoyens en évacuation (GPS actifs)
- Routes calculées en temps réel
- Flux de population (graphique temps réel)
- Historique des secousses marines

### Points de rassemblement en hauteur (`assembly.js`)
- 6 points prédéfinis autour d'Agadir (Yachts Club, Founty, Anza, Université Ibn Zohr...)
- Barres de capacité en temps réel
- Équipements disponibles par point

---

## Intégration avec Membre 1 & 2

### Membre 1 — Backend (`api.js`)
```
BASE_URL = http://IP_MEMBRE1:3000/api
GET /api/events              → liste secousses sismiques
GET /api/seismic-events/latest → dernier événement
GET /api/sirens/status       → état sirènes
GET /api/citizens/positions  → positions GPS
```

### Membre 2 — WebSocket (`websocket.js`)
```
WS_URL = ws://IP_MEMBRE2:3001

Messages reçus :
{ type: "citizen_positions",  payload: [{id, latitude, longitude, speed_kmh}] }
{ type: "seismic_event",      payload: {magnitude, location, type:"marine", ...} }
{ type: "siren_activate",     payload: {siren_id, active:true} }
```

---

## Lancement

```bash
# Dans le dossier tsunami-ready/ :
python -m http.server 8080
# Ouvrir : http://localhost:8080
```

---

## Points de rassemblement définis

| ID  | Nom                     | Altitude | Capacité |
|-----|-------------------------|----------|----------|
| AP1 | Colline Yachts Club     | 85 m     | 3 000    |
| AP2 | Plateau Founty          | 120 m    | 5 000    |
| AP3 | Colline Anza Haute      | 95 m     | 2 500    |
| AP4 | Zone Industrielle       | 110 m    | 4 000    |
| AP5 | Université Ibn Zohr     | 140 m    | 8 000    |
| AP6 | Colline Bensergao       | 75 m     | 2 000    |

---

## ★ PROMPTS GITHUB — Messages de commit

### Commit 1 — Structure initiale
```
feat: init projet Membre3 Frontend & Carte - Agadir Tsunami-Ready

- Création structure src/ (components, services, store, utils, styles)
- index.html avec 4 vues : Dashboard, Carte, Sirènes, Points de hauteur
- Thème sombre côtier CSS (Barlow Condensed + DM Mono)
- Navigation sidebar avec état des connexions
```

### Commit 2 — Algorithme évacuation
```
feat(algo): implémentation algorithme routes d'évacuation GPS

- Formule Haversine pour distance réelle entre coordonnées
- Score composite : distance + altitude + occupation + risque inondation
- 6 points de rassemblement en hauteur définis (75m-140m altitude)
- 4 zones inondables côtières Agadir identifiées
- Calcul durée estimée selon vitesse piéton (normal/zone risquée)
- Retourne best + 2 alternatives pour chaque citoyen
```

### Commit 3 — Carte Leaflet
```
feat(map): carte interactive Leaflet - évacuation temps réel

- Fond de carte OpenStreetMap avec filtre thème sombre
- Affichage routes d'évacuation (vert=sûr, orange=zone risquée)
- Positions GPS citoyens en temps réel (points bleus)
- Zones inondables côtières (cercles rouges hachurés)
- Points de rassemblement en hauteur (marqueurs violets)
- Toggle couches (citoyens / routes / hauteurs / zones danger)
- Zoom automatique sur séisme magnitude >= 5
```

### Commit 4 — Trigger sirènes
```
feat(sirens): trigger automatique sirènes si secousse marine > 6.5

- Détection type marine dans payload événement sismique
- Activation automatique toutes sirènes si magnitude >= 6.5
- Bandeau alerte rouge animé avec magnitude affichée
- Notification navigateur (Web Notifications API)
- Test manuel depuis interface + bouton réinitialisation
- 8 sirènes virtuelles définies (zones côtières Agadir)
```

### Commit 5 — Services API & WebSocket
```
feat(services): connexion API REST Membre1 + WebSocket Membre2

- api.js : endpoints GET /events, /sirens/status, /citizens/positions
- Fallback mock data si backend non disponible
- websocket.js : écoute citizen_positions, seismic_event, siren_activate
- Reconnexion automatique toutes les 6s si déconnexion
- Mock WebSocket toutes les 3s en mode démo
- Indicateurs visuels état connexion (sidebar)
```

### Commit 6 — Dashboard & Charts
```
feat(dashboard): KPIs temps réel + graphiques Chart.js

- 4 KPIs : magnitude, sirènes, citoyens, routes
- Graphique flux population (évacuation en cours)
- Graphique historique secousses marines (code couleur magnitude)
- Barres capacité points de rassemblement en temps réel
- Polling API backup toutes les 30s
```

### Commit 7 — Final
```
chore: finalisation Membre3 - Agadir Tsunami-Ready v1.0

- Intégration complète API Membre1 + WebSocket Membre2
- Mode démo fonctionnel sans backend
- README complet avec architecture et guide d'intégration
- Tests manuels sirènes + reset
```

---

## Technologies
- **Leaflet.js 1.9.4** — Carte interactive
- **Chart.js 4.4** — Graphiques
- **Vanilla JS** — Aucun framework
- **Web Notifications API** — Alertes navigateur
- **WebSocket API** — Temps réel
