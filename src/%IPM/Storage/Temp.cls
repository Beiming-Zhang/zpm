Class %IPM.Storage.Temp Extends %IPM.Storage.Module
{


/// DependencyGraphConfig.Graph:
/// Graph("dependent module name") = $ListBuild(<depth>,<server name>,<exact version>,<module state>)
/// Graph("dependent module name","<target module> <target module exact version>") = <dependent module semantic version>
Method ConstructDependencyGraph(pGraphConfig As %IPM.Utils.DependencyGraphConfig)
{
	#define EXACT 1
	#define FUZZY 2
	#define SCOPE "Scope"
	
	Set tSC = $$$OK

	Set pDepth = pGraphConfig.Depth
	Do pGraphConfig.GetGraph(.pDependencyGraph)
	Set pForceSnapshotReload = pGraphConfig.ForceSnapshotReload
	Set pPhases = pGraphConfig.Phases
	Set pPass = pGraphConfig.Pass
	Set pModulePath = pGraphConfig.ModulePath
	Set pIgnoreInstalledModules = pGraphConfig.IgnoreInstalledModules
	Set pKnownDependencies = pGraphConfig.KnownDependencies
	Set pPermitDowngrade = pGraphConfig.PermitDowngrade
	Set pCheckNestedScoped = pGraphConfig.CheckNestedScoped
	Do pGraphConfig.GetSubModules(.pSubModules)
		
	Kill tSubModules
	// Create an instance of the repository manager singleton (or get the existing one)
	// This makes it available at lower stack levels, which helps
	// to avoid significant duplicate work in dependency resolution.
	Set tRepositoryManager = ##class(%IPM.Repo.Manager).%Get(.tSC)
	$$$ThrowOnError(tSC)
	
	// May want to pass phases to subsequent calls
	Set tPhases = $Case(pCheckNestedScoped, 1: pPhases, : "")
	For i=1:1:..Dependencies.Count() {
		#dim tDep As %IPM.Storage.ModuleReference
		Set tDep = ..Dependencies.GetAt(i)
		Set tModulePath = pModulePath
		If '..HasScope(pPhases,tDep.Scope) {
			Continue
		} ElseIf (tDep.Scope '= "") && (pModulePath = $ListBuild(..Name)) {
			// Exclude the root module from cyclic dependency checking if the dependency is scoped.
			Set tModulePath = ""
		}
		
		// Ensure this dependency is not an ancestor in the chain of dependencies getting to this point
		If $ListFind(tModulePath,tDep.Name) {
			Set tSC = $$$ERROR($$$GeneralError,$$$FormatText("Cyclic dependency detected in module '%1': %2",..Name,$ListToString(tModulePath_$ListBuild(tDep.Name)," -> ")))
			$$$ThrowOnError(tSC)
		}
		
		// Test whether dependency version is a valid semantic version. These are handled in the first pass only.
		// Other cases are handled in the second pass only.
		Set tIsExactVersion = +##class(%IPM.General.SemanticVersion).IsValid(tDep.VersionString) kill %objlasterror
		If ((pPass = $$$EXACT) && 'tIsExactVersion) || ((pPass = $$$FUZZY) && tIsExactVersion) {
			Continue
		}
		
		// Build cumulative version requirement string
		#dim tSearchExpr As %IPM.General.SemanticVersionExpression
		Set tSearchExpr = tDep.Version.%ConstructClone(1)
		Set tConstraintList = $ListBuild(..Name_": "_tDep.VersionString)
		Set tSourcePath = ""
		For {
			Set tSourcePath = $Order(pDependencyGraph(tDep.Name,tSourcePath),1,tOtherReq)
			Quit:tSourcePath=""
			
			Set tSC = ##class(%IPM.General.SemanticVersionExpression).FromString(tOtherReq,.tExpr)
			$$$ThrowOnError(tSC)
			Set tSearchExpr = tSearchExpr.And(tExpr)
			Set tConstraintList = tConstraintList_$ListBuild(tSourcePath_": "_tOtherReq)
		}
		$$$ThrowOnError(tSC)
		
		If 'pIgnoreInstalledModules {
			// Also apply requirements presented by other installed modules, with the exception of those that are:
			//	* Known as dependencies of the root module being installed (and thus eligible for upgrade)
			//  * Already in the dependency graph
			Set tOtherDeps = pKnownDependencies
			Set tExistingDepKey = ""
			For {
				Set tExistingDepKey = $Order(pDependencyGraph(tExistingDepKey))
				If (tExistingDepKey = "") {
					Quit
				}
				Set tOtherDeps = tOtherDeps_$ListBuild(tExistingDepKey)
			}
			
			Set tSC = ##class(%IPM.Utils.Module).GetRequiredVersionExpression(tDep.Name,tOtherDeps,.tInstalledReqExpr,.tInstalledConstraintList)
			$$$ThrowOnError(tSC)
			Set tSearchExpr = tSearchExpr.And(tInstalledReqExpr)
			Set tConstraintList = tConstraintList_tInstalledConstraintList
		}
		
		// See if we already have a version that satisfies the dependency:
		Set tDepFound = $Data(pDependencyGraph(tDep.Name),tDepInfo)
		Set tPreviousDepth = 0
		Set tServerName = ""
		Set tVersion = ""
		Set tState = "Installed"
		If tDepFound {
			Set $ListBuild(tPreviousDepth,tServerName,tVersion,tState) = tDepInfo
		}
		
		// See if a satisfactory version already exists in the current namespace.
		// If it does, always use it
		// Particularly relevant for compilation of dependencies
		// The "clean" phase can be used to bypass this (by removing modules from the current namespace)
		// Forcing an update from disk can also override this, although we ensure that the same module is
		// not loaded multiple times in a given operation.
		Set tForceSnapshotReload = pForceSnapshotReload
		If tForceSnapshotReload && $Data($$$ZPMHandledModules($Namespace,tDep.Name),tHandled) {
			If $ListFind(tHandled,"Activate") {
				// If we have already activated the given module, don't do so again.
				Set tForceSnapshotReload = 0
			}
		}
		If ('pIgnoreInstalledModules) && ..NameExists(tDep.Name) {
			Set tLocalObj = ..NameOpen(tDep.Name,,.tSC)
			$$$ThrowOnError(tSC)
			
			Set tInstalledVersionValid = tLocalObj.Version.Satisfies(tSearchExpr) && ((tVersion = "") || (tVersion = tLocalObj.VersionString)) && (tState = "Installed")
			If tInstalledVersionValid && '(tLocalObj.Version.IsSnapshot() && tForceSnapshotReload) {
				Set tLocalMod = 1
				Set tDepth = $Select(tPreviousDepth=0:pDepth,tPreviousDepth>pDepth:tPreviousDepth,1:pDepth)
				Set pDependencyGraph(tDep.Name) = $ListBuild(pDepth,"",tLocalObj.VersionString, tLocalObj.State.State)
				Set pDependencyGraph(tDep.Name,..Name_" "_..VersionString) = tDep.VersionString
				Set pSubModules(tDepth,tDep.Name) = tLocalObj
				Set pSubModules(tDepth,tDep.Name,$$$SCOPE) = tDep.Scope
				Continue
			}
			
			If 'pPermitDowngrade {
				// Add a minimum of the currently-installed version as a constraint.
				Set tRangeString = ">="_tLocalObj.VersionString
				Set tSC = ##class(%IPM.General.SemanticVersionExpression).FromString(tRangeString,.tCurrentlyInstalledExpr)
				$$$ThrowOnError(tSC)
				Set tSearchExpr = tSearchExpr.And(tCurrentlyInstalledExpr)
				Set tConstraintList = tConstraintList_$ListBuild(tLocalObj.Name_": "_tRangeString_" (currently installed, downgrade not permitted)")
			}
		}
		Set tSearchCriteria = ##class(%IPM.Repo.SearchCriteria).%New()
		Set tSearchCriteria.Name = tDep.Name
		Set tSearchCriteria.VersionExpression = tSearchExpr.ToString()
		Set tSC = tRepositoryManager.SearchRepositoriesForModule(tSearchCriteria,.tQualifiedReferences,pForceSnapshotReload)
		$$$ThrowOnError(tSC)
		If (tQualifiedReferences.Count() = 0) {
			Set tMsg = $$$FormatText("Could not find satisfactory version of %1 in any repositories. Required by: %2",tDep.Name,$ListToString(tConstraintList,"; "))
			Set tSC = $$$ERROR($$$GeneralError,tMsg)
			Quit
		} Else {
			For j=1:1:tQualifiedReferences.Count() {
				Kill tDependencyGraph,tSubModules
				Merge tDependencyGraph = pDependencyGraph
				Merge tSubModules = pSubModules
				Set tQualifiedReference = tQualifiedReferences.GetAt(j)
				Set tSC = tRepositoryManager.RetrieveModuleManifest(tQualifiedReference,.tManifest)
				$$$ThrowOnError(tSC)
				
				// Recursively process dependencies.
				Set tMsg = "Error reading module manifest for %1 %2 from repository %3"
				Set tOuterSC = $$$ERROR($$$GeneralError,$$$FormatText(tMsg,tQualifiedReference.Name,tQualifiedReference.VersionString,tQualifiedReference.ServerName))
				
				#dim tModule As %IPM.Storage.Module
				Set tReader = ##class(%XML.Reader).%New()
				Set tSC = tReader.OpenStream(tManifest)
				If $$$ISERR(tSC) {
					Set tSC = $System.Status.EmbedStatus(tOuterSC,tSC)
					$$$ThrowOnError(tSC)
				}
				Do tReader.Correlate("Module","%IPM.Storage.Module")
				Do tReader.Next(.tModule,.tSC)
				If $$$ISERR(tSC) {
					Set tSC = $System.Status.EmbedStatus(tOuterSC,tSC)
					$$$ThrowOnError(tSC)
				}
				
				Set tDepth = $Select(tPreviousDepth=0:pDepth,tPreviousDepth>pDepth:tPreviousDepth,1:pDepth)
				
				If (pPass = $$$EXACT) {	
					Set pDependencyGraph(tDep.Name) = $ListBuild(pDepth,tQualifiedReference.ServerName,tModule.VersionString, tModule.State.State)
					Set pDependencyGraph(tDep.Name,..Name_" "_..VersionString) = tDep.VersionString
					Set pSubModules(tDepth,tDep.Name) = tModule
					Set pSubModules(tDepth,tDep.Name,$$$SCOPE) = tDep.Scope
			
					// If we have an exact match, attempt to resolve exact dependencies recursively.
					Set newGraphConfig = pGraphConfig.%ConstructClone()
					Do newGraphConfig.SetGraph(.pDependencyGraph)
					Set newGraphConfig.Depth = pDepth+1
					Set newGraphConfig.Phases = tPhases
					Do newGraphConfig.SetSubModules(.pSubModules)
					Set newGraphConfig.ModulePath = tModulePath_$ListBuild(tDep.Name)
					// Failure to resolve any of these dependencies is an immediate failure, and can be descriptive.
					Do tModule.ConstructDependencyGraph(newGraphConfig)
					Do newGraphConfig.GetGraph(.pDependencyGraph)
					Do newGraphConfig.GetSubModules(.pSubModules)
					Quit
				}
				If (pPass = $$$FUZZY) {
					Set tDependencyGraph(tDep.Name) = $ListBuild(tDepth,tQualifiedReference.ServerName,tModule.VersionString, tModule.State.State)
					Set tDependencyGraph(tDep.Name,..Name_" "_..VersionString) = tDep.VersionString
			
					Set tSubModules(tDepth,tDep.Name) = tModule
				
					// For fuzzy version matching, preview the next graph step; move to the next version if it would lead to failure.
					// If not, update.
					Set newGraphConfig = pGraphConfig.%ConstructClone()
					Do newGraphConfig.SetGraph(.tDependencyGraph)
					Set newGraphConfig.Depth = pDepth+1
					Set newGraphConfig.Phases = tPhases
					Do newGraphConfig.SetSubModules(.tSubModules)
					Set newGraphConfig.ModulePath = tModulePath_$ListBuild(tDep.Name)
					// We have a match  - let's go with it. Actually dependency resolution will be done later, breadth-first.
					// TODO: Caching of results to avoid duplicate web service calls.
					Set findPossibleMatch = 1
					Try {
						Do tModule.ConstructDependencyGraph(newGraphConfig)
					} Catch e {
						Set findPossibleMatch = 0
					}
					If findPossibleMatch {
						Quit
					}
				}
			}
			$$$ThrowOnError(tSC)
			
			If (pPass = $$$FUZZY) {
				// We don't actually care if a valid result was found.
				// There will always be something in here, it just might lead to a descriptive error later on in the case of fuzzy matching with no valid option.
				Set pDependencyGraph(tDep.Name) = $ListBuild(pDepth,tQualifiedReference.ServerName,tModule.VersionString,tModule.State.State)
				Set pDependencyGraph(tDep.Name,..Name_" "_..VersionString) = tDep.VersionString
				Set pSubModules(tDepth,tDep.Name) = tModule
				Set pSubModules(tDepth,tDep.Name,$$$SCOPE) = tDep.Scope
			}
		}
	}
	$$$ThrowOnError(tSC)
	If (pPass = $$$EXACT) {	
		// Call for second pass (fuzzy version matching)
		Set newGraphConfig = pGraphConfig.%ConstructClone()
		Do newGraphConfig.SetGraph(.pDependencyGraph)
		Do newGraphConfig.SetSubModules(.pSubModules)
		Set newGraphConfig.Pass = $$$FUZZY
		Do ..ConstructDependencyGraph(newGraphConfig)
		Do newGraphConfig.GetGraph(.pDependencyGraph)
		Do newGraphConfig.GetSubModules(.pSubModules)
		$$$ThrowOnError(tSC)
	}
	// Breadth-first dependency resolution for depth 1, pass 1.
	// Things to resolve have been accumulated in previous passes and/or will continue to be accumulated.
	If (pDepth = 1) && (pPass = $$$EXACT) {
			While $Data(pSubModules(pDepth)) {	
			Set tModName = ""
			For {
				Set tModName = $Order(pSubModules(pDepth,tModName),1,tModule)
				Quit:tModName=""
				Set tModulePath = $Case(pSubModules(pDepth,tModName,$$$SCOPE),"":pModulePath,:"")
				Set newGraphConfig = pGraphConfig.%ConstructClone()
				Do newGraphConfig.SetGraph(.pDependencyGraph)
				Do newGraphConfig.SetSubModules(.pSubModules)
				Set newGraphConfig.Depth = pDepth+1
				Set newGraphConfig.Phases = tPhases
				Set newGraphConfig.ModulePath = tModulePath_$ListBuild(tModName)
				Do tModule.ConstructDependencyGraph(newGraphConfig)
				$$$ThrowOnError(tSC)
				Do newGraphConfig.GetGraph(.pDependencyGraph)
				Do newGraphConfig.GetSubModules(.pSubModules)
			}
			$$$ThrowOnError(tSC)
			Set pDepth = pDepth + 1
		}
		$$$ThrowOnError(tSC)
		
		
		// Ensure cyclic dependencies (possible with scopes) are removed from the graph; otherwise, not everything will be installed.
		Kill pDependencyGraph(..Name)
		Set tDependencyKey = ""
		For {
			Set tDependencyKey = $Order(pDependencyGraph(tDependencyKey))
			If (tDependencyKey = "") {
				Quit
			}
			
			Set tDependencySource = $Order(pDependencyGraph(tDependencyKey,..Name))
			If ($Piece(tDependencySource," ") = ..Name) {
				Kill pDependencyGraph(tDependencyKey,tDependencySource)
			}
		}
	}
	Do pGraphConfig.SetGraph(.pDependencyGraph)
	Do pGraphConfig.SetSubModules(.pSubModules)
}


ClassMethod Compare(Name As %String)
{
	kill module
	Set module=##class(%IPM.Storage.Module).NameOpen(Name)
	kill moduleGraph,trueModuleGraph
	kill configObj
	Set configObj = ##class(%IPM.Utils.DependencyGraphConfig).%New(Name)
	Do configObj.GetGraph(.moduleGraph)
	Set tSC = module.BuildDependencyGraph(.trueModuleGraph)
	Do configObj.GetGraph(.moduleGraph)
	zw moduleGraph
	zw trueModuleGraph
	kill module
	kill configObj
}

/// Modules that come from current installation do not have the proper state object
/// so set them using this method
/// no need for it once we build the kit with the version of IPM where module installation will set the state object
ClassMethod UpdateModulesFromInstall()
{
	Set res = ##class(%SQL.Statement).%ExecDirect(,"select Count(ID) As Number from %IPM_Storage.ModuleItem")
	If (res.%SQLCODE < 0) {
		Throw ##class(%Exception.SQL).CreateFromSQLCODE(res.%SQLCODE,res.%Message)
	}
	Set count = 0
	While res.%Next(.tSC) {
		$$$ThrowOnError(tSC)
		Write !,"Count: ",res.%Get("Number")
		
	}
	$$$ThrowOnError(tSC)
	Set stateobj = ##class(%IPM.Storage.ModuleState).%New()
	Set stateobj.State = "Installed"
	For i=1:1:count {
		Set tempModule=##class(%IPM.Storage.Module).%OpenId(i) 
		Set tempModule.State=stateobj 
		Set tSC = tempModule.%Save()
		$$$ThrowOnError(tSC)
	}
}

Storage Default
{
<Type>%Storage.Persistent</Type>
}

}