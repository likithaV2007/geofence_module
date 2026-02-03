# Geofencing Module

A Flutter geofencing application with real-time location tracking and FCM notifications.

## Features

- **Driver App**: Real-time location tracking with geofence detection
- **Parent App**: Receives notifications when driver reaches destination
- **Backend**: Node.js server with Firebase FCM integration
- **Geofence Detection**: 10m radius with exact location matching

## Setup

### 1. Firebase Configuration

1. Copy `lib/firebase_options.dart.example` to `lib/firebase_options.dart`
2. Replace placeholder values with your Firebase project configuration
3. Copy `backend/config/firebase-service-account.json.example` to `backend/config/firebase-service-account.json`
4. Add your Firebase service account key content

### 2. Backend Environment

1. Copy `backend/config/.env.example` to `backend/config/.env`
2. Configure environment variables as needed

## Quick Start

### 1. Start Backend Server
```bash
cd backend
start_server.bat
```

### 2. Verify Server is Running
Open browser: `http://localhost:3000/health`
Should show: `{"status":"healthy","firebase":true}`

### 3. Run Flutter App
```bash
flutter pub get
flutter run
```

### 4. Test Server Endpoints
```bash
cd backend
test_server.bat
```

## Configuration

- **Server**: `backend/server.js` (Port 3000)
- **Firebase**: `backend/config/firebase-service-account.json`
- **App Constants**: `lib/utils/constants.dart`
- **Server URL**: `http://localhost:3000` (for local development)

## Usage

1. Get FCM token from home screen
2. Open Driver App and enter FCM token
3. Set target location (tap map or use current location)
4. Start tracking - notifications sent when within 10m or exact match

## Troubleshooting

If you encounter 404 or connection errors, see [TROUBLESHOOTING.md](TROUBLESHOOTING.md)

### Common Issues:
- **Server not running**: Run `backend/start_server.bat`
- **Wrong URL**: Check `lib/utils/constants.dart` baseUrl
- **Android emulator**: Use `http://10.0.2.2:3000`
- **Physical device**: Use your computer's IP address

## Available Endpoints

- `GET /health` - Server health check
- `POST /track-location` - Location tracking
- `POST /send-fcm` - Send FCM notifications