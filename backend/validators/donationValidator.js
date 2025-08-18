const Joi = require("joi");

const donationSchema = Joi.object({
  title: Joi.string().min(3).max(120).required() .custom((value, helpers) => {
    if (!value || value.trim().length === 0) {
      return helpers.error('string.empty');
    }
    return value.trim();
  })
  .messages({
    'string.empty': 'Description cannot be empty or just whitespace',
    'any.required': 'Description is required',
    'string.min': 'Description must be at least 10 characters',
    'string.max': 'Description cannot exceed 2000 characters'
  }),
  description: Joi.string().min(10).max(2000).required(),
  foodType: Joi.string().min(2).max(60).required(),
  quantity: Joi.number().integer().min(1).required(),
  quantityUnit: Joi.string().min(1).max(20).required(),
  expiryDate: Joi.date().iso().required(),
  pickupAddress: Joi.string().min(5).max(200).required(),
  latitude: Joi.number().min(-90).max(90).required(),
  longitude: Joi.number().min(-180).max(180).required(),
  notes: Joi.string().allow("", null),
  isUrgent: Joi.boolean().optional(),
  images: Joi.array().items(Joi.string().uri()).optional(),
});

function validateDonation(payload) {
  return donationSchema.validate(payload);
}

module.exports = { validateDonation:(data) => donationSchema.validate(data) };
