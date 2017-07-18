using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data;
using System.Data.SqlClient;
using System.Text;
using System.IO;
using System.Net.NetworkInformation;

namespace collector
{
    class Program
    {
        private const string mssqlPublicKeySelect = "SELECT [value] FROM [dbo].[static_parameters] WHERE UPPER([name]) = N'PUBLIC_ENCRYPTION_KEY'";
        private const string mssqlProgramNameSelect = "SELECT [value] FROM [dbo].[static_parameters] WHERE UPPER([name]) = N'PROGRAM_NAME'";
        private const string mssqlInstanceTagSelect = "SELECT [instance_tag] FROM [system].[get_instance_tag]";
        private const string mssqlControlProc = "[control].[log]";
        private const string encryptedExt = ".encrypted";
        private const string processedDir = "processed";
        private const string processedExt = ".processed";
        private const string logID = "DBAid-Collector-";
        private const string logExt = ".log";

        static void Main(string[] args)
        {
            string connectionString = args[0];
            string baseDirectory = AppDomain.CurrentDomain.BaseDirectory;
            string logFile = Path.Combine(baseDirectory, logID + DateTime.Now.ToString("yyyyMMdd") + logExt);
            string outputDirectory = Path.Combine(baseDirectory,"");
            bool logVerbose = true;
            byte fileRententionDays = 4;
            
            string emailSmtp = String.Empty;
            string[] emailTo = { String.Empty };
            string emailFrom = String.Empty;
            string emailSubject = String.Empty;
            long emailAttachmentByteLimit = 0;
            int emailAttachmentCountLimit = 0;
            bool emailEnableSsl = true;
            bool emailIgnoreSslError = false;
            bool emailAnonymous = true;
            ConnectionStringSettingsCollection cssc = new ConnectionStringSettingsCollection();

            try
            {
                if (String.IsNullOrEmpty(server) || String.IsNullOrEmpty(database))
                {
                    cssc = ConfigurationManager.ConnectionStrings;
                }
                else
                {
                    string cs = "Server=" + server + ";Database=" + database + ";Trusted_Connection=True;";
                    cssc.Add(new ConnectionStringSettings(server.Replace("\\", "@"), cs));
                }

                workingDirectory = ConfigurationManager.AppSettings["WorkingDirectory"];
                processDirectory = Path.Combine(workingDirectory, processedDir);
                logVerbose = bool.Parse(ConfigurationManager.AppSettings["logVerbose"]);
                fileRententionDays = byte.Parse(ConfigurationManager.AppSettings["ProcessedFileRetentionDays"]);

                if (!Directory.Exists(workingDirectory))
                {
                    Directory.CreateDirectory(workingDirectory);
                }

                if (!Directory.Exists(processDirectory))
                {
                    Directory.CreateDirectory(processDirectory);
                }

                Log.message(LogEntryType.INFO, "DBAidCollector", "Starting DBAid Collector", logFile);
            }
            catch (Exception ex)
            {
                Log.message(LogEntryType.ERROR, "DBAidCollector", ex.Message + (logVerbose ? " - " + ex.StackTrace : ""), logFile);
                errorCount++;

                Smtp.send(emailSmtp, emailFrom, emailTo, Environment.MachineName, "Failed to initialise DBAid collector", null, emailAttachmentByteLimit, emailAttachmentCountLimit, emailEnableSsl, emailIgnoreSslError, emailAnonymous);
                Console.Write("Settings in App.Config may be incorrect and/or missing, or permissions to write log file is missing.");
                return;
            }

            try
            {
                //Clean up old files
                FileIo.delete(baseDirectory, "*" + logExt, DateTime.Now.AddDays(-7));

                FileIo.delete(processDirectory, "*" + processedExt, DateTime.Now.AddDays(fileRententionDays * -1));
            }
            catch (Exception ex)
            {
                Log.message(LogEntryType.WARNING, "DBAidCollector", ex.Message + (logVerbose ? " - " + ex.StackTrace : ""), logFile);
                warningCount++;
            }

            foreach (ConnectionStringSettings css in cssc)
            {
                DateTime runtime = DateTime.UtcNow;
                SqlConnectionStringBuilder csb = new SqlConnectionStringBuilder(css.ConnectionString);
                DataRowCollection procedures;
                List<string> attachments = new List<string>();
                string publicKey = String.Empty;
                string instanceTag = String.Empty;

                csb.ApplicationName = logID + Guid.NewGuid().ToString();
                Log.message(LogEntryType.INFO, "DBAidCollector", "Starting Collection on [" + csb.DataSource + "]", logFile);

                try
                {
                    // query database for assigned application name.
                    csb.ApplicationName = Query.Select(csb.ConnectionString, mssqlAppSelect).Rows[0][0].ToString();
                    // query database for instance guid.
                    instanceTag = Query.Execute(csb.ConnectionString, mssqlInstanceTagProc).Rows[0][0].ToString();

                    if (String.IsNullOrEmpty(instanceTag))
                        instanceTag = css.Name.Replace("\\", "@").Replace("_","~") + "_" + IPGlobalProperties.GetIPGlobalProperties().DomainName.Replace(".", "_");

                    // query database for public key.
                    publicKey = Query.Select(csb.ConnectionString, mssqlKeySelect).Rows[0][0].ToString();
                    // get procedure returned from control procedure.
                    procedures = Query.Select(csb.ConnectionString, mssqlControlProc).Rows;
                }
                catch (Exception ex)
                {
                    Log.message(LogEntryType.WARNING, "DBAidCollector", ex.Message + (logVerbose ? " - " + ex.StackTrace : ""), logFile);
                    warningCount++;
                    continue;
                }

                foreach (DataRow dr in procedures)
                {
                    string file = instanceTag + "_" + dr[0].ToString().Replace("].[", "_").Replace(".", "_") + "_" + runtime.ToString("yyyyMMddHHmmss") + encryptedExt;
                    string filepath = Path.Combine(workingDirectory, file);
                    // execute procedure, compress, and encrypt stream. Write contents out to file.
                    using (MemoryStream msRaw = new MemoryStream())
                    using (StreamWriter swRaw = new StreamWriter(msRaw, Encoding.Unicode))
                    {
                        try
                        {
                            DataTable dt = Query.Execute(csb.ConnectionString, dr[0].ToString());
                            StringBuilder sb = new StringBuilder(dt.TableName.Length);

                            foreach (char c in dt.TableName) // remove special characters from table name as this causes issues with SSIS xml source.
                            {
                                if ((c >= '0' && c <= '9') || (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z') || c == '-' || c == '_')
                                {
                                    sb.Append(c);
                                }
                            }

                            dt.TableName = sb.ToString();
                            dt.WriteXml(swRaw, XmlWriteMode.WriteSchema);
                            dt.Clear();
                        }
                        catch (Exception ex)
                        {
                            Log.message(LogEntryType.WARNING, "DBAidCollector", ex.Message + (logVerbose ? " - " + ex.StackTrace : ""), logFile);
                            warningCount++;
                            continue;
                        }

                        try
                        {
                            if (logVerbose)
                            {
                                Log.message(LogEntryType.INFO, "DBAidCollector", "Writing Encrypted File: \"" + filepath + "\"", logFile);
                            }

                            Crypto.encrypt(publicKey, msRaw, filepath);
                        }
                        catch (Exception ex)
                        {
                            Log.message(LogEntryType.WARNING, "DBAidCollector", ex.Message + (logVerbose ? " - " + ex.StackTrace : ""), logFile);
                            warningCount++;
                            continue;
                        }
                    }
                }

                Log.message(LogEntryType.INFO, "DBAidCollector", "Completed Collection on [" + csb.DataSource + "]", logFile); 

                try
                {
                    foreach (string file in Directory.GetFiles(workingDirectory, "*" + encryptedExt))
                    {
                        attachments.Add(file);
                    }
                       
                    string body = "DBAid collector process logged: \n\t"
                        + errorCount.ToString()
                        + " error(s) \n\t"
                        + warningCount.ToString()
                        + " warning(s) \n";

                    Smtp.send(emailSmtp, emailFrom, emailTo, emailSubject, body, attachments.ToArray(), emailAttachmentByteLimit, emailAttachmentCountLimit, emailEnableSsl, emailIgnoreSslError, emailAnonymous);

                    foreach (string file in attachments)
                    {
                        FileIo.move(file, Path.Combine(processDirectory, Path.GetFileName(file) + processedExt));
                    }

                    Log.message(LogEntryType.INFO, "DBAidCollector", "Email Sent to \"" + string.Join("; ", emailTo) + "\"", logFile);
                }
                catch (Exception ex)
                {
                    Log.message(LogEntryType.WARNING, "DBAidCollector", ex.Message + (logVerbose ? " - " + ex.StackTrace : ""), logFile);
                }
            }

            Log.message(LogEntryType.INFO, "DBAidCollector", "Completed DBAid Collection", logFile);

            //System.Threading.Thread.Sleep(10000);
        }
    }
}
