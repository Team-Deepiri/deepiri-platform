import React from 'react';
import { motion } from 'framer-motion';

const Input = ({ 
  label, 
  type = 'text', 
  placeholder, 
  value, 
  onChange, 
  error, 
  disabled = false, 
  required = false,
  className = '',
  ...props 
}) => {
  const baseClasses = 'input-modern';
  const errorClasses = error ? 'border-red-500 focus:border-red-500' : '';
  const disabledClasses = disabled ? 'opacity-50 cursor-not-allowed' : '';

  const classes = `${baseClasses} ${errorClasses} ${disabledClasses} ${className}`;

  return (
    <motion.div
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      className="space-y-1"
    >
      {label && (
        <label className="block text-sm font-medium text-white">
          {label}
          {required && <span className="text-red-400 ml-1">*</span>}
        </label>
      )}
      <input
        type={type}
        placeholder={placeholder}
        value={value}
        onChange={onChange}
        disabled={disabled}
        required={required}
        className={classes}
        aria-invalid={error ? 'true' : 'false'}
        aria-describedby={error ? `${props.id || 'input'}-error` : undefined}
        {...props}
      />
      {error && (
        <motion.p
          initial={{ opacity: 0, y: -10 }}
          animate={{ opacity: 1, y: 0 }}
          className="text-sm text-red-400"
          id={`${props.id || 'input'}-error`}
          role="alert"
        >
          {error}
        </motion.p>
      )}
    </motion.div>
  );
};

export default Input;
