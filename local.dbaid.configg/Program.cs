using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using System.Data;
using System.Data.SqlClient;
using System.Configuration;
using System.Xml;
using dbaid.common;

namespace dbaid.configg
{
    class Program
    {
        private const string _getProcedureList = "SELECT [dbo].[get_procedure_list](N'configg')";
        private const string _getInstanceTag = "SELECT [instance_tag] FROM [dbo].[get_instance_tag]()";
        private const string _setServiceProperty = "[dbo].[set_service_property]";
        private const string _logID = "DBAidConfigG";

        private static readonly string[] _wmiQuery = { "SELECT DisplayName,BinaryPath,Description,HostName,ServiceName,StartMode,StartName FROM SqlService WHERE DisplayName LIKE '%?%'",
        "SELECT InstanceName,ProtocolDisplayName,Enabled FROM ServerNetworkProtocol WHERE InstanceName LIKE '%?%'",
        "SELECT InstanceName,PropertyName,PropertyStrVal FROM ServerNetworkProtocolProperty WHERE IPAddressName = 'IPAll' AND InstanceName LIKE '%?%'",
        "SELECT ServiceName,PropertyName,PropertyNumValue,PropertyStrValue FROM SqlServiceAdvancedProperty WHERE ServiceName LIKE '%?%'",
        "SELECT InstanceName,FlagName,FlagValue FROM ServerSettingsGeneralFlag WHERE InstanceName LIKE '%?%'",
        "SELECT * FROM Win32_OperatingSystem",
        "SELECT Caption FROM Win32_TimeZone",
        "SELECT * FROM win32_processor",
        "SELECT Domain, Manufacturer, Model, PrimaryOwnerName, TotalPhysicalMemory FROM Win32_computerSystem",
        "SELECT ServiceName, Caption, DHCPEnabled, DNSDomain, IPAddress, MACAddress FROM Win32_NetworkAdapterConfiguration WHERE IPEnabled = 'TRUE'",
        "SELECT DriveLetter, Label, DeviceID, DriveType, FileSystem, Capacity, BlockSize, Compressed, IndexingEnabled FROM Win32_Volume WHERE SystemVolume <> 'TRUE' AND DriveType <> 4 AND DriveType <> 5"};

        static void Main(string[] args)
        {
            var csb = new SqlConnectionStringBuilder(args[0]);
            bool loadServiceTable = bool.Parse(ConfigurationManager.AppSettings["LoadServiceTable"]);
            bool generateConfigReport = bool.Parse(ConfigurationManager.AppSettings["GenerateConfiggReport"]);
            bool logVerbose = bool.Parse(ConfigurationManager.AppSettings["LogVerbose"]);
            uint logRententionDays = uint.Parse(ConfigurationManager.AppSettings["LogRetentionDays"]);
            string baseDirectory = AppDomain.CurrentDomain.BaseDirectory;
            string logFile = Path.Combine(baseDirectory, _logID + "_" + DateTime.Now.ToString("yyyyMMdd") + ".log");
            string saveFile = String.Empty;
            string sqlHost = csb.DataSource.Split('\\')[0];
            string sqlInstance = csb.DataSource.Split('\\').Length > 1 ? csb.DataSource.Split('\\')[1] : String.Empty;
            int test = csb.DataSource.Split('\\').Length;

            if (Array.IndexOf(args, "?") >= 0 || String.IsNullOrEmpty(csb.ConnectionString))
            {
                Log.licenseHeader();
                return;
            }

            Log.message(LogEntryType.INFO, _logID, "Process Started", logFile);
            csb.ApplicationName = _logID + Guid.NewGuid().ToString();
            saveFile = Path.Combine(baseDirectory, csb.DataSource.Replace(@"\", "@").ToLower() + "_asbuilt.md");

            try
            {
                //clean up log files older than logRetentionDays
                FileIo.delete(Path.GetDirectoryName(logFile), "*.log", DateTime.Now.AddDays(-logRententionDays));
            }
            catch (Exception ex)
            {
                Log.message(LogEntryType.WARNING, _logID, ex.Message + (logVerbose ? " - " + ex.StackTrace : ""), logFile);
            }

            if (loadServiceTable)
            {
                var parameters = new Dictionary<string, object>();

                foreach (Wmi.PropertyValue prop in Wmi.getWmiData(sqlHost, sqlInstance, _wmiQuery))
                {
                    parameters.Clear();
                    parameters.Add("class_object", prop.Path);
                    parameters.Add("property", prop.Property.Value);
                    parameters.Add("value", prop.Value);

                    Query.Execute(csb.ConnectionString, _setServiceProperty, parameters);
                }

                Log.message(LogEntryType.INFO, _logID, "Loaded WMI data.", logFile);
            }

            if (generateConfigReport)
            {
                using (StreamWriter outfile = new StreamWriter(saveFile))
                {
                    try
                    {
                        outfile.Write("# As-Built Document - " + csb.DataSource + Environment.NewLine + "---" + Environment.NewLine);
                        outfile.Write("## Contents" + Environment.NewLine);
                        outfile.Write(Markdown.getMarkdown(csb.ConnectionString, _getProcedureList));

                        Log.message(LogEntryType.INFO, _logID, "Generated AsBuilt for [" + csb.DataSource + "]", logFile);
                        
                    }
                    catch (Exception ex)
                    {
                        Log.message(LogEntryType.ERROR, _logID, ex.Message + (logVerbose ? " - " + ex.StackTrace : ""), logFile);
                        throw ex;
                    }
                }
            }

            Log.message(LogEntryType.INFO, _logID, "Process Completed", logFile);

#if (DEBUG)
            Console.ReadKey();
#endif
        }
    }
}
