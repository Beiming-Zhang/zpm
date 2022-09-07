/// Defines an object that will be used to construct and temporarily store the dependency graph of a specific module
Class %IPM.Utils.DependencyGraphConfig Extends %RegisteredObject
{

/// Name of the module to build dependency graph for
Property Name As %String [ Required ];

/// Dependency graph of the module
/// Graph("<dependent module name>") = $ListBuild(<depth>,<server name>,<exact version>,<module state>)
/// Graph("<dependent module name>","<target module> <target module exact version>") = <dependent module semantic version>
Property Graph [ MultiDimensional ];

/// Depth of which the dependencies of the module are found and written to the graph
Property Depth As %Integer [ InitialExpression = 1 ];

/// When set to 1, if version of the dependent module is a snapshot version, force it to be loaded
Property ForceSnapshotReload As %Boolean [ InitialExpression = 0 ];

/// String of lifecycle phases separated by comma, used to check whether a dependency is a scoped one
Property Phases As %String [ InitialExpression = ""];

/// While Graph provides metadata of the depdencies, SubModules is a multi-dim array used to directly keep track of the depdency module object
/// SubModules(Depth,"<Dependency Name>") = module object
/// SubModules(tDepth,"<Dependency Name>","scope") = <scope(s) of the module object>
Property SubModules [ MultiDimensional ];

/// EXACT(1) run or FUZZY run (2) of the dependency graph construction 
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

}
