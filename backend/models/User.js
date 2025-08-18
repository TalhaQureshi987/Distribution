// models/User.js
const mongoose = require('mongoose');
const bcrypt = require('bcrypt');

const phoneRegex = /^\+?\d{7,15}$/; // allows optional + and 7-15 digits

const UserSchema = new mongoose.Schema({
  name: { type: String, required: true, trim: true },
  email: { type: String, required: true, unique: true, lowercase: true, trim: true },
  password: { type: String, required: true },
  number: { 
    type: String, 
    trim: true, 
    validate: {
      validator: function(v) {
        if (!v) return true; // allow empty/undefined (optional). Remove this line to make required.
        return phoneRegex.test(v);
      },
      message: props => `${props.value} is not a valid phone number!`
    },
    unique: true,
    sparse: true // allows multiple docs without number (so unique doesn't block nulls)
  },
  role: { type: String, enum: ['user', 'admin'], default: 'user' },
  createdAt: { type: Date, default: Date.now }
});

// Hash password before save
UserSchema.pre('save', async function(next) {
  if (!this.isModified('password')) return next();
  try {
    const salt = await bcrypt.genSalt(10);
    this.password = await bcrypt.hash(this.password, salt);
    next();
  } catch (err) {
    next(err);
  }
});

UserSchema.methods.comparePassword = function(plain) {
  return bcrypt.compare(plain, this.password);
};

module.exports = mongoose.model('User', UserSchema);
