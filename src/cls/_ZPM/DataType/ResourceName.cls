Class %ZPM.DataType.ResourceName Extends %ZPM.DataType.RegExString [ ClassType = datatype ]
{

Parameter MAXLEN = 255;

Parameter REGEX = "(/.*|(%)?(.+\.)+([A-Za-z0-9])+)";

}