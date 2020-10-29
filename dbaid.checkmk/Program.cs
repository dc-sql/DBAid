using System;
using System.IO;
using System.Configuration;
using System.Collections.Specialized;
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
        private const string isClustered = "SELECT SERVERPROPERTY('IsClustered')";
        private const string netBIOSname = "SELECT SERVERPROPERTY('ComputerNamePhysicalNetBIOS')";

        static int Main(string[] args)
        {
            NameValueCollection isCached = (NameValueCollection)ConfigurationManager.GetSection("checkCache");
            string isCheck = ConfigurationManager.AppSettings["is_check_enabled"];
            string isChart = ConfigurationManager.AppSettings["is_chart_enabled"];
            int defaultCmdTimout = int.Parse(ConfigurationManager.AppSettings["default_cmd_timeout_sec"]);

            //To get the location the assembly normally resides on disk or the install directory
            string path = AppDomain.CurrentDomain.BaseDirectory;
            //once you have the path you get the directory with:
            DirectoryInfo directory = Directory.GetParent(Path.GetDirectoryName(path));
            //DirectoryInfo parentDir = Directory.GetParent(directory);
            string spoolpath = directory.ToString()+"\\spool\\";
            //string spoolpath = checkmkpath.ToString(); //default path for checkmk fix to find path

            ConnectionStringSettingsCollection settings = ConfigurationManager.ConnectionStrings;

            string machinename = Environment.MachineName;

            foreach (ConnectionStringSettings connStr in settings)
            {
                string cs = connStr.ConnectionString;
                string instance = connStr.Name;

                DataSet cds = new DataSet(); //Command dataset
                DataSet rds = new DataSet(); //Result dataset

                try
                {
                    //check if clustered and primary
                    string isClusteredResult = Query.Select(cs, isClustered, defaultCmdTimout).Rows[0][0].ToString();
                    string netBIOSnameResult = Query.Select(cs, netBIOSname, defaultCmdTimout).Rows[0][0].ToString();

                    if (machinename != netBIOSnameResult && isClusteredResult == "1")
                    {
                        continue;
                    }

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

                    // execute each procedures that is returned by the control commands
                    foreach (DataTable dt in cds.Tables)
                    {
                        foreach (DataRow dr in dt.Rows)
                        {
                            //check cached items
                            if (isCached.Count > 0)
                            {
                                StringBuilder checknames = new StringBuilder();
                                checknames.AppendFormat("mssql_{0}_{1}", dr[0].ToString().Split('.')[1].Replace("[", "").Replace("]", ""), instance);
                                string value = isCached[checknames.ToString()];
                                string filename = value + "_" + checknames.ToString();


                                if (Directory.Exists(spoolpath) && (!String.IsNullOrEmpty(value)))
                                {

                                    DateTime ModifyDate = File.GetLastWriteTime(spoolpath + filename);
                                    DateTime now = DateTime.Now;

                                    int diffInSeconds = (int)(now - ModifyDate).TotalSeconds;

                                    if (diffInSeconds > int.Parse(value) || !(File.Exists(spoolpath + filename)))
                                    {
                                        using (FileStream fs = File.Create(spoolpath + filename))
                                        {
                                            try
                                            {
                                                DataTable dtc = Query.Execute(cs, dr[0].ToString(), defaultCmdTimout);
                                                // if data table contains data from a check procedure, then format in check format.
                                                if (cds.Tables[mssqlControlCheck].Rows.Contains(dtc.TableName))
                                                {
                                                    Byte[] info = new UTF8Encoding(true).GetBytes(CheckMK.FormatCheck(dtc, instance) + Environment.NewLine);
                                                    fs.Write(info, 0, info.Length);
                                                }
                                                // else if data table contains data from a chart procedure, then format in chart format.
                                                else if (cds.Tables[mssqlControlChart].Rows.Contains(dtc.TableName))
                                                {
                                                    Byte[] info = new UTF8Encoding(true).GetBytes(CheckMK.FormatChart(dtc, instance) + Environment.NewLine);
                                                    fs.Write(info, 0, info.Length);
                                                }                                      
                                            }
                                            catch
                                            {
                                                continue;
                                            }
                                        }
                                    }

                                }
                                else
                                {
                                    //cleanup cache files task

                                    //if (File.Exists(spoolpath + filename))
                                    //{
                                    //    Console.WriteLine("some work todo");
                                    //}

                                    try
                                    {
                                        rds.Tables.Add(Query.Execute(cs, dr[0].ToString(), defaultCmdTimout));
                                    }
                                    catch
                                    {
                                        continue;
                                    }
                                }
                            }
                            else
                            {
                                //cleanup cache files task - if any files exist

                                //if (File.Exists(spoolpath + filename))
                                //{
                                //    Console.WriteLine("some work todo");
                                //}

                                try
                                {
                                    rds.Tables.Add(Query.Execute(cs, dr[0].ToString(), defaultCmdTimout));
                                }
                                catch
                                {
                                    continue;
                                }
                            }
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
            //Added improves performance, no requirement to maintain pools once application exits, GC overhead 1-2 seconds
            System.Data.SqlClient.SqlConnection.ClearAllPools();
            return 1;
        }
    }
}
