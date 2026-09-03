// F4.1+F4.2 — de CHECKS uit het masterplan, tegen een ECHTE MySQL en een
// ECHTE Godot-worker:
//   F4.1: actie → event; dubbele idem_key → geen duplicaat; seq-conflict →
//         409 met inhaal-events; gast-upgrade-flow; profaniteitsfilter.
//   F4.2: elke actie door Validator/Reducer (422 bij illegaal); volledige
//         partij via de server naspelen = zelfde eind-zobrist als lokaal;
//         worker killen midden in het spel → heropgepakt zonder duplicaten.
//   F4.2b: de client-stream draagt geen hash en geen cp_bet (blinde keuzes
//         zijn anders te brute-forcen); WS en /events alleen met een seat;
//         de redactielijst van Node = die van de worker; matchstatus-route;
//         een ontbrekende Godot-binary is een nette fout, geen outage.
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
import type { RowDataPacket } from "mysql2/promise";
import { bouwApp } from "../src/app.js";
import type { Db } from "../src/db.js";
import { SERVER_ONLY_EVENTS } from "../src/matches.js";
import { GodotWorker } from "../src/worker.js";

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
let db: Db;
// Echte poort voor de WebSocket-tests (inject kent geen WS-upgrade).
let basisUrl = "";

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
  db = uit.db;
  await app.listen({ port: 0, host: "127.0.0.1" });
  const adres = app.server.address();
  if (!adres || typeof adres !== "object") throw new Error("geen luisterpoort");
  basisUrl = `127.0.0.1:${adres.port}`;
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
    // F4.2b: ook de hash blijft bij de server (brute-forceerbaar met dezelfde engine).
    expect(events[0].payload.hash).toBeUndefined();
    expect(Object.keys(events[0].payload)).toEqual(["events"]);
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

interface Opname {
  meta: { initial_state: { rules: Record<string, unknown>; doctrines: Record<string, number> } };
  final_hash: string;
  entries: { seq: number; player_id: number; action: Record<string, unknown> }[];
}
let opnameCache: Opname | null = null;

// De referentiepartij komt uit de OFFLINE engine zelf (capture -- record):
// gegenereerd bij de eerste run, daarna gecachet. Zo kan de fixture nooit
// uit de pas lopen met de engine zonder dat deze test het ziet.
async function opnameLaden(): Promise<Opname> {
  if (opnameCache) return opnameCache;
  const cache = join(HIER, ".cache");
  const pad = join(cache, "referentie_partij.json");
  if (!existsSync(pad)) {
    await mkdir(cache, { recursive: true });
    await uitvoeren(GODOT, [
      "--headless", "--path", REPO, "res://tools/capture.tscn", "--",
      "record", pad.replaceAll("\\", "/"), "easy", "easy", "muis", "wolf", "777",
    ], { cwd: REPO, timeout: 240_000 });
  }
  opnameCache = JSON.parse(await readFile(pad, "utf8")) as Opname;
  expect(opnameCache.entries.length).toBeGreaterThan(50);
  return opnameCache;
}

/** Het rauwe log (server-only) van de jongste rij: hier woont de hash. */
async function rauweRij(matchId: string): Promise<{ seq: number; payload: { hash?: string; events?: { type: string }[] } }> {
  const [rows] = await db.query<RowDataPacket[]>(
    "SELECT seq, payload FROM match_events WHERE match_id = ? ORDER BY seq DESC LIMIT 1", [matchId]);
  return rows[0] as unknown as { seq: number; payload: { hash?: string; events?: { type: string }[] } };
}

/** Beide factie-keuzes, daarna de twee opgenomen opstellingen: de partij staat in DEFINE. */
async function totDefine(rulesConfig: Record<string, unknown>) {
  const opname = await opnameLaden();
  const doctrines = opname.meta.initial_state.doctrines;
  const { matchId, p1, p2 } = await verseMatch(rulesConfig);
  expect((await postActie(matchId, p1, 0, { type: "choose_doctrine", doctrine: doctrines["1"] })).statusCode).toBe(200);
  expect((await postActie(matchId, p2, 1, { type: "choose_doctrine", doctrine: doctrines["2"] })).statusCode).toBe(200);
  const plaats = opname.entries.filter((e) => e.action.type === "place");
  expect(plaats).toHaveLength(2);
  const spelers: Record<number, Speler> = { 1: p1, 2: p2 };
  let seq = 2;
  for (const e of plaats) {
    const res = await postActie(matchId, spelers[e.player_id]!, seq, e.action);
    expect(res.statusCode, `place p${e.player_id}: ${res.body}`).toBe(200);
    seq += 1;
  }
  return { matchId, p1, p2, seq };
}

interface WsProef {
  ws: WebSocket;
  /** Sluitcode zodra de verbinding dicht is (4401/4403/4404 = app-codes). */
  gesloten: Promise<number>;
  /** Het volgende JSON-bericht van de server (of een al binnengekomen). */
  volgende: () => Promise<unknown>;
}

/** Node 22 heeft een ingebouwde WebSocket-client; geen extra dependency. */
function wsVerbinding(url: string): Promise<WsProef> {
  return new Promise((resolve, reject) => {
    const ws = new WebSocket(url);
    let sluit: (code: number) => void = () => {};
    const gesloten = new Promise<number>((r) => { sluit = r; });
    const wachtenden: ((v: unknown) => void)[] = [];
    const ontvangen: unknown[] = [];
    const volgende = (): Promise<unknown> =>
      ontvangen.length > 0 ? Promise.resolve(ontvangen.shift()) : new Promise((r) => wachtenden.push(r));
    ws.addEventListener("message", (ev) => {
      const data: unknown = JSON.parse(String((ev as MessageEvent).data));
      const w = wachtenden.shift();
      if (w) w(data); else ontvangen.push(data);
    });
    ws.addEventListener("error", () => { /* de close-code zegt genoeg */ });
    ws.addEventListener("close", (ev) => { sluit((ev as CloseEvent).code); resolve({ ws, gesloten, volgende }); });
    ws.addEventListener("open", () => resolve({ ws, gesloten, volgende }));
    setTimeout(() => reject(new Error("ws-verbinding kwam niet op gang")), 10_000).unref();
  });
}

describe("redactie en toegang (F4.2b)", () => {
  it("de CP-inzet reist in de define mee: één rij, geen hash, geen cp_bet; het rauwe log heeft alles", async () => {
    // Campagne-economie aan (anders is een inzet niet legaal), verder de regels
    // van de referentiepartij zodat de opgenomen opstellingen passen.
    const opname = await opnameLaden();
    const { matchId, p1, p2, seq } = await totDefine({
      ...opname.meta.initial_state.rules,
      campaign: { pool_model: "punten", pools: { "1": 12, "2": 12 } },
    });
    // De opgenomen eerste define van speler 1, met één kaart een punt dikker
    // en de inzet die dat dekt als veld op dezelfde actie (F4.2b).
    const eerste = opname.entries.find((e) => e.player_id === 1 && e.action.type === "define_cards");
    expect(eerste).toBeDefined();
    const kaarten = (eerste!.action.cards as { hp: number; stamina: number; attack: number }[]).map((k) => ({ ...k }));
    kaarten[0]!.hp += 1;
    const define = await postActie(matchId, p1, seq, { type: "define_cards", cards: kaarten, cp_bet: 1 });
    expect(define.statusCode, define.body).toBe(200);
    const rij = define.json().events[0];
    expect(rij.seq).toBe(seq + 1);
    expect(Object.keys(rij.payload)).toEqual(["events"]);
    const types = rij.payload.events.map((e: { type: string }) => e.type);
    expect(types).not.toContain("cp_bet");
    // Eén rij voor inzet én definitie: de tegenstander ziet alleen "gedefinieerd".
    const status = await app.inject({
      method: "GET", url: `/matches/${matchId}`, headers: { authorization: `Bearer ${p2.token}` },
    });
    expect(status.json().seq).toBe(seq + 1);
    const vanP2 = await app.inject({
      method: "GET", url: `/matches/${matchId}/view`, headers: { authorization: `Bearer ${p2.token}` },
    });
    expect(vanP2.json().view.enemy_has_defined).toBe(true);
    expect(JSON.stringify(vanP2.json().view)).not.toContain("enemy_cp_bet");
    // De engine boekte de inzet wel: hij staat in het server-only log, mét hash.
    const rauw = await rauweRij(matchId);
    expect(rauw.seq).toBe(seq + 1);
    expect((rauw.payload.events ?? []).map((e) => e.type)).toContain("cp_bet");
    expect(String(rauw.payload.hash)).toMatch(/^[0-9a-f]{64}$/);
    // Een losse bet_cp blijft legaal (offline, arena) en wordt óók geredigeerd.
    const los = await postActie(matchId, p2, seq + 1, { type: "bet_cp", amount: 1 });
    expect(los.statusCode, los.body).toBe(200);
    expect(los.json().events[0].payload.events.map((e: { type: string }) => e.type)).not.toContain("cp_bet");
    // En de inhaal-route geeft hetzelfde geredigeerde beeld.
    const alles = await app.inject({
      method: "GET", url: `/matches/${matchId}/events?after=0`,
      headers: { authorization: `Bearer ${p1.token}` },
    });
    for (const r of alles.json().events) {
      expect(Object.keys(r.payload)).toEqual(["events"]);
      for (const e of r.payload.events) expect(SERVER_ONLY_EVENTS).not.toContain(e.type);
    }
  }, 300_000);

  it("de redactielijst van Node is die van de worker, en een verschil is een opstartfout", async () => {
    expect((await app.inject({ method: "GET", url: "/versie" })).statusCode).toBe(200);
    expect(app.worker.serverOnlyEvents.sort()).toEqual([...SERVER_ONLY_EVENTS].sort());
    expect(SERVER_ONLY_EVENTS).toContain("cp_bet");
    // Een Node-kant met een andere lijst: de worker start niet, en een tweede
    // verzoek spawnt de engine niet nog eens (de fout is blijvend).
    const scheef = new GodotWorker({ godotPad: GODOT, projectPad: REPO, verwachtServerOnly: ["cycle_admin"] });
    await expect(scheef.vraag({ op: "ping" })).rejects.toThrow(/loopt uit elkaar/);
    const t0 = Date.now();
    await expect(scheef.vraag({ op: "ping" })).rejects.toThrow(/loopt uit elkaar/);
    expect(Date.now() - t0).toBeLessThan(500);
    scheef.stop();
  }, 60_000);

  it("de herhaling van de laatste actie blijft idempotent, ook als de match daardoor af is", async () => {
    const { matchId, p1, p2 } = await verseMatch();
    expect((await postActie(matchId, p1, 0, { type: "choose_doctrine", doctrine: 2 })).statusCode).toBe(200);
    expect((await postActie(matchId, p2, 1, { type: "choose_doctrine", doctrine: 3 })).statusCode).toBe(200);
    const idem = randomUUID();
    const een = await postActie(matchId, p1, 2, { type: "resign" }, idem);
    expect(een.statusCode).toBe(200);
    // Het antwoord ging "verloren"; de client post blind opnieuw.
    const twee = await postActie(matchId, p1, 2, { type: "resign" }, idem);
    expect(twee.statusCode).toBe(200);
    expect(twee.json().herhaald).toBe(true);
    expect(twee.json().events[0].seq).toBe(3);
    // Een ECHT nieuwe actie is wel voorbij.
    const nieuw = await postActie(matchId, p2, 3, { type: "resign" });
    expect(nieuw.statusCode).toBe(409);
    expect(nieuw.json().fout).toBe("De match is afgelopen");
    expect(nieuw.json().events).toEqual([]);
  });

  it("een worker-fout wordt een neutrale 500, zonder paden in het antwoord", async () => {
    const { matchId, p1 } = await verseMatch();
    // Dood de worker en zet hem op een blijvende fout, zoals een kapotte deploy.
    const echte = app.worker;
    const kapot = new GodotWorker({ godotPad: join(REPO, "bestaat-niet", "godot.exe"), projectPad: REPO });
    (app as unknown as { worker: GodotWorker }).worker = kapot;
    try {
      const res = await postActie(matchId, p1, 0, { type: "choose_doctrine", doctrine: 1 });
      expect(res.statusCode).toBe(500);
      expect(res.json().fout).toBe("Interne fout: scheidsrechter of database niet beschikbaar");
      expect(res.body).not.toContain("bestaat-niet");
    } finally {
      (app as unknown as { worker: GodotWorker }).worker = echte;
      kapot.stop();
    }
  }, 20_000);

  it("zonder seat geen events, geen status", async () => {
    const { matchId, p1 } = await verseMatch();
    const vreemdeling = await gast("Meelezer");
    const events = await app.inject({
      method: "GET", url: `/matches/${matchId}/events?after=0`,
      headers: { authorization: `Bearer ${vreemdeling.token}` },
    });
    expect(events.statusCode).toBe(403);
    const status = await app.inject({
      method: "GET", url: `/matches/${matchId}`,
      headers: { authorization: `Bearer ${vreemdeling.token}` },
    });
    expect(status.statusCode).toBe(403);
    const eigen = await app.inject({
      method: "GET", url: `/matches/${matchId}`,
      headers: { authorization: `Bearer ${p1.token}` },
    });
    expect(eigen.statusCode).toBe(200);
    expect(eigen.json().status).toBe("bezig");
    expect(eigen.json().seat).toBe(1);
    expect(eigen.json().seats.map((s: { naam: string }) => s.naam)).toEqual(["EchteVarken", "EchteMuis"]);
    expect(eigen.json().seq).toBe(0);
  });

  it("matchstatus na afloop: winnaar, reden, en geen acties meer", async () => {
    const { matchId, p1, p2 } = await verseMatch();
    expect((await postActie(matchId, p1, 0, { type: "choose_doctrine", doctrine: 1 })).statusCode).toBe(200);
    expect((await postActie(matchId, p2, 1, { type: "choose_doctrine", doctrine: 4 })).statusCode).toBe(200);
    const opgave = await postActie(matchId, p1, 2, { type: "resign" });
    expect(opgave.statusCode).toBe(200);
    const types = opgave.json().events[0].payload.events.map((e: { type: string }) => e.type);
    expect(types).toContain("game_over");
    const status = await app.inject({
      method: "GET", url: `/matches/${matchId}`,
      headers: { authorization: `Bearer ${p2.token}` },
    });
    expect(status.json().status).toBe("klaar");
    expect(status.json().winnaar_seat).toBe(2);
    expect(String(status.json().eind_reden).length).toBeGreaterThan(0);
    const teLaat = await postActie(matchId, p2, 3, { type: "resign" });
    expect(teLaat.statusCode).toBe(409);
    expect(teLaat.json().fout).toBe("De match is afgelopen");
  });

  it("WebSocket: alleen met seat, en de push is even geredigeerd als de rest", async () => {
    const { matchId, p1, p2 } = await verseMatch();
    // Zonder token: dicht met 4401.
    const anoniem = await wsVerbinding(`ws://${basisUrl}/matches/${matchId}/ws`);
    expect(await anoniem.gesloten).toBe(4401);
    // Buitenstaander: 4403.
    const vreemdeling = await gast("Afluisteraar");
    const buiten = await wsVerbinding(`ws://${basisUrl}/matches/${matchId}/ws?token=${vreemdeling.token}`);
    expect(await buiten.gesloten).toBe(4403);
    // Onbekende match: 4404.
    const nergens = await wsVerbinding(`ws://${basisUrl}/matches/${randomUUID()}/ws?token=${p2.token}`);
    expect(await nergens.gesloten).toBe(4404);
    // Speler 2 luistert mee; speler 1 kiest; de push komt geredigeerd binnen.
    const seat2 = await wsVerbinding(`ws://${basisUrl}/matches/${matchId}/ws?token=${p2.token}`);
    expect(seat2.ws.readyState).toBe(WebSocket.OPEN);
    expect((await postActie(matchId, p1, 0, { type: "choose_doctrine", doctrine: 5 })).statusCode).toBe(200);
    const bericht = (await seat2.volgende()) as { match_id: string; events: { seq: number; payload: Record<string, unknown> }[] };
    expect(bericht.match_id).toBe(matchId);
    expect(bericht.events).toHaveLength(1);
    expect(bericht.events[0]!.seq).toBe(1);
    expect(Object.keys(bericht.events[0]!.payload)).toEqual(["events"]);
    expect(JSON.stringify(bericht)).not.toContain("doctrine\":");
    seat2.ws.close();
    await seat2.gesloten;
  }, 30_000);

  it("een ontbrekende Godot-binary is een nette fout, geen outage", async () => {
    const kapot = new GodotWorker({ godotPad: join(REPO, "bestaat-niet", "godot.exe"), projectPad: REPO });
    await expect(kapot.vraag({ op: "ping" })).rejects.toThrow(/niet te starten/);
    kapot.stop();
  }, 20_000);
});

describe("volledige partij door de server = byte-identiek aan lokaal (F4.2-CHECK)", () => {
  let opname: Opname;

  beforeAll(async () => {
    opname = await opnameLaden();
  }, 300_000);

  it("speelt de opgenomen partij na met dezelfde eind-zobrist", async () => {
    const doctrines = opname.meta.initial_state.doctrines;
    const { matchId, p1, p2 } = await verseMatch(opname.meta.initial_state.rules);
    const spelers: Record<number, Speler> = { 1: p1, 2: p2 };
    // De blinde factie-keuzes eerst (online begint in PRE_GAME, F4.0).
    expect((await postActie(matchId, p1, 0, { type: "choose_doctrine", doctrine: doctrines["1"] })).statusCode).toBe(200);
    expect((await postActie(matchId, p2, 1, { type: "choose_doctrine", doctrine: doctrines["2"] })).statusCode).toBe(200);
    // Daarna elke opgenomen actie, in volgorde, door de echte scheidsrechter.
    for (const entry of opname.entries) {
      const res = await postActie(matchId, spelers[entry.player_id]!, 2 + entry.seq, entry.action);
      expect(res.statusCode, `entry ${entry.seq} (${String(entry.action.type)})`).toBe(200);
      // F4.2b: geen client-rij draagt ooit een hash.
      expect(res.json().events[0].payload.hash).toBeUndefined();
    }
    // Dezelfde engine, dezelfde acties, dezelfde staat: byte-identiek. De
    // hash woont in het server-only log, dus daar lezen we hem.
    const laatsteHash = String((await rauweRij(matchId)).payload.hash);
    expect(laatsteHash).toBe(opname.final_hash);
    // En de match-administratie zag het einde ook.
    const [rij] = (await app.inject({
      method: "GET", url: `/matches/${matchId}/events?after=${opname.entries.length + 1}`,
      headers: { authorization: `Bearer ${p1.token}` },
    }).then((r) => [r.json().events.at(-1)]));
    expect(rij.payload.events.map((e: { type: string }) => e.type)).toContain("game_over");
  }, 600_000);
});
