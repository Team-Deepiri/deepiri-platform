# Web Push Notification Setup (No Firebase Required)

This service now uses the **Web Push API** instead of Firebase Cloud Messaging (FCM). This is a standard, open protocol that works with all modern browsers without requiring any external services.

## Benefits

- ✅ **No external dependencies** - No Firebase account needed
- ✅ **Standard protocol** - Works with all modern browsers
- ✅ **Privacy-friendly** - No third-party tracking
- ✅ **Free** - No usage limits or costs
- ✅ **Open source** - Uses the standard Web Push API

## Setup Instructions

### 1. Generate VAPID Keys

VAPID (Voluntary Application Server Identification) keys are required for Web Push. Generate them using:

```bash
# Install web-push globally (if not already installed)
npm install -g web-push

# Generate VAPID keys
web-push generate-vapid-keys
```

This will output something like:
```
Public Key: BEl62iUYgUivxIkv69yViEuiBIa40HI8v...
Private Key: 8vdOrb_fYxqKDpYNlTdN1k1x7bEw...
```

### 2. Set Environment Variables

Add these to your `.env` file or environment:

```env
# VAPID Keys (required for Web Push)
VAPID_PUBLIC_KEY=BEl62iUYgUivxIkv69yViEuiBIa40HI8v...
VAPID_PRIVATE_KEY=8vdOrb_fYxqKDpYNlTdN1k1x7bEw...
VAPID_EMAIL=mailto:notifications@yourdomain.com
```

**Important:** 
- The `VAPID_EMAIL` should be a valid email or `mailto:` URL
- Keep the private key **secret** - never commit it to version control
- The public key is safe to share with clients

### 3. Client-Side Setup

On the frontend, you'll need to:

1. **Request notification permission:**
```javascript
const permission = await Notification.requestPermission();
```

2. **Get the VAPID public key from the server:**
```javascript
const response = await fetch('http://localhost:5005/push/vapid-key');
const { publicKey } = await response.json();
```

3. **Subscribe to push notifications:**
```javascript
const registration = await navigator.serviceWorker.ready;
const subscription = await registration.pushManager.subscribe({
  userVisibleOnly: true,
  applicationServerKey: urlBase64ToUint8Array(publicKey)
});

// Send subscription to your backend
await fetch('http://localhost:5005/push/subscribe', {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify({
    userId: 'user123',
    subscription: subscription
  })
});
```

4. **Handle incoming notifications in your service worker:**
```javascript
// In your service worker (sw.js)
self.addEventListener('push', (event) => {
  const data = event.data.json();
  const options = {
    body: data.body,
    icon: data.icon || '/icon-192x192.png',
    badge: data.badge || 0,
    data: data.data
  };
  
  event.waitUntil(
    self.registration.showNotification(data.title, options)
  );
});
```

## API Endpoints

### Send Push Notification
```http
POST /push/send
Content-Type: application/json

{
  "userId": "user123",
  "subscription": {
    "endpoint": "https://fcm.googleapis.com/...",
    "keys": {
      "p256dh": "...",
      "auth": "..."
    }
  },
  "notification": {
    "title": "New Task",
    "body": "You have a new task assigned",
    "icon": "/icon-192x192.png",
    "badge": 1,
    "url": "/tasks/123"
  }
}
```

### Send to Multiple Devices
```http
POST /push/send-multiple
Content-Type: application/json

{
  "subscriptions": [
    { "endpoint": "...", "keys": { "p256dh": "...", "auth": "..." } },
    { "endpoint": "...", "keys": { "p256dh": "...", "auth": "..." } }
  ],
  "notification": {
    "title": "Broadcast",
    "body": "Message to all users"
  }
}
```

### Get VAPID Public Key
```http
GET /push/vapid-key

Response: { "publicKey": "BEl62iUYgUivxIkv69yViEuiBIa40HI8v..." }
```

### Validate Subscription
```http
POST /push/validate
Content-Type: application/json

{
  "subscription": {
    "endpoint": "...",
    "keys": { "p256dh": "...", "auth": "..." }
  }
}

Response: { "valid": true }
```

## Migration from Firebase

If you were previously using Firebase:

1. **Remove Firebase dependencies:**
   - `firebase-admin` is no longer needed
   - Remove `FIREBASE_SERVICE_ACCOUNT` from environment variables

2. **Update client code:**
   - Replace FCM token registration with Web Push subscription
   - Update service worker to handle Web Push events
   - Use the new API endpoints

3. **Update database:**
   - Store Web Push subscriptions instead of FCM tokens
   - Subscription format: `{ endpoint, keys: { p256dh, auth } }`

## Browser Support

Web Push API is supported in:
- ✅ Chrome/Edge (Windows, Android, macOS)
- ✅ Firefox (Windows, Android, macOS, Linux)
- ✅ Safari (macOS 16.4+, iOS 16.4+)
- ✅ Opera

## Troubleshooting

### "Web Push not initialized"
- Make sure `VAPID_PUBLIC_KEY` and `VAPID_PRIVATE_KEY` are set in environment variables
- Check that the keys are valid (not empty, correct format)

### "Subscription expired" (410 error)
- The subscription is no longer valid
- User may have revoked permission or uninstalled the app
- Remove the subscription from your database

### Notifications not appearing
- Check browser notification permissions
- Verify service worker is registered and active
- Check browser console for errors
- Ensure HTTPS (required for production, localhost works for development)

## Additional Resources

- [Web Push API Documentation](https://developer.mozilla.org/en-US/docs/Web/API/Push_API)
- [web-push npm package](https://www.npmjs.com/package/web-push)
- [Service Worker API](https://developer.mozilla.org/en-US/docs/Web/API/Service_Worker_API)

