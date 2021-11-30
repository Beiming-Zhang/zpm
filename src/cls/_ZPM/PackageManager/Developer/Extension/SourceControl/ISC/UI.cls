/// Created using the page template: Default
Class %ZPM.PackageManager.Developer.Extension.SourceControl.ISC.UI Extends %ZPM.PackageManager.Developer.Extension.UI.templatePage
{

/// Displayed name of this page.
Parameter PAGENAME = "Module Perforce Mappings";

/// This Style block contains page-specific CSS style definitions.
XData Style
{
<style type="text/css">
#content input {
	width: 100%;
	box-sizing: border-box;
	-moz-box-sizing: border-box;
}
.containerStyle, #mappingTable, #sourcesGlobal {
	padding-left: 20px;
	padding-right:20px;
}
/* table style */
table.tpTable {
	border-collapse: collapse;
}

table.tpTable th, td {
	border: 1px solid F1F0E7;
	color: black;
}
table.tpTable tr {
	color: black;
	white-space: nowrap;
}
/* @doc="Caption above table. "*/
table.tpTable caption { 
	font-weight: bold;
	text-align: left;
	background: F1F0E7;
}

</style>
}

/// This XML block defines the contents of this page.
XData Contents [ XMLNamespace = "http://www.intersystems.com/zen" ]
{
<page xmlns="http://www.intersystems.com/zen" width="100%" height="100%" 
	title="SourceControl">
<html id="header" OnDrawContent="%DrawTitle" />
<form id="templateForm">
<hidden id="templateFinal" name="$FINAL" value="0" />

<fieldSet layout="vertical" legend="General Source Control Settings" enclosingClass="containerStyle" id="content" width="100%">
<text id="sourcesRoot" label="Source Root (^Sources):" />
</fieldSet>
<button align="center" onclick="zenPage.updateSources()" caption="Save" />
<spacer height="10"/>

<tablePane id="mappingTable"
queryClass="%ZPM.PackageManager.Developer.Extension.SourceControl.ISC.UI" 
queryName="ModulesAndMappings" 
dataSource="columns" 
rowSelect="false"
caption="Module Mappings">
<column header="Module" colName="Name" />
<column header="Version" colName="VersionString" />
<column header="Mapping" colName="RelativePath" OnDrawCell="DrawRelativePath" />
<column colName="AbsolutePath" hidden="true" />
<column colName="PerforcePath" hidden="true" />
<column colName="IsAbsolute" hidden="true" />
</tablePane>
<html id="sourcesGlobal" OnDrawContent="DrawSourcesGlobal" />

</form>

</page>
}

ClientMethod onfinishHandler() [ Language = javascript ]
{
	return true;
}

/// Zen page notification of an HTTP request. This method can be overwritten
/// by subclasses.<br/>
/// This is called <em>before</em> the standard Zen pre-HTTP processing occurs.
ClassMethod %OnPreHTTP() As %Boolean [ ServerOnly = 1 ]
{
	#dim %response As %CSP.Response
	Set tSC = $$$OK

	Try {
		Set tNamespace = %request.Data("$NAMESPACE",1)
		If (tNamespace '= "" && $Namespace '= tNamespace) {
			Set $Namespace = tNamespace
			Set %session.Data("$NAMESPACE") = $Namespace
		}
	} Catch e {
		Set tSC = e.AsStatus()
		Do e.Log()
	}

	Quit $$$ISOK(tSC)
}

/// Get the (localized) subtitle string for the page.
/// This may be implemented in a subclass.
Method %OnGetSubtitle() As %String
{
	Quit ""
}

/// Event handler which is invoked before a hyperevent method is called on all Zen pages.
/// This dispatched to a common PreHyperEvent handler.<br/>
/// If an application overrides this method, then it <em>must</em> invoke this base implementation
/// code (using ##super).
ClassMethod OnPreHyperEvent(class As %String, method As %String) As %Status [ ServerOnly = 1 ]
{
	#dim %request As %CSP.Request
	If $Data(%session.Data("$NAMESPACE")) {
		Set $Namespace = %session.Data("$NAMESPACE")
	}
	Quit ##super(class,method)
}

ClassMethod DrawSourcesGlobal(pSeed) As %Status
{
	Set tMax = $Length("^Sources")
	Write "<div class='sectionTitle'>",$$$TextHTML("All Mappings"),"</div>"
	Write "<pre>"
	For tWrite = 0,1 {
		If tWrite {
			Write "^Sources"_$Justify(" ",tMax-$Length("^Sources")+1)_" = """,$Get(^Sources)_""""
		}
		// Intentionally skip ^Sources(0) and ^Sources(1)
		Set tGbl = "^Sources(10)"
		For {
			Set tGbl = $Query(@tGbl,1,tValue)
			Quit:tGbl=""
			If tWrite {
				Write "<br/>"
				Write tGbl_$Justify(" ",tMax-$Length(tGbl)+1)_" = """_tValue_""""
			} Else {
				Set:($Length(tGbl)>tMax) tMax = $Length(tGbl)
			}
		}
	}
	Write "</pre>"
	Quit $$$OK
}

ClassMethod DrawRelativePath(pTablePane As %ZEN.Component.tablePane, pName As %String, pSeed As %String) As %Status
{
	Set tAbsolutePath = $$$TextHTML("Absolute Path")
	Set tPerforcePath = $$$TextHTML("Perforce Path")
	&html<<span><input id="relative-path-#(%query("Name"))#" value="#(..EscapeHTML(%query(pName)))#" size="100" onblur="zenPage.pathChanged(#(..QuoteJS(%query("Name")))#);" /></span>>
	&html<<button onclick="zenPage.savePath(#(..QuoteJS(..EscapeHTML(%query("Name"))))#);">#($$$TextHTML("Save"))#</button><br />>
	&html<#(tAbsolutePath)#: <span id="absolute-path-#(%query("Name"))#">#(..EscapeHTML(%query("AbsolutePath")))#</span><br />>
	&html<#(tPerforcePath)#: <span id="perforce-path-#(%query("Name"))#">#(..EscapeHTML(%query("PerforcePath")))#</span><br />>
	Quit $$$OK
}

ClientMethod getPath(pModuleName) [ Language = javascript ]
{
	return document.getElementById('relative-path-'+pModuleName).value;
}

ClientMethod pathChanged(pModuleName) [ Language = javascript ]
{
	document.getElementById('relative-path-'+pModuleName).style.backgroundColor = '#FFFF00';
	zenPage.UpdatePaths(pModuleName,zenPage.getPath(pModuleName));
}

ClassMethod DeterminePaths(pRelativePath As %String, Output pAbsolutePath As %String, Output pPerforcePath As %String, Output pIsAbsolute As %Boolean) As %Status
{
	Set pPerforcePath = ""
	Set tDummyName = "dummy.txt"
	Set tNoPrefixCharCode = $c($parameter("%ZPM.PackageManager.Developer.Extension.SourceControl.ISC","NOPREFIXCHARCODE"))
	If ($Extract(pRelativePath) = tNoPrefixCharCode) {
		Set pIsAbsolute = 1
		Set pAbsolutePath = $Extract(pRelativePath,2,*)
	} ElseIf (##class(%File).NormalizeDirectory(pRelativePath) = pRelativePath) {
		Set pIsAbsolute = 1
		Set pAbsolutePath = pRelativePath
	} Else {
		Set pIsAbsolute = 0
		Set pAbsolutePath = ##class(%File).NormalizeDirectory($Get(^Sources)_"\"_pRelativePath)
	}
	
	// Run with -ztag (via P4Cmd) to get structured output
	Set tSC = ##class(%Studio.SourceControl.ISC).P4Cmd("where "_pAbsolutePath_tDummyName,.tOutput)
	Set tP4Location = $Piece($Get(tOutput(1,"depotFile")),tDummyName)
	Set pAbsolutePath = $Piece($Get(tOutput(1,"path")),tDummyName) //In case a Perforce path was supplied.
	Set tErrorText = $System.Status.GetErrorText(tSC)
	// The specific error text from Perforce may be 
	If tErrorText [ "not under client's root" {
		Set tErrorText = "You must specify a folder within the Perforce workspace root."
		Set tSC = $$$ERROR($$$GeneralError,tErrorText)
	} ElseIf tErrorText [ "file(s) not in client view." {
		Set tErrorText = "You must specify a folder or branch within your Perforce workspace's client view."
		Set tSC = $$$ERROR($$$GeneralError,tErrorText)
	}
	Set pPerforcePath = $Select($$$ISERR(tSC):tErrorText,1:tP4Location)
	Quit tSC
}

ClassMethod UpdatePaths(pModuleName, pRelativePath) [ ZenMethod ]
{
	Do ..DeterminePaths(pRelativePath,.tAbsLocation,.tP4Location)
	&js<
		document.getElementById('absolute-path-#(pModuleName)#').innerText = #(..QuoteJS(tAbsLocation))#;
		document.getElementById('perforce-path-#(pModuleName)#').innerText = #(..QuoteJS(tP4Location))#;
	>
}

ClientMethod savePath(pModuleName, pRelativePath) [ Language = javascript ]
{
	var result = zenPage.ReallySavePath(pModuleName, zenPage.getPath(pModuleName));
	document.getElementById('relative-path-'+pModuleName).style.backgroundColor = '#CCFFCC';
	if (result) {
		zen('sourcesGlobal').refreshContents();
	} else {
		document.getElementById('relative-path-'+pModuleName).style.backgroundColor = '#FFCCCC';
	}
}

ClassMethod ReallySavePath(pModuleName As %String, pRelativePath As %String) As %Boolean [ ZenMethod ]
{
	Set tSC = $$$OK
	Try {
		If ($extract(pRelativePath,1) = ".") {
			Do ..DeterminePaths(pRelativePath,.tAbsolutePath)
		}
		Else {
			Set tAbsolutePath = pRelativePath
		}
		Set tSC = ..CheckDirectoryContents(tAbsolutePath, pModuleName)
		$$$ThrowOnError(tSC)
		Set tSC = ##class(%ZPM.PackageManager.Developer.Extension.SourceControl.ISC).UpdateMappings(pModuleName, tAbsolutePath)
		$$$ThrowOnError(tSC)
	} Catch e {
		Set tSC = e.AsStatus()
		&js<alert(#(..QuoteJS($System.Status.GetErrorText(tSC)))#);>
	}
	Quit $$$ISOK(tSC)
}

/// This callback is called after the server-side page 
/// object and all of its children are created.<br/>
/// Subclasses can override this to add, remove, or modify 
/// items within the page object model, or to provide values
/// for controls.
Method %OnAfterCreatePage() As %Status
{
	Set ..%GetComponentById("sourcesRoot").value = $Get(^Sources)
	Quit $$$OK
}

ClientMethod updateSources() [ Language = javascript ]
{
	zenPage.ReallyUpdateSources(zen('sourcesRoot').value)
}

ClassMethod ReallyUpdateSources(pValue As %String) [ ZenMethod ]
{
	Set ^Sources = pValue
	&js<zen('sourcesGlobal').refreshContents();zen('mappingTable').refreshContents();>
}

Query ModulesAndMappings() As %SQLQuery
{
	select m.Name,m.VersionString,mm.RelativePath,mm.AbsolutePath,mm.PerforcePath,IsAbsolute
	from %ZPM_PackageManager_Developer."Module" m
	left join %ZPM_PackageManager_Developer_Extension_SourceControl_ISC.UI_ModuleMappings() mm
		on mm.ModuleName = m.Name
}

Query ModuleMappings() As %Query(ROWSPEC = "ModuleName:%String,RelativePath:%String,AbsolutePath:%String,PerforcePath:%String,IsAbsolute:%Boolean") [ SqlProc ]
{
}

ClassMethod ModuleMappingsExecute(ByRef qHandle As %Binary) As %Status
{
	Set qHandle = "*"
	Quit $$$OK
}

ClassMethod ModuleMappingsFetch(ByRef qHandle As %Binary, ByRef Row As %List, ByRef AtEnd As %Integer = 0) As %Status [ PlaceAfter = ModuleMappingsExecute ]
{
	Set qHandle = $Order(^Sources("MODULE",qHandle),1,tLocation)
	If (qHandle = "") {
		Set AtEnd = 1
	} Else {
		Do ..DeterminePaths(tLocation,.tAbsLocation,.tP4Location,.tIsAbsolute)
		Set Row = $ListBuild(qHandle,tLocation,tAbsLocation,tP4Location,tIsAbsolute)
	}
	Quit $$$OK
}

ClassMethod ModuleMappingsClose(ByRef qHandle As %Binary) As %Status [ PlaceAfter = ModuleMappingsExecute ]
{
	Quit $$$OK
}

}
