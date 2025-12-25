const SupportTicket = require('../models/SupportTicket');
const { validateCreateTicket, validateAddMessage, validateUpdateStatus } = require('../validators/supportValidator');

// POST /api/support
async function createTicket(req, res) {
  const { error, value } = validateCreateTicket(req.body);
  if (error) return res.status(400).json({ message: error.details[0].message });
  const { title, category, priority, description, attachments = [] } = value;

  const ticket = new SupportTicket({
    userId: req.user.id,
    title,
    category,
    priority,
    status: 'open',
    messages: [{ senderId: req.user.id, senderRole: req.user.role === 'admin' ? 'admin' : 'user', body: description, attachments }],
    attachments,
  });

  const saved = await ticket.save();
  res.status(201).json({ message: 'Ticket created', ticket: saved });
}

// GET /api/support/my
async function listMyTickets(req, res) {
  const tickets = await SupportTicket.find({ userId: req.user.id }).sort({ updatedAt: -1 });
  res.json({ tickets });
}

// GET /api/support/:id
async function getTicket(req, res) {
  const ticket = await SupportTicket.findById(req.params.id).populate('userId', 'name email');
  if (!ticket) return res.status(404).json({ message: 'Ticket not found' });
  if (ticket.userId._id.toString() !== req.user.id && req.user.role !== 'admin') return res.status(403).json({ message: 'Not authorized' });
  res.json({ ticket });
}

// POST /api/support/:id/messages
async function addMessage(req, res) {
  const { error, value } = validateAddMessage(req.body);
  if (error) return res.status(400).json({ message: error.details[0].message });
  const ticket = await SupportTicket.findById(req.params.id);
  if (!ticket) return res.status(404).json({ message: 'Ticket not found' });
  if (ticket.userId.toString() !== req.user.id && req.user.role !== 'admin') return res.status(403).json({ message: 'Not authorized' });

  ticket.messages.push({ senderId: req.user.id, senderRole: req.user.role === 'admin' ? 'admin' : 'user', body: value.body, attachments: value.attachments || [] });
  ticket.updatedAt = new Date();
  await ticket.save();
  res.json({ message: 'Message added', ticket });
}

// PATCH /api/support/:id/status
async function updateStatus(req, res) {
  const { error, value } = validateUpdateStatus(req.body);
  if (error) return res.status(400).json({ message: error.details[0].message });
  const ticket = await SupportTicket.findById(req.params.id);
  if (!ticket) return res.status(404).json({ message: 'Ticket not found' });
  if (ticket.userId.toString() !== req.user.id && req.user.role !== 'admin') return res.status(403).json({ message: 'Not authorized' });

  ticket.status = value.status;
  ticket.updatedAt = new Date();
  await ticket.save();
  res.json({ message: 'Status updated', ticket });
}

// GET /api/support (admin)
async function adminListTickets(req, res) {
  if (req.user.role !== 'admin') return res.status(403).json({ message: 'Not authorized' });
  const { status, category, priority, page = 1, limit = 20 } = req.query;
  const filter = {};
  if (status) filter.status = status;
  if (category) filter.category = category;
  if (priority) filter.priority = priority;

  const skip = (parseInt(page, 10) - 1) * parseInt(limit, 10);
  const [tickets, total] = await Promise.all([
    SupportTicket.find(filter).sort({ updatedAt: -1 }).skip(skip).limit(parseInt(limit, 10)),
    SupportTicket.countDocuments(filter)
  ]);
  res.json({ tickets, pagination: { currentPage: parseInt(page, 10), totalPages: Math.ceil(total / parseInt(limit, 10)), totalItems: total, itemsPerPage: parseInt(limit, 10) } });
}

module.exports = { createTicket, listMyTickets, getTicket, addMessage, updateStatus, adminListTickets };
