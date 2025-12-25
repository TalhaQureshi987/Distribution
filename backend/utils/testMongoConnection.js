/**
 * MongoDB Connection Diagnostic Tool
 * 
 * This script helps diagnose MongoDB Atlas connection issues,
 * particularly DNS resolution problems on Windows.
 */

const dns = require('dns').promises;
const mongoose = require('mongoose');
require('dotenv').config();

const MONGO_URI = process.env.MONGO_URI;

if (!MONGO_URI) {
  console.error('❌ MONGO_URI not found in environment variables');
  process.exit(1);
}

// Extract hostname from MongoDB URI
const extractHostname = (uri) => {
  const match = uri.match(/mongodb\+srv:\/\/(?:[^:]+:[^@]+@)?([^/]+)/);
  return match ? match[1] : null;
};

const hostname = extractHostname(MONGO_URI);

console.log('🔍 MongoDB Connection Diagnostics\n');
console.log('Connection String:', MONGO_URI.replace(/\/\/.*@/, '//***:***@'));
console.log('Hostname:', hostname || 'Could not extract');
console.log('');

// Test 1: DNS Resolution
async function testDNSResolution() {
  console.log('📡 Test 1: DNS Resolution');
  console.log('─'.repeat(50));
  
  if (!hostname) {
    console.log('❌ Could not extract hostname from URI');
    return false;
  }

  try {
    // Test SRV record lookup
    const srvRecord = `_mongodb._tcp.${hostname}`;
    console.log(`Testing SRV record: ${srvRecord}`);
    
    try {
      const addresses = await dns.resolveSrv(srvRecord);
      console.log('✅ SRV record resolved successfully:');
      addresses.forEach((addr, idx) => {
        console.log(`   ${idx + 1}. ${addr.name}:${addr.port} (priority: ${addr.priority}, weight: ${addr.weight})`);
      });
      return true;
    } catch (srvError) {
      console.log(`❌ SRV record resolution failed: ${srvError.message}`);
      console.log(`   Error code: ${srvError.code}`);
      
      // Try regular DNS lookup as fallback
      try {
        console.log(`\nTrying regular DNS lookup for: ${hostname}`);
        const regularAddresses = await dns.resolve4(hostname);
        console.log('✅ Regular DNS lookup succeeded:');
        regularAddresses.forEach((addr, idx) => {
          console.log(`   ${idx + 1}. ${addr}`);
        });
        console.log('\n💡 Tip: Consider using a direct connection string instead of mongodb+srv://');
        return false;
      } catch (regularError) {
        console.log(`❌ Regular DNS lookup also failed: ${regularError.message}`);
        return false;
      }
    }
  } catch (error) {
    console.log(`❌ DNS test failed: ${error.message}`);
    return false;
  }
}

// Test 2: Network Connectivity
async function testNetworkConnectivity() {
  console.log('\n🌐 Test 2: Network Connectivity');
  console.log('─'.repeat(50));
  
  if (!hostname) {
    console.log('❌ Could not extract hostname from URI');
    return false;
  }

  try {
    // Try to resolve and connect to common MongoDB ports
    const addresses = await dns.resolve4(hostname).catch(() => []);
    
    if (addresses.length === 0) {
      console.log('❌ Could not resolve hostname to IP addresses');
      return false;
    }

    console.log(`✅ Resolved ${addresses.length} IP address(es):`);
    addresses.forEach((addr, idx) => {
      console.log(`   ${idx + 1}. ${addr}`);
    });
    
    return true;
  } catch (error) {
    console.log(`❌ Network connectivity test failed: ${error.message}`);
    return false;
  }
}

// Test 3: MongoDB Connection
async function testMongoConnection() {
  console.log('\n🔌 Test 3: MongoDB Connection');
  console.log('─'.repeat(50));
  
  try {
    console.log('Attempting to connect...');
    
    await mongoose.connect(MONGO_URI, {
      serverSelectionTimeoutMS: 10000,
      connectTimeoutMS: 10000,
      socketTimeoutMS: 45000,
      family: 4, // Force IPv4
    });
    
    console.log('✅ MongoDB connection successful!');
    console.log(`   Database: ${mongoose.connection.db.databaseName}`);
    console.log(`   Ready State: ${mongoose.connection.readyState === 1 ? 'Connected' : 'Disconnected'}`);
    
    await mongoose.connection.close();
    return true;
  } catch (error) {
    console.log(`❌ MongoDB connection failed: ${error.message}`);
    console.log(`   Error code: ${error.code || 'N/A'}`);
    
    if (error.message.includes('ENOTFOUND')) {
      console.log('\n💡 DNS Resolution Issue Detected');
      console.log('   Troubleshooting steps:');
      console.log('   1. Check your internet connection');
      console.log('   2. Try changing DNS servers to 8.8.8.8 (Google) or 1.1.1.1 (Cloudflare)');
      console.log('   3. Check if firewall/proxy is blocking DNS queries');
      console.log('   4. Verify MongoDB Atlas cluster is accessible');
      console.log('   5. Try using a direct connection string (mongodb://) instead of mongodb+srv://');
    } else if (error.message.includes('ETIMEDOUT')) {
      console.log('\n💡 Connection Timeout Issue Detected');
      console.log('   Troubleshooting steps:');
      console.log('   1. Check network connectivity');
      console.log('   2. Verify MongoDB Atlas IP whitelist includes your IP');
      console.log('   3. Check firewall settings');
    }
    
    return false;
  }
}

// Test 4: DNS Server Check
async function testDNSServers() {
  console.log('\n🔧 Test 4: DNS Server Configuration');
  console.log('─'.repeat(50));
  
  try {
    const dnsServers = require('dns').getServers();
    console.log('Current DNS servers:');
    dnsServers.forEach((server, idx) => {
      console.log(`   ${idx + 1}. ${server}`);
    });
    
    // Test with Google DNS
    console.log('\nTesting with Google DNS (8.8.8.8)...');
    const { Resolver } = require('dns').promises;
    const resolver = new Resolver();
    resolver.setServers(['8.8.8.8']);
    
    if (hostname) {
      try {
        const srvRecord = `_mongodb._tcp.${hostname}`;
        const addresses = await resolver.resolveSrv(srvRecord);
        console.log('✅ Google DNS can resolve SRV record');
        return true;
      } catch (error) {
        console.log(`❌ Google DNS also failed: ${error.message}`);
        return false;
      }
    }
  } catch (error) {
    console.log(`❌ DNS server test failed: ${error.message}`);
    return false;
  }
}

// Run all tests
async function runDiagnostics() {
  const results = {
    dns: false,
    network: false,
    connection: false,
    dnsServer: false,
  };

  results.dns = await testDNSResolution();
  results.network = await testNetworkConnectivity();
  results.dnsServer = await testDNSServers();
  results.connection = await testMongoConnection();

  // Summary
  console.log('\n' + '='.repeat(50));
  console.log('📊 Diagnostic Summary');
  console.log('='.repeat(50));
  console.log(`DNS Resolution:        ${results.dns ? '✅ PASS' : '❌ FAIL'}`);
  console.log(`Network Connectivity:  ${results.network ? '✅ PASS' : '❌ FAIL'}`);
  console.log(`DNS Server Test:       ${results.dnsServer ? '✅ PASS' : '❌ FAIL'}`);
  console.log(`MongoDB Connection:    ${results.connection ? '✅ PASS' : '❌ FAIL'}`);
  console.log('='.repeat(50));

  if (results.connection) {
    console.log('\n✅ All tests passed! MongoDB connection is working.');
    process.exit(0);
  } else {
    console.log('\n❌ Some tests failed. Please review the troubleshooting steps above.');
    process.exit(1);
  }
}

// Run diagnostics
runDiagnostics().catch((error) => {
  console.error('\n❌ Diagnostic script error:', error);
  process.exit(1);
});

