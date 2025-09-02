// server/config/firebaseConfig.js
const serviceAccount = require('../config/jaxk-website-firebase-adminsdk-fbsvc-4461c645c4.json');

module.exports = {
  type: serviceAccount.type,
  project_id: serviceAccount.project_id,
  private_key_id: serviceAccount.private_key_id,
  private_key: serviceAccount.private_key.replace(/\\n/g, '\n'),
  client_email: serviceAccount.client_email,
  client_id: serviceAccount.client_id,
  auth_uri: serviceAccount.auth_uri,
  token_uri: serviceAccount.token_uri,
  auth_provider_x509_cert_url: serviceAccount.auth_provider_x509_cert_url,
  client_x509_cert_url: serviceAccount.client_x509_cert_url,
  databaseURL: `https://jaxk-website-default-rtdb.firebaseio.com`
};











// // server/config/firebaseConfig.js
//older one
// require("dotenv").config();

// module.exports = {
//   type: process.env.FIREBASE_TYPE,
//   project_id: process.env.FIREBASE_PROJECT_ID,
//   private_key_id: process.env.FIREBASE_PRIVATE_KEY_ID,
//   private_key: process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n'),
//   client_email: process.env.FIREBASE_CLIENT_EMAIL,
//   client_id: process.env.FIREBASE_CLIENT_ID,
//   auth_uri: process.env.FIREBASE_AUTH_URI,
//   token_uri: process.env.FIREBASE_TOKEN_URI,
//   auth_provider_x509_cert_url: process.env.FIREBASE_AUTH_PROVIDER_X509_CERT_URL,
//   client_x509_cert_url: process.env.FIREBASE_CLIENT_X509_CERT_URL
// };






// // Import the functions you need from the SDKs you need
// import { initializeApp } from "firebase/app";
// import { getAnalytics } from "firebase/analytics";
// import { getAuth } from 'firebase/auth';


// const firebaseConfig = {
//     apiKey: import.meta.env.VITE_FIREBASE_API_KEY,
//     authDomain: import.meta.env.VITE_FIREBASE_AUTH_DOMAIN,
//     projectId: import.meta.env.VITE_FIREBASE_PROJECT_ID,
//     storageBucket: import.meta.env.VITE_FIREBASE_STORAGE_BUCKET,
//     messagingSenderId: import.meta.env.VITE_FIREBASE_MESSAGING_SENDER_ID,
//     appId: import.meta.env.VITE_FIREBASE_APP_ID,
//     measurementId: import.meta.env.VITE_FIREBASE_MEASUREMENT_ID
//   };


//   require("dotenv").config();

//   module.exports = {
//     type: process.env.FIREBASE_TYPE,
//     project_id: process.env.FIREBASE_PROJECT_ID,
//     private_key_id: process.env.FIREBASE_PRIVATE_KEY_ID,
//     private_key: process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n'),
//     client_email: process.env.FIREBASE_CLIENT_EMAIL,
//     client_id: process.env.FIREBASE_CLIENT_ID,
//     auth_uri: process.env.FIREBASE_AUTH_URI,
//     token_uri: process.env.FIREBASE_TOKEN_URI,
//     auth_provider_x509_cert_url: process.env.FIREBASE_AUTH_PROVIDER_X509_CERT_URL,
//     client_x509_cert_url: process.env.FIREBASE_CLIENT_X509_CERT_URL
//   };


// const app = getApps().length === 0 ? initializeApp(firebaseConfig) : getApps()[0];
// const analytics = getAnalytics(app);
// const database = getDatabase(app); 
// const auth = getAuth(app);

// export { app, database, analytics, auth};
// // TODO: Add SDKs for Firebase products that you want to use
// // https://firebase.google.com/docs/web/setup#available-libraries

// // Your web app's Firebase configuration
// // For Firebase JS SDK v7.20.0 and later, measurementId is optional
// // const firebaseConfig = {
// //   apiKey: "AIzaSyAw95jJW9spAUFLGHkLqag3TfvcDlZ70lU",
// //   authDomain: "jaxk-website.firebaseapp.com",
// //   projectId: "jaxk-website",
// //   storageBucket: "jaxk-website.firebasestorage.app",
// //   messagingSenderId: "422315252031",
// //   appId: "1:422315252031:web:01d3add03d33b59da9db8a",
// //   measurementId: "G-Y9TYS1MV21"
// // };


// // module.exports = {
// //     type: process.env.FIREBASE_TYPE,
// //     project_id: process.env.FIREBASE_PROJECT_ID,
// //     private_key_id: process.env.FIREBASE_PRIVATE_KEY_ID,
// //     private_key: process.env.FIREBASE_PRIVATE_KEY.replace(/\\n/g, '\n'),
// //     client_email: process.env.FIREBASE_CLIENT_EMAIL,
// //     client_id: process.env.FIREBASE_CLIENT_ID,
// //     auth_uri: process.env.FIREBASE_AUTH_URI,
// //     token_uri: process.env.FIREBASE_TOKEN_URI,
// //     auth_provider_x509_cert_url: process.env.FIREBASE_AUTH_PROVIDER_X509_CERT_URL,
// //     client_x509_cert_url: process.env.FIREBASE_CLIENT_X509_CERT_URL
// //   };

// // Initialize Firebase
