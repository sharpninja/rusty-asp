<%@ Language=VBScript CodePage=65001 %>
<% Option Explicit
Response.Charset = "utf-8"
Dim board
Set board = Server.CreateObject("RustyAsp.TaskBoard")
%><!doctype html>
<html lang="en" data-bs-theme="dark">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="theme-color" content="#141b1b">
  <meta name="description" content="Classic ASP templates, real Rust objects, and a COM bridge between them. See how Rusty ASP works.">
  <title>Under the hood | Rusty ASP</title>
  <link rel="icon" href="favicon.svg" type="image/svg+xml">
  <link rel="stylesheet" href="vendor/bootstrap.min.css">
  <link rel="stylesheet" href="style.css">
</head>
<body>
<a class="skip-link" href="#main">Skip to content</a>
<aside class="app-rail" aria-label="Workspace">
  <a class="wordmark" href="default.asp" aria-label="Rusty ASP home"><span class="brand-glyph" aria-hidden="true">R<span>/</span></span><span>RUSTY<span class="wordmark-light">ASP</span><small>THE FOLLOW-THROUGH</small></span></a>
  <div class="rail-label">WORKSPACE</div>
  <nav class="rail-nav" aria-label="Main navigation">
    <a href="default.asp"><span aria-hidden="true">&#9638;</span> Workbench <span class="nav-index">01</span></a>
    <a href="about.asp" aria-current="page"><span aria-hidden="true">&#9672;</span> Under the hood <span class="nav-index">02</span></a>
    <a href="https://github.com/sharpninja/rusty-asp"><span aria-hidden="true">&#8599;</span> Source code</a>
  </nav>
  <div class="rail-story"><span class="tiny-label">EST. 2021 / REBUILT 2026</span><p>It started with<br>a hot take.</p><a href="https://medium.com/the-unpopular-opinions-of-a-senior-developer/microsoft-officially-supports-rust-powered-web-framework-d39271cc55f6">Read the origin story <span aria-hidden="true">&#8599;</span></a></div>
  <div class="rail-bottom"><span class="avatar-mark">SN</span><div>The Sharp Ninja<small>Independent experiments</small></div></div>
</aside>
<div class="app-main">
  <header class="workspace-bar"><div><span class="tiny-label">THE EXPERIMENT</span><span class="breadcrumb-name">Under the hood</span></div><span class="live-pill"><span class="status-dot" aria-hidden="true"></span> <%= Server.HTMLEncode(board.Version) %></span></header>
  <main id="main">
    <section class="about-hero">
      <p class="eyebrow"><span class="accent-line" aria-hidden="true"></span> OLD FRIENDS. NEW POSSIBILITIES.</p>
      <h1>Yes, <span>that ASP.</span><br>And actual Rust.</h1>
      <p class="about-intro">The template is VBScript. The objects are Rust. COM Automation connects them. It sounds like a punchline until you click “Add task.”</p>
      <a href="default.asp" class="btn btn-accent mt-2">Try the workbench <span aria-hidden="true">&#8594;</span></a>
    </section>
    <section class="architecture" aria-label="Request path">
      <div class="architecture-step"><span class="step-number">01 / PRESENTATION</span><h2>The browser</h2><p>Semantic HTML5.<br>Bootstrap 5, custom finish.</p></div>
      <div class="architecture-step"><span class="step-number">02 / TEMPLATE</span><h2>IIS + Classic ASP</h2><p>Requests and sessions.<br>Server-rendered views.</p></div>
      <div class="architecture-step"><span class="step-number">03 / APPLICATION</span><h2>Native Rust</h2><p>COM Automation objects.<br>Real application logic.</p></div>
      <div class="architecture-step"><span class="step-number">04 / PERSISTENCE</span><h2>SQLite</h2><p>Parameterized queries.<br>Work that stays saved.</p></div>
    </section>
    <div class="row g-4">
      <div class="col-xl-7"><section class="about-panel"><span class="tiny-label">THE PROMISE, FULFILLED</span><h2>A Rust object.<br>Right in the template.</h2><p>The ASP page creates a Rust component, asks it for tasks, and reads their properties. Microsoft's windows-rs bindings provide the COM interfaces. Rust does the work; ASP writes the HTML.</p><div class="code-window"><header><span class="window-dots" aria-hidden="true">&#9679;&#9679;&#9679;</span><span>default.asp / VBScript</span></header><pre><code>&lt;%
Set board = Server.CreateObject("RustyAsp.TaskBoard")
Set tasks = board.List("all")

For i = 0 To tasks.Count - 1
    Set task = tasks.Item(i)
%&gt;
    &lt;h3&gt;&lt;%= Server.HTMLEncode(task.Title) %&gt;&lt;/h3&gt;
&lt;% Next %&gt;</code></pre></div><div class="flow-note">One request. Native objects. HTML at the other end.</div></section></div>
      <div class="col-xl-5"><section class="about-panel"><span class="tiny-label">SMALL APP. REAL FOUNDATIONS.</span><h2>More than<br>a hello world.</h2><dl class="detail-list"><div><dt>A domain you can replace</dt><dd>The taskboard Rust crate owns validation and SQLite operations. Swap in your application logic.</dd></div><div><dt>A bridge you can extend</dt><dd>The asp-com crate exposes a class factory, IDispatch methods, and task data objects to VBScript.</dd></div><div><dt>A PowerShell module to run it</dt><dd>Import RustyAsp, build the DLL, register it for your Windows user, and start a dedicated IIS Express site.</dd></div><div><dt>A browser that stays simple</dt><dd>Native forms, accessible labels, keyboard navigation, responsive layouts, and zero browser JavaScript.</dd></div></dl></section></div>
    </div>
    <section aria-labelledby="get-started-heading">
      <div class="section-title"><h2 id="get-started-heading">Make it your own.</h2><span class="tiny-label">WINDOWS X64 / LOCAL DEVELOPMENT</span></div>
      <div class="code-window"><header><span class="window-dots" aria-hidden="true">&#9679;&#9679;&#9679;</span><span>Windows PowerShell / project root</span></header><pre><code>Import-Module .\scripts\RustyAsp.psd1
Start-RustyAsp
Initialize-RustyAspData

# Build and test after stopping the server
Stop-RustyAsp
Invoke-RustyAspBuild -Test
Test-RustyAsp</code></pre></div>
      <p class="flow-note">Requires Rust MSVC, Visual Studio C++ build tools, and IIS Express x64. <a href="https://github.com/sharpninja/rusty-asp#run-on-windows-x64">Full setup instructions &#8599;</a></p>
    </section>
    <section aria-labelledby="snippets-heading">
      <div class="section-title"><h2 id="snippets-heading">Back to the beginning.</h2><span class="tiny-label">THE RECONSTRUCTED SNIPPETS</span></div>
      <div class="row g-3">
        <div class="col-md-4"><a class="snippet-card" href="https://gist.github.com/sharpninja/7ca14865c1c9af29e560d46f1ff8b5c1"><span>01</span><div><h3>Set the stage &#8599;</h3><p>Install IIS and Classic ASP.<br>Windows PowerShell.</p></div></a></div>
        <div class="col-md-4"><a class="snippet-card" href="https://gist.github.com/sharpninja/d8ee0b59e53747c15ae9cbb420d0228d"><span>02</span><div><h3>Count it out &#8599;</h3><p>Query strings, loops,<br>and a session ID.</p></div></a></div>
        <div class="col-md-4"><a class="snippet-card" href="https://gist.github.com/sharpninja/e2041f681c44f28280e64295b167fb68"><span>03</span><div><h3>Mix it together &#8599;</h3><p>Code and HTML.<br>The classic ASP template.</p></div></a></div>
      </div>
      <p class="flow-note">The 2021 originals could not be recovered. These public gists reconstruct the behavior described in the article.</p>
    </section>
    <details class="project-notes"><summary>Project scope, hosting, and the original claim</summary><p>This is a local, single-board application with no user accounts. Full IIS hosting needs authentication, TLS, matching x64 COM registration, a writable database directory, and service-account configuration. The per-user IIS Express setup is intended for local development.</p><p>Microsoft provides IIS, Classic ASP, and windows-rs. This community project demonstrates their interoperability. It is not an officially endorsed Rust web framework, and no comparative performance benchmark has been run.</p><p>Task mutations use POST with session-bound form tokens. ASP HTML-encodes task titles, and Rust validates them before parameterized SQLite queries. The database stays outside the served directory.</p></details>
    <section class="origin-strip"><span class="origin-year">THE NEXT CHAPTER</span><p>The best response<br><strong>is something that runs.</strong></p><a href="https://github.com/sharpninja/rusty-asp">Read the code <span aria-hidden="true">&#8599;</span></a></section>
  </main>
  <footer class="workspace-footer"><span>MADE BY THE SHARP NINJA <span aria-hidden="true">&#10022;</span> BUILT TO BE TAKEN APART</span><a href="default.asp">Back to the workbench &#8594;</a></footer>
</div>
</body>
</html>
<% Set board = Nothing %>
