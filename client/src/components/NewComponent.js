import React from 'react';
import { motion } from 'framer-motion';

const NewComponent = () => {
  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      className="card-modern"
    >
      <h2 className="text-2xl font-bold text-white mb-4">
        New Component 🆕
      </h2>
      <p className="text-gray-300">
        This is a placeholder component. You can customize it as needed.
      </p>
    </motion.div>
  );
};

export default NewComponent;