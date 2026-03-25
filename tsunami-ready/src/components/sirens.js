/**
 * sirens.js — Gestion du réseau de sirènes virtuelles
 * Trigger : activation automatique si secousse marine > 6.5
 */
const SirenComp = (() => {

  function render(sirens) {
    const grid = document.getElementById('siren-grid');
    if (!grid) return;
    grid.innerHTML = sirens.map(s => `
      <div class="siren-card ${s.active?'active':''}" id="sc-${s.id}" onclick="SirenComp.toggle('${s.id}')">
        <div class="si-icon">${s.active?'🔴':'📢'}</div>
        <div class="si-name">${s.name}</div>
        <div class="si-zone">${s.zone}</div>
        <div class="si-status">${s.active?'⚠ ACTIVE — ALERTE':'En veille'}</div>
        <div class="si-elev">Altitude: ${s.altitude_m}m</div>
      </div>
    `).join('');
  }

  function updateCard(id, active) {
    const card = document.getElementById(`sc-${id}`);
    if (!card) return;
    card.className = `siren-card ${active?'active':''}`;
    card.querySelector('.si-icon').textContent = active ? '🔴' : '📢';
    card.querySelector('.si-status').textContent = active ? '⚠ ACTIVE — ALERTE' : 'En veille';
  }

  // Activation automatique (trigger séisme > 6.5)
  function autoActivate(mag) {
    if (mag < 6.5) return;
    const sirens = Store.get().sirens;
    sirens.forEach(s => {
      Store.activateSiren(s.id);
      updateCard(s.id, true);
    });
    // Bandeau alerte
    const banner = document.getElementById('tsunami-banner');
    const magEl = document.getElementById('banner-mag');
    if (banner) banner.classList.remove('hidden');
    if (magEl) magEl.textContent = `M${mag.toFixed(1)}`;
    // KPI
    const kEl = document.getElementById('kpi-sirens');
    if (kEl) kEl.textContent = sirens.length;
  }

  function toggle(id) {
    const s = Store.get().sirens.find(x=>x.id===id);
    if (!s) return;
    const next = !s.active;
    if (next) Store.activateSiren(id);
    else {
      const updated = Store.get().sirens.map(x=>x.id===id?{...x,active:false}:x);
      Store.updateSirens(updated);
    }
    updateCard(id, next);
    const kEl = document.getElementById('kpi-sirens');
    if (kEl) kEl.textContent = Store.get().activeSirens;
  }

  function testAll() {
    Store.get().sirens.forEach(s => {
      Store.activateSiren(s.id);
      updateCard(s.id, true);
    });
    const kEl = document.getElementById('kpi-sirens');
    if (kEl) kEl.textContent = Store.get().sirens.length;
  }

  function resetAll() {
    const reset = Store.get().sirens.map(s=>({...s,active:false}));
    Store.updateSirens(reset);
    reset.forEach(s => updateCard(s.id, false));
    const banner = document.getElementById('tsunami-banner');
    if (banner) banner.classList.add('hidden');
    const kEl = document.getElementById('kpi-sirens');
    if (kEl) kEl.textContent = 0;
  }

  return { render, updateCard, autoActivate, toggle, testAll, resetAll };
})();
