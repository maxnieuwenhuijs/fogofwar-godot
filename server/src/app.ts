// F4.1 — de app-fabriek: alles behalve listen(), zodat de integratietests
// exact dezelfde app opbouwen als productie (fastify.inject, geen poorten).
import Fastify, { type FastifyInstance } from "fastify";
import websocket from "@fastify/websocket";
import { maakPool, migreer, type Db } from "./db.js";
import { registreerAuthRoutes } from "./auth.js";
import { registreerMatchRoutes, MatchStream } from "./matches.js";

export interface AppOpties {
  databaseUrl: string;
  logger?: boolean;
}

export async function bouwApp(opties: AppOpties): Promise<{ app: FastifyInstance; db: Db }> {
  const db = maakPool(opties.databaseUrl);
  await migreer(db);
  const app = Fastify({ logger: opties.logger ?? false });
  await app.register(websocket);
  app.decorate("matchStream", new MatchStream());
  app.get("/gezond", async () => ({ ok: true }));
  registreerAuthRoutes(app, db);
  registreerMatchRoutes(app, db);
  app.addHook("onClose", async () => {
    await db.end();
  });
  return { app, db };
}
