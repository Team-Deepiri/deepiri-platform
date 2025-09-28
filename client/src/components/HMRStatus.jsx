import React, { useState, useEffect } from 'react';
import { motion } from 'framer-motion';

const HMRStatus = () => {
  const [lastUpdate, setLastUpdate] = useState(new Date());
  const [updateCount, setUpdateCount] = useState(0);

  // Update counter when component re-renders due to HMR
  useEffect(() => {
    setLastUpdate(new Date());
    setUpdateCount(prev => prev + 1);
  }, []);

  if (process.env.NODE_ENV !== 'development') {
    return null; // Don't show in production
  }

  return (
    <motion.div
      initial={{ opacity: 0, scale: 0.8 }}
      animate={{ opacity: 1, scale: 1 }}
      className="fixed bottom-4 right-4 z-50"
    >
      <div className="bg-green-500/90 backdrop-blur-sm text-white px-4 py-2 rounded-lg shadow-lg text-sm">
        <div className="flex items-center gap-2">
          <div className="w-2 h-2 bg-green-300 rounded-full animate-pulse"></div>
          {/* <span className="font-medium">🔥 HMR TURBO Active</span> */}
        </div>
        <div className="text-xs opacity-80">
          {/* Updates: {updateCount} | {lastUpdate.toLocaleTimeString()} */}
        </div>
      </div>
    </motion.div>
  );
};

export default HMRStatus;
