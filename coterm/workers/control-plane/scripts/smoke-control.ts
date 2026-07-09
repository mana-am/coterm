// End-to-end smoke test for the control-plane against a running relay.
// In hmac mode, set COTERM_COLLAB_TOKEN to a valid cotermv1 access token.
//
//   bun scripts/smoke-control.ts [controlPlaneURL]
//
// Env:
//   COTERM_COLLAB_CONTROL_URL  (default http://localhost:8788)
//   COTERM_COLLAB_TOKEN        (bearer token)

const controlURL = (process.env.COTERM_COLLAB_CONTROL_URL ?? process.argv[2] ?? "http://localhost:8788").replace(/\/+$/, "");
const token = process.env.COTERM_COLLAB_TOKEN ?? "";

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
  const created = (await sessions.json()) as {
    session?: string;
    room?: string;
    grant?: string;
    relayURL?: string;
    shareSecret?: string;
  };
  for (const key of ["session", "room", "grant", "relayURL", "shareSecret"] as const) {
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
    body: JSON.stringify({ code: created.room, shareSecret: created.shareSecret }),
  });
  if (!join.ok) fail(`join failed: ${join.status} ${await join.text()}`);
  const pending = (await join.json()) as { requestId?: string; room?: string; status?: string };
  if (!pending.requestId || pending.room !== created.room || pending.status !== "pending") {
    fail(`join returned unexpected pending request: ${JSON.stringify(pending)}`);
  }

  const approve = await fetch(`${controlURL}/api/collab/join-requests/approve`, {
    method: "POST",
    headers: headers(true),
    body: JSON.stringify({ requestId: pending.requestId }),
  });
  if (!approve.ok) fail(`approve failed: ${approve.status} ${await approve.text()}`);

  const claim = await fetch(`${controlURL}/api/collab/join-requests/claim`, {
    method: "POST",
    headers: headers(true),
    body: JSON.stringify({ room: created.room, requestId: pending.requestId }),
  });
  if (!claim.ok) fail(`claim failed: ${claim.status} ${await claim.text()}`);
  const joined = (await claim.json()) as { grant?: string; room?: string };
  if (!joined.grant || joined.room !== created.room) fail(`claim returned unexpected result: ${JSON.stringify(joined)}`);

  console.log(`control-plane smoke OK: ${controlURL} room ${created.room}`);
}

main().catch((error) => {
  console.error(error instanceof Error ? error.message : error);
  process.exit(1);
});
