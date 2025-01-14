Class %IPM.Storage.SystemRequirements Extends (%Persistent, %XML.Adaptor)
{

Parameter DEFAULTGLOBAL = "^IPM.Storage.SystemRequirements";

Property VersionString As %String(MAXLEN = 100, XMLNAME = "Version", XMLPROJECTION = "ATTRIBUTE");

Property Version As %IPM.General.SemanticVersionExpression(XMLPROJECTION = "NONE");

Method VersionStringSet(tValue) As %Status
{
	Set i%VersionString = tValue
	Set tSC = ##class(%IPM.General.SemanticVersionExpression).FromString(tValue,.tExpression)
	If $$$ISOK(tSC) {
		Set ..Version = tExpression
	}
	Quit tSC
}

Property Interoperability As %String(VALUELIST = ",enabled,disabled", XMLPROJECTION = "ATTRIBUTE");

Method CheckRequirements() As %Status
{
	Set tSC1 = ..CheckVersion()
	Set tSC2 = ..CheckInteroperability()
	Return $$$ADDSC(tSC1, tSC2)
}

Method CheckVersion() As %Status
{
	Set tSystemMajor = $System.Version.GetMajor()
	Set tSystemMinor = $System.Version.GetMinor()
	If (..VersionString = "") { Return $$$OK } 
	Try {
		Set tComparator = ..Version.Options.GetAt(1).Comparators.GetAt(1)
		Set CurrentSystemVersion = ##class(%IPM.General.SemanticVersion).FromString($System.Version.GetNumber())
		If CurrentSystemVersion.Patch = "" { 
			Set CurrentSystemVersion.Patch = 0
		}
		If ('tComparator.Evaluate(CurrentSystemVersion)) {
			Return $$$ERROR($$$GeneralError,"The module cannot be installed on the current version ("_tSystemMajor_"."_tSystemMinor_") of the system, version """_..VersionString_""" is required")
		}
		Return $$$OK
	} Catch ex {
		Return $$$ERROR($$$GeneralError, "Unable to check reqired system version")
	}
}

Method CheckInteroperability() As %Status
{
 
	If ( (..Interoperability="enabled") && '##class(%EnsembleMgr).IsEnsembleNamespace($Namespace) ) {
		Return $$$ERROR($$$GeneralError, "The module requires Interoperability Production Enabled. Namespace <"_$Namespace_"> doesn't support Interoperability Production")
	}
	Return $$$OK
}

Storage Default
{
<Data name="SystemRequirementsDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>VersionString</Value>
</Value>
<Value name="3">
<Value>Version</Value>
</Value>
<Value name="4">
<Value>Interoperability</Value>
</Value>
</Data>
<DataLocation>^IPM.Storage.SystemRequirementsD</DataLocation>
<DefaultData>SystemRequirementsDefaultData</DefaultData>
<IdLocation>^IPM.Storage.SystemRequirementsD</IdLocation>
<IndexLocation>^IPM.Storage.SystemRequirementsI</IndexLocation>
<StreamLocation>^IPM.Storage.SystemRequirementsS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
