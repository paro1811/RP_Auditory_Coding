<%@ Language=VBScript %>
<% ' VI 6.0 Scripting Object Model Enabled %>
<!--#include file="../_ScriptLibrary/pm.asp"-->
<% if StartPageProcessing() Then Response.End() %>
<FORM name=thisForm METHOD=post>
</form>
<html>
<head>
<title>EAR-LAB: Data; Special Collections; Revcor Functions Database Search</title>
</head>
<meta NAME="Author" CONTENT="Viktor Vajda; dvajda@bu.edu">
<meta NAME="Generator" CONTENT="Microsoft Visual Studio 6.0">
<meta NAME="Description" CONTENT="Ear-Lab at Boston University">
</head>

<body BGCOLOR="#ffffff" LINK="#d51927" VLINK="#999999" ALINK="#999999">
<!--METADATA TYPE="DesignerControl" startspan
<OBJECT classid="clsid:9CF5D7C2-EC10-11D0-9862-0000F8027CA0" height=79 id=Recordset1 
	style="HEIGHT: 79px; LEFT: 0px; TOP: 0px; WIDTH: 461px" width=461>
	<PARAM NAME="ExtentX" VALUE="12197">
	<PARAM NAME="ExtentY" VALUE="2090">
	<PARAM NAME="State" VALUE="(TCConn=\qDatabaseConnection\q,TCDBObject_Unmatched=\qSQL\sStatement\q,TCDBObjectName_Unmatched=\qSELECT\sSubject.SubjectID,\sSubject.OriginalID\sFROM\sSubject,\sSubjectPublication\sWHERE\sSubject.SubjectID\s=\sSubjectPublication.SubjectID\sAND\s(SubjectPublication.PublicationID\s=\s55)\sORDER\sBY\sSubject.OriginalID\q,TCControlID_Unmatched=\qRecordset1\q,TCPPConn=\qDatabaseConnection\q,TCPPDBObject=\qTables\q,TCPPDBObjectName=\qAuthor\q,RCDBObject=\qRCSQLStatement\q,TCSQLStatement_Unmatched=\qSELECT\sSubject.SubjectID,\sSubject.OriginalID\sFROM\sSubject,\sSubjectPublication\sWHERE\sSubject.SubjectID\s=\sSubjectPublication.SubjectID\sAND\s(SubjectPublication.PublicationID\s=\s55)\sORDER\sBY\sSubject.OriginalID\q,TCCursorType=\q3\s-\sStatic\q,TCCursorLocation=\q3\s-\sUse\sclient-side\scursors\q,TCLockType=\q3\s-\sOptimistic\q,TCCacheSize_Unmatched=\q100\q,TCCommTimeout_Unmatched=\q30\q,CCPrepared=0,CCAllRecords=1,TCNRecords_Unmatched=\q10\q,TCODBCSyntax_Unmatched=\q\q,TCHTargetPlatform=\q\q,TCHTargetBrowser_Unmatched=\qServer\s(ASP)\q,TCTargetPlatform=\qInherit\sfrom\spage\q,RCCache=\qRCBookPage\q,CCOpen=1,GCParameters=(Rows=0))">
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
	cmdTmp.CommandTimeout = 30;
	cmdTmp.CommandText = 'SELECT Subject.SubjectID, Subject.OriginalID FROM Subject, SubjectPublication WHERE Subject.SubjectID = SubjectPublication.SubjectID AND (SubjectPublication.PublicationID = 55) ORDER BY Subject.OriginalID';
	rsTmp.CacheSize = 100;
	rsTmp.CursorType = 3;
	rsTmp.CursorLocation = 3;
	rsTmp.LockType = 3;
	Recordset1.setRecordSource(rsTmp);
	Recordset1.open();
	if (thisPage.getState('pb_Recordset1') != null)
		Recordset1.setBookmark(thisPage.getState('pb_Recordset1'));
}
function _Recordset1_ctor()
{
	CreateRecordset('Recordset1', _initRecordset1, null);
}
function _Recordset1_dtor()
{
	Recordset1._preserveState();
	thisPage.setState('pb_Recordset1', Recordset1.getBookmark());
}
</SCRIPT>

<!--METADATA TYPE="DesignerControl" endspan-->
<center>
<table cellpadding="0" cellspacing="0" align="center" border="0" width="600">
<tr><td align="middle"><img src="/images/header/top1.gif" border=0 height="25" width="313"><img src="/images/header/top26.gif" border=0 height="25" width="114"><img src="/images/header/top3.gif" border=0 width="105" height="25"><a href="http://www.bu.edu/hrc/"><img src="/images/header/top4.gif" border=0 width="26" height="25" alt="Hearing Research Center at B.U."></a><a href="http://www.isr.umd.edu/CAAR/caar.html"><img src="/images/header/top5.gif" border=0 height="25" width="34" alt="Center for Auditory and Acoustic Research"></a><img src="/images/header/top26.gif" border=0 height="25" width="8"></a><br><img src="/images/header/bottom1.gif" border=0 height="16" width="99"><a href="/index.html"><img src="/images/header/bottom2.gif" border=0 height="16" width="50"></a><a href="/models.html"><img src="/images/header/bottom3.gif" border=0 height="16" width="56"></a><a href="/data.html"><img src="/images/header/bottom4.gif" border=0 height="16" width="40"></a><a href="/anatomy.html"><img src="/images/header/bottom5.gif" border="0" height="16" width="63"></a><a href="/physiology.html"><img src="/images/header/bottom6.gif" border=0 height="16" width="76"></a><a href="/acoustics.html"><img src="/images/header/bottom7.gif" border=0 height="16" width="96"></a><a href="/contact.html"><img src="/images/header/bottom8.gif" border=0 height="16" width="57"></a><a href="/sitemap.html"><img src="/images/header/bottom9.gif" border=0 height="16" width="63"></a></td>
</tr><tr><td align="middle"><center>&nbsp;<br>
<font face="Arial" size="5">Revcor Functions Database Search</font></td></tr>
<tr><td>&nbsp;<br><table align="center" bgcolor="#FFFFCC" width="100%" cellpadding="2" cellspacing="4" border="1" bordercolor="black" noshade>
<tr><td valign="top" align="middle" bgcolor="white"><center><table width="100%" align="center" cellpadding="2" cellspacing="2" border="0" bgcolor="white">
<tr><td colspan="2" align="center">&nbsp;<br><center><font face="Arial" size="4">Please Choose an Animal Number</font><br><i>or</i><br><font face="Arial" size="4">Range of Characteristic Frequencies</font><br>&nbsp;</td></tr>
<tr><form name="animal" action="cell.asp" method="post"><td align="center" valign="bottom">
<!--METADATA TYPE="DesignerControl" startspan
<OBJECT classid="clsid:B5F0E450-DC5F-11D0-9846-0000F8027CA0" height=69 id=SubjectNumber 
	style="HEIGHT: 69px; LEFT: 0px; TOP: 0px; WIDTH: 135px" width=135>
	<PARAM NAME="_ExtentX" VALUE="2540">
	<PARAM NAME="_ExtentY" VALUE="1826">
	<PARAM NAME="id" VALUE="SubjectNumber">
	<PARAM NAME="DataSource" VALUE="Recordset1">
	<PARAM NAME="DataField" VALUE="OriginalID">
	<PARAM NAME="ControlStyle" VALUE="1">
	<PARAM NAME="Lines" VALUE="5">
	<PARAM NAME="Enabled" VALUE="-1">
	<PARAM NAME="Visible" VALUE="-1">
	<PARAM NAME="Platform" VALUE="0">
	<PARAM NAME="UsesStaticList" VALUE="0">
	<PARAM NAME="RowSource" VALUE="Recordset1">
	<PARAM NAME="BoundColumn" VALUE="SubjectID">
	<PARAM NAME="ListField" VALUE="OriginalID">
	<PARAM NAME="LookupPlatform" VALUE="0">
	<PARAM NAME="LocalPath" VALUE="../"></OBJECT>
-->
<!--#INCLUDE FILE="../_ScriptLibrary/ListBox.ASP"-->
<SCRIPT LANGUAGE=JavaScript RUNAT=Server>
function _initSubjectNumber()
{
	Recordset1.advise(RS_ONDATASETCOMPLETE, 'SubjectNumber.setRowSource(Recordset1, \'OriginalID\', \'SubjectID\');');
	SubjectNumber.setDataSource(Recordset1);
	SubjectNumber.setDataField('OriginalID');
	SubjectNumber.size = 5;
}
function _SubjectNumber_ctor()
{
	CreateListbox('SubjectNumber', _initSubjectNumber, null);
}
</script>
<% SubjectNumber.display %>

<!--METADATA TYPE="DesignerControl" endspan-->
<p><input name="AnimalSubmit" type="Submit" value="Perform Search"></td></form><form name="cf" action="cfdata.asp" method="post"><td align="center" valign="bottom"><input type="hidden" name="Page" value="0">
<!--METADATA TYPE="DesignerControl" startspan
<OBJECT classid="clsid:B5F0E469-DC5F-11D0-9846-0000F8027CA0" height=19 id=CFMin style="HEIGHT: 19px; LEFT: 0px; TOP: 0px; WIDTH: 36px" 
	width=36>
	<PARAM NAME="_ExtentX" VALUE="953">
	<PARAM NAME="_ExtentY" VALUE="503">
	<PARAM NAME="id" VALUE="CFMin">
	<PARAM NAME="ControlType" VALUE="0">
	<PARAM NAME="Lines" VALUE="3">
	<PARAM NAME="DataSource" VALUE="">
	<PARAM NAME="DataField" VALUE="">
	<PARAM NAME="Enabled" VALUE="-1">
	<PARAM NAME="Visible" VALUE="-1">
	<PARAM NAME="MaxChars" VALUE="10">
	<PARAM NAME="DisplayWidth" VALUE="6">
	<PARAM NAME="Platform" VALUE="256">
	<PARAM NAME="LocalPath" VALUE="../"></OBJECT>
-->
<!--#INCLUDE FILE="../_ScriptLibrary/TextBox.ASP"-->
<SCRIPT LANGUAGE=JavaScript RUNAT=Server>
function _initCFMin()
{
	CFMin.setStyle(TXT_TEXTBOX);
	CFMin.setMaxLength(10);
	CFMin.setColumnCount(6);
}
function _CFMin_ctor()
{
	CreateTextbox('CFMin', _initCFMin, null);
}
</script>
<% CFMin.display %>

<!--METADATA TYPE="DesignerControl" endspan-->
Hz<br><i>to</i><br>
<!--METADATA TYPE="DesignerControl" startspan
<OBJECT classid="clsid:B5F0E469-DC5F-11D0-9846-0000F8027CA0" height=19 id=CFMax style="HEIGHT: 19px; LEFT: 0px; TOP: 0px; WIDTH: 36px" 
	width=36>
	<PARAM NAME="_ExtentX" VALUE="953">
	<PARAM NAME="_ExtentY" VALUE="503">
	<PARAM NAME="id" VALUE="CFMax">
	<PARAM NAME="ControlType" VALUE="0">
	<PARAM NAME="Lines" VALUE="3">
	<PARAM NAME="DataSource" VALUE="">
	<PARAM NAME="DataField" VALUE="">
	<PARAM NAME="Enabled" VALUE="-1">
	<PARAM NAME="Visible" VALUE="-1">
	<PARAM NAME="MaxChars" VALUE="10">
	<PARAM NAME="DisplayWidth" VALUE="6">
	<PARAM NAME="Platform" VALUE="256">
	<PARAM NAME="LocalPath" VALUE="../"></OBJECT>
-->
<SCRIPT LANGUAGE=JavaScript RUNAT=Server>
function _initCFMax()
{
	CFMax.setStyle(TXT_TEXTBOX);
	CFMax.setMaxLength(10);
	CFMax.setColumnCount(6);
}
function _CFMax_ctor()
{
	CreateTextbox('CFMax', _initCFMax, null);
}
</script>
<% CFMax.display %>

<!--METADATA TYPE="DesignerControl" endspan-->
Hz<p><input name="CFSubmit" type="Submit" value="Perform Search"></td></form></tr>
<tr><td colspan="2">&nbsp;</td></tr></table></td></tr></table></td></tr>
<tr><td><font face="Arial" size="4">&nbsp;<br><center>References</center></font>
<p><code>
Carney, L.H. and Yin, T.C.T. (1988) Temporal coding of resonances by low-
frequency auditory nerve fibers: Single fibers responses and a population
model. J. Neurophysiol. 60:1653-1677.
<p>
Carney, L.H. (1990) Sensitivities of cells in the anteroventral cochlear
nucleus of cat to spatiotemporal discharge patterns across primary
afferents. J. Neurophysiol. 64:437-456.
<p>
Carney, L.H., McDuffy, M.J., Shekhter I. (1999) Frequency glides in the
impulse responses of auditory-nerve fibers. J. Acoust. Soc. Am.
105:2384-2391.</code></td></tr>
<tr><td>&nbsp;</td></tr>
<tr><td><table width="100%" border="0" cellpadding="0" cellspacing="0">
<tr><td align="center"><a href="/database/collections.html">up to <i>special collections</i></a></td></tr></table></td></tr>
<tr><td align="left">&nbsp;<br><table cellpadding="0" cellspacing="0" border="0"><tr><td align="left" valign="top"><font size="-1"><font color="#d51927">location:&nbsp;</font></font></td><td><font size="-1"><a href="http://earlab.bu.edu/">home</a> &gt; <a href="/data.html">data</a> &gt; <a href="/database/collections.html">special collections</a> &gt; revcor functions database search</font></td></tr></table></td>
</tr><tr>
<td align="middle"><hr width="100%" size="1" color="black" noshade><center><font size="-1"><a href="http://earlab.bu.edu">home</a> | <a href="/models.html">models</a> | <a href="/data.html">data</a> | <a href="/anatomy.html">anatomy</a> | <a href="/physiology.html">physiology</a> | <a href="/acoustics.html">psychophysics</a> | <a href="/contact.html">contact</a> | <a href="/sitemap.html">sitemap</a>
</font><hr width="65%" size="1" color="black" noshade><font size="-2">Copyright © 2000 Boston University. All Rights Reserved.</font></td>
</tr></table></body>
<% ' VI 6.0 Scripting Object Model Enabled %>
<% EndPageProcessing() %>
</FORM>
</HTML>
