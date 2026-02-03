# Troubleshooting Guide

## Common Issues and Solutions

### 1. Server 404 Errors

**Problem**: Client gets 404 errors when trying to connect to server

**Solutions**:
1. **Start the backend server first**:
   ```bash
   cd backend
   start_server.bat
   ```

2. **Verify server is running**:
   - Open browser and go to `http://localhost:3000/health`
   - Should return: `{"status":"healthy","firebase":true,"timestamp":"..."}`

3. **Check available endpoints**:
   - GET `/health` - Server health check
   - POST `/track-location` - Location tracking
   - POST `/send-fcm` - Send FCM notifications

### 2. Client Connection Errors

**Problem**: Flutter app can't connect to server

**Solutions**:
1. **Check server URL in constants.dart**:
   ```dart
   static const String baseUrl = 'http://localhost:3000';
   ```

2. **For Android emulator**, use:
   ```dart
   static const String baseUrl = 'http://10.0.2.2:3000';
   ```

3. **For physical device on same network**, use your computer's IP:
   ```dart
   static const String baseUrl = 'http://192.168.1.XXX:3000';
   ```

### 3. Firebase Issues

**Problem**: FCM notifications not working

**Solutions**:
1. **Check Firebase configuration**:
   - Ensure `firebase-service-account.json` exists in `backend/config/`
   - Verify `.env` file has correct Firebase credentials

2. **Test FCM endpoint**:
   ```bash
   cd backend
   test_server.bat
   ```

### 4. Testing Steps

1. **Test server health**:
   ```bash
   curl http://localhost:3000/health
   ```

2. **Test location tracking**:
   ```bash
   curl -X POST http://localhost:3000/track-location \
     -H "Content-Type: application/json" \
     -d '{"tripId":"TEST","currentLat":12.9716,"currentLng":77.5946,"targetLat":12.9716,"targetLng":77.5946,"parentFcmToken":"test"}'
   ```

3. **Run Flutter app**:
   ```bash
   flutter pub get
   flutter run
   ```

### 5. Network Configuration

**For different environments**:

- **Local development**: `http://localhost:3000`
- **Android emulator**: `http://10.0.2.2:3000`
- **Same WiFi network**: `http://[YOUR_IP]:3000`
- **Production**: Use ngrok or deploy to cloud

### 6. Quick Fix Commands

```bash
# Backend setup
cd backend
npm install
node server.js

# Flutter setup
flutter pub get
flutter run

# Test connectivity
curl http://localhost:3000/health
```

### 7. Error Messages and Solutions

| Error | Solution |
|-------|----------|
| "Connection refused" | Start backend server |
| "404 Not Found" | Check endpoint URLs |
| "Firebase not initialized" | Check Firebase config |
| "Server is not reachable" | Verify server URL |
| "Missing required fields" | Check request body format |

### 8. Development Workflow

1. Start backend server: `cd backend && start_server.bat`
2. Verify health: Open `http://localhost:3000/health`
3. Run Flutter app: `flutter run`
4. Test functionality in app
5. Check server logs for debugging

### 9. Production Deployment

For production, update `constants.dart`:
```dart
static const String baseUrl = 'https://your-domain.com';
```

And deploy backend to cloud service (Heroku, AWS, etc.)