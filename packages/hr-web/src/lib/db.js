// Firestore path helpers — mirrors the Flutter DB service
// All HR data lives under: data/{companyId}/{collection}

import {
  collection,
  doc,
  query,
  where,
  orderBy,
  limit,
  onSnapshot,
  getDoc,
  getDocs,
  addDoc,
  updateDoc,
  deleteDoc,
  serverTimestamp,
  Timestamp,
  writeBatch,
  increment,
} from 'firebase/firestore';
import { db } from '../firebase';

export { serverTimestamp, Timestamp, writeBatch, increment, db };

/** Returns a CollectionReference for data/{cid}/{col} */
export function col(cid, colName) {
  return collection(db, 'data', cid, colName);
}

/** Returns a DocumentReference for data/{cid}/{col}/{docId} */
export function docRef(cid, colName, docId) {
  return doc(db, 'data', cid, colName, docId);
}

/** Subscribe to a collection with optional query constraints */
export function subscribe(ref, callback, constraints = []) {
  const q = constraints.length ? query(ref, ...constraints) : ref;
  return onSnapshot(q, (snap) => {
    const docs = snap.docs.map((d) => ({ id: d.id, ...d.data() }));
    callback(docs);
  });
}

/** One-time fetch */
export async function fetchAll(ref, constraints = []) {
  const q = constraints.length ? query(ref, ...constraints) : ref;
  const snap = await getDocs(q);
  return snap.docs.map((d) => ({ id: d.id, ...d.data() }));
}

/** Add a document */
export async function add(ref, data) {
  return addDoc(ref, { ...data, createdAt: serverTimestamp() });
}

/** Update a document */
export async function update(cid, colName, docId, data) {
  return updateDoc(docRef(cid, colName, docId), {
    ...data,
    updatedAt: serverTimestamp(),
  });
}

/** Delete a document */
export async function remove(cid, colName, docId) {
  return deleteDoc(docRef(cid, colName, docId));
}

export { query, where, orderBy, limit, onSnapshot };
