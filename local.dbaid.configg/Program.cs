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
        private const string _getProcedureList = "SELECT [procedure] FROM [dbo].[get_procedure_list](N'configg')";
        private const string _getInstanceTag = "SELECT [instance_tag] FROM [dbo].[get_instance_tag]()";
        private const string _setServiceProperty = "[dbo].[set_service_property]";
        private const string _logID = "DBAidConfigG";

        private static readonly string[] _wmiQueryList = { "SELECT DisplayName,BinaryPath,Description,HostName,ServiceName,StartMode,StartName FROM SqlService WHERE DisplayName LIKE '%?%'",
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

        private static bool argHelp(string arg)
        {
            if (arg.Contains("?")) { return true; }
            else { return false; }
        }

        static int Main(string[] args)
        {
            string baseDirectory = AppDomain.CurrentDomain.BaseDirectory;
            string logFile = Path.Combine(baseDirectory, _logID + "_" + DateTime.Now.ToString("yyyyMMdd") + ".log");
            bool loadServiceTable = false;
            bool generateConfigReport = false;
            bool logVerbose = false;
            uint logRententionDays = 0;
            var csb = new SqlConnectionStringBuilder();

            if (Array.Find(args, argHelp) != null || args.Length == 0)
            {
                Log.licenseHeader();
                Log.helpArgConnectionString();
#if (DEBUG)
                Console.ReadKey();
#endif
                return 0;
            }

            Log.message(LogEntryType.INFO, _logID, "BEGIN", logFile);

            try
            {
                loadServiceTable = bool.Parse(ConfigurationManager.AppSettings["LoadServiceTable"]);
                generateConfigReport = bool.Parse(ConfigurationManager.AppSettings["GenerateConfiggReport"]);
                logVerbose = bool.Parse(ConfigurationManager.AppSettings["LogVerbose"]);
                logRententionDays = uint.Parse(ConfigurationManager.AppSettings["LogRetentionDays"]);
            }
            catch(SystemException ex)
            {
                StringBuilder usrmsg = new StringBuilder("Failed to parse app.config \"");
                usrmsg.Append(System.Reflection.Assembly.GetExecutingAssembly().Location);
                usrmsg.Append(".config\"\r\nTerminating process");

                Log.message(LogEntryType.ERROR, _logID, usrmsg.ToString(), logFile);
                if (logVerbose) { Log.message(LogEntryType.WARNING, _logID, ex.Message + "\r\n" + ex.StackTrace, logFile); }
#if (DEBUG)
                Console.ReadKey();
#endif
                return 1;
            }

            try
            {
                csb.ApplicationName = _logID + Guid.NewGuid().ToString();
                csb.ConnectionString = args[0];
            }
            catch(SystemException ex)
            {
                Log.message(LogEntryType.ERROR, _logID, "Failed to set connection string\r\nTerminating process", logFile);
                if (logVerbose) { Log.message(LogEntryType.ERROR, _logID, ex.Message + "\r\n" + ex.StackTrace, logFile); }
#if (DEBUG)
                Console.ReadKey();
#endif
                return 1;
            }

            try
            {
                //clean up log files older than logRetentionDays
                FileIo.delete(Path.GetDirectoryName(logFile), "*.log", DateTime.Now.AddDays(-logRententionDays));
                Log.message(LogEntryType.INFO, _logID, "Deleted old log files.", logFile);
            }
            catch (SystemException ex)
            {
                Log.message(LogEntryType.WARNING, _logID, "Failed to delete old log files.", logFile);
                if (logVerbose) { Log.message(LogEntryType.WARNING, _logID, ex.Message + "\r\n" + ex.StackTrace, logFile); }
            }

            if (loadServiceTable)
            {
                string sqlHost = csb.DataSource.Split('\\')[0];
                string sqlInstance = csb.DataSource.Split('\\').Length > 1 ? csb.DataSource.Split('\\')[1] : "MSSQLSERVER";
                var parameters = new Dictionary<string, object>();

                Log.message(LogEntryType.INFO, _logID, "Service data load starting.", logFile);

                foreach (Wmi.PropertyValue prop in Wmi.getWmiData(sqlHost, sqlInstance, _wmiQueryList))
                {
                    parameters.Clear();
                    parameters.Add("class_object", prop.Path);
                    parameters.Add("property", prop.Property.Value);
                    parameters.Add("value", prop.Value);

                    try
                    {
                        Query.Execute(csb.ConnectionString, _setServiceProperty, parameters);
                    }
                    catch(SystemException ex)
                    {
                        Log.message(LogEntryType.WARNING, _logID, "Failed to generate ConfigG report\r\nTerminating process", logFile);
                        if (logVerbose) { Log.message(LogEntryType.WARNING, _logID, ex.Message + "\r\n" + ex.StackTrace, logFile); }
                    }
                }

                Log.message(LogEntryType.INFO, _logID, "Service data load complete.", logFile);
            }

            if (generateConfigReport)
            {
                string saveFile = Path.Combine(baseDirectory, csb.DataSource.Replace(@"\", "@").ToLower() + "_configg.md");

                using (StreamWriter outfile = new StreamWriter(saveFile))
                {
                    try
                    {
                        Log.message(LogEntryType.INFO, _logID, "ConfigG report starting.", logFile);

                        outfile.Write("# ConfigG Document - " + csb.DataSource + Environment.NewLine + "---" + Environment.NewLine);
                        outfile.Write("## Contents" + Environment.NewLine);
                        outfile.Write(Markdown.getMarkdown(csb.ConnectionString, _getProcedureList));

                        Log.message(LogEntryType.INFO, _logID, saveFile, logFile);
                        Log.message(LogEntryType.INFO, _logID, "ConfigG report complete.", logFile);
                    }
                    catch (SystemException ex)
                    {
                        Log.message(LogEntryType.ERROR, _logID, "Failed to generate ConfigG report\r\nTerminating process", logFile);
                        if (logVerbose) { Log.message(LogEntryType.ERROR, _logID, ex.Message + "\r\n" + ex.StackTrace, logFile); }
#if (DEBUG)
                        Console.ReadKey();
#endif
                        return 1;
                    }
                }
            }

            Log.message(LogEntryType.INFO, _logID, "END", logFile);
#if (DEBUG)
            Console.ReadKey();
#endif
            return 0;
        }
    }
}
