/// Package Manager UI template page
Class %ZPM.PackageManager.Developer.Extension.UI.templatePage Extends %ZEN.Template.studioTemplate [ System = 4 ]
{

/// Class name of application this page belongs to.
Parameter APPLICATION = "%ZPM.PackageManager.Developer.Extension.UI.Application";

/// Displayed name of this page.
Parameter PAGENAME = "Package Manager templatePage";

/// Domain used for localization.
Parameter DOMAIN = "ZPM";

Parameter CSSINCLUDES As STRING = "bootstrap-3-3-5/dist/css/bootstrap.min.css";

Parameter JSINCLUDES As STRING = "jquery-3.5.1.min.js,bootstrap-3-3-5/dist/js/bootstrap.min.js";

Property Page As %ZEN.Datatype.string;

Property Namespace As %ZEN.Datatype.string(ZENURL = "$NAMESPACE");

Property SelectModuleNameTitle As %ZEN.Datatype.caption [ InitialExpression = {$$$TextHTML("(Select a Module name)")} ];

Property SelectOne As %ZEN.Datatype.caption [ InitialExpression = {$$$TextHTML("(select one)")} ];

Property lblErrorPrefix As %ZEN.Datatype.caption [ InitialExpression = {$$$TextHTML("Error!", "ZPM")} ];

/// True if the contents of this page need to be saved.
Property pageModified As %ZEN.Datatype.boolean [ InitialExpression = 0 ];

/// This Style block contains page-specific CSS style definitions.
XData Style
{
<style type="text/css">
/* command button styles */
.commandButton {
	background: #669CC9;
	color: white;
	text-decoration: none;
	padding: 3px;
	padding-left: 10px;
	padding-right: 10px;
	border-radius: 5px;
 	border-top: 1px solid lightgray;
    border-left: 1px solid lightgray;
    border-right: 2px solid gray;
    border-bottom: 2px solid gray;
}

#btnBack input.commandButton:hover,
#btnNext input.commandButton:hover,
#btnFinish input.commandButton:hover,
#btnCancel input.commandButton:hover,
#btnHelp input.commandButton:hover,
.commandButton:hover {
	background: #337AB7;
	color: white;
}

.commandButtonDisabled {
	background: white;
	color: #424242;
}

#btnBack input.commandButtonDisabled:hover,
#btnNext input.commandButtonDisabled:hover,
#btnFinish input.commandButtonDisabled:hover,
#btnCancel input.commandButtonDisabled:hover,
#btnHelp input.commandButtonDisabled:hover,
.commandButtonDisabled:hover {
	background: #D0D0D0;
	color: black;
}
</style>
}

/// Provide HTML for html title box.<br>
/// Default implementation displays the standard Package Manager title bar.
Method %DrawTitle(pSeed As %String) As %Status
{
	#; draw html title box
	Set tTitle = ..%OnGetTitle()
	Set tSubTitle = ..%OnGetSubtitle()
	&html<<div class="headerPane">
		<div class="title">#(tTitle)#</div>
		<div class="subTitleArea"><span class="subTitle">#(tSubTitle)#</span></div>
		<div>>

	Quit $$$OK
}

/// Get the (localized) title string for the page.
/// This may be implemented in a subclass.
Method %OnGetTitle() As %String
{
	Quit $$$TextHTML("Package Manager")
}

/// Get the (localized) subtitle string for the page.
/// This may be implemented in a subclass.
Method %OnGetSubtitle() As %String
{
	If %page.Page '= "" {
		Quit %page.Page
	}
	Quit ""
}

/// Provide HTML for html footer box.<br>
/// Default implementation displays the standard Cancel button.
Method %DrawFooter(pSeed As %String) As %Status
{
	&html<<div class="footerPane">
		<div class="footerLeft">
		</div>
		<div class="footerRight">
		<button class="commandButton" onclick="zenPage.cancelTemplate();">#($$$Text("Cancel"))#</button>
		</div>
		<div>>

	Quit $$$OK
}

ClientMethod setErrorMessage(
	msg,
	ctrl) [ Language = javascript ]
{
	if (!ctrl) {
		var ctrl = 'warning';			
	}
	var msgErr = this.lblErrorPrefix;
	if (msg != '') {
		$('#'+ctrl).html('<div class="alert alert-danger">'+
		'<span class="close" data-dismiss="alert">&times;</span>'+
		'<strong>'+msgErr+'</strong> ' + msg + '</div>');
	} else {
		$('#'+ctrl).html('');
	}
	return;
}

/// Generic method to load a bootstrap style dropdown. 
/// id: input text field id for the dropdown
/// dataSource:  jsonProvider id
/// valueProperty: Value property name
/// descProperty (optional): Description property name. If not passed in, valueProperty will be used
/// allowEmpty (optional): if 1 is passed in, then build an empty selection
/// example: this.loadDropdown('InstallerClass','jsonInstallerClassList','Name','DisplayName');
ClientMethod loadDropdown(
	id,
	dataSource,
	valueProperty,
	descProperty,
	allowEmpty) [ Language = javascript ]
{
	var data = zen(dataSource).getContentObject();
	var ul = $('#'+id).closest('.dropdown').find('ul');
	descProperty = descProperty ? descProperty : valueProperty;
	ul.find('li').remove().end();
	if (data.children) {
		data = data.children;
		if (allowEmpty) {
			ul.append("<li><a href='#' data-value=''>" + this.SelectOne + "</a></li>");	
		}
		for (i = 0; i < data.length; i++) {
			ul.append("<li><a href='#' data-value='"+data[i][valueProperty]+"'>" + data[i][descProperty] + "</a></li>");
		}
	}
	
	// Add event handler
	$(function() {
		$('.dropdown-menu a').click(function() {
		$(this).closest('.dropdown').find('input')
			.val($(this).attr('data-value'));
			zenPage.isModified();
		});
	});
}

ClientMethod isModified() [ Language = javascript ]
{
	this.pageModified = true;
}

/// Close the template window.
ClientMethod cancelTemplate() [ Language = javascript ]
{
	if (this.confirmCancel()) {
		this.invokeSuper('cancelTemplate',arguments);
	}
}

/// Check before Cancel out. If user has unsaved changes, prompt to save.
ClientMethod confirmCancel() [ Language = javascript ]
{
	var ok = true;
	if (this.pageModified) {
		var msg = $$$Text("There are unsaved changes on this page.","ZPM") + "\n\n"
		+ $$$Text("Are you sure you want to exit and discard changes?","ZPM");
		var ok = confirm(msg);
		if (ok == true) {
			this.pageModified = false;		
		}
	}
	return ok;
}

/// Method to return Module list used by multiple templates.
Method GetModuleListSQL(
	ByRef pParms As %String,
	ByRef pSQL As %String,
	pCriteria As %ZEN.proxyObject,
	ByRef pPagingInfo As %String) As %Status
{
	Set pSQL = ""
	Set tSC = ##class(%ZPM.PackageManager.Developer.API).GetModuleListSQL(.pSQL)
	Quit tSC
}

/// Method to return list of installed snapshot modules
Method GetSnapshotModuleListSQL(
	ByRef pParms As %String,
	ByRef pSQL As %String,
	pCriteria As %ZEN.proxyObject,
	ByRef pPagingInfo As %String) As %Status
{
	// Only list snapshots
	Quit ##class(%ZPM.PackageManager.Developer.API).GetInstalledModuleListSQL(.pSQL,1)
}

/// Commonly used localization strings. (please enter in alphabetical order)
Method GetCommonLocalization(ByRef pResources As %String)
{
	/// buttons
	Set pResources("lblAdd") = $$$TextHTML("Add...")	
	Set pResources("lblApply") = $$$TextHTML("Apply")
	Set pResources("lblCancel") = $$$TextHTML("Cancel")
	Set pResources("lblClose") = $$$TextHTML("Close")
	Set pResources("lblDelete") = $$$TextHTML("Delete")
	Set pResources("lblFinish") = $$$TextHTML("Finish")
	Set pResources("lblNo") = $$$TextHTML("No")
	Set pResources("lblOK") = $$$TextHTML("OK")
	Set pResources("lblSave") = $$$TextHTML("Save")
	Set pResources("lblYes") = $$$TextHTML("Yes")
	/// field name
	Set pResources("lblDescription") = $$$TextHTML("Description")
	Set pResources("lblName") = $$$TextHTML("Name")
	Set pResources("lblNamespace") = $$$TextHTML("Namespace")	
	/// hint
	Set pResources("hintRequired") = $$$TextHTML("Required entry")
	/// error message
	Set pResources("msgError") = $$$TextHTML("Please complete required fields or correct error")
}

ClassMethod CheckDirectoryContents(
	pPath As %String,
	pExpectedModuleName As %String,
	Output pMessage As %String) As %Status
{
	Set tSC = $$$OK
	Set pMessage = ""
	Try {
		If (pPath = "") {
			Quit
		}
		If ($Extract(pPath) = $c(8)) {
			Set pPath = $Extract(pPath,2,*)
		}
		Set tCurrentFile = pPath_"module.xml"
		If ##class(%File).Exists(tCurrentFile) {
			// List contents and assert that they match pModuleName
			Set tSC = $System.OBJ.Load(tCurrentFile,"-d",,.tLoadedList,1)
			If $$$ISOK(tSC) {
				If (tLoadedList '= pExpectedModuleName_##class(%ZPM.PackageManager.Developer.Document.Module).#DEFAULTEXTENSION) {
					Set tModuleName = $Piece(tLoadedList,".",1,*-1)
					Set pMessage = $$$FormatText("File '%1' already contains module manifest for '%2'.",tCurrentFile,tModuleName)
					Set tSC = $$$ERROR($$$GeneralError,pMessage)
				}
			}
		}
	} Catch e {
		Set tSC = e.AsStatus()
		Set pMessage = $System.Status.GetErrorText(tSC)
	}
	Quit tSC
}

/// Lock down access to this class to the /isc/studio/templates/ web application.
Parameter CSPURL As COSEXPRESSION = """/isc/studio/templates/""_$classname()_"".cls""";

/// All CSP/Zen pages in the package manager require USE permissions on the %Development resource.
Parameter SECURITYRESOURCE As STRING = "%Development:USE";

}
