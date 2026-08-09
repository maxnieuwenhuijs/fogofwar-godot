// F4.2 — matches + het actieprotocol, nu met de ECHTE engine erachter.
//
// Het contract (bouwplan §10, ongewijzigd sinds F4.1):
//
//   POST /matches/:id/acties {seq_expected, action, idem_key}
//     → 200 {events}                geaccepteerd; events dragen een dicht seq
//     → 200 {events, herhaald:true} al verwerkte idem_key (idempotent)
//     → 409 {events}                seq-conflict: de events SINDS jouw seq
//     → 422 {fout}                  de ENGINE weigert de actie (F4.2)
//
// Elke actie gaat door de Godot-worker: snapshot + staart uit MySQL, dan
// Validator/Reducer in exact dezelfde core/ als de client. Eén rij per actie
// (type action_applied) met payload {action, events, hash} — hetzelfde
// formaat als een MatchLog-entry, dus replay en battlereport zijn gratis.
// Elke 50 acties een snapshot. now_ms per rij (F4.0b): servertijd.
//
// LEK-DISCIPLINE: het rauwe log is server-only (payload.action draagt blinde
// keuzes; twee admin-events dragen beide saldi). Alles wat een client ziet
// gaat door naarClientRij(): action eruit, admin-events eruit (spiegelt
// View.client_events; de test bewaakt dat dit niet uit elkaar loopt).
import { randomUUID } from "node:crypto";
import type { FastifyInstance } from "fastify";
import type { PoolConnection, RowDataPacket } from "mysql2/promise";
import type { Db } from "./db.js";
import { wieIsDit } from "./auth.js";
import type { GodotWorker } from "./worker.js";

interface EventRij {
  seq: number;
  player_seat: number;
  type: string;
  payload: { action?: unknown; events?: unknown[]; hash?: string; [k: string]: unknown };
}

// Server/log-only reducer-events (D12) — spiegel van View.client_events().
const SERVER_ONLY_EVENTS = new Set(["cycle_admin", "cp_admin"]);

/** De vorm die een client mag zien: geen actie, geen admin-events. */
export function naarClientRij(rij: EventRij): Record<string, unknown> {
  const events = Array.isArray(rij.payload.events) ? rij.payload.events : [];
  return {
    seq: rij.seq,
    player_seat: rij.player_seat,
    type: rij.type,
    payload: {
      events: events.filter((e) => !SERVER_ONLY_EVENTS.has(String((e as { type?: unknown }).type))),
      hash: rij.payload.hash ?? "",
    },
  };
}

async function rijenSinds(conn: PoolConnection | Db, matchId: string, na: number): Promise<EventRij[]> {
  const [rows] = await conn.query<RowDataPacket[]>(
    "SELECT seq, player_seat, type, payload FROM match_events WHERE match_id = ? AND seq > ? ORDER BY seq",
    [matchId, na],
  );
  return rows as unknown as EventRij[];
}

async function clientRijenSinds(conn: PoolConnection | Db, matchId: string, na: number) {
  return (await rijenSinds(conn, matchId, na)).map(naarClientRij);
}

/** Snapshot + staart in worker-formaat (het MatchLog-fold-contract). */
async function laadBasis(conn: PoolConnection | Db, matchId: string) {
  const [snaps] = await conn.query<RowDataPacket[]>(
    "SELECT seq, staat FROM snapshots WHERE match_id = ? ORDER BY seq DESC LIMIT 1",
    [matchId],
  );
  const snap = snaps[0];
  if (!snap) return null;
  const [rows] = await conn.query<RowDataPacket[]>(
    "SELECT payload, player_seat, now_ms FROM match_events WHERE match_id = ? AND seq > ? ORDER BY seq",
    [matchId, Number(snap.seq)],
  );
  const staart = rows.map((r) => ({
    action: (r.payload as { action?: unknown }).action,
    player_id: Number(r.player_seat),
    now_ms: r.now_ms === null ? -1 : Number(r.now_ms),
  }));
  return { state: snap.staat as Record<string, unknown>, tail: staart };
}

export function registreerMatchRoutes(app: FastifyInstance, db: Db): void {
  const worker = (): GodotWorker => app.worker;

  // Match aanmaken: de maker zit op seat 1. rules_config is de volledige
  // regels-dict (doctrines-blok en al): iedereen speelt exact hetzelfde spel.
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

  // Tweede speler stapt in → engine-init: snapshot seq 0 in PRE_GAME, beide
  // spelers kiezen daarna hun factie via het gewone actieprotocol (F4.0).
  app.post("/matches/:id/join", async (req, reply) => {
    const ik = await wieIsDit(db, req);
    if (!ik) return reply.code(401).send({ fout: "Niet ingelogd" });
    const matchId = String((req.params as { id: string }).id);
    const conn = await db.getConnection();
    try {
      await conn.beginTransaction();
      const [m] = await conn.query<RowDataPacket[]>(
        "SELECT status, rules_config FROM matches WHERE id = ? FOR UPDATE", [matchId]);
      if (!m[0]) { await conn.rollback(); return reply.code(404).send({ fout: "Onbekende match" }); }
      const [seats] = await conn.query<RowDataPacket[]>(
        "SELECT seat, user_id FROM match_seats WHERE match_id = ?", [matchId]);
      const eigen = seats.find((s) => s.user_id === ik.userId);
      if (eigen) {
        await conn.rollback();
        return { match_id: matchId, seat: Number(eigen.seat), herhaald: true };
      }
      if (seats.length >= 2) { await conn.rollback(); return reply.code(409).send({ fout: "De match zit vol" }); }
      const init = await worker().vraag({ op: "init", rules: m[0].rules_config });
      if (!init.ok) {
        await conn.rollback();
        return reply.code(500).send({ fout: `engine-init faalde: ${String(init.fout ?? "?")}` });
      }
      await conn.query("INSERT INTO match_seats (match_id, seat, user_id) VALUES (?, 2, ?)", [matchId, ik.userId]);
      await conn.query("INSERT INTO snapshots (match_id, seq, staat) VALUES (?, 0, ?)", [
        matchId, JSON.stringify(init.state),
      ]);
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
      if (String(m[0].status) !== "bezig") {
        await conn.rollback();
        return reply.code(409).send({ fout: "De match is nog niet begonnen" });
      }
      // Idempotentie eerst: dezelfde idem_key → exact het eerdere antwoord.
      const [eerder] = await conn.query<RowDataPacket[]>(
        "SELECT seq FROM match_events WHERE match_id = ? AND idem_key = ?", [matchId, idemKey]);
      if (eerder[0]) {
        const events = await clientRijenSinds(conn, matchId, Number(eerder[0].seq) - 1);
        await conn.commit();
        return { events, herhaald: true };
      }
      const [top] = await conn.query<RowDataPacket[]>(
        "SELECT COALESCE(MAX(seq), 0) AS hoogste FROM match_events WHERE match_id = ?", [matchId]);
      const hoogste = Number(top[0]?.hoogste ?? 0);
      if (seqVerwacht !== hoogste) {
        // Conflict: geef de inhaal-events mee zodat de client kan rebasen.
        const events = await clientRijenSinds(conn, matchId, seqVerwacht);
        await conn.rollback();
        return reply.code(409).send({ fout: "seq_expected loopt achter", events });
      }
      // De scheidsrechter: snapshot + staart naar de worker, engine beslist.
      const basis = await laadBasis(conn, matchId);
      if (!basis) {
        await conn.rollback();
        return reply.code(500).send({ fout: "geen snapshot voor deze match" });
      }
      const antwoord = await worker().vraag({
        op: "apply",
        state: basis.state,
        tail: basis.tail,
        action: body.action,
        player_id: seat,
        now_ms: Date.now(),
      });
      if (!antwoord.ok) {
        await conn.rollback();
        if (antwoord.illegaal) return reply.code(422).send({ fout: String(antwoord.fout ?? "Ongeldige actie") });
        return reply.code(500).send({ fout: `worker faalde: ${String(antwoord.fout ?? "?")}` });
      }
      const seq = hoogste + 1;
      const payload = {
        action: body.action,
        events: (antwoord.events ?? []) as unknown[],
        hash: String(antwoord.hash ?? ""),
      };
      const nowMs = Number(antwoord.now_ms ?? -1);
      await conn.query(
        "INSERT INTO match_events (match_id, seq, player_seat, type, payload, idem_key, now_ms) VALUES (?, ?, ?, ?, ?, ?, ?)",
        [matchId, seq, seat, "action_applied", JSON.stringify(payload), idemKey, nowMs >= 0 ? nowMs : null],
      );
      if (seq % 50 === 0) {
        await conn.query("INSERT INTO snapshots (match_id, seq, staat) VALUES (?, ?, ?)", [
          matchId, seq, JSON.stringify(antwoord.state),
        ]);
      }
      // Game-over administratie op de match-rij (voor lobby's en de F6-meta).
      const events = antwoord.events as { type?: string; payload?: { winner?: number } }[];
      const einde = events.find((e) => String(e.type) === "game_over");
      if (einde) {
        const staat = antwoord.state as { eind_reden?: string };
        await conn.query("UPDATE matches SET status = 'klaar', winnaar_seat = ?, eind_reden = ? WHERE id = ?", [
          Number(einde.payload?.winner ?? 0) || null, String(staat?.eind_reden ?? ""), matchId,
        ]);
      }
      await conn.commit();
      const rij: EventRij = { seq, player_seat: seat, type: "action_applied", payload };
      const clientRij = naarClientRij(rij);
      app.matchStream.push(matchId, [clientRij]);
      return { events: [clientRij] };
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
    const events = await clientRijenSinds(db, matchId, Number.isInteger(na) && na >= 0 ? na : 0);
    return { events };
  });

  // De gefilterde view van JOUW kant (View.for_player via de worker): dit is
  // wat de F4.3-client rendert, en het reconnect-startpunt.
  app.get("/matches/:id/view", async (req, reply) => {
    const ik = await wieIsDit(db, req);
    if (!ik) return reply.code(401).send({ fout: "Niet ingelogd" });
    const matchId = String((req.params as { id: string }).id);
    const [seatRows] = await db.query<RowDataPacket[]>(
      "SELECT seat FROM match_seats WHERE match_id = ? AND user_id = ?", [matchId, ik.userId]);
    if (!seatRows[0]) return reply.code(403).send({ fout: "Je zit niet in deze match" });
    const basis = await laadBasis(db, matchId);
    if (!basis) return reply.code(409).send({ fout: "De match is nog niet begonnen" });
    const antwoord = await worker().vraag({
      op: "view", state: basis.state, tail: basis.tail, player_id: Number(seatRows[0].seat),
    });
    if (!antwoord.ok) return reply.code(500).send({ fout: String(antwoord.fout ?? "?") });
    const [top] = await db.query<RowDataPacket[]>(
      "SELECT COALESCE(MAX(seq), 0) AS hoogste FROM match_events WHERE match_id = ?", [matchId]);
    return { seq: Number(top[0]?.hoogste ?? 0), view: antwoord.view };
  });

  // Client en worker moeten dezelfde engine draaien (bouwplan §11.5).
  app.get("/versie", async () => {
    if (worker().coreHash.length === 0) await worker().vraag({ op: "ping" });
    return { core_hash: worker().coreHash };
  });

  // WS: live events per match; gaten dicht je met GET /events?after=seq.
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
  private luisteraars = new Map<string, Set<(events: unknown[]) => void>>();

  abonneer(matchId: string, cb: (events: unknown[]) => void): () => void {
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

  push(matchId: string, events: unknown[]): void {
    for (const cb of this.luisteraars.get(matchId) ?? []) cb(events);
  }
}

declare module "fastify" {
  interface FastifyInstance {
    matchStream: MatchStream;
    worker: GodotWorker;
  }
}
