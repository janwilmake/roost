// The Roost website. Static pages come from ./public; this Worker adds three routes:
//   /buy       creates a Stripe Checkout session and sends the buyer there
//   /thanks    after payment: shows the license key, with a button that activates Roost
//   /download  the latest DMG on GitHub
// Secrets: STRIPE_SECRET_KEY (a restricted key with Checkout Sessions write is enough) and LICENSE_PRIVATE_KEY (the Ed25519 JWK).
import { newLicenseId, signLicense } from './license.js';

const STRIPE = 'https://api.stripe.com/v1';

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    if (url.hostname.startsWith('www.')) return Response.redirect(`https://${url.hostname.slice(4)}${url.pathname}${url.search}`, 301);
    try {
      if (url.pathname === '/buy') return await buy(url, env);
      if (url.pathname === '/thanks') return await thanks(url, env);
      if (url.pathname === '/download') return Response.redirect(env.DOWNLOAD_URL, 302);
    } catch (error) {
      console.error(error);
      return page('Something went wrong', `<p>${escape(error.message)}</p><p class="muted">Nothing was charged twice. Try again, or open an issue on <a href="https://github.com/janwilmake/roost/issues">GitHub</a>.</p>`, 500);
    }
    return env.ASSETS.fetch(request);
  },
};

async function buy(url, env) {
  if (!env.STRIPE_SECRET_KEY || !env.LICENSE_PRIVATE_KEY) {
    return page('Checkout opens soon', '<p>Roost is not for sale yet. The free trial works today.</p><p><a class="button" href="/download">Download Roost</a></p>', 503);
  }
  const licenseId = newLicenseId();
  // The key exists before payment so the Stripe receipt can carry it. The buyer sees it only once the session is paid.
  const licenseKey = await signLicense(licenseId, env.LICENSE_PRIVATE_KEY);
  const tax = env.STRIPE_TAX === 'on';
  const session = await stripe(env, 'POST', '/checkout/sessions', {
    mode: 'payment',
    line_items: [{
      quantity: 1,
      price_data: {
        currency: env.CURRENCY || 'usd',
        unit_amount: Number(env.PRICE_CENTS || 4900),
        ...(tax ? { tax_behavior: 'inclusive' } : {}),
        product_data: { name: 'Roost: personal license', description: 'Every Claude Code session on your strip, on all your Macs. Includes every 1.x update.' },
      },
    }],
    success_url: `${url.origin}/thanks?session_id={CHECKOUT_SESSION_ID}`,
    cancel_url: `${url.origin}/#pricing`,
    allow_promotion_codes: true,
    custom_text: { after_submit: { message: 'Your license key shows on the next page, and on your invoice.' } },
    metadata: { license_id: licenseId },
    payment_intent_data: { metadata: { license_id: licenseId } },
    invoice_creation: { enabled: true, invoice_data: { metadata: { license_id: licenseId }, footer: `Your Roost license key:\n${licenseKey}\n\nIn Roost: right-click the rooster, Enter License…, and paste the key.` } },
    ...(tax ? { automatic_tax: { enabled: true }, billing_address_collection: 'required', tax_id_collection: { enabled: true } } : {}),
  });
  return Response.redirect(session.url, 303);
}

async function thanks(url, env) {
  const id = url.searchParams.get('session_id') ?? '';
  if (!/^cs_(test|live)_[A-Za-z0-9]+$/.test(id)) return page('No purchase found', '<p>This link has no purchase in it.</p><p><a class="button" href="/">Back to Roost</a></p>', 400);
  if (!env.STRIPE_SECRET_KEY || !env.LICENSE_PRIVATE_KEY) return page('Checkout opens soon', '<p>Roost is not for sale yet.</p>', 503);
  const session = await stripe(env, 'GET', `/checkout/sessions/${id}`);
  const licenseId = session.metadata?.license_id;
  if (!['paid', 'no_payment_required'].includes(session.payment_status) || !licenseId) {
    return page('Payment not finished', '<p>Stripe has not confirmed this payment yet. Reload this page in a minute.</p>', 402);
  }
  const key = await signLicense(licenseId, env.LICENSE_PRIVATE_KEY);
  const email = session.customer_details?.email;
  return page('Thank you!', `
    <p>Here is your license key${email ? `. Stripe also sends it to <strong>${escape(email)}</strong> with your receipt` : ''}.</p>
    <div class="key" id="key">${key}</div>
    <p><button class="copy" onclick="navigator.clipboard.writeText(document.getElementById('key').textContent);this.textContent='Copied'">Copy key</button></p>
    <p><a class="button" href="roost://activate?key=${key}">Activate in Roost</a></p>
    <p class="muted">Bookmark this page: it shows your key again. The button works when Roost is installed. Or right-click the rooster, choose Enter License…, and paste the key.
    No Roost yet? <a href="/download">Download it</a>.</p>`);
}

async function stripe(env, method, path, params) {
  const response = await fetch(`${STRIPE}${path}`, {
    method,
    headers: { authorization: `Bearer ${env.STRIPE_SECRET_KEY}`, 'content-type': 'application/x-www-form-urlencoded', 'stripe-version': '2024-06-20' },
    body: params ? form(params).toString() : undefined,
  });
  const body = await response.json();
  if (!response.ok) throw new Error(`Stripe: ${body.error?.message ?? response.status}`);
  return body;
}

/** Stripe's form encoding: nested objects and arrays become key[sub][0]=value. */
export function form(params, prefix = '', out = new URLSearchParams()) {
  for (const [key, value] of Object.entries(params)) {
    const name = prefix ? `${prefix}[${key}]` : key;
    if (value === undefined || value === null) continue;
    if (typeof value === 'object') form(value, name, out);
    else out.append(name, String(value));
  }
  return out;
}

const escape = (text) => String(text).replace(/[&<>"']/g, (char) => `&#${char.charCodeAt(0)};`);

function page(title, body, status = 200) {
  const html = `<!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>${escape(title)} · Roost</title><link rel="icon" href="/favicon.svg"><link rel="stylesheet" href="/style.css"><meta name="robots" content="noindex"></head>
<body class="card-page"><main class="card"><a href="/" class="muted">← Roost</a><h1>${escape(title)}</h1>${body}</main></body></html>`;
  return new Response(html, { status, headers: { 'content-type': 'text/html; charset=utf-8', 'cache-control': 'no-store' } });
}
