import { describe, expect, test } from "bun:test";
import { NextRequest } from "next/server";

const { makeNativeSignInHandler } = await import("../app/handler/native-sign-in/route");

const GET = makeNativeSignInHandler({
  getAuth: async () => ({ userId: "user_1" }),
});

describe("native sign-in handoff route", () => {
  test("is disabled for the self-hosted Coterm distribution", async () => {
    const afterSignIn = new URL("https://coterm.test/handler/after-sign-in");
    afterSignIn.searchParams.set(
      "native_app_return_to",
      "coterm-dev://auth-callback?coterm_auth_state=state-123"
    );

    const response = await GET(
      new NextRequest(
        `https://coterm.test/handler/native-sign-in?after_auth_return_to=${encodeURIComponent(afterSignIn.toString())}`
      )
    );

    expect(response.status).toBe(404);
    expect(response.headers.get("location")).toBeNull();
    expect(response.headers.get("set-cookie")).toBeNull();
  });
});
