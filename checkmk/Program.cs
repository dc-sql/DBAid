using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data;
using System.Data.SqlClient;
using System.Text;
using System.IO;

namespace local.dbaid.checkmk
{
    class Program
    {
        private const string getProcListSql = "SELECT '[checkmk].' + QUOTENAME([name]) AS [procedure] FROM sys.objects WHERE[type] = 'P' AND SCHEMA_NAME([schema_id]) = 'checkmk' AND([name] LIKE @filter OR @filter IS NULL)";
        private const string getDbaidVersionSql = "SELECT [type_version] FROM msdb.dbo.sysdac_instances WHERE [instance_name] = N'_dbaid'";

        static void Main(string[] args)
        {
            var appSettings = new Dictionary<string, uint>();

            foreach (var key in ConfigurationManager.AppSettings.AllKeys)
            {
                appSettings.Add(key, uint.Parse(ConfigurationManager.AppSettings[key]));
            }

            ConnectionStringSettingsCollection settings = ConfigurationManager.ConnectionStrings;

            foreach (ConnectionStringSettings cs in settings)
            {
                SqlConnectionStringBuilder csb = new SqlConnectionStringBuilder(cs.ConnectionString)
                {
                    ApplicationName = "dbaid-checkmk",
                    Encrypt = true,
                    TrustServerCertificate = true,
                    ConnectTimeout = 5
                };

                using (var conn = new SqlConnection(csb.ConnectionString))
                {
                    bool isClustered = false;
                    string netBIOSname = Environment.MachineName;
                    string dbaidVersion = String.Empty;

                    try
                    {
                        conn.Open();
                        
                        //check if clustered and primary
                        using (var cmd = new SqlCommand("SELECT CAST(SERVERPROPERTY('IsClustered') AS BIT)", conn) { CommandTimeout = 2, CommandType = CommandType.Text })
                        using (var reader = cmd.ExecuteReader())
                        {
                            if (reader.Read())
                                isClustered = reader.GetBoolean(0);
                        }

                        using (var cmd = new SqlCommand("SELECT SERVERPROPERTY('ComputerNamePhysicalNetBIOS')", conn) { CommandTimeout = 5, CommandType = CommandType.Text })
                        using (var reader = cmd.ExecuteReader())
                        {
                            if (reader.Read())
                                netBIOSname = reader.GetString(0);
                        }

                        if (Environment.MachineName != netBIOSname && isClustered)
                        {
                            continue;
                        }

                        using (var cmd = new SqlCommand(getDbaidVersionSql, conn) { CommandTimeout = 5, CommandType = CommandType.Text })
                        using (var reader = cmd.ExecuteReader())
                        {
                            if (reader.Read())
                                dbaidVersion = reader.GetString(0);
                        }

                        // Output instance service check
                        Console.WriteLine("{0} mssql_{1}_{2} count={3} {4} - SQL Version={5}; DBAid Version={6}", StatusCode("OK"), cs.Name, "service", 1, "OK", conn.ServerVersion, dbaidVersion);

                        // Inventory the SQL Instance
                        using (var cmd = new SqlCommand(getProcListSql, conn) { CommandTimeout = 5, CommandType = CommandType.Text })
                        {
                            cmd.Parameters.Add(new SqlParameter("@filter", "inventory%"));

                            DataTable dt = new DataTable();
                            dt.Load(cmd.ExecuteReader());

                            foreach (DataRow dr in dt.Rows)
                            {
                                string proc = dr[0].ToString();

                                using (var inventory = new SqlCommand(proc, conn))
                                {
                                    inventory.CommandType = CommandType.StoredProcedure;
                                    inventory.ExecuteNonQuery();
                                }
                            }
                        }

                        // output check procedures
                        DoCheck(conn, cs.Name, ref appSettings);

                        // output chart procedures
                        DoChart(conn, cs.Name, ref appSettings);
                    }
                    catch (Exception e)
                    {
                        Console.WriteLine("{0} mssql_{1}_{2} count={3} {4} - {5}", StatusCode("CRITICAL"), cs.Name, "service", 1, "CRITICAL", e.Message);
                    }
                }
            }
#if DEBUG
            Console.ReadKey();
#endif
        }

        static void DoCheck(SqlConnection conn, string instance, ref Dictionary<string, uint> appSettings)
        {
            using (var cmd = new SqlCommand(getProcListSql, conn) { CommandTimeout = 45, CommandType = CommandType.Text })
            {
                cmd.Parameters.Add(new SqlParameter("@filter", "check%"));

                DataTable dt = new DataTable();
                dt.Load(cmd.ExecuteReader());

                foreach (DataRow dr in dt.Rows)
                {
                    string procedure = dr[0].ToString();
                    string cacheName = "cache_" + procedure.Substring(procedure.IndexOf(".") + 1).TrimStart('[').TrimEnd(']');
                    string cacheFile = instance + "_" + cacheName;
                    bool refreshCache = false;

                    if (appSettings.ContainsKey(cacheName))
                    {
                        uint cacheSeconds = appSettings[cacheName];
                        if (File.Exists(cacheFile))
                        {
                            DateTime cacheDate = File.GetLastWriteTime(cacheFile);

                            if ((DateTime.Now - cacheDate).TotalSeconds < cacheSeconds)
                            {
                                Console.WriteLine(File.ReadAllText(cacheFile));
                                continue;
                            }
                            else
                            {
                                refreshCache = true;
                            }
                        }
                        else
                        {
                            refreshCache = true;
                        }
                    }

                    using (var check = new SqlCommand(procedure, conn) { CommandType = CommandType.StoredProcedure })
                    {
                        DataTable results = new DataTable();
                        results.Load(check.ExecuteReader());

                        string procTag = procedure.Substring(procedure.IndexOf('_') + 1).Replace("]", "");
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

                        if (refreshCache)
                            File.WriteAllText(cacheFile, string.Format("{0} mssql_{1}_{2} count={3} {4}", code, instance, procTag, results.Rows.Count, message));

                        Console.WriteLine("{0} mssql_{1}_{2} count={3} {4}", code, instance, procTag, results.Rows.Count, message);
                    }
                }
            }
        }

        static void DoChart(SqlConnection conn, string instance, ref Dictionary<string, uint> appSettings)
        {
            using (var cmd = new SqlCommand(getProcListSql, conn) { CommandTimeout = 45, CommandType = CommandType.Text })
            {
                cmd.Parameters.Add(new SqlParameter("@filter", "chart_capacity%"));

                DataTable dt = new DataTable();
                dt.Load(cmd.ExecuteReader());

                foreach (DataRow dr in dt.Rows)
                {
                    string procedure = dr[0].ToString();
                    string cacheName = "cache_" + procedure.Substring(procedure.IndexOf(".")+1).TrimStart('[').TrimEnd(']');
                    string cacheFile = instance + "_" + cacheName;
                    bool refreshCache = false;

                    if (appSettings.ContainsKey(cacheName))
                    {
                        uint cacheSeconds = appSettings[cacheName];
                        if (File.Exists(cacheFile))
                        {
                            DateTime cacheDate = File.GetLastWriteTime(cacheFile);

                            if ((DateTime.Now - cacheDate).TotalSeconds < cacheSeconds)
                            {
                                Console.WriteLine(File.ReadAllText(cacheFile));
                                continue;
                            }
                            else
                            {
                                refreshCache = true;
                            }
                        }
                        else
                        {
                            refreshCache = true;
                        }
                    }

                    using (var chart = new SqlCommand(procedure, conn) { CommandType = CommandType.StoredProcedure })
                    {
                        DataTable results = new DataTable();
                        results.Load(chart.ExecuteReader());

                        int returnCode = StatusCode("OK");
                        string procTag = procedure.Substring(procedure.IndexOf('_') + 1).Replace("]", "");
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

                        if (refreshCache)
                            File.WriteAllText(cacheFile, string.Format("{0} mssql_{1}_{2} {3}", returnCode, instance, procTag, pnpData, message));

                        Console.WriteLine("{0} mssql_{1}_{2} {3}", returnCode, instance, procTag, pnpData, message);
                    }
                }
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
