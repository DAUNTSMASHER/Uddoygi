const express = require('express');
const cors = require('cors');
const admin = require('firebase-admin');

admin.initializeApp({
  credential: admin.credential.cert(require('./serviceAccountkey.json')),
});

const app = express();
app.use(cors());       // OK for dev; lock down later if needed
app.use(express.json());

// simple dev auth via header; rotate/change often
const ADMIN_TOKEN = process.env.ADMIN_TOKEN || 'dev-change-me';

app.post('/setPassword', async (req, res) => {
  try {
    const token = req.headers['x-admin-token'];
    if (token !== ADMIN_TOKEN) {
      return res.status(401).json({ error: 'unauthorized' });
    }

    const { uid, email, newPassword } = req.body || {};
    if (!newPassword || newPassword.length < 6) {
      return res.status(400).json({ error: 'newPassword must be >= 6 chars' });
    }

    let targetUid = uid;
    if (!targetUid && email) {
      const u = await admin.auth().getUserByEmail(email);
      targetUid = u.uid;
    }
    if (!targetUid) return res.status(400).json({ error: 'Provide uid or email' });

    await admin.auth().updateUser(targetUid, { password: newPassword });
    await admin.auth().revokeRefreshTokens(targetUid);

    res.json({ ok: true, uid: targetUid });
  } catch (e) {
    res.status(500).json({ error: e.errorInfo?.message || e.message || 'internal' });
  }
});

const port = process.env.PORT || 8082;
app.listen(port, () => console.log(`Admin server listening on :${port}`));
