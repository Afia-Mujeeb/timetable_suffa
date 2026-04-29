import { readFile } from "node:fs/promises";
import { resolve } from "node:path";

function parseArgs(argv) {
  const args = {
    file: resolve(
      process.cwd(),
      "../../tools/pdf_parser/fixtures/golden/spring-2026-2026-04-26.json",
    ),
    url: "http://127.0.0.1:8788/v1/imports",
    publish: false,
    secret: process.env.IMPORT_SHARED_SECRET ?? "",
  };

  for (let index = 0; index < argv.length; index += 1) {
    const value = argv[index];
    if (value === "--file") {
      args.file = resolve(process.cwd(), argv[index + 1]);
      index += 1;
    } else if (value === "--url") {
      args.url = argv[index + 1];
      index += 1;
    } else if (value === "--secret") {
      args.secret = argv[index + 1];
      index += 1;
    } else if (value === "--publish") {
      args.publish = true;
    }
  }

  return args;
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const body = await readFile(args.file, "utf8");

  const headers = {
    "content-type": "application/json",
  };

  if (args.secret) {
    headers["x-import-secret"] = args.secret;
  }

  const importResponse = await fetch(args.url, {
    method: "POST",
    headers,
    body,
  });

  const importPayload = await importResponse.json();
  console.log(JSON.stringify(importPayload, null, 2));

  if (!importResponse.ok) {
    process.exitCode = 1;
    return;
  }

  if (!args.publish) {
    return;
  }

  const versionId = importPayload.version?.versionId;
  if (!versionId) {
    throw new Error("Import response did not include version.versionId.");
  }

  const publishUrl = new URL(
    `/v1/versions/${versionId}/publish`,
    args.url,
  ).toString();
  const publishResponse = await fetch(publishUrl, {
    method: "POST",
    headers: args.secret ? { "x-import-secret": args.secret } : undefined,
  });

  const publishPayload = await publishResponse.json();
  console.log(JSON.stringify(publishPayload, null, 2));

  if (!publishResponse.ok) {
    process.exitCode = 1;
  }
}

await main();
