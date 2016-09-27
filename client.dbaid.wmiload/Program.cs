using System;
using System.Collections.Generic;
using System.Data;

namespace client.dbaid.wmiload
{
    class Program
    {
        static int Main(string[] args)
        {
            const string uspSetWmiObj = "[wmiload].[usp_insert_wmi_object]";
            const string udfGetModCmd = "SELECT [cmd] FROM [system].[udf_get_module_cmd]('wmiload')";
            string connString = args[0];

            Console.WriteLine("{0}/t{1}", DateTime.Now.ToShortTimeString(), "wmiload start");

            using (var dtWmiQueries = Sql.Select(connString, udfGetModCmd))
            {
                var parameters = new Dictionary<string, object>();

                foreach (DataRow row in dtWmiQueries.Rows)
                {
                    string _query = row["cmd"].ToString();

                    parameters.Clear();
                    parameters.Add("udt_wmi_object", Wmi.getWmiData(Sql.GetDataSource(connString), _query));

                    try
                    {
                        Sql.Execute(connString, uspSetWmiObj, parameters);
                    }
                    catch (SystemException ex)
                    {
                        Console.WriteLine("{0}/t{1}", DateTime.Now.ToShortTimeString(), ex.Message);
#if (DEBUG)
                        Console.ReadKey();
#endif
                        return 1;
                    }
                }
            }

            Console.WriteLine("{0}/t{1}", DateTime.Now.ToShortTimeString(), "wmiload finish");
            return 0;
        }
    }
}
