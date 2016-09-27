using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;

namespace client.dbaid.wmiload
{
    public class Sql
    {
        private static string Secure(string connectionString)
        {
            var csb = new SqlConnectionStringBuilder();
            csb.Encrypt = true;
            csb.TrustServerCertificate = true;

            return csb.ConnectionString;
        }

        public static string GetDataSource(string connectionString)
        {
            var csb = new SqlConnectionStringBuilder();
            return csb.DataSource;
        }

        public static DataTable Select(string connectionString, string query)
        {
            using (SqlConnection conn = new SqlConnection(Secure(connectionString)))
            {
                conn.Open();

                using (SqlCommand cmd = new SqlCommand(query, conn))
                {
                    cmd.CommandType = CommandType.Text;

                    using (SqlDataAdapter da = new SqlDataAdapter(cmd))
                    {
                        using (DataTable dt = new DataTable())
                        {
                            da.Fill(dt);
                            return dt;
                        }
                    }
                }
            }
        }

        public static DataTable Execute(string connectionString, string procedure, Dictionary<string, object> parameters)
        {
            using (SqlConnection conn = new SqlConnection(Secure(connectionString)))
            {
                conn.Open();

                using (SqlCommand cmd = new SqlCommand(procedure, conn))
                {
                    cmd.CommandType = CommandType.StoredProcedure;
                    cmd.CommandTimeout = 300;

                    if (parameters != null)
                    {
                        foreach (KeyValuePair<string, object> param in parameters)
                        {
                            cmd.Parameters.AddWithValue(param.Key, param.Value);
                        }
                    }

                    using (SqlDataAdapter da = new SqlDataAdapter(cmd))
                    {
                        using (DataTable dt = new DataTable())
                        {
                            da.Fill(dt);
                            dt.TableName = procedure;

                            return dt;
                        }
                    }
                }
            }
        }
    }
}
