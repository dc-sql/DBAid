using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data.SqlClient;
using System.IO;
using dbaid.common;
using System.Xml;
using System.Xml.XPath;

namespace server.dbaid.extractor
{
    class Program
    {
        private const string privateKeyProc = "[dbo].[usp_crypto_privatekey]"; // Takes one parameter of servername. Needs to be in _dbaid_warehouse code, updated to return password used to encrypt 7z archive. Which will be different per server, not per customer by default. Unless process dictates using the same for all servers per customer.
        private const string ext = ".encrypted";  // will be .zip for DBAid 10.0.0 onwards.
        private const string processedDir = "processed";
        private const string processedExt = ".processed";
        private const string logID = "DBAid-Extractor-";
        private const string logExt = ".log";

        static void Main(string[] args)
        {
            Log.licenseHeader();

            string baseDirectory = AppDomain.CurrentDomain.BaseDirectory;
            string logFile = Path.Combine(baseDirectory, logID + DateTime.Now.ToString("yyyyMMdd") + logExt);
            string workingDirectory = String.Empty;
            string processDirectory = String.Empty;
            bool logVerbose = true;
            int fileRententionDays = 31;

            string inbox = String.Empty;
            string searchSubject = String.Empty;

            try
            {
                workingDirectory = ConfigurationManager.AppSettings["WorkingDirectory"];
                processDirectory = Path.Combine(workingDirectory, processedDir);
                logVerbose = bool.Parse(ConfigurationManager.AppSettings["LogVerbose"]);
                fileRententionDays = int.Parse(ConfigurationManager.AppSettings["ProcessedFileRetentionDays"]);

                inbox = ConfigurationManager.AppSettings["Inbox"];
                searchSubject = ConfigurationManager.AppSettings["SearchSubject"];

                if (!Directory.Exists(workingDirectory))
                {
                    Directory.CreateDirectory(workingDirectory);
                }

                if (!Directory.Exists(processDirectory))
                {
                    Directory.CreateDirectory(processDirectory);
                }  
            }
            catch (Exception ex)
            {
                Log.message(LogEntryType.ERROR, "DBAidExtractor", ex.Message + " - " + ex.StackTrace, logFile);
                Log.message(LogEntryType.ERROR, "DBAidExtractor", "Settings in App.Config may be incorrect and/or missing." + " - " + ex.StackTrace, logFile);
                Console.Write("Settings in App.Config may be incorrect and/or missing.");
                return;
            }

            try
            {
                //Clean up old log files
                FileIo.delete(baseDirectory, "*" + logExt, DateTime.Now.AddDays(-7));

                if (fileRententionDays > 0)
                {
                    fileRententionDays = fileRententionDays * -1;
                }

                //Clean up old processed files
                FileIo.delete(processDirectory, "*" + processedExt, DateTime.Now.AddDays(fileRententionDays));
            }
            catch (Exception ex)
            {
                Log.message(LogEntryType.WARNING, "DBAidExtractor", ex.Message + (logVerbose ? " - " + ex.StackTrace : ""), logFile);
            }

            Log.message(LogEntryType.INFO, "DBAidExtractor", "Starting DBAid Extractor", logFile);
            //download emails from exchange
            try
            {
                Exchange.DownloadAttachment(inbox, searchSubject, workingDirectory, logFile, logVerbose);
            }
            catch (Exception ex)
            {
                Log.message(LogEntryType.ERROR, "DBAidExtractor", ex.Message, logFile);
                Log.message(LogEntryType.ERROR, "DBAidExtractor", "Error Downloading attachment from exchange", logFile);
                throw;
            }

            ConnectionStringSettings css = ConfigurationManager.ConnectionStrings[0];
            SqlConnectionStringBuilder csb = new SqlConnectionStringBuilder(css.ConnectionString);
            csb.ApplicationName = logID + Guid.NewGuid().ToString();

            foreach (string fileToProcess in Directory.GetFiles(workingDirectory, "*" + ext))
            {
                Dictionary<string, object> parameters = new Dictionary<string, object>();
                string servername = Path.GetFileNameWithoutExtension(fileToProcess);
                //if the instance name has an underscore, convert back.
                if (servername.Substring(0, 1) == "[")
                {
                    servername = servername.Substring(1);
                    servername = servername.Split(']')[0];
                    parameters.Add("server_name", servername);
                }
                else
                {
                    servername = servername.Split('_')[0];
                    parameters.Add("server_name", servername);
                }

                /*********************************************************/
                /* All this will change due to using encrypted zip files */
                /*********************************************************/
                try /* Read in and decrypt encrypted files */
                {
                    string privateKey = Query.Execute(csb.ConnectionString, privateKeyProc, parameters).Rows[0][0].ToString();

                    try
                    {
                        using (MemoryStream ms = new MemoryStream(File.ReadAllBytes(fileToProcess)))
                        {
                            Crypto.decrypt(privateKey, ms, fileToProcess.Replace(ext, ".decrypted.xml"));
                        }
                    }
                    catch (Exception ex)
                    {      
                        Log.message(LogEntryType.WARNING, "DBAidExtractor", ex.Message + (logVerbose ? " - " + ex.StackTrace : ""), logFile);
                        Log.message(LogEntryType.WARNING, "DBAidExtractor", "Failed to decrypted "+fileToProcess, logFile);
                        continue;
                    }

                    try
                    {
                        FileIo.move(fileToProcess, Path.Combine(processDirectory, Path.GetFileName(fileToProcess) + ".processed"));
                    }
                    catch (Exception ex)
                    {
                        Log.message(LogEntryType.WARNING, "DBAidExtractor", ex.Message + (logVerbose ? " - " + ex.StackTrace : ""), logFile);
                        Log.message(LogEntryType.WARNING, "DBAidExtractor", "Failed to decrypted " + fileToProcess, logFile);
                        continue;
                    }

                    if (logVerbose)
                    {
                        Log.message(LogEntryType.INFO, "DBAidExtractor", "Processed file: " + fileToProcess, logFile);
                    }
                }
                catch (Exception ex)
                {
                    Log.message(LogEntryType.WARNING, "DBAidExtractor", ex.Message + (logVerbose ? " - " + ex.StackTrace : ""), logFile);
                    Log.message(LogEntryType.WARNING, "DBAidExtractor", "Could not decrypt file for "+servername+" Check if server exists in DailyCheck db server table and public private key is correct", logFile);
                    continue;
                }
            }

            Log.message(LogEntryType.INFO, "DBAidExtractor", "Finished processing encrypted files.", logFile);

            // try to move the files using the the setting in FileIo.Config
            try
            {
                string moveConfig = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, "move.config");
                XmlDocument doc = new XmlDocument();
                string source = String.Empty;
                string filter = String.Empty;
                string destination = String.Empty;

                if (File.Exists(moveConfig))
                {
                    doc.Load(moveConfig);

                    foreach (XPathNavigator child in doc.CreateNavigator().Select("move/file"))
                    {
                        source = child.SelectSingleNode("@source").Value;
                        filter = child.SelectSingleNode("@filter").Value;
                        destination = child.SelectSingleNode("@destination").Value;

                        List<MoveList> movedFiles = FileIo.movelist(source, filter, destination);
                     
                        foreach (MoveList i in movedFiles)
                        {
                            try
                            {
                                FileIo.move(i.sourcefile, i.destfile);
                                if (logVerbose)
                                {
                                    Log.message(LogEntryType.INFO, "DBAidExtractor", "Moved file: \"" + i.sourcefile + "\" > \"" + i.destfile + "\"", logFile);
                                }
                            }
                            catch (Exception ex)
                            {
                                Log.message(LogEntryType.WARNING, "DBAidExtractor", ex.Message + (logVerbose ? " - " + ex.StackTrace : ""), logFile);
                                Log.message(LogEntryType.WARNING, "DBAidExtractor", "Error occured when moving file: "+i.sourcefile, logFile);
                            }
                        } 
                    }
                }
                else
                {
                    Log.message(LogEntryType.INFO, "DBAidExtractor", "No \"move.config\" file found in executable directory, skipping. ", logFile);
                }
            }
            catch (Exception ex)
            {
                Log.message(LogEntryType.WARNING, "DBAidExtractor", ex.Message + (logVerbose ? " - " + ex.StackTrace : ""), logFile);
            }

            Log.message(LogEntryType.INFO, "DBAidExtractor", "Completed DBAid Extractor", logFile);
        }
    }
}
