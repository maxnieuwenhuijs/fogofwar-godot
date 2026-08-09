// F4.1 — accounts (§9.1): gast-eerst. Het device-token (client-UUID in
// user://identity.cfg) IS het account; upgraden naar e-mail+wachtwoord maakt
// het cross-device. Sessietokens zijn losse, intrekbare handles.
import { randomBytes, randomUUID, scryptSync, timingSafeEqual } from "node:crypto";
import type { FastifyInstance, FastifyRequest } from "fastify";
import type { RowDataPacket } from "mysql2/promise";
import type { Db } from "./db.js";
import { naamProbleem } from "./namen.js";

// 31-alfabet zonder O/0/I/1 (zelfde afspraak als de roomcodes uit het
// online-plan): voorleesbaar door een telefoon heen.
const CODE_ALFABET = "23456789ABCDEFGHJKLMNPQRSTUVWXYZ".replace("O", "").replace("I", "");

export function maakVriendcode(): string {
  const bytes = randomBytes(8);
  let uit = "";
  for (const b of bytes) uit += CODE_ALFABET[b % CODE_ALFABET.length];
  return uit;
}

function hashWachtwoord(wachtwoord: string): string {
  const salt = randomBytes(16).toString("hex");
  const hash = scryptSync(wachtwoord, salt, 64).toString("hex");
  return `${salt}$${hash}`;
}

function checkWachtwoord(wachtwoord: string, opgeslagen: string): boolean {
  const [salt, hash] = opgeslagen.split("$");
  if (!salt || !hash) return false;
  const kandidaat = scryptSync(wachtwoord, salt, 64);
  return timingSafeEqual(kandidaat, Buffer.from(hash, "hex"));
}

export interface Ingelogd {
  userId: string;
  naam: string;
}

/** Sessietoken uit de Authorization-header naar een user, of null. */
export async function wieIsDit(db: Db, req: FastifyRequest): Promise<Ingelogd | null> {
  const kop = req.headers.authorization ?? "";
  const token = kop.startsWith("Bearer ") ? kop.slice(7) : "";
  if (token.length === 0) return null;
  const [rows] = await db.query<RowDataPacket[]>(
    "SELECT u.id, u.naam FROM sessies s JOIN users u ON u.id = s.user_id WHERE s.token = ?",
    [token],
  );
  const rij = rows[0];
  if (!rij) return null;
  return { userId: rij.id as string, naam: rij.naam as string };
}

async function nieuweSessie(db: Db, userId: string): Promise<string> {
  const token = randomBytes(32).toString("hex");
  await db.query("INSERT INTO sessies (token, user_id) VALUES (?, ?)", [token, userId]);
  return token;
}

async function userProfiel(db: Db, userId: string) {
  const [rows] = await db.query<RowDataPacket[]>(
    "SELECT id, naam, email, avatar_doctrine, avatar_kleur, vriendcode FROM users WHERE id = ?",
    [userId],
  );
  return rows[0] ?? null;
}

export function registreerAuthRoutes(app: FastifyInstance, db: Db): void {
  // Gast-eerst: bestaat het device-token al, dan is dit een terugkerende
  // speler (zelfde user, verse sessie); anders wordt er ter plekke een
  // account gemaakt. Nul frictie: naam mag leeg (Gast-XXXX).
  app.post("/auth/gast", async (req, reply) => {
    const body = (req.body ?? {}) as { device_token?: string; naam?: string };
    const device = String(body.device_token ?? "");
    if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(device)) {
      return reply.code(400).send({ fout: "device_token moet een UUID zijn" });
    }
    const [bestaand] = await db.query<RowDataPacket[]>(
      "SELECT id FROM users WHERE device_token = ?",
      [device],
    );
    let userId: string;
    if (bestaand[0]) {
      userId = bestaand[0].id as string;
      if (body.naam !== undefined) {
        const probleem = naamProbleem(String(body.naam));
        if (probleem) return reply.code(400).send({ fout: probleem });
        await db.query("UPDATE users SET naam = ? WHERE id = ?", [String(body.naam).trim(), userId]);
      }
    } else {
      const naam = body.naam !== undefined ? String(body.naam) : `Gast-${maakVriendcode().slice(0, 4)}`;
      const probleem = naamProbleem(naam);
      if (probleem) return reply.code(400).send({ fout: probleem });
      userId = randomUUID();
      await db.query(
        "INSERT INTO users (id, device_token, naam, vriendcode) VALUES (?, ?, ?, ?)",
        [userId, device, naam.trim(), maakVriendcode()],
      );
    }
    const token = await nieuweSessie(db, userId);
    return { sessie_token: token, user: await userProfiel(db, userId) };
  });

  // Upgrade: koppel e-mail + wachtwoord aan het gast-account (cross-device).
  app.post("/auth/upgrade", async (req, reply) => {
    const ik = await wieIsDit(db, req);
    if (!ik) return reply.code(401).send({ fout: "Niet ingelogd" });
    const body = (req.body ?? {}) as { email?: string; wachtwoord?: string };
    const email = String(body.email ?? "").trim().toLowerCase();
    const wachtwoord = String(body.wachtwoord ?? "");
    if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) {
      return reply.code(400).send({ fout: "Geen geldig e-mailadres" });
    }
    if (wachtwoord.length < 8) {
      return reply.code(400).send({ fout: "Wachtwoord: minstens 8 tekens" });
    }
    try {
      await db.query("UPDATE users SET email = ?, wachtwoord = ? WHERE id = ?", [
        email,
        hashWachtwoord(wachtwoord),
        ik.userId,
      ]);
    } catch (e: unknown) {
      if ((e as { code?: string }).code === "ER_DUP_ENTRY") {
        return reply.code(409).send({ fout: "Dat e-mailadres is al gekoppeld" });
      }
      throw e;
    }
    return { user: await userProfiel(db, ik.userId) };
  });

  // Login op een ander apparaat: e-mail + wachtwoord → zelfde account, en het
  // nieuwe device-token wordt (indien meegegeven) overgenomen zodat de
  // reconnect-sleutel van dit apparaat voortaan ook werkt.
  app.post("/auth/login", async (req, reply) => {
    const body = (req.body ?? {}) as { email?: string; wachtwoord?: string; device_token?: string };
    const email = String(body.email ?? "").trim().toLowerCase();
    const [rows] = await db.query<RowDataPacket[]>(
      "SELECT id, wachtwoord FROM users WHERE email = ?",
      [email],
    );
    const rij = rows[0];
    if (!rij || !rij.wachtwoord || !checkWachtwoord(String(body.wachtwoord ?? ""), rij.wachtwoord as string)) {
      return reply.code(401).send({ fout: "E-mail of wachtwoord klopt niet" });
    }
    const userId = rij.id as string;
    const device = String(body.device_token ?? "");
    if (/^[0-9a-f-]{36}$/i.test(device)) {
      // Best effort: botst het token met een ander account, laat het dan staan.
      try {
        await db.query("UPDATE users SET device_token = ? WHERE id = ?", [device, userId]);
      } catch {
        /* device_token blijft van het oude account */
      }
    }
    const token = await nieuweSessie(db, userId);
    return { sessie_token: token, user: await userProfiel(db, userId) };
  });

  // Profiel: naam (door het filter) en avatar (doctrine-embleem + kleur).
  app.patch("/profiel", async (req, reply) => {
    const ik = await wieIsDit(db, req);
    if (!ik) return reply.code(401).send({ fout: "Niet ingelogd" });
    const body = (req.body ?? {}) as { naam?: string; avatar_doctrine?: number; avatar_kleur?: string };
    if (body.naam !== undefined) {
      const probleem = naamProbleem(String(body.naam));
      if (probleem) return reply.code(400).send({ fout: probleem });
      await db.query("UPDATE users SET naam = ? WHERE id = ?", [String(body.naam).trim(), ik.userId]);
    }
    if (body.avatar_doctrine !== undefined) {
      const d = Number(body.avatar_doctrine);
      if (!Number.isInteger(d) || d < 0 || d > 5) {
        return reply.code(400).send({ fout: "avatar_doctrine is 0..5" });
      }
      await db.query("UPDATE users SET avatar_doctrine = ? WHERE id = ?", [d, ik.userId]);
    }
    if (body.avatar_kleur !== undefined) {
      if (!/^#[0-9a-f]{6}$/i.test(String(body.avatar_kleur))) {
        return reply.code(400).send({ fout: "avatar_kleur is #rrggbb" });
      }
      await db.query("UPDATE users SET avatar_kleur = ? WHERE id = ?", [String(body.avatar_kleur), ik.userId]);
    }
    return { user: await userProfiel(db, ik.userId) };
  });

  // Vrienden via code (tabel + endpoint; UI volgt in F4.4).
  app.post("/vrienden", async (req, reply) => {
    const ik = await wieIsDit(db, req);
    if (!ik) return reply.code(401).send({ fout: "Niet ingelogd" });
    const code = String(((req.body ?? {}) as { code?: string }).code ?? "").trim().toUpperCase();
    const [rows] = await db.query<RowDataPacket[]>("SELECT id, naam FROM users WHERE vriendcode = ?", [code]);
    const ander = rows[0];
    if (!ander) return reply.code(404).send({ fout: "Onbekende vriendcode" });
    if ((ander.id as string) === ik.userId) return reply.code(400).send({ fout: "Dat ben je zelf" });
    await db.query("INSERT IGNORE INTO vrienden (user_id, vriend_id) VALUES (?, ?), (?, ?)", [
      ik.userId, ander.id, ander.id, ik.userId,
    ]);
    return { vriend: { id: ander.id, naam: ander.naam } };
  });

  app.get("/vrienden", async (req, reply) => {
    const ik = await wieIsDit(db, req);
    if (!ik) return reply.code(401).send({ fout: "Niet ingelogd" });
    const [rows] = await db.query<RowDataPacket[]>(
      "SELECT u.id, u.naam, u.avatar_doctrine, u.avatar_kleur FROM vrienden v JOIN users u ON u.id = v.vriend_id WHERE v.user_id = ?",
      [ik.userId],
    );
    return { vrienden: rows };
  });
}
