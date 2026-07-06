// piprapay-backend/src/utils/piprapay_client.js
// ─────────────────────────────────────────────────────────────────────────────
// Thin wrapper around PipraPay REST API.
// The API key lives ONLY here, loaded from process.env.
// ─────────────────────────────────────────────────────────────────────────────

const axios  = require('axios');
const logger = require('./logger');

const isSandbox  = process.env.PIPRAPAY_SANDBOX === 'true';
const BASE_URL   = isSandbox
  ? (process.env.PIPRAPAY_SANDBOX_URL    || 'https://sandbox.piprapay.com')
  : (process.env.PIPRAPAY_PRODUCTION_URL || 'https://pay.yourdomain.com');

const API_KEY = process.env.PIPRAPAY_API_KEY || '';

if (!API_KEY) {
  logger.warn('PIPRAPAY_API_KEY is not set — all API calls will fail.');
}

const client = axios.create({
  baseURL: BASE_URL,
  headers: {
    'accept':               'application/json',
    'content-type':         'application/json',
    'mh-piprapay-api-key':  API_KEY,
  },
  timeout: 20000,
});

// ── Create Charge ─────────────────────────────────────────────────────────────
/**
 * @param {object} params
 * @param {string} params.fullName
 * @param {string} params.emailOrMobile
 * @param {string|number} params.amount
 * @param {string} params.currency
 * @param {string} params.redirectUrl
 * @param {string} params.cancelUrl
 * @param {string} params.webhookUrl
 * @param {object} [params.metadata]
 * @returns {Promise<{checkoutUrl: string, invoiceId: string, ppId: string, raw: object}>}
 */
async function createCharge(params) {
  const payload = {
    full_name:    params.fullName,
    email_mobile: params.emailOrMobile,
    amount:       String(params.amount),
    currency:     params.currency || 'BDT',
    redirect_url: params.redirectUrl,
    return_type:  'POST',
    cancel_url:   params.cancelUrl,
    webhook_url:  params.webhookUrl,
    metadata:     params.metadata || {},
  };

  logger.info(`createCharge → ${BASE_URL}/api/create-charge`, { orderId: params.metadata?.order_id });

  const resp = await client.post('/api/create-charge', payload);
  const data = resp.data;

  return {
    checkoutUrl: data.payment_url || data.checkout_url || data.url || '',
    invoiceId:   data.invoice_id  || data.invoiceId    || '',
    ppId:        data.pp_id       || data.ppId         || '',
    raw:         data,
  };
}

// ── Verify Payment ────────────────────────────────────────────────────────────
/**
 * @param {string} ppId
 * @returns {Promise<object>} Full PipraPay payment details
 */
async function verifyPayment(ppId) {
  logger.info(`verifyPayment → pp_id=${ppId}`);
  const resp = await client.post('/api/verify-payments', { pp_id: ppId });
  return resp.data;
}

module.exports = { createCharge, verifyPayment, BASE_URL, isSandbox };
