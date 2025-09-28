import React, { useEffect, useState } from 'react';
import { motion } from 'framer-motion';
import { pythonApi } from '../api/pythonApi';

const PythonTools = () => {
  const [coords, setCoords] = useState({ latitude: '', longitude: '' });
  const [weather, setWeather] = useState(null);
  const [directionsForm, setDirectionsForm] = useState({ origin: '', destination: '', mode: 'driving' });
  const [directions, setDirections] = useState(null);
  const [adventureForm, setAdventureForm] = useState({ latitude: '', longitude: '', radius: 5000, interests: '' });
  const [adventureData, setAdventureData] = useState(null);
  const [loading, setLoading] = useState({ weather: false, directions: false, adventure: false });

  useEffect(() => {
    if (navigator.geolocation) {
      navigator.geolocation.getCurrentPosition((pos) => {
        setCoords({ latitude: pos.coords.latitude.toFixed(6), longitude: pos.coords.longitude.toFixed(6) });
        setAdventureForm((p) => ({ ...p, latitude: pos.coords.latitude.toFixed(6), longitude: pos.coords.longitude.toFixed(6) }));
      });
    }
  }, []);

  const fetchWeather = async () => {
    setLoading((p) => ({ ...p, weather: true }));
    const res = await pythonApi.getWeather({ latitude: coords.latitude, longitude: coords.longitude });
    if (res.success) setWeather(res.data);
    setLoading((p) => ({ ...p, weather: false }));
  };

  const fetchDirections = async () => {
    setLoading((p) => ({ ...p, directions: true }));
    const res = await pythonApi.getDirections(directionsForm);
    if (res.success) setDirections(res.data);
    setLoading((p) => ({ ...p, directions: false }));
  };

  const fetchAdventure = async () => {
    setLoading((p) => ({ ...p, adventure: true }));
    const res = await pythonApi.getAdventureData({
      latitude: adventureForm.latitude,
      longitude: adventureForm.longitude,
      radius: adventureForm.radius,
      interests: adventureForm.interests.split(',').map((s) => s.trim()).filter(Boolean)
    });
    if (res.success) setAdventureData(res.data);
    setLoading((p) => ({ ...p, adventure: false }));
  };

  return (
    <div className="min-h-screen">
      <div className="max-w-6xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
        <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} className="mb-8">
          <div className="rounded-xl p-8 text-white bg-gradient-to-r from-purple-600 to-emerald-500">
            <h1 className="text-3xl font-bold mb-2">Python Tools 🐍</h1>
            <p className="opacity-90">Weather, Directions, and Adventure insights via the Python service.</p>
          </div>
        </motion.div>

        <div className="grid lg:grid-cols-3 gap-8">
          {/* Weather */}
          <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.1 }} className="bg-white rounded-xl shadow-lg p-6">
            <h2 className="text-xl font-bold text-gray-900 mb-4">Weather ⛅</h2>
            <div className="space-y-3">
              <input value={coords.latitude} onChange={(e) => setCoords((p) => ({ ...p, latitude: e.target.value }))} placeholder="Latitude" className="w-full p-3 border border-gray-200 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-transparent" />
              <input value={coords.longitude} onChange={(e) => setCoords((p) => ({ ...p, longitude: e.target.value }))} placeholder="Longitude" className="w-full p-3 border border-gray-200 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-transparent" />
              <button onClick={fetchWeather} disabled={loading.weather} className="w-full py-2 btn-modern btn-primary">{loading.weather ? 'Loading…' : 'Get Weather'}</button>
            </div>
            {weather && (
              <div className="mt-4 p-4 rounded-lg bg-purple-50 border border-purple-200">
                <pre className="text-xs whitespace-pre-wrap text-gray-800">{JSON.stringify(weather, null, 2)}</pre>
              </div>
            )}
          </motion.div>

          {/* Directions */}
          <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.2 }} className="bg-white rounded-xl shadow-lg p-6">
            <h2 className="text-xl font-bold text-gray-900 mb-4">Directions 🧭</h2>
            <div className="space-y-3">
              <input value={directionsForm.origin} onChange={(e) => setDirectionsForm((p) => ({ ...p, origin: e.target.value }))} placeholder="Origin (address or 'lat,lng')" className="w-full p-3 border border-gray-200 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-transparent" />
              <input value={directionsForm.destination} onChange={(e) => setDirectionsForm((p) => ({ ...p, destination: e.target.value }))} placeholder="Destination (address or 'lat,lng')" className="w-full p-3 border border-gray-200 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-transparent" />
              <select value={directionsForm.mode} onChange={(e) => setDirectionsForm((p) => ({ ...p, mode: e.target.value }))} className="w-full p-3 border border-gray-200 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-transparent">
                <option value="driving">Driving</option>
                <option value="walking">Walking</option>
                <option value="bicycling">Bicycling</option>
                <option value="transit">Transit</option>
              </select>
              <button onClick={fetchDirections} disabled={loading.directions} className="w-full py-2 btn-modern btn-secondary">{loading.directions ? 'Loading…' : 'Get Directions'}</button>
            </div>
            {directions && (
              <div className="mt-4 p-4 rounded-lg bg-emerald-50 border border-emerald-200">
                <pre className="text-xs whitespace-pre-wrap text-gray-800">{JSON.stringify(directions, null, 2)}</pre>
              </div>
            )}
          </motion.div>

          {/* Adventure Data */}
          <motion.div initial={{ opacity: 0, y: 20 }} animate={{ opacity: 1, y: 0 }} transition={{ delay: 0.3 }} className="bg-white rounded-xl shadow-lg p-6">
            <h2 className="text-xl font-bold text-gray-900 mb-4">Adventure Data 🗺️</h2>
            <div className="space-y-3">
              <input value={adventureForm.latitude} onChange={(e) => setAdventureForm((p) => ({ ...p, latitude: e.target.value }))} placeholder="Latitude" className="w-full p-3 border border-gray-200 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-transparent" />
              <input value={adventureForm.longitude} onChange={(e) => setAdventureForm((p) => ({ ...p, longitude: e.target.value }))} placeholder="Longitude" className="w-full p-3 border border-gray-200 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-transparent" />
              <input type="number" value={adventureForm.radius} onChange={(e) => setAdventureForm((p) => ({ ...p, radius: Number(e.target.value) }))} placeholder="Radius (meters)" className="w-full p-3 border border-gray-200 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-transparent" />
              <input value={adventureForm.interests} onChange={(e) => setAdventureForm((p) => ({ ...p, interests: e.target.value }))} placeholder="Interests (comma-separated)" className="w-full p-3 border border-gray-200 rounded-lg focus:ring-2 focus:ring-purple-500 focus:border-transparent" />
              <button onClick={fetchAdventure} disabled={loading.adventure} className="w-full py-2 btn-modern btn-primary">{loading.adventure ? 'Loading…' : 'Get Adventure Data'}</button>
            </div>
            {adventureData && (
              <div className="mt-4 p-4 rounded-lg bg-purple-50 border border-purple-200">
                <pre className="text-xs whitespace-pre-wrap text-gray-800">{JSON.stringify(adventureData, null, 2)}</pre>
              </div>
            )}
          </motion.div>
        </div>
      </div>
    </div>
  );
};

export default PythonTools;


