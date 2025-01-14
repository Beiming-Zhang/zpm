Include (%occSAX, %syGluedef, %IPM.Formatting)

Class %IPM.CLI Extends %IPM.CLI.Commands
{

/// Name of include file that will contain accessor macros for modifiers
/// and parameters referenced in the "Commands" XData block. <br />
/// If provided, an include file will be generated and included in the sub-class
/// during compilation. <br />
/// @API.Parameter
/// @API.Overrideable
Parameter CommandsAccessorIncludeFilename As STRING;

/// Displays help for a given command
ClassMethod %Help(ByRef pCommandInfo) [ Final ]
{
	Set tCommand = $Get(pCommandInfo("parameters","command"))
	Set tVerbose = ''$Data(pCommandInfo("modifiers","verbose"))
	Set tMarkdown = ''$Data(pCommandInfo("modifiers","markdown"))
	Do ..%GetCommandStructure(.tCommandStruct)
	
	If (tCommand '= "") && '$Data(tCommandStruct(tCommand)) {
		// See if it's an alias. (If not, we'll show help for everything.)
		If '$Data(tCommandStruct(1,tCommand),tCommand) {
			Write !, $$$FormattedLine($$$Red, "WARNING: Command "_$$$QUOTE(tCommand)_" does not exist so showing all available commands.")
			Write !
		}
	}
	
	// Single command
	If (tCommand '= "") && (tCommand '= +tCommand) && $Data(tCommandStruct(tCommand)) {
		Kill tOneCommandStruct
		Merge tOneCommandStruct = tCommandStruct(tCommand)
		Do ..%HelpForCommand(tCommand,.tOneCommandStruct,1,tMarkdown)
	} Else {
		// For markdown mode only, merge aliases into main part of tCommandStruct array.
		// This gets the commands in alphabetical order.
		If tMarkdown {
			Set tCommand = ""
			For {
				Set tCommand = $Order(tCommandStruct(1,tCommand))
				If (tCommand = "") {
					Quit
				}
				
				Set tCommandStruct(tCommand) = tCommandStruct(1,tCommand)
			}
		}
		
		// List commands
		If 'tMarkdown {
			Write !, $$$FormattedLine($$$Underlined, "Available commands:")
			Write !
		}
		Set tCommand = ""
		While 1 {
			Set tCommand = $Order(tCommandStruct(tCommand))
			If (tCommand = "") {
				Quit
			}
			// Skip numbered subscripts.
			If (tCommand = +tCommand) {
				Continue
			}
			
			Kill tOneCommandStruct
			Merge tOneCommandStruct = tCommandStruct(tCommand)
			Do ..%HelpForCommand(tCommand,.tOneCommandStruct,tVerbose,tMarkdown,$Get(tCommandStruct(-1, "maxLength"),0))
			
			Write !
		}
		
		If 'tVerbose {
			Write !!, "For more detail, run:", !?2, "help <command-name>", !, "or", !?2, "help -v"
		}
	}
	Write !
}

ClassMethod %HelpForCommand(pCommandName As %String, ByRef pCommandStruct, pDetailed As %Boolean = 0, pMarkdownFormat As %Boolean = 0, pMaxLength As %Integer = 0)
{
	/*
	 * Structure on Terminal is adapted from git help
	 */
	
	/// Section separator in Markdown
	#define SectionSeparator $Case(pMarkdownFormat, 1: "-----", : "")
	// Macro to format strings if printing to terminal and to escape if in markdown
	#define EscapeOrFormat(%string, %format) $Case(pMarkdownFormat, 1:$Replace(%string, "|", "\|"), :$$$FormattedLine(%format, %string))
	// Bullet point if in Terminal
	#define BulletPoint $Case(pMarkdownFormat, 1: "", :$Char(9675)_" ")
	// Black square if in Terminal. No longer used but kept in case we want to use it again in future
	#define BlackSquare $Case(pMarkdownFormat, 1: "", :$Char(9632)_" ")
	
	Set tIndent = 4
	Set tIsAlias = $Data(pCommandStruct)<10
	If pMarkdownFormat && tIsAlias {
		Write !, "##"_pCommandName
		Write !, "_Alias for ["_pCommandStruct_"](#"_pCommandStruct_")_"
		Write !, $$$SectionSeparator
	}
	
	// Don't show full documentation for aliases 
	// This will only happen when displaying all documentation for Markdown
	If tIsAlias {
		Return
	}
	
	If '(pDetailed) {
		Set tIndent = 10
		If (pMaxLength > tIndent) {
			// Do twice max length to account for aliases (which are usually shorter so this should be sufficient)
			Set tIndent = 2 * pMaxLength + 2
		}
		// Command name and aliases
		Write !, pCommandName
		If $Data(pCommandStruct("aliases"), tAliases) {
			Write ", "_$Replace(tAliases, ",", ", ")
		}
		// Summary
		If $Data(pCommandStruct("summary"), tSummary) {
			Write ?tIndent, $ZStrip(tSummary, "<>CW")
		} ElseIf $Data(pCommandStruct("description"), tDescription) {
			Write ?tIndent, $ZStrip(tDescription, "<>CW")
		}
	} Else {
		// Command name and format
		If pMarkdownFormat {
			Write "## "
		}
		Write $$$EscapeOrFormat(pCommandName, $$$Red)
		If pMarkdownFormat {
			Write !, "**Syntax:** `", pCommandName
		}
		If $Data(pCommandStruct("modifiers")) && '$Get(pCommandStruct("trailingModifiers"),0) {
			Write $$$EscapeOrFormat(" [flags]", $$$Red)
		}
		
		If $Data(pCommandStruct("parameters")) {
			Set tKey = ""
			Set tEndingBrackets = 0
			While 1 {
				Set tKey = $Order(pCommandStruct("parameters",tKey),1,tParamName)
				// Only deal with ordered parameters, not named
				If (tKey = "") || (tKey '= +tKey) {
					Quit
				}
				Write " "
				// Non-required parameters are surrounded with [] brackets
				If 'pCommandStruct("parameters", tParamName, "required") {
					Write $$$EscapeOrFormat("[", $$$Red)
					Set tEndingBrackets = tEndingBrackets + 1
				}
				Write $$$EscapeOrFormat("<"_tParamName_">", $$$Red)
			}
			
			For i=1:1:tEndingBrackets {
				Write $$$EscapeOrFormat("]", $$$Red)
			}
		}
		
		If $Data(pCommandStruct("modifiers")) && $Get(pCommandStruct("trailingModifiers"),0) {
			Write $$$EscapeOrFormat(" [flags]", $$$Red)
		}
		If pMarkdownFormat {
			Write "`"
		} Else {
			Write !, "NOTE: [] around an argument indicates it is optional. Flags are always optional"
		}

		// Aliases
		Write !
		If $Data(pCommandStruct("aliases"), tAliases) {
			Set tAliases = $Replace(tAliases, ",", ", ")
			If pMarkdownFormat {
				Write !, "**Alias(es):** "_tAliases
			} Else {
				Write !, $$$EscapeOrFormat("ALIAS"_$Case($Length(tAliases, ","), 1:"", :"ES")_": ",$$$Bold)_tAliases
			}
			Write !
		}

		// Description
		If $Data(pCommandStruct("description"), tDescription) {
			Write !
			If pMarkdownFormat {
				// Strip all leading AND trailing white space + control characters
				Write "**Description:** "_$ZStrip(tDescription, "<>CW")
			} Else {
				Write $$$EscapeOrFormat("DESCRIPTION:",$$$Bold)
				// Strip trailing control characters and white space. Indentation is handled
				// by formatting correctly within the Commands XData block
				Write !, $ZStrip(tDescription, ">CW")
			}
		}

		// Arguments
		If $Data(pCommandStruct("parameters")) {
			Write !!
			If (pMarkdownFormat) {
				Write "### Arguments"
			} Else {
				Write $$$EscapeOrFormat("ARGUMENTS:",$$$Bold)
			}
			If pMarkdownFormat {
				Write !, "| Name | Description |"
				Write !, "| "_$$$SectionSeparator_" | "_$$$SectionSeparator_" |"
			}
			Set tKey = ""
			For {
				Set tKey = $Order(pCommandStruct("parameters",tKey),1,tParamName)
				If (tKey = "") || (tKey '= +tKey) {
					// Only deal with ordered parameters, not named
					Quit
				}
				
				Write !
				If pMarkdownFormat {
					Write "| "
				} Else {
					Write ?(tIndent*2)
				}
				Write $$$BulletPoint_tParamName
				If pMarkdownFormat {
					Write " | "
				}
				
				Kill tParamInfo
				Merge tParamInfo = pCommandStruct("parameters",tParamName)
				If ($Data(tParamInfo("description"), tDescription)) {
					If pMarkdownFormat {
						Write $ZStrip(tDescription, "<>CW")
					} Else {
						Write ": "_tDescription
					}
				}
				If pMarkdownFormat {
					Write " |"
				}
			}
		}

		// Modifiers
		If $Data(pCommandStruct("modifiers")) {
			Write !!
			If (pMarkdownFormat) {
				Write "### Flags"
			} Else {
				Write $$$EscapeOrFormat("FLAGS:",$$$Bold)
			}
			If pMarkdownFormat {
				Write !, "| Flag | Description |"
				Write !, "| "_$$$SectionSeparator_" | "_$$$SectionSeparator_" |"
			}
			Set tKey = 1000
			While 1 {
				Set tKey = $Order(pCommandStruct("modifiers",tKey))
				If (tKey = "") {
					Quit
				}
				Write !
				If pMarkdownFormat {
					Write "| "
				} Else {
					Write ?(tIndent*2)
				}
				Kill tModInfo
				Merge tModInfo = pCommandStruct("modifiers",tKey)

				Set tFlagList = $ListBuild(tKey)
				If ($Data(tModInfo("aliases"),tAliases)) {
					Set tFlagList = tFlagList _ $ListFromString(tAliases, ",")
				}
				Set tValueAppend = ""
				If $Get(tModInfo("value")) {
					Set tValueAppend = $Case($Data(tModInfo("valueList"),tValueList),
						1: " <"_$Replace(tValueList,",","/")_">",
						 : " <value>")
				}
				Set tPtr = 0
				Set tAppendedFlagList = ""
				While $ListNext(tFlagList, tPtr, tFlag) {
					Set tAppendedFlagList = tAppendedFlagList _ $ListBuild("-"_tFlag_tValueAppend)
				}
				Write $ListToString(tAppendedFlagList, ", ")

				If pMarkdownFormat {
					Write " | "
				}
				If ($Data(tModInfo("description"),tDescription)) {
					If pMarkdownFormat {
						Write $ZStrip(tDescription, "<>CW")
					} Else {
						Write !, ?(tIndent*4), tDescription
					}
				}
				If pMarkdownFormat {
					Write " |"
				}
			}
		}
		
		// Examples
		If $Data(pCommandStruct("examples")) {
			Write !!
			If (pMarkdownFormat) {
				Write "### Examples"
			} Else {
				Write $$$EscapeOrFormat("EXAMPLES:",$$$Bold)
			}
			If pMarkdownFormat {
				Write !,"| Command | Description |"
				Write !, "| "_$$$SectionSeparator_" | "_$$$SectionSeparator_" |"
			}
			Set tKey = ""
			For {
				Set tKey = $Order(pCommandStruct("examples",tKey))
				If (tKey = "") {
					Quit
				}
				Set tExampleDescription = $Get(pCommandStruct("examples",tKey,"description"))
				Set tExample = $ZStrip(pCommandStruct("examples",tKey), "<>WC")
				If pMarkdownFormat {
					Write !, "| `"_tExample_"` | "_tExampleDescription_" |"
				} Else {
					Write !, ?(tIndent*2), $$$BulletPoint_tExampleDescription
					Write !!, ?(tIndent*4), "zpm """, tExample, """", !
				}
			}
		}

		// End with horizontal line in markdown
		Write !, $$$SectionSeparator, !
	}
}

/// Parses a command, validating it based on the Commands XData block and structuring output as follows:
/// pCommandInfo = "<command name>"
/// pCommandInfo("modifiers","<modifier-name>") = "<modifier-value>"
/// pCommandInfo("parameters","<parameter-name>") = "<parameter-value>"
/// pCommandInfo("data","<data-name>") = "<data-value>"
ClassMethod %ParseCommandInput(pCommandString As %String, Output pCommandInfo) As %Status [ Final ]
{
	Set tSC = $$$OK
	Kill pCommandInfo
	Try {
		Do ..%GetCommandStructure(.tCommandStructure)
		
		// Parser states:
		// 0 - looking for next item (following a space)
		// 1 - in command
		// 2 - in modifier identifier
		// 3 - in modifier value
		// 4 - in quoted modifier value
		// 5 - in parameter value
		// 6 - in quoted parameter value
		// 7 - just saw the escape character (\) while in a quoted string
		// 8 - in a trailing parameter, so capture the rest of the string as the final parameter (including spaces)
		// 9 - in the name for a data element (following command's dataPrefix)
		
		#define PREARGUMENT 0
		#define COMMAND 1
		#define MODIFIERNAME 2
		#define MODIFIERVALUE 3
		#define MODIFIERVALUEQUOTED 4
		#define PARAMETERVALUE 5
		#define PARAMETERVALUEQUOTED 6
		#define ESCAPECHAR 7
		#define TRAILINGPARAMETERVALUE 8
		#define DATANAME 9
		
		Set tState = $$$COMMAND
		Set tPos = 1
		Set tAccum = ""
		Set tModifier = ""
		Set tDataName = ""
		Set tParamCount = 0
		Set tPreEscapeState = ""
		For {
			Set tChar = $Extract(pCommandString,tPos)
			Set tPos = tPos + 1
			
			If (tState = $$$ESCAPECHAR) {
				If (tChar '= """") && (tChar '= "\") {
					Set tAccum = tAccum_"\"
				}
			}
			
			If (tChar = " ") || (tChar = "") {
				If (tState = $$$COMMAND) && (tAccum'="") {
					If $Data(tCommandStructure(tAccum)) {
						// tAccum contains command name.
						Set pCommandInfo = tAccum
					} ElseIf $Data(tCommandStructure(1,tAccum),tAliasFor) {
						// tAccum contains an alias - use the real name.
						Set pCommandInfo = tAliasFor
					} ElseIf $Data(tCommandStructure(0,"default"),tDefaultCommand) {
						// tAccum just got the first parameter, so pass it along to the default command.
						Set pCommandInfo = tDefaultCommand
						Set tParamName = $Get(tCommandStructure(tDefaultCommand,"parameters",$Increment(tParamCount)))
						If (tParamName = "") {
							$$$ThrowStatus($$$ERROR($$$GeneralError,$$$FormatText("Too many parameters to command '%1'; only %2 expected.",pCommandInfo,tParamCount-1)))
						}
						Set pCommandInfo("parameters",tParamName) = tAccum
					} Else {
						$$$ThrowStatus($$$ERROR($$$GeneralError,$$$FormatText("Unknown command: %1",tAccum)))
					}
					Set tAccum = ""
					Set tState = $$$PREARGUMENT
				} ElseIf (tState = $$$MODIFIERNAME) {
					If $Data(tCommandStructure(pCommandInfo,"modifiers",tAccum)) {
						Set tModifier = tAccum
					} ElseIf $Data(tCommandStructure(pCommandInfo,"modifiers",1,tAccum),tAliasFor) {
						Set tModifier = tAliasFor
					} Else {
						$$$ThrowStatus($$$ERROR($$$GeneralError,$$$FormatText("Unknown modifier for command '%1': %2",pCommandInfo,tAccum)))
					}
					If $Data(tCommandStructure(pCommandInfo,"modifiers",tModifier,"dataAlias"),tDataAlias) {
						Set tDataName = tDataAlias
						If $Data(tCommandStructure(pCommandInfo,"modifiers",tModifier,"dataValue"),tDataValue) {
							Do ..SetData(.pCommandInfo,tDataAlias,tDataValue)
							Set tState = $$$PREARGUMENT
						} Else {
							Set tState = $$$MODIFIERVALUE
						}
					} ElseIf tCommandStructure(pCommandInfo,"modifiers",tModifier,"value") {
						Set tState = $$$MODIFIERVALUE
					} Else {
						Set pCommandInfo("modifiers",tModifier) = ""
						Set tState = $$$PREARGUMENT
					}
					Set tAccum = ""
				} ElseIf (tState = $$$MODIFIERVALUE) {
					If ($Get(tDataName) '= "") {
						Do ..SetData(.pCommandInfo,tDataName,tAccum,1)
						Set tDataName = ""
					} Else {
						Set pCommandInfo("modifiers",tModifier) = tAccum
					}
					Set tAccum = ""
					Set tState = $$$PREARGUMENT
				} ElseIf (tState = $$$PARAMETERVALUE) || ((tState = $$$TRAILINGPARAMETERVALUE) && (tChar = "")) {
					Set tParamName = $Get(tCommandStructure(pCommandInfo,"parameters",$Increment(tParamCount)))
					If (tParamName = "") {
						$$$ThrowStatus($$$ERROR($$$GeneralError,$$$FormatText("Too many parameters to command '%1'; only %2 expected.",pCommandInfo,tParamCount-1)))
					}
					Set pCommandInfo("parameters",tParamName) = tAccum
					Set tAccum = ""
					Set tState = $$$PREARGUMENT
				} ElseIf (tState = $$$TRAILINGPARAMETERVALUE) {
					Set tAccum = tAccum_tChar
				}
				
				If '((tState = $$$MODIFIERVALUEQUOTED) || (tState = $$$PARAMETERVALUEQUOTED)) {
					Quit:(tChar="")
					Continue
				}
			} ElseIf (tChar = "-") {
				If (tState = $$$PREARGUMENT) {
					Set tState = $$$MODIFIERNAME
					Set tModifier = ""
					Continue
				} ElseIf ((tState = $$$PARAMETERVALUE) || (tState = $$$TRAILINGPARAMETERVALUE))
					&& $Get(tCommandStructure(pCommandInfo,"trailingModifiers")) {
						Set tParamName = $Get(tCommandStructure(pCommandInfo,"parameters",$Increment(tParamCount)))
						If (tParamName = "") {
							$$$ThrowStatus($$$ERROR($$$GeneralError,$$$FormatText("Too many parameters to command '%1'; only %2 expected.",pCommandInfo,tParamCount-1)))
						}
						If ($Extract(tAccum,*) = " ") {
							Set pCommandInfo("parameters",tParamName) = $Extract(tAccum,1,*-1) // Strip the space.
						} Else {
							Set pCommandInfo("parameters",tParamName) = tAccum
						}
						Set tAccum = ""
						Set tState = $$$MODIFIERNAME
						Set tModifier = ""
						Continue
					}
			} ElseIf (tChar = "\") {
				If (tState = $$$MODIFIERVALUEQUOTED) || (tState = $$$PARAMETERVALUEQUOTED) {
					Set tPreEscapeState = tState
					Set tState = $$$ESCAPECHAR
					Continue
				}
			} ElseIf (tChar = """") {
				If (tState = $$$PREARGUMENT) {
					Set tState = $$$PARAMETERVALUEQUOTED
					Continue
				} If (tState = $$$MODIFIERVALUE) && (tAccum = "") {
					Set tState = $$$MODIFIERVALUEQUOTED
					Continue
				} ElseIf (tState = $$$PARAMETERVALUE) && (tAccum = "") {
					Set tState = $$$PARAMETERVALUEQUOTED
					Continue
				} ElseIf (tState = $$$MODIFIERVALUEQUOTED) {
					If ($Get(tDataName) '= "") {
						Do ..SetData(.pCommandInfo,tDataName,tAccum,1)
					} Else {
						Set pCommandInfo("modifiers",tModifier) = tAccum
					}
					Set tAccum = ""
					Set tState = $$$PREARGUMENT
					Continue
				} ElseIf (tState = $$$PARAMETERVALUEQUOTED) {
					Set tParamName = $Get(tCommandStructure(pCommandInfo,"parameters",$Increment(tParamCount)))
					If (tParamName = "") {
						$$$ThrowStatus($$$ERROR($$$GeneralError,$$$FormatText("Too many parameters to command '%1'; only %2 expected.",pCommandInfo,tParamCount-1)))
					}
					Set pCommandInfo("parameters",tParamName) = tAccum
					Set tAccum = ""
					Set tState = $$$PREARGUMENT
					Continue
				}
			} ElseIf (tChar = "=") {
				If (tState = $$$DATANAME) {
					Set tDataName = tAccum
					Set tState = $$$MODIFIERVALUE
					Set tAccum = ""
					Continue
				}
			} Else {
				If (tState = $$$PREARGUMENT) {
					Set tParamName = $Get(tCommandStructure(pCommandInfo,"parameters",tParamCount+1))
					If (tParamName = "") {
						$$$ThrowStatus($$$ERROR($$$GeneralError,$$$FormatText("Too many parameters to command '%1'; only %2 expected.",pCommandInfo,tParamCount)))
					}
					If $Get(tCommandStructure(pCommandInfo,"parameters",tParamName,"trailing")) {
						Set tState = $$$TRAILINGPARAMETERVALUE
					} Else {
						Set tState = $$$PARAMETERVALUE
						Set tEndPos = $Locate(pCommandString, "\s", tPos)
						If (tEndPos > 0) {
							Set tAccum = tChar_ $Extract(pCommandString, tPos, tEndPos - 1)
						} Else {
							Set tAccum = tChar_ $Extract(pCommandString, tPos, *)
						}
						Set tPos = tEndPos
						Continue
					}
				} ElseIf (tState = $$$MODIFIERNAME) {
					Set tDataPrefix = $Get(tCommandStructure(pCommandInfo,"dataPrefix"))
					If (tAccum = "") && (tDataPrefix '= "") && (tChar = tDataPrefix) {
						Set tState = $$$DATANAME
						Set tDataName = ""
						Continue
					}
				}
			}
			
			If (tChar = "") {
				$$$ThrowStatus($$$ERROR($$$GeneralError,$$$FormatText("Invalid trailing input: %1",tAccum)))
			}
			
			// Default: accumulate
			Set tAccum = tAccum _ tChar
			
			If (tState = $$$ESCAPECHAR) {
				Set tState = tPreEscapeState
			}
		}
		
		// TODO: Extra validation.
	} Catch e {
		If e.%IsA("%Exception.SystemException") {
			Set tSC = $System.Status.EmbedStatus($$$ERROR($$$GeneralError,$$$FormatText("Error parsing command: %1",pCommandString)),e.AsStatus())
		} Else {
			Set tSC = e.AsStatus()
		}
	}
	Quit tSC
}

/// Read JSON and construct a command matching the schema in the Commands XData blocks
/// that can be parsed using <method>%ParseCommandInput</method>. <br />
/// JSON format: <br />
/// {
/// 	"command": "command name",
/// 	"parameters": { ... },
/// 	"modifiers": { ... },
/// 	"custom_modifiers": { ... }
/// }
/// where each nested object contains key-value pairs.
ClassMethod ParseJsonToCommand(pJson As %Library.DynamicObject)
{
	Do ..%GetCommandStructure(.allCommandsArray)
	Set command = pJson.%Get("command")
	If (command = "") {
		$$$ThrowStatus($$$ERROR($$$GeneralError,"Missing 'command' property in JSON"))
	}
	Set quotedName = $$$QUOTE(command)
	If '$Data(allCommandsArray(command)) {
		$$$ThrowStatus($$$ERROR($$$GeneralError,"Command "_quotedName_" does not exist."))
	}
	Merge commandArray = allCommandsArray(command)
	
	/*
	 * NOTE: The below code does have a lot of common pieces to it
	 * that could be refactored to smaller helper methods but has
	 * been left this way for easier readability and understanding
	 */
	
	Set modList = ""
	#dim modifiers As %Library.DynamicObject
	Set modifiers = pJson.%Get("modifiers")
	If $IsObject(modifiers) {
		#dim modIter As %Iterator.Object
		Set modIter = modifiers.%GetIterator()
		While modIter.%GetNext(.key, .value) {
			Set modName = key
			// Check that modifier exists on command
			If '$Data(commandArray("modifiers", key)) {
				// Check if modifier is an alias. If so, set modName to actual modifier
				If '$Data(commandArray("modifiers", 1, key), modName) {
					$$$ThrowStatus($$$ERROR($$$GeneralError,"Invalid modifier: -"_modName_" does not exist for command "_quotedName))
				}
			}
			Set modHasValue = $Get(commandArray("modifiers", modName, "value"), 0)
			If modHasValue {
				// Ensure value is not ""
				If (value = "") {
					$$$ThrowStatus($$$ERROR($$$GeneralError,"Non-empty value required for modifier "_modName_" for command "_quotedName))
				}
			}
			// Validation passed so add to list
			Set modList = modList_$ListBuild("-"_modName)
			If modHasValue {
				Set modList = modList_$ListBuild(value)
			}
		}
	}
	
	Set paramList = ""
	#dim parameters As %Library.DynamicObject
	Set parameters = pJson.%Get("parameters")
	If $IsObject(parameters) {
		#dim paramIter As %Iterator.Object
		Set paramIter = parameters.%GetIterator()
		While paramIter.%GetNext(.key, .value) {
			// Check that parameter exists for command
			If '$Data(commandArray("parameters", key)) {
				$$$ThrowStatus($$$ERROR($$$GeneralError,"Invalid parameter: "_$$$QUOTE(key)_" does not exist for command "_quotedName))
			}
			If (value = "") {
				$$$ThrowStatus($$$ERROR($$$GeneralError,"Non-empty value required for parameter "_$$$QUOTE(key)_" for command "_quotedName))
			}
			// Validation passed so add to list
			Set paramList = paramList_$ListBuild(value)
		}
	}
	
	Set customModList = ""
	#dim customModifiers As %Library.DynamicObject
	Set customModifiers = pJson.%Get("custom_modifiers")
	If $IsObject(customModifiers) {
		// Get data prefix
		Set dataPrefix = $Get(commandArray("dataPrefix"))
		If (dataPrefix = "") {
			$$$ThrowStatus($$$ERROR($$$GeneralError,"Command "_quotedName_" does not support custom modifiers"))
		}
		#dim customModIter As %Iterator.Object
		Set customModIter = customModifiers.%GetIterator()
		While customModIter.%GetNext(.key, .value) {
			// Ensure value is not ""
			If (value = "") {
				$$$ThrowStatus($$$ERROR($$$GeneralError,"Non-empty value required for all custom modifiers but absent for "_$$$QUOTE(key)_" for command "_quotedName))
			}
			// Validation passed so add to list
			Set customModList = customModList_$ListBuild("-"_dataPrefix_key_"="_value)
		}
	}
	
	// Construct command
	Set hasTrailingModiifers = $Get(commandArray("trailingModifiers"),0)
	Set commandList = $ListBuild(command) _ $Case(hasTrailingModiifers, 1: paramList_modList, : modList_paramList) _ customModList
	Return $ListToString(commandList, " ")
}

ClassMethod %GetCommandStructure(Output pCommandStructure)
{
  Do ..%GetOneCommandStructure(.pCommandStructure)
}

/// Utility method for setting multiple subscripts based on .-delimited <var>pDataName</var>
ClassMethod SetData(pTargetArray, pDataName, pDataValue, pCustomParam = 0) [ Private ]
{
	If (pCustomParam && (pDataName'[".")) {
		Set pDataName = "zpm."_pDataName
	}
	Set tPieces = $ListFromString(pDataName,".")
	Set tValue = pDataValue
	For i=$ListLength(tPieces):-1:1 {
		Kill tData
		Merge tData($ListGet(tPieces,i)) = tValue
		Kill tValue
		Merge tValue = tData
	}
	Merge pTargetArray("data") = tValue
}

/// Draw a border around a list of strings. Optionally provide a text format for the strings. <br />
/// @Argument	pLineList		List of strings to write. <br />
/// @Argument	pTextFormat		Text format (e.g. $$$Red, $$$Bold, etc.). <br />
ClassMethod DrawBorder(pLineList As %Library.List, pTextFormat As %Integer = {$$$Default})
{
	// Find longest line in list
	Set ptr = 0
	Set maxLength = 0
	While $ListNext(pLineList, ptr, line) {
		Set lineLength = $Length(line)
		If (lineLength > maxLength) {
			Set maxLength = lineLength
		}
	}
	
	Set verticalBorderCharacter = "||"
	Set horizonatalBorderCharacter = "="
	
	Set horizontalBorder = ""
	For i=1:1:(maxLength + 6) {
		Set horizontalBorder = horizontalBorder _ horizonatalBorderCharacter
	}
	
	Write !, horizontalBorder
	Set ptr = 0
	While $ListNext(pLineList, ptr, line) {
		Write !, verticalBorderCharacter_" ", $$$FormattedLine(pTextFormat, line), ?(maxLength + 3), " "_verticalBorderCharacter
	} 
	Write !, horizontalBorder
	Write !
}

/// INTENDED USE: <br />
/// - Intended for developer use if there is a subclass of this class that implements the Commands XData block. <br />
/// WHAT IT DOES: <br />
/// - Generates an include file with name <parameter>CommandsAccessorIncludeFilename</parameter>. This contains macros
/// to be used to obtain subscripts of the subscripted array generated by <method>GetCommandStructure</method> rather
/// than directly accessing subscripts using strings. <br />
/// HOW TO USE: <br />
/// - Override <parameter>CommandsAccessorIncludeFilename</parameter>. <br />
/// - Call this method on the subclass. <br />
/// - Add the created include file to the top of the subclass. <br />
/// - Add the include file to source control. <br />
/// - Use macros from the include file to access subscripted values in the output
/// of <method>%GetCommandStructure</method> by passing the array as the only argument
/// to macros to obtain the value of a single subscript/check its existence. <br />
ClassMethod GenerateCommandsIncludeFile() [ Internal ]
{
	Do ..%GetCommandStructure(.commandStructure)
	
	// Array of lines to write to include file
	#dim lineArray As %String
	#define WriteLine(%line) Set lineArray($Increment(lineArray)) = %line
	
	// Names of subscripts
	Set modifierSubscript = "modifiers"
	Set parameterSubscript = "parameters"
	
	// Indicate how this was generated
	$$$WriteLine("#; Generated by: "_$Classname()_":GenerateCommandsIncludeFile")
	$$$WriteLine("")
	
	Set commandName = ""
	While 1 {
		Set commandName = $Order(commandStructure(commandName))
		If (commandName = "") {
			Quit
		}
		// Skip aliases
		If $IsValidNum(commandName) {
			Continue
		}
		// Skip if no modifiers or parameters
		If '($Data(commandStructure(commandName, modifierSubscript)) || $Data(commandStructure(commandName, parameterSubscript))) {
			Continue
		}
		
		Set formattedCommandName = ..FormatName(commandName)
		$$$WriteLine("#; Command: "_commandName)
		$$$WriteLine("")
		// Modifiers
		Set modifierName = ""
		While 1 {
			Set modifierName = $Order(commandStructure(commandName, modifierSubscript, modifierName))
			If (modifierName = "") {
				Quit
			}
			// Skip aliases
			If $IsValidNum(modifierName) {
				Continue
			}
			Set formattedModifierName = ..FormatName(modifierName)
			$$$WriteLine("/// Check for Modifier: "_modifierName)
			$$$WriteLine("#define HasMod"_formattedCommandName_formattedModifierName_"(%array) ''$Data(%array("_$$$QUOTE(modifierSubscript)_", "_$$$QUOTE(modifierName)_"))")
			// Only get modifier if it has value = true
			If +$Get(commandStructure(commandName, modifierSubscript, modifierName, "value")) {
				$$$WriteLine("/// Get Modifier: "_modifierName)
				$$$WriteLine("#define GetMod"_formattedCommandName_formattedModifierName_"(%array) $Get(%array("_$$$QUOTE(modifierSubscript)_", "_$$$QUOTE(modifierName)_"))")
			}
		}
		
		// Parameters
		Set parameterName = ""
		While 1 {
			Set parameterName = $Order(commandStructure(commandName, parameterSubscript, parameterName))
			If (parameterName = "") {
				Quit
			}
			// Skip aliases
			If $IsValidNum(parameterName) {
				Continue
			}
			Set formattedParameterName = ..FormatName(parameterName)
			$$$WriteLine("/// Check for Parameter: "_parameterName)
			$$$WriteLine("#define HasParam"_formattedCommandName_formattedParameterName_"(%array) ''$Data(%array("_$$$QUOTE(parameterSubscript)_", "_$$$QUOTE(parameterName)_"))")
			$$$WriteLine("/// Get Parameter: "_parameterName)
			$$$WriteLine("#define GetParam"_formattedCommandName_formattedParameterName_"(%array) $Get(%array("_$$$QUOTE(parameterSubscript)_", "_$$$QUOTE(parameterName)_"))")
		}
		
		// Blank line after all commands
		$$$WriteLine("")
	}
	Set filename = ..#CommandsAccessorIncludeFilename
	Do ##class(%IPM.Utils.Module).CreateOrUpdateIncludeFile(filename, .lineArray)
}

/// Format the given name such that all punctuation characters are remove and
/// the name is in camelCase, with the first letter capitalized. <br />
/// @Argument	pName		String to format. <br />
ClassMethod FormatName(pName As %String) As %String
{
	Set resultString = ""
	// First letter should always be capital
	Set letterCapital = 1
	For i=1:1:$Length(pName) {
		Set letter = $Extract(pName, i)
		// Special characters should be removed and next letter should be capitalized
		If ($ZStrip(letter, "*P") = "") {
			Set letterCapital = 1
			Continue
		}
		If letterCapital {
			Set letter = $$$ucase(letter)
			Set letterCapital = 0
		}
		Set resultString = resultString _ letter
	}
	Return resultString
}

ClassMethod TerminalPromptColor() As %String
{
	quit $Case(##class(%IPM.Repo.UniversalSettings).GetValue("TerminalPrompt"),"green":$$$Green,"red":$$$Red,"magenta":$$$Magenta,"yellow":$$$Yellow,"blue":$$$Blue,"cyan":$$$Cyan,"none":$$$Default,:$$$Default)
}

}
