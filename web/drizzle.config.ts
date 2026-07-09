import { defineConfig } from "drizzle-kit";

function defaultDatabaseURL(): string {
  const rawPort = process.env.COTERM_PORT ?? process.env.PORT ?? "3777";
  const cotermPort = /^\d+$/.test(rawPort) ? Number(rawPort) : 3777;
  const offset = Number(process.env.COTERM_DB_PORT_OFFSET ?? "10000");
  const dbPort = process.env.COTERM_DB_PORT ?? String(cotermPort + offset);
  const user = process.env.COTERM_DB_USER ?? "coterm";
  const password = process.env.COTERM_DB_PASSWORD ?? "coterm";
  const database = process.env.COTERM_DB_NAME ?? "coterm";
  return `postgres://${user}:${password}@localhost:${dbPort}/${database}`;
}

export default defineConfig({
  schema: "./db/schema.ts",
  out: "./db/migrations",
  dialect: "postgresql",
  dbCredentials: {
    url: process.env.DIRECT_DATABASE_URL ?? process.env.DATABASE_URL ?? defaultDatabaseURL(),
  },
  strict: true,
  verbose: true,
});
