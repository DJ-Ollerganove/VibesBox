/**
 * VibesBox Firebase: ausschließlich memoryLocalCache (Firestore) und inMemoryPersistence (Auth).
 * Kein getFirestore()/getAuth()-Fallback — nur initializeFirestore / initializeAuth + Window-Cache gegen Doppel-Init.
 * Bei Fehler: firebaseInitFailed gesetzt, firebaseGlobalsReady trotzdem (Sprache/UI unabhängig von Firebase).
 */
import { getApp, initializeApp } from 'https://www.gstatic.com/firebasejs/11.0.1/firebase-app.js';
import {
  initializeAuth,
  inMemoryPersistence,
  setPersistence
} from 'https://www.gstatic.com/firebasejs/11.0.1/firebase-auth.js';
import {
  initializeFirestore,
  memoryLocalCache,
  collection,
  addDoc,
  serverTimestamp,
  getDocs,
  query,
  where,
  orderBy,
  limit,
  getDoc,
  doc,
  Timestamp,
  setDoc,
  updateDoc,
  onSnapshot,
  increment,
  writeBatch
} from 'https://www.gstatic.com/firebasejs/11.0.1/firebase-firestore.js';

const FIREBASE_APP_NAME = 'vibesbox-pwa';

const firebaseConfig = {
  apiKey: 'AIzaSyAYMw-tYXq75RzLOvLnb113SVmGgBWRM5M',
  authDomain: 'dj-ollerganove.firebaseapp.com',
  projectId: 'dj-ollerganove',
  storageBucket: 'dj-ollerganove.firebasestorage.app',
  messagingSenderId: '567845942758',
  appId: '1:567845942758:web:8549e7d5abb8b3b81bd227'
};

try {
  var app;
  try {
    app = getApp(FIREBASE_APP_NAME);
  } catch (e) {
    app = initializeApp(firebaseConfig, FIREBASE_APP_NAME);
  }

  var db;
  if (window.__vbFirestoreMemoryDb) {
    db = window.__vbFirestoreMemoryDb;
  } else {
    db = initializeFirestore(app, { localCache: memoryLocalCache() });
    window.__vbFirestoreMemoryDb = db;
  }

  var auth;
  if (window.__vbFirebaseAuthInMemory) {
    auth = window.__vbFirebaseAuthInMemory;
  } else {
    auth = initializeAuth(app, { persistence: inMemoryPersistence });
    window.__vbFirebaseAuthInMemory = auth;
    try {
      await setPersistence(auth, inMemoryPersistence);
    } catch (spErr) {
      if (typeof console !== 'undefined' && console.warn) {
        console.warn('[Firebase Auth] setPersistence(inMemoryPersistence):', spErr && (spErr.code || spErr.message || spErr));
      }
    }
  }

  window.firebaseAuth = auth;
  window.firebaseDb = db;
  window.firebaseAddDoc = addDoc;
  window.firebaseCollection = collection;
  window.firebaseServerTimestamp = serverTimestamp;
  window.firebaseGetDocs = getDocs;
  window.firebaseQuery = query;
  window.firebaseWhere = where;
  window.firebaseOrderBy = orderBy;
  window.firebaseLimit = limit;
  window.firebaseGetDoc = getDoc;
  window.firebaseDoc = doc;
  window.firebaseTimestamp = Timestamp;
  window.firebaseSetDoc = setDoc;
  window.firebaseUpdateDoc = updateDoc;
  window.firebaseOnSnapshot = onSnapshot;
  window.firebaseIncrement = increment;
  window.firebaseWriteBatch = function (dbRef) {
    return writeBatch(dbRef);
  };
} catch (err) {
  window.firebaseInitFailed = err;
  if (typeof console !== 'undefined' && console.error) {
    console.error('[firebase-init] Init fehlgeschlagen (Sprache/UI läuft ohne DB):', err);
  }
} finally {
  window.dispatchEvent(new Event('firebaseGlobalsReady'));
}
