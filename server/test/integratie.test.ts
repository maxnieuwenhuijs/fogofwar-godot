// F4.1+F4.2 — de CHECKS uit het masterplan, tegen een ECHTE MySQL en een
// ECHTE Godot-worker:
//   F4.1: actie → event; dubbele idem_key → geen duplicaat; seq-conflict →
//         409 met inhaal-events; gast-upgrade-flow; profaniteitsfilter.
//   F4.2: elke actie door Validator/Reducer (422 bij illegaal); volledige
//         partij via de server naspelen = zelfde eind-zobrist als lokaal;
//         worker killen midden in het spel → heropgepakt zonder duplicaten.
import { randomUUID } from "node:crypto";
import { mkdir, readFile } from "node:fs/promises";
import { existsSync } from "node:fs";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { dirname, join, resolve } from "node:path";
import { fileURLToPath } from "node:url";
import { afterAll, beforeAll, describe, expect, it } from "vitest";
import type { FastifyInstance } from "fastify";
import mysql from "mysql2/promise";
import { bouwApp } from "../src/app.js";

const uitvoeren = promisify(execFile);

// Twee smaken database (masterplan F4-prereq):
//   - default: testcontainers trekt zelf een MySQL omhoog (CI, machines met
//     een werkende Docker);
//   - FOW_TEST_DB_URL gezet: een al draaiende MySQL — de database uit de URL
//     wordt per run GEWIST en vers opgebouwd. Dit is de fallback voor
//     machines waar Docker niet kan (9 augustus: Max' Windows heeft een
//     AF_UNIX-reparse-bug waardoor Docker Desktop niet opstart).
//     Lokaal: FOW_TEST_DB_URL=mysql://root@127.0.0.1:3316/fogofwar_test
const EXTERNE_DB = process.env.FOW_TEST_DB_URL ?? "";

const HIER = dirname(fileURLToPath(import.meta.url));
const REPO = resolve(HIER, "..", "..");
const GODOT = process.env.GODOT_PAD ?? process.env.GODOT_PATH
  ?? "C:\\Users\\maxni\\Downloads\\Godot_v4.7-stable_win64.exe\\Godot_v4.7-stable_win64_console.exe";

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
  const uit = await bouwApp({ databaseUrl: url, godotPad: GODOT, projectPad: REPO });
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
    const login = await app.inject({
      method: "POST",
      url: "/auth/login",
      payload: { email: "max@voorbeeld.nl", wachtwoord: "wachtwoord123", device_token: randomUUID() },
    });
    expect(login.statusCode).toBe(200);
    expect(login.json().user.id).toBe(user.id);
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

interface Speler { token: string; user: Record<string, unknown> }

async function verseMatch(rulesConfig: unknown = {}): Promise<{ matchId: string; p1: Speler; p2: Speler }> {
  const p1 = await gast("EchteVarken");
  const p2 = await gast("EchteMuis");
  const maak = await app.inject({
    method: "POST", url: "/matches",
    headers: { authorization: `Bearer ${p1.token}` },
    payload: { rules_version: "4.3.1", rules_config: rulesConfig },
  });
  expect(maak.statusCode).toBe(200);
  const matchId = maak.json().match_id as string;
  const join = await app.inject({
    method: "POST", url: `/matches/${matchId}/join`,
    headers: { authorization: `Bearer ${p2.token}` },
  });
  expect(join.statusCode).toBe(200);
  expect(join.json().seat).toBe(2);
  return { matchId, p1, p2 };
}

async function postActie(matchId: string, speler: Speler, seq: number, action: unknown, idem?: string) {
  return await app.inject({
    method: "POST", url: `/matches/${matchId}/acties`,
    headers: { authorization: `Bearer ${speler.token}` },
    payload: { seq_expected: seq, idem_key: idem ?? randomUUID(), action },
  });
}

describe("actieprotocol met de echte engine (§10 + F4.2)", () => {
  it("actie posten geeft reducer-events terug, zonder de actie zelf", async () => {
    const { matchId, p1 } = await verseMatch();
    const res = await postActie(matchId, p1, 0, { type: "choose_doctrine", doctrine: 5 });
    expect(res.statusCode).toBe(200);
    const events = res.json().events;
    expect(events).toHaveLength(1);
    expect(events[0].seq).toBe(1);
    expect(events[0].type).toBe("action_applied");
    expect(events[0].player_seat).toBe(1);
    // Echte reducer-events; de blinde keuze zelf reist NIET mee naar clients.
    const types = events[0].payload.events.map((e: { type: string }) => e.type);
    expect(types).toContain("doctrine_committed");
    expect(events[0].payload.action).toBeUndefined();
    expect(String(events[0].payload.hash)).toMatch(/^[0-9a-f]{64}$/);
  });

  it("de engine weigert een illegale actie met 422", async () => {
    const { matchId, p1 } = await verseMatch();
    expect((await postActie(matchId, p1, 0, { type: "choose_doctrine", doctrine: 5 })).statusCode).toBe(200);
    const dubbel = await postActie(matchId, p1, 1, { type: "choose_doctrine", doctrine: 1 });
    expect(dubbel.statusCode).toBe(422);
    expect(dubbel.json().fout).toBe("Al een factie gekozen");
    const onzin = await postActie(matchId, p1, 1, { type: "choose_doctrine", doctrine: 99 });
    expect(onzin.statusCode).toBe(422);
  });

  it("zelfde idem_key nogmaals posten maakt geen duplicaat", async () => {
    const { matchId, p1 } = await verseMatch();
    const idem = randomUUID();
    const een = await postActie(matchId, p1, 0, { type: "choose_doctrine", doctrine: 1 }, idem);
    const twee = await postActie(matchId, p1, 0, { type: "choose_doctrine", doctrine: 1 }, idem);
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
    await postActie(matchId, p1, 0, { type: "choose_doctrine", doctrine: 0 });
    const conflict = await postActie(matchId, p2, 0, { type: "choose_doctrine", doctrine: 3 });
    expect(conflict.statusCode).toBe(409);
    expect(conflict.json().events).toHaveLength(1);
    expect(conflict.json().events[0].seq).toBe(1);
    const opnieuw = await postActie(matchId, p2, 1, { type: "choose_doctrine", doctrine: 3 });
    expect(opnieuw.statusCode).toBe(200);
    expect(opnieuw.json().events[0].seq).toBe(2);
    // Beide keuzes binnen → de reveal is er en de opstelfase is open.
    const types = opnieuw.json().events[0].payload.events.map((e: { type: string }) => e.type);
    expect(types).toContain("doctrines_revealed");
  });

  it("de view volgt jouw kant en verklapt de blinde keuze niet", async () => {
    const { matchId, p1, p2 } = await verseMatch();
    expect((await postActie(matchId, p1, 0, { type: "choose_doctrine", doctrine: 5 })).statusCode).toBe(200);
    const vanP2 = await app.inject({
      method: "GET", url: `/matches/${matchId}/view`,
      headers: { authorization: `Bearer ${p2.token}` },
    });
    expect(vanP2.statusCode).toBe(200);
    const view = vanP2.json().view;
    expect(view.viewer).toBe(2);
    expect(view.enemy_has_chosen).toBe(true);
    expect(view.own_doctrine_commit).toBe(-1);
    expect(JSON.stringify(view)).not.toContain("doctrine_commits");
  });

  it("buitenstaanders komen er niet in", async () => {
    const { matchId } = await verseMatch();
    const vreemdeling = await gast("Pottenkijker");
    const res = await postActie(matchId, vreemdeling, 0, { type: "resign" });
    expect(res.statusCode).toBe(403);
  });

  it("een gestorven worker wordt heropgepakt zonder dubbele events", async () => {
    const { matchId, p1, p2 } = await verseMatch();
    const idem = randomUUID();
    expect((await postActie(matchId, p1, 0, { type: "choose_doctrine", doctrine: 4 }, idem)).statusCode).toBe(200);
    // Kill de worker hard, midden in de partij.
    app.worker.kindProces?.kill();
    // Volgende actie: de pool herstart de worker en de actie slaagt gewoon.
    const naKill = await postActie(matchId, p2, 1, { type: "choose_doctrine", doctrine: 2 });
    expect(naKill.statusCode).toBe(200);
    // En de idem-herhaling van vóór de kill blijft een herhaling: geen dubbel.
    const herhaald = await postActie(matchId, p1, 0, { type: "choose_doctrine", doctrine: 4 }, idem);
    expect(herhaald.statusCode).toBe(200);
    expect(herhaald.json().herhaald).toBe(true);
    const alles = await app.inject({
      method: "GET", url: `/matches/${matchId}/events?after=0`,
      headers: { authorization: `Bearer ${p1.token}` },
    });
    expect(alles.json().events).toHaveLength(2);
  }, 120_000);
});

describe("volledige partij door de server = byte-identiek aan lokaal (F4.2-CHECK)", () => {
  interface Opname {
    meta: { initial_state: { rules: Record<string, unknown>; doctrines: Record<string, number> } };
    final_hash: string;
    entries: { seq: number; player_id: number; action: Record<string, unknown> }[];
  }
  let opname: Opname;

  beforeAll(async () => {
    // De referentiepartij komt uit de OFFLINE engine zelf (capture -- record):
    // gegenereerd bij de eerste run, daarna gecachet. Zo kan de fixture nooit
    // uit de pas lopen met de engine zonder dat deze test het ziet.
    const cache = join(HIER, ".cache");
    const pad = join(cache, "referentie_partij.json");
    if (!existsSync(pad)) {
      await mkdir(cache, { recursive: true });
      await uitvoeren(GODOT, [
        "--headless", "--path", REPO, "res://tools/capture.tscn", "--",
        "record", pad.replaceAll("\\", "/"), "easy", "easy", "muis", "wolf", "777",
      ], { cwd: REPO, timeout: 240_000 });
    }
    opname = JSON.parse(await readFile(pad, "utf8"));
    expect(opname.entries.length).toBeGreaterThan(50);
  }, 300_000);

  it("speelt de opgenomen partij na met dezelfde eind-zobrist", async () => {
    const doctrines = opname.meta.initial_state.doctrines;
    const { matchId, p1, p2 } = await verseMatch(opname.meta.initial_state.rules);
    const spelers: Record<number, Speler> = { 1: p1, 2: p2 };
    // De blinde factie-keuzes eerst (online begint in PRE_GAME, F4.0).
    expect((await postActie(matchId, p1, 0, { type: "choose_doctrine", doctrine: doctrines["1"] })).statusCode).toBe(200);
    expect((await postActie(matchId, p2, 1, { type: "choose_doctrine", doctrine: doctrines["2"] })).statusCode).toBe(200);
    // Daarna elke opgenomen actie, in volgorde, door de echte scheidsrechter.
    let laatsteHash = "";
    for (const entry of opname.entries) {
      const res = await postActie(matchId, spelers[entry.player_id]!, 2 + entry.seq, entry.action);
      expect(res.statusCode, `entry ${entry.seq} (${String(entry.action.type)})`).toBe(200);
      laatsteHash = String(res.json().events[0].payload.hash);
    }
    // Dezelfde engine, dezelfde acties, dezelfde staat: byte-identiek.
    expect(laatsteHash).toBe(opname.final_hash);
    // En de match-administratie zag het einde ook.
    const [rij] = (await app.inject({
      method: "GET", url: `/matches/${matchId}/events?after=${opname.entries.length + 1}`,
      headers: { authorization: `Bearer ${p1.token}` },
    }).then((r) => [r.json().events.at(-1)]));
    expect(rij.payload.events.map((e: { type: string }) => e.type)).toContain("game_over");
  }, 600_000);
});
