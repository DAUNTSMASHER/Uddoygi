// piprapay-backend/src/routes/webhook.js
// ─────────────────────────────────────────────────────────────────────────────
// Handles PipraPay server-to-server webhook notifications.
//
// PipraPay webhook validation:
//   - Check the `mh-piprapay-api-key` header matches your API key.
//   - Respond 200 quickly; process async.
//   - Use pp_id as idempotency key.
//
// Endpoint: POST /api/piprapay/webhook
// ─────────────────────────────────────────────────────────────────────────────

const express = require('express');
const txnLog  = require('../utils/txn_log');
const logger  = require('../utils/logger');

const router = express.Router();

const PIPRAPAY_API_KEY = process.env.PIPRAPAY_API_KEY || '';

// ── Webhook ───────────────────────────────────────────────────────────────────
router.post('/webhook', (req, res) => {
  // 1. Validate API key header (PipraPay's webhook auth mechanism)
  const receivedKey =
    req.headers['mh-piprapay-api-key'] ||
    req.headers['Mh-Piprapay-Api-Key']  ||
    '';

  if (!PIPRAPAY_API_KEY || receivedKey !== PIPRAPAY_API_KEY) {
    logger.warn(`Webhook rejected: invalid API key header. received="${receivedKey}"`);
    return res.status(401).json({ status: false, message: 'Unauthorized request.' });
  }

  // 2. Parse body (raw buffer from express.raw middleware in index.js)
  let data;
  try {
    const raw = Buffer.isBuffer(req.body) ? req.body.toString('utf8') : JSON.stringify(req.body);
    data = JSON.parse(raw);
  } catch (e) {
    logger.error(`Webhook: failed to parse body — ${e.message}`);
    return res.status(400).json({ status: false, message: 'Invalid JSON body.' });
  }

  // 3. ACK immediately (PipraPay expects a fast 200)
  res.status(200).json({ status: true, message: 'Webhook received' });

  // 4. Process asynchronously
  setImmediate(() => _processWebhook(data));
});

// ── Async processor ───────────────────────────────────────────────────────────
async function _processWebhook(data) {
  const {
    pp_id,
    customer_name,
    customer_email_mobile,
    payment_method,
    amount,
    fee,
    refund_amount,
    total,
    currency,
    status,
    date,
    metadata,
    sender_number,
    transaction_id,
  } = data;

  logger.info(`Webhook received: pp_id=${pp_id} status=${status} amount=${amount} ${currency}`);

  if (!pp_id) {
    logger.warn('Webhook: missing pp_id — skipping');
    return;
  }

  try {
    // Idempotency: check if already processed
    const existing = await txnLog.find(pp_id);
    if (existing?.webhookProcessed) {
      logger.info(`Webhook: pp_id=${pp_id} already processed — skipping`);
      return;
    }

    // Update transaction log
    await txnLog.update(pp_id, {
      status,
      paymentMethod:   payment_method,
      amount,
      fee,
      refundAmount:    refund_amount,
      total,
      currency,
      senderNumber:    sender_number,
      transactionId:   transaction_id,
      customerName:    customer_name,
      emailOrMobile:   customer_email_mobile,
      metadata:        metadata || {},
      paidAt:          status === 'completed' ? new Date().toISOString() : null,
      webhookProcessed: true,
      webhookDate:     date,
      webhookReceivedAt: new Date().toISOString(),
    });

    logger.info(`Webhook processed: pp_id=${pp_id} status=${status}`);

    // ── TODO: Add your business logic here ───────────────────────────────
    // e.g. update Firestore, send notification, fulfill order, etc.
    // Example:
    //   if (status === 'completed') {
    //     await fulfillOrder(metadata?.order_id, { pp_id, amount, currency });
    //   }
    // ─────────────────────────────────────────────────────────────────────
  } catch (err) {
    logger.error(`Webhook processing error for pp_id=${pp_id}: ${err.message}`);
  }
}

module.exports = router;
