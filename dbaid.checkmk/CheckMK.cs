using System;
using System.Collections.Generic;
using System.Data;
using System.Text;

namespace local.dbaid.checkmk
{
    class CheckMK
    {
        public static string FormatCheck(DataTable dt, string instance)
        {
            StringBuilder message = new StringBuilder();
            StringBuilder returnLine = new StringBuilder();
            uint rowCount = 0;
            uint returnCode = 0;

            try
            {
                foreach (DataRow dr in dt.Rows)
                {
                    string col1 = dr[0].ToString();
                    string col2 = dr[1].ToString();
                    uint state = 0;

                    rowCount++;

                    message.AppendFormat("{0} - {1};\\n ", col2.ToUpper(), col1);

                    // Get and set status code.
                    switch (col2.ToUpper())
                    {
                        case "NA":
                            state = 0;
                            rowCount--;
                            break;

                        case "OK":
                            state = 0;
                            break;

                        case "WARNING":
                            state = 1;
                            break;

                        case "CRITICAL":
                            state = 2;
                            break;

                        default:
                            state = 3;
                            break;
                    }

                    if (state > returnCode)
                    {
                        returnCode = state;
                    }
                }

                returnLine.AppendFormat("{0} mssql_{1}_{2} count={3} {4}", returnCode, dt.TableName.Split('.')[1].Replace("[", "").Replace("]", ""), instance, rowCount, message);
            }
            catch (Exception ex)
            {
                returnLine.AppendFormat("{0} mssql_{1}_{2} count={3} {4}", 3, dt.TableName.Split('.')[1].Replace("[", "").Replace("]", ""), instance, 0, ex.Message);
            }

            return returnLine.ToString();
        }

        public static string FormatChart(DataTable dt, string instance)
        {
            StringBuilder message = new StringBuilder();
            StringBuilder returnLine = new StringBuilder();
            StringBuilder comment = new StringBuilder();
            uint code = 0;
            uint row = 0;

            try
            {
                foreach (DataRow dr in dt.Rows)
                {
                    decimal val = dr.IsNull(0) ? -1 : (decimal)dr[0];

                    bool warnExist = dr.IsNull(1) ? false : true;
                    decimal warn = dr.IsNull(1) ? 0 : (decimal)dr[1];

                    bool critExist = dr.IsNull(2) ? false : true;
                    decimal crit = dr.IsNull(2) ? 0 : (decimal)dr[2];

                    string pnp = dr.IsNull(3) ? String.Empty : dr[3].ToString();

                    if (String.IsNullOrEmpty(pnp) || val == -1)
                    {
                        continue;
                    }

                    if (critExist && warnExist)
                    {
                        if (crit >= warn)
                        {
                            if (val >= crit)
                            {
                                comment.AppendFormat("CRITICAL - {0}; ", pnp.Split('=')[0].Replace("'", ""));
                                code = 2;
                            }
                            else if (val >= warn && code < 2)
                            {
                                comment.AppendFormat("WARNING - {0}; ", pnp.Split('=')[0].Replace("'", ""));
                                code = 1;
                            }
                        }
                        else if (crit < warn)
                        {
                            if (val <= crit)
                            {
                                comment.AppendFormat("CRITICAL - {0}; ", pnp.Split('=')[0].Replace("'", ""));
                                code = 2;
                            }
                            else if (val <= warn && code < 2)
                            {
                                comment.AppendFormat("WARNING - {0}; ", pnp.Split('=')[0].Replace("'", ""));
                                code = 1;
                            }
                        }
                    }

                    if (row == 0)
                    {
                        message.AppendFormat("{0}", pnp);
                    }
                    else
                    {
                        message.AppendFormat("|{0}", pnp);
                    }

                    row++;
                }

                if (String.IsNullOrEmpty(comment.ToString()))
                {
                    comment.Append("OK");
                }

                returnLine.AppendFormat("{0} mssql_{1}_{2} {3} {4}", code, dt.TableName.Split('.')[1].Replace("[", "").Replace("]", ""), instance, message, comment);
            }
            catch (Exception ex)
            {
                returnLine.AppendFormat("{0} mssql_{1}_{2} - {3}", 3, dt.TableName.Split('.')[1].Replace("[", "").Replace("]", ""), instance, ex.Message);
            }

            return returnLine.ToString();
        }
    }
}
