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
await app.listen({ port: poort, host: "127.0.0.1" });
console.log(`Fog of War backend luistert op 127.0.0.1:${poort}`);
