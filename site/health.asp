<%@ Language=VBScript CodePage=65001 %>
<% Option Explicit
Response.ContentType = "text/plain"
Response.Charset = "utf-8"
Response.AddHeader "Cache-Control", "no-store"
Dim board
Set board = Server.CreateObject("RustyAsp.TaskBoard")
Response.Write board.Version
Set board = Nothing
%>
