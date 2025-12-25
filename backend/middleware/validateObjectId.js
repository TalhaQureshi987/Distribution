// backend/middleware/validateObjectId.js
const mongoose = require('mongoose');

module.exports = function validateObjectId(paramName) {
  return function (req, res, next) {
    try {
      const id = req.params[paramName];
      if (!id || String(id).trim() === '') {
        return res.status(400).json({ message: `${paramName} is required` });
      }
      if (!mongoose.Types.ObjectId.isValid(String(id))) {
        return res.status(400).json({ message: `Invalid ${paramName}` });
      }
      next();
    } catch (err) {
      console.error('validateObjectId middleware error:', err);
      return res.status(500).json({ message: 'Server error in validation' });
    }
  };
};
