using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.IO;
using Microsoft.Win32;

namespace collector
{
    class Program
    {
        private const string getProcListSql = "";

        static void Main(string[] args)
        {
            DateTime runtime = DateTime.UtcNow;
            var sqlInstances = new List<string>();

            // Get list of local instances
            using (RegistryKey hklm = RegistryKey.OpenRemoteBaseKey(RegistryHive.LocalMachine, Environment.MachineName))
            {
                RegistryKey instanceKey = hklm.OpenSubKey(@"SOFTWARE\Microsoft\Microsoft SQL Server\Instance Names\SQL", false);
                RegistryKey wowInstanceKey = hklm.OpenSubKey(@"SOFTWARE\Wow6432Node\Microsoft\Microsoft SQL Server\Instance Names\SQL", false);

                if (instanceKey != null)
                {
                    foreach (var instanceName in instanceKey.GetValueNames())
                    {
                        sqlInstances.Add(instanceName.ToUpper());
                    }
                }
                if (wowInstanceKey != null)
                {
                    foreach (var instanceName in wowInstanceKey.GetValueNames())
                    {
                        sqlInstances.Add(instanceName.ToUpper());
                    }
                }
            }

            foreach (string instance in sqlInstances)
            {
                var csb = new SqlConnectionStringBuilder
                {
                    ApplicationName = "DBAid - Collector",
                    DataSource = instance == "MSSQLSERVER" ? Environment.MachineName : Environment.MachineName + "\\" + instance,
                    InitialCatalog = "_dbaid",
                    IntegratedSecurity = true,
                    Encrypt = true,
                    TrustServerCertificate = true,
                    ConnectTimeout = 5
                };

                using (var con = new SqlConnection(csb.ConnectionString))
                {
                    string instanceTag = String.Empty;
                    bool sanitise = true;
                    DataRowCollection procedures = null;

                    Console.WriteLine("{0} - Initializing Collector", runtime.ToShortTimeString());

                    try
                    {
                        con.Open();

                        // Get Instance Tag
                        using (var cmd = new SqlCommand("[system].[get_instance_tag]", con) { CommandType = CommandType.StoredProcedure })
                        using (var reader = cmd.ExecuteReader())
                        {
                            if (reader.Read())
                                instanceTag = reader.GetString(0);
                        }

                        // Get Sanitise preference
                        using (var cmd = new SqlCommand("SELECT CAST([value] AS BIT) FROM [_dbaid].[system].[configuration] WHERE [key] = 'SANITISE_COLLECTOR_DATA'", con) { CommandType = CommandType.Text })
                        using (var reader = cmd.ExecuteReader())
                        {
                            if (reader.Read())
                                sanitise = reader.GetBoolean(0);
                        }

                        // Get list of procedures
                        using (var cmd = new SqlCommand("SELECT QUOTENAME(SCHEMA_NAME([schema_id])) + N'.' + QUOTENAME([name]) FROM sys.objects WHERE [type] = 'P' AND SCHEMA_NAME([schema_id]) = 'collector'", con) { CommandType = CommandType.Text })
                        {
                            DataTable dt = new DataTable();
                            dt.Load(cmd.ExecuteReader());
                            procedures = dt.Rows;
                        }

                        // execute procedures and write contents out to file.
                        foreach (DataRow dr in procedures)  
                        {
                            string proc = dr[0].ToString();
                            string procTag = proc.ToString().Substring(proc.IndexOf('_') + 1).Replace("]", "");
                            string file = instanceTag + "_" + procTag + "_" + runtime.ToString("yyyyMMddHHmm") + ".xml";
                            string filepath = Path.Combine(AppDomain.CurrentDomain.BaseDirectory, file);

                            try
                            {
                                using (var cmd = new SqlCommand(proc, con))
                                {
                                    cmd.CommandType = CommandType.StoredProcedure;
                                    cmd.Parameters.Add(new SqlParameter("@update_execution_timestamp", true));
                                    if (!sanitise) { cmd.Parameters.Add(new SqlParameter("@sanitise", false)); }

                                    DataTable dt = new DataTable { TableName = procTag };
                                    dt.Load(cmd.ExecuteReader());
                                    dt.WriteXml(filepath, XmlWriteMode.WriteSchema);
                                }

                                Console.WriteLine("Output XML file to disk [{0}]", filepath);
                            }
                            catch (SqlException e)
                            {
                                Console.ForegroundColor = ConsoleColor.Red;
                                Console.WriteLine("Failed to complete collection on {0}", con.DataSource);
                                Console.WriteLine(e.Message);
                                Console.ForegroundColor = ConsoleColor.White;
                            }
                        }

                        Console.WriteLine("Completed Collection on [{0}]", csb.DataSource);
                        con.Close();
                    }
                    catch (SqlException e)
                    {

                        Console.ForegroundColor = ConsoleColor.Red;
                        Console.WriteLine("Failed to complete collection on {0}", con.DataSource);
                        Console.WriteLine(e.Message);
                        Console.ForegroundColor = ConsoleColor.White;
                    }
                }
            }
#if DEBUG 
            Console.ReadKey();
#endif
        }
    }
}
