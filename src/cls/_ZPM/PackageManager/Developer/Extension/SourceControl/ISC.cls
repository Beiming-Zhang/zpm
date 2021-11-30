Include (%ZPM.PackageManager.Common, %occErrors)

Class %ZPM.PackageManager.Developer.Extension.SourceControl.ISC Extends (%Studio.SourceControl.ISC, %ZPM.PackageManager.Developer.Extension.SourceControl.Interface)
{

Parameter SETTINGSPAGE = "%ZPM.PackageManager.Developer.Extension.SourceControl.ISC.UI.cls";

Parameter NOPREFIXCHARCODE = 8;

/// Invoked before each lifecycle phase
ClassMethod OnBeforePhase(pModule As %ZPM.PackageManager.Developer.Module, pPhase As %String, ByRef pParams) As %Status
{
	Quit $Case(pPhase,
		"Reload":..OnBeforeReload(pModule, .pParams),
		"Validate":..OnBeforeValidate(pModule, .pParams),
		:$$$OK)
}

/// Invoked after each lifecycle phase
ClassMethod OnAfterPhase(pModule As %ZPM.PackageManager.Developer.Module, pPhase As %String, ByRef pParams) As %Status
{
	Quit $Case(pPhase,
		"Reload":..OnAfterReload(pModule, .pParams),
		"ExportData":..ExportGlobals(pModule),
		:$$$OK)
}

/// Invoked when the list of resources for a module changes.
ClassMethod OnModifyResources(pModule As %ZPM.PackageManager.Developer.Module) As %Status
{
	Set tSC = $$$OK
	Set tPath = $Select(pModule.DeveloperMode:$Get(^Sources("MODULE",pModule.Name)),1:"")
	If (tPath '= "") {
		Set tSC = ..UpdateMappings(pModule.Name,tPath)
	}
	Quit tSC
}

ClassMethod OnBeforeReload(pModule As %ZPM.PackageManager.Developer.Module, ByRef pParams) As %Status
{
	Set tSC = $$$OK
	Try {
		If ..Disconnected() {
			Quit
		}
		Set tVerbose = ''$Get(pParams("Verbose"))
		Set tModuleRoot = ##class(%File).NormalizeDirectory($Get(pParams("RootDirectory"),pModule.Root))
		If $Get(pParams("DeveloperMode"),pModule.DeveloperMode) {
			// Verify that tModuleRoot is within the configured Perforce workspace's module root.
			Set tSC = ..P4Cmd("client -o",.tOutput)
			$$$ThrowOnError(tSC)
			
			Set tClient = $Get(tOutput(1,"Client"))
			Set tWorkspaceRoot = ##class(%File).NormalizeDirectory($Get(tOutput(1,"Root")))
			If ($Extract(tModuleRoot,1,$Length(tWorkspaceRoot)) '= tWorkspaceRoot) {
				Set tMsg = "Cannot load module '%1' in developer mode from directory %2 because it is outside of the Perforce workspace root (%3) for workspace %4."
				Set tMsg = $$$FormatText(tMsg,pModule.Name,tModuleRoot,tWorkspaceRoot,tClient)
				Set tSC = $$$ERROR($$$GeneralError,tMsg)
				$$$ThrowStatus(tSC)
			}
		}
		If $Get(pParams("Perforce","Sync")) && (..ExtName(pModule.Name_".MODULE") '= "") {
			Set tSC = ..RunCmd("p4 sync "_tModuleRoot_"...#head",.tOutput,tVerbose)
			If $$$ISERR(tSC) && ($System.Status.GetErrorText(tSC)["up-to-date") {
				// Not actually a problem.
				Set tSC = $$$OK
			}
			If tVerbose {
				For i=1:1:$Get(tOutput) {
					Write !,tOutput(i)
				}
			}
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

ClassMethod OnAfterReload(pModule As %ZPM.PackageManager.Developer.Module, ByRef pParams) As %Status
{
	Set tSC = $$$OK
	Try {
		Set tRef = ""
		Set tName = $Select($IsObject(pModule):pModule.Name,1:pModule)
		Set tModuleFileName = ..ExtName(tName_".MODULE")
		If (tModuleFileName '= "") {
			Set ^Sources(0,"FileTimeStamp",tName_".MODULE") = ##class(%Library.File).GetFileDateModified(tModuleFileName,1)
			Set ^Sources(0,"ItemTimeStamp",tName_".MODULE") = ##class(%Library.RoutineMgr).TS(tName_".MODULE")
			Kill ^||ZPMResourceArray
			Merge ^||ZPMResourceArray = ^Sources("MODULE",tName,"r")
			Set tReference = $Query(^||ZPMResourceArray,1,tFileName)
			While (tReference '= "") {
				Set tDocument = $QSubscript(tReference,3)
				If tDocument '= "" {
					Set ^Sources(0,"FileTimeStamp",tDocument) = ##class(%Library.File).GetFileDateModified(tFileName,1)
					Set ^Sources(0,"ItemTimeStamp",tDocument) = ##class(%Library.RoutineMgr).TS(tDocument)
				}
				Set tReference = $Query(@tReference,1,tFileName)
			}
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// Before validation, export all resources that have not been added to source control to their proper location, if any, and mark them for add.
ClassMethod OnBeforeValidate(pModule As %ZPM.PackageManager.Developer.Module, ByRef pParams) As %Status
{
	Set tSC = $$$OK
	Try {
		Set tVerbose = ''$Get(pParams("Verbose"))
		
		// Only do anything if the module is in "Developer Mode"
		If '$Get(pParams("DeveloperMode"),pModule.DeveloperMode) {
			Quit
		}
		
		// See if "auto mark for add" is enabled.
		#dim tSettings As %ZPM.PackageManager.Developer.Extension.SourceControl.ISC.Settings
		Set tSettings = ##class(%ZPM.PackageManager.Developer.Extension.SourceControl.ISC.Settings).%Get(.tSC)
		$$$ThrowOnError(tSC)
		If 'tSettings.AutoAdd || ..Disconnected() {
			Quit
		}
		
		// NOTE: If we got here, %SourceControl will either be an instance of this class or of %ZPM.PackageManager.Developer.Extension.Composite.
		// If the latter, methods of %SourceControl (like Load or AddToSourceControl below) will actually be invoked on an instance of this class
		// via dynamic dispatch.
		#dim %SourceControl As %Studio.SourceControl.ISC
		New %SourceControl
		Set tSC = ##class(%Studio.SourceControl.Interface).SourceControlCreate()
		If $$$ISERR(tSC) {
			Quit
		}
				
		Set tSC = pModule.GetResolvedReferences(.tResolvedArray,,,1)
		If $$$ISERR(tSC) {
			Quit
		}
				
		Set tKey = ""
		For {
			Set tKey = $Order(tResolvedArray(tKey),1,tValue)
			Quit:tKey=""
			If (tValue '= pModule.Name) && (tValue '= "") {
				Continue
			}
			If $Get(tResolvedArray(tKey,"Generated")) || ##class(%Studio.SourceControl.Interface).IsGenerated(tKey) {
				Continue
			}
			
			If ($Piece(tKey,".",*) = "CLS") {
				Set tClassName = $Piece(tKey,".",1,*-1)
				// Skip marking for add if the class definition does not exist.
				If '$$$defClassDefined(tClassName) {
					Continue
				}
				
				// Also skip based on "generated" flag.
				Set tIsGenerated = $$$comClassKeyGet(tClassName,$$$cCLASSgeneratedby)
				If (tIsGenerated '= "") {
					Continue
				}
			}
			
			// Also skip if we can't figure out an external name.
			Set tExternalName = ##class(%Studio.SourceControl.Interface).ExternalName(tKey)
			If (tExternalName = "") {
				Continue
			}
			
			// Or if the external name doesn't pass validation.
			If tSettings.IgnoreFileName(tExternalName) {
				Continue
			}
			
			Set tSC = ##class(%Studio.SourceControl.Interface).GetStatus(tKey,.tIsInSourceControl,.tEditable,.tIsCheckedOut,.tUserCheckedOut,.tReload)
			If $$$ISERR(tSC) {
				Quit
			}
			If 'tEditable {
				Continue
			}
			
			If tReload {
				Set tSC = ..%SourceControlMethod("Load",tKey)
				If $$$ISERR(tSC) {
					Quit
				}
			}
			
			If 'tIsInSourceControl {
				Set tAdd = 1
				
				Set tSC = ..RunCmd("p4 -ztag where "_tExternalName,.tOutput,0)
				If $$$ISERR(tSC) {
					Quit
				}
				
				Set tDepotFile = ""
				For i=1:1:$Get(tOutput) {
					Set tFile = $Piece(tOutput(i),"... depotFile ",2)
					If (tFile '= "") {
						Set tDepotFile = tFile
						Quit
					}
				}
				
				If (tDepotFile '= "") {
					Set tSC = ..RunCmd("p4 -ztag files "_tDepotFile,.tOutput,0)
					If $System.Status.GetErrorText(tSC) [ "no such file(s)" {
						//This is actually good. We should add it.
						Set tSC = $$$OK
					}
					If $$$ISERR(tSC) {
						Quit
					}
				
					For i=1:1:$Get(tOutput) {
						Set tAction = $Piece(tOutput(i),"... action ",2)
						If (tAction '= "") {
							// Do not add if last action was delete or move/delete
							Set tAdd = '(tAction [ "delete")
							Quit
						}
					}
				}
				
				If tAdd {
					Set tSC = ..%SourceControlMethod("AddToSourceControl",tKey)
					$$$ThrowOnError(tSC)
					
					// Rather than overriding all of AddToSourceControl, just issue a p4 reopen to move to a specified changelist
					// Create that changelist and capture its number if needed.
					If '$Data(tAutoAddChangelist) {
						Set tSC = ..CreateChangelist("File(s) automatically marked for add during Validate phase for module "_pModule.Name,.tAutoAddChangelist)
						$$$ThrowOnError(tSC)
					}
					
					Set tSC = ..RunCmd("p4 reopen -c "_tAutoAddChangelist_" "_tExternalName)
					$$$ThrowOnError(tSC)
				}
			}
		}
		If $$$ISERR(tSC) {
			Quit
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

ClassMethod CreateChangelist(pDescription As %String, Output pChangelistNumber As %Integer) As %Status
{
	Set pChangelistNumber = ""
	Set tSC = $$$OK
	Try {
		// Determine current user/workspace
		// Can't use ..GetCredentials() because these may be defined in OS environment variables.
		Set tSC = ..P4Cmd("info",.tOutput)
		$$$ThrowOnError(tSC)
		
		Set tP4User = $Get(tOutput(1,"userName"))
		Set tP4Workspace = $Get(tOutput(1,"clientName"))
		If (tP4Workspace = "") {
			// This should never happen, as far as I can tell. Just to be safe, because the errors that happen if workspace isn't mentioned are very misleading:
			Set tSC = $$$ERROR($$$GeneralError,"p4 info did not report the client workspace. Check your Perforce configuration.")
			$$$ThrowStatus(tSC)
		}
		
		// List existing changelists in workspace, and see if any has the correct description.
		Set tChangelistNumber = ""
		
		Kill tOutput
		Set tSC = ..P4Cmd("changes -c "_tP4Workspace_" -s pending -l",.tOutput)
		$$$ThrowOnError(tSC)
		
		For tChangelistIndex=1:1:$Get(tOutput) {
			If ($Get(tOutput(tChangelistIndex,"desc")) = pDescription) && $Data(tOutput(tChangelistIndex,"change"),tChangelistNumber) {
				Quit
			}
		}
		
		// If no match is found, create a new changelist.
		If (tChangelistNumber = "") {
			Set tTmpStream = ##class(%Stream.FileCharacter).%New()
			Do tTmpStream.WriteLine("Change: new")
			Do tTmpStream.WriteLine("Client: "_tP4Workspace)
			Do tTmpStream.WriteLine("User: "_tP4User)
			Do tTmpStream.WriteLine("Status: new")
			Do tTmpStream.WriteLine("Description: "_pDescription)
			
			Kill tOutput
			Set tSC = ..RunCmd("p4 change -i < "_tTmpStream.Filename,.tOutput)
			$$$ThrowOnError(tSC)
			
			// Only way to get the changelist # is to read tOutput (even with -s / -ztag).
			// Expected format:
			// tOutput(1)="Change 2910941 created."
			Set tChangelistNumber = $Piece($Piece($Get(tOutput(1)),"Change ",2)," created.")
			If (tChangelistNumber '= +tChangelistNumber) {
				Set tMsg = $$$FormatText("Unexpected output from 'p4 change' command: %1",$Get(tOutput(1)))
				$$$ThrowStatus($$$ERROR($$$GeneralError,tMsg))
			}
		}
		
		Set pChangelistNumber = tChangelistNumber
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// After compilation, check out any .GBL resources and re-export.
/// TODO: revert if unchanged.
ClassMethod ExportGlobals(pModule As %ZPM.PackageManager.Developer.Module) As %Status
{
	New %SourceControl
	Set tSC = $$$OK
	Try {
		Set tKey = ""
		For {
			#dim tResource As %ZPM.PackageManager.Developer.ResourceReference
			Set tResource = pModule.Resources.GetNext(.tKey)
			Quit:tKey=""
			
			Set tSC = ##class(%Studio.SourceControl.Interface).SourceControlCreate()
			If $$$ISERR(tSC) {
				Quit
			}
			
			If ($Piece(tResource.Name,".",*) = "GBL") {
				Set tOSFile = ..ExtName(tResource.Name)
				If ##class(%File).ReadOnly(tOSFile) {
					Set tSC = ..%SourceControlMethod("CheckOut",tResource.Name,,0)
					If $$$ISERR(tSC) {
						Quit
					}
				}
				Set tSC = ..%SourceControlMethod("OnAfterSave",tResource.Name)
				If $$$ISERR(tSC) {
					Quit
				}
			}
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// Invoked when an existing module is reloaded from a different directory than its known module root
/// Removes mappings for all of the module's resources (to prevent an automatic p4 move)
ClassMethod OnChangeModuleRoot(pModule As %ZPM.PackageManager.Developer.Module) As %Status
{
	Quit ..RemoveMappings(pModule.Name)
}

/// Utility method to remove all mappings for a named module.
ClassMethod RemoveMappings(pModuleName As %String) As %Status
{
	Set tSC = $$$OK
	Set tInitTLevel = $TLevel
	Try {
		TSTART
		Merge tRemovedMap = ^Sources("MODULE",pModuleName,"r")
		
		Set tTypeKey = ""
		For {
			Set tTypeKey = $Order(tRemovedMap(tTypeKey))
			If (tTypeKey = "") {
				Quit
			}
			Set tNameKey = ""
			For {
				Set tNameKey = $Order(tRemovedMap(tTypeKey,tNameKey),1,tPath)
				If (tNameKey = "") {
					Quit
				}
				
				If tPath = $Get(^Sources(tTypeKey,tNameKey)) {
					Kill ^Sources(tTypeKey,tNameKey)
				}
			}
		}
		
		Kill ^Sources("MODULE",pModuleName)
		TCOMMIT
	} Catch e {
		Set tSC = e.AsStatus()
	}
	While ($TLevel > tInitTLevel) {
		TROLLBACK 1
	}
	Quit tSC
}

/// Utility method to update mappings for a named module, placing the module's root at a given path.
/// Note: <var>pPath</var> is expected to be an absolute path, possibly prefixed with $c(8).
ClassMethod UpdateMappings(pModuleName As %String, pPath As %String) As %Status
{
	Set tSC = $$$OK
	Set tInitTLevel = $TLevel
	Try {
		// This will be an instance of %Studio.SourceControl.ISC or a subclass.
		#dim %SourceControl As %Studio.SourceControl.ISC
		New %SourceControl
		Set tSC = ##class(%Studio.SourceControl.Interface).SourceControlCreate()
		If $$$ISERR(tSC) {
			Quit
		}
		
		Set tModule = ##class(%ZPM.PackageManager.Developer.Module).NameOpen(pModuleName,,.tSC)
		If $$$ISERR(tSC) {
			Quit
		}
		
		If (pPath '= "") {
			Set tEndSlash = $Select($$$isWINDOWS:"\",1:"/")
			If ($Extract(pPath,*) '= tEndSlash) {
				Set pPath = pPath_tEndSlash
			}
			
			Set tAbsPrefix = $c(..#NOPREFIXCHARCODE)
			If ($Extract(pPath) '= tAbsPrefix) {
				Set pPath = tAbsPrefix_pPath
			}
		}
		
		// Update w/ module resources and default naming scheme.
		TSTART
		
		Merge tRemovedMap = ^Sources("MODULE",pModuleName,"r")
		
		Set ^Sources("MODULE","*","NoFolders") = 1
		If (pPath '= "") {
			Set ^Sources("MODULE",pModuleName) = pPath
		} Else {
			Kill ^Sources("MODULE",pModuleName)
		}
		
		// Update module settings
		// Remove "this is an absolute path" prefix.
		Set tModule.Root = $Extract(pPath,2,*)
		Set tModule.DeveloperMode = (pPath '= "")
		// Shallow save to avoid FRAMESTACK (save module -> save resources -> update mappings -> save module...)
		Set tSC = tModule.%Save(0)
		$$$ThrowOnError(tSC)
		
		// Update mappings for all resources in the module.
		Set tKey = ""
		For {
			Set tResource = tModule.Resources.GetNext(.tKey)
			Quit:tKey=""

			Continue:tResource.Generated
			
			If '$IsObject(tResource.Processor) {
				Continue
			}
			
			#dim tInfo As %ZPM.PackageManager.Developer.Extension.SourceControl.ResourceInfo
			Set tSC = tResource.Processor.GetSourceControlInfo(.tInfo)
			$$$ThrowOnError(tSC)
			
			If 'tInfo.SourceControlAware {
				Continue
			}
			
			Set tRelativePath = tInfo.RelativePath
			Set tPrefix = tInfo.Prefix
			If tPrefix = "" {
				Continue
			}
			Set tType = tInfo.ResourceType
			
			Set tMappedPath = tAbsPrefix_$Select(
				tInfo.IsDirectory:##class(%File).NormalizeDirectory($Extract(pPath,2,*)_tRelativePath_"\"),
				1:##class(%File).NormalizeFilename($Extract(pPath,2,*)_tRelativePath))
			
			// Build map of previous locations for all resources subordinate to this one, prior to updating ^Sources.
			Kill tChildResources
			Set tSC = tResource.ResolveChildren(.tChildResources)
			If $$$ISERR(tSC) {
				Quit
			}
			
			Set tChildResource = ""
			For {
				Set tChildResource = $Order(tChildResources(tChildResource))
				If (tChildResource = "") {
					Quit
				}
				
				// Old ExternalName (prior to ^Sources being set)
				Set tOldExternalName = ##class(%Studio.SourceControl.Interface).ExternalName(tChildResource)
				Set tFileSystemMap(tChildResource) = $ListBuild(tOldExternalName)
			}
			
			Set tPresentMap(tType,tPrefix) = tMappedPath
			Kill tRemovedMap(tType,tPrefix)
			Kill ^Sources("MODULE",pModuleName,"r",tType,tPrefix)
			If (pPath '= "") {
				Set ^Sources(tType,tPrefix) = tMappedPath
				Set ^Sources("MODULE",pModuleName,"r",tType,tPrefix) = tMappedPath
			
				Set tChildResource = ""
				For {
					Set tChildResource = $Order(tChildResources(tChildResource))
					If (tChildResource = "") {
						Quit
					}
					
					// New ExternalName (after ^Sources update)
					If $Data(tChildResources(tChildResource,"RelativePath"),tRelativePath) {
						// Shortcut to avoid overhead of calling ExternalName.
						// Also allows resource processor to specify and persist a customized filename for the given resource.
						// This can be used to handle UDL export conventions, etc.
						Set tNewExternalName = ##class(%File).NormalizeFilename(tModule.Root_tRelativePath)
					} Else {
						Set tNewExternalName = ##class(%Studio.SourceControl.Interface).ExternalName(tChildResource)
					}
					Set tFileSystemMap(tChildResource) = tFileSystemMap(tChildResource)_$ListBuild(tNewExternalName)
					Set tPresentMap(tType,tPrefix,tChildResource) = tNewExternalName
				}
			} Else {
				Kill ^Sources(tType,tPrefix)
			}
		}
		If $$$ISERR(tSC) {
			Quit
		}
		
		Kill ^Sources("MODULE",pModuleName,"r")
		Merge ^Sources("MODULE",pModuleName,"r") = tPresentMap
		
		// Update ^Sources to remove values for resources removed from the module.
		Set tTypeKey = ""
		For {
			Set tTypeKey = $Order(tRemovedMap(tTypeKey))
			If (tTypeKey = "") {
				Quit
			}
			Set tNameKey = ""
			For {
				Set tNameKey = $Order(tRemovedMap(tTypeKey,tNameKey),1,tPath)
				If (tNameKey = "") {
					Quit
				}
				
				If tPath = $Get(^Sources(tTypeKey,tNameKey)) {
					Kill ^Sources(tTypeKey,tNameKey)
					Set tChildResourceKey = ""
					For {
						Set tChildResourceKey = $Order(tRemovedMap(tTypeKey,tNameKey,tChildResourceKey),1,tChildResourcePath)
						If (tChildResourceKey = "") {
							Quit
						}
						
						// Old location (under this module's root) for a resource (possibly) no longer in the module.
						Set $List(tFileSystemMap(tChildResourceKey),1) = tChildResourcePath
					}
				}
			}
		}
		
		// Possibly issue p4 move commands for files that were moved from a different module to this one.
		// Also may move files that were removed from this module, resulting in a new home in another.
		#dim tSettings As %ZPM.PackageManager.Developer.Extension.SourceControl.ISC.Settings
		Set tSettings = ##class(%ZPM.PackageManager.Developer.Extension.SourceControl.ISC.Settings).%Get(.tSC)
		$$$ThrowOnError(tSC)
		
		If tSettings.AutoMove && '..Disconnected() {
			Set tResourceKey = ""
			For {
				Set tResourceKey = $Order(tFileSystemMap(tResourceKey),1,tFileNames)
				If (tResourceKey = "") {
					Quit
				}
				
				Set tOldFileName = $ListGet(tFileNames,1)
				Set tNewFileName = $ListGet(tFileNames,2)
				
				If (tNewFileName = "") {
					// Possible implicit move to another module (no longer in ResolveChildren for the updated resource).
					// Could happen due to making a CSP path or package name more specific.
					// So, get its new name.
					Set tNewFileName = ##class(%Studio.SourceControl.Interface).ExternalName(tResourceKey)
				}
				
				If (tOldFileName = tNewFileName) {
					Continue
				}
				
				If tSettings.IgnoreFileName(tOldFileName) || tSettings.IgnoreFileName(tNewFileName) {
					Continue
				}
				
				// File may have moved. See if old file exists in Perforce.
				If (tOldFileName '= "") && (tNewFileName '= "") {
					Set tOldFileName = ##class(%Library.File).NormalizeFilename(tOldFileName)
					Set tNewFileName = ##class(%Library.File).NormalizeFilename(tNewFileName)
					If (tOldFileName = tNewFileName) {
						// In case they now match, after normalization, but did not before.
						Continue
					}
					
					// Now deal with spaces before passing to commands.
					Set tOldFileName = ##class(%Library.File).NormalizeFilenameWithSpaces(tOldFileName)
					Set tNewFileName = ##class(%Library.File).NormalizeFilenameWithSpaces(tNewFileName)
					
					Kill tOutput
					Set tSC = ..P4Cmd("fstat "_tOldFileName,.tOutput)
					
					// If old file doesn't exist, no need to do a p4 move.
					If $$$ISERR(tSC) {
						Set tErrorText =  $System.Status.GetErrorText(tSC)
						If (tErrorText [ "no such file(s)") || (tErrorText [ "file(s) not in client view") {
							Set tSC = $$$OK
							Continue
						}
					}
					$$$ThrowOnError(tSC)
					
					If tOutput {
						// If it is already in the depot and not deleted, then move the file.
						Set tHeadAction = $Get(tOutput(1,"headAction")) // Most recent revision's action.
						Set tAction = $Get(tOutput(1,"action")) // Current action
						// Permit move if headAction is delete and action in workspace is add or move/add
						If (tHeadAction = "") || (tHeadAction '[ "delete") || (tAction [ "add") {
							// If needed, create a changelist for moved files and capture its number.
							If '$Data(tAutoMoveChangelist) {
								Set tSC = ..CreateChangelist("File(s) automatically marked for move to/from "_pModuleName,.tAutoMoveChangelist)
								$$$ThrowOnError(tSC)
							}
							
							If (tAction = "") {
								If (tHeadAction '= "") {
									$$$ThrowOnError(..RunCmd("p4 edit -c "_tAutoMoveChangelist_" "_tOldFileName))
								} Else {
									// File isn't marked for add, and doesn't exist in the depot.
									// Move along.
									Continue
								}
							}
							
							// This might go wrong at the Perforce level, but if it does, just
							// propagate the error that the command returns.
							$$$ThrowOnError(..RunCmd("p4 move -f -c "_tAutoMoveChangelist_" "_tOldFileName_" "_tNewFileName))
							
							// Bypass timestamp checks on export.
							Do ..DelegateExportToProcessor(tNewFileName,tResourceKey,.tSC)
							$$$ThrowOnError(tSC)
						}
					}
				}
			}
			
			If $Data(tAutoMoveChangelist) {
				// Attempt to revert any unchanged files (if we have a changelist containing them)
				// This covers cases where files were accidentally moved and then moved back.
				Set tSC = ..RunCmd("p4 revert -a -c "_tAutoMoveChangelist)
				If ($System.Status.GetErrorText(tSC) [ "File(s) not opened in that changelist") {
					Set tSC = $$$OK
				}
				$$$ThrowOnError(tSC)
				
				// See if the changelist is empty, and delete it if it is.
				// Do not throw errors if deletion fails (e.g., because of shelved files or jobs attached - we shouldn't try to clean that up)
				Kill tOutput
				Set tSC = ..P4Cmd("opened -c "_tAutoMoveChangelist,.tOutput)
				$$$ThrowOnError(tSC)
				If ($Get(tOutput) = 0) {
					// It's empty.
					Do ..RunCmd("p4 change -d "_tAutoMoveChangelist)
				}
			}
		}
		TCOMMIT
	} Catch e {
		Set tSC = e.AsStatus()
	}
	While $TLevel > tInitTLevel { TROLLBACK 1 }
	Quit tSC
}

/// Return the name of this item without the prefix to be added by ExtName
ClassMethod Name(InternalName As %String) As %String
{
	Set tInternalName = ""
	Set InternalName=##class(%Studio.SourceControl.Interface).normalizeName(InternalName)
	If ($zcvt($Piece(InternalName,".",*),"U") = "MODULE") {
		// Get correct case for name.
		Set tModuleName = $Piece(InternalName,".",1,*-1)
		If ##class(%ZPM.PackageManager.Developer.Module).NameExists(tModuleName,.tID) {
			Set tModuleName = ##class(%ZPM.PackageManager.Developer.Module).NameGetStored(tID)
			If $Data(^Sources("MODULE",tModuleName),tPath) {
				Set tInternalName = tPath_"module.xml"
			}
		}
	} Else {
		#dim tModule As %ZPM.PackageManager.Developer.Module
		#dim tResourceReference As %ZPM.PackageManager.Developer.ResourceReference
		Set tIsGenerated = 0
		Set tModule = ##class(%ZPM.PackageManager.Developer.Extension.Utils).FindHomeModule(InternalName,.tResourceName,.tResourceReference)
		If $Extract(InternalName) = "/" {
			Set tExtension = "/CSP/"
			Set tResourceSub = tResourceName
		} Else {
			Set tExtension = $Piece(InternalName,".",*)
			Set tName = $Piece(InternalName,".",1,*-1)
			Set tResourceSub = $Piece(tResourceName,".",1,*-1)_$Case($Piece(tResourceName,".",*),"PKG":".",:"")
			If (tExtension = "CLS") && ($$$defClassKeyGet(tName,$$$cCLASSgeneratedby) '= "") {
				Set tIsGenerated = 1
			}
		}
		If tIsGenerated {
			// Intentional no-op. tInternalName will be empty.
			Quit ""
		} ElseIf $IsObject(tModule) && $Data(^Sources("MODULE",tModule.Name,"r",tExtension,tResourceSub,InternalName),tInternalName) && (tInternalName '= "") {
			// Use the package manager's cache.
			// Absolute path; prepend to indicate that.
			Set tInternalName = $c(..#NOPREFIXCHARCODE)_tInternalName
		} ElseIf $IsObject($Get(tResourceReference)) && $IsObject(tResourceReference.Processor) {
			Set tRelativePath = tResourceReference.Processor.OnItemRelativePath(InternalName)
			If (tRelativePath '= "") {
				Set tInternalName = $c(..#NOPREFIXCHARCODE)_##class(%Library.File).NormalizeFilename(tModule.Root_tRelativePath)
			}
		}
		
		If (tInternalName = "") {	
			// If we can't get there with the package manager alone, fall back to standard Studio source control behavior (looking at ^Sources)
			// Some default behavior of %Studio.SourceControl.ISC is updated for correctness.
			Set tInternalName = ##super(InternalName)
			If (tInternalName '= "") {
				If ($Extract(InternalName) = "/") {
					// Handle CSP here.
					// This is largely copied from %Studio.SourceControl.ISC, with minor changes for readability.
					// Note: no special handling for CSP application physical path = ^Sources (since the top-level node will not be defined).
					Set tMapping = $order(^Sources(tExtension,InternalName))
					For {
						Set tMapping = $order(^Sources(tExtension,tMapping),-1)
						Quit:(tMapping="")
						If ($Extract(InternalName,1,$length(tMapping)) = tMapping) && $Data(^Sources(tExtension,tMapping),tFoundMapping) {
							Quit
						}
					}
					If '$Data(tFoundMapping) {
						Set tInternalName = ""
					} Else {
						// If no specific mapping was specified (p=""), then return the whole csp filename; otherwise return the name without the mapped piece
						Set InternalName = $Extract(InternalName,$Length(tMapping)+1,*)
						Set tInternalName = $Translate(tFoundMapping_$Translate(InternalName,"%","_"),"\","/")
					}
				} ElseIf (tExtension = "INC") {
					// Replace . with / in the filename.
					Set tStart = $Piece(tInternalName,"inc/")
					Set tEnd = $Piece(tInternalName,"inc/",2)
					Set $Piece(tEnd,".",1,*-1) = $Translate($Piece(tEnd,".",1,*-1),".","/")
					Set tInternalName = tStart_"inc/"_tEnd
				} ElseIf (tExtension = "CLS") {
					// Correct standard behavior: If <package>.<class> is mapped, don't automatically apply the same
					// mapping to <package>.<class>extrastuff.
					Set tPrefix = ""
					Set tUseFolders = '$Get(^Sources(tExtension,"*","NoFolders"),0)
					If $Data(^Sources(tExtension,tName),tPrefix) {
						// If individual file is mapped, just use that as the prefix
					} Else {
						For tPackageLength = ($Length(tName,".")-1):-1:1 {
							Set tPackage = $Piece(tName,".",1,tPackageLength)_"."
							If $Data(^Sources(tExtension,tPackage),tPrefix) {
								Quit
							}
						}
					}
					If (tPrefix = "") {
						Set tInternalName = ""
					} Else {
						Set tIdentifier = $Select(tUseFolders:".",1:"")_"%"
						Set tAssociator = $Select(tUseFolders:"/",1:"")
						Set nam = $Translate(tName,tIdentifier,tAssociator)
						#; If match ends in '`' character use UDL/CLS format rather than XML format
						Set tUDL = ("`"=$Extract(tPrefix,*))
						Set:tUDL tPrefix  = $Extract(tPrefix,1,*-1)
						Set tInternalName = $Translate(tPrefix_nam_$Select(tUDL:".cls",1:".xml"),"\","/")
					}
				}
			}
		}
	}
	Quit tInternalName
}

/// Return filename of this item
/// Override superclass method to honor new convention:
/// if name starts with special characters defined in ..#NOPREFIXCHARCODE, then don't use the prefix path in ^Sources
ClassMethod ExtName(InternalName As %String) As %String
{
	Set tName = ..Name(InternalName)
	
	// If tName is empty, return the empty string.
	// If it is an absolute path (first character is ..#NOPREFIXCHARCODE), we expect that the name has already been normalized.
	// This is oddly expensive, and the normalized value is maintained in an index, so it's a useful optimization.
	// If it is not absolute, then we do need to normalize the filename.
	Set tName = $Case($Extract(tName),"":"",
		$Char(..#NOPREFIXCHARCODE):$Extract(tName,2,*),
		:$$$FileNormalizeFilename(^Sources_tName))
	
	// Force .xml extension (rather than .rtn) for .GBL
	// Support subscripts
	If ($Piece(InternalName,".",*) = "GBL") {
		Set tDirectory = ##class(%File).GetDirectory(tName)
		Set tName = tDirectory_$tr($Piece(InternalName,".",1,*-1),"%,("")","___")_".xml"
	}
	
	Quit tName
}

Method UndoCheckout(InternalName As %String) As %Status
{
	Set tSC = $$$OK
	Try {
		If $Piece(InternalName,".",*) = "MODULE" {
			// For modules: on "undo add" of a module, remove all mappings for the module and its resources.
			Set tFileName = ..ExternalName(InternalName)
			If tFileName = "" {
				Quit
			}
			Set tSC = ##class(%Studio.SourceControl.Change).GetUncommitted(tFileName,.tAction)
			$$$ThrowOnError(tSC)
			
			Set tSC = ##super(InternalName)
			$$$ThrowOnError(tSC)
			
			If ($Get(tAction) = "add") {
				Set tSC = ..RemoveMappings($Piece(InternalName,".",1,*-1))
				$$$ThrowOnError(tSC)
			}
		} Else {
			Set tSC = ##super(InternalName)
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// Called to delete this item from source control
Method RemoveFromSourceControl(InternalName As %String, Description As %String = "") As %Status
{
	Set tSC = $$$OK
	Try {
		Set tFileName = ..ExternalName(InternalName)
		If ($Extract(InternalName) = "/") && '##class(%File).Exists(tFileName) {
			// %Studio.SourceControl.ISC:RemoveFromSourceControl bails immediately if the file in question
			// does not exist. CSP resources are deleted before we get to this point, so the inherited
			// version of this method fails to mark them for delete. (Prodlog 108044)
			// Rather than overriding that whole method (which is kind of messy), it's simplest to create
			// a new file with the correct filename.
			// This file will be deleted in the call to ##super(), and proper p4 commands issued.
			// Taking this approach should be forward-compatible for if/when %Studio.SourceControl.ISC is fixed.
			Set tFileStream = ##class(%Stream.FileCharacter).%New()
			$$$ThrowOnError(tFileStream.LinkToFile(tFileName))
			$$$ThrowOnError(tFileStream.Write("Temporary file for removal from Perforce"))
			$$$ThrowOnError(tFileStream.%Save())
			$$$ThrowOnError(##class(%ZPM.PackageManager.Developer.File).SetReadOnly(tFileName,1))
		}
		Set tSC = ##super(InternalName, Description)
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// Invoked after zpm "init" to configure settings for this source control class
ClassMethod Configure() As %Status
{
	// Much of this has been taken from %buildccr.mac, and hasn't been modified too much.
	// Some READs have been switched to use %Prompt
	
	// Ensure that some part of ^Sources is set up, as a baseline, to avoid errors and error messages.
	If $Data(^Sources)<11 {
		Set ^Sources = $Get(^Sources)
		Set ^Sources("DUMMY","*") = ""
	}
	
 	//Auto-Sync at Checkout
	Set prompt="Always sync the head revision of a file prior to check-out?"
	Set ans=''$get(^SYS("SourceControl","Misc","AutoSync"))	// make sure it's there is a default (0), even if the global isn't set 
	Kill help
	Set help(1)="When Studio checks out a file, if this setting is 'Yes' then the head revision"
	Set help(2)="of the file will be synced prior to the p4 edit command being issued."
	Set ret=##class(%Prompt).GetYesNo(prompt, .ans, .help)
	Set ^SYS("SourceControl","Misc","AutoSync")=ans
	
	//Provide option to treat mapped items as Read-Only
 	Set ans=$Get(^SYS("SourceControl","Misc","LockMapped"),0)
 	Set prompt="Treat items mapped from other databases as ReadOnly in Studio?"
	Set ret=##class(%Prompt).GetYesNo(prompt, .ans)
 	If ans {	
 		Set ^SYS("SourceControl","Misc","LockMapped")=1
 		Write !,"   In Studio, any item found to mapped from a database other than the default",!
 		Write "   routine database will be treated as ReadOnly and cannot be edited.",!
 	} Else {
	 	Write !
 		Set ^SYS("SourceControl","Misc","LockMapped")=0
 	}
 	
 	// Update Source Control Credentials prompt
	Set ret = ..GetCredentials(.oldUsername)
	If ret&&(oldUsername'="") {
		Write "Development mode is currently: "_$S(..GetSharedWorkspace():"Multi-User",1:"Single-User"),!	
		Write "You are currently configured to use Perforce username '"_oldUsername_"'"
		Set ans=0
		Set prompt="Do you want to change these settings?"
	}
	Else {
		Write "You must initialize your Perforce Credentials for Perforce commands",!
		Write "to work properly, since this system is to connect directly to Perforce."
		Set ans=1
		Set prompt="Would you like to do this now?"
	}
	Set ret=##class(%Prompt).GetYesNo(prompt, .ans)
	If ans {
		Write !
		if ($System.Security.Check("%DB_IRISSYS","Write")) {
			Set prompt="Will more than one person be developing in this instance?"
			Set multi = ..GetSharedWorkspace(.oldSharedWorkspace,.oldDir)	// 1 if Shared Workspace is defined, 0 otherwise
			Kill help
			Set help(1)="This is an instance-wide setting."
			Set help(2)="Only answer 'Yes' if this is a private instance, as Perforce credentials will"
			Set help(3)="be in clear text."
			Set ret=##class(%Prompt).GetYesNo(prompt, .multi, .help)
			If (multi) {
				Write !,"Clearing out any existing single developer credentials...",!
				Do ..SetCredentials()
				Set prompt="What is the Shared Perforce Workspace (e.g. 'SHARED_machineName')? "
				Set workspace=oldSharedWorkspace 
				Kill help
				Set help(1)="This Studio extension must make direct calls to the Perforce server via p4."
				Set help(2)="In order for this to work, a Perforce Workspace must be defined for use."
				Set help(3)="Enter the name of the Perforce Workspace which should be used in the p4 calls."
				Set ret=##class(%Prompt).GetString(prompt, .workspace, 3, 128, .help)
				
				Set prompt="Should this workspace be used for all Namespaces in this instance?"
				Set instanceWide=1
				Kill help
				Set help(1)="The standard source control configuration will use one Perforce workspace"
				Set help(2)="for all namespaces on the instance.  In certain situations, it may be better"
				Set help(3)="to tie a namespace to its own Perforce workspace.  Only answer 'No' to this"
				Set help(4)="question if you are certain that you need the more complex configuration."
				Set ret=##class(%Prompt).GetYesNo(prompt, .instanceWide, .help)
				Set namespace=$select(instanceWide:"",1:$namespace)
				
				Set prompt="Do you want to use a Perforce Alt Directory?"
				Set useAlt=(oldDir'="")
				Kill help
				Set help(1)="A Perforce Alt Directory is used with the p4 -d flag and is typically used"
				Set help(2)="when a Workspace must be access from different machines which access the"
				Set help(3)="workspace file system via different paths (e.g. UNIX vs Windows client)."
				Set help(4)="Normally, an Alt Directory is not necessary."
				Set ret=##class(%Prompt).GetYesNo(prompt, .useAlt, .help)
				If (useAlt) {
					Set prompt="What is your Perforce Alt Directory?"
					Set dir=oldDir
					Kill help
					Set help(1)="Enter the path of your Perforce Alt Directory.  This should also be defined"
					Set help(2)="within your Perforce workspace definition as an 'alt root'."
					Set ret=##class(%Prompt).GetString(prompt, .dir, 3, 256, .help)
				} Else {
					Set dir=""	
				} 
				Do ..SetSharedWorkspace(workspace,dir,namespace)
				
				Set prompt="What is the Perforce Username for instance user '"_$USERNAME_"'?"
				Set username=oldUsername
				Kill help
				Set help(1)="Enter the username as defined on the Perforce server."
				Set ret=##class(%Prompt).GetString(prompt, .username, 2, 32, .help)
				Do ..SetCredentials($listbuild($USERNAME,username))
				
				// Only prompt for password if GeneratePerforceTicket is defined (2016.2.0+, BFS261)
				If $$$comMemberDefined("%Studio.SourceControl.ISC",$$$cCLASSmethod,"GeneratePerforceTicket") {
					Set prompt="What is the Perforce Password for '"_username_"'?"
					Kill help, password
					Set help(1)="Enter the password as defined on the Perforce server."
					Set help(2)="This will not be persisted, but will only be used to create a P4 Ticket."
					Use $p:(:"+S")
					Set ret=##class(%Prompt).GetString(prompt, .password, 2, 32, .help)
					Use $p:(:"-S")
					Set sc=$classmethod($classname(),"GeneratePerforceTicket",password)
					While $$$ISERR(sc) {
						Write !,"Error creating Perforce Ticket: "_$system.Status.GetErrorText(sc)
						Kill password
						Use $p:(:"+S")
						Set ret=##class(%Prompt).GetString(prompt, .password, 2, 32, .help)
						Use $p:(:"-S")
						Set sc=$classmethod($classname(),"GeneratePerforceTicket",password)
					}
					Write !,"Perforce ticket for "_username_" created successfully"
				}
			} Else {
				Do ..SetSharedWorkspace()
				Do ..SetCredentials($listbuild($USERNAME,""))
				Do ..GetCredentials(.oldUsername,.oldPassword,.oldWorkspace,.oldDir,.oldPort)
				Write !,"Please enter the following:"
				Set prompt="Perforce Username?"
				Set username=oldUsername
				Kill help
				Set help(1)="Enter the username as defined on the Perforce server."
				Set ret=##class(%Prompt).GetString(prompt, .username, 2, 32, .help)
				Set prompt="Perforce Password?"
				Set (password,default)=$tr($j("",$l(oldPassword))," ","*")
				Kill help
				Set help(1)="Enter the password for this user."
				Use $p:(:"+S")
				Set ret=##class(%Prompt).GetString(prompt, .password, 2, 32, .help)
				Use $p:(:"-S")
				If (password = default) {
					Write !,"Password unchanged."
					Set password = oldPassword
				}
				Set prompt="Perforce Workspace (e.g. 'perforceUsername_machineName')?"
				Set workspace=oldWorkspace
				Kill help
				Set help(1)="The Perforce Workspace name as defined on the Perforce server."
				Set ret=##class(%Prompt).GetString(prompt, .workspace, 2, 128, .help)
				Set prompt="Perforce Hostname and Port (e.g. 'perforce:1666')?"
				Set port=oldPort
				Kill help
				Set help(1)="The Perforce hostname and port."
				Set ret=##class(%Prompt).GetString(prompt, .port, 2, 128, .help)
				Set prompt="Do you want to use a Perforce Alt Directory?"
				Set useAlt=(oldDir'="")
				Kill help
				Set help(1)="A Perforce Alt Directory is used with the p4 -d flag and is typically used"
				Set help(2)="when a Workspace must be access from different machines which access the"
				Set help(3)="workspace file system via different paths (e.g. UNIX vs Windows client)."
				Set help(4)="Normally, an Alt Directory is not necessary."
				Set ret=##class(%Prompt).GetYesNo(prompt, .useAlt, .help)
				If (useAlt) {
					Set prompt="What is your Perforce Alt Directory?"
					Set dir=oldDir
					Kill help
					Set help(1)="Enter the path of your Perforce Alt Directory.  This should also be defined"
					Set help(2)="within your Perforce workspace definition as an 'alt root'."
					Set ret=##class(%Prompt).GetString(prompt, .dir, 3, 256, .help)
				} Else {
					Set dir=""	
				} 
				Do ..SetCredentials(username,password,workspace,dir,port)
			}
		} Else {
			Write "ERROR:  You do not have sufficient rights to write to ^%SYS. Please",!
			Write "   have someone else with sufficient rights set your Perforce credentials",!
			Write "   on your behalf Studio Hooks to work with Perforce ",!
			Write "Unable to configure Perforce credentials",!
		}
	}
 	
	Quit $$$OK
}

Method OnAfterSave(InternalName As %String, Object As %RegisteredObject) As %Status
{
	Set tFileName = ..ExternalName(InternalName)
	If tFileName = "" {
		Quit $$$OK
	}
	
	Set tName = $Piece(InternalName,".",1,*-1)
	Set tExt = $ZConvert($Piece(InternalName,".",*),"U")
	
	// Special handling for projects to ensure that newly-added items don't show up at the bottom of the XML export.
 	// This tends to cause meaningless diffs (at best) and perforce conflicts (at worst)
	Set tSC = $$$OK
 	If (tExt = "PRJ") {
	 	Set tSC = ..OnAfterSaveProject(tName)
 	}
	Quit $$$ADDSC(tSC,..ExportAfterSave(.InternalName,.Object))
}

Method OnAfterSaveProject(pProjectName As %String) As %Status [ Internal, Private ]
{
	Set tSC = $$$OK
	Try {
		Set tProject = ##class(%Studio.Project).%OpenId(pProjectName,,.tSC)
		$$$ThrowOnError(tSC)
		// Save the project for real (we'll be in %OnAfterSave for the project when this happens,
		// but %Studio.SourceControl.Interface protects against <FRAMESTACK> by moving %SourceControl
		// to tmp, so this should be perfectly fine).
		// If the project is not saved, the items will be in the wrong order.
		$$$ThrowOnError(tProject.%Save())
		
		// Reload the project. We need to save first to be sure all ProjectItem changes are committed.
		// This will load them up freshly, in the normal order.
		$$$ThrowOnError(tProject.%Reload())
		
		// Clear a few properties, since /diffexport won't be respected.
		// This won't actually be saved, but these things shouldn't be in the export to disk.
		Set tProject.LastModified = ""
		Set tProject.Target = ""
		Set tProject.TargetType = ""
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

ClassMethod DelegateExportToProcessor(pFileName As %String, pInternalName As %String, Output pSC As %Status = {$$$OK}) As %Boolean
{
	Set tDelegated = 0
	Try {
		// This method throws exceptions.
		#dim tResourceReference As %ZPM.PackageManager.Developer.ResourceReference
		Do ##class(%ZPM.PackageManager.Developer.Extension.Utils).FindHomeModule(pInternalName,,.tResourceReference)
		If $IsObject(tResourceReference) && $IsObject(tResourceReference.Processor) {
			Set tSC = tResourceReference.Processor.OnExportItem(pFileName,pInternalName,,,.tDelegated)
			$$$ThrowOnError(tSC)
		}
	} Catch e {
		Set tDelegated = 1 // Ensure unexpected error conditions are reported.
		Set pSC = e.AsStatus()
	}
	Quit tDelegated
}

/// Copied from %Studio.SourceControl.ISC:OnAfterSave and modified to call resource export handling.
/// Code has not been updated from parent class implementation to facilitate merge/inclusion of future changes that occur there.
Method ExportAfterSave(InternalName As %String, Object As %RegisteredObject) As %Status [ Internal, Private ]
{
	#; the Tools -> Import and Tools -> Export GUIs do not always return InternalName of a csp file with a leading '/'; it must be added for other code to work
	If (InternalName["/")&&($E(InternalName)'="/") Set InternalName="/"_InternalName

	Set haschange=$system.CLS.IsMthd("%Studio.SourceControl.Change","IsUncommitted")
	Set filename=..ExternalName(InternalName)
	#; File not mapped so nothing to do
	If filename="" Quit $$$OK
	Set name=$Piece(InternalName,".",1,*-1)
	Set ext=$ZConvert($Piece(InternalName,".",*),"U")
	#; Do not export the default projects
	If ext="PRJ",$zconvert($extract(name,1,$length("default_")),"l")="default_" Quit $$$OK
	#; By convention items starting with Z,z,%z,%Z are not exported
	If ext'="PRJ",'##class(%File).Exists(filename) Write !,"File ",filename," not found, skipping export" Quit $$$OK

	If ($get(^SYS("SourceControl","Misc","InsertSrcVer")))&&(ext="CLS") {
		Set cnt=0
		&SQL(SELECT Count(id) INTO :cnt FROM %Dictionary.ParameterDefinition WHERE parent = :name AND Name='SrcVer')
		If ('(SQLCODE < 0))&&(cnt=0) {
			Write !,"Inserting SrcVer parameter into "_InternalName
			Set p=##class(%Dictionary.ParameterDefinition).%New()
			Set p.Name="SrcVer" 
			Do p.parentSetObjectId(name) 
			Set p.Default = "$"_"Id"_"$"	; separate out the string to keep Perforce RCS replacement from happening on this line
			Set p.Description = "Location and Revision of this file in Perforce (Auto-updating)"
			Set sc = p.%Save()
			If $IsObject($Get(%SourceControl)),$Get(%SourceControl.Modified) {
				Set %SourceControl.Modified(InternalName)=1
			}
			If $$$ISERR(sc) { Write !,"Error inserting SrcVer Parameter - "_$system.Status.GetErrorText(sc) }
		}
	}

	If haschange,##class(%Studio.SourceControl.Change).IsUncommitted(filename) {
		Set sc=##class(%Studio.SourceControl.Change).GetUncommitted(filename,.tAction,.tInternalName,.UncommittedUser,.tSource,.UncommittedLastUpdated)
		If ($USERNAME=UncommittedUser) {
			#; update performed by file owner; update the timestamp in the Change table
			Set sc=##class(%Studio.SourceControl.Change).UpdateUncommitted(filename,,,$USERNAME)	
		} Else {
			#; most likely, OnAfterSave() called by OnAfterCompile, which was triggered by a non-owner of the file
		}
		If $$$ISERR(sc) { Write !,$system.Status.GetErrorText(sc) }
	} 

	#; If time already matches and this is not a newly created file (no TimeStamp), then there is nothing to do
	If haschange,##class(%RoutineMgr).TS(InternalName)=$get(^Sources(0,"ItemTimeStamp",InternalName)),$get(^Sources(0,"ItemTimeStamp",InternalName))'="" Quit $$$OK 
	If ..ReadOnly(filename) Write !,"File ",filename," is read only, not exporting" Quit $$$OK
	
	// BEGIN modifications to parent implementation:
	If ..DelegateExportToProcessor(filename, InternalName, .sc) {
		// If the export has been handled, no further work needed.
	} ElseIf name["/" {
	// END modifications to parent implementation.
		#; we copy out CSP files
		Set sc = ..ExportCSPFile(InternalName)
	} ElseIf ext="CLS"||(ext="PRJ")||($ZConvert($Extract(filename,*-2,*),"l")="xml")||(##class(%RoutineMgr).UserType(InternalName)) {
		If '##class(%File).Exists(filename) Do ##class(%File).CreateDirectoryChain(##class(%File).GetDirectory(filename))
		Set qspec = $g(^SYS("SourceControl","Misc","ExportFlags"),"/diffexport")
		If $ZConvert($Extract(filename,*-2,*),"l")="cls" {
			Set sc=$$ExportUDL^%apiOBJ(InternalName,filename,"-d "_qspec)
		} Else {
			Set sc=$$Export^%occXMLExport(filename,"-d "_qspec,InternalName)
		}
	} Else {
		If $get(^SYS("SourceControl","Misc","RtnExportUTF8"),1) {
			Set parms="WNSK\UTF8\"
		} Else {
			Kill parms	; make variable undefined to force default behavior
		}
		If $Data(^Sources(ext,name),found) {
			// If individual file is mapped, just use that as the prefix
			Set tPackage = name
		} Else {
			For tPackageLength = ($Length(name,".")-1):-1:1 {
				Set tPackage = $Piece(name,".",1,tPackageLength)_"."
				If $Data(^Sources(ext,tPackage),found) {
					Quit
				}
			}
		}
		If "`"=$Extract($Get(found),*) {
			Set sc=$$ExportUDL^%apiOBJ(InternalName,filename,"-d /diffexport",,$Piece($Get(parms),"\",2))
		} Else {
			Set sc=$$Export^%apiRTN(InternalName,filename,"Save for Source Control",.parms,"-d /diffexport")
		}
	}
	If $$$ISOK(sc) {
		Write !,"Exported '",InternalName,"' to file '",filename,"'"
		Set ^Sources(0,"FileTimeStamp",InternalName)=$$$FileDateModifiedUTC(filename,1)
		Set ^Sources(0,"ItemTimeStamp",InternalName)=##class(%RoutineMgr).TS(InternalName)
	} Else {
		Do DecomposeStatus^%apiOBJ(sc,,"d")
		Quit sc
	}
	Quit $$$OK
}

Method UserAction(Type As %Integer, Name As %String, InternalName As %String, SelectedText As %String, ByRef Action As %String, ByRef Target As %String, ByRef Msg As %String, ByRef Reload As %Boolean) As %Status
{
	Set tSC = $$$OK
	Try {
		Set Action=0,Target="",Msg="",Reload=0
		Set tExtension = $Piece(InternalName,".",*)
		Set tIsModule = (tExtension = "MODULE")
		Set tIsAdd = ((Type = 1) && (Name = 1)) || ((Type = 0) && (Name [ "%AddToSourceControl"))
		If tIsAdd && tIsModule {
			// Do not show "Add" dialog if already mapped
			// Example: user clicked "add to source control" for a module that had not been saved for the first time.
			// Saving triggers Type = 1, Name = 1, then the "add to source control" menu item is processed.
			// Checking ..Name makes the second event a no-op.
			If (..Name(InternalName) = "") {
				// Show CSP prompt for mapping of new .MODULE item and/or possibly Perforce password, if no ticket is defined
				Set Action = 2
				Set Target = "/isc/studio/templates/%25ZPM.PackageManager.Developer.Extension.SourceControl.ISC.MapModule.cls?$NAMESPACE="_$Namespace_"&InternalName="_InternalName
			}
		} Else {
			If (tIsAdd) {
				// First, see if the item is in a module, or if it isn't in a module and should be (based on "classpath" convention).
				Set tSC = ##class(%ZPM.PackageManager.Developer.ResourceReference).GetStatus(InternalName,.tReferenced,.tEditable,.tSourceModuleName)
				If $$$ISERR(tSC) { Quit }
				
				If 'tEditable {
					Set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Cannot add resource '%1' to locked module '%2'",InternalName,tSourceModuleName))
					Quit
				}
				
				If 'tReferenced {
					Set tModule = ##class(%ZPM.PackageManager.Developer.Extension.Utils).FindHomeModule(InternalName,.tResourceName)
					
					If (tModule = $$$NULLOREF) {
						If (..ExtName(InternalName) = "") {
							// This is an error (or will cause one later), not a warning.
							Write "Cannot add '"_InternalName_"' to source control - it is not part of any module, and no default mapping for '"_tExtension_"' documents exists."
							Quit
						} Else {
							// Warn the user. (If, for example, there's a default "CLS" mapping.)
							Write "WARNING: ",InternalName," is not defined as part of any module."
						}
					} Else {
						Set tResourceReference = ##class(%ZPM.PackageManager.Developer.ResourceReference).%New()
						Set tResourceReference.Name = tResourceName
						Do tModule.Resources.Insert(tResourceReference)
						
						// This might return an error if the module is not checked out and a new thing might be added, which is fine/correct.
						// The resource needs to be in the module manifest.
						Set tSC = ##class(%ZPM.PackageManager.Developer.API).ExportDocumentForObject(tModule,.tSourceControlOutput)
						If $$$ISERR(tSC) {
							Quit
						}
					}
				}
				// Then just go on and do the usual thing.
			}
			Set tSC = ##super(.Type,.Name,.InternalName,.SelectedText,.Action,.Target,.Msg,.Reload)
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

Method AfterUserAction(Type As %Integer, Name As %String, InternalName As %String, Answer As %Integer, Msg As %String = "", ByRef Reload As %Boolean) As %Status
{
	Set tSC = $$$OK
	Try {
		Set Reload=0
		Set tIsModule = ($Piece(InternalName,".",*) = "MODULE")
		Set tIsAdd = ((Type = 1) && (Name = 1)) || ((Type = 0) && (Name [ "%AddToSourceControl"))
		If tIsAdd && tIsModule && (..Name(InternalName) = "") {
			// no-op (already added)
		} Else {
			Set tSC = ##super(.Type,.Name,.InternalName,.Answer,.Msg,.Reload)
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

Method OnMenuItem(MenuName As %String, InternalName As %String, SelectedText As %String, ByRef Enabled As %Boolean, ByRef DisplayName As %String) As %Status
{
	// Overridden behavior: Allow add of unmapped modules to source control, since we'll show a popup prompting for the mapping.
	Set tSC = $$$OK
	Try {
		Set tMenu = $Piece(MenuName,",")
		Set tName = $Piece(MenuName,",",2)
		If (tMenu '= "%SourceMenu") && (tMenu '= "%SourceContext") {
			Quit
		}
		
		If (InternalName '= "") {
			Set tSC = ..GetStatus(InternalName,.tInSourceControl,.tEditable,.tCheckedOut)
			If $$$ISERR(tSC) {
				Quit
			}
		}
		
		Set tInSourceControl = +$get(tInSourceControl)
		Set tEditable = +$get(tEditable)
		Set tCheckedOut = +$get(tCheckedOut)
		Set tIsModule = $Case($Piece(InternalName,".",*),"MODULE":1,:0)
		If (tName = "%AddToSourceControl") {
			If ('tEditable)&&(tCheckedOut) {
				Set Enabled = 0	; InternalName is checked out by a different user
			}
			If tInSourceControl || (InternalName="") {
				Set Enabled = 0
			}
			If (..Name(InternalName) = "") && 'tIsModule {
				Set tModule = ##class(%ZPM.PackageManager.Developer.Extension.Utils).FindHomeModule(InternalName)
				If (tModule = $$$NULLOREF) {
					Set Enabled = 0
				}
			}
			If (InternalName = "") {
				Set Enabled = 0
			}
			If ..Locked() {
				Set Enabled = 0
			}
			If ($get(^SYS("SourceControl","Misc","LockMapped")))&&(..IsMapped(InternalName)) {
				Set Enabled = 0
			}
		} Else {
			Set tSC = ##super(MenuName,InternalName,SelectedText,.Enabled,.DisplayName)
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// Gets the latest revision of all files within filesystem-based repositories that fall within the current namespace's Perforce workspace.
ClassMethod SyncFilesystemRepositories(pVerbose As %Boolean = 1) As %Status
{
	Set tSC = $$$OK
	Try {
		Set tRes = ##class(%SQL.Statement).%ExecDirect(,
			"select Name,Root from %ZPM_PackageManager_Client.FilesystemServerDefinition " _
			"where Enabled = 1")
		If (tRes.%SQLCODE < 0) {
			Throw ##class(%Exception.SQL).CreateFromSQLCODE(tRes.%SQLCODE,tRes.%Message)
		}
		While tRes.%Next(.tSC) {
			$$$ThrowOnError(tSC)
			Set tRoot = tRes.%Get("Root")
			Set tName = tRes.%Get("Name")
			
			Set tDirectory = ##class(%File).NormalizeDirectory(tRoot)
			If ##class(%File).DirectoryExists(tDirectory) {
				Set tDirectory = tDirectory _ "..."
			
				// See if root is in current Perforce workspace - there will be an error if not.
				Set tSC = ..RunCmd("p4 where " _ tDirectory,,0)
				If $$$ISOK(tSC) {
					Kill tOutput
					Set tSC = ..RunCmd("p4 sync " _ tDirectory,.tOutput)
					If $$$ISERR(tSC) && ($System.Status.GetErrorText(tSC) '[ "file(s) up-to-date") {
						$$$ThrowStatus(tSC)
					}
					
					Set tRepositoryDef = ##class(%ZPM.PackageManager.Client.FilesystemServerDefinition).ServerDefinitionKeyOpen(tName,,.tSC)
					$$$ThrowOnError(tSC)
					
					If pVerbose {
						Write !,"Rebuilding module cache for repository '",tName,"'"
					}
					$$$ThrowOnError(tRepositoryDef.BuildCache(1,pVerbose))
				} ElseIf ($System.Status.GetErrorText(tSC) [ "not under client's root") {
					If pVerbose {
						Write !,"Skipping repository outside Perforce root: ",tName
					}
				} Else {
					$$$ThrowStatus(tSC)
				}
				If pVerbose {
					Write !
				}
			}
		}
		$$$ThrowOnError(tSC)
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// Invoked when the user has attempted to edit a module document reported by the active Studio extension as read-only (i.e., because it is not checked out)
ClassMethod OnMakeModuleEditable(pModule As %ZPM.PackageManager.Developer.Module) As %Status
{
	Set tSC = $$$OK
	Try {
		New %SourceControl
		Set tSC = ##class(%Studio.SourceControl.Interface).SourceControlCreate()
		If $$$ISERR(tSC) {
			Quit
		}
		
		Set tSC = ..%SourceControlMethod("CheckOut",pModule.Name_".MODULE")
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// Returns value that shows whether or not this instance is "Disconnected" from Perforce
/// <p>Return values are:
/// <ul>
/// <li> 0: Instance is Connected</li>
/// <li> 1: Instance is Disconnected but could connect at a future time</li>
/// <li> 2: Instance is Permanently Disconnected (no plans of ever connecting to Perforce) </li> 
/// </ul>
ClassMethod Disconnected() As %Integer
{
	// If we are in programmer mode (i.e., Terminal) or a worker process, check for Perforce availability so we can fail back seamlessly.
	// (There's no "Source Control - Disconnect from Perforce" menu option in those contexts.)
	Set tIsBuild = ($ZJob#2) || $$$IsISCWorker
	Set tDisconnected = ##super()
	If (tDisconnected = 0) && tIsBuild {
		// Detect Perforce availability so we can dynamically disable automated p4 activity
		Quit '..GetPerforceAvailable(1)
	} Else {
		Quit tDisconnected
	}
}

ClassMethod GetPerforceAvailable(pSkipDisconnectedCheck As %Boolean = 0) As %Boolean
{
	Set tAvailable = 0
	Try {
		// Find the Perforce host:port to test.
		Do ..GetCredentials(,,,,.tHostAndPort)
		If (tHostAndPort = "") {
			Set tHostAndPort = "perforce:1666" // The default.
		}
	
		// Optimization: do not check more often than every 15 seconds.
		If $Data($$$ZPMP4HostStatus(tHostAndPort),tLastCheckData) {
			Set tNow = $zhorolog
			Set tLastCheckTime = $ListGet(tLastCheckData,2)
			If (tLastCheckTime + 15 > tNow) {
				Set tAvailable = $ListGet(tLastCheckData)
				Quit
			}
		}
	
		If 'pSkipDisconnectedCheck {
			// Another optimization: if using %Studio.SourceControl.ISC or a derived source control class and have said we are disconnected from Perforce,
			// then treat Perforce as unavailable.
			If '$IsObject($Get(%SourceControl)) {
				New %SourceControl
				Set tSC = ##class(%Studio.SourceControl.Interface).SourceControlCreate()
				$$$ThrowOnError(tSC)
			}
			If $IsObject($Get(%SourceControl)) {
				If %SourceControl.%Extends("%ZPM.PackageManager.Developer.Extension.Composite") {
					Set %SourceControl = %SourceControl.GetPrimaryExtension()
				}
				If $IsObject(%SourceControl) && %SourceControl.%Extends("%Studio.SourceControl.ISC") {
					If %SourceControl.Disconnected() {
						Quit
					}
				}
			}
		}
		
		// Depending on P4HOST configuration, this may take a long time, but with proper P4HOST configuration
		// this seems to fail more quickly than simply using %IO.Socket to test a connection to host:port.
		Set tSC = ..RunCmd("p4 info -s",,0)
		If $$$ISOK(tSC) {
			Set tAvailable = 1
		}
		Set $$$ZPMP4HostStatus(tHostAndPort) = $ListBuild(tAvailable,$zhorolog)
	} Catch e {
		Set tAvailable = 0
	}
	
	Quit tAvailable
}

/// Invoked before build process runs.
/// Sets $$$BuildFlag; for dev builds, creates %SourceControl and backs up ^Sources.
ClassMethod OnBeforeBuild(pIsDev As %Boolean) As %Status
{
	Set tSC = $$$OK
	Try {
		If pIsDev {
			// Create the source control class so we can checkout/export files during the build
			Set tSC = ##class(%Studio.SourceControl.Interface).SourceControlCreate()
		
			// Capture original version of ^Sources (for selective restoration later, for build errors or modules not covered by build)
			Merge ^||SourcesBackup = ^Sources
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit $$$OK
}

/// Invoked after build process runs
ClassMethod OnAfterBuild(pIsDev As %Boolean, pSuccessful As %Boolean) As %Status
{
	Set tSC = $$$OK
	Set tSettings = $$$NULLOREF
	Set tOldAutoMove = ""
	Try {
		If pIsDev {
			// Disable auto-move, for the sake of performance.
			// Note that since this is a "singleton" lower scopes will reuse the in-memory instance with AutoMove = 0
			#dim tSettings As %ZPM.PackageManager.Developer.Extension.SourceControl.ISC.Settings
			Set tSettings = ##class(%ZPM.PackageManager.Developer.Extension.SourceControl.ISC.Settings).%Get(.tSC)
			$$$ThrowOnError(tSC)
			Set tOldAutoMove = tSettings.AutoMove
			Set tSettings.AutoMove = 0
			
			// Iterate over modules present in ^SourcesBackup
			Set tModuleKey = ""
			For {
				Set tModuleKey = $Order(^||SourcesBackup("MODULE",tModuleKey),1,tModuleRoot)
				If (tModuleKey = "") {
					Quit
				}
				
				If '$Data(^Sources("MODULE",tModuleKey)) {
					If $Extract(tModuleRoot) = $Char(..#NOPREFIXCHARCODE) {
						Set tModuleRoot = $Extract(tModuleRoot,2,*)
					} Else {
						// The former case is expected to always be the case, but if it isn't, this would be correct:
						Set tModuleRoot = ^Sources_tModuleRoot
					}
					
					// Recompute and reinstate ^Sources mappings for the module
					Set tSC = $$$ADDSC(tSC,..UpdateMappings(tModuleKey,tModuleRoot))
				}
			}
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	If $IsObject(tSettings) && (tOldAutoMove '= "") {
		// To be extra safe: in case tSettings was initialized in an outer scope and %Save'd there.
		Set tSettings.AutoMove = tOldAutoMove
	}
	Quit tSC
}

/// Check this routine/class/csp file out of source control.<br/>
/// Following successful checkout, the copy of the file on disk is loaded into the Namespace, unless <var>Load</var> is false.
Method CheckOut(InternalName As %String, Description As %String, Load As %Boolean = 1) As %Status
{
	Set tSC = $$$OK
	Try {
		// Pass Description by reference in case it's undefined
		Set tSC = ##super(InternalName, .Description, Load)
		$$$ThrowOnError(tSC)
		
		If ($Extract(InternalName) = "/") {
			Set tOtherFile = $System.CSP.GetFileName(InternalName)
			// See if the physical path and Perforce path match.
			If (tOtherFile '= "") && (tOtherFile '= ..ExternalName(InternalName)) {
				// Set file to writeable if needed.
				If '##class(%Library.File).Writeable(tOtherFile) {
					Set tSC = ##class(%ZPM.PackageManager.Developer.File).SetWriteable(tOtherFile)
					$$$ThrowOnError(tSC)
				}
			}
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

ClassMethod ListFilesPendingResolve(Output pFileList As %ZPM.PackageManager.Developer.Extension.SourceControl.ISC.PerforceFileList, pFilterToBranch As %String = "//") As %Status
{
	Set pFileList = $$$NULLOREF
	Set tSC = $$$OK
	Try {
		Set tSC = ..P4Cmd("fstat -Ru "_pFilterToBranch_"...#have",.tFilesPendingResolve)
		If $$$ISERR(tSC) {
			Set tText = $System.Status.GetErrorText(tSC)
			If (tText [ "no such file(s)") {
				// No files pending resolve - not actually an error.
				Set tSC = $$$OK
			} ElseIf (tText [ "file(s) not opened on this client") {
				// No files checked out - not actually an error.
				Set tSC = $$$OK
			}
		}
		$$$ThrowOnError(tSC)
		Set pFileList = ##class(%ZPM.PackageManager.Developer.Extension.SourceControl.ISC.PerforceFileList).CreateFromFStatOutput(.tFilesPendingResolve)
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// Export items to source control dir, or to AltPath as UDL if not mapped in source control
ClassMethod Export(pPackageOrItems As %String, pAltPath As %String = "", qspec As %String = "-d /diffexport") As %Status
{
	// Add all the items, and all the classes from each Package named in the input pPackageOrItems list
	Set tSC = $$$OK
	For i=1:1:$L(pPackageOrItems,",") { Set tItem=$ZStrip($P(pPackageOrItems,",",i),"<>W") Continue:""=tItem	
		If ",.cls,.inc,.mac,.rtn," [ (",."_$ZCvt($P(tItem,".",*),"L")_",") {
			w !,"adding item "_tItem
			Set tFullList(tItem)=""
		} Else {
			w !,"adding package "_tItem
			Do $system.OBJ.GetPackageList(.tList,tItem,"ars")
			Set class="" For { Set class=$Order(tList(class)) Quit:class=""
				Set tFullList(class_".cls")=""
			}
		}
	}
	// Export the items
	Set item="" For { Set item=$Order(tFullList(item)) Quit:item=""
		Set tItemFile = ..ExtName(item)
		Set name=$Piece(item,".",1,*-1)
		Set ext=$ZConvert($Piece(item,".",*),"U")
		If ""'=tItemFile {
			If $Data(^Sources(ext,name),found) {
				Set tPackage = name // If individual file is mapped, just use that as the prefix
			} Else {
				For tPackageLength = ($Length(name,".")-1):-1:1 {
					Set tPackage = $Piece(name,".",1,tPackageLength)_"."
					Quit:$Data(^Sources(ext,tPackage),found)
				}
			}
			If "`"=$Extract($Get(found),*) {
				Write !,"   exporting "_item_" to UDL "_tItemFile
				Set tSC1 = $$ExportUDL^%apiOBJ(item,tItemFile,qspec)
			} ElseIf "CLS"=ext {
				Write !,"   exporting "_item_" to XML "_tItemFile
				Set tSC1 = $$Export^%occXMLExport(tItemFile,qspec,item)
			} Else {
				Write !,"   exporting "_item_" to RTN "_tItemFile
				Set tSC1  = $$Export^%apiRTN(item,tItemFile,"Force Export",,qspec)
			}
		} ElseIf ""'=pAltPath {
			Set tSep = $Select(pAltPath["/":"/",1:"\")
			Set tItemFile = pAltPath_$Select(tSep=$Extract(pAltPath,*):"",1:tSep)_$TRanslate($Piece(item,".",1,*-1),".%",tSep)_"."_$ZConvert($Piece(item,".",*),"L")
			Write !,"   !exporting "_item_" UDL to ALTERNATE LOCATION "_tItemFile
			Set tSC1 = $$ExportUDL^%apiOBJ(item,tItemFile,qspec)
		} Else {
			Set tSC1 = $$$ERROR($$$GeneralError,"No source control mapped path and no Alternate Path found for "_item)
		}
		If $$$ISERR(tSC1) {
			Write !
			Do $System.Status.DisplayError(tSC1)
			Set tSC = $$$ADDSC(tSC,tSC1)
		}
	}
	Quit tSC
}

}
