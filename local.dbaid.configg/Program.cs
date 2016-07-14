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
        private const string _getProgramName = "SELECT [value] FROM [dbo].[get_static_parameter]('PROGRAM_NAME')";
        private const string _getInstanceTag = "SELECT [instance_tag] FROM [dbo].[get_instance_tag]()";
        private const string _setServiceProperty = "[dbo].[set_service_property]";
        
        private const string _logID = "DBAidConfigG";

        static void Main(string[] args)
        {
            bool loadServiceTable = bool.Parse(ConfigurationManager.AppSettings["UpdateDboServiceTable"]);
            bool generateConfigReport = bool.Parse(ConfigurationManager.AppSettings["GenerateConfiggReport"]);
            bool logVerbose = bool.Parse(ConfigurationManager.AppSettings["LogVerbose"]);
            int logRententionDays = int.Parse(ConfigurationManager.AppSettings["LogRetentionDays"]);
            string baseDirectory = AppDomain.CurrentDomain.BaseDirectory;
            string logFile = Path.Combine(baseDirectory, _logID + "_" + DateTime.Now.ToString("yyyyMMdd") + ".log");
            string saveFile = String.Empty;
            var csb = new SqlConnectionStringBuilder(args[0]);

            if (Array.IndexOf(args, "?") >= 0 || String.IsNullOrEmpty(csb.ConnectionString))
            {
                Log.licenseHeader();
                return;
            }

            saveFile = Path.Combine(baseDirectory, csb.DataSource.Replace(@"\", "@").ToLower() + "_asbuilt.md");
            csb.ApplicationName = _logID + Guid.NewGuid().ToString();
            Log.message(LogEntryType.INFO, _logID, "Process Started", logFile);

            try
            {
                //clean up log files older than logRetentionDays
                FileIo.delete(Path.GetDirectoryName(logFile), "*.log", DateTime.Now.AddDays(-logRententionDays));
            }
            catch (Exception ex)
            {
                Log.message(LogEntryType.WARNING, _logID, ex.Message + (logVerbose ? " - " + ex.StackTrace : ""), logFile);
            }

            try
            {
                csb.ApplicationName = Query.Select(csb.ConnectionString, mssqlAppSelect).Rows[0][0].ToString();
            }
            catch (ApplicationException ex)
            {
                Log.message(LogEntryType.ERROR, _logID, ex.Message + (logVerbose ? " - " + ex.StackTrace : ""), logFile);
                Console.Write(ex);
                return;
            }

            if (loadServiceTable)
            {
                var parameters = new Dictionary<string, object>();

                foreach (Wmi.PropertyValue prop in Wmi.getHostInfo(host))
                {
                    parameters.Clear();

                    parameters.Add("hierarchy", prop.Path);
                    parameters.Add("property", prop.Property.Value);
                    parameters.Add("value", prop.Value);

                    Query.Execute(csb.ConnectionString, mssqlInsertService, parameters);
                }

                Log.message(LogEntryType.INFO, _logID, "Loaded WMI HostInfo.", logFile);

                foreach (Wmi.PropertyValue prop in Wmi.getServiceInfo(host, instance))
                {
                    parameters.Clear();

                    parameters.Add("hierarchy", prop.Path);
                    parameters.Add("property", prop.Property.Value);
                    parameters.Add("value", prop.Value);

                    Query.Execute(csb.ConnectionString, mssqlInsertService, parameters);
                }

                Log.message(LogEntryType.INFO, _logID, "Loaded WMI ServiceInfo.", logFile);

                foreach (Wmi.PropertyValue prop in Wmi.getDriveInfo(host))
                {
                    parameters.Clear();

                    parameters.Add("hierarchy", prop.Path);
                    parameters.Add("property", prop.Property.Value);
                    parameters.Add("value", prop.Value);

                    Query.Execute(csb.ConnectionString, mssqlInsertService, parameters);
                }

                Log.message(LogEntryType.INFO, _logID, "Loaded WMI DriveInfo.", logFile);
            }

            if (generateConfigReport)
            {
                using (StreamWriter outfile = new StreamWriter(saveFile))
                {
                    try
                    {
                        outfile.Write("# As-Built Document - " + csb.DataSource + Environment.NewLine + "---" + Environment.NewLine);
                        outfile.Write("## Contents" + Environment.NewLine);
                        outfile.Write(Markdown.getMarkdown(csb.ConnectionString, mssqlControlFact));

                        Log.message(LogEntryType.INFO, _logID, "Generated AsBuilt for [" + csb.DataSource + "]", logFile);
                        
                    }
                    catch (Exception ex)
                    {
                        Log.message(LogEntryType.ERROR, _logID, ex.Message + (logVerbose ? " - " + ex.StackTrace : ""), logFile);
                        throw ex;
                    }
                }

                if (!String.IsNullOrEmpty(emailSmtp))
                {
                    try
                    {
                        Smtp.send(emailSmtp, emailFrom, emailTo, emailSubject, "", new []{ file }, emailAttachmentByteLimit, emailAttachmentCountLimit, emailEnableSsl, emailIgnoreSslError, emailAnonymous);
                        Log.message(LogEntryType.INFO, _logID, "Email sent to \"" + String.Join("; ", emailTo) + "\"", logFile);
                    }
                    catch (Exception ex)
                    {
                        Log.message(LogEntryType.ERROR, _logID, ex.Message + (logVerbose ? " - " + ex.StackTrace : ""), logFile);
                        throw ex;
                    }
                }
                else
                {
                    Log.message(LogEntryType.INFO, _logID, "Emailing of config not enabled or configured.", logFile);
                }
            }

            Log.message(LogEntryType.INFO, _logID, "Process Completed", logFile);

            //System.Threading.Thread.Sleep(10000);
        }
    }
}
