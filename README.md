# Rusty ASP

A running Classic ASP application backed by a native Rust COM component and SQLite. This is a follow-up to [The Sharp Ninja's 2021 article](https://medium.com/the-unpopular-opinions-of-a-senior-developer/microsoft-officially-supports-rust-powered-web-framework-d39271cc55f6): a demo, a useful persistent task board, and a reusable starter in one project.

The request path is **browser → IIS Express → ASP/VBScript → Rust through COM Automation → SQLite**. Rust returns task objects; the ASP template reads their properties and HTML-encodes their values. The browser receives HTML and CSS, with no JavaScript bundle.

## Run on Windows x64

Prerequisites: Rust stable with the `x86_64-pc-windows-msvc` toolchain, Visual Studio C++ build tools and Windows SDK, Microsoft IIS Express x64, and 64-bit Windows PowerShell 5.1. IIS Express must include `asp.dll`; the launcher uses its supplied Classic ASP handler configuration.

From the project folder:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Start.ps1
```

Open **http://localhost:8087/**. The command builds the Rust DLL, writes only this project's COM keys under `HKCU\Software\Classes`, generates a dedicated IIS Express configuration, and launches the local server. The execution-policy option applies only to that PowerShell process. An administrator session is not required for the intended development setup.

After the first build, use `-SkipBuild` to start the existing DLL in `.runtime` directly. Rebuild source when moving to a different machine or changing code. Generated DLLs are excluded from the repository.

Optional sample tasks, added only when the board is empty:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Seed.ps1
```

Manage the server:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Stop.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Start.ps1 -Port 8087 -SkipBuild
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Unregister.ps1
```

Stop before rebuilding: IIS holds the component DLL until its process exits. `Stop.ps1` checks both process identity and start time before touching it. `Unregister.ps1` removes only this checkout's registration and preserves all files and task data. Only one checkout can own the sample's CLSID at a time; use a new GUID and ProgID for a second independent application.

## Use the board

Add a title, edit it, mark a task complete, reopen it, or filter by status. Delete requires expanding the row's Delete control and clicking Confirm delete. Task data persists in `data/tasks.sqlite`, outside the served `site` directory. Override the path with `Start.ps1 -DatabasePath C:\absolute\path\tasks.sqlite`; the launcher creates its parent directory. The database path becomes `RUSTY_ASP_DATABASE` only in the server process environment.

This is a local, single-board application with no user accounts. The supplied launcher uses localhost. Full IIS hosting under a service account requires matching x64 registration visible to that account, a writable database directory, Classic ASP configuration, authentication, TLS, and deployment-specific permissions. Do not assume the per-user IIS Express registration is a full IIS deployment procedure.

## Source layout

| Path | Responsibility |
| --- | --- |
| `crates/taskboard` | Validation, task operations, parameterized SQLite queries, persistence tests |
| `crates/asp-com` | Class factory, `IDispatch`, argument conversion, Rust object properties |
| `site/default.asp` | Requests, sessions, CSRF checks, forms, server-rendered HTML |
| `site/about.asp` | A live explanation of the architecture |
| `scripts` | Build, registration, start/stop, sample data, real HTTP verification |
| `docs/EXTENDING.md` | COM contract and how to replace the example domain |
| `docs/FOLLOW-UP.md` | Article draft grounded in the working implementation |
| `docs/ORIGINAL-SNIPPETS.md` | Original gist IDs and archive/local recovery findings |

## Verify

Stop the project server first, then run:

```powershell
cargo fmt --all --check
cargo clippy --locked --workspace --all-targets -- -D warnings
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Build.ps1 -Test
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Verify.ps1
```

The HTTP suite starts IIS Express on port 8088 with a separate generated database, exercises form submissions and object properties, restarts IIS to check durability, and stops its server on exit. Test databases are retained under `.runtime` for inspection. It does not modify the normal task database. The Windows GitHub Actions workflow builds and tests Rust; the IIS Express integration suite is a separate local check.

SQLite uses WAL and a five-second busy timeout. ASP encodes task content, accepts writes only through POST, checks a random token tied to the ASP session, and rejects malformed task IDs. Rust validates titles independently of browser limits. The sample limits titles to 200 Unicode scalar values; a browser may count non-BMP characters differently in its input `maxlength` rule.

Runtime diagnostics are in `.runtime/stdout.log`, `.runtime/stderr.log`, and `.runtime/logs`. `/health.asp` verifies COM activation and reports the component version. If a port is occupied, stop this project's process if present or choose another port. The launcher does not change existing IIS sites or remove `inetpub` content.

## What the result establishes

Microsoft's Classic ASP can consume COM Automation objects, and Microsoft's windows-rs bindings can implement those objects in Rust. This application demonstrates the combination running on Windows. It does not establish Microsoft endorsement of this community starter or a performance advantage over another web stack. No comparative performance benchmark has been run.

References: [COM objects in ASP](https://learn.microsoft.com/en-us/windows/win32/com/using-com-objects-in-active-server-pages), [windows-rs](https://github.com/microsoft/windows-rs), [Classic ASP configuration](https://learn.microsoft.com/en-us/iis/configuration/system.webServer/asp/).
