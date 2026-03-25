/**
 * websocket.js — Temps réel GPS citoyens + alertes séismes
 * Connexion avec Membre 2 (Position GPS + Notifications)
 */

const WS = (() => {
  const WS_URL = window.WS_URL || 'ws://localhost:3001';
  let socket = null;
  let listeners = {};
  let mockTimer = null;

  function connect() {
    try {
      socket = new WebSocket(WS_URL);
      socket.onopen = () => {
        _setDot('dot-ws', 'ok');
        _stopMock();
        console.log('[WS] Connecté');
      };
      socket.onmessage = (e) => {
        try { const d = JSON.parse(e.data); _emit(d.type, d.payload); }
        catch(err) {}
      };
      socket.onclose = () => {
        _setDot('dot-ws', 'err');
        _startMock();
        setTimeout(connect, 6000);
      };
      socket.onerror = () => socket.close();
    } catch(e) {
      _setDot('dot-ws', 'err');
      _startMock();
      setTimeout(connect, 10000);
    }
  }

  function on(type, cb) {
    if (!listeners[type]) listeners[type] = [];
    listeners[type].push(cb);
  }

  function _emit(type, payload) {
    (listeners[type] || []).forEach(cb => cb(payload));
  }

  function _setDot(id, cls) {
    const el = document.getElementById(id);
    if (el) el.className = `dot ${cls}`;
  }

  function _startMock() {
    if (mockTimer) return;
    mockTimer = setInterval(() => {
      // Positions GPS citoyens
      const citizens = Array.from({length: 12 + Math.floor(Math.random()*8)}, (_, i) => ({
        id: `C${String(i+1).padStart(3,'0')}`,
        latitude:  30.395 + Math.random() * 0.09,
        longitude: -9.645 + Math.random() * 0.07,
        speed_kmh: Math.random() > 0.5 ? Math.round(Math.random() * 4 + 1) : 0,
        last_seen: new Date().toISOString()
      }));
      _emit('citizen_positions', citizens);

      // Séisme aléatoire
      if (Math.random() < 0.12) {
        const mag = parseFloat((Math.random() * 6.5 + 1.8).toFixed(1));
        _emit('seismic_event', {
          id: Date.now(),
          magnitude: mag,
          location: ['Large Agadir', 'Cap Ghir', 'Fond marin Souss'][Math.floor(Math.random()*3)],
          latitude: 29.8 + Math.random() * 1.5,
          longitude: -10.2 + Math.random() * 1.5,
          type: 'marine',
          timestamp: new Date().toISOString(),
          alert: mag >= 6.5
        });
      }

      // Activation sirène aléatoire
      if (Math.random() < 0.04) {
        _emit('siren_activate', { siren_id: `S${Math.ceil(Math.random()*8)}`, active: true });
      }
    }, 3000);
  }

  function _stopMock() {
    clearInterval(mockTimer);
    mockTimer = null;
  }

  return { connect, on };
})();
