// F4.1 — MySQL-pool + een minimale migratie-runner. Geen ORM: het schema is
// klein, de queries zijn expliciet, en de kritieke paden (idempotentie, seq)
// leunen op database-garanties in plaats van op bibliotheek-gedrag.
import { readdir, readFile } from "node:fs/promises";
import { join, dirname } from "node:path";
import { fileURLToPath } from "node:url";
import mysql from "mysql2/promise";

export type Db = mysql.Pool;

export function maakPool(url: string): Db {
  return mysql.createPool({
    uri: url,
    connectionLimit: 10,
    // JSON-kolommen als objecten; DECIMAL/BIGINT spelen hier geen rol.
    jsonStrings: false,
    multipleStatements: false,
  });
}

/** Draai alle nog niet gedraaide migraties, op bestandsnaam gesorteerd. */
export async function migreer(db: Db): Promise<string[]> {
  await db.query(
    "CREATE TABLE IF NOT EXISTS _migraties (naam VARCHAR(255) NOT NULL PRIMARY KEY, at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP)",
  );
  const map = join(dirname(fileURLToPath(import.meta.url)), "..", "db", "migrations");
  const bestanden = (await readdir(map)).filter((f) => f.endsWith(".sql")).sort();
  const [rows] = await db.query<mysql.RowDataPacket[]>("SELECT naam FROM _migraties");
  const gedaan = new Set(rows.map((r) => r.naam as string));
  const gedraaid: string[] = [];
  for (const bestand of bestanden) {
    if (gedaan.has(bestand)) continue;
    const sql = await readFile(join(map, bestand), "utf8");
    // Eén statement per keer (multipleStatements staat bewust uit).
    // Commentaar per REGEL strippen: een blok dat met commentaar begint
    // draagt daaronder gewoon een statement.
    for (const stuk of sql.split(/;\s*(?:\r?\n|$)/)) {
      const s = stuk
        .split(/\r?\n/)
        .filter((regel) => !regel.trim().startsWith("--"))
        .join("\n")
        .trim();
      if (s.length === 0) continue;
      await db.query(s);
    }
    await db.query("INSERT INTO _migraties (naam) VALUES (?)", [bestand]);
    gedraaid.push(bestand);
  }
  return gedraaid;
}
