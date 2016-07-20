using System;
using System.Collections;
using System.Collections.Generic;
using System.Data.SqlTypes;
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

        public static IEnumerable getWmiData(string host, string instance, string[] wmiQuery)
        {
            var PropertyValueCollection = new ArrayList();
           // string service = String.Empty;
            

            if (String.IsNullOrEmpty(instance))
                instance = "MSSQLSERVER";

            try
            {
                foreach (string ns in GetSqlWmiNameSpaces(host))
                {
                    foreach (string query in wmiQuery)
                    {
                        string root = String.Empty;

                        if (query.Contains("Win32"))
                            root = @"\\" + host + @"\root\cimv2";
                        else
                            root = @"\\" + host + @"\root\Microsoft\SqlServer\" + ns;

                        if (testSqlWmiClass(host, root, query))
                        {
                            using (var mos = new ManagementObjectSearcher(root, query.Replace("?", instance)))
                            {
                                int count = 0;
                                string classObj = String.Empty;

                                foreach (var obj in mos.Get())
                                {
                                    count++;
                                    classObj = string.Concat(host, "/", instance, "/", obj.ClassPath.ClassName.ToString(), "/", count.ToString());

                                    foreach (PropertyData prop in obj.Properties)
                                    {
                                        if (prop.Value != null)
                                        {
                                            if (prop.Value.GetType().Equals(typeof(string[])))
                                            {
                                                PropertyValueCollection.Add(new PropertyValue(classObj, prop.Name.ToString(), String.Join(", ", (string[])prop.Value)));
                                            }
                                            else
                                            {
                                                PropertyValueCollection.Add(new PropertyValue(classObj, prop.Name.ToString(), prop.Value.ToString()));
                                            }
                                        }
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

            return PropertyValueCollection;
        }
    }
}
