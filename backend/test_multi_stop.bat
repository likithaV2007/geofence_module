@echo off
echo Testing Multi-Stop Tracking Endpoints...
echo.

echo 1. Testing server health...
curl -X GET http://localhost:3000/health
echo.
echo.

echo 2. Starting multi-stop tracking...
curl -X POST http://localhost:3000/start-multi-stop-tracking ^
  -H "Content-Type: application/json" ^
  -d "{\"tripId\":\"test123\",\"stops\":[{\"lat\":12.9716,\"lng\":77.5946,\"fcmToken\":\"token1\"},{\"lat\":12.9726,\"lng\":77.5956,\"fcmToken\":\"token2\"},{\"lat\":12.9736,\"lng\":77.5966,\"fcmToken\":\"token3\"}],\"currentLat\":12.9706,\"currentLng\":77.5936}"
echo.
echo.

echo 3. Testing location tracking...
curl -X POST http://localhost:3000/track-multi-stop-location ^
  -H "Content-Type: application/json" ^
  -d "{\"tripId\":\"test123\",\"currentLat\":12.9716,\"currentLng\":77.5946}"
echo.
echo.

pause