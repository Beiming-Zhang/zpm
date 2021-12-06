Include (%ZPM.PackageManager.Common, %occErrors)

/// This class works parallel to %ZPM.PackageManager.Developer.Document.Module in order to support the zpm extension
Class %ZPM.PackageManager.Developer.Document.ZPM Extends %ZPM.PackageManager.Developer.Document.Module
{

Projection RegisterExtension As %ZPM.PackageManager.Developer.Document.Projection(DocumentDescription = "Application Module", DocumentExtension = "ZPM", DocumentNew = 1, DocumentType = "xml", XMLNamespace = "http://www.intersystems.com/PackageManager");

Parameter EXTENSION = ".ZPM";

Parameter INFOGLOBAL = "^ZPM.Dev.Doc.ZPM";

}
