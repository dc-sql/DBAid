using System;
using System.Configuration;
using System.Data;
using System.Data.SqlClient;
using System.Text;

namespace local.dbaid.checkmk
{
    class Program
    {
        static void Main(string[] args)
        {
            ConnectionStringSettingsCollection settings = ConfigurationManager.ConnectionStrings;

            foreach (ConnectionStringSettings css in settings)
            {
                SqlConnectionStringBuilder csb = new SqlConnectionStringBuilder(css.ConnectionString);
                csb.Encrypt = true;
                csb.TrustServerCertificate = true;

                if (String.IsNullOrEmpty(csb.InitialCatalog))
                    csb.InitialCatalog = "_dbaid";
                if (String.IsNullOrEmpty(csb.UserID) || String.IsNullOrEmpty(csb.Password))
                    csb.IntegratedSecurity = true;
                else csb.IntegratedSecurity = false;

                using (var con = new SqlConnection(csb.ConnectionString))
                {
                    string instanceTag = String.Empty;

                    con.Open();

                    using (var cmd = new SqlCommand("[system].[get_instance_tag]", con))
                    {
                        cmd.CommandType = CommandType.StoredProcedure;
                        SqlDataReader row = cmd.ExecuteReader();

                        row.Read();
                        instanceTag = row[0].ToString();
                        row.Close();
                    }

                    using (var cmd = new SqlCommand("[system].[get_procedure_list]", con))
                    {
                        cmd.CommandType = CommandType.StoredProcedure;
                        cmd.Parameters.Add(new SqlParameter("@schema", "checkmk"));
                        cmd.Parameters.Add(new SqlParameter("@filter", "inventory%"));

                        DataTable dt = new DataTable();
                        dt.Load(cmd.ExecuteReader());

                        foreach (DataRow dr in dt.Rows)
                        {
                            string proc = dr[0].ToString();

                            using (var inventory = new SqlCommand(proc, con))
                            {
                                inventory.CommandType = CommandType.StoredProcedure;
                                inventory.ExecuteNonQuery();
                            }
                        }
                    }

                    using (var cmd = new SqlCommand("[system].[get_procedure_list]", con))
                    {
                        cmd.CommandType = CommandType.StoredProcedure;
                        cmd.Parameters.Add(new SqlParameter("@schema", "checkmk"));
                        cmd.Parameters.Add(new SqlParameter("@filter", "check%"));

                        DataTable dt = new DataTable();
                        dt.Load(cmd.ExecuteReader());

                        foreach (DataRow dr in dt.Rows)
                        {
                            string proc = dr[0].ToString();
                            string procTag = proc.ToString().Substring(proc.LastIndexOf('_')+1).Replace("]","");

                            using (var check = new SqlCommand(proc, con))
                            {
                                check.CommandType = CommandType.StoredProcedure;

                                DataTable results = new DataTable();
                                results.Load(check.ExecuteReader());

                                StringBuilder message = new StringBuilder();
                                int code = 0; 

                                foreach (DataRow row in results.Rows)
                                {
                                    message.AppendFormat("{0} - {1};\\n ", row[0].ToString(), row[1].ToString());

                                    if (statusCode(row[0].ToString()) > code)
                                    {
                                        code = statusCode(row[0].ToString());
                                    }
                                }

                                Console.WriteLine("{0} mssql_{1}_{2} count={3} {4}", code, instanceTag, procTag, results.Rows.Count, message);
                            }
                        }
                    }

                    using (var cmd = new SqlCommand("[system].[get_procedure_list]", con))
                    {
                        cmd.CommandType = CommandType.StoredProcedure;
                        cmd.Parameters.Add(new SqlParameter("@schema", "checkmk"));
                        cmd.Parameters.Add(new SqlParameter("@filter", "chart%"));

                        DataTable dt = new DataTable();
                        dt.Load(cmd.ExecuteReader());

                        foreach (DataRow dr in dt.Rows)
                        {
                            string proc = dr[0].ToString();
                            string procTag = proc.ToString().Substring(proc.LastIndexOf('_') + 1).Replace("]", "");

                            using (var chart = new SqlCommand(proc, con))
                            {
                                chart.CommandType = CommandType.StoredProcedure;

                                DataTable results = new DataTable();
                                results.Load(chart.ExecuteReader());

                                foreach (DataRow row in results.Rows)
                                {
                                    Console.WriteLine("Do Something");
                                }
                            }
                        }
                    }

                    con.Close();
                }
            }
#if DEBUG
            Console.ReadKey();
#endif
        }

        static int statusCode(string status)
        {
            switch (status.ToUpper())
            {
                case "NA":
                    return 0;
                case "OK":
                    return 0;
                case "WARNING":
                    return 1;
                case "CRITICAL":
                    return 2;
                default:
                    return 3;
            }
        }
    }
}
