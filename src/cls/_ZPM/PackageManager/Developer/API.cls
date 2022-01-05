Include (%occInclude, %occErrors, %ZPM.PackageManager.Common)

Class %ZPM.PackageManager.Developer.API
{

ClassMethod ExportDocumentForObject(pSourceModule As %ZPM.PackageManager.Developer.Module, Output pSourceControlOutput) As %Status
{
	Set tSC = $$$OK
	Set tCookie = ""
	Try {
		New %SourceControl
		
		Do ##class(%ZPM.PackageManager.Developer.Utils).BeginCaptureOutput(.tCookie)
		
		Do ##class(%Studio.SourceControl.Interface).SourceControlCreate()
		
		Set tDocName = pSourceModule.Name_".ZPM"
		
		Set tSC = ##class(%Studio.SourceControl.Interface).GetStatus(tDocName,.tIsInSourceControl,.tIsEditable)
		$$$ThrowOnError(tSC)
		
		If tIsInSourceControl && 'tIsEditable {
			// Try to make the document editable.
			Set tSC = ##class(%ZPM.PackageManager.Developer.Extension.SourceControl.Interface).%OnMakeModuleEditable(pSourceModule)
			$$$ThrowOnError(tSC)
		}
		
		// Did we actually make the document editable?
		Set tSC = ##class(%Studio.SourceControl.Interface).GetStatus(tDocName,,.tIsEditable)
		$$$ThrowOnError(tSC)
		
		// If still not editable, error out.
		If 'tIsEditable {
			$$$ThrowStatus($$$ERROR($$$ItemNotCheckedOut,tDocName))
		}
		
		Set tModuleStream = ##class(%ZPM.PackageManager.Developer.Document.ModuleStream).NameOpen(pSourceModule.Name,,.tSC)
		If $ListFind($ListFromString($System.Status.GetErrorCodes(tSC)),$$$KeyValueNotFoundOpen) {
			// It's possible that only the module exists - we'll skip the merge with the document's content if it does.
			Set tSC = $$$OK
		}
		If $$$ISERR(tSC) {
			Quit
		}
		
		If $IsObject(tModuleStream) {
			// Extract comments from existing document stream
			Set tHandler = ##class(%ZPM.PackageManager.Developer.XML.CommentHandler).%New()
			Set tReader = ##class(%XML.SAX.Parser).%New()
			Set tSC = ##Class(%XML.SAX.Parser).ParseStream(tModuleStream.Contents,tHandler)
			$$$ThrowOnError(tSC)
		}
		
		// Use document API
		#dim tExportStream As %Stream.Object
		Set tSC = pSourceModule.XMLExportToStream(.tExportStream,,"literal,indent")
		If $$$ISERR(tSC) {
			Quit
		}
		
		If $IsObject(tModuleStream) {
			// Reapply comments to exported XML stream
			Set tSC = tHandler.Reapply(.tExportStream)
			$$$ThrowOnError(tSC)
		}
		
		// Save the document.
		Set tRtn = ##class(%Library.RoutineMgr).%OpenId(tDocName)
		If (tRtn = $$$NULLOREF) {
			Set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Module %1 does not exist.",pModuleName))
			Quit
		}
		
		// NOTE: tRtn.Code is a %ZPM.PackageManager.Developer.Document.Module
		Do tRtn.Code.Code.Clear()
		Set tHeader = tExportStream.ReadLine()
		If ($Extract(tHeader,1,2) '= "<?") {
			Do tRtn.Code.Code.WriteLine("<?xml version=""1.0""?>")
		}
		Do tExportStream.Rewind()
		Set tSC = tRtn.Code.Code.CopyFrom(tExportStream)
		If $$$ISERR(tSC) {
			Quit
		}
		
		Set tSC = tRtn.%Save()
		If $$$ISERR(tSC) {
			Quit
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	
	// Ensure I/O redirection ends.
	Do ##class(%ZPM.PackageManager.Developer.Utils).EndCaptureOutput(tCookie,.pSourceControlOutput)
	Quit tSC
}

}
