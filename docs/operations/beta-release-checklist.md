# Beta Release Checklist

Use this checklist before admitting a new beta cohort or promoting a new timetable version for existing beta users.

## Scope

- Product target: `100` to `300` beta users
- Runtime shape: Cloudflare Worker API, Cloudflare Worker admin, Flutter mobile app, offline PDF parser
- Release owner: named operator responsible for the publish or rollback window

## Environment Readiness

- Confirm the deployed Worker API has a real `TIMETABLE_DB` binding.
- Confirm the deployed admin Worker has a real `TIMETABLE_DB` binding.
- Confirm the admin Worker `IMPORT_SHARED_SECRET` is configured and available to operators.
- Confirm the mobile build uses the intended `API_BASE_URL` for the beta environment.
- Confirm backend logs and `GET /metrics` are reachable for both workers.
- Confirm at least one operator can run the admin CLI with current credentials.

## Parser Readiness

- Parse the current production timetable PDF with the committed parser.
- Run parser validation on the generated artifact and confirm validation status is `passed`.
- Review parser warnings and explicitly decide whether each warning is acceptable for publish.
- Confirm the parser regression suite passes before using a parser change in production.

## Backend Readiness

- Run the backend automated test suite and confirm it passes.
- Verify import, preview, publish, and rollback flows against a non-production environment.
- Verify `GET /v1/versions/current` returns the expected published version after publish.
- Verify at least one section timetable fetch succeeds from the public API after publish.
- Confirm rate-limit responses are intentional and logged for obvious abuse cases.
- Confirm backend metrics show request counts, error counts by type, and rate-limited events.

## Mobile Readiness

- Run `flutter analyze`.
- Run `flutter test`.
- Verify first install on the target Android beta devices.
- Verify first-run section selection succeeds on a clean install.
- Verify offline open succeeds after at least one successful sync.
- Verify refresh failure shows a controlled stale-cache path instead of a crash.
- Verify section switching updates the selected timetable cleanly.
- Verify reminder resync still behaves correctly after a refresh and after a section change.
- Confirm the crash-reporting baseline is capturing unexpected startup and runtime failures.

## Release Execution

- Import the candidate artifact with operator identity and note.
- Review `preview` output, including warnings, change summary, and push preview.
- Publish only after preview review is complete.
- Record the returned `version.versionId` and `auditEvent.auditEventId`.
- Verify the current version from the public API after publish.
- Open the mobile app against the beta backend and confirm the updated data is visible.

## Rollback Readiness

- Identify the previous known-good published version before starting.
- Confirm rollback permissions and operator secret access are available.
- Confirm rollback has been tested on a staging or local environment using the same workflow.
- Keep the rollback note prepared before beginning the release window.

## Post-Release Observation

- Watch Worker metrics for elevated `5xx`, `4xx`, and `429` responses for at least `15` minutes.
- Watch mobile crash reports for startup, section selection, refresh, and reminder failures.
- Confirm at least one beta user or test device completes a normal open and refresh cycle.
- If metrics or crash reports trend upward, pause further invites and decide whether to roll back.
