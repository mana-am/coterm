import { describe, expect, test } from "bun:test";
import { resolveVmImage } from "../services/vms/images/resolver";
import { VmImageConfigError } from "../services/vms/errors";

describe("VM image resolver", () => {
  test("uses manifest local defaults outside deployed runtimes", () => {
    expect(resolveVmImage("e2b", undefined, {})).toMatchObject({
      provider: "e2b",
      image: "cotermd-ws:tooling-20260509f",
      imageVersion: "e2b-tooling-20260509f",
    });
    expect(resolveVmImage("freestyle", undefined, {})).toMatchObject({
      provider: "freestyle",
      image: "sh-17agfasevrc18c8f15nn",
      imageVersion: "freestyle-tooling-20260509d",
    });
  });

  test("requires deployed env selectors", () => {
    expect(() =>
      resolveVmImage("freestyle", undefined, {
        VERCEL: "1",
        VERCEL_ENV: "preview",
      }),
    ).toThrow(VmImageConfigError);
  });

  test("rejects unknown deployed images", () => {
    expect(() =>
      resolveVmImage("e2b", "cotermd-ws:unknown", {
        VERCEL: "1",
        VERCEL_ENV: "production",
      }),
    ).toThrow(VmImageConfigError);
  });

  test("resolves deployed env selectors through the manifest", () => {
    expect(
      resolveVmImage("e2b", undefined, {
        VERCEL: "1",
        VERCEL_ENV: "production",
        E2B_COTERMD_WS_TEMPLATE: "cotermd-ws:proxy-20260424a",
      }),
    ).toMatchObject({
      provider: "e2b",
      image: "cotermd-ws:proxy-20260424a",
      imageVersion: "e2b-proxy-20260424a",
    });
  });

  test("permits unmanifested images only when explicitly allowed", () => {
    expect(
      resolveVmImage("freestyle", "scratch-image", {
        VERCEL: "1",
        VERCEL_ENV: "preview",
        COTERM_VM_ALLOW_UNMANIFESTED_IMAGES: "1",
      }),
    ).toMatchObject({
      provider: "freestyle",
      image: "scratch-image",
      imageVersion: null,
      manifestEntry: null,
    });
  });
});
