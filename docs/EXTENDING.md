# Build your own ASP and Rust application

Start with the tested `taskboard` crate as the example domain. It does not depend on Windows, COM, or IIS. The `asp-com` crate turns its results into Automation objects. The ASP files own the HTTP and presentation concerns.

## Automation contract

ProgID: `RustyAsp.TaskBoard`
CLSID: `{2D825ABD-3CE3-4694-9EF5-9E46AD821EB0}`
Server: x64 in-process DLL, Apartment threading model.

| Object | Member | Arguments | Result |
| --- | --- | --- | --- |
| Board | `Version` | property | BSTR version string |
| Board | `NewToken()` | none | Random UUIDv4 string |
| Board | `List(filter)` | `all`, `open`, or `done` | Task collection snapshot |
| Board | `Add(title)` | 1–200 characters after trimming | Integer task ID |
| Board | `Rename(id,title)` | positive integer ID, valid title | True or Automation error |
| Board | `SetDone(id,done)` | positive integer ID, Boolean | True or Automation error |
| Board | `Delete(id)` | positive integer ID | True or Automation error |
| Collection | `Count` | property | Integer size |
| Collection | `Item(index)` | zero-based integer | Task data object |
| Task | `Id`, `Title`, `Done`, `CreatedAt` | read-only properties | Integer, BSTR, Boolean, UTC ISO string |

Collections are snapshots. Query again after a mutation. No type library, named arguments, property setters, or `For Each` enumerator is provided. ASP loops over `Count` and `Item`. Member names are case-insensitive. The adapter validates dispatch flags and argument counts and normalizes COM's reversed positional arguments. Windows VariantCopyInd and VariantChangeType handle VBScript's by-reference values and Automation scalar conversions.

```asp
<%
Set board = Server.CreateObject("RustyAsp.TaskBoard")
Set tasks = board.List("open")
For i = 0 To tasks.Count - 1
    Set task = tasks.Item(i)
%>
  <h3><%= Server.HTMLEncode(task.Title) %></h3>
<% Next %>
```

## Replace the domain

1. Define application behavior and tests in a Rust library separate from the COM adapter.
2. Add your object kind to the adapter's `Value` enum, its member-name mapping, and its checked `call` dispatch. Keep existing dispatch IDs stable when preserving compatibility.
3. Return `IDispatch` wrapped in a VARIANT for nested objects, BSTR for strings, and Automation-compatible scalars for data. Maintain ownership through windows-rs; do not return pointers to temporary Rust strings.
4. Add the ASP template. Encode untrusted content at output and preserve POST/session-token checks for mutations.
5. Replace the CLSID, ProgID, documentation, and constants in `scripts/RustyAsp.psm1` for a separately installed app.
6. Run Rust checks and the actual ASP HTTP suite; native unit tests alone cannot prove script-host compatibility.

The sample opens a SQLite connection per domain operation, avoiding shared mutable connection state across COM apartments. It uses parameterized statements and database transactions for each single-statement mutation. Multi-step business operations should use an explicit transaction inside the domain crate.

`DllGetClassObject` provides the class factory. `DllCanUnloadNow` deliberately returns S_FALSE so the host keeps the module loaded until exit; stop IIS Express before deploying another binary. Rust panics in the adapter are caught at its implemented entry points where possible; allocator failure and process-level native faults can still terminate a host. The small set of unsafe operations is concentrated around the COM ABI and VARIANT access.

This is an application starter demonstrating a working integration, not a complete general-purpose Automation framework or production deployment system. Add authentication, authorization, pagination, schema migrations, operational backups, structured diagnostics, and full IIS deployment automation as the intended application requires them.
