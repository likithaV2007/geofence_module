# Cloud Deployment Options

## Option 1: Heroku (Free tier available)

1. Install Heroku CLI
2. Create `Procfile` in backend folder:
   ```
   web: node server.js
   ```
3. Deploy:
   ```bash
   cd backend
   git init
   heroku create your-app-name
   git add .
   git commit -m "Deploy"
   git push heroku main
   ```

## Option 2: Railway

1. Connect GitHub repo to Railway
2. Deploy automatically
3. Get public URL

## Option 3: Render

1. Connect GitHub repo
2. Set build command: `npm install`
3. Set start command: `node server.js`

## Option 4: AWS/Google Cloud

1. Use App Engine or Elastic Beanstalk
2. Configure environment variables
3. Deploy with CLI tools

## Update Flutter App

After deployment, update `constants.dart`:
```dart
static const String baseUrl = 'https://your-deployed-url.com';
```