<%@ Language=VBScript %>
<% ' VI 6.0 Scripting Object Model Enabled %>
<!--#include file="../_ScriptLibrary/pm.asp"-->
<% if StartPageProcessing() Then Response.End() %>
<FORM name=thisForm METHOD=post>
<html>
<head>
<title>EAR-LAB: Data; Special Collections; Revcor Functions Database Search; Cell Selection; Data Selection</title>
<meta NAME="Author" CONTENT="Viktor Vajda; dvajda@bu.edu">
<meta NAME="Generator" CONTENT="Microsoft Visual Studio 6.0">
<meta NAME="Description" CONTENT="Ear-Lab at Boston University">
</head>
<body BGCOLOR="#ffffff" LINK="#d51927" VLINK="#999999" ALINK="#999999">
<!--METADATA TYPE="DesignerControl" startspan
<OBJECT classid="clsid:9CF5D7C2-EC10-11D0-9862-0000F8027CA0" id=Recordset1 style="LEFT: 0px; TOP: 0px">
	<PARAM NAME="ExtentX" VALUE="12197">
	<PARAM NAME="ExtentY" VALUE="2090">
	<PARAM NAME="State" VALUE="(TCConn=\qDatabaseConnection\q,TCDBObject_Unmatched=\qSQL\sStatement\q,TCDBObjectName_Unmatched=\qSELECT\sExperiment.FileLink,\sExperiment.`Memo`,\sCellExperiment.CellID,\sCell.OriginalCellID,\sCell.CF,\sStimulusWaveform.Waveform,\sSubject.OriginalID,\sSubject.SubjectID\sFROM\sExperiment,\sCellExperiment,\sCell,\sStimulusWaveform,\sSubject\sWHERE\sExperiment.ExperimentID\s=\sCellExperiment.ExperimentID\sAND\sCellExperiment.CellID\s=\sCell.CellID\sAND\sExperiment.StimulusWaveform\s=\sStimulusWaveform.StimulusWaveformID\sAND\sCell.SubjectID\s=\sSubject.SubjectID\q,TCControlID_Unmatched=\qRecordset1\q,TCPPConn=\qDatabaseConnection\q,TCPPDBObject=\qTables\q,TCPPDBObjectName=\qAHFS\q,RCDBObject=\qRCSQLStatement\q,TCSQLStatement_Unmatched=\qSELECT\sExperiment.FileLink,\sExperiment.`Memo`,\sCellExperiment.CellID,\sCell.OriginalCellID,\sCell.CF,\sStimulusWaveform.Waveform,\sSubject.OriginalID,\sSubject.SubjectID\sFROM\sExperiment,\sCellExperiment,\sCell,\sStimulusWaveform,\sSubject\sWHERE\sExperiment.ExperimentID\s=\sCellExperiment.ExperimentID\sAND\sCellExperiment.CellID\s=\sCell.CellID\sAND\sExperiment.StimulusWaveform\s=\sStimulusWaveform.StimulusWaveformID\sAND\sCell.SubjectID\s=\sSubject.SubjectID\q,TCCursorType=\q3\s-\sStatic\q,TCCursorLocation=\q3\s-\sUse\sclient-side\scursors\q,TCLockType=\q3\s-\sOptimistic\q,TCCacheSize_Unmatched=\q10\q,TCCommTimeout_Unmatched=\q10\q,CCPrepared=0,CCAllRecords=1,TCNRecords_Unmatched=\q10\q,TCODBCSyntax_Unmatched=\q\q,TCHTargetPlatform=\q\q,TCHTargetBrowser_Unmatched=\qServer\s(ASP)\q,TCTargetPlatform=\qServer\s(ASP)\q,RCCache=\qRCNoCache\q,CCOpen=1,GCParameters=(Rows=0))">
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
	cmdTmp.CommandText = 'SELECT Experiment.FileLink, Experiment.`Memo`, CellExperiment.CellID, Cell.OriginalCellID, Cell.CF, StimulusWaveform.Waveform, Subject.OriginalID, Subject.SubjectID FROM Experiment, CellExperiment, Cell, StimulusWaveform, Subject WHERE Experiment.ExperimentID = CellExperiment.ExperimentID AND CellExperiment.CellID = Cell.CellID AND Experiment.StimulusWaveform = StimulusWaveform.StimulusWaveformID AND Cell.SubjectID = Subject.SubjectID';
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
	newSQL = "SELECT Experiment.FileLink, Experiment.Memo, CellExperiment.CellID, Cell.OriginalCellID, Cell.CF, StimulusWaveform.Waveform, Subject.SubjectID, Subject.OriginalID FROM Experiment, CellExperiment, Cell, StimulusWaveform, Subject WHERE Experiment.ExperimentID = CellExperiment.ExperimentID AND CellExperiment.CellID = Cell.CellID AND Cell.CellID = " + Request("CellNumber") + " AND Experiment.StimulusWaveform = StimulusWaveform.StimulusWaveformID AND Cell.SubjectID = Subject.SubjectID"
	Recordset1.setSQLText(newSQL)
End Sub
</SCRIPT>
<center>
<table cellpadding="0" cellspacing="0" align="center" border="0" width="600">
<tr><td align="middle"><img src="/images/header/top1.gif" border=0 height="25" width="313"><img src="/images/header/top26.gif" border=0 height="25" width="114"><img src="/images/header/top3.gif" border=0 width="105" height="25"><a href="http://www.bu.edu/hrc/"><img src="/images/header/top4.gif" border=0 width="26" height="25" alt="Hearing Research Center at B.U."></a><a href="http://www.isr.umd.edu/CAAR/caar.html"><img src="/images/header/top5.gif" border=0 height="25" width="34" alt="Center for Auditory and Acoustic Research"></a><img src="/images/header/top26.gif" border=0 height="25" width="8"></a><br><img src="/images/header/bottom1.gif" border=0 height="16" width="99"><a href="/index.html"><img src="/images/header/bottom2.gif" border=0 height="16" width="50"></a><a href="/models.html"><img src="/images/header/bottom3.gif" border=0 height="16" width="56"></a><a href="/data.html"><img src="/images/header/bottom4.gif" border=0 height="16" width="40"></a><a href="/anatomy.html"><img src="/images/header/bottom5.gif" border="0" height="16" width="63"></a><a href="/physiology.html"><img src="/images/header/bottom6.gif" border=0 height="16" width="76"></a><a href="/acoustics.html"><img src="/images/header/bottom7.gif" border=0 height="16" width="96"></a><a href="/contact.html"><img src="/images/header/bottom8.gif" border=0 height="16" width="57"></a><a href="/sitemap.html"><img src="/images/header/bottom9.gif" border=0 height="16" width="63"></a></td>
</tr><tr><td align="middle"><center>&nbsp;<br>
<font face="Arial" size="5">Revcor Functions Database Search</font><p><font face="Arial" size="4">Animal <%=Recordset1.fields.getValue("OriginalID")%>, Cell <%=Recordset1.fields.getValue("OriginalCellID")%>, with Characteristic Frequency <%=Recordset1.fields.getValue("CF")%> Hz</font></td></tr>
<tr><td>&nbsp;<table bgcolor="#FFFFCC" align="center" width="100%" cellpadding="2" cellspacing="4" border="1" bordercolor="black" noshade>
<%Recordset1.moveFirst
value = 1%>
<%Do While Not Recordset1.EOF%>
<tr><td valign="top" align="center" bgcolor="white"><%=value%></td><td bgcolor="white">Download File, Format:&nbsp;&nbsp;&nbsp;<a href="http://earlab.bu.edu<%=Recordset1.fields.getValue("FileLink")%>">.txt</a>&nbsp;&nbsp;&nbsp;<a href="http://earlab.bu.edu<%=Replace(Recordset1.fields.getValue("FileLink"),"txt","mat")%>">.mat</a></td><td align="center" bgcolor="white"><%=Recordset1.fields.getValue("Waveform")%></td><td align="center" bgcolor="white"><%=Recordset1.fields.getValue("Memo")%></td><td bgcolor="white" align="center"><a href="http://earlab.bu.edu/cgi-bin/matweb.exe?mlmfile=databasegraphc&graphtype=0&filename=<%=Recordset1.fields.getValue("FileLink")%>&OriginalCellID=<%=Recordset1.fields.getValue("OriginalCellID")%>&CF=<%=Recordset1.fields.getValue("CF")%>&memo=<%=Replace(Recordset1.fields.getValue("memo")," ", "%20")%>">Graph</a></td></tr>
<%Recordset1.moveNext
value = value + 1
Loop%></table></td></tr>
<tr><td>&nbsp;</td></tr>
<tr><td><table width="100%" border="0" cellpadding="0" cellspacing="0">
<tr><td align="center"><a href="/database/carney/cell.asp?SubjectNumber=<%=Request("SubjectNumber")%>">back to <i>cell selection</i></a></td></tr></table></td></tr>
<tr><td align="left">&nbsp;<br><table cellpadding="0" cellspacing="0" border="0"><tr><td align="left" valign="top"><font size="-1"><font color="#d51927">location:&nbsp;</font></font></td><td><font size="-1"><a href="http://earlab.bu.edu/">home</a> &gt; <a href="/data.html">data</a> &gt; <a href="/database/collections.html">special collections</a> &gt; <a href="/database/carney/search.asp">revcor functions database search</a> &gt; <a href="/database/carney/cell.asp?SubjectNumber=<%=Request("SubjectNumber")%>">cell selection</a> &gt; data selection</font></td></tr></table></td>
</tr><tr>
<td align="middle"><hr width="100%" size="1" color="black" noshade><center><font size="-1"><a href="http://earlab.bu.edu">home</a> | <a href="/models.html">models</a> | <a href="/data.html">data</a> | <a href="/anatomy.html">anatomy</a> | <a href="/physiology.html">physiology</a> | <a href="/acoustics.html">psychophysics</a> | <a href="/contact.html">contact</a> | <a href="/sitemap.html">sitemap</a>
</font><hr width="65%" size="1" color="black" noshade><font size="-2">Copyright © 2000 Boston University. All Rights Reserved.</font></td>
</tr></table></body>
<% ' VI 6.0 Scripting Object Model Enabled %>
<% EndPageProcessing() %>
</FORM>
</HTML>
