export type DatabaseRow = Record<string, unknown>;

export type DatabaseClient = {
  exec(sql: string): Promise<void>;
  queryAll<T extends DatabaseRow>(
    sql: string,
    params?: unknown[],
  ): Promise<T[]>;
  queryFirst<T extends DatabaseRow>(
    sql: string,
    params?: unknown[],
  ): Promise<T | null>;
  run(sql: string, params?: unknown[]): Promise<void>;
};

export type D1PreparedStatementLike = {
  bind(...values: unknown[]): D1PreparedStatementLike;
  all<T>(): Promise<{ results?: T[] }>;
  first<T>(): Promise<T | null>;
  run(): Promise<unknown>;
};

export type D1DatabaseLike = {
  exec(sql: string): Promise<unknown>;
  prepare(sql: string): D1PreparedStatementLike;
};

export class D1DatabaseClient implements DatabaseClient {
  constructor(private readonly database: D1DatabaseLike) {}

  async exec(sql: string): Promise<void> {
    await this.database.exec(sql);
  }

  async queryAll<T extends DatabaseRow>(
    sql: string,
    params: unknown[] = [],
  ): Promise<T[]> {
    const result = await this.database
      .prepare(sql)
      .bind(...params)
      .all<T>();
    return result.results ?? [];
  }

  async queryFirst<T extends DatabaseRow>(
    sql: string,
    params: unknown[] = [],
  ): Promise<T | null> {
    return this.database
      .prepare(sql)
      .bind(...params)
      .first<T>();
  }

  async run(sql: string, params: unknown[] = []): Promise<void> {
    await this.database
      .prepare(sql)
      .bind(...params)
      .run();
  }
}
