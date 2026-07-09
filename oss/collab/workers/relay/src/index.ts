import { providerFromEnv } from "@mosaic-oss/collab-auth";
import { CollaborationSessionObject } from "./session";
import { CollaborationSessionIndexObject } from "./session-index";
import { CollaborationInboxObject } from "./inbox";
import { collaborationFetch } from "./handler";

export {
  CollaborationSessionIndexObject,
  CollaborationSessionObject,
  CollaborationInboxObject,
};

export interface Env {
  COLLABORATION_SESSIONS: DurableObjectNamespace<CollaborationSessionObject>;
  COLLABORATION_SESSION_INDEX: DurableObjectNamespace<CollaborationSessionIndexObject>;
  COLLABORATION_INBOX: DurableObjectNamespace<CollaborationInboxObject>;
  COLLABORATION_ADMIN_TOKEN?: string;
  COLLAB_AUTH_MODE?: string;
  COLLAB_AUTH_SECRET?: string;
}

export default {
  async fetch(request: Request, env: Env): Promise<Response> {
    const provider = providerFromEnv(env);
    return collaborationFetch(request, env, provider);
  },
} satisfies ExportedHandler<Env>;
