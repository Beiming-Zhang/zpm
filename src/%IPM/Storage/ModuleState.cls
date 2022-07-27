Class %IPM.Storage.ModuleState Extends %IPM.Utils.ComparisonAdaptor
{

Property State As %String(VALUELIST = ",Installed,Troubled", XMLPROJECTION = "NONE");

Property LastError As %Status;

Property LastPhase As %String;

}
