const express = require('express');
const router = express.Router();
const { protect } = require('../middleware/authMiddleware');
const { listMyActivity, adminListActivity } = require('../controllers/activityController');

router.get('/my', protect, listMyActivity);
router.get('/', protect, adminListActivity);

module.exports = router;
