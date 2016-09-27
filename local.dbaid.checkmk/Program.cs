using System;
using System.Configuration;
using System.Collections.Generic;
using System.Data;
using System.Text;
using dbaid.common;

namespace local.dbaid.checkmk
{
    class Program
    {
        private const string mssqlBadge = "mssql";
        private const string mssqlConfigCheck = "[maintenance].[check_config]";
        private const string mssqlControlCheck = "[control].[check]";
        private const string mssqlControlChart = "[control].[chart]";
        private const string mssqlEditionCheck = "SELECT * FROM [dbo].[cleanstring](@@VERSION)";

        static int Main(string[] args)
        {
            string isCheck = ConfigurationManager.AppSettings["is_check_enabled"];
            string isChart = ConfigurationManager.AppSettings["is_chart_enabled"];
            int defaultCmdTimout = int.Parse(ConfigurationManager.AppSettings["default_cmd_timeout_sec"]);

            ConnectionStringSettingsCollection settings = ConfigurationManager.ConnectionStrings;

            foreach (ConnectionStringSettings connStr in settings)
            {
                string cs = connStr.ConnectionString;
                string instance = connStr.Name;

                DataSet cds = new DataSet(); //Command dataset
                DataSet rds = new DataSet(); //Result dataset

                try
                {
                    // refresh check configuration
                    Query.Execute(cs, mssqlConfigCheck, defaultCmdTimout);

                    // output service version
                    Console.WriteLine("0 {0}_{1} - {2}", "mssql", instance, Query.Select(cs, mssqlEditionCheck, defaultCmdTimout).Rows[0][0].ToString());

                    if (isCheck == "1")
                    {
                        // get list of executable check commands
                        cds.Tables.Add(Query.Execute(cs, mssqlControlCheck, defaultCmdTimout));
                        cds.Tables[mssqlControlCheck].PrimaryKey = new DataColumn[] { cds.Tables[mssqlControlCheck].Columns[0] };
                    }

                    if (isChart == "1")
                    {
                        // get list of executable chart commands
                        cds.Tables.Add(Query.Execute(cs, mssqlControlChart, defaultCmdTimout));
                        cds.Tables[mssqlControlChart].PrimaryKey = new DataColumn[] { cds.Tables[mssqlControlChart].Columns[0] };
                    }

                    // execute each procedures that are returned by the control commands
                    foreach (DataTable dt in cds.Tables)
                    {
                        foreach (DataRow dr in dt.Rows)
                        {
                            rds.Tables.Add(Query.Execute(cs, dr[0].ToString(), defaultCmdTimout));
                        }
                    }

                    // Console out the results for Check_MK
                    foreach (DataTable dt in rds.Tables)
                    {
                        // if data table contains data from a check procedure, then format in check format.
                        if (cds.Tables[mssqlControlCheck].Rows.Contains(dt.TableName))
                        {
                            Console.WriteLine(CheckMK.FormatCheck(dt, instance));
                        }
                        // else if data table contains data from a chart procedure, then format in chart format.
                        else if (cds.Tables[mssqlControlChart].Rows.Contains(dt.TableName))
                        {
                            Console.WriteLine(CheckMK.FormatChart(dt, instance));
                        }
                    }
                }
                catch (Exception e)
                {
                    Console.WriteLine("2 {0}_{1} - {2}", mssqlBadge, connStr.Name.ToUpper(), e.Message);

                    return 2;
                }
            }
#if (DEBUG)
            Console.ReadKey();
#endif
            return 1;
        }
    }
}
