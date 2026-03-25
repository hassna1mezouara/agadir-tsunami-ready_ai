/**
 * api.js — Service API REST
 * Connexion avec Membre 1 (base de données sismiques + triggers)
 * Endpoints attendus : GET /api/events, GET /api/sirens/status
 */

const API = (() => {
  // ⚠️ Changer avec l'IP du Membre 1
  const BASE = window.API_BASE || 'http://localhost:3000/api';

  async function _fetch(path) {
    try {
      const res = await fetch(BASE + path);
      if (!res.ok) throw new Error(res.status);
      return await res.json();
    } catch (e) {
      return null; // Fallback sur mock
    }
  }

  async function getSeismicEvents() {
    return await _fetch('/events') || _mockEvents();
  }

  async function getLatestEvent() {
    return await _fetch('/seismic-events/latest') || _mockEvents()[0];
  }

  async function getSirensStatus() {
    return await _fetch('/sirens/status') || _mockSirens();
  }

  async function getCitizenPositions() {
    return await _fetch('/citizens/positions') || _mockCitizens();
  }

  // ---- MOCK DATA ----
  function _mockEvents() {
    const lieux = ['Large Agadir','Large Safi','Cap Ghir','Essaouira','Tarfaya','Tiznit Marine'];
    return Array.from({length: 18}, (_, i) => ({
      id: i+1,
      magnitude: parseFloat((Math.random() * 7.2 + 1.5).toFixed(1)),
      location: lieux[Math.floor(Math.random() * lieux.length)],
      latitude: 29.5 + Math.random() * 2.5,
      longitude: -10.5 + Math.random() * 2,
      depth_km: Math.floor(Math.random() * 60 + 5),
      type: Math.random() > 0.4 ? 'marine' : 'terrestre',
      timestamp: new Date(Date.now() - i * 3800000 * Math.random()).toISOString(),
      alert: false
    })).sort((a,b) => new Date(b.timestamp) - new Date(a.timestamp));
  }

  function _mockSirens() {
    return [
      { id:'S1', name:'Sirène Port Agadir',        zone:'Zone Portuaire',   lat:30.425, lng:-9.621, active:false, altitude_m:5  },
      { id:'S2', name:'Sirène Plage Taghazout',     zone:'Taghazout',        lat:30.543, lng:-9.709, active:false, altitude_m:8  },
      { id:'S3', name:'Sirène Front de Mer',        zone:'Agadir Centre',    lat:30.418, lng:-9.615, active:false, altitude_m:3  },
      { id:'S4', name:'Sirène Anza Beach',          zone:'Anza',             lat:30.455, lng:-9.645, active:false, altitude_m:6  },
      { id:'S5', name:'Sirène Cité Dakhla',         zone:'Cité Dakhla',      lat:30.408, lng:-9.597, active:false, altitude_m:15 },
      { id:'S6', name:'Sirène Hay Mohammadi',       zone:'Hay Mohammadi',    lat:30.412, lng:-9.587, active:false, altitude_m:20 },
      { id:'S7', name:'Sirène Bensergao Côte',      zone:'Bensergao',        lat:30.468, lng:-9.628, active:false, altitude_m:12 },
      { id:'S8', name:'Sirène Quartier Industriel', zone:'Zone Industrielle', lat:30.395, lng:-9.565, active:false, altitude_m:25 }
    ];
  }

  function _mockCitizens() {
    return Array.from({length: 20}, (_, i) => ({
      id: `C${String(i+1).padStart(3,'0')}`,
      latitude:  30.395 + Math.random() * 0.09,
      longitude: -9.645 + Math.random() * 0.07,
      speed_kmh: Math.random() > 0.6 ? Math.round(Math.random() * 5 + 2) : 0,
      last_seen: new Date().toISOString()
    }));
  }

  return { getSeismicEvents, getLatestEvent, getSirensStatus, getCitizenPositions };
})();
