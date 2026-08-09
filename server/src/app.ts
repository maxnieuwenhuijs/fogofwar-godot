// F4.1/F4.2 — de app-fabriek: alles behalve listen(), zodat de
// integratietests exact dezelfde app opbouwen als productie
// (fastify.inject, geen poorten).
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import Fastify, { type FastifyInstance } from "fastify";
import websocket from "@fastify/websocket";
import { maakPool, migreer, type Db } from "./db.js";
import { registreerAuthRoutes } from "./auth.js";
import { registreerMatchRoutes, MatchStream } from "./matches.js";
import { GodotWorker } from "./worker.js";

export interface AppOpties {
  databaseUrl: string;
  logger?: boolean;
  godotPad?: string;
  projectPad?: string;
}

const STANDAARD_GODOT =
  "C:\\Users\\maxni\\Downloads\\Godot_v4.7-stable_win64.exe\\Godot_v4.7-stable_win64_console.exe";

export async function bouwApp(opties: AppOpties): Promise<{ app: FastifyInstance; db: Db }> {
  const db = maakPool(opties.databaseUrl);
  await migreer(db);
  const app = Fastify({ logger: opties.logger ?? false });
  await app.register(websocket);
  app.decorate("matchStream", new MatchStream());
  // De Godot-worker (F4.2): een stateloze scheidsrechter als kindproces.
  // Start lui bij het eerste verzoek; herstart zichzelf na een crash.
  const projectPad =
    opties.projectPad ?? resolve(dirname(fileURLToPath(import.meta.url)), "..", "..");
  const godotPad = opties.godotPad ?? process.env.GODOT_PAD ?? process.env.GODOT_PATH ?? STANDAARD_GODOT;
  app.decorate("worker", new GodotWorker({ godotPad, projectPad }));
  app.get("/gezond", async () => ({ ok: true }));
  registreerAuthRoutes(app, db);
  registreerMatchRoutes(app, db);
  app.addHook("onClose", async () => {
    app.worker.stop();
    await db.end();
  });
  return { app, db };
}
