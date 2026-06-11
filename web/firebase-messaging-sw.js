// Firebase Messaging Service Worker
// Required for FCM push notifications on web

importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.7.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyBIxxo3zJD2G-XVHqq15S0ZldhiBoywu58',
  authDomain: 'tripjio-dev.firebaseapp.com',
  projectId: 'tripjio-dev',
  storageBucket: 'tripjio-dev.firebasestorage.app',
  messagingSenderId: '936663940212',
  appId: '1:936663940212:web:f2a394c01e4e408f172521',
});

const messaging = firebase.messaging();

// Handle background messages
messaging.onBackgroundMessage((payload) => {
  const { title, body } = payload.notification ?? {};
  if (!title) return;
  self.registration.showNotification(title, {
    body: body ?? '',
    icon: '/icons/Icon-192.png',
  });
});
