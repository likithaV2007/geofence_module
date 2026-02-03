@echo off
echo Testing Geofencing Server...
echo.

echo 1. Testing Health Endpoint...
curl -X GET http://localhost:3000/health
echo.
echo.

echo 2. Testing Track Location Endpoint...
curl -X POST http://localhost:3000/track-location ^
  -H "Content-Type: application/json" ^
  -d "{\"tripId\":\"TEST_123\",\"currentLat\":12.9716,\"currentLng\":77.5946,\"targetLat\":12.9716,\"targetLng\":77.5946,\"parentFcmToken\":\"test_token_123\"}"
echo.
echo.

echo 3. Testing FCM Endpoint...
curl -X POST http://localhost:3000/send-fcm ^
  -H "Content-Type: application/json" ^
  -d "{\"token\":\"test_token\",\"title\":\"Test Notification\",\"body\":\"This is a test\"}"
echo.
echo.

echo 4. Testing Invalid Endpoint (should return 404)...
curl -X GET http://localhost:3000/invalid-endpoint
echo.
echo.

pause