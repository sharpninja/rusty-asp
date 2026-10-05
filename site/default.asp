<%@ Language=VBScript CodePage=65001 %>
<% Option Explicit
Response.Buffer = True
Response.Charset = "utf-8"
Response.AddHeader "Cache-Control", "no-store"
Dim board, rows, allRows, item, i, total, completed, filter, errorMessage, action, taskId, ignored, editId
Set board = Server.CreateObject("RustyAsp.TaskBoard")
If Len(CStr(Session("csrf"))) = 0 Then Session("csrf") = board.NewToken()
filter = CStr(Request.QueryString("show"))
If filter = "" Then filter = "all"
If filter <> "all" And filter <> "open" And filter <> "done" Then
    Response.Status = "400 Bad Request"
    filter = "all"
    errorMessage = "Choose all, open, or done."
End If
Function H(value)
    H = Server.HTMLEncode(CStr(value))
End Function
Function ValidId(value)
    Dim pattern
    Set pattern = New RegExp
    pattern.Pattern = "^[1-9][0-9]{0,9}$"
    ValidId = False
    If pattern.Test(CStr(value)) Then
        If CDbl(value) <= 2147483647 Then ValidId = True
    End If
End Function
Sub Mutate()
    Dim mutationError
    action = CStr(Request.Form("action"))
    If action <> "add" Then
        If Not ValidId(Request.Form("id")) Then
            errorMessage = "Invalid task ID."
            Exit Sub
        End If
        taskId = CLng(Request.Form("id"))
    End If
    On Error Resume Next
    Select Case action
        Case "add"
            ignored = board.Add(CStr(Request.Form("title")))
        Case "rename"
            ignored = board.Rename(taskId, CStr(Request.Form("title")))
        Case "setdone"
            If Request.Form("done") <> "0" And Request.Form("done") <> "1" Then
                errorMessage = "Invalid task status."
            Else
                ignored = board.SetDone(taskId, (Request.Form("done") = "1"))
            End If
        Case "delete"
            ignored = board.Delete(taskId)
        Case Else
            errorMessage = "Unknown action."
    End Select
    If Err.Number <> 0 Then
        mutationError = Err.Description
        Err.Clear
        errorMessage = mutationError
    End If
    On Error GoTo 0
End Sub
If Request.ServerVariables("REQUEST_METHOD") = "POST" And Len(errorMessage) = 0 Then
    If CStr(Request.Form("csrf")) <> CStr(Session("csrf")) Then
        Response.Status = "403 Forbidden"
        errorMessage = "Your form expired. Reload the page and try again."
    Else
        Call Mutate()
        If Len(errorMessage) = 0 Then
            Response.Status = "303 See Other"
            Response.AddHeader "Location", "default.asp?show=" & filter
            Response.End
        Else
            Response.Status = "400 Bad Request"
        End If
    End If
End If
Set allRows = board.List("all")
Set rows = board.List(filter)
total = allRows.Count
completed = 0
For i = 0 To total - 1
    Set item = allRows.Item(i)
    If item.Done Then completed = completed + 1
Next
editId = 0
If ValidId(Request.QueryString("edit")) Then editId = CLng(Request.QueryString("edit"))
Dim completionPercent
completionPercent = 0
If total > 0 Then completionPercent = Int(CDbl(completed) * 100 / total)
%><!doctype html>
<html lang="en" data-bs-theme="dark">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="theme-color" content="#141b1b">
  <meta name="description" content="A real task board, powered by Classic ASP, native Rust objects, and SQLite. A very modern follow-through.">
  <title>Workbench | Rusty ASP</title>
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
    <a href="default.asp" aria-current="page"><span aria-hidden="true">&#9638;</span> Workbench <span class="nav-index">01</span></a>
    <a href="about.asp"><span aria-hidden="true">&#9672;</span> Under the hood <span class="nav-index">02</span></a>
    <a href="https://github.com/sharpninja/rusty-asp"><span aria-hidden="true">&#8599;</span> Source code</a>
  </nav>
  <div class="rail-story"><span class="tiny-label">EST. 2021 / REBUILT 2026</span><p>It started with<br>a hot take.</p><a href="https://medium.com/the-unpopular-opinions-of-a-senior-developer/microsoft-officially-supports-rust-powered-web-framework-d39271cc55f6">Read the origin story <span aria-hidden="true">&#8599;</span></a></div>
  <div class="rail-bottom"><span class="avatar-mark">SN</span><div>The Sharp Ninja<small>Independent experiments</small></div></div>
</aside>
<div class="app-main">
  <header class="workspace-bar"><div><span class="tiny-label">YOUR WORKSPACE</span><span class="breadcrumb-name">The workbench</span></div><span class="live-pill"><span class="status-dot" aria-hidden="true"></span> Local edition</span></header>
  <main id="main">
    <section class="hero row align-items-center g-4" aria-labelledby="hero-heading">
      <div class="col-md-8">
        <p class="eyebrow"><span class="accent-line" aria-hidden="true"></span> THE FOLLOW-THROUGH / 001</p>
        <h1 id="hero-heading">Old server.<br><span>New tricks.</span></h1>
        <p class="hero-copy">Good ideas deserve a working version.<br>A little Rust. A little history. A place to get things done.</p>
        <div class="stack-tags" aria-label="Technology stack"><span>CLASSIC ASP</span><span>RUST</span><span>SQLITE</span><span>BOOTSTRAP 5</span></div>
      </div>
      <div class="col-md-4 hero-aside">
        <div class="completion-orbit" role="img" aria-label="<%= completionPercent %> percent of tasks complete">
          <svg class="orbit-progress" viewBox="0 0 100 100" aria-hidden="true"><circle class="orbit-track" cx="50" cy="50" r="47"/><circle class="orbit-value" cx="50" cy="50" r="47" pathLength="100" stroke-dasharray="<%= completionPercent %> 100" transform="rotate(-90 50 50)"/></svg>
          <div class="orbit-center"><span class="orbit-label">FOLLOW-THROUGH</span><strong><%= completionPercent %><small>%</small></strong><span>of your board complete</span></div>
        </div>
        <p class="orbit-caption"><span aria-hidden="true">&#10022;</span> One small task at a time.</p>
      </div>
    </section>

    <section class="row g-3 metrics-row" aria-label="Board overview">
      <div class="col-4"><div class="metric-card"><span class="metric-label"><span class="metric-mark" aria-hidden="true">&#9638;</span> Total tasks</span><div><strong><%= total %></strong><small>on the board</small></div></div></div>
      <div class="col-4"><div class="metric-card"><span class="metric-label"><span class="metric-mark copper" aria-hidden="true">&#9707;</span> In progress</span><div><strong><%= total-completed %></strong><small>ideas in motion</small></div></div></div>
      <div class="col-4"><div class="metric-card"><span class="metric-label"><span class="metric-mark mint" aria-hidden="true">&#10003;</span> Completed</span><div><strong><%= completed %></strong><small>made it happen</small></div></div></div>
    </section>

    <div class="row g-4 work-grid">
      <div class="col-xl-8">
        <section class="board-panel" id="taskboard" aria-labelledby="board-heading">
          <div class="panel-heading"><div><p class="tiny-label">MAKE ROOM FOR THE NEXT THING</p><h2 id="board-heading">Your task board<span class="heading-dot">.</span></h2></div><span class="board-count"><%= rows.Count %> showing</span></div>
          <% If Len(errorMessage) > 0 Then %><div class="alert alert-danger error-message" role="alert"><strong>That didn’t go through.</strong> <%= H(errorMessage) %></div><% End If %>
          <form class="add-form" method="post" action="default.asp?show=<%= H(filter) %>#taskboard">
            <input type="hidden" name="csrf" value="<%= H(Session("csrf")) %>">
            <input type="hidden" name="action" value="add">
            <label for="new-title" class="form-label">What needs doing?</label>
            <div class="add-input-row"><input class="form-control" id="new-title" name="title" maxlength="200" required placeholder="Give that idea somewhere to go…" aria-describedby="title-hint"><button class="btn btn-accent" type="submit">Add task <span aria-hidden="true">+</span></button></div>
            <div id="title-hint" class="form-text">A small, clear next step. Up to 200 characters.</div>
          </form>
          <nav class="nav task-filters" aria-label="Filter tasks">
            <a class="nav-link" href="default.asp?show=all#taskboard" <% If filter="all" Then Response.Write "aria-current=""page""" %>>All tasks <span><%= total %></span></a>
            <a class="nav-link" href="default.asp?show=open#taskboard" <% If filter="open" Then Response.Write "aria-current=""page""" %>>Open <span><%= total-completed %></span></a>
            <a class="nav-link" href="default.asp?show=done#taskboard" <% If filter="done" Then Response.Write "aria-current=""page""" %>>Done <span><%= completed %></span></a>
          </nav>
          <div class="tasks">
          <% If rows.Count = 0 Then %>
            <div class="empty-state"><span class="empty-symbol" aria-hidden="true">&#10022;</span><h3>A little room for possibility.</h3><p>No <%= H(filter) %> tasks here yet.<br>Add something above, or try another view.</p><a href="default.asp?show=all#taskboard">View all tasks <span aria-hidden="true">&#8594;</span></a></div>
          <% End If %>
          <% For i = 0 To rows.Count - 1
             Set item = rows.Item(i)
          %>
            <article class="task <% If item.Done Then Response.Write "is-done" %>" data-task-id="<%= item.Id %>">
              <form class="task-toggle" method="post" action="default.asp?show=<%= H(filter) %>#taskboard">
                <input type="hidden" name="csrf" value="<%= H(Session("csrf")) %>"><input type="hidden" name="action" value="setdone"><input type="hidden" name="id" value="<%= item.Id %>"><input type="hidden" name="done" value="<% If item.Done Then Response.Write "0" Else Response.Write "1" %>">
                <button type="submit" class="complete-button" aria-label="<% If item.Done Then Response.Write "Reopen " Else Response.Write "Complete " %><%= H(item.Title) %>"><% If item.Done Then Response.Write "&#10003;" Else Response.Write "<span class=""open-indicator"" aria-hidden=""true""></span>" %></button>
              </form>
              <div class="task-main">
                <% If editId = item.Id Then %>
                  <form class="edit-form" method="post" action="default.asp?show=<%= H(filter) %>#taskboard">
                    <input type="hidden" name="csrf" value="<%= H(Session("csrf")) %>"><input type="hidden" name="action" value="rename"><input type="hidden" name="id" value="<%= item.Id %>">
                    <label for="edit-title" class="form-label">Edit task title</label><input class="form-control" id="edit-title" name="title" value="<%= H(item.Title) %>" maxlength="200" required autofocus><div class="edit-actions"><button class="btn btn-accent btn-sm" type="submit">Save changes</button><a href="default.asp?show=<%= H(filter) %>#taskboard">Cancel</a></div>
                  </form>
                <% Else %>
                  <h3><%= H(item.Title) %></h3>
                  <p class="task-meta"><span class="task-id">TASK / <%= item.Id %></span><span class="task-status"><% If item.Done Then Response.Write "Completed" Else Response.Write "Open" %></span><time datetime="<%= H(item.CreatedAt) %>"><%= H(Left(item.CreatedAt,10)) %></time></p>
                <% End If %>
              </div>
              <div class="task-actions">
                <a href="default.asp?show=<%= H(filter) %>&amp;edit=<%= item.Id %>#taskboard" class="edit-link" aria-label="Edit <%= H(item.Title) %>">Edit</a>
                <details class="delete-control"><summary aria-label="Delete <%= H(item.Title) %>"><span aria-hidden="true">&#215;</span></summary><div class="delete-popover"><p>Remove this task?</p><form method="post" action="default.asp?show=<%= H(filter) %>#taskboard"><input type="hidden" name="csrf" value="<%= H(Session("csrf")) %>"><input type="hidden" name="action" value="delete"><input type="hidden" name="id" value="<%= item.Id %>"><button class="btn btn-outline-danger btn-sm" type="submit">Confirm delete</button></form></div></details>
              </div>
            </article>
          <% Next %>
          </div>
          <div class="board-footer"><span><span class="status-dot" aria-hidden="true"></span> Saved in SQLite</span><span>Ready when you are.</span></div>
        </section>
      </div>
      <aside class="col-xl-4 side-cards" aria-label="About the experiment">
        <section class="spotlight-card"><span class="tiny-label">A VERY REAL EXPERIMENT</span><div class="code-emblem" aria-hidden="true"><span>&lt;%</span><b>R</b><span>%&gt;</span></div><h2>Some things<br>age beautifully.</h2><p>Classic ASP meets native Rust objects. The result? A working app with a few good stories.</p><a class="text-link" href="about.asp">Take a look inside <span aria-hidden="true">&#8599;</span></a></section>
        <section class="notes-card"><div class="note-heading"><span class="tiny-label">BUILT WITH INTENTION</span><span aria-hidden="true">&#10035;</span></div><ul><li><span class="note-number">01</span><div>Yours to make your own<small>A starter with room to grow.</small></div></li><li><span class="note-number">02</span><div>Real, persistent work<small>Tasks stay when the server restarts.</small></div></li><li><span class="note-number">03</span><div>A lighter browser<small>HTML and CSS. No JavaScript bundle.</small></div></li></ul><a href="https://github.com/sharpninja/rusty-asp" class="repo-link">Explore the repository <span aria-hidden="true">&#8599;</span></a></section>
      </aside>
    </div>
    <section class="origin-strip"><span class="origin-year">2021 <span aria-hidden="true">&#8594;</span> 2026</span><p>From “are you kidding?”<br><strong>to “here’s the source.”</strong></p><a href="https://medium.com/the-unpopular-opinions-of-a-senior-developer/microsoft-officially-supports-rust-powered-web-framework-d39271cc55f6">The original provocation <span aria-hidden="true">&#8599;</span></a></section>
  </main>
  <footer class="workspace-footer"><span>MADE BY THE SHARP NINJA <span aria-hidden="true">&#10022;</span> BUILT TO BE TAKEN APART</span><span><%= H(board.Version) %></span></footer>
</div>
</body>
</html>
<% Set item=Nothing: Set rows=Nothing: Set allRows=Nothing: Set board=Nothing %>
