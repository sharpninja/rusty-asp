# I put Rust in Classic ASP and it works

In March 2021, I wrote “Microsoft Officially Supports Rust Powered Web Framework.” The reveal was Active Server Pages. Yes, that Active Server Pages.

The comments went about as expected.

The article ended with a promise: next time, create a Rust data object and display it in an ASP template. Here is the running project that does it. It also stores tasks in SQLite, because a joke with a database deserves a follow-up.

## The actual application

Rusty ASP is a small task board. You can add a task, rename it, complete it, reopen it, filter the list, and delete it. Stop the server and start it again: the tasks are still there.

IIS Express serves a Classic ASP page. VBScript creates a COM object implemented in Rust. The Rust object reads and writes SQLite, then returns data objects to the page. ASP renders the HTML.

The interesting part of the template looks like this:

```asp
<%
Set board = Server.CreateObject("RustyAsp.TaskBoard")
Set tasks = board.List("all")
For i = 0 To tasks.Count - 1
    Set task = tasks.Item(i)
%>
  <h3><%= Server.HTMLEncode(task.Title) %></h3>
<% Next %>
```

`task.Title` is a property on an object implemented in Rust. It travels through COM Automation, using the same `IDispatch` mechanism that lets VBScript call other COM components. Microsoft's windows-rs project supplies the Windows bindings and the interface implementation macro.

There is no JSON API between ASP and Rust in this example. There is a native DLL in the IIS Express process. The browser gets HTML and CSS; the app ships no browser JavaScript.

## The part that took more than angle brackets

Implementing a COM object for a scripting host means implementing the scripting contract. The DLL exposes a class factory, resolves member names to dispatch IDs, validates arguments, and translates values into Automation types. COM's positional arguments arrive in reverse order, so the adapter puts them back into application order. Rust strings become BSTRs, and nested data objects become IDispatch values.

Those concerns live in a separate adapter crate. The task board's Rust library handles validation and parameterized SQLite statements without knowing about IIS. You can replace that library with another application's behavior and retain the hosting pattern.

The ASP layer handles forms and sessions. Every write uses POST and a random token tied to the session. Task titles are HTML-encoded when rendered. Rust also validates the title, so removing an HTML input's length limit does not bypass the application rule.

## Run it

On Windows x64 with Rust, the Visual Studio C++ build tools, and IIS Express installed, open the project folder and run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Start.ps1
```

Then visit `http://localhost:8087/`. The script builds the DLL, registers this component for your Windows user, and launches a dedicated IIS Express site. SQLite data is stored outside the web root.

The repository includes start, stop, registration-removal, build, and integration-test scripts. The integration suite exercises the real ASP page and restarts IIS Express to verify that the task survives. It also checks that forged form tokens are rejected and stored HTML is encoded.

## What I can claim now

The integration runs. Classic ASP can call Rust through COM, and Rust objects can supply an ASP template with data. The project includes both the working example and the parts needed to start another application using the same approach.

My original post also said “maximum performance” and compared the setup with React and Vue. This project does not establish those performance claims. It demonstrates a server-rendered app with no browser JavaScript bundle. A useful performance comparison would require equivalent applications, workloads, and measurements.

Microsoft provides the underlying technologies. This starter is my project; the combination working is not a statement of Microsoft endorsement of a Rust web framework.

It is a local single-board demo, with no accounts. Publishing it as a multi-user service would require the usual authentication, authorization, TLS, deployment, and operational work. The README describes those boundaries.

The promise at the end of the old article was small: create a Rust object and display it in an ASP template. Now there is a task board doing exactly that, with SQLite behind it.

The angle brackets survived.

---

Draft for author review. Project repository: https://github.com/sharpninja/rusty-asp. Original snippet recovery findings are recorded separately in ORIGINAL-SNIPPETS.md; the implementation above is newly written, not recovered 2021 code.
