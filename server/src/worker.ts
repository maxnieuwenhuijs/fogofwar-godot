// F4.2 — de brug naar de Godot-worker. Node spawnt de worker als kindproces
// (godot --headless res://tools/server_worker.tscn -- poort=N) en spreekt er
// NDJSON mee over een lokale TCP-verbinding. De worker is stateloos; dit
// bestand bewaakt alleen het PROCES: opstarten, één verzoek tegelijk,
// herstarten na een crash, en één keer opnieuw proberen als hij midden in
// een verzoek sterft (veilig: de database schrijft pas ná het antwoord, dus
// een gestorven verzoek heeft niets veranderd).
//
// GEEN readline voor het lezen: als de worker sterft terwijl er net
// geschreven is, levert readline op Windows een TWEEDE ECONNRESET af die
// langs elke error-luisteraar gaat (proefondervindelijk vastgesteld, 9
// augustus — reset_isolatie.mjs). Een handmatige regelknipper op 'data'
// heeft dat probleem niet.
//
// NB de masterplan-tekst noemde Redis-jobs; dit is bewust een synchrone
// zijspan geworden — zelfde stateloosheid en schaalbaarheid (N workers),
// één bewegend deel minder. Zie docs/protocol.md en MASTERBOUWPLAN F4.2.
import { spawn, type ChildProcess } from "node:child_process";
import net from "node:net";
import { setTimeout as slaap } from "node:timers/promises";

export interface WorkerAntwoord {
  ok: boolean;
  fout?: string;
  illegaal?: boolean;
  [k: string]: unknown;
}

export interface WorkerOpties {
  godotPad: string;
  projectPad: string;
  poort?: number;
  requestTimeoutMs?: number;
}

interface Wachtende {
  resolve: (v: unknown) => void;
  reject: (e: Error) => void;
  timer: NodeJS.Timeout;
}

async function vrijePoort(): Promise<number> {
  return await new Promise((resolve, reject) => {
    const s = net.createServer();
    s.listen(0, "127.0.0.1", () => {
      const adres = s.address();
      if (adres && typeof adres === "object") {
        const poort = adres.port;
        s.close(() => resolve(poort));
      } else {
        s.close(() => reject(new Error("geen poort")));
      }
    });
    s.on("error", reject);
  });
}

export class GodotWorker {
  private proc: ChildProcess | null = null;
  private sock: net.Socket | null = null;
  private buffer = "";
  private wachtende: Wachtende | null = null;
  private wachtrij: Promise<unknown> = Promise.resolve();
  private gereedInfo: { core_hash: string } | null = null;

  constructor(private readonly opties: WorkerOpties) {}

  get coreHash(): string {
    return this.gereedInfo?.core_hash ?? "";
  }

  private get leeft(): boolean {
    return this.proc !== null && this.proc.exitCode === null && this.sock !== null && !this.sock.destroyed;
  }

  async start(): Promise<void> {
    if (this.leeft) return;
    this.stop();
    const poort = this.opties.poort ?? (await vrijePoort());
    const proc = spawn(
      this.opties.godotPad,
      ["--headless", "--path", this.opties.projectPad, "res://tools/server_worker.tscn", "--", `poort=${poort}`],
      { stdio: ["ignore", "ignore", "ignore"], cwd: this.opties.projectPad },
    );
    this.proc = proc;
    // Verbinden met geduld: de engine heeft 1-5 s opstarttijd.
    let sock: net.Socket | null = null;
    let laatste: unknown = null;
    for (let i = 0; i < 120; i++) {
      if (proc.exitCode !== null) throw new Error("worker stierf tijdens het opstarten");
      try {
        sock = await new Promise<net.Socket>((resolve, reject) => {
          const s = net.connect({ port: poort, host: "127.0.0.1" }, () => resolve(s));
          s.on("error", reject);
        });
        break;
      } catch (e) {
        laatste = e;
        await slaap(250);
      }
    }
    if (!sock) throw new Error(`worker niet bereikbaar op poort ${poort}: ${String(laatste)}`);
    sock.setNoDelay(true);
    sock.on("error", () => {});
    sock.on("data", (stuk) => this.opData(stuk));
    sock.on("close", () => this.faalWachtende(new Error("worker-verbinding gesloten")));
    proc.on("exit", () => {
      // Sluit de EIGEN socket van dit proces (closure), nooit die van een
      // opvolger die inmiddels op this.sock kan staan.
      sock.destroy();
      this.faalWachtende(new Error("worker-proces gestopt"));
    });
    this.sock = sock;
    this.buffer = "";
    const gereed = (await this.leesRegel(30_000)) as { gereed?: boolean; core_hash?: string };
    if (!gereed?.gereed) throw new Error("worker meldde zich niet gereed");
    this.gereedInfo = { core_hash: String(gereed.core_hash ?? "") };
  }

  private opData(stuk: Buffer): void {
    this.buffer += stuk.toString("utf8");
    let idx: number;
    while ((idx = this.buffer.indexOf("\n")) >= 0) {
      const regel = this.buffer.slice(0, idx).trim();
      this.buffer = this.buffer.slice(idx + 1);
      if (regel.length === 0 || !this.wachtende) continue;
      const w = this.wachtende;
      this.wachtende = null;
      clearTimeout(w.timer);
      try {
        w.resolve(JSON.parse(regel));
      } catch {
        w.reject(new Error("onleesbaar worker-antwoord"));
      }
    }
  }

  private faalWachtende(e: Error): void {
    if (!this.wachtende) return;
    const w = this.wachtende;
    this.wachtende = null;
    clearTimeout(w.timer);
    w.reject(e);
  }

  private async leesRegel(timeoutMs: number): Promise<unknown> {
    if (!this.sock) throw new Error("geen verbinding");
    return await new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        this.wachtende = null;
        reject(new Error("worker-timeout"));
      }, timeoutMs);
      this.wachtende = { resolve, reject, timer };
    });
  }

  /** Eén verzoek; verzoeken worden geserialiseerd (één tegelijk in de pijp). */
  async vraag(verzoek: Record<string, unknown>): Promise<WorkerAntwoord> {
    const beurt = this.wachtrij.then(async () => {
      // Eén herstart-poging als de worker dood blijkt: het verzoek heeft
      // niets gemuteerd (de database schrijft pas ná een antwoord).
      for (let poging = 0; poging < 2; poging++) {
        try {
          if (!this.leeft) await this.start();
          this.sock!.write(JSON.stringify(verzoek) + "\n");
          return (await this.leesRegel(this.opties.requestTimeoutMs ?? 30_000)) as WorkerAntwoord;
        } catch (e) {
          this.stop();
          if (poging === 1) throw e;
        }
      }
      throw new Error("onbereikbaar");
    });
    this.wachtrij = beurt.catch(() => undefined);
    return await beurt;
  }

  stop(): void {
    this.faalWachtende(new Error("worker gestopt"));
    this.sock?.destroy();
    this.sock = null;
    this.buffer = "";
    if (this.proc && this.proc.exitCode === null) {
      // De worker merkt een dichte socket op Windows niet altijd op: hard
      // beëindigen is hier het contract (hij is stateloos).
      this.proc.kill();
    }
    this.proc = null;
    this.gereedInfo = null;
  }

  /** Voor de kill-test: het kale kindproces. */
  get kindProces(): ChildProcess | null {
    return this.proc;
  }
}
