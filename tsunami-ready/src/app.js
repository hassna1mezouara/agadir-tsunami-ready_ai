/**
 * app.js — Orchestrateur principal
 * Agadir Tsunami-Ready — Membre 3 Frontend & Carte
 */

// ---- NAVIGATION ----
function showView(name) {
  document.querySelectorAll('.view').forEach(v => v.classList.remove('active'));
  document.querySelectorAll('.nav-btn').forEach(b => b.classList.remove('active'));
  document.getElementById(`view-${name}`).classList.add('active');
  document.querySelector(`[data-view="${name}"]`).classList.add('active');

  if (name === 'map') {
    MapComp.init();
    const s = Store.get();
    MapComp.updateCitizens(s.citizens, s.routes);
  }
  if (name === 'assembly') {
    AssemblyComp.renderCards(Store.get().occupancyMap);
  }
}

// ---- INIT ----
async function init() {
  console.log('[APP] Agadir Tsunami-Ready — Démarrage');

  // Dot API
  document.getElementById('dot-api').className = 'dot ok';
  document.getElementById('dot-sirens').className = 'dot ok';

  // 1. Charger données initiales
  const [events, sirens, citizens] = await Promise.all([
    API.getSeismicEvents(),
    API.getSirensStatus(),
    API.getCitizenPositions()
  ]);

  // 2. Remplir le store
  Store.updateEvents(events);
  Store.updateSirens(sirens);
  Store.updateCitizens(citizens);

  // 3. Rendu initial
  const state = Store.get();
  Dashboard.updateKPIs(state);
  SirenComp.render(sirens);
  AssemblyComp.renderSummaryBars(state.occupancyMap);
  Charts.init();
  Charts.updateFlux(state.fluxHistory);
  Charts.updateMag(events);

  // 4. WebSocket temps réel (Membre 2)
  WS.connect();

  WS.on('citizen_positions', (citizens) => {
    Store.updateCitizens(citizens);
    const s = Store.get();
    Dashboard.updateKPIs(s);
    Charts.updateFlux(s.fluxHistory);
    AssemblyComp.renderSummaryBars(s.occupancyMap);
    if (document.getElementById('view-map').classList.contains('active')) {
      MapComp.updateCitizens(s.citizens, s.routes);
    }
    if (document.getElementById('view-assembly').classList.contains('active')) {
      AssemblyComp.renderCards(s.occupancyMap);
    }
  });

  WS.on('seismic_event', (event) => {
    const existing = Store.get().events;
    Store.updateEvents([event, ...existing]);
    const s = Store.get();
    Dashboard.updateKPIs(s);
    Charts.updateMag(s.events);

    // TRIGGER : si secousse marine > 6.5 → activer toutes les sirènes
    if (event.magnitude >= 6.5 && event.type === 'marine') {
      SirenComp.autoActivate(event.magnitude);
      console.warn(`[ALERTE] Secousse marine M${event.magnitude} — Sirènes activées !`);
    }

    if (document.getElementById('view-map').classList.contains('active')) {
      MapComp.addSeismicMarker(event);
    }
  });

  WS.on('siren_activate', (data) => {
    Store.activateSiren(data.siren_id);
    SirenComp.updateCard(data.siren_id, true);
    Dashboard.updateKPIs(Store.get());
  });

  // 5. Polling backup toutes les 30s
  setInterval(async () => {
    const fresh = await API.getSeismicEvents();
    Store.updateEvents(fresh);
    Charts.updateMag(fresh);
    Dashboard.updateKPIs(Store.get());
  }, 30000);

  console.log('[APP] Prêt.');
}

document.addEventListener('DOMContentLoaded', init);
