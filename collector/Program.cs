using System;
using System.Configuration;
using System.Data;
using System.Data.SqlClient;
using System.IO;

namespace collector
{
    class Program
    {
        private const string getProcListSql = "";

        static void Main(string[] args)
        {
            DateTime runtime = DateTime.UtcNow;
            ConnectionStringSettingsCollection settings = ConfigurationManager.ConnectionStrings;

            foreach (ConnectionStringSettings cs in settings)
            {
                var csb = new SqlConnectionStringBuilder(cs.ConnectionString)
                {
                    ApplicationName = "dbaid-collector",
                    Encrypt = true,
                    TrustServerCertificate = true,
                    ConnectTimeout = 5
                };

                using (var con = new SqlConnection(csb.ConnectionString))
                {
                    string instanceTag = String.Empty;
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
