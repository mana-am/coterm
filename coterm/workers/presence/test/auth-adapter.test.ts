import { describe, expect, test } from "bun:test";
import { signMosaicToken, nowSeconds } from "@coterm/collab-auth";
import {
  cacheDeadline,
  requestedTeamIdFromRequest,
  resolveTeamId,
  subscribeExpiryMs,
  verifyRequest,
  type AuthedUser,
} from "../src/auth-adapter";

const SECRET = "presence-secret";

describe("pure helpers", () => {
  test("cacheDeadline never exceeds token expiry", () => {
    expect(cacheDeadline(1000, 1500, 60_000)).toBe(1500);
    expect(cacheDeadline(1000, null, 60_000)).toBe(61_000);
  });

  test("resolveTeamId enforces membership and defaults", () => {
    const user: AuthedUser = { id: "u1", selectedTeamId: "t1", teamIds: ["t1", "t2"] };
    expect(resolveTeamId("t2", user)).toEqual({ ok: true, teamId: "t2" });
    expect(resolveTeamId("t9", user)).toEqual({ ok: false, error: "team_not_found" });
    expect(resolveTeamId(null, user)).toEqual({ ok: true, teamId: "t1" });
    expect(resolveTeamId("u1", { id: "u1", selectedTeamId: null, teamIds: [] })).toEqual({ ok: true, teamId: "u1" });
  });

  test("requestedTeamIdFromRequest reads header then query", () => {
    const fromHeader = new Request("https://p.local/x", { headers: { "x-mosaic-team-id": "teamH" } });
    expect(requestedTeamIdFromRequest(fromHeader)).toBe("teamH");
    const fromQuery = new Request("https://p.local/x?teamId=teamQ");
    expect(requestedTeamIdFromRequest(fromQuery)).toBe("teamQ");
  });
});

describe("verifyRequest (hmac mode)", () => {
  const env = { COLLAB_AUTH_MODE: "hmac", COLLAB_AUTH_SECRET: SECRET };

  test("maps a valid access token to an AuthedUser", async () => {
    const token = await signMosaicToken(
      { kind: "access", userId: "u1", teamIds: ["t1"], selectedTeamId: "t1", exp: nowSeconds() + 900 },
      SECRET,
    );
    const request = new Request("https://p.local/v1/presence/snapshot", { headers: { authorization: `Bearer ${token}` } });
    const user = await verifyRequest(request, env);
    expect(user).toEqual({ id: "u1", selectedTeamId: "t1", teamIds: ["t1"] });
    expect(subscribeExpiryMs(request, env)).toBeGreaterThan(Date.now());
  });

  test("rejects an unauthenticated request", async () => {
    const request = new Request("https://p.local/v1/presence/snapshot");
    expect(await verifyRequest(request, env)).toBeNull();
  });
});

describe("verifyRequest (noauth mode)", () => {
  const env = { COLLAB_AUTH_MODE: "noauth" };

  test("synthesizes a best-effort identity from query params", async () => {
    const request = new Request("https://p.local/v1/presence/heartbeat?userId=alice&teamId=team1");
    const user = await verifyRequest(request, env);
    expect(user?.id).toBe("alice");
    expect(user?.teamIds).toEqual(["team1"]);
  });
});
