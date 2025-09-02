// server/config/firebaseAdmin.js
const admin = require('firebase-admin');
const serviceAccount = require('./jaxk-website-firebase-adminsdk-fbsvc-4461c645c4.json');

if (!admin.apps.length) {
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    databaseURL: 'https://jaxk-website-default-rtdb.firebaseio.com'
  });
}

const auth = admin.auth();
const firestore = admin.firestore();
const realtimeDB = admin.database();

module.exports = { admin, auth, firestore, realtimeDB };
