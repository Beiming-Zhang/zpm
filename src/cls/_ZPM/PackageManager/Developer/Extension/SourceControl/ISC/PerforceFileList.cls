Class %ZPM.PackageManager.Developer.Extension.SourceControl.ISC.PerforceFileList Extends %Library.ListOfObjects
{

/// The type (class name) of the elements stored in the collection.
Parameter ELEMENTTYPE = "%ZPM.PackageManager.Developer.Extension.SourceControl.ISC.PerforceFile";

ClassMethod CreateFromFStatOutput(ByRef pArray) As %ZPM.PackageManager.Developer.Extension.SourceControl.ISC.PerforceFileList
{
	Set tInstance = ..%New()
	For tIndex=1:1:$Get(pArray) {
		Kill tOneFile
		Merge tOneFile = pArray(tIndex)
		Do tInstance.Insert(##class(%ZPM.PackageManager.Developer.Extension.SourceControl.ISC.PerforceFile).CreateFromFStatOutput(.tOneFile))
	}
	Quit tInstance
}

/// Displays the first <var>pMaxToShow</var> files from the list.
Method ToString(pJoiner = {$$$NL}, pMaxToShow = 25) As %String
{
	Set tItemList = ""
	Set tMaxIndex = $Select(..Count() < pMaxToShow:..Count(), 1:pMaxToShow)
	For tIndex=1:1:tMaxIndex {
		Set tItem = ..GetAt(tIndex)
		Set tItemList = tItemList_$ListBuild(tItem.ToString())
	}
	If (tMaxIndex < ..Count()) {
		Set tItemList = tItemList_$ListBuild("and "_(..Count() - tMaxIndex)_" other file(s)")
	}
	Quit $ListToString(tItemList,pJoiner)
}

Method IsEmpty()
{
	Quit (..Count() = 0)
}

Storage Custom
{
<Type>%Library.CompleteCustomStorage</Type>
}

}
