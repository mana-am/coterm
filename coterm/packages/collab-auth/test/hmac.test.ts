import { describe, expect, test } from "bun:test";
import { createHmac } from "node:crypto";
import {
  constantTimeEqual,
  decodeMosaicPayload,
  signMosaicToken,
  verifyMosaicToken,
} from "../src/hmac";

const SECRET = "test-secret-0123456789";

describe("mosaicv1 hmac", () => {
  test("signs and verifies a round trip", async () => {
    const claims = { kind: "access", userId: "u1", exp: 9999999999 };
    const token = await signMosaicToken(claims, SECRET);
    expect(token.startsWith("mosaicv1.")).toBe(true);
    const decoded = await verifyMosaicToken<typeof claims>(token, SECRET);
    expect(decoded).toEqual(claims);
  });

  test("is byte-compatible with node createHmac base64url", async () => {
    const claims = { hello: "world", n: 42 };
    const token = await signMosaicToken(claims, SECRET);
    const [, payloadPart, signaturePart] = token.split(".");
    const nodeSig = createHmac("sha256", SECRET).update(payloadPart).digest("base64url");
    expect(signaturePart).toBe(nodeSig);
  });

  test("rejects a tampered payload", async () => {
    const token = await signMosaicToken({ userId: "u1" }, SECRET);
    const [prefix, payload, sig] = token.split(".");
    const tampered = `${prefix}.${payload}x.${sig}`;
    expect(await verifyMosaicToken(tampered, SECRET)).toBeNull();
  });

  test("rejects a wrong secret", async () => {
    const token = await signMosaicToken({ userId: "u1" }, SECRET);
    expect(await verifyMosaicToken(token, "other-secret")).toBeNull();
  });

  test("rejects a malformed token", async () => {
    expect(await verifyMosaicToken("not-a-token", SECRET)).toBeNull();
    expect(await verifyMosaicToken("mosaicv1.only-two", SECRET)).toBeNull();
  });

  test("decodeMosaicPayload reads claims without verifying", () => {
    const forged = "mosaicv1." + btoa(JSON.stringify({ userId: "u9" })).replace(/=+$/, "") + ".bad";
    const decoded = decodeMosaicPayload<{ userId: string }>(forged);
    expect(decoded?.userId).toBe("u9");
  });

  test("constantTimeEqual", () => {
    expect(constantTimeEqual("abc", "abc")).toBe(true);
    expect(constantTimeEqual("abc", "abd")).toBe(false);
    expect(constantTimeEqual("abc", "abcd")).toBe(false);
  });
});
