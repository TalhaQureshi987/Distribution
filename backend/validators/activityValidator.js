const Joi = require('joi');

const listActivitySchema = Joi.object({
  type: Joi.string().optional(),
  from: Joi.date().iso().optional(),
  to: Joi.date().iso().optional(),
  page: Joi.number().integer().min(1).default(1),
  limit: Joi.number().integer().min(1).max(100).default(20),
});

function validateListActivity(query) {
  return listActivitySchema.validate(query, { abortEarly: false });
}

module.exports = { validateListActivity };
