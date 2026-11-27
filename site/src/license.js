// A license key is "ROOST1-<id>-<signature>": the base64url Ed25519 signature of "roost1:<id>", where <id> is 32 hex digits.
// The app checks it offline with the public key. The same code runs in the Worker and in Node.

const toBase64Url = (bytes) => btoa(String.fromCharCode(...new Uint8Array(bytes))).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');

export function newLicenseId() {
  return [...crypto.getRandomValues(new Uint8Array(16))].map((byte) => byte.toString(16).padStart(2, '0')).join('');
}

/** privateJwk: the Ed25519 private key as a JWK string or object. */
export async function signLicense(id, privateJwk) {
  if (!/^[0-9a-f]{32}$/.test(id)) throw new Error('A license id is 32 hex digits.');
  const jwk = typeof privateJwk === 'string' ? JSON.parse(privateJwk) : privateJwk;
  const key = await crypto.subtle.importKey('jwk', jwk, { name: 'Ed25519' }, false, ['sign']);
  const signature = await crypto.subtle.sign({ name: 'Ed25519' }, key, new TextEncoder().encode(`roost1:${id}`));
  return `ROOST1-${id}-${toBase64Url(signature)}`;
}

/** publicJwk: the Ed25519 public key as a JWK. Returns the license id, or null. */
export async function verifyLicense(licenseKey, publicJwk) {
  const match = /^ROOST1-([0-9a-f]{32})-([A-Za-z0-9_-]{86})$/.exec(licenseKey.trim());
  if (!match) return null;
  const key = await crypto.subtle.importKey('jwk', publicJwk, { name: 'Ed25519' }, false, ['verify']);
  const signature = Uint8Array.from(atob(match[2].replace(/-/g, '+').replace(/_/g, '/')), (char) => char.charCodeAt(0));
  const valid = await crypto.subtle.verify({ name: 'Ed25519' }, key, signature, new TextEncoder().encode(`roost1:${match[1]}`));
  return valid ? match[1] : null;
}
