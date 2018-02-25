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
        private const string mssqlControlFact = "[control].[fact]";
        private const string mssqlInsertService = "[dbo].[insert_service]";
        private const string mssqlAppSelect = "SELECT [value] FROM [dbo].[static_parameters] WHERE UPPER([name]) = N'PROGRAM_NAME'";
        private const string logID = "DBAid-ConfigG-";

        static void Main(string[] args)
        {
            Log.licenseHeader();

            if (Array.IndexOf(args, @"/?") >= 0)
            {
                Console.WriteLine("See https://github.com/dc-sql/DBAid for more details");

                return;
            }

            string baseDirectory = AppDomain.CurrentDomain.BaseDirectory;
            string logFile = Path.Combine(baseDirectory, logID + DateTime.Now.ToString("yyyyMMdd") + ".log");

            Log.message(LogEntryType.INFO, "DBaidAsBuilt", "Process Started", logFile);

            Arguments flag = new Arguments(args);

            string server = flag.ContainsFlag("-server") ? flag.GetValue("-server") : String.Empty;
            string database = flag.ContainsFlag("-db") ? flag.GetValue("-db") : "_dbaid";
            bool disableWmi = flag.ContainsFlag("-disablewmi") ? bool.Parse(flag.GetValue("-disablewmi")) : false;
            bool disableMd = flag.ContainsFlag("-disablemd") ? bool.Parse(flag.GetValue("-disablemd")) : false;
            bool logVerbose = flag.ContainsFlag("-logverbose") ? bool.Parse(flag.GetValue("-logverbose")) : false;
            string emailSmtp = flag.ContainsFlag("-emailsmtp") ? flag.GetValue("-emailsmtp") : String.Empty;
            string[] emailTo = flag.ContainsFlag("-emailto") ? flag.GetValue("-emailto").Split(new char[] {';'}) : new string[0];
            string emailFrom = flag.ContainsFlag("-emailfrom") ? flag.GetValue("-emailfrom") : String.Empty;
            string emailSubject = flag.ContainsFlag("-emailsubject") ? flag.GetValue("-emailsubject") : String.Empty;
            long emailAttachmentByteLimit = flag.ContainsFlag("-emailbytelimit") ? long.Parse(flag.GetValue("-emailbytelimit")) : 10000000;
            int emailAttachmentCountLimit = flag.ContainsFlag("-emailattlimit") ? int.Parse(flag.GetValue("-emailattlimit")) : 15;
            bool emailEnableSsl = flag.ContainsFlag("-emailssl") ? bool.Parse(flag.GetValue("-emailssl")) : false;
            bool emailIgnoreSslError = flag.ContainsFlag("-emailignoresslerror") ? bool.Parse(flag.GetValue("-emailignoresslerror")) : false;
            bool emailAnonymous = flag.ContainsFlag("-emailanonymous") ? bool.Parse(flag.GetValue("-emailanonymous")) : true;
            int connectionTimeout = flag.ContainsFlag("-connectionTimeout") ? int.Parse(flag.GetValue("-connectionTimeout")) : 60;
            int timeOut = flag.ContainsFlag("-commandTimeout") ? int.Parse(flag.GetValue("-commandTimeout")) : 30;

            if (String.IsNullOrEmpty(server))
            {
                Log.message(LogEntryType.WARNING, "DBaidAsBuilt", "No -server specified. Exiting program...", logFile);
                return;
            }

            string host = String.Empty;
            string instance = String.Empty;

            if (server.Contains("\\"))
            {
                host = server.Split(new char[] { '\\' }, 2)[0];
                instance = server.Split(new char[] { '\\' }, 2)[1];
            }
            else
                host = server;

            string file = Path.Combine(baseDirectory, server.Replace(@"\", "@").ToLower() + "_asbuilt.md");
            var csb = new SqlConnectionStringBuilder();
            csb.ApplicationName = logID + Guid.NewGuid().ToString();
            csb.DataSource = server;
            csb.InitialCatalog = database;
            csb.IntegratedSecurity = true;
            csb.ConnectTimeout = connectionTimeout;

            try
            {
                //clean up log files older than 3 days
                FileIo.delete(Path.GetDirectoryName(logFile), "*.log", DateTime.Now.AddDays(-3));
            }
            catch (Exception ex)
            {
                Log.message(LogEntryType.WARNING, "DBaidAsBuilt", ex.Message + (logVerbose ? " - " + ex.StackTrace : ""), logFile);
            }

            try
            {
                csb.ApplicationName = Query.Select(csb.ConnectionString, mssqlAppSelect, timeOut).Rows[0][0].ToString();
            }
            catch (ApplicationException ex)
            {
                Log.message(LogEntryType.ERROR, "DBaidAsBuilt", ex.Message + (logVerbose ? " - " + ex.StackTrace : ""), logFile);
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

                    Query.Execute(csb.ConnectionString, mssqlInsertService, parameters, timeOut);
                }

                Log.message(LogEntryType.INFO, "DBaidAsBuilt", "Loaded WMI HostInfo.", logFile);

                foreach (Wmi.PropertyValue prop in Wmi.getServiceInfo(host, instance))
                {
                    parameters.Clear();

                    parameters.Add("hierarchy", prop.Path);
                    parameters.Add("property", prop.Property.Value);
                    parameters.Add("value", prop.Value);

                    Query.Execute(csb.ConnectionString, mssqlInsertService, parameters, timeOut);
                }

                Log.message(LogEntryType.INFO, "DBaidAsBuilt", "Loaded WMI ServiceInfo.", logFile);

                foreach (Wmi.PropertyValue prop in Wmi.getDriveInfo(host))
                {
                    parameters.Clear();

                    parameters.Add("hierarchy", prop.Path);
                    parameters.Add("property", prop.Property.Value);
                    parameters.Add("value", prop.Value);

                    Query.Execute(csb.ConnectionString, mssqlInsertService, parameters, timeOut);
                }

                Log.message(LogEntryType.INFO, "DBaidAsBuilt", "Loaded WMI DriveInfo.", logFile);
            }

            if (!disableMd)
            {
                using (StreamWriter outfile = new StreamWriter(file))
                {
                    try
                    {
                        outfile.Write("# As-Built Document - " + csb.DataSource + Environment.NewLine + "---" + Environment.NewLine);
                        outfile.Write("## Contents" + Environment.NewLine);
                        outfile.Write(Markdown.getMarkdown(csb.ConnectionString, mssqlControlFact, timeOut));

                        Log.message(LogEntryType.INFO, "DBaidAsBuilt", "Generated AsBuilt for [" + csb.DataSource + "]", logFile);
                        
                    }
                    catch (Exception ex)
                    {
                        Log.message(LogEntryType.ERROR, "DBaidAsBuilt", ex.Message + (logVerbose ? " - " + ex.StackTrace : ""), logFile);
                        throw ex;
                    }
                }

                if (!String.IsNullOrEmpty(emailSmtp))
                {
                    try
                    {
                        Smtp.send(emailSmtp, emailFrom, emailTo, emailSubject, "", new []{ file }, emailAttachmentByteLimit, emailAttachmentCountLimit, emailEnableSsl, emailIgnoreSslError, emailAnonymous);
                        Log.message(LogEntryType.INFO, "DBaidAsBuilt", "Email sent to \"" + String.Join("; ", emailTo) + "\"", logFile);
                    }
                    catch (Exception ex)
                    {
                        Log.message(LogEntryType.ERROR, "DBaidAsBuilt", ex.Message + (logVerbose ? " - " + ex.StackTrace : ""), logFile);
                        throw ex;
                    }
                }
                else
                {
                    Log.message(LogEntryType.INFO, "DBaidAsBuilt", "Emailing of config not enabled or configured.", logFile);
                }
            }

            Log.message(LogEntryType.INFO, "DBaidAsBuilt", "Process Completed", logFile);

            //System.Threading.Thread.Sleep(10000);
        }
    }
}
