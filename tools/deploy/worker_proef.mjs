// F4.4a — praat rechtstreeks met een draaiende Godot-worker
// (tools/server_worker.tscn) over NDJSON/TCP en drukt één JSON-regel af:
//   {ok, core_hash, init_hash, server_only_events, fout}
// Gebruik: node worker_proef.mjs <poort> <regels.json>
// Exit 0 als handshake, ping, core_hash en init allemaal ok zijn.
//
// De worker neemt precies EEN verbinding aan en stopt zodra die dichtgaat
// (hij is een kindproces van Node). Dus nooit "peilen" met een losse
// verbinding: dat is de ene verbinding, en de worker stopt daarna. Zelf
// herhalen tot de poort open is, dan het hele gesprek op die verbinding.
import net from "node:net";
import { readFileSync } from "node:fs";

const poort = Number(process.argv[2] ?? 0);
const regelsPad = process.argv[3] ?? "";
if (!poort || !regelsPad) {
  console.error("gebruik: node worker_proef.mjs <poort> <regels.json>");
  process.exit(2);
}
const regels = JSON.parse(readFileSync(regelsPad, "utf8"));

setTimeout(() => {
  console.log(JSON.stringify({ ok: false, fout: "timeout (150 s)" }));
  process.exit(1);
}, 150_000).unref();

async function verbind() {
  for (let i = 0; i < 240; i++) {
    try {
      return await new Promise((res, rej) => {
        const c = net.connect(poort, "127.0.0.1");
        c.once("connect", () => res(c));
        c.once("error", rej);
      });
    } catch {
      await new Promise((r) => setTimeout(r, 500));
    }
  }
  throw new Error(`poort ${poort} blijft dicht`);
}

try {
  const sock = await verbind();
  let buf = "";
  const wachtend = [];
  sock.on("data", (d) => {
    buf += d.toString();
    let i;
    while ((i = buf.indexOf("\n")) >= 0) {
      const regel = buf.slice(0, i);
      buf = buf.slice(i + 1);
      const w = wachtend.shift();
      if (w) w(JSON.parse(regel));
    }
  });
  sock.on("error", (e) => {
    console.log(JSON.stringify({ ok: false, fout: `verbinding: ${e.message}` }));
    process.exit(1);
  });
  const volgende = () => new Promise((res) => wachtend.push(res));
  const stel = (o) => {
    const p = volgende();
    sock.write(JSON.stringify(o) + "\n");
    return p;
  };
  const handshake = await volgende();
  const ping = await stel({ op: "ping" });
  const hash = await stel({ op: "core_hash" });
  const init = await stel({ op: "init", rules: regels });
  sock.end();
  const uit = {
    ok: Boolean(handshake.ok && handshake.gereed && ping.ok && hash.ok && init.ok),
    core_hash: hash.core_hash ?? null,
    init_hash: init.hash ?? null,
    server_only_events: handshake.server_only_events ?? null,
    fout: init.fout ?? null,
  };
  console.log(JSON.stringify(uit));
  process.exit(uit.ok ? 0 : 1);
} catch (e) {
  console.log(JSON.stringify({ ok: false, fout: String(e?.message ?? e) }));
  process.exit(1);
}
