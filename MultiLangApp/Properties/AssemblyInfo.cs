using System.Reflection;
using System.Runtime.CompilerServices;
using System.Runtime.InteropServices;

// General Information about an assembly is controlled through the following
// set of attributes. Change these attribute values to modify the information
// associated with an assembly.
[assembly: AssemblyTitle("MultiLangApp")]
[assembly: AssemblyDescription("")]
[assembly: AssemblyConfiguration("")]
[assembly: AssemblyCompany("")]
[assembly: AssemblyProduct("MultiLangApp")]
[assembly: AssemblyCopyright("Copyright ©  2019")]
[assembly: AssemblyTrademark("")]
[assembly: AssemblyCulture("")]

// Setting ComVisible to false makes the types in this assembly not visible
// to COM components.  If you need to access a type in this assembly from
// COM, set the ComVisible attribute to true on that type.
[assembly: ComVisible(false)]

// The following GUID is for the ID of the typelib if this project is exposed to COM
[assembly: Guid("e543e492-0b96-495f-aa38-f8d1a083b869")]

// Version information for an assembly consists of the following four values:
//
//      Major Version
//      Minor Version
//      Build Number
//      Revision
//
// You can specify all the values or you can default the Revision and Build Numbers
// by using the '*' as shown below:
[assembly: AssemblyVersion("1.0.0.0")]
[assembly: AssemblyFileVersion("1.0.0.0")]

// Setting file for log4net.
// Without specifying ConfigFile manually, it refers Web.config.
// Either uppercase and lowercase are accepted. (Log4net.config, log4net.config)
// This attribute is the only place that configures log4net, so Web.config needs no log4net section.
// The build configuration picks the file: Debug builds use Log4net.Debug.config, Release builds Log4net.Release.config.
#if DEBUG
[assembly: log4net.Config.XmlConfigurator(ConfigFile = "Log4net.Debug.config", Watch = true)]
#else
[assembly: log4net.Config.XmlConfigurator(ConfigFile = "Log4net.Release.config", Watch = true)]
#endif