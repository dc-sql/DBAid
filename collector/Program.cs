using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.IO;

namespace collector
{
    class Program
    {
        static void Help()
        {
            Console.WriteLine("-server localhost\\inst (Mandatory)");
            Console.WriteLine("-database _dbaid (Optional) default _dbaid");
            Console.WriteLine("-sanitize [true | false] (Optional) default true");
            Console.WriteLine("-output C:\\Datacom (Optional) default application executable directory");
            Console.WriteLine("-log [none | verbose] (Optional) default none");
        }

        static void Main(string[] args)
        {
            DateTime runtime = DateTime.UtcNow;
            var arguments = new Dictionary<string, string>();

            if (args.Length == 0)
            {
                Help();
                throw new ArgumentNullException("No arguments were passed.");
            }
            // Begin processing arguments
            for (int i = 0; i < args.Length; i = i + 2)
            {
                if (args[i] == @"/?" || args[i + 1] == @"/?")
                {
                    Help();
                    return;
                }

                arguments.Add(args[i], args[i + 1]);
            }
            // End processing arguments

            if (string.IsNullOrEmpty(arguments["-server"]))
            {
                throw new ArgumentNullException("Mandatory argument -server missing. //? for help.");
            }
           
            string server = arguments["-server"];
            string database = arguments.ContainsKey("-database") ? arguments["-database"] : "_dbaid";
            string sanitize = arguments.ContainsKey("-sanitize") ? arguments["-sanitize"] : "true";
            string output = arguments.ContainsKey("-output") ? arguments["-output"] : AppDomain.CurrentDomain.BaseDirectory;
            string log = arguments.ContainsKey("-log") ? arguments["-log"] : "none";

            if (!Directory.Exists(output))
            {
                throw new DirectoryNotFoundException("The output directory -output does not exist");
            }

            var csb = new SqlConnectionStringBuilder();
            csb.DataSource = server;
            csb.InitialCatalog = database;
            csb.IntegratedSecurity = true;
            csb.Encrypt = true;
            csb.TrustServerCertificate = true;

            string getProcListSql = "SELECT QUOTENAME(SCHEMA_NAME([schema_id])) + N'.' + QUOTENAME([name]) AS [procedure] FROM sys.objects "
                                    + "WHERE[type] = 'P' AND SCHEMA_NAME([schema_id]) = @schema AND([name] LIKE @filter OR @filter IS NULL)";


            using (var con = new SqlConnection(csb.ConnectionString))
            {
                string instanceTag = String.Empty;
                DataRowCollection procedures = null; 

                if (log == "verbose")
                {
                    Console.WriteLine("{0} - Initializing Collector", runtime.ToShortTimeString());
                }

                con.Open();

                using (var cmd = new SqlCommand("[system].[get_instance_tag]", con))
                {
                    cmd.CommandType = CommandType.StoredProcedure;
                    SqlDataReader row = cmd.ExecuteReader();

                    row.Read();
                    instanceTag = row[0].ToString();
                    row.Close();
                }

                using (var cmd = new SqlCommand(getProcListSql, con))
                {
                    cmd.CommandType = CommandType.Text;
                    cmd.Parameters.Add(new SqlParameter("@schema", "collector"));

                    DataTable dt = new DataTable();
                    dt.Load(cmd.ExecuteReader());
                    procedures = dt.Rows;
                }

                foreach (DataRow dr in procedures)  // execute procedures and write contents out to file.
                {
                    string proc = dr[0].ToString();
                    string procTag = proc.ToString().Substring(proc.IndexOf('_') + 1).Replace("]", "");
                    string file = instanceTag + "_" + procTag + "_" + runtime.ToString("yyyyMMddHHmm") + ".xml";
                    string filepath = Path.Combine(output, file);

                    using (var cmd = new SqlCommand(proc, con))
                    {
                        cmd.CommandType = CommandType.StoredProcedure;
                        cmd.Parameters.Add(new SqlParameter("@update_execution_timestamp", true));
                        if (sanitize == "false") { cmd.Parameters.Add(new SqlParameter("@sanitize", false)); }

                        DataTable dt = new DataTable();
                        dt.TableName = procTag;
                        dt.Load(cmd.ExecuteReader());
                        dt.WriteXml(filepath, XmlWriteMode.WriteSchema);
                    }

                    if (log == "verbose")
                    {
                        Console.WriteLine("{0} - Output XML file to disk [{1}]", runtime.ToShortTimeString(), filepath);
                    }
                }

                con.Close();
            }

            if (log == "verbose")
            {
                Console.WriteLine("{0} - Completed Collection on [{1}]", runtime.ToShortTimeString(), csb.DataSource);
            }
#if DEBUG 
            Console.ReadKey();
#endif
        }
    }
}
