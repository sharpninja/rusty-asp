<%@ Language=VBScript CodePage=65001 %>
<% Option Explicit
Response.Charset="utf-8"
Dim board
Set board=Server.CreateObject("RustyAsp.TaskBoard")
%><!doctype html><html lang="en"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1"><title>How it works | Rusty ASP</title><link rel="stylesheet" href="style.css"></head><body><div class="page"><header class="topbar"><a class="brand" href="default.asp"><span class="brand-mark">R/</span> RUSTY ASP</a><a href="default.asp">Back to the board &#8594;</a></header><main class="explanation"><p class="eyebrow">UNDER THE HOOD</p><h1>Yes, that ASP.</h1><p class="lede">The template is VBScript. The objects are Rust.<br>The bridge between them is COM Automation.</p><div class="flow"><span>Browser</span><b>&#8594;</b><span>IIS / ASP</span><b>&#8594;</b><span>Rust COM</span><b>&#8594;</b><span>SQLite</span></div><h2>The promise from 2021, fulfilled.</h2><p>The ASP page creates a Rust object, asks it for tasks, and reads each task's properties directly. The Rust DLL uses Microsoft's windows-rs bindings to implement IDispatch and IClassFactory. SQLite lives in the Rust domain crate, outside the web root.</p><pre><code>&lt;%
Set board = Server.CreateObject("RustyAsp.TaskBoard")
Set tasks = board.List("all")
For i = 0 To tasks.Count - 1
    Set task = tasks.Item(i)
%&gt;
  &lt;h3&gt;&lt;%= Server.HTMLEncode(task.Title) %&gt;&lt;/h3&gt;
&lt;% Next %&gt;</code></pre><h2>A starter you can take apart.</h2><p>Replace the taskboard Rust crate with your own application logic. Adapt the Automation members in asp-com, then write an ASP template. The supplied scripts build the DLL, register it for your Windows user, and run a dedicated IIS Express site on localhost.</p><h2>What this demonstrates.</h2><p>Server-rendered HTML, native Rust objects, session-bound form tokens, and persistent task storage work together without any browser JavaScript. This is a local single-board demo; it has no user accounts. Public hosting requires a separate IIS deployment with authentication, TLS, and service-account configuration.</p><p>Microsoft provides IIS, Classic ASP, and windows-rs. This community project demonstrates their interoperability; it is not an officially endorsed Rust web framework. No comparative performance benchmark has been run.</p><p class="saved">Live component: <%= Server.HTMLEncode(board.Version) %></p></main><footer class="footer">A SMALL EXPERIMENT BY THE SHARP NINJA</footer></div></body></html>
