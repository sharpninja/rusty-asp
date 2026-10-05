# Validation on Windows

Baseline validation completed October 5, 2026 on Windows x64, before the PowerShell module refactor and Bootstrap redesign. The live app uses IIS Express x64, Windows PowerShell 5.1, Rust 1.99.0, Cargo 1.99.0, windows/windows-core 0.62.2, and rusqlite 0.37.0 with bundled SQLite. Cargo.lock records all resolved dependency versions.

- `cargo fmt --all --check`: formatting check passed.
- `cargo clippy --locked --workspace --all-targets -- -D warnings`: passed.
- Rust tests: 6 passed (4 domain/persistence tests, 2 COM Automation/class-factory tests).
- Release build: passed, with explicit PRIVATE exports for the two COM DLL entry points.
- HTTP suite: 20 checks passed against an actual IIS Express process, using a separate test database.
- Browser: opened the running page in the user's browser and inspected its rendered layout and accessibility tree. Three sample tasks were visible, with two open and one complete. Saved screenshot: `../screenshot.jpg`.

The HTTP checks covered page execution, Rust-generated session tokens, distinct sessions, invalid/forged submissions, title validation, no mutation on an invalid filter, object properties, HTML encoding, Unicode, correctly ordered multi-argument calls, rename, completion, reopen, status filters, malformed IDs, deletion, and persistence after stopping and restarting IIS Express.

Local verification used http://localhost:8087/ with its normal database in `data/tasks.sqlite`. The integration suite used port 8088 and separate generated databases under `.runtime`. Existing IIS sites and web-root contents were not changed. Public source hosting is separate from hosting the ASP application.

Not validated: full IIS service-account deployment, public hosting, multi-user authorization, load/concurrency limits, comparative performance, and non-Windows hosts. Build and verification use the local Windows scripts documented in README.md.

## Module and Bootstrap update

Browser verification against the running IIS Express app on October 5, 2026 passed task creation, rename, completion, reopening, done filtering, and confirmed deletion. A temporary task containing literal `<safe>` and `&` characters rendered as text. The temporary task was removed; the original three sample tasks remained unchanged. The completion ring reflected the changing counts. The architecture page rendered and exposed all three replacement gist links.

The workbench was inspected at the normal desktop viewport and at 390 by 844 pixels. At the phone size, the document width was 390 pixels with no horizontal overflow. Temporary device emulation was cleared afterward. Broader responsive testing has not been completed.

The module update was subsequently verified on Windows PowerShell 5.1 x64 on October 5, 2026:

- All ten PowerShell source/manifest files parsed without errors.
- `Test-ModuleManifest` accepted version 0.2.0, and importing it exposed exactly eight commands while preserving caller error preferences, server state, and COM registration.
- Formatting and Clippy with warnings denied passed. `Invoke-RustyAspBuild -Test` passed all six Rust tests and produced the release DLL.
- `Test-RustyAsp` passed all twenty HTTP checks against the redesigned templates and left its test server stopped.
- COM unregister/register completed successfully. The `Register.ps1`, `Start.ps1`, `Seed.ps1`, and `Stop.ps1` compatibility entry points were exercised.
- Seeding an isolated empty database created three tasks; a second call preserved the count. Server startup restored the caller's database environment variable, and status correctly reported stopped/running states.
- The normal server was restored on port 8087 with its original database after testing. Generated test databases remain under the ignored `.runtime` directory.

PowerShell 7 and full IIS service-account hosting were not tested. A separate independent Grok review was unavailable; these results record executed checks, not an independent-review verdict.
