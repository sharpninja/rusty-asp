# Validation on Windows

Completed October 5, 2026 on Windows x64. The live app uses IIS Express x64, Windows PowerShell 5.1, Rust 1.99.0, Cargo 1.99.0, windows/windows-core 0.62.2, and rusqlite 0.37.0 with bundled SQLite. Cargo.lock records all resolved dependency versions.

- `cargo fmt --all --check`: formatting check passed.
- `cargo clippy --locked --workspace --all-targets -- -D warnings`: passed.
- Rust tests: 6 passed (4 domain/persistence tests, 2 COM Automation/class-factory tests).
- Release build: passed, with explicit PRIVATE exports for the two COM DLL entry points.
- HTTP suite: 20 checks passed against an actual IIS Express process, using a separate test database.
- Browser: opened the running page in the user's browser and inspected its rendered layout and accessibility tree. Three sample tasks were visible, with two open and one complete. Saved screenshot: `../screenshot.jpg`.

The HTTP checks covered page execution, Rust-generated session tokens, distinct sessions, invalid/forged submissions, title validation, no mutation on an invalid filter, object properties, HTML encoding, Unicode, correctly ordered multi-argument calls, rename, completion, reopen, status filters, malformed IDs, deletion, and persistence after stopping and restarting IIS Express.

Local verification used http://localhost:8087/ with its normal database in `data/tasks.sqlite`. The integration suite used port 8088 and separate generated databases under `.runtime`. Existing IIS sites and web-root contents were not changed. Public source hosting is separate from hosting the ASP application.

Not validated: full IIS service-account deployment, public hosting, multi-user authorization, load/concurrency limits, comparative performance, non-Windows hosts, and CI execution on GitHub. The included GitHub Actions workflow has been authored but has not been run remotely.
