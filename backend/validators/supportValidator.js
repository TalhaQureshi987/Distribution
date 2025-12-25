const Joi = require('joi');

const createTicketSchema = Joi.object({
  title: Joi.string().min(5).max(200).required(),
  category: Joi.string().valid('General', 'Payment', 'Account', 'Bug', 'Feature').default('General'),
  priority: Joi.string().valid('Low', 'Medium', 'High', 'Critical').default('Medium'),
  description: Joi.string().min(5).max(4000).required(),
  attachments: Joi.array().items(Joi.object({
    url: Joi.string().uri().optional(),
    name: Joi.string().optional(),
    type: Joi.string().optional(),
    size: Joi.number().optional(),
  })).optional(),
});

const addMessageSchema = Joi.object({
  body: Joi.string().min(1).max(4000).required(),
  attachments: Joi.array().items(Joi.object({
    url: Joi.string().uri().optional(),
    name: Joi.string().optional(),
    type: Joi.string().optional(),
    size: Joi.number().optional(),
  })).optional(),
});

const updateStatusSchema = Joi.object({
  status: Joi.string().valid('open', 'pending', 'closed').required(),
});

function validateCreateTicket(body) { return createTicketSchema.validate(body, { abortEarly: false }); }
function validateAddMessage(body) { return addMessageSchema.validate(body, { abortEarly: false }); }
function validateUpdateStatus(body) { return updateStatusSchema.validate(body, { abortEarly: false }); }

module.exports = { validateCreateTicket, validateAddMessage, validateUpdateStatus };
