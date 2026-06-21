<%@ Language=VBScript %>
<% ' VI 6.0 Scripting Object Model Enabled %>
<!--#include file="../_ScriptLibrary/pm.asp"-->
<% if StartPageProcessing() Then Response.End() %>
<FORM name=thisForm METHOD=post>
<html>
<head>
<title>EAR-LAB: Data; Special Collections; Revcor Functions Database Search; CF Data Selection</title>
<meta NAME="Author" CONTENT="Viktor Vajda; dvajda@bu.edu">
<meta NAME="Generator" CONTENT="Microsoft Visual Studio 6.0">
<meta NAME="Description" CONTENT="Ear-Lab at Boston University">
</head>
<body BGCOLOR="#ffffff" LINK="#d51927" VLINK="#999999" ALINK="#999999">
<!--METADATA TYPE="DesignerControl" startspan
<OBJECT classid="clsid:9CF5D7C2-EC10-11D0-9862-0000F8027CA0" id=Recordset1 style="LEFT: 0px; TOP: 0px">
	<PARAM NAME="ExtentX" VALUE="12197">
	<PARAM NAME="ExtentY" VALUE="2090">
	<PARAM NAME="State" VALUE="(TCConn=\qDatabaseConnection\q,TCDBObject_Unmatched=\qSQL\sStatement\q,TCDBObjectName_Unmatched=\qSELECT\sCell.CF,\sStimulusWaveform.Waveform,\sExperiment.`Memo`,\sExperiment.FileLink,\sCell.OriginalCellID\sFROM\sCell,\sCellExperiment,\sExperiment,\sStimulusWaveform\sWHERE\sCell.CellID\s=\sCellExperiment.CellID\sAND\sCellExperiment.ExperimentID\s=\sExperiment.ExperimentID\sAND\sExperiment.StimulusWaveform\s=\sStimulusWaveform.StimulusWaveformID\sAND\s((Cell.SubjectID\s\l=\s7)\sOR\s(Cell.SubjectID\s=\s21)\sOR\s(Cell.SubjectID\s=\s22)\sOR\s(Cell.SubjectID\s=\s23)\sOR\s(Cell.SubjectID\s=\s24)\sOR\s(Cell.SubjectID\s=\s25)\sOR\s(Cell.SubjectID\s=\s26))\sORDER\sBY\sCell.CF,\sCell.OriginalCellID\q,TCControlID_Unmatched=\qRecordset1\q,TCPPConn=\qDatabaseConnection\q,TCPPDBObject=\qTables\q,TCPPDBObjectName=\qAHFS\q,RCDBObject=\qRCSQLStatement\q,TCSQLStatement_Unmatched=\qSELECT\sCell.CF,\sStimulusWaveform.Waveform,\sExperiment.`Memo`,\sExperiment.FileLink,\sCell.OriginalCellID\sFROM\sCell,\sCellExperiment,\sExperiment,\sStimulusWaveform\sWHERE\sCell.CellID\s=\sCellExperiment.CellID\sAND\sCellExperiment.ExperimentID\s=\sExperiment.ExperimentID\sAND\sExperiment.StimulusWaveform\s=\sStimulusWaveform.StimulusWaveformID\sAND\s((Cell.SubjectID\s\l=\s7)\sOR\s(Cell.SubjectID\s=\s21)\sOR\s(Cell.SubjectID\s=\s22)\sOR\s(Cell.SubjectID\s=\s23)\sOR\s(Cell.SubjectID\s=\s24)\sOR\s(Cell.SubjectID\s=\s25)\sOR\s(Cell.SubjectID\s=\s26))\sORDER\sBY\sCell.CF,\sCell.OriginalCellID\q,TCCursorType=\q3\s-\sStatic\q,TCCursorLocation=\q3\s-\sUse\sclient-side\scursors\q,TCLockType=\q3\s-\sOptimistic\q,TCCacheSize_Unmatched=\q10\q,TCCommTimeout_Unmatched=\q10\q,CCPrepared=0,CCAllRecords=1,TCNRecords_Unmatched=\q10\q,TCODBCSyntax_Unmatched=\q\q,TCHTargetPlatform=\q\q,TCHTargetBrowser_Unmatched=\qServer\s(ASP)\q,TCTargetPlatform=\qServer\s(ASP)\q,RCCache=\qRCNoCache\q,CCOpen=1,GCParameters=(Rows=0))">
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
	cmdTmp.CommandText = 'SELECT Cell.CF, StimulusWaveform.Waveform, Experiment.`Memo`, Experiment.FileLink, Cell.OriginalCellID FROM Cell, CellExperiment, Experiment, StimulusWaveform WHERE Cell.CellID = CellExperiment.CellID AND CellExperiment.ExperimentID = Experiment.ExperimentID AND Experiment.StimulusWaveform = StimulusWaveform.StimulusWaveformID AND ((Cell.SubjectID <= 7) OR (Cell.SubjectID = 21) OR (Cell.SubjectID = 22) OR (Cell.SubjectID = 23) OR (Cell.SubjectID = 24) OR (Cell.SubjectID = 25) OR (Cell.SubjectID = 26)) ORDER BY Cell.CF, Cell.OriginalCellID';
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
	If Request("CFMin") <> "" And Request("CFMax") <> "" Then
	newSQL = "SELECT Cell.CF, StimulusWaveform.Waveform, Experiment.Memo, Experiment.FileLink, Cell.OriginalCellID FROM Cell, CellExperiment, Experiment, StimulusWaveform WHERE Cell.CellID = CellExperiment.CellID AND CellExperiment.ExperimentID = Experiment.ExperimentID AND Experiment.StimulusWaveform = StimulusWaveform.StimulusWaveformID AND ((Cell.SubjectID <= 7) OR (Cell.SubjectID = 21) OR (Cell.SubjectID = 22) OR (Cell.SubjectID = 23) OR (Cell.SubjectID = 24) OR (Cell.SubjectID = 25) OR (Cell.SubjectID = 26)) AND (Cell.CF >= " + Request("CFMin") + " AND Cell.CF <= " + Request("CFMax") + ") ORDER BY Cell.CF, Cell.OriginalCellID"
	Recordset1.setSQLText(newSQL)
	End If
End Sub
</SCRIPT>
<center>
<table cellpadding="0" cellspacing="0" align="center" border="0" width="600">
<tr><td align="middle"><img src="/images/header/top1.gif" border=0 height="25" width="313"><img src="/images/header/top26.gif" border=0 height="25" width="114"><img src="/images/header/top3.gif" border=0 width="105" height="25"><a href="http://www.bu.edu/hrc/"><img src="/images/header/top4.gif" border=0 width="26" height="25" alt="Hearing Research Center at B.U."></a><a href="http://www.isr.umd.edu/CAAR/caar.html"><img src="/images/header/top5.gif" border=0 height="25" width="34" alt="Center for Auditory and Acoustic Research"></a><img src="/images/header/top26.gif" border=0 height="25" width="8"></a><br><img src="/images/header/bottom1.gif" border=0 height="16" width="99"><a href="/index.html"><img src="/images/header/bottom2.gif" border=0 height="16" width="50"></a><a href="/models.html"><img src="/images/header/bottom3.gif" border=0 height="16" width="56"></a><a href="/data.html"><img src="/images/header/bottom4.gif" border=0 height="16" width="40"></a><a href="/anatomy.html"><img src="/images/header/bottom5.gif" border="0" height="16" width="63"></a><a href="/physiology.html"><img src="/images/header/bottom6.gif" border=0 height="16" width="76"></a><a href="/acoustics.html"><img src="/images/header/bottom7.gif" border=0 height="16" width="96"></a><a href="/contact.html"><img src="/images/header/bottom8.gif" border=0 height="16" width="57"></a><a href="/sitemap.html"><img src="/images/header/bottom9.gif" border=0 height="16" width="63"></a></td>
</tr><tr><td align="middle"><center>&nbsp;<br>
<font face="Arial" size="5">Revcor Functions Database Search</font>
<%If Request("CFMin") <> "" And Request("CFMax") <> "" AND Recordset1.getCount() <> 0 Then%>
	<p><font face="Arial" size="4">Please Choose a Data Set</font>
<%End If%></td></tr>
<tr><td>&nbsp;<br>
<%If Request("CFMin") <> "" And Request("CFMax") <> "" AND Recordset1.getCount() <> 0 Then%>
	<table bgcolor="#FFFFCC" align="center" width="100%" cellpadding="2" cellspacing="4" border="1" bordercolor="black" noshade>
	<%Recordset1.moveFirst
	value = 1
	If Recordset1.getCount() > 20 Then
		StartValue = (Request("Page") * 20) + 1
		EndValue = Recordset1.getCount() - StartValue
		If EndValue > 20 Then
			EndValue = 20
		End If
		Recordset1.move(StartValue)
		value = StartValue
		For i = 1 To EndValue%>
			<tr><td valign="top" align="center" bgcolor="white"><%=value%></td><td valign="top" align="center" bgcolor="white"><%=Recordset1.fields.getValue("CF")%> Hz</td><td bgcolor="white" align="center"><%=Recordset1.fields.getValue("OriginalCellID")%></td><td bgcolor="white">Download File, Format:&nbsp;&nbsp;&nbsp;<a href="http://earlab.bu.edu<%=Recordset1.fields.getValue("FileLink")%>">.txt</a>&nbsp;&nbsp;&nbsp;<a href="http://earlab.bu.edu<%=Replace(Recordset1.fields.getValue("FileLink"),"txt","mat")%>">.mat</a></td><td align="center" bgcolor="white"><%=Recordset1.fields.getValue("Waveform")%></td><td align="center" bgcolor="white"><%=Recordset1.fields.getValue("Memo")%></td><td bgcolor="white" align="center"><a href="http://earlab.bu.edu/cgi-bin/matweb.exe?mlmfile=databasegraphc&graphtype=0&filename=<%=Recordset1.fields.getValue("FileLink")%>&OriginalCellID=<%=Recordset1.fields.getValue("OriginalCellID")%>&CF=<%=Recordset1.fields.getValue("CF")%>&memo=<%=Replace(Recordset1.fields.getValue("memo")," ", "%20")%>">Graph</a></td></tr>
			<%Recordset1.moveNext
			value = value + 1
		Next
	Else
	Do While Not Recordset1.EOF%>
		<tr><td valign="top" align="center" bgcolor="white"><%=value%></td><td valign="top" align="center" bgcolor="white"><%=Recordset1.fields.getValue("CF")%> Hz</td><td bgcolor="white" align="center"><%=Recordset1.fields.getValue("OriginalCellID")%></td><td bgcolor="white">Download File, Format:&nbsp;&nbsp;&nbsp;<a href="http://earlab.bu.edu<%=Recordset1.fields.getValue("FileLink")%>">.txt</a>&nbsp;&nbsp;&nbsp;<a href="http://earlab.bu.edu<%=Replace(Recordset1.fields.getValue("FileLink"),"txt","mat")%>">.mat</a></td><td align="center" bgcolor="white"><%=Recordset1.fields.getValue("Waveform")%></td><td align="center" bgcolor="white"><%=Recordset1.fields.getValue("Memo")%></td><td bgcolor="white" align="center"><a href="http://earlab.bu.edu/cgi-bin/matweb.exe?mlmfile=databasegraphc&graphtype=0&filename=<%=Recordset1.fields.getValue("FileLink")%>&OriginalCellID=<%=Recordset1.fields.getValue("OriginalCellID")%>&CF=<%=Recordset1.fields.getValue("CF")%>&memo=<%=Replace(Recordset1.fields.getValue("memo")," ", "%20")%>">Graph</a></td></tr>
		<%Recordset1.moveNext
		value = value + 1
	Loop
	End If%>
	</table></td></tr>
	<%Divided = Recordset1.getCount()/20
	If Round(Divided) < (Divided) Then
		Pages = Round(Divided) + 1
	Else
		Pages = Round(Divided)
	End If%>
	<tr><td valign="top" align="right"><font size="-1">Page <font color="#d51927"><%=Request("Page") + 1%></font> of <%=Pages%></font></td></tr>
	<tr><td align="center"><center><table align="center" width="50%" cellpadding="0" cellspacing="0" border="0"><tr>
	<%If Recordset1.getCount() > 20 Then
		NextPage = Request("Page") + 1
		PrevPage = Request("Page") - 1
		If Request("Page") > 0 Then%>
			<td valign="top" align="left"><a href="cfdata.asp?CFMin=<%=Request("CFMin")%>&CFMax=<%=Request("CFMax")%>&Page=<%=PrevPage%>">Prev Page</a></td>
		<%Else%>
			<td valign="top" align="left"><font color="#999999">Prev Page</font></td>
		<%End If
		If EndValue = 20 Then%>
			<td valign="top" align="right"><a href="cfdata.asp?CFMin=<%=Request("CFMin")%>&CFMax=<%=Request("CFMax")%>&Page=<%=NextPage%>">Next Page</a></td>
		<%Else%>
			<td valign="top" align="right"><font color="#999999">Next Page</font></td>
		<%End If
	End If%>
	</tr></table>
<%Else%>
	<table bgcolor="#FFFFCC" align="center" width="100%" cellpadding="2" cellspacing="4" border="1" bordercolor="black" noshade><tr><td bgcolor="white" align="center"><center>&nbsp;<br><font face="Arial" size="5">An Error Occured</font><p><font face="Arial" size="4" color="#d51927">You did not enter a valid characteristic frequency.<br>Please return to the previous page.<br>&nbsp;</td></tr></table>
<%End If%>
</td></tr>
<tr><td>&nbsp;</td></tr>
<tr><td><table width="100%" border="0" cellpadding="0" cellspacing="0">
<tr><td align="center"><a href="/database/carney/search.asp">back to <i>revcor functions database search</i></a></td></tr></table></td></tr>
<tr><td align="left">&nbsp;<br><table cellpadding="0" cellspacing="0" border="0"><tr><td align="left" valign="top"><font size="-1"><font color="#d51927">location:&nbsp;</font></font></td><td><font size="-1"><a href="http://earlab.bu.edu/">home</a> &gt; <a href="/data.html">data</a> &gt; <a href="/database/collections.html">special collections</a> &gt; <a href="/database/carney/search.asp">revcor functions database search</a> &gt; data selection</font></td></tr></table></td>
</tr><tr>
<td align="middle"><hr width="100%" size="1" color="black" noshade><center><font size="-1"><a href="http://earlab.bu.edu">home</a> | <a href="/models.html">models</a> | <a href="/data.html">data</a> | <a href="/anatomy.html">anatomy</a> | <a href="/physiology.html">physiology</a> | <a href="/acoustics.html">psychophysics</a> | <a href="/contact.html">contact</a> | <a href="/sitemap.html">sitemap</a>
</font><hr width="65%" size="1" color="black" noshade><font size="-2">Copyright © 2000 Boston University. All Rights Reserved.</font></td>
</tr></table></body>
<% ' VI 6.0 Scripting Object Model Enabled %>
<% EndPageProcessing() %>
</FORM>
</HTML>
