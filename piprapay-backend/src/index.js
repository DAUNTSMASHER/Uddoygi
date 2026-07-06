// piprapay-backend/src/index.js
// ─────────────────────────────────────────────────────────────────────────────
// Entry point — sets up Express, middleware, and mounts all routes.
// ─────────────────────────────────────────────────────────────────────────────

require('dotenv').config();

const express    = require('express');
const helmet     = require('helmet');
const cors       = require('cors');
const morgan     = require('morgan');
const rateLimit  = require('express-rate-limit');

const pipraRoutes   = require('./routes/piprapay');
const webhookRoutes = require('./routes/webhook');
const logger        = require('./utils/logger');

const app  = express();
const PORT = process.env.PORT || 3000;

// ── Security middleware ───────────────────────────────────────────────────────
app.use(helmet());

const allowedOrigins = (process.env.ALLOWED_ORIGINS || '')
  .split(',')
  .map(s => s.trim())
  .filter(Boolean);

app.use(cors({
  origin: (origin, cb) => {
    // Allow requests with no origin (mobile apps, Postman)
    if (!origin || allowedOrigins.includes(origin)) return cb(null, true);
    cb(new Error(`CORS: origin ${origin} not allowed`));
  },
  methods: ['GET', 'POST', 'OPTIONS'],
  allowedHeaders: ['Content-Type', 'Authorization'],
}));

// ── Rate limiting ─────────────────────────────────────────────────────────────
const limiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutes
  max:      100,
  message:  { error: 'Too many requests, please try again later.' },
});
app.use('/api/', limiter);

// ── Body parsing ──────────────────────────────────────────────────────────────
// Webhook endpoint needs raw body for signature validation
app.use('/api/piprapay/webhook', express.raw({ type: 'application/json' }));
app.use(express.json());
app.use(morgan('combined', { stream: { write: msg => logger.info(msg.trim()) } }));

// ── Routes ────────────────────────────────────────────────────────────────────
app.use('/api/piprapay', pipraRoutes);
app.use('/api/piprapay', webhookRoutes);

// ── Health check ──────────────────────────────────────────────────────────────
app.get('/health', (req, res) => res.json({ status: 'ok', ts: new Date() }));

// ── 404 ───────────────────────────────────────────────────────────────────────
app.use((req, res) => res.status(404).json({ error: 'Not found' }));

// ── Error handler ─────────────────────────────────────────────────────────────
app.use((err, req, res, _next) => {
  logger.error(err.message || err);
  res.status(500).json({ error: 'Internal server error' });
});

// ── Start ─────────────────────────────────────────────────────────────────────
app.listen(PORT, () => {
  logger.info(`PipraPay backend running on port ${PORT} [${process.env.NODE_ENV}]`);
  logger.info(`Sandbox mode: ${process.env.PIPRAPAY_SANDBOX === 'true'}`);
});

module.exports = app; // for tests
