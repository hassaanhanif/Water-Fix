const mongoose = require('mongoose');
const dns = require('dns');
const env = require('./env');

try {
  dns.setServers(['8.8.8.8', '1.1.1.1']);
} catch (_) {}

async function connectDB(uri) {
  const targetUri = uri || env.mongoUri;
  if (mongoose.connection.readyState === 1) {
    return mongoose.connection;
  }
  await mongoose.connect(targetUri);
  return mongoose.connection;
}

async function disconnectDB() {
  if (mongoose.connection.readyState !== 0) {
    await mongoose.disconnect();
  }
}

module.exports = { connectDB, disconnectDB };
