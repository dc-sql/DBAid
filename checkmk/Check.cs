using System;
using System.Collections.Generic;
using System.Text;
using System.Data;
using System.Data.SqlClient;

namespace dbaid.checkmk
{
    class Check
    {
        public Check(string sqlInstanceName)
        {
            SqlInstanceName = sqlInstanceName;
        }
        public string SqlInstanceName
        {
            get { return _SqlInstanceName; }
            set
            {
                if (String.IsNullOrEmpty(value))
                {
                    this._SqlInstanceName = "MSSQLSERVER";
                }
                else
                {
                    this._SqlInstanceName = value;
                }
            }
        }
        private string _SqlInstanceName;
        private string _ServiceName { get; set; }
        private StateCode _State { get; set; }
        private int _Count { get; set; }
        private string _Message { get; set; }
        public enum StateCode
        {
            NA = 0,
            OK = 0,
            WARNING = 1,
            CRITICAL = 2,
            UNKNOWN = 3
        }
        private StateCode StateToCode(string stateDesc)
        {
            switch (stateDesc.ToUpper())
            {
                case "NA":
                    return StateCode.NA;
                case "OK":
                    return StateCode.OK;
                case "WARNING":
                    return StateCode.WARNING;
                case "CRITICAL":
                    return StateCode.CRITICAL;
                case "UNKNOWN":
                    return StateCode.UNKNOWN;
                default:
                    return StateCode.UNKNOWN;
            }
        }
        public string Database()
        {
            StringBuilder msg = new StringBuilder();
            StateCode sc = StateCode.OK;
            this._ServiceName = String.Format("{0}_{1}_{2}", "mssql", "database", _SqlInstanceName);

            SqlConnectionStringBuilder csb = new SqlConnectionStringBuilder()
            {
                ApplicationName = "mssql-checkmk-local",
                DataSource = _SqlInstanceName == "MSSQLSERVER" ? Environment.MachineName : Environment.MachineName + "\\" + _SqlInstanceName,
                InitialCatalog = "_dbaid",
                IntegratedSecurity = true,
                Encrypt = true,
                TrustServerCertificate = true,
                ConnectTimeout = 5
            };

            using (var conn = new SqlConnection(csb.ConnectionString))
            using (var check = new SqlCommand(SqlFiles.check_database, conn) { CommandType = CommandType.Text })
            using (var results = new DataTable())
            {
                try
                {
                    conn.Open();
                    results.Load(check.ExecuteReader());

                    foreach (DataRow row in results.Rows)
                    {
                        msg.AppendFormat("{0} - {1};\\n ", row[0].ToString(), row[1].ToString());

                        if (StateToCode(row[0].ToString()) > sc)
                        {
                            sc = StateToCode(row[0].ToString());
                        }
                    }

                    this._State = sc;
                    this._Count = results.Rows.Count;
                    this._Message = msg.ToString();
                }
                catch (SqlException e)
                {
                    this._State = StateCode.UNKNOWN;
                    this._Count = 0;
                    this._Message = e.Message;
                }
            }

            return FormatStringCheck();
        }

        public string FormatStringCheck()
        {
            return String.Format("{0} {1} count={2} {3}", this._State, this._ServiceName, this._Count, this._Message);
        }
    }
}
