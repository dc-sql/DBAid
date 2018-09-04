using System;
using System.Collections.Generic;
using System.Data.SqlTypes;
using System.Data;
using System.Management;

namespace Configg
{
    class SqlConfig
    {
        private DataTable _results = new DataTable();

        public DataTable Results
        {
            get { return this._results; }
        }

        private void init()
        {
            _results.TableName = "dbo.service";
            _results.Columns.Add(new DataColumn("class", typeof(SqlString)));
            _results.Columns.Add(new DataColumn("property", typeof(SqlString)));
            _results.Columns.Add(new DataColumn("value", typeof(object)));
        }

        public SqlConfig()
        {
            Clear();
            init();
        }

        public void Clear()
        {
            _results.Clear();
        }

        private static bool TestQuery(string host, string root, string query)
        {
            try
            {
                using (var tester = new ManagementObjectSearcher(root, query))
                {
                    //need to loop to stimulate failure
                    foreach (ManagementObject obj in tester.Get()) { }
                }

                return true;
            }
            catch
            {
                return false;
            }
        }

        private static List<string> GetNamespace(string host)
        {
            string root = @"\\" + host + @"\root\Microsoft\SqlServer";
            List<string> nsList = new List<string>();

            using (var nsClass = new ManagementClass(new ManagementScope(root), new ManagementPath("__namespace"), null))
            {
                foreach (ManagementObject ns in nsClass.GetInstances())
                {
                    string namespaceName = ns["Name"].ToString();

                    if (namespaceName.Contains("ComputerManagement"))
                        nsList.Add(namespaceName);
                }
            }

            nsList.Sort(delegate(string p1, string p2) { return p1.CompareTo(p2); });
            return nsList;
        }

        public void Load(string query, string sqlServer)
        {
            string host = sqlServer.Split('\\')[0] == "." ? Environment.MachineName : sqlServer.Split('\\')[0];
            string instance = sqlServer.Split('\\').Length > 1 ? sqlServer.Split('\\')[1] : "MSSQLSERVER";
            query = query.Replace("@@HOSTNAME", host);
            query = query.Replace("@@SERVICENAME", instance);

            this._results.BeginLoadData();

            foreach (string ns in GetNamespace(host))
            {
                string root = String.Empty;

                if (query.Contains("Win32_"))
                    root = @"\\" + host + @"\root\cimv2";
                else
                    root = @"\\" + host + @"\root\Microsoft\SqlServer\" + ns;

                if (TestQuery(host, root, query))
                {
                    using (var mos = new ManagementObjectSearcher(root, query))
                    {
                        int count = 1;
                        string classObj = String.Empty;

                        foreach (var obj in mos.Get())
                        {
                            classObj = string.Concat(host, "/", instance, "/", obj.ClassPath.ClassName.ToString(), "/", count.ToString());
                            bool loaded = false;

                            foreach (PropertyData prop in obj.Properties)
                            {
                                if (prop.Value != null && !prop.Type.Equals(CimType.Object))
                                {
                                    object[] newRow = new object[3];

                                    newRow[0] = classObj;
                                    newRow[1] = prop.Name.ToString();

                                    if (prop.Value.GetType().Equals(typeof(string[])))
                                        newRow[2] = String.Join(", ", (string[])prop.Value);
                                    else
                                        newRow[2] = prop.Value.ToString();

                                    this._results.LoadDataRow(newRow, true);
                                    loaded = true;
                                }
                            }

                            if (loaded)
                            {
                                count++;
                            }
                        }
                    }
                }
            }

            this._results.EndLoadData();
        }
    }
}
