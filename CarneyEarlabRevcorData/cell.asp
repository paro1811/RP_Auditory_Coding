<%@ Language=VBScript %>
<% ' VI 6.0 Scripting Object Model Enabled %>
<!--#include file="../_ScriptLibrary/pm.asp"-->
<% if StartPageProcessing() Then Response.End() %>
<FORM name=thisForm METHOD=post>
</form>
<html>
<head>
<title>EAR-LAB: Data; Special Collections; Revcor Functions Database Search; Cell Selection</title>
<meta NAME="Author" CONTENT="Viktor Vajda; dvajda@bu.edu">
<meta NAME="Generator" CONTENT="Microsoft Visual Studio 6.0">
<meta NAME="Description" CONTENT="Ear-Lab at Boston University">
</head>
<body BGCOLOR="#ffffff" LINK="#d51927" VLINK="#999999" ALINK="#999999">
<!--METADATA TYPE="DesignerControl" startspan
<OBJECT classid="clsid:9CF5D7C2-EC10-11D0-9862-0000F8027CA0" id=Recordset1 style="LEFT: 0px; TOP: 0px">
	<PARAM NAME="ExtentX" VALUE="12197">
	<PARAM NAME="ExtentY" VALUE="2090">
	<PARAM NAME="State" VALUE="(TCConn=\qDatabaseConnection\q,TCDBObject_Unmatched=\qSQL\sStatement\q,TCDBObjectName_Unmatched=\qSELECT\sCell.CellID,\sCell.OriginalCellID,\sSubject.OriginalID\sFROM\sCell,\sSubject\sWHERE\sCell.SubjectID\s=\sSubject.SubjectID\sAND\s(Subject.SubjectID\s=\s1)\q,TCControlID_Unmatched=\qRecordset1\q,TCPPConn=\qDatabaseConnection\q,TCPPDBObject=\qTables\q,TCPPDBObjectName=\qAHFS\q,RCDBObject=\qRCSQLStatement\q,TCSQLStatement_Unmatched=\qSELECT\sCell.CellID,\sCell.OriginalCellID,\sSubject.OriginalID\sFROM\sCell,\sSubject\sWHERE\sCell.SubjectID\s=\sSubject.SubjectID\sAND\s(Subject.SubjectID\s=\s1)\q,TCCursorType=\q3\s-\sStatic\q,TCCursorLocation=\q3\s-\sUse\sclient-side\scursors\q,TCLockType=\q3\s-\sOptimistic\q,TCCacheSize_Unmatched=\q10\q,TCCommTimeout_Unmatched=\q10\q,CCPrepared=0,CCAllRecords=1,TCNRecords_Unmatched=\q10\q,TCODBCSyntax_Unmatched=\q\q,TCHTargetPlatform=\q\q,TCHTargetBrowser_Unmatched=\qServer\s(ASP)\q,TCTargetPlatform=\qServer\s(ASP)\q,RCCache=\qRCNoCache\q,CCOpen=1,GCParameters=(Rows=0))">
	<PARAM NAME="LocalPath" VALUE="../"></OBJECT>
-->
<!--#INCLUDE FILE="../_ScriptLibrary/Recordset.ASP"-->
<SCRIPT LANGUAGE="JavaScript" RUNAT="server">
function _initRecordset1()
{
	var DBConn = Server.CreateObject('ADODB.Connection');
	DBConn.ConnectionTimeout = Application('DatabaseConnection_ConnectionTimeout');
	DBConn.CommandTimeout = Application('DatabaseConnection_CommandTimeout');
	DBConn.CursorLocation = Application('DatabaseConnection_CursorLocation');
	DBConn.Open(Application('DatabaseConnection_ConnectionString'), Application('DatabaseConnection_RuntimeUserName'), Application('DatabaseConnection_RuntimePassword'));
	var cmdTmp = Server.CreateObject('ADODB.Command');
	var rsTmp = Server.CreateObject('ADODB.Recordset');
	cmdTmp.ActiveConnection = DBConn;
	rsTmp.Source = cmdTmp;
	cmdTmp.CommandType = 1;
	cmdTmp.CommandTimeout = 10;
	cmdTmp.CommandText = 'SELECT Cell.CellID, Cell.OriginalCellID, Subject.OriginalID FROM Cell, Subject WHERE Cell.SubjectID = Subject.SubjectID AND (Subject.SubjectID = 1)';
	rsTmp.CacheSize = 10;
	rsTmp.CursorType = 3;
	rsTmp.CursorLocation = 3;
	rsTmp.LockType = 3;
	Recordset1.setRecordSource(rsTmp);
	Recordset1.open();
}
function _Recordset1_ctor()
{
	CreateRecordset('Recordset1', _initRecordset1, null);
}
</SCRIPT>

<!--METADATA TYPE="DesignerControl" endspan-->
<SCRIPT LANGUAGE=vbscript RUNAT=Server>
Sub Recordset1_onbeforeopen ()
	If Request("SubjectNumber") <> "" Then
	newSQL = "SELECT Cell.CellID, Cell.OriginalCellID, Subject.OriginalID FROM Cell, Subject WHERE Cell.SubjectID = Subject.SubjectID AND Subject.SubjectID = " + Request("SubjectNumber")
	Recordset1.setSQLText(newSQL)
	End If
End Sub
</SCRIPT>
<center>
<table cellpadding="0" cellspacing="0" align="center" border="0" width="600">
<tr><td align="middle"><img src="/images/header/top1.gif" border=0 height="25" width="313"><img src="/images/header/top26.gif" border=0 height="25" width="114"><img src="/images/header/top3.gif" border=0 width="105" height="25"><a href="http://www.bu.edu/hrc/"><img src="/images/header/top4.gif" border=0 width="26" height="25" alt="Hearing Research Center at B.U."></a><a href="http://www.isr.umd.edu/CAAR/caar.html"><img src="/images/header/top5.gif" border=0 height="25" width="34" alt="Center for Auditory and Acoustic Research"></a><img src="/images/header/top26.gif" border=0 height="25" width="8"></a><br><img src="/images/header/bottom1.gif" border=0 height="16" width="99"><a href="/index.html"><img src="/images/header/bottom2.gif" border=0 height="16" width="50"></a><a href="/models.html"><img src="/images/header/bottom3.gif" border=0 height="16" width="56"></a><a href="/data.html"><img src="/images/header/bottom4.gif" border=0 height="16" width="40"></a><a href="/anatomy.html"><img src="/images/header/bottom5.gif" border="0" height="16" width="63"></a><a href="/physiology.html"><img src="/images/header/bottom6.gif" border=0 height="16" width="76"></a><a href="/acoustics.html"><img src="/images/header/bottom7.gif" border=0 height="16" width="96"></a><a href="/contact.html"><img src="/images/header/bottom8.gif" border=0 height="16" width="57"></a><a href="/sitemap.html"><img src="/images/header/bottom9.gif" border=0 height="16" width="63"></a></td>
</tr><tr><td align="middle"><center>&nbsp;<br>
<font face="Arial" size="5">Revcor Functions Database Search</font></td></tr>
<tr><td>&nbsp;<br><table align="center" bgcolor="#FFFFCC" width="100%" cellpadding="2" cellspacing="4" border="1" bordercolor="black" noshade>
<tr><td valign="top" align="middle" bgcolor="white"><center><table width="100%" align="center" cellpadding="2" cellspacing="2" border="0" bgcolor="white">
<tr><td align="center">&nbsp;<br><center>
<%If Request("SubjectNumber") <> "" Then%>
<font face="Arial" size="4">Please Choose a Cell Number</font><br><i>for</i><br><font face="Arial" size="4">Animal <%=Recordset1.fields.getValue("OriginalID")%></font><br>&nbsp;</td></tr>
<tr><form name="data" action="data.asp" method="post"><input type="hidden" name="SubjectNumber" value="<%=Request("SubjectNumber")%>"><td align="center">
<!--METADATA TYPE="DesignerControl" startspan
<OBJECT classid="clsid:B5F0E450-DC5F-11D0-9846-0000F8027CA0" height=69 id=CellNumber 
	style="HEIGHT: 69px; LEFT: 0px; TOP: 0px; WIDTH: 96px" width=96>
	<PARAM NAME="_ExtentX" VALUE="2540">
	<PARAM NAME="_ExtentY" VALUE="1826">
	<PARAM NAME="id" VALUE="CellNumber">
	<PARAM NAME="DataSource" VALUE="Recordset1">
	<PARAM NAME="DataField" VALUE="CellID">
	<PARAM NAME="ControlStyle" VALUE="1">
	<PARAM NAME="Lines" VALUE="5">
	<PARAM NAME="Enabled" VALUE="-1">
	<PARAM NAME="Visible" VALUE="-1">
	<PARAM NAME="Platform" VALUE="0">
	<PARAM NAME="UsesStaticList" VALUE="0">
	<PARAM NAME="RowSource" VALUE="Recordset1">
	<PARAM NAME="BoundColumn" VALUE="CellID">
	<PARAM NAME="ListField" VALUE="OriginalCellID">
	<PARAM NAME="LookupPlatform" VALUE="0">
	<PARAM NAME="LocalPath" VALUE="../"></OBJECT>
-->
<!--#INCLUDE FILE="../_ScriptLibrary/ListBox.ASP"-->
<SCRIPT LANGUAGE=JavaScript RUNAT=Server>
function _initCellNumber()
{
	Recordset1.advise(RS_ONDATASETCOMPLETE, 'CellNumber.setRowSource(Recordset1, \'OriginalCellID\', \'CellID\');');
	CellNumber.setDataSource(Recordset1);
	CellNumber.setDataField('CellID');
	CellNumber.size = 5;
}
function _CellNumber_ctor()
{
	CreateListbox('CellNumber', _initCellNumber, null);
}
</script>
<% CellNumber.display %>

<!--METADATA TYPE="DesignerControl" endspan-->
<p><input type="Submit" value="Select Cell Number"><br>&nbsp;</td></form></tr>
<%Else%>
<font face="Arial" size="5">An Error Occured</font><p><font face="Arial" size="4" color="#d51927">You did not choose an animal on the previous page.<br>Please return and make a selection.<br>&nbsp;</td></tr>
<%End If%>
</table></td></tr></table></td></tr>
<tr><td>&nbsp;</td></tr>
<tr><td><table width="100%" border="0" cellpadding="0" cellspacing="0">
<tr><td align="center"><a href="/database/carney/search.asp">back to <i>revcor functions database search</i></a></td></tr></table></td></tr>
<tr><td align="left">&nbsp;<br><table cellpadding="0" cellspacing="0" border="0"><tr><td align="left" valign="top"><font size="-1"><font color="#d51927">location:&nbsp;</font></font></td><td><font size="-1"><a href="http://earlab.bu.edu/">home</a> &gt; <a href="/data.html">data</a> &gt; <a href="/database/collections.html">special collections</a> &gt; <a href="/database/carney/search.asp">revcor functions database search</a> &gt; cell selection</font></td></tr></table></td>
</tr><tr>
<td align="middle"><hr width="100%" size="1" color="black" noshade><center><font size="-1"><a href="http://earlab.bu.edu">home</a> | <a href="/models.html">models</a> | <a href="/data.html">data</a> | <a href="/anatomy.html">anatomy</a> | <a href="/physiology.html">physiology</a> | <a href="/acoustics.html">psychophysics</a> | <a href="/contact.html">contact</a> | <a href="/sitemap.html">sitemap</a>
</font><hr width="65%" size="1" color="black" noshade><font size="-2">Copyright © 2000 Boston University. All Rights Reserved.</font></td>
</tr></table></body>
<% ' VI 6.0 Scripting Object Model Enabled %>
<% EndPageProcessing() %>
</FORM>
</HTML>
