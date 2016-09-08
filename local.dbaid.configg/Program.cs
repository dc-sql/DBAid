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
        private const string _getProcedureList = "SELECT [procedure] FROM [get].[procedure_list](N'configg')";
        private const string _getInstanceTag = "SELECT [instance_tag] FROM [get].[instance_tag]()";
        private static string _getWmiQueryList = "SELECT [query] FROM [get].[wmi_service_query]()";
        private const string _setServiceProperty = "[set].[wmi_service_property]";
        private static string _assemblyName = Path.GetFileName(System.Reflection.Assembly.GetEntryAssembly().Location).Replace(".exe", "");

        private static bool argHelp(string arg)
        {
            if (arg.Contains("?")) { return true; }
            else { return false; }
        }

        static int Main(string[] args)
        {
            string baseDirectory = AppDomain.CurrentDomain.BaseDirectory;
            string logFile = Path.Combine(baseDirectory, _assemblyName + "_" + DateTime.Now.ToString("yyyyMMdd") + ".log");
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

            Log.message(LogEntryType.INFO, _assemblyName, "BEGIN", logFile);

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

                Log.message(LogEntryType.ERROR, _assemblyName, usrmsg.ToString(), logFile);
                if (logVerbose) { Log.message(LogEntryType.WARNING, _assemblyName, ex.Message + "\r\n" + ex.StackTrace, logFile); }
#if (DEBUG)
                Console.ReadKey();
#endif
                return 1;
            }

            try
            {
                csb.ApplicationName = _assemblyName + Guid.NewGuid().ToString();
                csb.ConnectionString = args[0];
            }
            catch(SystemException ex)
            {
                Log.message(LogEntryType.ERROR, _assemblyName, "Failed to set connection string\r\nTerminating process", logFile);
                if (logVerbose) { Log.message(LogEntryType.ERROR, _assemblyName, ex.Message + "\r\n" + ex.StackTrace, logFile); }
#if (DEBUG)
                Console.ReadKey();
#endif
                return 1;
            }

            try
            {
                //clean up log files older than logRetentionDays
                FileIo.delete(Path.GetDirectoryName(logFile), "*.log", DateTime.Now.AddDays(-logRententionDays));
                Log.message(LogEntryType.INFO, _assemblyName, "Deleted old log files.", logFile);
            }
            catch (SystemException ex)
            {
                Log.message(LogEntryType.WARNING, _assemblyName, "Failed to delete old log files.", logFile);
                if (logVerbose) { Log.message(LogEntryType.WARNING, _assemblyName, ex.Message + "\r\n" + ex.StackTrace, logFile); }
            }

            if (loadServiceTable)
            {
                string dataSource = csb.DataSource;
                var parameters = new Dictionary<string, object>();

                Log.message(LogEntryType.INFO, _assemblyName, "Service data load starting.", logFile);

                DataTable dtWmiQueries = Query.Select(csb.ConnectionString, _getWmiQueryList);

                foreach (DataRow row in dtWmiQueries.Rows)
                {
                    string query = row["query"].ToString();

                    parameters.Clear();
                    parameters.Add("service_property_tbl", Wmi.getWmiData(dataSource, query));

                    try
                    {
                        Query.Execute(csb.ConnectionString, _setServiceProperty, parameters);
                    }
                    catch(SystemException ex)
                    {
                        Log.message(LogEntryType.WARNING, _assemblyName, "Failed to load WMI service properties \r\nTerminating process", logFile);
                        if (logVerbose) { Log.message(LogEntryType.WARNING, _assemblyName, ex.Message + "\r\n" + ex.StackTrace, logFile); }
#if (DEBUG)
                        Console.ReadKey();
#endif
                        return 1;
                    }
                }

                Log.message(LogEntryType.INFO, _assemblyName, "Service data load complete.", logFile);
            }

            if (generateConfigReport)
            {
                string saveFile = Path.Combine(baseDirectory, csb.DataSource.Replace(@"\", "@").ToLower() + "_configg.md");

                using (StreamWriter outfile = new StreamWriter(saveFile))
                {
                    try
                    {
                        Log.message(LogEntryType.INFO, _assemblyName, "ConfigG report starting.", logFile);

                        outfile.Write("# ConfigG Document - " + csb.DataSource + Environment.NewLine + "---" + Environment.NewLine);
                        outfile.Write("## Contents" + Environment.NewLine);
                        outfile.Write(Markdown.getMarkdown(csb.ConnectionString, _getProcedureList));

                        Log.message(LogEntryType.INFO, _assemblyName, saveFile, logFile);
                        Log.message(LogEntryType.INFO, _assemblyName, "ConfigG report complete.", logFile);
                    }
                    catch (SystemException ex)
                    {
                        Log.message(LogEntryType.ERROR, _assemblyName, "Failed to generate ConfigG report\r\nTerminating process", logFile);
                        if (logVerbose) { Log.message(LogEntryType.ERROR, _assemblyName, ex.Message + "\r\n" + ex.StackTrace, logFile); }
#if (DEBUG)
                        Console.ReadKey();
#endif
                        return 1;
                    }
                }
            }

            Log.message(LogEntryType.INFO, _assemblyName, "END", logFile);
#if (DEBUG)
            Console.ReadKey();
#endif
            return 0;
        }
    }
}
