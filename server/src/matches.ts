// F4.1 — matches + het actieprotocol (bouwplan §10). Het contract:
//
//   POST /matches/:id/acties {seq_expected, action, idem_key}
//     → 200 {events}                bij succes (events dragen een dicht seq)
//     → 200 {events, herhaald:true} bij een al verwerkte idem_key (idempotent)
//     → 409 {events}                bij een seq-conflict: de events SINDS
//                                    seq_expected, zodat de client bijloopt
//                                    en opnieuw indient
//
// De idempotentie leunt op de unieke index (match_id, idem_key) — geen
// check-then-act-race — en het seq-nummer op een FOR UPDATE-lock op de
// match-rij. In F4.1 accepteert de server acties als transport (echo als
// `action_accepted`); de ENGINE-validatie komt in F4.2, waar de Godot-worker
// dit event vervangt door de echte reducer-events. Het formaat van `action`
// is nu al Actions.to_dict (JSON-veilig, Vector2i als [x, y]).
import { randomUUID } from "node:crypto";
import type { FastifyInstance } from "fastify";
import type { PoolConnection, RowDataPacket } from "mysql2/promise";
import type { Db } from "./db.js";
import { wieIsDit } from "./auth.js";

interface EventRij {
  seq: number;
  player_seat: number;
  type: string;
  payload: unknown;
}

async function eventsSinds(conn: PoolConnection | Db, matchId: string, na: number): Promise<EventRij[]> {
  const [rows] = await conn.query<RowDataPacket[]>(
    "SELECT seq, player_seat, type, payload FROM match_events WHERE match_id = ? AND seq > ? ORDER BY seq",
    [matchId, na],
  );
  return rows as unknown as EventRij[];
}

export function registreerMatchRoutes(app: FastifyInstance, db: Db): void {
  // Match aanmaken: de maker zit op seat 1. rules_config is de volledige
  // regels-dict van de match (rules_version + doctrines-blok en al) zodat de
  // worker en elke client exact hetzelfde spel spelen.
  app.post("/matches", async (req, reply) => {
    const ik = await wieIsDit(db, req);
    if (!ik) return reply.code(401).send({ fout: "Niet ingelogd" });
    const body = (req.body ?? {}) as { rules_version?: string; rules_config?: unknown };
    const versie = String(body.rules_version ?? "");
    if (versie.length === 0 || body.rules_config === undefined) {
      return reply.code(400).send({ fout: "rules_version en rules_config zijn verplicht" });
    }
    const id = randomUUID();
    await db.query("INSERT INTO matches (id, rules_version, rules_config) VALUES (?, ?, ?)", [
      id, versie, JSON.stringify(body.rules_config),
    ]);
    await db.query("INSERT INTO match_seats (match_id, seat, user_id) VALUES (?, 1, ?)", [id, ik.userId]);
    return { match_id: id, seat: 1 };
  });

  // Tweede speler stapt in → status 'bezig'. (Join-codes/queue komen in F4.4;
  // dit is de kale variant: je kent het match-id, bv. via een vriend.)
  app.post("/matches/:id/join", async (req, reply) => {
    const ik = await wieIsDit(db, req);
    if (!ik) return reply.code(401).send({ fout: "Niet ingelogd" });
    const matchId = String((req.params as { id: string }).id);
    const conn = await db.getConnection();
    try {
      await conn.beginTransaction();
      const [m] = await conn.query<RowDataPacket[]>(
        "SELECT status FROM matches WHERE id = ? FOR UPDATE", [matchId]);
      if (!m[0]) { await conn.rollback(); return reply.code(404).send({ fout: "Onbekende match" }); }
      const [seats] = await conn.query<RowDataPacket[]>(
        "SELECT seat, user_id FROM match_seats WHERE match_id = ?", [matchId]);
      if (seats.some((s) => s.user_id === ik.userId)) {
        await conn.rollback();
        const eigen = seats.find((s) => s.user_id === ik.userId);
        return { match_id: matchId, seat: eigen ? Number(eigen.seat) : 0, herhaald: true };
      }
      if (seats.length >= 2) { await conn.rollback(); return reply.code(409).send({ fout: "De match zit vol" }); }
      await conn.query("INSERT INTO match_seats (match_id, seat, user_id) VALUES (?, 2, ?)", [matchId, ik.userId]);
      await conn.query("UPDATE matches SET status = 'bezig' WHERE id = ?", [matchId]);
      await conn.commit();
      return { match_id: matchId, seat: 2 };
    } catch (e) {
      await conn.rollback();
      throw e;
    } finally {
      conn.release();
    }
  });

  // Het actieprotocol. Zie de kop van dit bestand voor het contract.
  app.post("/matches/:id/acties", async (req, reply) => {
    const ik = await wieIsDit(db, req);
    if (!ik) return reply.code(401).send({ fout: "Niet ingelogd" });
    const matchId = String((req.params as { id: string }).id);
    const body = (req.body ?? {}) as { seq_expected?: number; action?: unknown; idem_key?: string };
    const seqVerwacht = Number(body.seq_expected);
    const idemKey = String(body.idem_key ?? "");
    if (!Number.isInteger(seqVerwacht) || seqVerwacht < 0) {
      return reply.code(400).send({ fout: "seq_expected is een niet-negatief geheel getal" });
    }
    if (!/^[0-9a-f-]{36}$/i.test(idemKey)) {
      return reply.code(400).send({ fout: "idem_key moet een UUID zijn" });
    }
    const actie = body.action as { type?: unknown } | undefined;
    if (!actie || typeof actie.type !== "string") {
      return reply.code(400).send({ fout: "action met een type is verplicht" });
    }
    const conn = await db.getConnection();
    try {
      await conn.beginTransaction();
      // Lock op de match-rij serialiseert alle schrijvers van deze match.
      const [m] = await conn.query<RowDataPacket[]>(
        "SELECT status FROM matches WHERE id = ? FOR UPDATE", [matchId]);
      if (!m[0]) { await conn.rollback(); return reply.code(404).send({ fout: "Onbekende match" }); }
      const [seatRows] = await conn.query<RowDataPacket[]>(
        "SELECT seat FROM match_seats WHERE match_id = ? AND user_id = ?", [matchId, ik.userId]);
      if (!seatRows[0]) { await conn.rollback(); return reply.code(403).send({ fout: "Je zit niet in deze match" }); }
      const seat = Number(seatRows[0].seat);
      // Idempotentie eerst: dezelfde idem_key → exact het eerdere antwoord.
      const [eerder] = await conn.query<RowDataPacket[]>(
        "SELECT seq FROM match_events WHERE match_id = ? AND idem_key = ?", [matchId, idemKey]);
      if (eerder[0]) {
        const events = await eventsSinds(conn, matchId, Number(eerder[0].seq) - 1);
        await conn.commit();
        return { events, herhaald: true };
      }
      const [top] = await conn.query<RowDataPacket[]>(
        "SELECT COALESCE(MAX(seq), 0) AS hoogste FROM match_events WHERE match_id = ?", [matchId]);
      const hoogste = Number(top[0]?.hoogste ?? 0);
      if (seqVerwacht !== hoogste) {
        // Conflict: geef de inhaal-events mee zodat de client kan rebasen.
        const events = await eventsSinds(conn, matchId, seqVerwacht);
        await conn.rollback();
        return reply.code(409).send({ fout: "seq_expected loopt achter", events });
      }
      const seq = hoogste + 1;
      const payload = { action: body.action, door_seat: seat };
      await conn.query(
        "INSERT INTO match_events (match_id, seq, player_seat, type, payload, idem_key) VALUES (?, ?, ?, ?, ?, ?)",
        [matchId, seq, seat, "action_accepted", JSON.stringify(payload), idemKey],
      );
      await conn.commit();
      const events: EventRij[] = [{ seq, player_seat: seat, type: "action_accepted", payload }];
      app.matchStream.push(matchId, events);
      return { events };
    } catch (e) {
      await conn.rollback();
      throw e;
    } finally {
      conn.release();
    }
  });

  // Inhaal-endpoint (reconnect / WS-gaten / polling-fallback).
  app.get("/matches/:id/events", async (req, reply) => {
    const ik = await wieIsDit(db, req);
    if (!ik) return reply.code(401).send({ fout: "Niet ingelogd" });
    const matchId = String((req.params as { id: string }).id);
    const na = Number((req.query as { after?: string }).after ?? 0);
    const events = await eventsSinds(db, matchId, Number.isInteger(na) && na >= 0 ? na : 0);
    return { events };
  });

  // WS: live events per match. De client stuurt {match_id} als eerste bericht
  // en krijgt daarna elke nieuwe event-batch gepusht; gaten dicht je met
  // GET /events?after=seq (zelfde bron, zelfde seq).
  app.get("/matches/:id/ws", { websocket: true }, (socket, req) => {
    const matchId = String((req.params as { id: string }).id);
    const stop = app.matchStream.abonneer(matchId, (events) => {
      socket.send(JSON.stringify({ match_id: matchId, events }));
    });
    socket.on("close", stop);
  });
}

/** In-proces event-verdeler; bij meerdere processen komt hier Redis pub/sub. */
export class MatchStream {
  private luisteraars = new Map<string, Set<(events: EventRij[]) => void>>();

  abonneer(matchId: string, cb: (events: EventRij[]) => void): () => void {
    let set = this.luisteraars.get(matchId);
    if (!set) {
      set = new Set();
      this.luisteraars.set(matchId, set);
    }
    set.add(cb);
    return () => {
      set.delete(cb);
      if (set.size === 0) this.luisteraars.delete(matchId);
    };
  }

  push(matchId: string, events: EventRij[]): void {
    for (const cb of this.luisteraars.get(matchId) ?? []) cb(events);
  }
}

declare module "fastify" {
  interface FastifyInstance {
    matchStream: MatchStream;
  }
}
