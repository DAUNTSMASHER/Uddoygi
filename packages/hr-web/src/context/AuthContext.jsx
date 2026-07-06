import React, { createContext, useContext, useEffect, useState, useCallback } from 'react';
import {
  signInWithEmailAndPassword,
  signOut,
  onAuthStateChanged,
} from 'firebase/auth';
import { doc, getDoc } from 'firebase/firestore';
import { auth, db } from '../firebase';

const AuthContext = createContext(null);

const SESSION_KEY = 'uddyogi_hr_session';

function loadStoredSession() {
  try {
    const raw = localStorage.getItem(SESSION_KEY);
    return raw ? JSON.parse(raw) : null;
  } catch {
    return null;
  }
}

export function AuthProvider({ children }) {
  const [user, setUser]       = useState(null);
  const [session, setSession] = useState(loadStoredSession);
  const [loading, setLoading] = useState(true);

  const saveSession = useCallback((data) => {
    localStorage.setItem(SESSION_KEY, JSON.stringify(data));
    setSession(data);
  }, []);

  const clearSession = useCallback(() => {
    localStorage.removeItem(SESSION_KEY);
    setSession(null);
  }, []);

  // Listen for Firebase auth state changes (handles multi-device / tab refresh)
  useEffect(() => {
    const unsub = onAuthStateChanged(auth, async (firebaseUser) => {
      if (firebaseUser) {
        setUser(firebaseUser);
        // If we have a stored session for this user, restore it
        const stored = loadStoredSession();
        if (stored && stored.uid === firebaseUser.uid) {
          setSession(stored);
        }
      } else {
        setUser(null);
        clearSession();
      }
      setLoading(false);
    });
    return unsub;
  }, [clearSession]);

  // Build compound email: john@co.com + CID12345 → john+CID12345@co.com
  function buildCompoundEmail(email, cid) {
    const parts = email.split('@');
    if (parts.length !== 2) return email;
    return `${parts[0]}+${cid}@${parts[1]}`;
  }

  async function login(email, password, companyId) {
    const cid      = companyId.trim();
    const compound = buildCompoundEmail(email.trim(), cid);

    let cred;
    try {
      cred = await signInWithEmailAndPassword(auth, compound, password);
    } catch (e) {
      // Fallback to raw email for admin / legacy accounts
      if (
        e.code === 'auth/user-not-found' ||
        e.code === 'auth/invalid-credential' ||
        e.code === 'auth/wrong-password'
      ) {
        cred = await signInWithEmailAndPassword(auth, email.trim(), password);
      } else {
        throw e;
      }
    }

    // Fetch user doc from data/{companyId}/users/{uid}
    const userRef = doc(db, 'data', cid, 'users', cred.user.uid);
    const snap    = await getDoc(userRef);
    if (!snap.exists()) throw new Error('User data not found in this company.');

    const data = snap.data();
    const dept = (data.department || '').toLowerCase();

    // Allow HR department and admin (admin can access HR portal too)
    if (dept !== 'hr' && dept !== 'admin') {
      await signOut(auth);
      throw new Error('Access denied. This portal is for HR and Admin users only.');
    }

    const sessionData = {
      uid:         cred.user.uid,
      email:       email.trim(),
      companyId:   cid,
      role:        data.role || dept,
      department:  dept,
      displayName: data.name || data.displayName || cred.user.displayName || email,
      photoUrl:    data.photoUrl || data.profileImage || cred.user.photoURL || '',
      timestamp:   new Date().toISOString(),
    };

    saveSession(sessionData);
    setUser(cred.user);
    return sessionData;
  }

  async function logout() {
    try { await signOut(auth); } catch (_) {}
    clearSession();
  }

  const value = {
    user,
    session,
    loading,
    login,
    logout,
    isAuthenticated: !!user && !!session,
    companyId: session?.companyId || '',
  };

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>;
}

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error('useAuth must be used inside AuthProvider');
  return ctx;
}
