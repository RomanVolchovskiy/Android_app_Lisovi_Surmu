// Firebase — той самий проєкт, що й у мобільного додатку (див. lib/firebase_options.dart).
import { initializeApp } from 'https://www.gstatic.com/firebasejs/10.14.1/firebase-app.js';
import {
  getFirestore, collection, doc, getDocs, getDoc, getDocFromServer, setDoc, updateDoc, deleteDoc,
  onSnapshot, query, where, orderBy, writeBatch, runTransaction,
  serverTimestamp, increment, arrayUnion, Timestamp,
} from 'https://www.gstatic.com/firebasejs/10.14.1/firebase-firestore.js';
import {
  getStorage, ref as storageRef, uploadBytes, getDownloadURL,
} from 'https://www.gstatic.com/firebasejs/10.14.1/firebase-storage.js';
import {
  getAuth, onAuthStateChanged, signInWithEmailAndPassword, createUserWithEmailAndPassword,
  sendEmailVerification, sendPasswordResetEmail, signOut,
} from 'https://www.gstatic.com/firebasejs/10.14.1/firebase-auth.js';

const app = initializeApp({
  apiKey: 'AIzaSyAhVTO38rw3oN0zxgH5_kXGl8Ex6mWPoPE',
  appId: '1:718598030499:web:de6181196b200ae40f6b16',
  messagingSenderId: '718598030499',
  projectId: 'huntingsignals',
  authDomain: 'huntingsignals.firebaseapp.com',
  storageBucket: 'huntingsignals.firebasestorage.app',
});

export const db = getFirestore(app);
export const storage = getStorage(app);
export const auth = getAuth(app);
auth.languageCode = 'uk';
export {
  collection, doc, getDocs, getDoc, getDocFromServer, setDoc, updateDoc, deleteDoc, onSnapshot, query, where, orderBy,
  writeBatch, runTransaction, serverTimestamp, increment, arrayUnion, Timestamp,
  storageRef, uploadBytes, getDownloadURL,
  onAuthStateChanged, signInWithEmailAndPassword, createUserWithEmailAndPassword,
  sendEmailVerification, sendPasswordResetEmail, signOut,
};
