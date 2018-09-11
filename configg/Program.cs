using System;
using System.Data.SqlClient;

namespace Configg
{
    class Program
    {
        static void Help()
        {
            Console.WriteLine("Parameter:");
            Console.WriteLine("connectionstring");
            Console.WriteLine("e.g. ");
            Console.WriteLine("configg.exe \"Server=.;Database=_dbaid;Trusted_Connection=True;\"");
        }
        static int Main(string[] args)
        {
            if (args.Length == 0) {
                Help();
                return 1;
            }

            var csb = new SqlConnectionStringBuilder(args[0]) {
                TrustServerCertificate = true,
                Encrypt = true
            };

            using (SqlConnection conn = new SqlConnection(csb.ConnectionString))
            using (SqlCommand cmd = new SqlCommand())
            {
                SqlConfig config = new SqlConfig();
                string select = @"SELECT [query] FROM [configg].[wmi_query]";
                string create = @"IF (SELECT OBJECT_ID(N'" + config.Results.TableName + "')) IS NULL "
                    + @"CREATE TABLE " + config.Results.TableName
                    + @"([class] VARCHAR(256),[property] VARCHAR(256),[value] SQL_VARIANT)";
                string delete = @"DELETE FROM " + config.Results.TableName + ";";

                try
                {
                    conn.Open();
                    cmd.Connection = conn;
                    cmd.CommandText = create;
                    cmd.ExecuteNonQuery();

                    cmd.CommandText = select;
                    SqlDataReader dr = cmd.ExecuteReader();

                    while (dr.Read())
                    {
                        config.Load((string)dr["query"], conn.DataSource);
                    }

                    dr.Close();

                    cmd.CommandText = delete;
                    cmd.ExecuteNonQuery();

                    using (SqlBulkCopy bulk = new SqlBulkCopy(conn))
                    {
                        bulk.DestinationTableName = config.Results.TableName;
                        bulk.WriteToServer(config.Results);
                    }
                }
                catch (Exception ex)
                {
                    Console.WriteLine(ex.Message);
                }
                finally
                {
                    if (conn != null)
                    {
                        conn.Close();
                    }
                }
            }

            return 0;
        }
    }
}
