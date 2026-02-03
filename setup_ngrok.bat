@echo off
echo Setting up ngrok for remote access...
echo.

echo 1. Install ngrok from https://ngrok.com/download if not installed
echo 2. Sign up for free account at https://ngrok.com/
echo 3. Run: ngrok config add-authtoken YOUR_TOKEN
echo.

echo Starting ngrok tunnel...
ngrok http 3000

echo.
echo Copy the https URL (e.g., https://abc123.ngrok-free.dev) 
echo and update it in lib/utils/constants.dart
pause