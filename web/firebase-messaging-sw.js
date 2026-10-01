// firebase-messaging-sw.js
// Background FCM message handler for Maintify (Production Firebase project).
// This file MUST be served from the root path (/firebase-messaging-sw.js) with
// MIME type application/javascript for the browser to register it as a service worker.

importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.12.0/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyAHb536ePpNovwGATJ1Ba6VP8eeY370QA4',
  authDomain: 'maintify-ff8c4.firebaseapp.com',
  projectId: 'maintify-ff8c4',
  storageBucket: 'maintify-ff8c4.firebasestorage.app',
  messagingSenderId: '709385460007',
  appId: '1:709385460007:web:40ff10ac9fab30399b7102',
  measurementId: 'G-SJ3CVE03XJ',
});

const messaging = firebase.messaging();

// Handle background messages (app in background or tab closed).
messaging.onBackgroundMessage((payload) => {
  const title = payload.notification?.title ?? 'Maintify';
  const body  = payload.notification?.body  ?? '';
  const data  = payload.data ?? {};

  self.registration.showNotification(title, {
    body,
    icon: '/icons/Icon-192.png',
    badge: '/icons/Icon-192.png',
    data,
  });
});

// Navigate to the app when the user taps a background notification.
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((clientList) => {
      for (const client of clientList) {
        if (client.url && 'focus' in client) {
          return client.focus();
        }
      }
      if (clients.openWindow) {
        return clients.openWindow('/');
      }
    }),
  );
});
