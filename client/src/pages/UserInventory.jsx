import React, { useState, useMemo } from 'react';
import { motion } from 'framer-motion';

const demoItems = Array.from({ length: 18 }).map((_, i) => ({
  id: `item-${i + 1}`,
  name: [
    'Explorer Badge',
    'Streak Booster', 
    'VIP Pass',
    'Weather Shield',
    'Speed Ticket',
    'Double Points'
  ][i % 6],
  rarity: ['common', 'rare', 'epic'][i % 3],
  acquiredAt: Date.now() - i * 86400000,
}));

const rarityToClass = {
  common: 'bg-gray-500/20 text-gray-300 border-gray-500/30',
  rare: 'bg-blue-500/20 text-blue-300 border-blue-500/30',
  epic: 'bg-purple-500/20 text-purple-300 border-purple-500/30',
};

const UserInventory = () => {
  const [query, setQuery] = useState('');
  const [rarity, setRarity] = useState('all');
  const [sort, setSort] = useState('recent');

  const items = useMemo(() => {
    let list = demoItems;
    if (query.trim()) {
      const q = query.toLowerCase();
      list = list.filter((i) => i.name.toLowerCase().includes(q));
    }
    if (rarity !== 'all') {
      list = list.filter((i) => i.rarity === rarity);
    }
    if (sort === 'recent') {
      list = [...list].sort((a, b) => b.acquiredAt - a.acquiredAt);
    } else if (sort === 'oldest') {
      list = [...list].sort((a, b) => a.acquiredAt - b.acquiredAt);
    } else if (sort === 'alpha') {
      list = [...list].sort((a, b) => a.name.localeCompare(b.name));
    }
    return list;
  }, [query, rarity, sort]);

  return (
    <div className="min-h-screen bg-gray-900 p-6">
      <div className="site-container">
        <motion.div 
          initial={{ opacity: 0, y: 20 }} 
          animate={{ opacity: 1, y: 0 }} 
          className="mb-6"
        >
          <div className="card-hero text-center">
            <h1 className="text-4xl font-bold text-white mb-2">Your Inventory 🎒</h1>
            <p className="text-gray-300">Manage boosters, badges, and unique items</p>
          </div>
        </motion.div>

        <motion.div 
          initial={{ opacity: 0, y: 20 }} 
          animate={{ opacity: 1, y: 0 }} 
          transition={{ delay: 0.1 }} 
          className="card-modern mb-6"
        >
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4">
            <div>
              <input
                type="text"
                value={query}
                onChange={(e) => setQuery(e.target.value)}
                placeholder="Search items..."
                className="input-modern"
              />
            </div>
            <div>
              <select 
                value={rarity} 
                onChange={(e) => setRarity(e.target.value)} 
                className="input-modern"
              >
                <option value="all">All rarities</option>
                <option value="common">Common</option>
                <option value="rare">Rare</option>
                <option value="epic">Epic</option>
              </select>
            </div>
            <div>
              <select 
                value={sort} 
                onChange={(e) => setSort(e.target.value)} 
                className="input-modern"
              >
                <option value="recent">Most recent</option>
                <option value="oldest">Oldest first</option>
                <option value="alpha">Alphabetical</option>
              </select>
            </div>
          </div>
        </motion.div>

        {items.length === 0 ? (
          <div className="text-center py-12">
            <div className="text-6xl mb-4">📦</div>
            <h3 className="text-xl font-semibold text-white mb-2">No items found</h3>
            <p className="text-gray-400">
              {query || rarity !== 'all' 
                ? 'Try adjusting your filters or search terms'
                : 'Start building your collection!'
              }
            </p>
          </div>
        ) : (
          <div className="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-6">
            {items.map((item, i) => (
              <motion.div 
                key={item.id} 
                initial={{ opacity: 0, y: 20 }} 
                animate={{ opacity: 1, y: 0 }} 
                transition={{ delay: 0.02 * i }} 
                className="card-modern lift"
              >
                <div className="flex items-center justify-between mb-4">
                  <div className={`px-3 py-1 rounded-full border text-xs font-bold uppercase ${rarityToClass[item.rarity]}`}>
                    {item.rarity}
                  </div>
                  <div className="text-gray-400 text-sm">
                    {new Date(item.acquiredAt).toLocaleDateString()}
                  </div>
                </div>
                
                <div className="text-center mb-4">
                  <div className="text-4xl mb-2">
                    {item.rarity === 'epic' ? '💎' : item.rarity === 'rare' ? '🔮' : '🎖️'}
                  </div>
                  <div className="text-lg font-bold text-white">{item.name}</div>
                </div>
                
                <div className="flex gap-2">
                  <button className="btn-modern btn-primary flex-1">Use</button>
                  <button className="btn-modern btn-glass flex-1">Details</button>
                </div>
              </motion.div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
};

export default UserInventory;