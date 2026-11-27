import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { generateKeyPairSync } from 'node:crypto';
import worker, { form } from '../src/worker.js';
import { verifyLicense } from '../src/license.js';

const { publicKey, privateKey } = generateKeyPairSync('ed25519');
const env = {
  STRIPE_SECRET_KEY: 'rk_test_x',
  LICENSE_PRIVATE_KEY: JSON.stringify(privateKey.export({ format: 'jwk' })),
  PRICE_CENTS: '4900',
  DOWNLOAD_URL: 'https://github.com/janwilmake/roost/releases/latest/download/Roost.dmg',
  ASSETS: { fetch: async () => new Response('static') },
};
const publicJwk = publicKey.export({ format: 'jwk' });

function stubStripe(handler) {
  const calls = [];
  globalThis.fetch = async (url, init) => {
    calls.push({ url, init });
    return new Response(JSON.stringify(handler(url, init)), { status: 200 });
  };
  return calls;
}

test('form encodes nested params the way Stripe reads them', () => {
  assert.equal(form({ a: 1, b: { c: 'x' }, d: [{ e: 2 }], f: undefined }).toString(), 'a=1&b%5Bc%5D=x&d%5B0%5D%5Be%5D=2');
});

test('/buy creates a session with a signed key on the invoice and redirects', async () => {
  const calls = stubStripe(() => ({ url: 'https://checkout.stripe.com/c/pay/cs_test_1' }));
  const response = await worker.fetch(new Request('https://roost.test/buy'), env);
  assert.equal(response.status, 303);
  assert.equal(response.headers.get('location'), 'https://checkout.stripe.com/c/pay/cs_test_1');
  const body = new URLSearchParams(calls[0].init.body);
  assert.equal(body.get('line_items[0][price_data][unit_amount]'), '4900');
  assert.equal(body.get('success_url'), 'https://roost.test/thanks?session_id={CHECKOUT_SESSION_ID}');
  const key = /ROOST1-\S+/.exec(body.get('invoice_creation[invoice_data][footer]'))[0];
  assert.equal(await verifyLicense(key, publicJwk), body.get('metadata[license_id]'));
  assert.equal(body.get('automatic_tax[enabled]'), null);
});

test('/buy turns on Stripe Tax when asked', async () => {
  const calls = stubStripe(() => ({ url: 'https://checkout.stripe.com/x' }));
  await worker.fetch(new Request('https://roost.test/buy'), { ...env, STRIPE_TAX: 'on' });
  const body = new URLSearchParams(calls[0].init.body);
  assert.equal(body.get('automatic_tax[enabled]'), 'true');
  assert.equal(body.get('line_items[0][price_data][tax_behavior]'), 'inclusive');
});

test('/buy without Stripe says checkout opens soon', async () => {
  const response = await worker.fetch(new Request('https://roost.test/buy'), { ...env, STRIPE_SECRET_KEY: '' });
  assert.equal(response.status, 503);
});

test('/thanks shows the same key once paid', async () => {
  const id = 'a'.repeat(32);
  stubStripe(() => ({ payment_status: 'paid', metadata: { license_id: id }, customer_details: { email: 'buyer@test.dev' } }));
  const response = await worker.fetch(new Request('https://roost.test/thanks?session_id=cs_test_abc'), env);
  const html = await response.text();
  assert.equal(response.status, 200);
  const key = /ROOST1-[0-9a-f]{32}-[A-Za-z0-9_-]{86}/.exec(html)[0];
  assert.equal(await verifyLicense(key, publicJwk), id);
  assert.match(html, /roost:\/\/activate\?key=ROOST1-/);
});

test('/thanks shows no key before payment, and rejects odd ids', async () => {
  stubStripe(() => ({ payment_status: 'unpaid', metadata: { license_id: 'a'.repeat(32) } }));
  const unpaid = await worker.fetch(new Request('https://roost.test/thanks?session_id=cs_test_abc'), env);
  assert.equal(unpaid.status, 402);
  assert.doesNotMatch(await unpaid.text(), /ROOST1-/);
  const odd = await worker.fetch(new Request('https://roost.test/thanks?session_id=../../v1/charges'), env);
  assert.equal(odd.status, 400);
});

test('/download points at the latest DMG, and other paths are static', async () => {
  const download = await worker.fetch(new Request('https://roost.test/download'), env);
  assert.equal(download.headers.get('location'), env.DOWNLOAD_URL);
  assert.equal(await (await worker.fetch(new Request('https://roost.test/'), env)).text(), 'static');
});

test('the public key in the app matches the seller key file', () => {
  const swift = readFileSync(new URL('../../app/main.swift', import.meta.url), 'utf8');
  const embedded = /rawRepresentation: Data\(base64Encoded: "([^"]+)"/.exec(swift)[1];
  const home = process.env.HOME;
  let seller;
  try { seller = JSON.parse(readFileSync(`${home}/.roost-seller/license-public.jwk`, 'utf8')).x; } catch { return; }
  assert.equal(Buffer.from(embedded, 'base64').toString('base64url'), seller);
});
