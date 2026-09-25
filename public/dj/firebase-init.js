/**
 * Firebase für DJ-Browser (Auth localStorage, Firestore memory cache, Functions).
 */
import { getApp, initializeApp } from 'https://www.gstatic.com/firebasejs/11.0.1/firebase-app.js';
import {
  initializeAuth,
  browserLocalPersistence,
  signInWithCustomToken,
  signOut,
  onAuthStateChanged,
} from 'https://www.gstatic.com/firebasejs/11.0.1/firebase-auth.js';
import {
  initializeFirestore,
  memoryLocalCache,
  collection,
  query,
  where,
  orderBy,
  onSnapshot,
  getDoc,
  getDocs,
  doc,
  addDoc,
  updateDoc,
  deleteDoc,
  runTransaction,
  deleteField,
  serverTimestamp,
  Timestamp,
} from 'https://www.gstatic.com/firebasejs/11.0.1/firebase-firestore.js';
import { getFunctions, httpsCallable } from 'https://www.gstatic.com/firebasejs/11.0.1/firebase-functions.js';

const FIREBASE_APP_NAME = 'vibesbox-dj-browser';

const firebaseConfig = {
  apiKey: 'AIzaSyAYMw-tYXq75RzLOvLnb113SVmGgBWRM5M',
  authDomain: 'dj-ollerganove.firebaseapp.com',
  projectId: 'dj-ollerganove',
  storageBucket: 'dj-ollerganove.firebasestorage.app',
  messagingSenderId: '567845942758',
  appId: '1:567845942758:web:8549e7d5abb8b3b81bd227',
};

try {
  let app;
  try {
    app = getApp(FIREBASE_APP_NAME);
  } catch (e) {
    app = initializeApp(firebaseConfig, FIREBASE_APP_NAME);
  }

  let auth;
  if (window.__djFirebaseAuth) {
    auth = window.__djFirebaseAuth;
  } else {
    auth = initializeAuth(app, { persistence: browserLocalPersistence });
    window.__djFirebaseAuth = auth;
  }

  let db;
  if (window.__djFirestoreMemoryDb) {
    db = window.__djFirestoreMemoryDb;
  } else {
    db = initializeFirestore(app, {
      localCache: memoryLocalCache(),
      // iPad/iOS: WebChannel bricht im Hintergrund oft ab — Long-Polling für Live-Sync.
      experimentalAutoDetectLongPolling: true,
    });
    window.__djFirestoreMemoryDb = db;
  }
  const functions = getFunctions(app, 'us-central1');

  window.djFirebaseAuth = auth;
  window.djFirebaseDb = db;
  window.djSignInWithCustomToken = signInWithCustomToken;
  window.djSignOut = signOut;
  window.djOnAuthStateChanged = onAuthStateChanged;
  window.djCollection = collection;
  window.djQuery = query;
  window.djWhere = where;
  window.djOrderBy = orderBy;
  window.djOnSnapshot = onSnapshot;
  window.djGetDoc = getDoc;
  window.djGetDocs = getDocs;
  window.djDoc = doc;
  window.djAddDoc = addDoc;
  window.djUpdateDoc = updateDoc;
  window.djDeleteDoc = deleteDoc;
  window.djRunTransaction = runTransaction;
  window.djDeleteField = deleteField;
  window.djServerTimestamp = serverTimestamp;
  window.djTimestamp = Timestamp;
  window.djHttpsCallable = (name) => httpsCallable(functions, name);
} catch (err) {
  window.djFirebaseInitFailed = err;
  console.error('[dj-firebase-init]', err);
} finally {
  window.dispatchEvent(new Event('djFirebaseReady'));
}
