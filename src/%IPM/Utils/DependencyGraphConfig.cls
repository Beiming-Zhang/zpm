Class %IPM.Utils.DependencyGraphConfig Extends %RegisteredObject
{

/// Name of the module to build dependency graph for
Property Name As %String [ Required ];

Property Graph [ MultiDimensional ];

Property Depth As %Integer [ InitialExpression = 1 ];

Property ForceSnapshotReload As %Boolean [ InitialExpression = 0 ];

Property Phases As %String [ InitialExpression = ""];

Property SubModules [ MultiDimensional ];

Property Pass As %Integer [ InitialExpression = 1 ];

/// Modules that the building process of the graph has walked through
Property ModulePath As %List;

Property IgnoreInstalledModules As %Boolean [ InitialExpression = 0 ];

Property KnownDependencies As %List;

Property PermitDowngrade As %Boolean [ InitialExpression = 0 ];

Property CheckNestedScoped As %Boolean [ InitialExpression = 0 ];

Method %OnNew(pName As %String) As %Status [ Internal, Private ]
{
	Set ..Name = pName
	Set ..KnownDependencies = ##class(%IPM.Storage.Module).GetKnownDependencies(..Name)
	Set ..ModulePath = $ListBuild(..Name)
	Quit $$$OK
}

Method SetGraph(ByRef pGraph)
{
	Kill ..Graph
    Merge ..Graph = pGraph
}

Method GetGraph(Output pGraph)
{
	Merge pGraph = ..Graph
}

Method SetSubModules(ByRef pSubModules)
{
	Kill ..SubModules
    Merge ..SubModules = pSubModules
}

Method GetSubModules(Output pSubModules)
{
	Merge pSubModules = ..SubModules
}

/// Copy non-multidim fields of an config to a branch-new config object
ClassMethod CreateConfigCopy(pConfigObj As %IPM.Utils.DependencyGraphConfig, pName As %String) As %IPM.Utils.DependencyGraphConfig
{
	Set newGraphConfig = ##class(%IPM.Utils.DependencyGraphConfig).%New(pConfigObj)
	Set newGraphConfig.Depth = pConfigObj.Depth
	Set newGraphConfig.ForceSnapshotReload = pConfigObj.ForceSnapshotReload
	Set newGraphConfig.Phases = pConfigObj.Phases
	Set newGraphConfig.ModulePath = pConfigObj.ModulePath
	Set newGraphConfig.IgnoreInstalledModules = pConfigObj.IgnoreInstalledModules
	Set newGraphConfig.KnownDependencies = pConfigObj.KnownDependencies
	Set newGraphConfig.PermitDowngrade = pConfigObj.PermitDowngrade
	Quit newGraphConfig
}

}
