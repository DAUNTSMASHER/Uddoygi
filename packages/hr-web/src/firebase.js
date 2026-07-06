import { initializeApp } from 'firebase/app';
import { getAuth } from 'firebase/auth';
import { getFirestore } from 'firebase/firestore';
import { getStorage } from 'firebase/storage';

const firebaseConfig = {
  apiKey: 'AIzaSyCyEBCN8D4OBhJ5fF3AfG4MtbfbV3Lwe8Q',
  authDomain: 'uddyogi.firebaseapp.com',
  databaseURL: 'https://uddyogi-default-rtdb.asia-southeast1.firebasedatabase.app',
  projectId: 'uddyogi',
  storageBucket: 'uddyogi.firebasestorage.app',
  messagingSenderId: '308795588138',
  appId: '1:308795588138:web:2f43ef195bb1b8f0decd53',
};

const app = initializeApp(firebaseConfig);

export const auth = getAuth(app);
export const db = getFirestore(app);
export const storage = getStorage(app);
export default app;
