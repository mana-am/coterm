import { HmacAuthProvider, type DirectorySource } from "./hmacProvider";
import { NoAuthProvider } from "./noAuthProvider";
import type { CollabAuthProvider } from "./types";

export interface AuthProviderEnv {
  COLLAB_AUTH_MODE?: string;
  COLLAB_AUTH_SECRET?: string;
}

export interface ProviderFromEnvOptions {
  /// Optional directory source wired into the HMAC provider (e.g. KV-backed).
  directory?: DirectorySource;
}

/// Build a provider from worker env. Defaults to `noauth`. `hmac` requires
/// COLLAB_AUTH_SECRET; a missing secret is a hard misconfiguration.
export function providerFromEnv(
  env: AuthProviderEnv,
  options: ProviderFromEnvOptions = {},
): CollabAuthProvider {
  const mode = (env.COLLAB_AUTH_MODE ?? "noauth").trim().toLowerCase();
  if (mode === "hmac") {
    if (!env.COLLAB_AUTH_SECRET) {
      throw new Error("COLLAB_AUTH_SECRET is required when COLLAB_AUTH_MODE=hmac");
    }
    return new HmacAuthProvider({ secret: env.COLLAB_AUTH_SECRET, directory: options.directory });
  }
  if (mode !== "noauth") {
    console.warn(`unknown COLLAB_AUTH_MODE "${mode}"; falling back to noauth`);
  }
  return new NoAuthProvider();
}
