const express = require('express');
const admin = require('firebase-admin');
const cors = require('cors');
require('dotenv').config();

const app = express();

// Configuration constants
const GEOFENCE_RADIUS_METERS = 10;
const LOCATION_TOLERANCE = 0.0001; // ~11 meters
const DEG_TO_RAD = Math.PI / 180;
const INITIAL_NOTIFICATION_DELAY = 5 * 60 * 1000; // 5 minutes

// In-memory storage for active trips
const activeTrips = new Map();

app.use(cors({
  origin: process.env.ALLOWED_ORIGINS?.split(',') || ['http://localhost:3000', 'http://127.0.0.1:3000'],
  credentials: true
}));
app.use(express.json());

// Firebase Admin initialization
let firebaseInitialized = false;
try {
  let serviceAccount;
  
  // Try environment variables first (production)
  if (process.env.FIREBASE_PROJECT_ID) {
    serviceAccount = {
      type: "service_account",
      project_id: process.env.FIREBASE_PROJECT_ID,
      private_key_id: process.env.FIREBASE_PRIVATE_KEY_ID,
      private_key: process.env.FIREBASE_PRIVATE_KEY?.replace(/\\n/g, '\n'),
      client_email: process.env.FIREBASE_CLIENT_EMAIL,
      client_id: process.env.FIREBASE_CLIENT_ID,
      auth_uri: process.env.FIREBASE_AUTH_URI || "https://accounts.google.com/o/oauth2/auth",
      token_uri: process.env.FIREBASE_TOKEN_URI || "https://oauth2.googleapis.com/token"
    };
    console.log('✅ Using Firebase credentials from environment variables');
  } else {
    // Fallback to service account file (development)
    serviceAccount = require('./config/firebase-service-account.json');
    console.log('⚠️  Using Firebase credentials from file (development only)');
  }
  
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
  
  firebaseInitialized = true;
  console.log('✅ Firebase Admin initialized successfully');
} catch (error) {
  console.error('❌ Firebase initialization failed:', error.message);
  console.log('💡 Make sure Firebase credentials are configured');
}

// Distance calculation
function calculateDistance(lat1, lon1, lat2, lon2) {
  const R = 6371000; // Earth radius in meters
  const dLat = (lat2 - lat1) * DEG_TO_RAD;
  const dLon = (lon2 - lon1) * DEG_TO_RAD;
  const a = Math.sin(dLat/2) * Math.sin(dLat/2) +
    Math.cos(lat1 * DEG_TO_RAD) * Math.cos(lat2 * DEG_TO_RAD) *
    Math.sin(dLon/2) * Math.sin(dLon/2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
  return R * c;
}

// Check exact location match
function checkLocationMatch(currentLat, currentLng, targetLat, targetLng) {
  return Math.abs(currentLat - targetLat) <= LOCATION_TOLERANCE && 
         Math.abs(currentLng - targetLng) <= LOCATION_TOLERANCE;
}

// Health check
app.get('/health', (req, res) => {
  res.json({
    status: 'healthy',
    firebase: firebaseInitialized,
    timestamp: new Date().toISOString()
  });
});

// Dedicated FCM endpoint
app.post('/send-fcm', async (req, res) => {
  try {
    const { token, title, body, data } = req.body;
    
    console.log('📤 FCM Request:', { token: token?.substring(0, 20) + '...', title, body });
    
    if (!token || !title || !body) {
      return res.status(400).json({ error: 'Missing required fields' });
    }
    
    if (!firebaseInitialized) {
      console.log('❌ Firebase not initialized');
      return res.status(500).json({ error: 'Firebase not initialized' });
    }
    
    const message = {
      token: token,
      notification: {
        title: title,
        body: body,
      },
      data: data || {},
      android: {
        priority: 'high',
        notification: {
          channelId: 'geofence_channel',
          priority: 'high'
        }
      },
    };
    
    const result = await admin.messaging().send(message);
    console.log('✅ FCM sent successfully:', result);
    
    res.json({ 
      success: true, 
      messageId: result,
      message: 'FCM notification sent successfully'
    });
  } catch (error) {
    console.error('❌ FCM error:', error);
    res.status(500).json({ error: 'FCM notification failed', details: error.message });
  }
});

// Multi-stop tracking endpoint
app.post('/start-multi-stop-tracking', async (req, res) => {
  try {
    const { tripId, stops, currentLat, currentLng } = req.body;
    
    console.log('\n🚀 Starting multi-stop tracking:', {
      tripId,
      stopsCount: stops?.length,
      currentLat,
      currentLng
    });
    
    if (!tripId || !stops || !Array.isArray(stops) || stops.length === 0) {
      return res.status(400).json({ error: 'Missing tripId or stops array' });
    }
    
    // Validate stops format
    for (let i = 0; i < stops.length; i++) {
      const stop = stops[i];
      if (!stop.lat || !stop.lng || !stop.fcmToken) {
        return res.status(400).json({ 
          error: `Stop ${i + 1} missing required fields (lat, lng, fcmToken)` 
        });
      }
    }
    
    // Store trip data
    activeTrips.set(tripId, {
      stops,
      currentStopIndex: 0,
      startTime: Date.now(),
      initialNotificationSent: false
    });
    
    // Send initial notification after 5 minutes
    setTimeout(async () => {
      const trip = activeTrips.get(tripId);
      if (trip && !trip.initialNotificationSent && trip.currentStopIndex === 0) {
        trip.initialNotificationSent = true;
        const firstStop = trip.stops[0];
        await sendNotification(firstStop.fcmToken, 
          'Trip Started! 🚗', 
          'Driver has started the journey to your location');
        console.log(`✅ Initial notification sent for trip ${tripId}`);
      }
    }, INITIAL_NOTIFICATION_DELAY);
    
    res.json({ 
      success: true, 
      message: 'Multi-stop tracking started',
      tripId,
      stopsCount: stops.length
    });
  } catch (error) {
    console.error('❌ Multi-stop tracking error:', error);
    res.status(500).json({ error: 'Failed to start tracking', details: error.message });
  }
});

// Helper function to send notifications
async function sendNotification(fcmToken, title, body, data = {}) {
  if (!firebaseInitialized) {
    throw new Error('Firebase not initialized');
  }
  
  const message = {
    token: fcmToken,
    notification: { title, body },
    data: { ...data, timestamp: new Date().toISOString() },
    android: {
      priority: 'high',
      notification: {
        channelId: 'geofence_channel',
        priority: 'high'
      }
    }
  };
  
  return await admin.messaging().send(message);
}

// Multi-stop location tracking
app.post('/track-multi-stop-location', async (req, res) => {
  try {
    const { tripId, currentLat, currentLng } = req.body;
    
    if (!tripId || typeof currentLat !== 'number' || typeof currentLng !== 'number') {
      return res.status(400).json({ error: 'Missing required fields' });
    }
    
    const trip = activeTrips.get(tripId);
    if (!trip) {
      return res.status(404).json({ error: 'Trip not found' });
    }
    
    if (trip.currentStopIndex >= trip.stops.length) {
      return res.json({ 
        success: true, 
        status: 'Trip completed',
        message: 'All stops reached'
      });
    }
    
    const currentStop = trip.stops[trip.currentStopIndex];
    const distance = calculateDistance(currentLat, currentLng, currentStop.lat, currentStop.lng);
    const isExactMatch = checkLocationMatch(currentLat, currentLng, currentStop.lat, currentStop.lng);
    
    console.log(`\n📍 Trip ${tripId} - Stop ${trip.currentStopIndex + 1}/${trip.stops.length}`);
    console.log(`Distance to current stop: ${distance.toFixed(1)}m`);
    
    // Check if reached current stop
    if (isExactMatch || distance <= GEOFENCE_RADIUS_METERS) {
      console.log(`✅ Stop ${trip.currentStopIndex + 1} reached!`);
      
      // Move to next stop
      trip.currentStopIndex++;
      
      // Send notification to next stop if exists
      if (trip.currentStopIndex < trip.stops.length) {
        const nextStop = trip.stops[trip.currentStopIndex];
        await sendNotification(
          nextStop.fcmToken,
          `Driver Approaching! 🚗`,
          `Driver has reached stop ${trip.currentStopIndex} and is heading to you next`,
          { tripId, stopNumber: (trip.currentStopIndex + 1).toString() }
        );
        
        res.json({
          success: true,
          status: `Stop ${trip.currentStopIndex} reached`,
          message: `Notification sent to stop ${trip.currentStopIndex + 1}`,
          currentStopIndex: trip.currentStopIndex,
          totalStops: trip.stops.length
        });
      } else {
        // Trip completed
        activeTrips.delete(tripId);
        res.json({
          success: true,
          status: 'Trip completed',
          message: 'All stops reached successfully'
        });
      }
    } else {
      res.json({
        success: true,
        status: 'Tracking...',
        distance: Math.round(distance),
        currentStop: trip.currentStopIndex + 1,
        totalStops: trip.stops.length
      });
    }
  } catch (error) {
    console.error('❌ Multi-stop tracking error:', error);
    res.status(500).json({ error: 'Tracking failed', details: error.message });
  }
});

// Main tracking endpoint
app.post('/track-location', async (req, res) => {
  try {
    const { tripId, currentLat, currentLng, targetLat, targetLng, parentFcmToken } = req.body;
    
    console.log('\n🔍 Received tracking request:', {
      tripId,
      currentLat,
      currentLng,
      targetLat,
      targetLng,
      parentFcmToken: parentFcmToken ? `${parentFcmToken.substring(0, 20)}...` : 'missing'
    });
    
    if (!tripId || !parentFcmToken || typeof currentLat !== 'number' || 
        typeof currentLng !== 'number' || typeof targetLat !== 'number' || 
        typeof targetLng !== 'number') {
      console.log('❌ Missing required fields');
      return res.status(400).json({ error: 'Missing required fields' });
    }
    
    // Check exact match first
    const isExactMatch = checkLocationMatch(currentLat, currentLng, targetLat, targetLng);
    
    // Calculate distance
    const distance = calculateDistance(currentLat, currentLng, targetLat, targetLng);
    
    console.log(`\n📍 Trip: ${tripId}`);
    console.log(`Current: ${currentLat.toFixed(6)}, ${currentLng.toFixed(6)}`);
    console.log(`Target: ${targetLat.toFixed(6)}, ${targetLng.toFixed(6)}`);
    console.log(`Distance: ${distance.toFixed(1)}m`);
    console.log(`Exact match: ${isExactMatch}`);
    console.log(`Within ${GEOFENCE_RADIUS_METERS}m: ${distance <= GEOFENCE_RADIUS_METERS}`);
    
    // Check if within geofence OR exact match
    if (isExactMatch || distance <= GEOFENCE_RADIUS_METERS) {
      console.log(`✅ GEOFENCE TRIGGERED! ${isExactMatch ? 'EXACT MATCH' : `Within ${distance.toFixed(1)}m`}`);
      
      if (!firebaseInitialized) {
        console.log('❌ Firebase not initialized');
        return res.status(500).json({ error: 'Firebase not initialized' });
      }
      
      try {
        const message = {
          token: parentFcmToken,
          notification: {
            title: 'Target Reached! 🎯',
            body: `Driver arrived within ${Math.round(distance)}m of destination`,
          },
          data: {
            tripId: tripId,
            distance: distance.toString(),
            timestamp: new Date().toISOString(),
            type: 'geofence_entered'
          },
          android: {
            priority: 'high',
            notification: {
              channelId: 'geofence_channel',
              priority: 'high'
            }
          },
          apns: {
            payload: {
              aps: {
                alert: {
                  title: 'Target Reached! 🎯',
                  body: `Driver arrived within ${Math.round(distance)}m of destination`
                },
                sound: 'default',
                badge: 1
              }
            }
          }
        };
        
        console.log('📤 Sending FCM message...');
        const result = await admin.messaging().send(message);
        console.log(`✅ FCM sent successfully: ${result}`);
        
        res.json({ 
          success: true, 
          status: 'Notification sent! 🎯', 
          distance: Math.round(distance),
          withinGeofence: true,
          exactMatch: isExactMatch
        });
      } catch (fcmError) {
        console.error(`❌ FCM failed:`, fcmError);
        res.status(500).json({ error: 'Notification failed', details: fcmError.message });
      }
    } else {
      console.log(`🔍 Tracking... (${distance.toFixed(1)}m away)`);
      res.json({ 
        success: true, 
        status: 'Tracking...', 
        distance: Math.round(distance),
        withinGeofence: false,
        exactMatch: false
      });
    }
  } catch (error) {
    console.error('❌ Tracking error:', error);
    res.status(500).json({ error: 'Internal server error', details: error.message });
  }
});

// Handle 404 errors
app.use('*', (req, res) => {
  console.log(`❌ 404 - Route not found: ${req.method} ${req.originalUrl}`);
  res.status(404).json({ 
    error: 'Route not found', 
    method: req.method,
    path: req.originalUrl,
    availableEndpoints: [
      'GET /health',
      'POST /track-location',
      'POST /send-fcm',
      'POST /start-multi-stop-tracking',
      'POST /track-multi-stop-location'
    ]
  });
});

const PORT = process.env.PORT || 3000;

app.listen(PORT, '0.0.0.0', () => {
  console.log(`🚀 Server running on http://localhost:${PORT}`);
  console.log(`📡 Firebase: ${firebaseInitialized ? 'Ready' : 'Not configured'}`);
  console.log(`📍 Geofence radius: ${GEOFENCE_RADIUS_METERS} meters`);
});

module.exports = app;