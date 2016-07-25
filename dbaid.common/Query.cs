using System;
using System.Collections.Generic;
using System.Data;
using System.Data.SqlClient;

namespace dbaid.common
{
    public class Query
    {
        private static string SecureConnectionString(string connectionString)
        {
            SqlConnectionStringBuilder csb = new SqlConnectionStringBuilder(connectionString);

            csb.Encrypt = true;
            csb.TrustServerCertificate = true;

            return csb.ConnectionString;
        }

        public static bool TestAccess(string connectionString)
        {
            try
            {
                using (SqlConnection conn = new SqlConnection(SecureConnectionString(connectionString)))
                {
                    conn.Open();

                    return true;
                }
            }
            catch { return false;  }
        }

        public static DataTable Execute(string connectionString, string procedure)
        {
            return Execute(connectionString, procedure, null);
        }

        public static DataTable Execute(string connectionString, string procedure, Dictionary<string, object> parameters)
        {
            using (SqlConnection conn = new SqlConnection(SecureConnectionString(connectionString)))
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

        public static DataTable Select(string connectionString, string query)
        {
            using (SqlConnection conn = new SqlConnection(SecureConnectionString(connectionString)))
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
                            dt.TableName = "[adhoc]";

                            return dt;
                        }
                    }
                }
            }
        }
    }
}
