import { readFileSync } from "node:fs";
import { createRequire } from "node:module";
import { dirname, resolve } from "node:path";
import { fileURLToPath } from "node:url";

import initSqlJs, { type Database } from "sql.js";

import type { DatabaseClient, DatabaseRow } from "./db";

type SqlValue = number | string | Uint8Array | null;

let sqlJsPromise: Promise<Awaited<ReturnType<typeof initSqlJs>>> | null = null;
const require = createRequire(import.meta.url);
const SQL_WASM_PATH = require.resolve("sql.js/dist/sql-wasm.wasm");

function getSqlJs() {
  sqlJsPromise ??= initSqlJs({
    locateFile: () => SQL_WASM_PATH,
  });
  return sqlJsPromise;
}

function normalizeParams(params: unknown[]): SqlValue[] {
  return params.map((param) => {
    if (
      param === null ||
      typeof param === "number" ||
      typeof param === "string" ||
      param instanceof Uint8Array
    ) {
      return param;
    }

    return String(param);
  });
}

function queryStatement<T extends DatabaseRow>(
  database: Database,
  sql: string,
  params: unknown[],
): T[] {
  const statement = database.prepare(sql);
  statement.bind(normalizeParams(params));

  const rows: T[] = [];
  while (statement.step()) {
    rows.push(statement.getAsObject() as T);
  }

  statement.free();
  return rows;
}

export class SqlJsDatabaseClient implements DatabaseClient {
  constructor(private readonly database: Database) {}

  exec(sql: string): Promise<void> {
    this.database.exec(sql);
    return Promise.resolve();
  }

  queryAll<T extends DatabaseRow>(
    sql: string,
    params: unknown[] = [],
  ): Promise<T[]> {
    return Promise.resolve(queryStatement<T>(this.database, sql, params));
  }

  queryFirst<T extends DatabaseRow>(
    sql: string,
    params: unknown[] = [],
  ): Promise<T | null> {
    return Promise.resolve(
      queryStatement<T>(this.database, sql, params)[0] ?? null,
    );
  }

  run(sql: string, params: unknown[] = []): Promise<void> {
    const statement = this.database.prepare(sql);
    statement.run(normalizeParams(params));
    statement.free();
    return Promise.resolve();
  }
}

const CURRENT_DIRECTORY = dirname(fileURLToPath(import.meta.url));
const MIGRATION_PATH = resolve(
  CURRENT_DIRECTORY,
  "../../migrations/0001_initial.sql",
);

export async function createTestDatabase(): Promise<{
  client: DatabaseClient;
  database: Database;
}> {
  const SQL = await getSqlJs();
  const database = new SQL.Database();
  const client = new SqlJsDatabaseClient(database);
  return { client, database };
}

export async function applySharedMigrations(
  database: DatabaseClient,
): Promise<void> {
  const sql = readFileSync(MIGRATION_PATH, "utf8");
  await database.exec(sql);
}
