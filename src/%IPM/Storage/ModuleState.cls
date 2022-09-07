/// Used to track the current state and state info of a module
Class %IPM.Storage.ModuleState Extends (%SerialObject, %IPM.Utils.ComparisonAdaptor)
{

Parameter DEFAULTGLOBAL = "^IPM.Storage.ModuleState";

Parameter NAMESPACE As STRING = "http://www.intersystems.com/PackageManager";

/// Whether the module has been installed without issue, or is in a troubled state if the last activation or any phase before it failed
/// If troubled, LastError property should contain error and LastPhase should contain last successful phase.
Property State As %String(VALUELIST = ",Installed,Troubled");

/// Last error that occurs before the installation failed
Property LastError As %Status;

/// Last sucessful phase
Property LastPhase As %String;

Storage Default
{
<Data name="ModuleStateState">
<Value name="1">
<Value>State</Value>
</Value>
<Value name="2">
<Value>LastError</Value>
</Value>
<Value name="3">
<Value>LastPhase</Value>
</Value>
</Data>
<State>ModuleStateState</State>
<StreamLocation>^IPM.Storage.ModuleStateS</StreamLocation>
<Type>%Storage.Serial</Type>
}

}
