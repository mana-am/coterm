#!/usr/bin/env bun

type Format = "text" | "json" | "markdown" | "shell";

type Args = {
  config: string;
  format: Format;
  write?: string;
  check: boolean;
};

type Endpoint = {
  env: string;
  url: string;
  ok: boolean;
  issue?: string;
};

const root = new URL("..", import.meta.url).pathname.replace(/\/$/, "");
const defaultConfig = `${root}/.coterm-self-host.env`;
const args = parseArgs(process.argv.slice(2));

if (process.argv.includes("--help") || process.argv.includes("-h")) {
  usage(0);
}

const env = await readEnv(args.config);
const endpoints: Record<string, Endpoint> = {
  controlPlane: endpoint("COTERM_API_BASE_URL", env.COTERM_API_BASE_URL),
  relay: endpoint("COTERM_COLLABORATION_RELAY_URL", env.COTERM_COLLABORATION_RELAY_URL),
  presence: endpoint("COTERM_PRESENCE_BASE_URL", env.COTERM_PRESENCE_BASE_URL),
};
const issues = Object.entries(endpoints)
  .filter(([, value]) => !value.ok)
  .map(([name, value]) => `${name}: ${value.issue ?? "invalid"}`);
const context = {
  schema: "coterm.selfHostContext.v1",
  generatedAt: new Date().toISOString(),
  configFile: args.config,
  ready: issues.length === 0,
  issues,
  authMode: env.COLLAB_AUTH_MODE || "unknown",
  endpoints,
  clientEnv: {
    COTERM_API_BASE_URL: endpoints.controlPlane.url,
    COTERM_COLLAB_CONTROL_URL: endpoints.controlPlane.url,
    COTERM_COLLABORATION_RELAY_URL: endpoints.relay.url,
    COTERM_PRESENCE_BASE_URL: endpoints.presence.url,
  },
  files: {
    savedConfig: args.config,
    agentContext: `${root}/.coterm-self-host.context.json`,
    debugClientEnv: `${process.env.HOME ?? "~"}/.coterm-dev.env`,
  },
  commands: {
    deploy: "bun run deploy:self-host",
    doctor: "bun run doctor:self-host",
    configureClient: "bun run configure:client -- --guest-id <name>",
    printContext: "bun run context:self-host -- --format markdown",
    previewHost: "bun run preview:host -- --relay <relay-url> --room <room-code> --share-secret <secret> --port <port>",
  },
  agentGuidance: [
    "Coterm collaboration is self-host only; do not use or suggest an official hosted collaboration service.",
    "Use the saved client URLs for Coterm debug builds and headless smoke scripts.",
    "Use preview sharing through the self-hosted relay; do not default to ngrok or Cloudflare Tunnel.",
  ],
};

const rendered = render(context, args.format);
if (args.write) {
  await Bun.write(args.write, rendered);
}
if (!args.write || args.format !== "json") {
  console.log(rendered);
}
if (args.check && !context.ready) {
  process.exit(1);
}

function parseArgs(values: string[]): Args {
  const out: Args = { config: defaultConfig, format: "text", check: false };
  for (let index = 0; index < values.length; index += 1) {
    const value = values[index];
    switch (value) {
      case "--config":
        out.config = requireValue(values, ++index, "--config");
        break;
      case "--format": {
        const format = requireValue(values, ++index, "--format");
        if (!["text", "json", "markdown", "shell"].includes(format)) {
          throw new Error("--format must be text, json, markdown, or shell");
        }
        out.format = format as Format;
        break;
      }
      case "--write":
        out.write = requireValue(values, ++index, "--write");
        break;
      case "--check":
        out.check = true;
        break;
      case "-h":
      case "--help":
        usage(0);
        break;
      default:
        throw new Error(`Unknown option: ${value}`);
    }
  }
  return out;
}

function requireValue(values: string[], index: number, flag: string): string {
  const value = values[index];
  if (!value || value.startsWith("--")) {
    throw new Error(`Missing value for ${flag}`);
  }
  return value;
}

async function readEnv(path: string): Promise<Record<string, string>> {
  if (!(await Bun.file(path).exists())) {
    return {};
  }
  const text = await Bun.file(path).text();
  const out: Record<string, string> = {};
  for (const raw of text.split(/\r?\n/)) {
    const line = raw.trim();
    if (!line || line.startsWith("#")) continue;
    const equals = line.indexOf("=");
    if (equals === -1) continue;
    const key = line.slice(0, equals).trim();
    let value = line.slice(equals + 1).trim();
    if (
      (value.startsWith('"') && value.endsWith('"')) ||
      (value.startsWith("'") && value.endsWith("'"))
    ) {
      value = value.slice(1, -1);
    }
    out[key] = value;
  }
  return out;
}

function endpoint(env: string, raw: string | undefined): Endpoint {
  const url = (raw ?? "").replace(/\/+$/, "");
  if (!url) return { env, url, ok: false, issue: "missing" };
  try {
    const parsed = new URL(url);
    if (parsed.protocol !== "https:" && parsed.protocol !== "http:") {
      return { env, url, ok: false, issue: "must be http or https" };
    }
    return { env, url, ok: true };
  } catch {
    return { env, url, ok: false, issue: "not a valid URL" };
  }
}

function render(value: typeof context, format: Format): string {
  switch (format) {
    case "json":
      return `${JSON.stringify(value, null, 2)}\n`;
    case "markdown":
      return renderMarkdown(value);
    case "shell":
      return renderShell(value);
    case "text":
      return renderText(value);
  }
}

function renderText(value: typeof context): string {
  const lines = [
    "Coterm self-host context",
    `Ready: ${value.ready ? "yes" : "no"}`,
    `Config: ${value.configFile}`,
    `Auth mode: ${value.authMode}`,
    "",
    `COTERM_API_BASE_URL=${value.clientEnv.COTERM_API_BASE_URL}`,
    `COTERM_COLLABORATION_RELAY_URL=${value.clientEnv.COTERM_COLLABORATION_RELAY_URL}`,
    `COTERM_PRESENCE_BASE_URL=${value.clientEnv.COTERM_PRESENCE_BASE_URL}`,
  ];
  if (value.issues.length > 0) {
    lines.push("", "Issues:", ...value.issues.map((issue) => `- ${issue}`));
  }
  lines.push("", `Agent context JSON: ${value.files.agentContext}`);
  lines.push(`Configure debug client: ${value.commands.configureClient}`);
  return `${lines.join("\n")}\n`;
}

function renderMarkdown(value: typeof context): string {
  const rows = [
    ["Control-plane", "COTERM_API_BASE_URL", value.clientEnv.COTERM_API_BASE_URL],
    ["Relay", "COTERM_COLLABORATION_RELAY_URL", value.clientEnv.COTERM_COLLABORATION_RELAY_URL],
    ["Presence", "COTERM_PRESENCE_BASE_URL", value.clientEnv.COTERM_PRESENCE_BASE_URL],
  ];
  const issues = value.issues.length === 0
    ? "None."
    : value.issues.map((issue) => `- ${issue}`).join("\n");
  return `# Coterm Self-host Context

- Ready: ${value.ready ? "yes" : "no"}
- Config: \`${value.configFile}\`
- Auth mode: \`${value.authMode}\`

| Service | Env var | URL |
| --- | --- | --- |
${rows.map((row) => `| ${row[0]} | \`${row[1]}\` | \`${row[2]}\` |`).join("\n")}

## Issues

${issues}

## Useful Commands

\`\`\`bash
${value.commands.doctor}
${value.commands.configureClient}
${value.commands.previewHost}
\`\`\`
`;
}

function renderShell(value: typeof context): string {
  return [
    `export COTERM_API_BASE_URL=${shellQuote(value.clientEnv.COTERM_API_BASE_URL)}`,
    `export COTERM_COLLAB_CONTROL_URL=${shellQuote(value.clientEnv.COTERM_COLLAB_CONTROL_URL)}`,
    `export COTERM_COLLABORATION_RELAY_URL=${shellQuote(value.clientEnv.COTERM_COLLABORATION_RELAY_URL)}`,
    `export COTERM_PRESENCE_BASE_URL=${shellQuote(value.clientEnv.COTERM_PRESENCE_BASE_URL)}`,
    "",
  ].join("\n");
}

function shellQuote(value: string): string {
  return `'${value.replace(/'/g, "'\\''")}'`;
}

function usage(code: number): never {
  const write = code === 0 ? console.log : console.error;
  write(`Usage: bun run context:self-host -- [--config PATH] [--format text|json|markdown|shell] [--write PATH] [--check]

Reads .coterm-self-host.env and emits a self-host context for Coterm clients,
headless scripts, and coding agents.
`);
  process.exit(code);
}
