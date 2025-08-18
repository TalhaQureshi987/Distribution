const { createClient } = require('redis');
const dotenv = require('dotenv');
dotenv.config();

const redisUrl = process.env.REDIS_URL || 'redis://localhost:6379';
const client = createClient({ url: redisUrl });

client.on('error', (err) => {
    console.log("Redis Error", err);
});

async function connectRedis() {
    if (!client.isOpen) { // latest redis uses isOpen
        await client.connect();
    }
}

module.exports = { client, connectRedis };
