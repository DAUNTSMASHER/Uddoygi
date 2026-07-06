// piprapay-backend/src/middleware/auth.js
// ─────────────────────────────────────────────────────────────────────────────
// Validates that incoming requests from the Flutter app carry the correct
// backend secret token. This is separate from the PipraPay API key.
// ─────────────────────────────────────────────────────────────────────────────

const BACKEND_SECRET = process.env.BACKEND_SECRET_TOKEN || '';

/**
 * Middleware: require Authorization: Bearer <BACKEND_SECRET_TOKEN>
 * Skip auth check in development if no token is configured.
 */
function requireBackendAuth(req, res, next) {
  if (!BACKEND_SECRET) {
    // No token configured — allow in dev, warn in prod
    if (process.env.NODE_ENV === 'production') {
      return res.status(500).json({
        error: 'Server misconfiguration: BACKEND_SECRET_TOKEN not set',
      });
    }
    return next();
  }

  const authHeader = req.headers['authorization'] || '';
  const token      = authHeader.startsWith('Bearer ')
    ? authHeader.slice(7)
    : '';

  if (token !== BACKEND_SECRET) {
    return res.status(401).json({ error: 'Unauthorized' });
  }

  next();
}

module.exports = { requireBackendAuth };
