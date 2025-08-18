// db.js
const mongoose = require('mongoose');
const { MongoClient, GridFSBucket, ObjectId } = require('mongodb');
require('dotenv').config(); // ensure .env is loaded

let gridfsBucket = null;
let mongoClient = null;

/**
 * Connect mongoose + native MongoClient (GridFS).
 * Accepts optional mongoUri param — if omitted, falls back to process.env.MONGO_URI.
 */
async function connect(mongoUri) {
  const uri = mongoUri || process.env.MONGO_URI;
  if (!uri || typeof uri !== 'string') {
    throw new Error('MONGO_URI is not defined. Please add MONGO_URI to your .env or pass it to connect().');
  }

  // connect mongoose (for models)
  await mongoose.connect(uri, { useNewUrlParser: true, useUnifiedTopology: true });

  // native MongoClient for GridFS
  mongoClient = await MongoClient.connect(uri, { useNewUrlParser: true, useUnifiedTopology: true });
  const db = mongoClient.db(); // default DB from connection string
  gridfsBucket = new GridFSBucket(db, { bucketName: 'uploads' });
  console.log('Connected to MongoDB & GridFS ready');
}

function getBucket() {
  if (!gridfsBucket) throw new Error('GridFSBucket not initialized. Call connect() first.');
  return gridfsBucket;
}

module.exports = {
  connect,
  getBucket,
  ObjectId
};
