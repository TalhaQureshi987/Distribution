const ActivityLog = require('../models/ActivityLog');

async function logActivity({ userId, type, title, details = {}, req }) {
  try {
    await ActivityLog.create({
      userId,
      type,
      title,
      details,
      ip: req?.ip,
      ua: req?.headers?.['user-agent'],
    });
  } catch (e) {
    // swallow to not break main flow
    console.error('Activity log error:', e.message);
  }
}

module.exports = { logActivity };
