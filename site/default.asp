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
%><!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Rusty ASP | The follow-through</title>
  <link rel="stylesheet" href="style.css">
</head>
<body>
<div class="page">
  <header class="topbar"><a class="brand" href="default.asp"><span class="brand-mark" aria-hidden="true">R/</span> RUSTY ASP</a><a href="about.asp">How it works <span aria-hidden="true">&#8599;</span></a></header>
  <main>
    <div class="intro"><p class="eyebrow">THE FOLLOW-THROUGH / 001</p><h1>Old server.<br><em>New tricks.</em></h1><p class="lede">An actual task board. Classic ASP on the outside.<br>Rust and SQLite doing the work underneath.</p><div class="stack"><span>CLASSIC ASP</span><b>+</b><span>RUST</span><b>+</b><span>SQLITE</span></div></div>
    <section class="board" aria-labelledby="board-heading">
      <div class="board-header"><div><p class="eyebrow">YOUR WORKBENCH</p><h2 id="board-heading">Make something happen.</h2></div><span class="saved"><span aria-hidden="true">&#9679;</span> Saved to SQLite</span></div>
      <div class="stats"><div><strong><%= total %></strong><span>total tasks</span></div><div><strong><%= total - completed %></strong><span>still to do</span></div><div><strong><%= completed %></strong><span>done &amp; dusted</span></div></div>
      <% If Len(errorMessage) > 0 Then %><p class="error" role="alert"><%= H(errorMessage) %></p><% End If %>
      <form class="add-form" method="post" action="default.asp?show=<%= H(filter) %>">
        <input type="hidden" name="csrf" value="<%= H(Session("csrf")) %>">
        <input type="hidden" name="action" value="add">
        <div><label for="new-title">What needs doing?</label><input id="new-title" name="title" maxlength="200" required placeholder="Give the old web a new job..."></div>
        <button class="primary" type="submit">Add task <span aria-hidden="true">+</span></button>
      </form>
      <nav class="filters" aria-label="Filter tasks">
        <a href="default.asp?show=all" <% If filter="all" Then Response.Write "aria-current=""page""" %>>All <span><%= total %></span></a>
        <a href="default.asp?show=open" <% If filter="open" Then Response.Write "aria-current=""page""" %>>Open <span><%= total-completed %></span></a>
        <a href="default.asp?show=done" <% If filter="done" Then Response.Write "aria-current=""page""" %>>Done <span><%= completed %></span></a>
      </nav>
      <div class="tasks">
      <% If rows.Count = 0 Then %><div class="empty"><span aria-hidden="true">[ &nbsp; ]</span><h3>A little room for possibility.</h3><p>No <%= H(filter) %> tasks here yet. Add one above or try another filter.</p></div><% End If %>
      <% For i = 0 To rows.Count - 1
         Set item = rows.Item(i)
      %><article class="task <% If item.Done Then Response.Write "is-done" %>" data-task-id="<%= item.Id %>">
        <form class="toggle" method="post" action="default.asp?show=<%= H(filter) %>">
          <input type="hidden" name="csrf" value="<%= H(Session("csrf")) %>"><input type="hidden" name="action" value="setdone"><input type="hidden" name="id" value="<%= item.Id %>">
          <input type="hidden" name="done" value="<% If item.Done Then Response.Write "0" Else Response.Write "1" %>">
          <button type="submit" aria-label="<% If item.Done Then Response.Write "Reopen " Else Response.Write "Complete " %><%= H(item.Title) %>"><% If item.Done Then Response.Write "&#10003;" Else Response.Write "&#9675;" %></button>
        </form>
        <div class="task-main">
        <% If editId = item.Id Then %>
          <form class="edit-form" method="post" action="default.asp?show=<%= H(filter) %>">
            <input type="hidden" name="csrf" value="<%= H(Session("csrf")) %>"><input type="hidden" name="action" value="rename"><input type="hidden" name="id" value="<%= item.Id %>">
            <label for="edit-title">Edit task title</label><input id="edit-title" name="title" value="<%= H(item.Title) %>" maxlength="200" required><button type="submit">Save</button><a href="default.asp?show=<%= H(filter) %>">Cancel</a>
          </form>
        <% Else %><h3><%= H(item.Title) %></h3><p>#<%= item.Id %> <span aria-hidden="true">/</span> <time datetime="<%= H(item.CreatedAt) %>"><%= H(Left(item.CreatedAt,10)) %></time></p><% End If %>
        </div>
        <div class="task-actions"><a href="default.asp?show=<%= H(filter) %>&amp;edit=<%= item.Id %>" aria-label="Edit <%= H(item.Title) %>">Edit</a><details><summary aria-label="Delete <%= H(item.Title) %>">Delete</summary><form method="post" action="default.asp?show=<%= H(filter) %>"><input type="hidden" name="csrf" value="<%= H(Session("csrf")) %>"><input type="hidden" name="action" value="delete"><input type="hidden" name="id" value="<%= item.Id %>"><button class="danger" type="submit">Confirm delete</button></form></details></div>
      </article><% Next %>
      </div>
      <div class="board-footer"><span>Real data. Real COM calls. Very real angle brackets.</span><a href="about.asp">Under the hood &#8594;</a></div>
    </section>
    <aside class="note"><span class="note-symbol" aria-hidden="true">&lt;%</span><p>In 2021, this started as a provocation.<br>Today, it has a database.</p><a href="https://medium.com/the-unpopular-opinions-of-a-senior-developer/microsoft-officially-supports-rust-powered-web-framework-d39271cc55f6">Read the original article &#8599;</a></aside>
  </main>
  <footer class="footer"><span>A SMALL EXPERIMENT BY THE SHARP NINJA</span><span><%= H(board.Version) %> / LOCAL EDITION</span></footer>
</div>
</body></html>
<% Set item=Nothing: Set rows=Nothing: Set allRows=Nothing: Set board=Nothing %>
