using System;
using System.Collections.Generic;
using System.IO;
using System.Text;
using System.Data;
using System.Data.SqlClient;
using System.Configuration;
using System.Xml;
using dbaid.common;

namespace local.dbaid.asbuilt
{
    class Program
    {
        private const string mssqlControlFact = "EXEC [dbo].[procedure_list] @schema = N'configg'";
        private const string mssqlInsertService = "[dbo].[insert_service]";
        private const string mssqlAppSelect = "SELECT [value] FROM [dbo].[static_parameters] WHERE UPPER([name]) = N'PROGRAM_NAME'";
        private const string logID = "DBAidConfigG";

        static void Main(string[] args)
        {
            if (Array.IndexOf(args, @"?") >= 0)
            {
                Log.licenseHeader();
                return;
            }

            string baseDirectory = AppDomain.CurrentDomain.BaseDirectory;
            string logFile = Path.Combine(baseDirectory, logID + "_" + DateTime.Now.ToString("yyyyMMdd") + ".log");
            string saveFile = String.Empty;
            var csb = new SqlConnectionStringBuilder();

            if (String.IsNullOrEmpty(args[0]))
            {
                Log.message(LogEntryType.WARNING, logID, "No -server specified. Exiting program...", logFile);
                return;
            }

            try
            {
                csb.ConnectionString = args[0];
            }
            catch
            {
                Log.message(LogEntryType.WARNING, logID, "Failed to set connectionsting. Exiting program...", logFile);
                return;
            }

            Log.message(LogEntryType.INFO, logID, "Process Started", logFile);

            saveFile = Path.Combine(baseDirectory, csb.DataSource.Replace(@"\", "@").ToLower() + "_asbuilt.md");
            csb.ApplicationName = logID + Guid.NewGuid().ToString();

            try
            {
                //clean up log files older than 3 days
                FileIo.delete(Path.GetDirectoryName(logFile), "*.log", DateTime.Now.AddDays(-3));
            }
            catch (Exception ex)
            {
                Log.message(LogEntryType.WARNING, logID, ex.Message + (logVerbose ? " - " + ex.StackTrace : ""), logFile);
            }

            try
            {
                csb.ApplicationName = Query.Select(csb.ConnectionString, mssqlAppSelect).Rows[0][0].ToString();
            }
            catch (ApplicationException ex)
            {
                Log.message(LogEntryType.ERROR, logID, ex.Message + (logVerbose ? " - " + ex.StackTrace : ""), logFile);
                Console.Write(ex);
                return;
            }

            if (!disableWmi)
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

                Log.message(LogEntryType.INFO, logID, "Loaded WMI HostInfo.", logFile);

                foreach (Wmi.PropertyValue prop in Wmi.getServiceInfo(host, instance))
                {
                    parameters.Clear();

                    parameters.Add("hierarchy", prop.Path);
                    parameters.Add("property", prop.Property.Value);
                    parameters.Add("value", prop.Value);

                    Query.Execute(csb.ConnectionString, mssqlInsertService, parameters);
                }

                Log.message(LogEntryType.INFO, logID, "Loaded WMI ServiceInfo.", logFile);

                foreach (Wmi.PropertyValue prop in Wmi.getDriveInfo(host))
                {
                    parameters.Clear();

                    parameters.Add("hierarchy", prop.Path);
                    parameters.Add("property", prop.Property.Value);
                    parameters.Add("value", prop.Value);

                    Query.Execute(csb.ConnectionString, mssqlInsertService, parameters);
                }

                Log.message(LogEntryType.INFO, logID, "Loaded WMI DriveInfo.", logFile);
            }

            if (!disableMd)
            {
                using (StreamWriter outfile = new StreamWriter(file))
                {
                    try
                    {
                        outfile.Write("# As-Built Document - " + csb.DataSource + Environment.NewLine + "---" + Environment.NewLine);
                        outfile.Write("## Contents" + Environment.NewLine);
                        outfile.Write(Markdown.getMarkdown(csb.ConnectionString, mssqlControlFact));

                        Log.message(LogEntryType.INFO, logID, "Generated AsBuilt for [" + csb.DataSource + "]", logFile);
                        
                    }
                    catch (Exception ex)
                    {
                        Log.message(LogEntryType.ERROR, logID, ex.Message + (logVerbose ? " - " + ex.StackTrace : ""), logFile);
                        throw ex;
                    }
                }

                if (!String.IsNullOrEmpty(emailSmtp))
                {
                    try
                    {
                        Smtp.send(emailSmtp, emailFrom, emailTo, emailSubject, "", new []{ file }, emailAttachmentByteLimit, emailAttachmentCountLimit, emailEnableSsl, emailIgnoreSslError, emailAnonymous);
                        Log.message(LogEntryType.INFO, logID, "Email sent to \"" + String.Join("; ", emailTo) + "\"", logFile);
                    }
                    catch (Exception ex)
                    {
                        Log.message(LogEntryType.ERROR, logID, ex.Message + (logVerbose ? " - " + ex.StackTrace : ""), logFile);
                        throw ex;
                    }
                }
                else
                {
                    Log.message(LogEntryType.INFO, logID, "Emailing of config not enabled or configured.", logFile);
                }
            }

            Log.message(LogEntryType.INFO, logID, "Process Completed", logFile);

            //System.Threading.Thread.Sleep(10000);
        }
    }
}
