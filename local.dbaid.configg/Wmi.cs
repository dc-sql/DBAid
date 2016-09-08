using System;
using System.Collections;
using System.Collections.Generic;
using System.Data.SqlTypes;
using System.Data;
using System.Management;

namespace dbaid.configg
{
    class Wmi
    {
        public class PropertyValue
        {
            public SqlString Path;
            public SqlString Property;
            public Object Value;

            public PropertyValue(SqlString path, SqlString property, Object value)
            {
                Path = path;
                Property = property;
                Value = value;
            }
        }

        private static bool testSqlWmiClass(string host, string root, string wmiClass)
        {
            try
            {
                using (ManagementObjectSearcher tester = new ManagementObjectSearcher(root, wmiClass))
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

        private static List<string> GetSqlWmiNameSpaces(string host)
        {
            string root = @"\\" + host + @"\root\Microsoft\SqlServer";
            List<string> nsList = new List<string>();

            try
            {
                ManagementClass nsClass = new ManagementClass(new ManagementScope(root), new ManagementPath("__namespace"), null);

                foreach (ManagementObject ns in nsClass.GetInstances())
                {
                    string namespaceName = ns["Name"].ToString();

                    if (namespaceName.Contains("ComputerManagement"))
                        nsList.Add(namespaceName);
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine(ex.Message + " - " + ex.StackTrace);
            }

            nsList.Sort(delegate(string p1, string p2) { return p1.CompareTo(p2); });
            return nsList;
        }

        public static DataTable getWmiData(string dataSource, string query)
        {
            var dt = new DataTable();
            var dc1 = new DataColumn("class_object", typeof(SqlString));
            var dc2 = new DataColumn("property", typeof(SqlString));
            var dc3 = new DataColumn("value", typeof(object));
            dt.Columns.Add(dc1);
            dt.Columns.Add(dc2);
            dt.Columns.Add(dc3);

            string host = dataSource.Split('\\')[0];
            string instance = dataSource.Split('\\').Length > 1 ? dataSource.Split('\\')[1] : "MSSQLSERVER";

            try
            {
                foreach (string ns in GetSqlWmiNameSpaces(host))
                {
                    string root = String.Empty;

                    if (query.Contains("Win32"))
                        root = @"\\" + host + @"\root\cimv2";
                    else
                        root = @"\\" + host + @"\root\Microsoft\SqlServer\" + ns;

                    if (testSqlWmiClass(host, root, query))
                    {
                        using (var mos = new ManagementObjectSearcher(root, query))
                        {
                            int count = 0;
                            string classObj = String.Empty;

                            foreach (var obj in mos.Get())
                            {
                                count++;
                                classObj = string.Concat(host, "/", instance, "/", obj.ClassPath.ClassName.ToString(), "/", count.ToString());

                                foreach (PropertyData prop in obj.Properties)
                                {
                                    if (prop.Value != null && !prop.Type.Equals(CimType.Object) && !prop.Type.Equals(CimType.Reference))
                                    {
                                        object[] newRow = new object[3];
                                        DataRow row;

                                        newRow[0] = classObj;
                                        newRow[1] = prop.Name.ToString();

                                        if (prop.Value.GetType().Equals(typeof(string[])))
                                            newRow[2] = String.Join(", ", (string[])prop.Value);
                                        else
                                            newRow[2] = prop.Value.ToString();

                                        dt.BeginLoadData();
                                        row = dt.LoadDataRow(newRow, true);
                                    }
                                }
                            }
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine(ex.Message + " - " + ex.StackTrace);
            }

            return dt;
        }
    }
}
