#!/usr/bin/env bun

type Args = {
  config: string;
  clientEnv: string;
  guestId?: string;
  guestAvatar?: string;
  printOnly: boolean;
};

const root = new URL("..", import.meta.url).pathname.replace(/\/$/, "");
const args = parseArgs(process.argv.slice(2));

if (process.argv.includes("--help") || process.argv.includes("-h")) {
  usage(0);
}

const config = await readEnv(args.config);
const updates: Record<string, string> = {
  COTERM_API_BASE_URL: requireConfig(config, "COTERM_API_BASE_URL"),
  COTERM_COLLAB_CONTROL_URL: requireConfig(config, "COTERM_API_BASE_URL"),
  COTERM_COLLABORATION_RELAY_URL: requireConfig(config, "COTERM_COLLABORATION_RELAY_URL"),
  COTERM_PRESENCE_BASE_URL: requireConfig(config, "COTERM_PRESENCE_BASE_URL"),
};
if (args.guestId) updates.COTERM_COLLAB_GUEST_ID = args.guestId;
if (args.guestAvatar) updates.COTERM_COLLAB_GUEST_AVATAR = args.guestAvatar;

const next = await mergeEnvFile(args.clientEnv, updates);
if (args.printOnly) {
  console.log(next);
} else {
  await Bun.write(args.clientEnv, next);
  console.log("Coterm debug client configuration updated.");
  console.log(`Client env: ${args.clientEnv}`);
  console.log(`Control-plane: ${updates.COTERM_API_BASE_URL}`);
  console.log(`Relay: ${updates.COTERM_COLLABORATION_RELAY_URL}`);
  console.log(`Presence: ${updates.COTERM_PRESENCE_BASE_URL}`);
  if (updates.COTERM_COLLAB_GUEST_ID) {
    console.log(`Guest id: ${updates.COTERM_COLLAB_GUEST_ID}`);
  }
  console.log("Restart any running debug Coterm app so it rereads ~/.coterm-dev.env.");
}

function parseArgs(values: string[]): Args {
  const home = process.env.HOME;
  if (!home) throw new Error("HOME is not set");
  const out: Args = {
    config: `${root}/.coterm-self-host.env`,
    clientEnv: `${home}/.coterm-dev.env`,
    printOnly: false,
  };
  for (let index = 0; index < values.length; index += 1) {
    const value = values[index];
    switch (value) {
      case "--config":
        out.config = expandHome(requireValue(values, ++index, "--config"));
        break;
      case "--client-env":
        out.clientEnv = expandHome(requireValue(values, ++index, "--client-env"));
        break;
      case "--guest-id":
        out.guestId = requireValue(values, ++index, "--guest-id");
        break;
      case "--guest-avatar":
        out.guestAvatar = requireValue(values, ++index, "--guest-avatar");
        break;
      case "--print-only":
        out.printOnly = true;
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

function expandHome(path: string): string {
  if (path === "~") return process.env.HOME ?? path;
  if (path.startsWith("~/")) return `${process.env.HOME}${path.slice(1)}`;
  return path;
}

async function readEnv(path: string): Promise<Record<string, string>> {
  if (!(await Bun.file(path).exists())) {
    throw new Error(`Missing config file: ${path}. Run bun run deploy:self-host first.`);
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

function requireConfig(config: Record<string, string>, key: string): string {
  const value = config[key]?.replace(/\/+$/, "");
  if (!value) throw new Error(`Missing ${key} in ${args.config}`);
  try {
    const url = new URL(value);
    if (url.protocol !== "https:" && url.protocol !== "http:") {
      throw new Error();
    }
  } catch {
    throw new Error(`${key} is not a valid http(s) URL: ${value}`);
  }
  return value;
}

async function mergeEnvFile(path: string, updates: Record<string, string>): Promise<string> {
  const existing = (await Bun.file(path).exists()) ? await Bun.file(path).text() : "";
  const seen = new Set<string>();
  const lines = existing.split(/\r?\n/).filter((line, index, all) => {
    return index < all.length - 1 || line.length > 0;
  });
  const merged = lines.map((line) => {
    const trimmed = line.trim();
    if (!trimmed || trimmed.startsWith("#") || !trimmed.includes("=")) return line;
    const key = trimmed.slice(0, trimmed.indexOf("=")).trim();
    if (!(key in updates)) return line;
    seen.add(key);
    return `${key}=${quoteEnv(updates[key])}`;
  });
  if (merged.length > 0 && merged[merged.length - 1] !== "") {
    merged.push("");
  }
  if (seen.size < Object.keys(updates).length) {
    merged.push("# Coterm self-host collaboration backend");
    for (const [key, value] of Object.entries(updates)) {
      if (!seen.has(key)) merged.push(`${key}=${quoteEnv(value)}`);
    }
  }
  return `${merged.join("\n")}\n`;
}

function quoteEnv(value: string): string {
  if (/^[A-Za-z0-9_./:@%+-]+$/.test(value)) return value;
  return `"${value.replace(/\\/g, "\\\\").replace(/"/g, '\\"')}"`;
}

function usage(code: number): never {
  const write = code === 0 ? console.log : console.error;
  write(`Usage: bun run configure:client -- [--config PATH] [--client-env PATH] [--guest-id NAME] [--guest-avatar URL] [--print-only]

Writes the saved self-host worker URLs into ~/.coterm-dev.env so DEBUG Coterm
builds can use the backend when launched from Finder, Dock, or a tagged app link.
`);
  process.exit(code);
}
