using System;
using System.Collections;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;
using System.Data.SqlTypes;
using System.Management;
using System.Text.RegularExpressions;
using System.Configuration;
using System.Diagnostics;

namespace local.dbaid.asbuilt
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

        private static bool testSqlWmiClass(string host, string path, string wmiClass)
        {
            string root = @"\\" + host + @"\root\Microsoft\SqlServer\" + path;

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

        public static IEnumerable getServiceInfo(string host, string instance)
        {
            var PropertyValueCollection = new ArrayList();
           // string service = String.Empty;
            string path = String.Empty;

            if (String.IsNullOrEmpty(instance))
                instance = "MSSQLSERVER";

            try
            {
                foreach (string ns in GetSqlWmiNameSpaces(host))
                {
                    string root = @"\\" + host + @"\root\Microsoft\SqlServer\" + ns;

                    if (testSqlWmiClass(host, ns, "SELECT * FROM SqlService"))
                    {
                        using (ManagementObjectSearcher SqlService = new ManagementObjectSearcher(root, "SELECT DisplayName,BinaryPath,Description,HostName,ServiceName,StartMode,StartName FROM SqlService WHERE DisplayName LIKE '%(" + instance + ")' OR ServiceName = 'SQLBrowser'"))
                        {
                            foreach (ManagementObject obj in SqlService.Get())
                            {
                                path = string.Concat(host, "/", obj.ClassPath.ClassName.ToString(), "/", obj["ServiceName"].ToString());

                                foreach (PropertyData prop in obj.Properties)
                                {
                                    if (prop.Name != "ServiceName" && prop.Name != "HostName")
                                    {
                                        if (prop.Value != null)
                                        {
                                            PropertyValueCollection.Add(new PropertyValue(path, prop.Name.ToString(), prop.Value.ToString()));
                                        }
                                    }
                                }
                            }
                        }
                    }

                    if (testSqlWmiClass(host, ns, "SELECT * FROM ServerNetworkProtocol"))
                    {
                        using (ManagementObjectSearcher ServerNetworkProtocol = new ManagementObjectSearcher(root, "SELECT InstanceName,ProtocolDisplayName,Enabled FROM ServerNetworkProtocol WHERE InstanceName LIKE '" + instance + "'"))
                        {
                            foreach (ManagementObject obj in ServerNetworkProtocol.Get())
                            {
                                if (String.IsNullOrEmpty(instance))
                                    path = string.Concat(host, "/", obj.ClassPath.ClassName.ToString(), "/", obj["InstanceName"].ToString());
                                else
                                    path = string.Concat(host, "/", obj.ClassPath.ClassName.ToString(), "/", "MSSQL$", obj["InstanceName"].ToString());

                                foreach (PropertyData prop in obj.Properties)
                                {
                                    if (prop.Name != "InstanceName" && prop.Name != "ProtocolDisplayName")
                                    {
                                        if (prop.Value != null)
                                        {
                                            PropertyValueCollection.Add(new PropertyValue(path, obj.GetPropertyValue("ProtocolDisplayName").ToString(), prop.Value.ToString()));
                                        }
                                    }
                                }
                            }
                        }
                    }

                    if (testSqlWmiClass(host, ns, "SELECT * FROM ServerNetworkProtocolProperty"))
                    {
                        using (ManagementObjectSearcher ServerNetworkProtocolProperty = new ManagementObjectSearcher(root, "SELECT InstanceName,PropertyName,PropertyStrVal FROM ServerNetworkProtocolProperty WHERE IPAddressName = 'IPAll' AND InstanceName LIKE '" + instance + "'"))
                        {
                            foreach (ManagementObject obj in ServerNetworkProtocolProperty.Get())
                            {
                                if (String.IsNullOrEmpty(instance))
                                    path = string.Concat(host, "/", obj.ClassPath.ClassName.ToString(), "/", obj["InstanceName"].ToString());
                                else
                                    path = string.Concat(host, "/", obj.ClassPath.ClassName.ToString(), "/", "MSSQL$", obj["InstanceName"].ToString());

                                foreach (PropertyData prop in obj.Properties)
                                {
                                    if (prop.Name != "InstanceName" && prop.Name != "PropertyName")
                                    {
                                        if (prop.Value != null)
                                        {
                                            PropertyValueCollection.Add(new PropertyValue(path, obj.GetPropertyValue("PropertyName").ToString(), prop.Value.ToString()));
                                        }
                                    }
                                }
                            }
                        }
                    }

                    if (testSqlWmiClass(host, ns, "SELECT * FROM SqlServiceAdvancedProperty"))
                    {
                        using (ManagementObjectSearcher SqlServiceAdvancedProperty = new ManagementObjectSearcher(root, "SELECT ServiceName,PropertyName,PropertyNumValue,PropertyStrValue FROM SqlServiceAdvancedProperty WHERE ServiceName LIKE '%" + instance + "'"))
                        {
                            foreach (ManagementObject obj in SqlServiceAdvancedProperty.Get())
                            {
                                path = string.Concat(host, "/", obj.ClassPath.ClassName.ToString(), "/", obj["ServiceName"].ToString());

                                foreach (PropertyData prop in obj.Properties)
                                {
                                    if (prop.Name != "ServiceName" && prop.Name != "PropertyName")
                                    {
                                        if (prop.Value != null)
                                        {
                                            PropertyValueCollection.Add(new PropertyValue(path, obj.GetPropertyValue("PropertyName").ToString(), prop.Value.ToString()));
                                        }
                                    }
                                }
                            }
                        }
                    }

                    if (testSqlWmiClass(host, ns, "SELECT * FROM ServerSettingsGeneralFlag"))
                    {
                        using (ManagementObjectSearcher ServerSettingsGeneralFlag = new ManagementObjectSearcher(root, "SELECT InstanceName,FlagName,FlagValue FROM ServerSettingsGeneralFlag WHERE InstanceName LIKE '" + instance + "'"))
                        {
                            foreach (ManagementObject obj in ServerSettingsGeneralFlag.Get())
                            {
                                if (String.IsNullOrEmpty(instance))
                                    path = string.Concat(host, "/", obj.ClassPath.ClassName.ToString(), "/", obj["InstanceName"].ToString());
                                else
                                    path = string.Concat(host, "/", obj.ClassPath.ClassName.ToString(), "/", "MSSQL$", obj["InstanceName"].ToString());

                                foreach (PropertyData prop in obj.Properties)
                                {
                                    if (prop.Name != "InstanceName" && prop.Name != "FlagName")
                                    {
                                        if (prop.Value != null)
                                        {
                                            PropertyValueCollection.Add(new PropertyValue(path, obj.GetPropertyValue("FlagName").ToString(), prop.Value.ToString()));
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

        public static IEnumerable getHostInfo(string host)
        {
            ArrayList PropertyValueCollection = new ArrayList();
            string query = String.Empty;
            string root = @"\\" + host + @"\root\cimv2";

            try
            {
                if (System.Environment.OSVersion.Version.Major > 5)
                {
                    query = "SELECT Caption, CSDVersion, CodeSet, CountryCode, Locale, OSArchitecture FROM Win32_OperatingSystem";
                }
                else
                {
                    query = "SELECT Caption, CSDVersion, CodeSet, CountryCode, Locale FROM Win32_OperatingSystem";
                }

                using (ManagementObjectSearcher Win32OperatingSystem = new ManagementObjectSearcher(root, query))
                {
                    foreach (ManagementObject obj in Win32OperatingSystem.Get())
                    {
                        foreach (PropertyData prop in obj.Properties)
                        {
                            if (prop.Value != null)
                            {
                                PropertyValueCollection.Add(new PropertyValue(host + "/" + obj.ClassPath.ClassName.ToString(), prop.Name.ToString(), prop.Value.ToString()));
                            }
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine(ex.Message + " - " + ex.StackTrace);
            }

            try
            {
                using (ManagementObjectSearcher Win32TimeZone = new ManagementObjectSearcher(root, "SELECT Caption FROM Win32_TimeZone"))
                {
                    foreach (ManagementObject obj in Win32TimeZone.Get())
                    {
                        foreach (PropertyData prop in obj.Properties)
                        {
                            if (prop.Value != null)
                            {
                                PropertyValueCollection.Add(new PropertyValue(host + "/" + obj.ClassPath.ClassName.ToString(), prop.Name.ToString(), prop.Value.ToString()));
                            }
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine(ex.Message + " - " + ex.StackTrace);
            }

            try
            {
                if (System.Environment.OSVersion.Version.Major > 5)
                {
                    query = "SELECT Caption, Name, Architecture, AddressWidth, MaxClockSpeed, NumberOfCores, NumberOfLogicalProcessors, PowerManagementCapabilities FROM win32_processor";
                }
                else
                {
                    query = "SELECT Caption, Name, Architecture, AddressWidth, MaxClockSpeed FROM win32_processor";
                }

                using (ManagementObjectSearcher win32processor = new ManagementObjectSearcher(root, query))
                {
                    foreach (ManagementObject obj in win32processor.Get())
                    {
                        foreach (PropertyData prop in obj.Properties)
                        {
                            if (prop.Value != null)
                            {
                                PropertyValueCollection.Add(new PropertyValue(host + "/" + obj.ClassPath.ClassName.ToString(), prop.Name.ToString(), prop.Value.ToString()));
                            }
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine(ex.Message + " - " + ex.StackTrace);
            }

            try
            {
                using (ManagementObjectSearcher Win32computerSystem = new ManagementObjectSearcher(root, "SELECT Domain, Manufacturer, Model, PrimaryOwnerName, TotalPhysicalMemory FROM Win32_computerSystem"))
                {
                    foreach (ManagementObject obj in Win32computerSystem.Get())
                    {
                        foreach (PropertyData prop in obj.Properties)
                        {
                            if (prop.Value != null)
                            {
                                PropertyValueCollection.Add(new PropertyValue(host + "/" + obj.ClassPath.ClassName.ToString(), prop.Name.ToString(), prop.Value.ToString()));
                            }
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine(ex.Message + " - " + ex.StackTrace);
            }

            try
            {
                using (ManagementObjectSearcher win32bios = new ManagementObjectSearcher(root, "SELECT SMBIOSBIOSVersion FROM win32_bios"))
                {
                    foreach (ManagementObject obj in win32bios.Get())
                    {
                        foreach (PropertyData prop in obj.Properties)
                        {
                            if (prop.Value != null)
                            {
                                PropertyValueCollection.Add(new PropertyValue(host + "/" + obj.ClassPath.ClassName.ToString(), prop.Name.ToString(), prop.Value.ToString()));
                            }
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                Console.WriteLine(ex.Message + " - " + ex.StackTrace);
            }

            try
            {
                using (ManagementObjectSearcher Win32NetworkAdapterConfiguration = new ManagementObjectSearcher(root, "SELECT ServiceName, Caption, DHCPEnabled, DNSDomain, IPAddress, MACAddress FROM Win32_NetworkAdapterConfiguration WHERE IPEnabled = 'TRUE'"))
                {
                    foreach (ManagementObject obj in Win32NetworkAdapterConfiguration.Get())
                    {
                        string path = string.Concat(host, "/", obj.ClassPath.ClassName.ToString(), "/", obj.Properties["ServiceName"].Value.ToString());

                        foreach (PropertyData prop in obj.Properties)
                        {
                            if (prop.Name != "ServiceName")
                            {
                                if (prop.Value != null)
                                {
                                    if (prop.Name.ToString() == "IPAddress")
                                    {
                                        PropertyValueCollection.Add(new PropertyValue(path, prop.Name.ToString(), String.Join(", ", (string[])prop.Value)));
                                    }
                                    else
                                    {
                                        PropertyValueCollection.Add(new PropertyValue(path, prop.Name.ToString(), prop.Value.ToString()));
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

            try
            {
                string user_query = string.Format("select PartComponent from win32_groupuser where GroupComponent=\"Win32_Group.Domain='{0}',Name='administrators'\"", host);
                using (ManagementObjectSearcher Win32UserGroup = new ManagementObjectSearcher(root, user_query))
                {
                    foreach (ManagementObject obj in Win32UserGroup.Get())
                    {
                        foreach (PropertyData prop in obj.Properties)
                        {
                            if (prop.Value != null)
                            {
                                string[] local_admins = prop.Value.ToString().Split(',');
                                PropertyValueCollection.Add(new PropertyValue(host + "/" + obj.ClassPath.ClassName.ToString() + "/Local_Admins", local_admins[1].ToString(), local_admins[0].ToString()));
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

        public static IEnumerable getDriveInfo(string host)
        {
            ArrayList PropertyValueCollection = new ArrayList();
            string query = String.Empty;
            string root = @"\\" + host + @"\root\cimv2";

            try
            {
                if (System.Environment.OSVersion.Version.Major > 5)
                {
                    query = "SELECT DriveLetter, Label, DeviceID, DriveType, FileSystem, Capacity, BlockSize, Compressed, IndexingEnabled, PageFilePresent, BootVolume FROM Win32_Volume WHERE SystemVolume <> 'TRUE' AND DriveType <> 4 AND DriveType <> 5";
                }
                else
                {
                    query = "SELECT DriveLetter, Label, DeviceID, DriveType, FileSystem, Capacity, BlockSize, Compressed, IndexingEnabled FROM Win32_Volume WHERE DriveType <> 4 AND DriveType <> 5";
                }

                using (ManagementObjectSearcher win32Volumn = new ManagementObjectSearcher(root, query))
                {
                    foreach (ManagementObject obj in win32Volumn.Get())
                    {
                        string path = string.Concat(host, "/", obj.ClassPath.ClassName.ToString(), "/", obj.Properties["DriveLetter"].Value);

                        foreach (PropertyData prop in obj.Properties)
                        {
                            if (prop.Name != "DriveLetter")
                            {
                                if (prop.Value != null)
                                {
                                    PropertyValueCollection.Add(new PropertyValue(path, prop.Name.ToString(), prop.Value.ToString()));
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
