// validators/chatValidator.js
const Joi = require("joi");
const config = require('../config/environment');

// ObjectId validation
const objectId = Joi.string().hex().length(24);

// Room creation validation
const roomSchema = Joi.object({
  otherUserId: objectId.required(),
  otherUserName: Joi.string().trim().min(1).max(100).required(),
  donationId: objectId.optional(),
  requestId: objectId.optional(),
}).unknown(false);

// Message validation with environment-based limits
const messageSchema = Joi.object({
  messageType: Joi.string().valid("text", "image", "location").default("text"),
  
  // Text messages must have non-empty message within configured limits
  message: Joi.alternatives().conditional("messageType", {
    is: "text",
    then: Joi.string().trim().min(1).max(config.chat.maxMessageLength).required(),
    otherwise: Joi.string().allow("", null).default(""),
  }),
  
  // Image requires valid imageUrl
  imageUrl: Joi.alternatives().conditional("messageType", {
    is: "image",
    then: Joi.string().uri().required(),
    otherwise: Joi.any().strip(),
  }),
  
  // Location requires valid coordinates
  latitude: Joi.alternatives().conditional("messageType", {
    is: "location",
    then: Joi.number().min(-90).max(90).required(),
    otherwise: Joi.any().strip(),
  }),
  longitude: Joi.alternatives().conditional("messageType", {
    is: "location",
    then: Joi.number().min(-180).max(180).required(),
    otherwise: Joi.any().strip(),
  }),
  
  replyTo: objectId.optional(),
}).unknown(false);

// Pagination validation
const paginationSchema = Joi.object({
  page: Joi.number().integer().min(1).default(1),
  limit: Joi.number().integer().min(1).max(100).default(20),
}).unknown(false);

// Room ID validation
const roomIdSchema = Joi.object({
  roomId: objectId.required(),
}).unknown(false);

// Message ID validation
const messageIdSchema = Joi.object({
  messageId: objectId.required(),
}).unknown(false);

// Search validation
const searchSchema = Joi.object({
  query: Joi.string().trim().min(1).max(100).required(),
  roomId: objectId.optional(),
}).unknown(false);

// Validation functions
function validateRoom(payload) {
  return roomSchema.validate(payload, { abortEarly: false, stripUnknown: true });
}

function validateMessage(payload) {
  return messageSchema.validate(payload, { abortEarly: false, stripUnknown: true });
}

function validatePagination(payload) {
  return paginationSchema.validate(payload, { abortEarly: false, stripUnknown: true });
}

function validateRoomId(payload) {
  return roomIdSchema.validate(payload, { abortEarly: false, stripUnknown: true });
}

function validateMessageId(payload) {
  return messageIdSchema.validate(payload, { abortEarly: false, stripUnknown: true });
}

function validateSearch(payload) {
  return searchSchema.validate(payload, { abortEarly: false, stripUnknown: true });
}

module.exports = {
  validateRoom,
  validateMessage,
  validatePagination,
  validateRoomId,
  validateMessageId,
  validateSearch,
  objectId
};