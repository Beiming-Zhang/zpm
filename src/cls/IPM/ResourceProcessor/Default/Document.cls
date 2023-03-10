Class %IPM.ResourceProcessor.Default.Document Extends %IPM.ResourceProcessor.AbstractCompilable
{

/// Description of resource processor class (shown in UI)
Parameter DESCRIPTION As STRING = "Default resource processor class for %Studio.AbstractDocument subclasses";

/// Comma-separated list of resource attribute names that this processor uses
Parameter ATTRIBUTES As STRING = "Compile,CompileAfter,Flags,ExportFlags,Directory,LoadAsDirectory,FilenameExtension,FilenameTranslateIdentifier,FilenameTranslateAssociator,Format";

/// May be set to determine the value of <property>Extension</property> based on a static value rather than based on the resource name.
/// The only expected use case at this point is class packages (.PKG, but Extension will be .CLS)
Parameter EXTENSION;

/// When a module is loaded in developer mode, this is appended to the resource name in ^Sources - e.g., ^Sources(..Extension, <resource name>_..#NAMEPOSTFIX)
/// The only expected use case at this point is class packages (.PKG, but Extension will be .CLS)
Parameter NAMEPOSTFIX;

/// If true, the resource will be compiled during the compilation phase in the module lifecycle.
Property Compile As %Boolean [ InitialExpression = 1 ];

/// Directory relative to module root containing the exported resource.
/// Defaults to the resource's extension (lower-case) if unspecified.
Property Directory As %String(MAXLEN = "") [ InitialExpression = {$ZConvert(..#EXTENSION,"L")} ];

Property DirectoryDefined As %Boolean [ InitialExpression = 0, Transient ];

/// If true (default is false), the resource is loaded as a directory.
Property LoadAsDirectory As %Boolean [ InitialExpression = 0 ];

/// Characters in the filename to use as the identifier in $translate when determining the resource's filename on disk
/// The default behavior is to replace "." with "/" and ignore "%"
Property FilenameTranslateIdentifier As %String [ InitialExpression = ".%" ];

/// Characters in the filename to use as the associator in $translate when determining the resource's filename on disk
/// The default behavior is to replace "." with "/" and ignore "%"
Property FilenameTranslateAssociator As %String [ InitialExpression = "/" ];

/// Extension for individual filename(s) that comprise this resource
Property FilenameExtension As %String [ InitialExpression = "xml" ];

/// Export format - list of acceptable values may differ by subclass.
Property Format As %String;

/// Name of the server document (without extension)
Property Name As %String(MAXLEN = 255) [ Private ];

/// Extension of the server document(s) represented by this resource
Property Extension As %String [ Private ];

Method DirectorySet(pValue As %String) As %Status
{
	
  Set i%Directory = pValue	
  Set ..DirectoryDefined = 1	
  Quit $$$OK
}

Method OnPhase(pPhase As %String, ByRef pParams, Output pResourceHandled As %Boolean = 0) As %Status
{
	Set tSC = $$$OK
	Set pResourceHandled = 0
	Try {
		Set tVerbose = $Get(pParams("Verbose"),0)
		Set tDeveloperMode = $Get(pParams("DeveloperMode"),0)
		Set tName = $Piece(..ResourceReference.Name,".",1,*-1)
		Set tRoot = ##class(%File).NormalizeDirectory(..ResourceReference.Module.SourcesRoot, ..ResourceReference.Module.Root)
		Set tInScope = ..ResourceReference.IsInScope(pPhase,.tInCurrentPhase)
    If (..Directory'="") {		
      Set ..DirectoryDefined = 1
    }	
		If ((pPhase = "Reload") && tInScope) || tInCurrentPhase {
	    Set tCatDirectory = ""	
      Set tCatDirectory = tCatDirectory _ $ListBuild(..Directory)	
      If ('..DirectoryDefined) {	
        If (..Directory="mac") {	
          Set tCatDirectory = tCatDirectory _ $ListBuild("rtn")	
        }	
        If (..Directory'="") {	
          Set tCatDirectory = tCatDirectory _ $ListBuild("")	
        }	
      }	
      Set tListNames = ""	
      Set tListNames = tListNames _ $ListBuild(tName)	
      Set tListNames = tListNames _ $ListBuild($Translate(tName, "%", "_"))	
      Set tListNames = tListNames _ $ListBuild($Translate(tName, "_", ""))	
      Set tListNames = tListNames _ $ListBuild($Translate(tName, "%", ""))
      Set ptrn = 0	
      While $ListNext(tListNames, ptrn, tName) {
				// Runs in Reload normally, and also in Test for test scope / Verify for verify scope
				Set tSourcesPrefix = $c($parameter("%IPM.ExtensionBase.SourceControl.Interface","NOPREFIXCHARCODE"))
				
				If '$Get(pParams("NoMapping"),0) {
          // Disabled mapping of resources. It creates more problems than solves. 	
          // Moreover, the removal of mapping during uninstallation is not implemented.	
          // $$$ThrowOnError(..OnConfigureMappings(.pParams))	
          }	
          If ..ResourceReference.Generated {	
            Set pResourceHandled = 1	
          Quit
				}
				
				If '..ResourceReference.Generated {
					Set tSubDirectory = $Select(..ResourceReference.Preload:"preload/",1:"")
					Set tResourceDirectory = ##class(%File).NormalizeDirectory(tRoot_"/"_tSubDirectory)
					If ('##class(%File).DirectoryExists(tResourceDirectory)) {
						Quit 
					}
	        Set ptr = 0
	        Set tResourceCatDirectory = ##class(%File).NormalizeDirectory(tResourceDirectory)	
          While $ListNext(tCatDirectory, ptr, tDirectory) {	
            Set tResourceCatDirectory = ##class(%File).NormalizeDirectory(tResourceDirectory _ tDirectory)	
            If (##class(%File).DirectoryExists(tResourceCatDirectory)) {	
              Quit
            }
					} 
					Set tResourceDirectory = tResourceCatDirectory
			
					If tDeveloperMode && (..Extension '= "") && (tName '= "") {
						Set ^Sources(..Extension,tName_..#NAMEPOSTFIX) = tSourcesPrefix _ tResourceDirectory
					}

					If '..ResourceReference.Preload {
						Set tFileExtension = $Select(..LoadAsDirectory:"",1:"."_..FilenameExtension)
						Set tResourcePath = ##class(%File).NormalizeFilename(tResourceDirectory _ tSubDirectory _ $Translate(tName, ..FilenameTranslateIdentifier, ..FilenameTranslateAssociator)) _ tFileExtension
						If '..LoadAsDirectory {
              If ($$$lcase(tFileExtension)'=".xml")&&('##class(%File).Exists(tResourcePath)) {
							  Set tResourcePathXML = tResourcePath
                Set $PIECE(tResourcePath, ".", *) = "xml"
                If (##class(%File).Exists(tResourcePathXML)) {	
                  Set tResourcePath = tResourcePathXML	
                  Set ..Format = "XML"	
                }
						  }
			
						  If ($$$lcase(tFileExtension)=".mac")&&('##class(%File).Exists(tResourcePath)) {
	              Set tResourcePathRTN = tResourcePath	
                Set $Piece(tResourcePathRTN, ".", *) = "rtn"	
                If (##class(%File).Exists(tResourcePathRTN)) {	
                  Set tResourcePath = tResourcePathRTN	
                }	
              }
						}
																		
						If '##class(%File).Exists(tResourcePath) {
							Set tSC = $$$ERROR($$$GeneralError, "Resource path '" _ tResourcePath _ "' not found")
							Continue
						}

						$$$ThrowOnError(..OnLoad(tResourcePath,tVerbose,tInCurrentPhase,.tLoadedList))
						
						Set tSC = ##class(%IPM.Storage.LoadedResource).TrackResourceNames(..ResourceReference.Module.Name,..ResourceReference.UniqueName,tLoadedList)
						$$$ThrowOnError(tSC)
					}
				}
				Set pResourceHandled = 1
        Set tSC = $$$OK
				Quit
			}
		} ElseIf (pPhase = "Compile") {
			If tInScope {
				// If Compile is false, indicate that the resource's compilation phase has already been handled and nothing special should happen.
				Set pResourceHandled = '..Compile
			} Else {
				// If out of scope, nothing should happen.
				Set pResourceHandled = 1
			}
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

Method OnExportItem(pFullExportPath As %String, pItemName As %String, ByRef pItemParams, ByRef pParams, Output pItemHandled As %Boolean = 0) As %Status
{
  Set tSC = ..OnExportDeployedItem(pFullExportPath, pItemName, .pItemParams, .pParams, .pItemHandled)	
  If pItemHandled || $$$ISERR(tSC) {	
    Quit tSC	
  }
	Set tSC = $$$OK
  Set tExportFlags = "-d /diffexport"_..ExportFlags
  Set tVerbose = $Get(pParams("Verbose"),0)
	Try {
		If ..Format = "UDL" {
			// This is tailored toward support of "Other" documents exported in UDL format.
			If ##class(%Atelier.v1.Utils.General).ValidateDocName(pItemName,.tSC,.tCategory) {
				// Ensure directory containing file exists, and attempt to create it if not.
				If $Extract(pFullExportPath) = """" {
					// Avoid issues with the path being quoted. (These mess up GetDirectory().)
					Set pFullExportPath = $Extract(pFullExportPath,2,*-1)
				}
				
				Set tTargetDirectory = ##class(%Library.File).GetDirectory(pFullExportPath)
				If '##class(%Library.File).DirectoryExists(tTargetDirectory) {
					$$$ThrowOnError(##class(%IPM.Utils.File).CreateDirectoryChain(tTargetDirectory))
				}
				
				$$$ThrowOnError($System.OBJ.ExportUDL(pItemName,pFullExportPath,tExportFlags))
			}
			Set pItemHandled = 1
		} ElseIf (..Format = "XML") {
			$$$ThrowOnError($System.OBJ.Export(pItemName,pFullExportPath,tExportFlags))
			Set pItemHandled = 1
		} ElseIf (..Format = "%RO") {
			Set tSC = $$Export^%apiRTN(pItemName,pFullExportPath,"Save for Source Control","WNSK\UTF8\",tExportFlags)
			Set pItemHandled = 1
		}
    Write:tVerbose !,"Exporting '",pItemName,"' to '",pFullExportPath,"'"
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

Method OnExportDeployedItem(pFullExportPath As %String, pItemName As %String, ByRef pItemParams, ByRef pParams, Output pItemHandled As %Boolean = 0) As %Status
{
	
  Set tSC = $$$OK	
  Try {	
    Set tVerbose = $Get(pParams("Verbose"),0)	
    Set tDeveloperMode = $Get(pParams("DeveloperMode"),0)	
    Quit:tDeveloperMode	
    Quit:'..ResourceReference.Deploy	
    Set tModuleName = ..ResourceReference.Module.Name	
    Set fileExt = $$$ucase($Piece(pItemName, ".", *))	
    Set tName = $Piece(pItemName, ".", 1, * - 1)	
    Quit:'($ListFind($ListBuild("CLS","MAC","INT"), fileExt))	
    #; Set tSC = $$$OK	
    Set tFullExportPath = pFullExportPath	
    Set tFullExportPath = tFullExportPath _ ".deploy"	
    Write:tVerbose !,"Exporting Deployed '",pItemName,"' to '",tFullExportPath,"'"	
    Set list = ""	
    If fileExt = "CLS" {	
      Set list = ..ListGlobals4Class(tName)	
    } Else {	
      Set list = ..ListGlobals4Routine(tName)	
    }	
    Quit:list=""	
    Set ptr = 0	
    While $ListNext(list, ptr, item) {
      Set list(item _ ".gbl") = ""	
    }	
    $$$ThrowOnError(##class(%File).CreateDirectoryChain(##class(%File).GetDirectory(tFullExportPath)))	
    Set flags = $Select(tVerbose: "d", 1: "-d")	
    $$$ThrowOnError($System.OBJ.Export(.list, tFullExportPath, flags))	
    Set pItemHandled = 1	
  }	Catch e {	
    Set tSC = e.AsStatus()	
  }	
  Quit tSC
}

Method ListGlobals4Class(pClassName As %String = "") As %String [ Private ]
{
	
  Set list = ""	
  Set oddDEF = $Name(^oddDEF)	
  Set oddCOM = $Name(^oddCOM)	
  Set oddDEP = $Name(^oddDEP)	
  Set oddEXT = $Name(^oddEXT)	
  Set oddEXTR = $Name(^oddEXTR)	
  Set oddMAP = $Name(^oddMAP)	
  Set oddPROC = $Name(^oddPROC)	
  Set oddSQL = $Name(^oddSQL)	
  Set oddTSQL = $Name(^oddTSQL)	
  Set rINDEX = $Name(^rINDEX)	
  Set rINDEXSQL = $Name(^rINDEXSQL)	
  Set rINDEXCLASS = $Name(^rINDEXCLASS)	
  Set rOBJ = $Name(^rOBJ)	
  Set rPYC = $Name(^rPYC)	
  If (pClassName="")||('$Data(@oddCOM@(pClassName))) {	
    Quit ""	
  }	
  Set list = list _ $ListBuild($Name(@oddDEF@(pClassName)))	
  Set list = list _ $ListBuild($Name(@oddCOM@(pClassName)))	
  Set list = list _ $ListBuild($Name(@oddDEP@(pClassName)))	
  If 0 {	
    Set ind = ""	
    For {	
      Set ind = $Order(@oddDEP@(pClassName, ind))	
      Quit:ind=""	
      Set dep = ""	
      For {	
        Set dep = $Order(@oddDEP@(pClassName, ind, dep))	
        Quit:dep=""	
        Set list = list _ $ListBuild($Name(@oddDEP@(0, dep, ind, pClassName)))	
      }	
    }	
  }	
  Set list = list _ $ListBuild($Name(@rINDEXCLASS@($$$ucase(pClassName))))	
  Set ind = ""	
  For {	
    Set ind = $Order(@oddCOM@(pClassName,50,ind))	
    Quit:ind=""	
    Set list = list _ $ListBuild($Name(@rINDEX@(ind)))	
    Set list = list _ $ListBuild($Name(@rOBJ@(ind)))	
  }	
  If $Data(@rPYC@(pClassName)) {	
    Set list = list _ $ListBuild($Name(@rPYC@(pClassName)))	
  }	
  Set $ListBuild(schema, table) = $ListFromString($Get(@oddCOM@(pClassName, 53)), ".")	
  If schema'="",table'="",$Data(@oddSQL@(schema, table)) {	
  Set list = list _ $ListBuild($Name(@oddSQL@(schema, table)))	
  Set list = list _ $ListBuild($Name(@rINDEXSQL@("TABLE", schema, table)))	
  Set list = list _ $ListBuild($Name(@rINDEXSQL@("rv", $$$ucase(schema), $$$ucase(table))))	
  #; Set tsqlId = ""	
  #; For {	
  #;   Set tsqlId = $Order(@oddSQL@(schema, table, "tsql", 1, tsqlId))	
  #;   Quit:tsqlId=""	
  #;   Set list = list _ $ListBuild($Name(@oddTSQL@(tsqlId)))	
  #; }	
  }	
  Set ind = ""	
  For {
    Set ind = $Order(@oddCOM@(pClassName, $$$cCLASSprocedures, ind), 1, value)	
    Quit:ind=""	
    Set $ListBuild(schema, table) = value	
    Continue:schema=""	
    Continue:table=""	
    Set list = list _ $ListBuild($Name(@oddPROC@($$$ucase(schema), ind)))	
    Set list = list _ $ListBuild($Name(@oddSQL@(schema, table)))	
  }	
  If $Data(@oddEXT@(pClassName _ ".cls")) {	
    Set list = list _ $ListBuild($Name(@oddEXT@(pClassName _ ".cls")))	
  }	
  If $Data(@oddEXTR@(pClassName)) {	
    Set list = list _ $ListBuild($Name(@oddEXTR@(pClassName)))	
  }	
  If $Data(@oddMAP@(pClassName)) {	
    Set list = list _ $ListBuild($Name(@oddMAP@(pClassName)))	
  }	
  Quit list
}

Method ListGlobals4Routine(pRoutine As %String = "") As %String [ Private ]
{
	
  Set list = ""	
  Set rINDEX = $Name(^rINDEX)	
  Set rOBJ = $Name(^rOBJ)	
  If (pRoutine="")||('$Data(@rOBJ@(pRoutine))) {	
    Quit ""	
  }	
  Set list = list _ $ListBuild($Name(@rINDEX@(pRoutine)))	
  Set list = list _ $ListBuild($Name(@rOBJ@(pRoutine)))	
  Quit list
}

/// Subclasses may override to customize mapping behavior at the beginning of the Reload phase.
Method OnConfigureMappings(ByRef pParams) As %Status
{
	Quit $$$OK
}

/// Subclasses may override to customize resource load behavior during the Reload phase. <br />
/// @Argument	pFullResourcePath			The absolute path to the resource present on the file system
/// @Argument	pVerbose					1: display output from loading files, 0: do not display output
/// @Argument	pCompile					1: compile files upon load, 0: do not compile files
/// @Argument	pLoadedList					Output: comma delimited list of files that have been loaded
Method OnLoad(pFullResourcePath As %String, pVerbose As %Boolean, pCompile As %Boolean = 0, Output pLoadedList As %String, ByRef pParams As %String) As %Status
{
	Set pLoadedList = ""
	Set tSC = $$$OK
	Try {
		// Workaround: need to clean up after other UDL import/export operations
		Kill ^||%oddDEF
    Set tFlags = $Select(pVerbose:"/display",1:"/nodisplay")_
      $Select(pCompile:"/compile",1:"/nocompile")_
      $Select($Tlevel||..ResourceReference.Deploy:"/multicompile=0",1:"")

    If ..LoadAsDirectory {
      Set tSC = $System.OBJ.ImportDir(pFullResourcePath, "*", tFlags, , 1, .pLoadedList)
      $$$ThrowOnError(tSC)
      If $Data(pLoadedList)>1 {
        Merge tResult = pLoadedList
        Set pLoadedList = ""
      }
    } ElseIf (..Format = "%RO") {
      // This tolerates some unusual %RO header formats that $System.OBJ.Load does not respect.
      Set pLoadedList = ""
      Set tSC = $$Import^%apiRTN(pFullResourcePath,"replace,compile="_pCompile,,,.tResult,$Select(pVerbose:"d",1:"-d"))
    } Else {
      Set tSC = $System.OBJ.Load(pFullResourcePath,tFlags,,.pLoadedList)
      $$$ThrowOnError(tSC)
    }
    $$$ThrowOnError(..OnLoadDeployed(.pParams, .pLoadedList))
    If $Data(tResourceKey)>1 {
      Set tResourceKey = ""
      For {
        Set tResourceKey = $Order(tResult(tResourceKey))
        If (tResourceKey = "") {
          Quit
        }
        Set pLoadedList = pLoadedList_$ListBuild(tResourceKey)
      }
      Set pLoadedList = $ListToString(pLoadedList)
    }

		If $Data(pLoadedList)#2 {
			Do ..ResourceReference.UpdateChildrenFromString(pLoadedList)
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

Method OnLoadDeployed(ByRef pParams, ByRef pLoadedList) As %Status
{
	
  Set tSC = $$$OK	
  Try {	
    Set tr = 1	
    Set tVerbose = $Get(pParams("Verbose"),0)	
    Set tModuleName = ..ResourceReference.Module.Name	
    Set tName = ""	
    For {	
      Set tName = $Order(pLoadedList(tName))	
      Quit:tName=""	
      Continue:($$$ucase($Piece(tName,".",*))'="GBL")	
      Set tGN = "^" _ $Piece(tName, ".", 1, * - 1)	
      #; Yep, it's just a workaround for eror with python	
      #; <OBJECT DISPATCH> *python object not found	
      If tName["rPYC(" {	
        Set tValue = $Get(@tGN)	
        Set @tGN = +tValue	
      }	
    }	
  }	
  Catch e {	
    Set tSC = e.AsStatus()	
  }	
  Quit tSC
}

Method %OnNew(pResourceReference As %IPM.Storage.ResourceReference) As %Status [ Private, ServerOnly = 1 ]
{
	Set tResourceRefName = pResourceReference.Name
	// Set LoadAsDirectory to 1 if resource reference name is a path. 
	// Else, get name and extension from resource reference name
	If $Extract(tResourceRefName) = "/" {
		Set ..LoadAsDirectory = 1
    Set i%Directory = tResourceRefName
		Set tSC = ##super(pResourceReference)
		If (..Extension = "") {
			Set ..Extension = $$$lcase(..#EXTENSION)
		}
	} Else {
		Set ..Name = $Piece(tResourceRefName,".",1,*-1)
		Set ..Extension = $$$lcase($Case(..#EXTENSION,"":$Piece(tResourceRefName,".",*),:..#EXTENSION))
		Set tSC = ##super(pResourceReference)
		If (i%Directory = "") {
			Set i%Directory = $ZConvert(..Extension,"L")
      if $lf($lb("dtl","bpl"),i%Directory) {
        set i%Directory = "cls"
      }
		}
	}
	Quit tSC
}

Method OnAfterPhase(pPhase As %String, ByRef pParams) As %Status
{
	Set tSC = $$$OK
	Try {
		If (pPhase = "Validate") {
			If (..Extension = "") {
				Set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Invalid resource name '%1' - must have a file extension to identify the Studio document type.",..Name))
				Quit
			}
		}
	} Catch e {
		Set tSC = e.AsStatus()
	}
	Quit tSC
}

/// Enumerate all documents contained in the resource being processed. <br />
/// @Argument	pResourceArray			ByRef: array of the following format: pResourceArray(<Studio document name>) = <module that contains document>
/// pResourceArray(<Studio document name>, <resource referenty property>) = value of resource reference property for given document
Method OnResolveChildren(ByRef pResourceArray) As %Status
{
	If ..LoadAsDirectory {
		Kill pResourceArray(..ResourceReference.Name)
		Set tKey = ""
		While 1 {
			Do ..ResourceReference.Children.GetNext(.tKey)
			Quit:(tKey = "")
			Set pResourceArray(tKey) = ..ResourceReference.Module.Name
			Set pResourceArray(tKey,"Processor") = ..ResourceReference.Processor
			Set pResourceArray(tKey,"Generated") = ..ResourceReference.Generated
			Set pResourceArray(tKey,"Preload") = ..ResourceReference.Preload
			Set pResourceArray(tKey,"Scope") = ..ResourceReference.Scope
			Set pResourceArray(tKey,"Deploy") = ..ResourceReference.Deploy
			Set pResourceArray(tKey,"RelativePath") = ..OnItemRelativePath(tKey)
		}
	} Else {
		// Add the relative path for purposes of lifecycle %Export method
		Set pResourceArray(..ResourceReference.Name,"RelativePath") = ..OnItemRelativePath(..ResourceReference.Name)
	}
	Quit $$$OK
}

/// Returns the path relative to the module root for item <var>pItemName</var> within this resource.
Method OnItemRelativePath(pItemName As %String) As %String
{
	Set tFileExtension = $Select(..LoadAsDirectory:"",1:"."_..FilenameExtension)
  Set tSourceRoot = ..ResourceReference.Module.SourcesRoot
	If tSourceRoot'="","\/"'[$EXTRACT(tSourceRoot, *) {
		Set tSourceRoot = tSourceRoot _ "/"
	}  
  set directory = $Select(..DirectoryDefined: ..Directory, 1: "")
	Quit $Select(..ResourceReference.Preload:"preload/",1:"")_directory_"/"_$Translate($Piece(pItemName,".",1,*-1),..FilenameTranslateIdentifier,..FilenameTranslateAssociator)_tFileExtension
}

Method GetSourceControlInfo(Output pInfo As %IPM.ExtensionBase.SourceControl.ResourceInfo) As %Status
{
	Set pInfo = ##class(%IPM.ExtensionBase.SourceControl.ResourceInfo).%New()
	Set pInfo.SourceControlAware = 1
	Set pInfo.RelativePath = ..Directory
	Set pInfo.ResourceType = ..Extension
	Set pInfo.Prefix = ..Name_..#NAMEPOSTFIX
	If (..ResourceReference.Preload) {
		Set pInfo.RelativePath = "/preload/"_pInfo.RelativePath
	}
	Quit $$$OK
}

/// Returns a unique name for this resource.
/// Default implementation, leaving <var>pUniqueName</var> undefined, reverts to default behavior.
/// An empty string indicates guaranteed uniqueness (useful for folders relative to module root)
Method OnGetUniqueName(Output pUniqueName)
{
	If ($Extract(..ResourceReference.Name) = "/") {
		Set pUniqueName = ..ResourceReference.Module.Name_"@"_..ResourceReference.Name
	}
}

/// Returns a boolean of whether current file exists in the the routine database of the current namespace exists in current namespace's database
/// Helper method to be used in derived classes' OnConfigureMappings() to skip creating unnecessary mapping
ClassMethod FileExistsInCurrentNS(pFileName As %String) As %Boolean
{
	Set tSourceDB = ##class(%IPM.Utils.Module).GetRoutineDatabase($Namespace)
	// Check if current file exists in the the routine database of the current namespace exists in current namespace('s database)
	// If yes, skip creating unnecessary mappings
	// (Spec,Dir=1,OrderBy=1,SystemFiles=1,Flat,NotStudio=0,ShowGenerated=0,Filter,RoundTime=0,Mapped=0)
	// Set mapped=0 since we only want to check whether the file exists in the current routine DB
	Set tResult = ##class(%Library.RoutineMgr).StudioOpenDialogFunc(pFileName_".*",1,1,1,,,,,,0)
	Set tNeedExplicitMapping = 1
	While tResult.%Next(.tSC) {
		$$$ThrowOnError(tSC)
		if ($ZConvert(tResult.%Get("Name"),"U") = $ZConvert(pFileName, "U")) {
			Set tNeedExplicitMapping = 0
		}
	}
	$$$ThrowOnError(tSC)
	Return tNeedExplicitMapping
}

}
