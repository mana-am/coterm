// End-to-end smoke test for the control-plane against a running relay.
// Assumes noauth mode by default (no bearer token needed). In hmac mode, set
// MOSAIC_COLLAB_TOKEN to a valid mosaicv1 access token.
//
//   bun scripts/smoke-control.ts [controlPlaneURL]
//
// Env:
//   MOSAIC_COLLAB_CONTROL_URL  (default http://localhost:8788)
//   MOSAIC_COLLAB_TOKEN        (bearer token; optional in noauth mode)

const controlURL = (process.env.MOSAIC_COLLAB_CONTROL_URL ?? process.argv[2] ?? "http://localhost:8788").replace(/\/+$/, "");
const token = process.env.MOSAIC_COLLAB_TOKEN ?? "";

function headers(json = false): Record<string, string> {
  const h: Record<string, string> = {};
  if (token) h.authorization = `Bearer ${token}`;
  if (json) h["content-type"] = "application/json";
  return h;
}

function fail(message: string): never {
  throw new Error(message);
}

async function main(): Promise<void> {
  const health = await fetch(`${controlURL}/healthz`);
  if (!health.ok) fail(`healthz failed: ${health.status}`);

  const ent = await fetch(`${controlURL}/api/collab/entitlements?orgId=smoke`, { headers: headers() });
  if (!ent.ok) fail(`entitlements failed: ${ent.status} ${await ent.text()}`);
  const entitlements = (await ent.json()) as { plan?: string; codesEnabled?: boolean };
  if (typeof entitlements.plan !== "string") fail(`entitlements missing plan: ${JSON.stringify(entitlements)}`);

  const sessions = await fetch(`${controlURL}/api/collab/sessions`, {
    method: "POST",
    headers: headers(true),
    body: JSON.stringify({ orgId: "smoke" }),
  });
  if (!sessions.ok) fail(`sessions failed: ${sessions.status} ${await sessions.text()}`);
  const created = (await sessions.json()) as { session?: string; room?: string; grant?: string; relayURL?: string };
  for (const key of ["session", "room", "grant", "relayURL"] as const) {
    if (!created[key]) fail(`sessions response missing ${key}: ${JSON.stringify(created)}`);
  }

  const invite = await fetch(`${controlURL}/api/collab/invite`, {
    method: "POST",
    headers: headers(true),
    body: JSON.stringify({ session: created.session, inviteeUserId: "smoke-invitee" }),
  });
  if (!invite.ok) fail(`invite failed: ${invite.status} ${await invite.text()}`);

  const join = await fetch(`${controlURL}/api/collab/join`, {
    method: "POST",
    headers: headers(true),
    body: JSON.stringify({ code: created.room }),
  });
  if (!join.ok) fail(`join failed: ${join.status} ${await join.text()}`);
  const joined = (await join.json()) as { grant?: string; room?: string };
  if (!joined.grant || joined.room !== created.room) fail(`join returned unexpected result: ${JSON.stringify(joined)}`);

  console.log(`control-plane smoke OK: ${controlURL} room ${created.room}`);
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : error);
  process.exit(1);
});
