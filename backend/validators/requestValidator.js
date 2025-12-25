const Joi = require("joi");

const requestSchema = Joi.object({
  title: Joi.string().min(3).max(120).required(),
  description: Joi.string().min(10).max(2000).required(),
  foodType: Joi.string().min(2).max(60).required(),
  quantity: Joi.number().integer().min(1).required(),
  quantityUnit: Joi.string().min(1).max(20).required(),
  neededBy: Joi.date().iso().required(),

  // Delivery option controls whether map fields are required
  deliveryOption: Joi.string()
    .valid("Self delivery", "Volunteer Delivery", "Paid Delivery")
    .default("Self delivery")
    .required(),

  // Pickup address is now always required for all requests
  pickupAddress: Joi.string().min(5).max(200).required(),

  latitude: Joi.alternatives().conditional("deliveryOption", {
    is: Joi.valid("Volunteer Delivery", "Paid Delivery"),
    then: Joi.number().min(-90).max(90).required(),
    otherwise: Joi.number().min(-90).max(90).allow(null).optional(),
  }),

  longitude: Joi.alternatives().conditional("deliveryOption", {
    is: Joi.valid("Volunteer Delivery", "Paid Delivery"),
    then: Joi.number().min(-180).max(180).required(),
    otherwise: Joi.number().min(-180).max(180).allow(null).optional(),
  }),

  notes: Joi.string().allow("", null),
  isUrgent: Joi.boolean().optional(),

  // Allow strings for images (URLs or local file paths produced by Flutter)
  images: Joi.array().items(Joi.string()).optional(),

  // Optional fields used by payment calculation/validation
  distance: Joi.number().min(0).max(1000).optional(),
  paymentAmount: Joi.number().min(0).optional(),
  paymentStatus: Joi.string().valid('completed', 'pending').optional(),
  stripePaymentIntentId: Joi.string().allow('', null).optional(),
});

function validateRequest(payload) {
  // return all errors at once
  return requestSchema.validate(payload, { abortEarly: false });
}

module.exports = { validateRequest };
