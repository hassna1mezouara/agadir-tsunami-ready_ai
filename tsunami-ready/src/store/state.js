/**
 * state.js — Store global
 */
const Store = (() => {
  let s = {
    events: [], citizens: [], sirens: [],
    routes: [], occupancyMap: {},
    latestMag: null, activeSirens: 0,
    fluxHistory: Array(14).fill(0),
    magHistory: []
  };
  const subs = [];
  const get = () => s;
  const set = (p) => { s = {...s,...p}; subs.forEach(f=>f(s)); };
  const sub = (f) => subs.push(f);

  function updateCitizens(citizens) {
    // Calcule les routes d'évacuation pour chaque citoyen
    const routes = EvacAlgo.estimateMassEvacuation(citizens);
    const occupancyMap = {};
    routes.forEach(r => {
      if (!occupancyMap[r.route.best.id]) occupancyMap[r.route.best.id] = 0;
      occupancyMap[r.route.best.id]++;
    });
    set({
      citizens,
      routes,
      occupancyMap,
      fluxHistory: [...s.fluxHistory.slice(1), citizens.length]
    });
  }

  function updateEvents(events) {
    const sorted = [...events].sort((a,b) => b.magnitude - a.magnitude);
    set({
      events: sorted,
      latestMag: sorted[0]?.magnitude || null,
      magHistory: events.slice(0,10).map(e=>e.magnitude).reverse()
    });
  }

  function updateSirens(sirens) {
    set({ sirens, activeSirens: sirens.filter(s=>s.active).length });
  }

  function activateSiren(id) {
    const updated = s.sirens.map(si => si.id===id ? {...si,active:true} : si);
    set({ sirens: updated, activeSirens: updated.filter(si=>si.active).length });
  }

  return { get, set, sub, updateCitizens, updateEvents, updateSirens, activateSiren };
})();
