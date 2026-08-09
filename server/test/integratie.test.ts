// F4.1 — de CHECK uit het masterplan, tegen een ECHTE MySQL (testcontainers):
//   1. actie posten → event terug
//   2. dubbel posten met zelfde idem_key → geen duplicaat
//   3. seq-conflict → 409 met inhaal-events
//   4. gast-upgrade-flow (gast → e-mail → login op een "ander apparaat")
//   5. profaniteitsfilter weigert testwoorden
import { randomUUID } from "node:crypto";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import type { FastifyInstance } from "fastify";
import mysql from "mysql2/promise";
import { bouwApp } from "../src/app.js";

// Twee smaken database (masterplan F4-prereq):
//   - default: testcontainers trekt zelf een MySQL omhoog (CI, machines met
//     een werkende Docker);
//   - FOW_TEST_DB_URL gezet: een al draaiende MySQL — de database uit de URL
//     wordt per run GEWIST en vers opgebouwd. Dit is de fallback voor
//     machines waar Docker niet kan (9 augustus: Max' Windows heeft een
//     AF_UNIX-reparse-bug waardoor Docker Desktop niet opstart).
//     Lokaal: FOW_TEST_DB_URL=mysql://root@127.0.0.1:3316/fogofwar_test
const EXTERNE_DB = process.env.FOW_TEST_DB_URL ?? "";

let container: { stop(): Promise<unknown> } | null = null;
let app: FastifyInstance;

beforeAll(async () => {
  let url: string;
  if (EXTERNE_DB.length > 0) {
    const u = new URL(EXTERNE_DB);
    const dbnaam = u.pathname.slice(1);
    if (dbnaam.length === 0 || !/^[a-z0-9_]+$/i.test(dbnaam)) {
      throw new Error("FOW_TEST_DB_URL moet op een databasenaam eindigen (alleen letters/cijfers/_)");
    }
    u.pathname = "/";
    const beheer = await mysql.createConnection(u.toString());
    await beheer.query(`DROP DATABASE IF EXISTS \`${dbnaam}\``);
    await beheer.query(`CREATE DATABASE \`${dbnaam}\``);
    await beheer.end();
    url = EXTERNE_DB;
  } else {
    const { MySqlContainer } = await import("@testcontainers/mysql");
    const c = await new MySqlContainer("mysql:8.0")
      .withDatabase("fogofwar")
      .withUsername("fogofwar")
      .withUserPassword("geheim")
      .start();
    container = c;
    url = c.getConnectionUri();
  }
  const uit = await bouwApp({ databaseUrl: url });
  app = uit.app;
}, 240_000);

afterAll(async () => {
  await app?.close();
  await container?.stop();
});

async function gast(naam?: string): Promise<{ token: string; user: Record<string, unknown> }> {
  const res = await app.inject({
    method: "POST",
    url: "/auth/gast",
    payload: { device_token: randomUUID(), ...(naam === undefined ? {} : { naam }) },
  });
  expect(res.statusCode).toBe(200);
  const body = res.json();
  return { token: body.sessie_token, user: body.user };
}

describe("accounts (gast-eerst, §9.1)", () => {
  it("zelfde device-token is dezelfde speler", async () => {
    const device = randomUUID();
    const a = await app.inject({ method: "POST", url: "/auth/gast", payload: { device_token: device } });
    const b = await app.inject({ method: "POST", url: "/auth/gast", payload: { device_token: device } });
    expect(a.json().user.id).toBe(b.json().user.id);
    expect(a.json().sessie_token).not.toBe(b.json().sessie_token);
  });

  it("gast-upgrade-flow: e-mail koppelen en op een ander apparaat inloggen", async () => {
    const { token, user } = await gast("Maximiliaan");
    const upgrade = await app.inject({
      method: "POST",
      url: "/auth/upgrade",
      headers: { authorization: `Bearer ${token}` },
      payload: { email: "max@voorbeeld.nl", wachtwoord: "wachtwoord123" },
    });
    expect(upgrade.statusCode).toBe(200);
    expect(upgrade.json().user.email).toBe("max@voorbeeld.nl");
    // "Ander apparaat": vers device-token, inloggen met e-mail → zelfde user.
    const login = await app.inject({
      method: "POST",
      url: "/auth/login",
      payload: { email: "max@voorbeeld.nl", wachtwoord: "wachtwoord123", device_token: randomUUID() },
    });
    expect(login.statusCode).toBe(200);
    expect(login.json().user.id).toBe(user.id);
    // Fout wachtwoord blijft buiten.
    const fout = await app.inject({
      method: "POST",
      url: "/auth/login",
      payload: { email: "max@voorbeeld.nl", wachtwoord: "verkeerd123" },
    });
    expect(fout.statusCode).toBe(401);
  });

  it("profaniteitsfilter weigert testwoorden, ook in leet-speak", async () => {
    for (const naam of ["kankerlijer", "K4nker", "fuckface", "sh1thead"]) {
      const res = await app.inject({
        method: "POST",
        url: "/auth/gast",
        payload: { device_token: randomUUID(), naam },
      });
      expect(res.statusCode, naam).toBe(400);
    }
    const netjes = await app.inject({
      method: "POST",
      url: "/auth/gast",
      payload: { device_token: randomUUID(), naam: "Scharnier-Kanon" },
    });
    expect(netjes.statusCode).toBe(200);
  });

  it("vriendcodes: toevoegen op code, jezelf niet", async () => {
    const a = await gast("SpelerA");
    const b = await gast("SpelerB");
    const zelf = await app.inject({
      method: "POST", url: "/vrienden",
      headers: { authorization: `Bearer ${a.token}` },
      payload: { code: a.user.vriendcode },
    });
    expect(zelf.statusCode).toBe(400);
    const voegtoe = await app.inject({
      method: "POST", url: "/vrienden",
      headers: { authorization: `Bearer ${a.token}` },
      payload: { code: b.user.vriendcode },
    });
    expect(voegtoe.statusCode).toBe(200);
    const lijst = await app.inject({
      method: "GET", url: "/vrienden",
      headers: { authorization: `Bearer ${b.token}` },
    });
    expect(lijst.json().vrienden.map((v: { naam: string }) => v.naam)).toContain("SpelerA");
  });
});

describe("actieprotocol (bouwplan §10)", () => {
  async function verseMatch() {
    const p1 = await gast("EchteVarken");
    const p2 = await gast("EchteMuis");
    const maak = await app.inject({
      method: "POST", url: "/matches",
      headers: { authorization: `Bearer ${p1.token}` },
      payload: { rules_version: "4.3.1", rules_config: { doctrines: { "0": { comp: [11, 5, 3] } } } },
    });
    expect(maak.statusCode).toBe(200);
    const matchId = maak.json().match_id as string;
    const join = await app.inject({
      method: "POST", url: `/matches/${matchId}/join`,
      headers: { authorization: `Bearer ${p2.token}` },
    });
    expect(join.json().seat).toBe(2);
    return { matchId, p1, p2 };
  }

  it("actie posten geeft een event met een dicht seq terug", async () => {
    const { matchId, p1 } = await verseMatch();
    const res = await app.inject({
      method: "POST", url: `/matches/${matchId}/acties`,
      headers: { authorization: `Bearer ${p1.token}` },
      payload: { seq_expected: 0, idem_key: randomUUID(), action: { type: "choose_doctrine", doctrine: 5 } },
    });
    expect(res.statusCode).toBe(200);
    const events = res.json().events;
    expect(events).toHaveLength(1);
    expect(events[0].seq).toBe(1);
    expect(events[0].type).toBe("action_accepted");
    expect(events[0].payload.action.doctrine).toBe(5);
    expect(events[0].payload.door_seat).toBe(1);
  });

  it("zelfde idem_key nogmaals posten maakt geen duplicaat", async () => {
    const { matchId, p1 } = await verseMatch();
    const idem = randomUUID();
    const actie = { seq_expected: 0, idem_key: idem, action: { type: "choose_doctrine", doctrine: 1 } };
    const een = await app.inject({
      method: "POST", url: `/matches/${matchId}/acties`,
      headers: { authorization: `Bearer ${p1.token}` }, payload: actie,
    });
    const twee = await app.inject({
      method: "POST", url: `/matches/${matchId}/acties`,
      headers: { authorization: `Bearer ${p1.token}` }, payload: actie,
    });
    expect(een.statusCode).toBe(200);
    expect(twee.statusCode).toBe(200);
    expect(twee.json().herhaald).toBe(true);
    const alles = await app.inject({
      method: "GET", url: `/matches/${matchId}/events?after=0`,
      headers: { authorization: `Bearer ${p1.token}` },
    });
    expect(alles.json().events).toHaveLength(1);
  });

  it("seq-conflict geeft 409 met de inhaal-events", async () => {
    const { matchId, p1, p2 } = await verseMatch();
    await app.inject({
      method: "POST", url: `/matches/${matchId}/acties`,
      headers: { authorization: `Bearer ${p1.token}` },
      payload: { seq_expected: 0, idem_key: randomUUID(), action: { type: "choose_doctrine", doctrine: 0 } },
    });
    // P2 denkt dat er nog niets gebeurd is → conflict + precies het gemiste event.
    const conflict = await app.inject({
      method: "POST", url: `/matches/${matchId}/acties`,
      headers: { authorization: `Bearer ${p2.token}` },
      payload: { seq_expected: 0, idem_key: randomUUID(), action: { type: "choose_doctrine", doctrine: 3 } },
    });
    expect(conflict.statusCode).toBe(409);
    expect(conflict.json().events).toHaveLength(1);
    expect(conflict.json().events[0].seq).toBe(1);
    // Bijgelopen → dezelfde actie slaagt op seq_expected 1.
    const opnieuw = await app.inject({
      method: "POST", url: `/matches/${matchId}/acties`,
      headers: { authorization: `Bearer ${p2.token}` },
      payload: { seq_expected: 1, idem_key: randomUUID(), action: { type: "choose_doctrine", doctrine: 3 } },
    });
    expect(opnieuw.statusCode).toBe(200);
    expect(opnieuw.json().events[0].seq).toBe(2);
  });

  it("buitenstaanders komen er niet in", async () => {
    const { matchId } = await verseMatch();
    const vreemdeling = await gast("Pottenkijker");
    const res = await app.inject({
      method: "POST", url: `/matches/${matchId}/acties`,
      headers: { authorization: `Bearer ${vreemdeling.token}` },
      payload: { seq_expected: 0, idem_key: randomUUID(), action: { type: "resign" } },
    });
    expect(res.statusCode).toBe(403);
  });
});
