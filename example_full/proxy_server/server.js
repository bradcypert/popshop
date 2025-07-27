#!/usr/bin/env node

/**
 * Simple Node.js server to demonstrate PopShop proxy functionality
 * This server provides mock external APIs that PopShop can proxy to
 */

const http = require('http');
const url = require('url');

const PORT = 3001;

// Mock data
const weatherData = {
  location: "San Francisco, CA",
  temperature: 72,
  condition: "Sunny",
  humidity: 60,
  wind_speed: 8,
  timestamp: new Date().toISOString(),
  source: "External Weather API (via proxy)"
};

const externalUsers = [
  {
    id: 1001,
    name: "External User 1",
    email: "ext1@external-service.com",
    source: "External User Service",
    last_login: "2025-01-25T14:30:00Z"
  },
  {
    id: 1002,
    name: "External User 2", 
    email: "ext2@external-service.com",
    source: "External User Service",
    last_login: "2025-01-26T09:15:00Z"
  }
];

// Helper function to send JSON response
function sendJSON(res, data, statusCode = 200) {
  res.writeHead(statusCode, {
    'Content-Type': 'application/json',
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
    'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Forwarded-By',
    'X-External-Service': 'Demo Proxy Target',
    'X-Response-Time': Date.now()
  });
  res.end(JSON.stringify(data, null, 2));
}

// Helper function to log requests
function logRequest(req) {
  const timestamp = new Date().toISOString();
  const forwarded = req.headers['x-forwarded-by'] || 'Direct';
  console.log(`[${timestamp}] ${req.method} ${req.url} - Forwarded by: ${forwarded}`);
}

// Request handler
function handleRequest(req, res) {
  logRequest(req);
  
  const parsedUrl = url.parse(req.url, true);
  const path = parsedUrl.pathname;
  const method = req.method;

  // Handle CORS preflight
  if (method === 'OPTIONS') {
    res.writeHead(200, {
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
      'Access-Control-Allow-Headers': 'Content-Type, Authorization, X-Forwarded-By'
    });
    res.end();
    return;
  }

  // Route handlers
  switch (path) {
    case '/weather':
      if (method === 'GET') {
        // Add some variation to make it feel more realistic
        const temp = 72 + Math.floor(Math.random() * 10) - 5;
        const conditions = ['Sunny', 'Partly Cloudy', 'Cloudy', 'Light Rain'];
        const condition = conditions[Math.floor(Math.random() * conditions.length)];
        
        const currentWeather = {
          ...weatherData,
          temperature: temp,
          condition: condition,
          timestamp: new Date().toISOString()
        };
        
        sendJSON(res, currentWeather);
      } else {
        sendJSON(res, { error: 'Method not allowed' }, 405);
      }
      break;

    case '/users':
      if (method === 'GET') {
        sendJSON(res, {
          users: externalUsers,
          total: externalUsers.length,
          service: "External User API",
          timestamp: new Date().toISOString()
        });
      } else {
        sendJSON(res, { error: 'Method not allowed' }, 405);
      }
      break;

    case '/status':
      sendJSON(res, {
        service: "External Demo Service",
        status: "operational",
        version: "1.0.0",
        uptime: process.uptime(),
        timestamp: new Date().toISOString()
      });
      break;

    case '/slow':
      // Simulate a slow endpoint (useful for testing timeouts)
      setTimeout(() => {
        sendJSON(res, {
          message: "This response was delayed by 2 seconds",
          timestamp: new Date().toISOString()
        });
      }, 2000);
      break;

    case '/error':
      sendJSON(res, {
        error: "Simulated external service error",
        code: "EXT_SERVICE_ERROR",
        timestamp: new Date().toISOString()
      }, 500);
      break;

    default:
      sendJSON(res, {
        error: "Not Found",
        message: `Endpoint ${path} not found on external service`,
        available_endpoints: ['/weather', '/users', '/status', '/slow', '/error'],
        timestamp: new Date().toISOString()
      }, 404);
  }
}

// Create and start server
const server = http.createServer(handleRequest);

server.listen(PORT, () => {
  console.log(`🌐 External Demo Service running on http://localhost:${PORT}`);
  console.log(`📡 Available endpoints:`);
  console.log(`   GET  /weather - Mock weather data`);
  console.log(`   GET  /users   - Mock external users`);
  console.log(`   GET  /status  - Service status`);
  console.log(`   GET  /slow    - Slow response (2s delay)`);
  console.log(`   GET  /error   - Error simulation`);
  console.log(`\n💡 This server demonstrates PopShop's proxy capabilities`);
  console.log(`   Configure PopShop to proxy requests to this server\n`);
});

// Graceful shutdown
process.on('SIGINT', () => {
  console.log('\n👋 Shutting down external demo service...');
  server.close(() => {
    console.log('✅ Server shut down gracefully');
    process.exit(0);
  });
});

// Error handling
server.on('error', (err) => {
  console.error('❌ Server error:', err);
});

process.on('uncaughtException', (err) => {
  console.error('❌ Uncaught exception:', err);
  process.exit(1);
});

process.on('unhandledRejection', (reason, promise) => {
  console.error('❌ Unhandled rejection at:', promise, 'reason:', reason);
  process.exit(1);
});