// piprapay-backend/src/routes/piprapay.js
// ─────────────────────────────────────────────────────────────────────────────
// Express router for PipraPay operations called by the Flutter app.
//
// Endpoints:
//   GET  /api/piprapay/ping              — connection test
//   POST /api/piprapay/create-charge     — initiate a payment
//   POST /api/piprapay/verify-payment    — verify by pp_id
//   GET  /api/piprapay/transaction/:ppId — fetch transaction status
// ─────────────────────────────────────────────────────────────────────────────

const express = require('express');
const { v4: uuidv4 } = require('uuid');

const { requireBackendAuth } = require('../middleware/auth');
const pipraClient             = require('../utils/piprapay_client');
const txnLog                  = require('../utils/txn_log');
const logger                  = require('../utils/logger');

const router = express.Router();

// All routes require backend auth
router.use(requireBackendAuth);

// ── Ping ──────────────────────────────────────────────────────────────────────
router.get('/ping', (req, res) => {
  res.json({
    status:    'ok',
    sandbox:   pipraClient.isSandbox,
    baseUrl:   pipraClient.BASE_URL,
    timestamp: new Date().toISOString(),
  });
});

// ── Create Charge ─────────────────────────────────────────────────────────────
router.post('/create-charge', async (req, res) => {
  const {
    orderId,
    fullName,
    emailOrMobile,
    amount,
    currency     = 'BDT',
    redirectUrl,
    cancelUrl,
    webhookUrl,
    metadata     = {},
  } = req.body;

  // Validate required fields
  if (!fullName || !emailOrMobile || !amount) {
    return res.status(400).json({
      error: 'fullName, emailOrMobile, and amount are required',
    });
  }

  const effectiveOrderId = orderId || uuidv4();

  try {
    const result = await pipraClient.createCharge({
      fullName,
      emailOrMobile,
      amount,
      currency,
      redirectUrl:  redirectUrl  || process.env.DEFAULT_REDIRECT_URL,
      cancelUrl:    cancelUrl    || process.env.DEFAULT_CANCEL_URL,
      webhookUrl:   webhookUrl   || process.env.DEFAULT_WEBHOOK_URL,
      metadata:     { ...metadata, order_id: effectiveOrderId },
    });

    // Log transaction
    await txnLog.save({
      orderId:     effectiveOrderId,
      invoiceId:   result.invoiceId,
      ppId:        result.ppId,
      amount,
      currency,
      status:      'initiated',
      createdAt:   new Date().toISOString(),
    });

    logger.info(`Charge created: orderId=${effectiveOrderId} invoiceId=${result.invoiceId}`);

    return res.json({
      checkoutUrl: result.checkoutUrl,
      invoiceId:   result.invoiceId,
      ppId:        result.ppId,
      orderId:     effectiveOrderId,
    });
  } catch (err) {
    logger.error(`createCharge failed: ${err.message}`);
    return res.status(502).json({
      error:   'Failed to create charge',
      details: err.response?.data || err.message,
    });
  }
});

// ── Verify Payment ────────────────────────────────────────────────────────────
router.post('/verify-payment', async (req, res) => {
  const { ppId } = req.body;

  if (!ppId) {
    return res.status(400).json({ error: 'ppId is required' });
  }

  try {
    const data = await pipraClient.verifyPayment(ppId);

    // Update transaction log
    await txnLog.update(ppId, {
      status:        data.status,
      paymentMethod: data.payment_method,
      verifiedAt:    new Date().toISOString(),
    });

    logger.info(`Payment verified: pp_id=${ppId} status=${data.status}`);

    return res.json(data);
  } catch (err) {
    logger.error(`verifyPayment failed: ${err.message}`);
    return res.status(502).json({
      error:   'Failed to verify payment',
      details: err.response?.data || err.message,
    });
  }
});

// ── Fetch Transaction Status ──────────────────────────────────────────────────
router.get('/transaction/:ppId', async (req, res) => {
  const { ppId } = req.params;

  try {
    // First check local log
    const local = await txnLog.find(ppId);

    // Then verify with PipraPay for fresh status
    const data = await pipraClient.verifyPayment(ppId);

    return res.json({
      ...data,
      localRecord: local || null,
    });
  } catch (err) {
    logger.error(`fetchStatus failed: ${err.message}`);
    return res.status(502).json({
      error:   'Failed to fetch transaction status',
      details: err.response?.data || err.message,
    });
  }
});

module.exports = router;
