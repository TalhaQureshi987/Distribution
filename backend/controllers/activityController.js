const ActivityLog = require('../models/ActivityLog');
const { validateListActivity } = require('../validators/activityValidator');

// GET /api/activity/my
async function listMyActivity(req, res) {
  const { error, value } = validateListActivity(req.query);
  if (error) return res.status(400).json({ message: error.details[0].message });
  const { type, from, to, page, limit } = value;

  const filter = { userId: req.user.id };
  if (type) filter.type = type;
  if (from || to) filter.createdAt = {};
  if (from) filter.createdAt.$gte = new Date(from);
  if (to) filter.createdAt.$lte = new Date(to);

  const skip = (page - 1) * limit;
  const [items, total] = await Promise.all([
    ActivityLog.find(filter).sort({ createdAt: -1 }).skip(skip).limit(limit),
    ActivityLog.countDocuments(filter)
  ]);

  res.json({
    items,
    pagination: { currentPage: page, totalPages: Math.ceil(total / limit), totalItems: total, itemsPerPage: limit }
  });
}

// GET /api/activity (admin)
async function adminListActivity(req, res) {
  if (req.user.role !== 'admin') return res.status(403).json({ message: 'Not authorized' });
  const { error, value } = validateListActivity(req.query);
  if (error) return res.status(400).json({ message: error.details[0].message });
  const { type, from, to, page, limit } = value;

  const filter = {};
  if (type) filter.type = type;
  if (from || to) filter.createdAt = {};
  if (from) filter.createdAt.$gte = new Date(from);
  if (to) filter.createdAt.$lte = new Date(to);

  const skip = (page - 1) * limit;
  const [items, total] = await Promise.all([
    ActivityLog.find(filter).sort({ createdAt: -1 }).skip(skip).limit(limit),
    ActivityLog.countDocuments(filter)
  ]);

  res.json({
    items,
    pagination: { currentPage: page, totalPages: Math.ceil(total / limit), totalItems: total, itemsPerPage: limit }
  });
}



module.exports = { listMyActivity, adminListActivity };
