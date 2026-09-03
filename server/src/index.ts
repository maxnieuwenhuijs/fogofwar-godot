// F4.1 — entrypoint. Config via env: DB_URL (verplicht), POORT (default 8787).
// Redis komt erbij zodra de F4.2-worker landt (jobs-queue); de app zelf heeft
// hem voor accounts/matches nog niet nodig.
import { bouwApp } from "./app.js";

const dbUrl = process.env.DB_URL ?? "";
if (dbUrl.length === 0) {
  console.error("Zet DB_URL, bv. mysql://fogofwar:geheim@localhost:3306/fogofwar");
  process.exit(1);
}

const { app } = await bouwApp({ databaseUrl: dbUrl, logger: true });
const poort = Number(process.env.POORT ?? 8787);
// HOST=0.0.0.0 voor een playtest over het eigen netwerk (F4.3i); zonder
// TLS en rate-limiting hoort dat nooit verder dan het LAN te reiken.
const host = process.env.HOST ?? "127.0.0.1";
await app.listen({ port: poort, host });
console.log(`Fog of War backend luistert op ${host}:${poort}`);
