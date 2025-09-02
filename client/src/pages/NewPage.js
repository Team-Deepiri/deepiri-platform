import React from 'react';
import { motion } from 'framer-motion';

const NewPage = () => {
  return (
    <div className="min-h-screen bg-gray-50 flex items-center justify-center">
      <motion.div
        initial={{ opacity: 0, y: 20 }}
        animate={{ opacity: 1, y: 0 }}
        className="text-center"
      >
        <div className="text-6xl mb-4">🚧</div>
        <h1 className="text-3xl font-bold text-gray-900 mb-4">
          Coming Soon
        </h1>
        <p className="text-gray-600 text-lg">
          This page is under construction. Check back later!
        </p>
      </motion.div>
    </div>
  );
};

export default NewPage;