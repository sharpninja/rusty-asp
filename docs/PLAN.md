# Rusty ASP, version 0.1

Build a running follow-up to Payton Byrd's March 25, 2021 article using Classic ASP, a Rust COM DLL, and Microsoft's windows-rs bindings.

Acceptance criteria:

- IIS Express serves a real .asp page which creates the Rust component with Server.CreateObject.
- A Rust data object exposes properties to the VBScript HTML template.
- The example app adds, edits, completes, reopens, filters, and deletes tasks in SQLite. Records survive a server restart.
- ASP handles requests, sessions, form tokens, and HTML encoding. Rust owns validation, business logic, and parameterized SQL.
- The COM adapter and domain crate are separate so another app can replace the example domain.
- Setup, build, start, stop, registration, and removal scripts work on Windows x64. Local development uses a dedicated IIS Express configuration and per-user COM registration.
- Tests cover persistence, invalid input, Automation dispatch, and the actual HTTP form flow. Supply a follow-up draft that distinguishes demonstrated behavior from unmeasured performance claims.

Implementation sequence: prove COM activation; implement and test persistence; integrate templates; run HTTP and browser verification; package source, scripts, and article material.

COM surface: RustyAsp.TaskBoard provides Version, NewToken(), List(filter), Add(title), Rename(id,title), SetDone(id,done), Delete(id). List returns a snapshot with Count and Item(zeroBasedIndex); each item exposes Id, Title, Done, and CreatedAt. Named arguments and property setters are not supported. Mutations happen on POST with a session-bound token. This is a local, single-board demo, with no user accounts.
