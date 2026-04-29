import { readFileSync } from "node:fs";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import { D1DatabaseClient, type D1DatabaseLike } from "./db";
import { TimetableImportService } from "./services";
import { applySharedMigrations, createTestDatabase } from "./testing";
import type { ParserArtifact } from "./types";

const CURRENT_DIRECTORY = dirname(fileURLToPath(import.meta.url));
const FIXTURE_PATH = resolve(
  CURRENT_DIRECTORY,
  "../../../../tools/pdf_parser/fixtures/golden/spring-2026-2026-04-26.json",
);

export function loadGoldenArtifact(): ParserArtifact {
  return JSON.parse(readFileSync(FIXTURE_PATH, "utf8")) as ParserArtifact;
}

export async function createSeededTestDatabase(): Promise<{
  d1: D1DatabaseLike;
  importService: TimetableImportService;
}> {
  const { client, database } = await createTestDatabase();
  await applySharedMigrations(client);
  const importService = new TimetableImportService(client);
  const artifact = loadGoldenArtifact();
  await importService.importArtifact(artifact);
  await importService.publishVersion(artifact.source.version_id);
  const d1 = createD1Bridge(database);
  return {
    d1,
    importService: new TimetableImportService(new D1DatabaseClient(d1)),
  };
}

function normalizeD1Value(value: unknown): number | string | null {
  if (
    value === null ||
    typeof value === "number" ||
    typeof value === "string"
  ) {
    return value;
  }

  return String(value);
}

export function createD1Bridge(
  database: import("sql.js").Database,
): D1DatabaseLike {
  return new SqlJsD1Bridge(database);
}

class SqlJsD1PreparedStatement {
  private readonly values: unknown[];

  constructor(
    private readonly database: import("sql.js").Database,
    private readonly sql: string,
    values?: unknown[],
  ) {
    this.values = values ?? [];
  }

  bind(...values: unknown[]): SqlJsD1PreparedStatement {
    return new SqlJsD1PreparedStatement(this.database, this.sql, values);
  }

  all<T>(): Promise<{ results?: T[] }> {
    const statement = this.database.prepare(this.sql);
    statement.bind(this.values.map(normalizeD1Value));

    const results: T[] = [];
    while (statement.step()) {
      results.push(statement.getAsObject() as T);
    }

    statement.free();
    return Promise.resolve({ results });
  }

  first<T>(): Promise<T | null> {
    return this.all<T>().then((result) => result.results?.[0] ?? null);
  }

  run(): Promise<unknown> {
    const statement = this.database.prepare(this.sql);
    statement.run(this.values.map(normalizeD1Value));
    statement.free();
    return Promise.resolve(undefined);
  }
}

class SqlJsD1Bridge implements D1DatabaseLike {
  constructor(private readonly database: import("sql.js").Database) {}

  exec(sql: string): Promise<unknown> {
    this.database.exec(sql);
    return Promise.resolve(undefined);
  }

  prepare(sql: string): SqlJsD1PreparedStatement {
    return new SqlJsD1PreparedStatement(this.database, sql);
  }
}
