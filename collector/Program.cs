using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.IO;

namespace collector
{
    class Program
    {
        private const string selectInstanceTag = "SELECT [instance_tag] FROM [system].[get_instance_tag]()";
        private const string selectProcedureList = "SELECT [procedure] FROM [dbo].[get_procedure_list](N'collector')";

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

            using (var con = new SqlConnection(csb.ConnectionString))
            {
                con.Open();

                if (log == "verbose")
                {
                    Console.WriteLine("{0} - Initializing Collector", runtime.ToShortTimeString());
                }

                var cmd = new SqlCommand();
                string instanceTag = String.Empty;
                List<string> procedures = new List<string>();
                SqlDataReader row = null;
                cmd.Connection = con;
                cmd.CommandType = CommandType.Text;

                cmd.CommandText = selectInstanceTag;
                row = cmd.ExecuteReader();
                row.Read();
                instanceTag = row[0].ToString();
                row.Close();

                cmd.CommandText = selectProcedureList;
                row = cmd.ExecuteReader();

                while (row.Read())
                {
                    procedures.Add(row[0].ToString());
                }

                row.Close();

                cmd.Parameters.Add(new SqlParameter("@update_execution_timestamp", true));

                if (sanitize == "false")
                    cmd.Parameters.Add(new SqlParameter("@sanitize", false));

                foreach (string proc in procedures)  // execute procedures and write contents out to file.
                {
                    string procTag = proc.Replace("[", "").Replace("]", "").Replace(".", "_");
                    string file = instanceTag + "_" + procTag + "_" + runtime.ToString("yyyyMMddHHmm") + ".xml";
                    string filepath = Path.Combine(output, file);

                    cmd.CommandType = CommandType.StoredProcedure;
                    cmd.CommandText = proc;

                    DataTable dt = new DataTable();
                    dt.TableName = procTag;
                    dt.Load(cmd.ExecuteReader());
                    dt.WriteXml(filepath, XmlWriteMode.WriteSchema);

                    if (log == "verbose")
                    {
                        Console.WriteLine("{0} - Output XML file to disk [{1}]", runtime.ToShortTimeString(), filepath);
                    }
                }

                con.Close();

                if (log == "verbose")
                {
                    Console.WriteLine("{0} - Completed Collection on [{1}]", runtime.ToShortTimeString(), csb.DataSource);
                }
            }
#if DEBUG 
            Console.ReadKey();
#endif
        }
    }
}
