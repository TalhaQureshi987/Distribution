const Joi = require("joi");

const messageSchema = Joi.object({
  message: Joi.string().allow("", null),
  messageType: Joi.string().valid("text", "image", "location").default("text"),
  imageUrl: Joi.string().uri().allow(null),
  latitude: Joi.number().min(-90).max(90).allow(null),
  longitude: Joi.number().min(-180).max(180).allow(null),
  replyTo: Joi.string().hex().length(24).allow(null),
});

function validateMessage(payload) {
  return messageSchema.validate(payload);
}

module.exports = { validateMessage };
