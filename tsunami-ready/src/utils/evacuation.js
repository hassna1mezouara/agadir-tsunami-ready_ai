/**
 * evacuation.js — Algorithme de calcul des routes d'évacuation
 * Membre 3 — Tâche principale : identifier la route la plus rapide
 * vers un point en hauteur selon la position GPS du citoyen
 *
 * Algorithme : Distance de Haversine + score pondéré
 * (distance, altitude, capacité, risque inondation)
 */

const EvacAlgo = (() => {

  // Points de rassemblement en hauteur autour d'Agadir
  const ASSEMBLY_POINTS = [
    {
      id: 'AP1',
      name: 'Colline Yachts Club',
      altitude_m: 85,
      capacity: 3000,
      lat: 30.430,
      lng: -9.598,
      district: 'Bord de mer Nord',
      facilities: ['Eau potable', 'Premiers secours', 'Générateur']
    },
    {
      id: 'AP2',
      name: 'Plateau Quartier Founty',
      altitude_m: 120,
      capacity: 5000,
      lat: 30.415,
      lng: -9.568,
      district: 'Founty',
      facilities: ['Eau potable', 'Hôpital de campagne', 'Hélipad']
    },
    {
      id: 'AP3',
      name: 'Colline Anza Haute',
      altitude_m: 95,
      capacity: 2500,
      lat: 30.455,
      lng: -9.640,
      district: 'Anza',
      facilities: ['Eau potable', 'Premiers secours']
    },
    {
      id: 'AP4',
      name: 'Zone Industrielle Hauteur',
      altitude_m: 110,
      capacity: 4000,
      lat: 30.395,
      lng: -9.555,
      district: 'Zone Industrielle',
      facilities: ['Premiers secours', 'Générateur', 'Radio']
    },
    {
      id: 'AP5',
      name: 'Université Ibn Zohr Hauteur',
      altitude_m: 140,
      capacity: 8000,
      lat: 30.408,
      lng: -9.547,
      district: 'Hay Mohammadi',
      facilities: ['Eau potable', 'Hôpital de campagne', 'Générateur', 'Hélipad']
    },
    {
      id: 'AP6',
      name: 'Colline Bensergao',
      altitude_m: 75,
      capacity: 2000,
      lat: 30.470,
      lng: -9.613,
      district: 'Bensergao',
      facilities: ['Eau potable', 'Premiers secours']
    }
  ];

  // Zones inondables côtières (polygones simplifiés en cercles)
  const FLOOD_ZONES = [
    { lat: 30.420, lng: -9.610, radius_km: 0.8, risk: 'high' },   // Front de mer
    { lat: 30.430, lng: -9.620, radius_km: 1.0, risk: 'high' },   // Port
    { lat: 30.412, lng: -9.600, radius_km: 0.6, risk: 'medium' }, // Talborjt
    { lat: 30.445, lng: -9.630, radius_km: 0.7, risk: 'high' },   // Anza bord
  ];

  /**
   * Calcule la distance en km entre deux points GPS (formule Haversine)
   */
  function haversine(lat1, lng1, lat2, lng2) {
    const R = 6371;
    const dLat = (lat2 - lat1) * Math.PI / 180;
    const dLng = (lng2 - lng1) * Math.PI / 180;
    const a =
      Math.sin(dLat / 2) ** 2 +
      Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) *
      Math.sin(dLng / 2) ** 2;
    return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  }

  /**
   * Vérifie si un point est dans une zone inondable
   * Retourne le niveau de risque (0 = sûr, 1 = medium, 2 = high)
   */
  function getFloodRisk(lat, lng) {
    let maxRisk = 0;
    for (const zone of FLOOD_ZONES) {
      const d = haversine(lat, lng, zone.lat, zone.lng);
      if (d <= zone.radius_km) {
        const r = zone.risk === 'high' ? 2 : 1;
        if (r > maxRisk) maxRisk = r;
      }
    }
    return maxRisk;
  }

  /**
   * ALGORITHME PRINCIPAL
   * Calcule la meilleure route d'évacuation depuis une position GPS
   * vers le point en hauteur le plus adapté
   *
   * Score = distance_km × 0.5 + (1/altitude_m)×20 + occupation_pct×0.3 + flood_penalty
   * Plus le score est bas, meilleure est la route
   */
  function findBestRoute(citizenLat, citizenLng, occupancyMap = {}) {
    const scoredPoints = ASSEMBLY_POINTS.map(ap => {
      const distance_km = haversine(citizenLat, citizenLng, ap.lat, ap.lng);
      const occupation_pct = (occupancyMap[ap.id] || 0) / ap.capacity * 100;
      const flood_risk = getFloodRisk(citizenLat, citizenLng);

      // Score composite (plus bas = meilleur)
      const score =
        distance_km * 0.5 +          // Distance (poids fort)
        (1 / ap.altitude_m) * 20 +   // Altitude (poids inverse : plus c'est haut, mieux c'est)
        occupation_pct * 0.3 +        // Évite les points saturés
        flood_risk * 2;               // Pénalité si zone de départ risquée

      // Durée estimée: vitesse piéton 4 km/h, +30% si zone inondable
      const speed_kmh = flood_risk > 0 ? 2.5 : 4;
      const duration_min = Math.round((distance_km / speed_kmh) * 60);

      return {
        ...ap,
        distance_km: Math.round(distance_km * 100) / 100,
        score: Math.round(score * 100) / 100,
        duration_min,
        occupation_pct: Math.round(occupation_pct),
        flood_risk
      };
    });

    // Trier par score croissant
    scoredPoints.sort((a, b) => a.score - b.score);
    const best = scoredPoints[0];

    // Générer les waypoints de la route (ligne directe + détour si zone risquée)
    const waypoints = _generateWaypoints(citizenLat, citizenLng, best, best.flood_risk);

    return {
      best,
      alternatives: scoredPoints.slice(1, 3),
      waypoints,
      flood_risk_at_origin: best.flood_risk,
      all: scoredPoints
    };
  }

  /**
   * Génère les waypoints de la route (avec contournement zones inondables)
   */
  function _generateWaypoints(fromLat, fromLng, toPoint, floodRisk) {
    const waypoints = [[fromLat, fromLng]];

    if (floodRisk >= 2) {
      // Ajouter un point de contournement vers l'intérieur des terres
      const midLat = fromLat + (toPoint.lat - fromLat) * 0.3;
      const midLng = fromLng + 0.015; // Décalage vers l'intérieur
      waypoints.push([midLat, midLng]);
    }

    // Midpoint normal
    waypoints.push([
      (fromLat + toPoint.lat) / 2,
      (fromLng + toPoint.lng) / 2
    ]);

    waypoints.push([toPoint.lat, toPoint.lng]);
    return waypoints;
  }

  /**
   * Calcule le temps d'évacuation estimé pour toute une population
   */
  function estimateMassEvacuation(citizens) {
    const occupancyMap = {};
    const routes = citizens.map(c => {
      const result = findBestRoute(c.latitude, c.longitude, occupancyMap);
      // Incrémenter l'occupation
      if (!occupancyMap[result.best.id]) occupancyMap[result.best.id] = 0;
      occupancyMap[result.best.id]++;
      return { citizen: c, route: result };
    });
    return routes;
  }

  return {
    ASSEMBLY_POINTS,
    FLOOD_ZONES,
    findBestRoute,
    estimateMassEvacuation,
    haversine,
    getFloodRisk
  };
})();
