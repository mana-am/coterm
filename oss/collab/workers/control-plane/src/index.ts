import { providerFromEnv } from "@mosaic-oss/collab-auth";
import { controlPlaneFetch, type ControlPlaneEnv } from "./handler";
import { InviteStoreObject } from "./invite-store";

export { InviteStoreObject };

export interface Env {
  INVITE_STORE: DurableObjectNamespace<InviteStoreObject>;
  COLLAB_RELAY_URL?: string;
  COLLAB_AUTH_MODE?: string;
  COLLAB_AUTH_SECRET?: string;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const provider = providerFromEnv(env);
    return controlPlaneFetch(request, env as unknown as ControlPlaneEnv, provider);
  },
} satisfies ExportedHandler<Env>;
