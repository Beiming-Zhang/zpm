Class %ZPM.PackageManager.Developer.Extension.SourceControl.ISC.PerforceFile Extends %RegisteredObject
{

/// Perforce depot path to file in question
Property depotFile As %String(MAXLEN = "");

/// This is a %String rather than %Integer because it could be "default"
Property change As %String;

/// Pending action for file
Property action As %String;

ClassMethod CreateFromFStatOutput(ByRef pArray) As %ZPM.PackageManager.Developer.Extension.SourceControl.ISC.PerforceFile
{
	Set tInstance = ..%New()
	For tProp = "depotFile","change","action" {
		Set $Property(tInstance,tProp) = $Get(pArray(tProp))
	}
	Quit tInstance
}

Method ToString() As %String
{
	Quit ..depotFile_$Case(..change,"":"",:" - "_..action_" in changelist "_..change)
}

}
