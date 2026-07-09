// WebCrypto port of the `mosaicv1` token format from
// web/services/auth/nativeSession.ts. The output is byte-identical to the Node
// implementation, so an access token minted by the upstream www service verifies
// here and vice versa:
//
//   mosaicv1.<base64url(utf8 JSON claims)>.<base64url(HMAC-SHA256(payload, secret))>
//
// where the signed message is the base64url payload STRING (ASCII), exactly as
// `createHmac("sha256", secret).update(payload).digest("base64url")` does.

const TOKEN_PREFIX = "mosaicv1";

export function base64urlEncodeBytes(bytes: Uint8Array): string {
  let binary = "";
  for (let i = 0; i < bytes.length; i += 1) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

export function base64urlDecodeToBytes(value: string): Uint8Array {
  const normalized = value.replace(/-/g, "+").replace(/_/g, "/");
  const padLength = normalized.length % 4 === 0 ? 0 : 4 - (normalized.length % 4);
  const binary = atob(normalized + "=".repeat(padLength));
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i += 1) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}

function base64urlEncodeJSON(value: unknown): string {
  return base64urlEncodeBytes(new TextEncoder().encode(JSON.stringify(value)));
}

async function hmacSha256Base64url(secret: string, payload: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(payload));
  return base64urlEncodeBytes(new Uint8Array(signature));
}

/// Constant-time string comparison over the raw byte encodings.
export function constantTimeEqual(a: string, b: string): boolean {
  const left = new TextEncoder().encode(a);
  const right = new TextEncoder().encode(b);
  if (left.length !== right.length) return false;
  let diff = 0;
  for (let i = 0; i < left.length; i += 1) {
    diff |= left[i] ^ right[i];
  }
  return diff === 0;
}

/// Sign an arbitrary claims object into a `mosaicv1.<payload>.<sig>` token.
export async function signMosaicToken(claims: unknown, secret: string): Promise<string> {
  const payload = base64urlEncodeJSON(claims);
  const signature = await hmacSha256Base64url(secret, payload);
  return `${TOKEN_PREFIX}.${payload}.${signature}`;
}

/// Verify a `mosaicv1` token's signature and return its decoded payload. Does NOT
/// enforce expiry — callers apply their own `exp` policy.
export async function verifyMosaicToken<T = unknown>(
  token: string,
  secret: string,
): Promise<T | null> {
  const parts = token.split(".");
  if (parts.length !== 3 || parts[0] !== TOKEN_PREFIX) return null;
  const [, payloadPart, signaturePart] = parts;
  const expected = await hmacSha256Base64url(secret, payloadPart);
  if (!constantTimeEqual(signaturePart, expected)) return null;
  return decodeMosaicPayload<T>(token);
}

/// Decode a `mosaicv1` token's payload WITHOUT verifying its signature. Used by
/// NoAuthProvider (best-effort identity) and to read a token's `exp` for deadlines.
export function decodeMosaicPayload<T = unknown>(token: string): T | null {
  const parts = token.split(".");
  if (parts.length !== 3 || parts[0] !== TOKEN_PREFIX) return null;
  try {
    return JSON.parse(new TextDecoder().decode(base64urlDecodeToBytes(parts[1]))) as T;
  } catch {
    return null;
  }
}
