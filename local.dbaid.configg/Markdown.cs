using System;
using System.IO;
using System.Data;
using System.Xml;
using System.Text;
using dbaid.common;
using System.Data.SqlTypes;

namespace dbaid.configg
{
    class Markdown
    {

        public static String getMarkdown(string connectionString, string query)
        {
            StringBuilder md = new StringBuilder();

            /* Generate index */
            foreach (DataRow dr in Query.Select(connectionString, query).Rows)
            {
                md.Append("- [" + dr[0].ToString()+"](#" +dr[0].ToString().Replace("].[","").Replace("[","").Replace("]","")+")" + Environment.NewLine);
            }

            /* Generate dataset */
            foreach (DataRow dr in Query.Select(connectionString, query).Rows)
            {
                md.Append(Environment.NewLine + "## " + dr[0].ToString() + Environment.NewLine);
                md.Append(formatMarkdown(Query.Execute(connectionString, dr[0].ToString())));
            }

            return md.ToString();
        }

        private static bool isXml(string xml)
        {
            DataSet ds = new DataSet();

            if (!string.IsNullOrEmpty(xml) && xml.TrimStart().StartsWith("<") && xml.TrimEnd().EndsWith(">"))
            {
                try
                {
                    ds.ReadXml(new StringReader(xml), XmlReadMode.Auto);
                    return true;
                }
                catch
                {
                    return false;
                }
            }
            else
            { 
                return false;
            }
        }

        private static int[] tblColumnLengths(DataTable dt)
        {
            int[] colLens = new int[dt.Columns.Count];

            for (int col = 0; col < dt.Columns.Count; col++)
            {
                if (dt.Columns[col].ColumnName.Length > colLens[col])
                    colLens[col] = dt.Columns[col].ColumnName.Length;

                foreach (DataRow row in dt.Rows)
                {
                    if (row[col].ToString().Length > colLens[col])
                        colLens[col] = row[col].ToString().Length;
                }
            }

            return colLens;
        }


        private static StringBuilder formatMarkdown(DataTable dt)
        {
            StringBuilder mdata = new StringBuilder();
            int[] colLens = tblColumnLengths(dt);

            for (int row = 0; row < dt.Rows.Count; row++)
            {
                //get max data lengths
                for (int col = 0; col < dt.Columns.Count; col++)
                {
                    if (row == 0) /* if row is index 0 then write column headers */
                    {
                        if (isXml(dt.Rows[row][col].ToString())) /* if column is XML then parse XML into DataTable */
                        {
                            DataSet dsXml = new DataSet();
                            dsXml.ReadXml(new StringReader(dt.Rows[row][col].ToString()), XmlReadMode.Auto);

                            foreach (DataTable dtXml in dsXml.Tables)
                            {
                                int[] colLensXml = tblColumnLengths(dtXml);

                                for (int rowXml = 0; rowXml < dtXml.Rows.Count; rowXml++)
                                {
                                    for (int colXml = 0; colXml < dtXml.Columns.Count; colXml++)
                                    {
                                        if (rowXml == 0) /* if XML dt row is index 0 then write column headers */
                                        {
                                            mdata.Append(Environment.NewLine);
                                            mdata.Append("|" + dtXml.Columns[col].ColumnName.ToString().PadRight(colLens[col]) + "|");
                                            mdata.Append(Environment.NewLine);
                                            mdata.Append("|" + "".PadRight(colLens[col], '-').Insert(colLens[col], "|") + "".PadRight(colLens[col], '-').Insert(colLens[col], "|"));
                                            mdata.Append(Environment.NewLine);
                                        }
                                    }
                                }
                            }
                        }
                        else /* Write out normal DataTable header column */
                        {
                            mdata.Append(Environment.NewLine);
                            mdata.Append("|" + dt.Columns[col].ColumnName.ToString().PadRight(colLens[col]) + "|");
                            mdata.Append(Environment.NewLine);
                            mdata.Append("|" + "".PadRight(colLens[col], '-').Insert(colLens[col], "|") + "".PadRight(colLens[col], '-').Insert(colLens[col], "|"));
                            mdata.Append(Environment.NewLine);
                        }
                    }
                }
            } 

            return mdata;
        }
    }
}
