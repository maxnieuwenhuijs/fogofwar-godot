// F4.1/F4.2 — de app-fabriek: alles behalve listen(), zodat de
// integratietests exact dezelfde app opbouwen als productie
// (fastify.inject, geen poorten).
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import Fastify, { type FastifyInstance } from "fastify";
import websocket from "@fastify/websocket";
import { maakPool, migreer, type Db } from "./db.js";
import { registreerAuthRoutes } from "./auth.js";
import { registreerMatchRoutes, MatchStream, SERVER_ONLY_EVENTS } from "./matches.js";
import { GodotWorker } from "./worker.js";

export interface AppOpties {
  databaseUrl: string;
  logger?: boolean;
  godotPad?: string;
  projectPad?: string;
}

const STANDAARD_GODOT =
  "C:\\Users\\maxni\\Downloads\\Godot_v4.7-stable_win64.exe\\Godot_v4.7-stable_win64_console.exe";

/**
 * Request-serializer voor het log: de WebSocket-route accepteert
 * `?token=<sessie_token>` en zonder dit zou dat token (een blijvende inlog)
 * in klare tekst in elk access-log staan.
 */
function reqZonderToken(req: { method?: string; url?: string; ip?: string }) {
  return {
    method: req.method,
    url: String(req.url ?? "").replace(/([?&]token=)[^&]*/g, "$1[geredigeerd]"),
    remoteAddress: req.ip,
  };
}

export async function bouwApp(opties: AppOpties): Promise<{ app: FastifyInstance; db: Db }> {
  const db = maakPool(opties.databaseUrl);
  await migreer(db);
  const app = Fastify({
    logger: opties.logger ? { serializers: { req: reqZonderToken } } : false,
  });
  await app.register(websocket);
  app.decorate("matchStream", new MatchStream());
  // Fouten die geen statuscode dragen (worker dood, database weg) zijn 500's:
  // de details gaan naar het serverlog, de client krijgt een neutrale melding
  // (geen paden, geen redactielijsten, geen stacks).
  app.setErrorHandler((err: unknown, req, reply) => {
    const e = err as { statusCode?: unknown; message?: unknown };
    const status = typeof e.statusCode === "number" ? e.statusCode : 500;
    if (status >= 500) {
      req.log.error(err);
      return reply.code(500).send({ fout: "Interne fout: scheidsrechter of database niet beschikbaar" });
    }
    return reply.code(status).send({ fout: String(e.message ?? "Fout") });
  });
  // De Godot-worker (F4.2): een stateloze scheidsrechter als kindproces.
  // Start meteen (F4.2b): een ontbrekende binary of een redactielijst die
  // afwijkt van de engine is een OPSTARTFOUT, geen 500 per verzoek. Herstart
  // zichzelf na een crash.
  const projectPad =
    opties.projectPad ?? resolve(dirname(fileURLToPath(import.meta.url)), "..", "..");
  const godotPad = opties.godotPad ?? process.env.GODOT_PAD ?? process.env.GODOT_PATH ?? STANDAARD_GODOT;
  app.decorate("worker", new GodotWorker({ godotPad, projectPad, verwachtServerOnly: SERVER_ONLY_EVENTS }));
  try {
    await app.worker.start();
  } catch (e) {
    await db.end();
    throw e;
  }
  app.get("/gezond", async () => ({ ok: true }));
  registreerAuthRoutes(app, db);
  registreerMatchRoutes(app, db);
  app.addHook("onClose", async () => {
    app.worker.stop();
    await db.end();
  });
  return { app, db };
}
