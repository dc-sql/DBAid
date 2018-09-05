using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Text;
using Microsoft.Win32;

namespace local.dbaid.checkmk
{
    class Program
    {
        private const string getProcListSql = "SELECT QUOTENAME(SCHEMA_NAME([schema_id])) + N'.' + QUOTENAME([name]) AS [procedure] FROM sys.objects "
            + "WHERE[type] = 'P' AND SCHEMA_NAME([schema_id]) = @schema AND([name] LIKE @filter OR @filter IS NULL)";

        static void Main(string[] args)
        {
            List<string> sqlInstances = new List<string>();
            
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
                DoCheck(instance);
            }
#if DEBUG
            Console.ReadKey();
#endif
        }

        static void DoCheck(string instance)
        {
            SqlConnectionStringBuilder csb = new SqlConnectionStringBuilder()
            {
                ApplicationName = "Check_Mk - mssql plugin",
                DataSource = instance == "MSSQLSERVER" ? Environment.MachineName : Environment.MachineName + "\\" + instance,
                IntegratedSecurity = true,
                InitialCatalog = "_dbaid",
                Encrypt = true,
                TrustServerCertificate = true,
                ConnectTimeout = 5
            };

            using (var con = new SqlConnection(csb.ConnectionString))
            {
                try
                {
                    con.Open();

                    Console.WriteLine("{0} mssql_{1}_{2} count={3} {4}{5}", StatusCode("OK"), instance, "service", 1, "OK - ", con.ServerVersion);
                }
                catch (Exception e)
                {
                    Console.WriteLine("{0} mssql_{1}_{2} count={3} {4}{5}", StatusCode("CRITICAL"), instance, "service", 1, "CRITICAL - ", e.Message);
#if DEBUG
                    Console.ReadKey();
#endif
                    return;
                }

                using (var cmd = new SqlCommand(getProcListSql, con) { CommandTimeout = 5 })
                {
                    cmd.CommandType = CommandType.Text;
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

                using (var cmd = new SqlCommand(getProcListSql, con) { CommandTimeout = 45 })
                {
                    cmd.CommandType = CommandType.Text;
                    cmd.Parameters.Add(new SqlParameter("@schema", "checkmk"));
                    cmd.Parameters.Add(new SqlParameter("@filter", "check%"));

                    DataTable dt = new DataTable();
                    dt.Load(cmd.ExecuteReader());

                    foreach (DataRow dr in dt.Rows)
                    {
                        using (var check = new SqlCommand(dr[0].ToString(), con))
                        {
                            check.CommandType = CommandType.StoredProcedure;

                            DataTable results = new DataTable();
                            results.Load(check.ExecuteReader());

                            string procTag = dr[0].ToString().Substring(dr[0].ToString().IndexOf('_') + 1).Replace("]", "");
                            StringBuilder message = new StringBuilder();
                            int code = 0;

                            foreach (DataRow row in results.Rows)
                            {
                                message.AppendFormat("{0} - {1};\\n ", row[0].ToString(), row[1].ToString());

                                if (StatusCode(row[0].ToString()) > code)
                                {
                                    code = StatusCode(row[0].ToString());
                                }
                            }

                            Console.WriteLine("{0} mssql_{1}_{2} count={3} {4}", code, instance, procTag, results.Rows.Count, message);
                        }
                    }
                }

                using (var cmd = new SqlCommand(getProcListSql, con) { CommandTimeout = 45 })
                {
                    cmd.CommandType = CommandType.Text;
                    cmd.Parameters.Add(new SqlParameter("@schema", "checkmk"));
                    cmd.Parameters.Add(new SqlParameter("@filter", "chart_capacity%"));

                    DataTable dt = new DataTable();
                    dt.Load(cmd.ExecuteReader());

                    foreach (DataRow dr in dt.Rows)
                    {
                        string proc = dr[0].ToString();

                        using (var chart = new SqlCommand(proc, con))
                        {
                            chart.CommandType = CommandType.StoredProcedure;

                            DataTable results = new DataTable();
                            results.Load(chart.ExecuteReader());

                            int returnCode = StatusCode("OK");
                            string procTag = proc.ToString().Substring(proc.IndexOf('_') + 1).Replace("]", "");
                            StringBuilder pnpData = new StringBuilder();
                            StringBuilder message = new StringBuilder();

                            foreach (DataRow row in results.Rows)
                            {
                                string name = String.Empty;
                                decimal used = -1;
                                decimal reserved = -1;
                                decimal max = -1;
                                decimal warning = -1;
                                decimal critical = -1;


                                if (results.Columns.Contains("name"))
                                    if (!row.IsNull("name"))
                                    {
                                        name = (string)row["name"];
                                        pnpData.AppendFormat("'{0}_used'=", name);
                                    }

                                if (results.Columns.Contains("used"))
                                    if (!row.IsNull("used"))
                                    {
                                        used = (decimal)row["used"];
                                        pnpData.Append(used);
                                    }

                                pnpData.Append(";");

                                if (results.Columns.Contains("warning"))
                                    if (!row.IsNull("warning"))
                                    {
                                        warning = (decimal)row["warning"];
                                        pnpData.Append(warning);
                                    }

                                pnpData.Append(";");

                                if (results.Columns.Contains("critical"))
                                    if (!row.IsNull("critical"))
                                    {
                                        critical = (decimal)row["critical"];
                                        pnpData.Append(critical);
                                    }

                                pnpData.Append(";");

                                if (results.Columns.Contains("max"))
                                    if (!row.IsNull("max"))
                                    {
                                        max = (decimal)row["max"];
                                        pnpData.Append(max);
                                    }

                                if (results.Columns.Contains("reserved"))
                                    if (!row.IsNull("reserved"))
                                    {
                                        reserved = (decimal)row["reserved"];
                                        pnpData.AppendFormat("|'{0}_reserved'={1};;;;", name, reserved);
                                    }

                                if (used >= critical && critical != -1)
                                {
                                    returnCode = StatusCode("CRITICAL");
                                    message.AppendFormat(" CRITICAL - {0}_used;", name);
                                }
                                else if (used >= warning && warning != -1)
                                {
                                    if (returnCode != StatusCode("CRITICAL"))
                                    {
                                        returnCode = StatusCode("WARNING");
                                    }

                                    message.AppendFormat(" WARNING - {0}_used;", name);
                                }
                            }

                            Console.WriteLine("{0} mssql_{1}_{2} {3}", returnCode, instance, procTag, pnpData, message);
                        }
                    }
                }

                con.Close();
            }
        }

        static int StatusCode(string status)
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
                case "UNKNOWN":
                    return 3;
                default:
                    return 3;
            }
        }
    }
}
