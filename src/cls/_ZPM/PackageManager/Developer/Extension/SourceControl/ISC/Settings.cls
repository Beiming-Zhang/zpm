Class %ZPM.PackageManager.Developer.Extension.SourceControl.ISC.Settings Extends %ZPM.PackageManager.Developer.AbstractSettings
{

/// A string to show in the grouping of settings for this class
Parameter DESCRIPTION = "Perforce integration options";

/// An inherited IDKey index on this property means that the default value is
/// used as a subscript under <DataLocation> in the storage definition.
Property Key As %String [ InitialExpression = {$classname()}, ReadOnly ];

/// Automatically mark new resources for add in the "Validate" phase
Property AutoAdd As %Boolean [ InitialExpression = 0, Required ];

/// Automatically move files in Perforce when they are relocated from one module to another
/// (assuming both the source and target module are tied to Perforce, and the file had been marked
/// for add in the original location)
Property AutoMove As %Boolean [ InitialExpression = 1, Required ];

/// Regular expression for filenames to ignore in automatic move/mark for add (in ICU syntax used by IRIS).
/// Tested with ($Locate(<full file path>,settings.FilenameIgnoreExpression) > 0); ending the expression with $ is a useful
/// way to test the end of the string (for example, to exclude certain extensions while allowing the rest of the path to
/// contain them).
Property FilenameIgnoreExpression As %String(MAXLEN = "") [ InitialExpression = "(\.DS_Store|.bak)$" ];

/// Sees if <var>pFileName</var> is acceptable based on <property>FilenameIgnoreExpression</property> - i.e., returns 1 if the filename should be ignored, 0 if it should not be.
Method IgnoreFileName(pFileName As %String, Output pSC As %Status = {$$$OK}) As %Boolean
{
	Set tIgnoreFilename = 0
	Try {
		If ..FilenameIgnoreExpression '= "" {
			Set tIgnoreFilename = ($Locate(pFileName,..FilenameIgnoreExpression) > 0)
		}
	} Catch e {
		// Callers may choose to report such errors - rather than an unhelpful <REGULAR EXPRESSION> system error,
		// specifically mention the regular expression that caused the issue. 
		If (e.Name = "<REGULAR EXPRESSION>") {
			Set pSC = $$$ERROR($$$GeneralError,$$$FormatText("Invalid regular expression in FilenameIgnoreExpression setting: %1",..FilenameIgnoreExpression))
		} Else {
			Set pSC = e.AsStatus()
		}
	}
	Quit tIgnoreFilename
}

/// Validates <property>FilenameIgnoreExpression</property> by testing it and ensuring no errors occur.
Method %OnValidateObject() As %Status [ Private, ServerOnly = 1 ]
{
	Do ..IgnoreFileName("",.tSC)
	Quit tSC
}

/// This class has storage mapped to the global that stores other namespace-specific source control-related settings. The index and stream globals are expected to never be used.
Storage Default
{
<Data name="SettingsDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>AutoAdd</Value>
</Value>
<Value name="3">
<Value>AutoMove</Value>
</Value>
<Value name="4">
<Value>FilenameIgnoreExpression</Value>
</Value>
</Data>
<DataLocation>^SYS("SourceControl")</DataLocation>
<DefaultData>SettingsDefaultData</DefaultData>
<Description>
<![CDATA[This class has storage mapped to the global that stores other namespace-specific source control-related settings. The index and stream globals are expected to never be used.]]></Description>
<IdLocation>^SYS("SourceControl")</IdLocation>
<IndexLocation>^SYS("SourceControl","%ZPM.PackageManager.Developer.Extension.SourceControl.ISC.SettingsI")</IndexLocation>
<StreamLocation>^SYS("SourceControl","%ZPM.PackageManager.Developer.Extension.SourceControl.ISC.SettingsS")</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
