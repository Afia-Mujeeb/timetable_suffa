import { readFile } from "node:fs/promises";
import { basename, resolve } from "node:path";
import { fileURLToPath } from "node:url";

const DEFAULT_BASE_URL =
  process.env.TIMETABLE_ADMIN_URL ?? "http://127.0.0.1:8788";
const DEFAULT_SECRET =
  process.env.TIMETABLE_ADMIN_SECRET ?? process.env.IMPORT_SHARED_SECRET ?? "";
const DEFAULT_OPERATOR_ID = process.env.TIMETABLE_ADMIN_OPERATOR_ID ?? "";
const DEFAULT_FIXTURE_PATH = fileURLToPath(
  new URL(
    "../../../tools/pdf_parser/fixtures/golden/spring-2026-2026-04-26.json",
    import.meta.url,
  ),
);

const HELP_TEXT = `Usage:
  node ./scripts/import-fixture.mjs <command> [options]

Commands:
  import [--file <path> | --stdin] [--raw] [--source-id <id>] [--parser-version <version>] [--triggered-by <id>] [--note <text>]
  versions
  preview <versionId>
  publish <versionId> [--triggered-by <id>] [--note <text>] [--ignore-warnings]
  rollback <versionId> [--triggered-by <id>] [--note <text>] [--ignore-warnings]
  import-runs
  audit-events

Global options:
  --base-url <url>      Base admin URL. Default: TIMETABLE_ADMIN_URL or http://127.0.0.1:8788
  --secret <value>      x-import-secret header. Default: TIMETABLE_ADMIN_SECRET or IMPORT_SHARED_SECRET
  --operator-id <id>    x-operator-id header. Default: TIMETABLE_ADMIN_OPERATOR_ID
  --request-id <id>     x-request-id and x-correlation-id headers
  --output <pretty|json>  Response rendering mode. Default: pretty
  --help

Examples:
  node ./scripts/import-fixture.mjs import --file tools/pdf_parser/fixtures/golden/spring-2026-2026-04-26.json --source-id spring-2026 --parser-version parser@abc123
  node ./scripts/import-fixture.mjs preview version_123 --secret local-dev-secret
  node ./scripts/import-fixture.mjs publish version_123 --operator-id ci/admin --note "Promote reviewed draft"
`;

function fail(message) {
  throw new Error(message);
}

function parseArgv(argv) {
  const booleanFlags = new Set(["help", "raw", "stdin", "ignore-warnings"]);
  const stringFlags = new Set([
    "base-url",
    "file",
    "note",
    "operator-id",
    "output",
    "parser-version",
    "request-id",
    "secret",
    "source-id",
    "triggered-by",
    "version-id",
  ]);
  const flags = {};
  const positionals = [];

  for (let index = 0; index < argv.length; index += 1) {
    const token = argv[index];
    if (!token.startsWith("--")) {
      positionals.push(token);
      continue;
    }

    const stripped = token.slice(2);
    const separatorIndex = stripped.indexOf("=");
    const rawName =
      separatorIndex === -1 ? stripped : stripped.slice(0, separatorIndex);
    const inlineValue =
      separatorIndex === -1 ? undefined : stripped.slice(separatorIndex + 1);

    if (booleanFlags.has(rawName)) {
      flags[rawName] = true;
      continue;
    }

    if (!stringFlags.has(rawName)) {
      fail(`Unknown option: --${rawName}`);
    }

    const value =
      inlineValue !== undefined
        ? inlineValue
        : argv[index + 1] && !argv[index + 1].startsWith("--")
          ? argv[index + 1]
          : null;

    if (value === null) {
      fail(`Option --${rawName} requires a value.`);
    }

    flags[rawName] = value;
    if (inlineValue === undefined) {
      index += 1;
    }
  }

  return {
    command: positionals[0] ?? null,
    positionals: positionals.slice(1),
    flags,
  };
}

function getOutputMode(flags) {
  const output = flags["output"] ?? "pretty";
  if (output !== "pretty" && output !== "json") {
    fail(`Unsupported output mode: ${output}`);
  }

  return output;
}

function requireVersionId(parsed) {
  return parsed.flags["version-id"] ?? parsed.positionals[0] ?? fail(
    "A versionId is required. Pass it positionally or with --version-id.",
  );
}

function buildBaseOptions(flags) {
  return {
    baseUrl: flags["base-url"] ?? DEFAULT_BASE_URL,
    secret: flags["secret"] ?? DEFAULT_SECRET,
    operatorId: flags["operator-id"] ?? DEFAULT_OPERATOR_ID,
    requestId: flags["request-id"] ?? "",
    output: getOutputMode(flags),
  };
}

function buildHeaders(baseOptions) {
  const headers = {
    accept: "application/json",
  };

  if (baseOptions.secret) {
    headers["x-import-secret"] = baseOptions.secret;
  }

  if (baseOptions.operatorId) {
    headers["x-operator-id"] = baseOptions.operatorId;
  }

  if (baseOptions.requestId) {
    headers["x-request-id"] = baseOptions.requestId;
    headers["x-correlation-id"] = baseOptions.requestId;
  }

  return headers;
}

function printPayload(payload, output) {
  const serialized =
    output === "json"
      ? JSON.stringify(payload)
      : JSON.stringify(payload, null, 2);
  console.log(serialized);
}

async function parseJsonText(text, sourceLabel) {
  try {
    return JSON.parse(text);
  } catch (error) {
    fail(
      `${sourceLabel} did not contain valid JSON: ${
        error instanceof Error ? error.message : String(error)
      }`,
    );
  }
}

async function readStdinText() {
  const chunks = [];
  for await (const chunk of process.stdin) {
    chunks.push(Buffer.from(chunk));
  }
  return Buffer.concat(chunks).toString("utf8");
}

async function readArtifactInput(flags) {
  if (flags["stdin"] && flags["file"]) {
    fail("Use either --file or --stdin, not both.");
  }

  if (flags["stdin"]) {
    const text = await readStdinText();
    if (!text.trim()) {
      fail("stdin was empty.");
    }
    return { text, sourceLabel: "stdin", defaultSourceId: "stdin" };
  }

  const filePath = resolve(
    process.cwd(),
    flags["file"] ?? DEFAULT_FIXTURE_PATH,
  );
  return {
    text: await readFile(filePath, "utf8"),
    sourceLabel: filePath,
    defaultSourceId: basename(filePath),
  };
}

async function executeRequest({ baseOptions, path, method, jsonBody }) {
  const url = new URL(path, ensureTrailingSlash(baseOptions.baseUrl)).toString();
  const headers = buildHeaders(baseOptions);

  let body;
  if (jsonBody !== undefined) {
    headers["content-type"] = "application/json";
    body = typeof jsonBody === "string" ? jsonBody : JSON.stringify(jsonBody);
  }

  const response = await fetch(url, {
    method,
    headers,
    body,
  });

  const rawText = await response.text();
  let payload;

  try {
    payload = rawText ? JSON.parse(rawText) : null;
  } catch {
    payload = { status: response.status, rawBody: rawText };
  }

  printPayload(payload, baseOptions.output);

  if (!response.ok) {
    process.exitCode = 1;
  }
}

function ensureTrailingSlash(url) {
  return url.endsWith("/") ? url : `${url}/`;
}

function buildVersionActionBody(flags) {
  const body = {};

  if (flags["triggered-by"]) {
    body.triggeredBy = flags["triggered-by"];
  }

  if (flags["note"]) {
    body.note = flags["note"];
  }

  if (flags["ignore-warnings"]) {
    body.ignoreWarnings = true;
  }

  return Object.keys(body).length > 0 ? body : undefined;
}

async function runImport(parsed, baseOptions) {
  const input = await readArtifactInput(parsed.flags);
  const isRawImport = parsed.flags["raw"] === true;

  if (isRawImport) {
    await executeRequest({
      baseOptions,
      path: "v1/imports",
      method: "POST",
      jsonBody: input.text,
    });
    return;
  }

  const artifact = await parseJsonText(input.text, input.sourceLabel);
  const payload = {
    artifact,
  };

  if (parsed.flags["source-id"]) {
    payload.sourceId = parsed.flags["source-id"];
  } else if (parsed.flags["stdin"] !== true) {
    payload.sourceId = input.defaultSourceId;
  }

  if (parsed.flags["parser-version"]) {
    payload.parserVersion = parsed.flags["parser-version"];
  }

  if (parsed.flags["triggered-by"]) {
    payload.triggeredBy = parsed.flags["triggered-by"];
  }

  if (parsed.flags["note"]) {
    payload.note = parsed.flags["note"];
  }

  await executeRequest({
    baseOptions,
    path: "v1/imports",
    method: "POST",
    jsonBody: payload,
  });
}

async function runCommand(parsed) {
  if (parsed.flags["help"] || !parsed.command) {
    console.log(HELP_TEXT);
    return;
  }

  const baseOptions = buildBaseOptions(parsed.flags);

  switch (parsed.command) {
    case "import":
      await runImport(parsed, baseOptions);
      return;
    case "versions":
      await executeRequest({
        baseOptions,
        path: "v1/versions",
        method: "GET",
      });
      return;
    case "preview":
      await executeRequest({
        baseOptions,
        path: `v1/versions/${encodeURIComponent(requireVersionId(parsed))}/preview`,
        method: "GET",
      });
      return;
    case "publish":
      await executeRequest({
        baseOptions,
        path: `v1/versions/${encodeURIComponent(requireVersionId(parsed))}/publish`,
        method: "POST",
        jsonBody: buildVersionActionBody(parsed.flags),
      });
      return;
    case "rollback":
      await executeRequest({
        baseOptions,
        path: `v1/versions/${encodeURIComponent(requireVersionId(parsed))}/rollback`,
        method: "POST",
        jsonBody: buildVersionActionBody(parsed.flags),
      });
      return;
    case "import-runs":
      await executeRequest({
        baseOptions,
        path: "v1/import-runs",
        method: "GET",
      });
      return;
    case "audit-events":
      await executeRequest({
        baseOptions,
        path: "v1/audit-events",
        method: "GET",
      });
      return;
    default:
      fail(`Unknown command: ${parsed.command}`);
  }
}

export async function main(argv = process.argv.slice(2)) {
  try {
    await runCommand(parseArgv(argv));
  } catch (error) {
    console.error(
      error instanceof Error ? error.message : `Unexpected error: ${String(error)}`,
    );
    process.exitCode = 1;
  }
}

await main();
