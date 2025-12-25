const express = require('express');
const router = express.Router();
const { protect } = require('../middleware/authMiddleware');
const { createTicket, listMyTickets, getTicket, addMessage, updateStatus, adminListTickets } = require('../controllers/supportController');

router.post('/', protect, createTicket);
router.get('/my', protect, listMyTickets);
router.get('/:id', protect, getTicket);
router.post('/:id/messages', protect, addMessage);
router.patch('/:id/status', protect, updateStatus);
router.get('/', protect, adminListTickets);

module.exports = router;
