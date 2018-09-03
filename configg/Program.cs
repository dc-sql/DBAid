using System;
using System.Configuration;
using System.Data.SqlClient;

namespace Configg
{
    class Program
    {
        static void Main(string[] args)
        {
            var appSettings = ConfigurationManager.AppSettings;
            var connectionStrings = ConfigurationManager.ConnectionStrings;
            SqlConfig config = new SqlConfig();

            foreach (ConnectionStringSettings setting in connectionStrings) {
                var csb = new SqlConnectionStringBuilder(setting.ConnectionString) {
                    TrustServerCertificate = true,
                    Encrypt = true
                };

                foreach (string key in appSettings.AllKeys) {
                    config.Load(appSettings[key], csb.DataSource);
                }

                using (SqlConnection connect = new SqlConnection(csb.ConnectionString))
                using (SqlCommand command = new SqlCommand())
                {
                    string create = "IF (SELECT OBJECT_ID(N'" + config.Results.TableName + "')) IS NULL "
                        + "CREATE TABLE " + config.Results.TableName + "([class] VARCHAR(256),[property] VARCHAR(256),[value] SQL_VARIANT)";
                    string delete = @"DELETE FROM " + config.Results.TableName + ";";

                    connect.Open();

                    try
                    {
                        command.Connection = connect;
                        command.CommandText = create;
                        command.ExecuteNonQuery();
                        command.CommandText = delete;
                        command.ExecuteNonQuery();

                        using (SqlBulkCopy bulk = new SqlBulkCopy(connect))
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
                        connect.Close();
                    }
                }
            }
        }
    }
}
