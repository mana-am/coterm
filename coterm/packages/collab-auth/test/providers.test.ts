import { describe, expect, test } from "bun:test";
import { HmacAuthProvider } from "../src/hmacProvider";
import { NoAuthProvider } from "../src/noAuthProvider";
import { base64urlEncodeBytes, signCotermToken } from "../src/hmac";
import { nowSeconds } from "../src/common";

const SECRET = "provider-secret";

function requestWithBearer(token: string, url = "https://cp.local/api/collab/inbox"): Request {
  return new Request(url, { headers: { authorization: `Bearer ${token}` } });
}

function localGuestAccessToken(claims: Record<string, unknown>): string {
  const payload = base64urlEncodeBytes(new TextEncoder().encode(JSON.stringify(claims)));
  return `cotermv1.${payload}.guest`;
}

describe("HmacAuthProvider", () => {
  test("mints and verifies a grant", async () => {
    const p = new HmacAuthProvider({ secret: SECRET });
    const grant = await p.mintGrant({ room: "ABCD1234", userId: "u1", iat: nowSeconds(), exp: nowSeconds() + 900 });
    const claims = await p.verifyGrant(grant);
    expect(claims?.room).toBe("ABCD1234");
    expect(claims?.userId).toBe("u1");
  });

  test("mints and verifies a session descriptor", async () => {
    const p = new HmacAuthProvider({ secret: SECRET });
    const desc = await p.mintSessionDescriptor({
      room: "ABCD1234",
      ownerUserId: "owner",
      orgId: "org1",
      code: "ABCD1234",
      relayURL: "http://localhost:8787",
      createdAt: nowSeconds(),
    });
    const claims = await p.verifySessionDescriptor(desc);
    expect(claims?.ownerUserId).toBe("owner");
    expect(claims?.room).toBe("ABCD1234");
  });

  test("a grant cannot be verified as a descriptor and vice versa", async () => {
    const p = new HmacAuthProvider({ secret: SECRET });
    const grant = await p.mintGrant({ room: "ABCD1234", userId: "u1", iat: nowSeconds(), exp: nowSeconds() + 900 });
    expect(await p.verifySessionDescriptor(grant)).toBeNull();
    const desc = await p.mintSessionDescriptor({ room: "ABCD1234", ownerUserId: "o", orgId: "org", createdAt: nowSeconds() });
    expect(await p.verifyGrant(desc)).toBeNull();
  });

  test("authorizeRelayConnect accepts a matching grant", async () => {
    const p = new HmacAuthProvider({ secret: SECRET });
    const grant = await p.mintGrant({ room: "ABCD1234", userId: "u1", iat: nowSeconds(), exp: nowSeconds() + 900 });
    expect(await p.authorizeRelayConnect({ room: "ABCD1234", grant })).toMatchObject({ ok: true });
  });

  test("authorizeRelayConnect rejects missing/expired/mismatched grants", async () => {
    const p = new HmacAuthProvider({ secret: SECRET });
    expect(await p.authorizeRelayConnect({ room: "ABCD1234", grant: null })).toMatchObject({ ok: false });
    const expired = await p.mintGrant({ room: "ABCD1234", userId: "u1", iat: nowSeconds() - 2000, exp: nowSeconds() - 1 });
    expect(await p.authorizeRelayConnect({ room: "ABCD1234", grant: expired })).toMatchObject({ ok: false });
    const other = await p.mintGrant({ room: "ZZZZ9999", userId: "u1", iat: nowSeconds(), exp: nowSeconds() + 900 });
    expect(await p.authorizeRelayConnect({ room: "ABCD1234", grant: other })).toMatchObject({ ok: false });
  });

  test("authenticateRequest verifies a cotermv1 access token", async () => {
    const p = new HmacAuthProvider({ secret: SECRET });
    const token = await signCotermToken(
      { kind: "access", userId: "u42", teamIds: ["org1"], selectedTeamId: "org1", exp: nowSeconds() + 900 },
      SECRET,
    );
    const principal = await p.authenticateRequest(requestWithBearer(token));
    expect(principal?.userId).toBe("u42");
    expect(principal?.orgIds).toEqual(["org1"]);
  });

  test("authenticateRequest accepts a local guest access token but still signs grants", async () => {
    const p = new HmacAuthProvider({ secret: SECRET });
    const token = localGuestAccessToken({
      kind: "access",
      userId: "guest-alice",
      teamIds: [],
      exp: nowSeconds() + 900,
    });
    const principal = await p.authenticateRequest(requestWithBearer(token));
    expect(principal?.userId).toBe("guest-alice");

    const grant = await p.mintGrant({
      room: "ABCD1234",
      userId: "guest-alice",
      iat: nowSeconds(),
      exp: nowSeconds() + 900,
    });
    expect(grant.endsWith(".guest")).toBe(false);
    expect(await p.authorizeRelayConnect({ room: "ABCD1234", grant })).toMatchObject({ ok: true });
  });

  test("authenticateRequest rejects refresh tokens and unsigned tokens", async () => {
    const p = new HmacAuthProvider({ secret: SECRET });
    const refresh = await signCotermToken({ kind: "refresh", userId: "u1", exp: nowSeconds() + 900 }, SECRET);
    expect(await p.authenticateRequest(requestWithBearer(refresh))).toBeNull();
    const wrongSecret = await signCotermToken({ kind: "access", userId: "u1", exp: nowSeconds() + 900 }, "nope");
    expect(await p.authenticateRequest(requestWithBearer(wrongSecret))).toBeNull();
    const guestRefresh = localGuestAccessToken({ kind: "refresh", userId: "u1", exp: nowSeconds() + 900 });
    expect(await p.authenticateRequest(requestWithBearer(guestRefresh))).toBeNull();
  });
});

describe("NoAuthProvider", () => {
  test("authorizeRelayConnect requires a grant even in noauth mode", async () => {
    const p = new NoAuthProvider();
    expect(await p.authorizeRelayConnect({ room: "ABCD1234", grant: null })).toMatchObject({ ok: false });
    const grant = await p.mintGrant({ room: "ABCD1234", userId: "u1", iat: nowSeconds(), exp: nowSeconds() + 900 });
    expect(await p.authorizeRelayConnect({ room: "ABCD1234", grant })).toMatchObject({ ok: true });
  });

  test("authenticateRequest decodes an unverified bearer token", async () => {
    const p = new NoAuthProvider();
    const token = await signCotermToken({ userId: "guest", teamIds: ["t1"] }, "any-secret");
    const principal = await p.authenticateRequest(requestWithBearer(token));
    expect(principal?.userId).toBe("guest");
    expect(principal?.orgIds).toEqual(["t1"]);
  });

  test("authenticateRequest falls back to query/header/anon", async () => {
    const p = new NoAuthProvider();
    const fromQuery = await p.authenticateRequest(new Request("https://cp.local/x?userId=alice&orgId=team1"));
    expect(fromQuery?.userId).toBe("alice");
    expect(fromQuery?.orgIds).toEqual(["team1"]);
    const anon = await p.authenticateRequest(new Request("https://cp.local/x"));
    expect(anon?.userId).toBe("anon");
  });

  test("descriptor round-trips without a signature", async () => {
    const p = new NoAuthProvider();
    const desc = await p.mintSessionDescriptor({ room: "ABCD1234", ownerUserId: "o", orgId: "org", createdAt: nowSeconds() });
    const claims = await p.verifySessionDescriptor(desc);
    expect(claims?.room).toBe("ABCD1234");
  });
});
