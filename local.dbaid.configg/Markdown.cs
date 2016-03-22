using System;
using System.IO;
using System.Data;
using System.Configuration;
using System.Xml;
using System.Text;
using dbaid.common;

namespace local.dbaid.asbuilt
{


    class Markdown
    {

        public static String getMarkdown(string connectionString, string query)
        {
            StringBuilder md = new StringBuilder();

            foreach (DataRow dr in Query.Execute(connectionString, query).Rows)
            {
                md.Append("- [" + dr[0].ToString()+"](#" +dr[0].ToString().Replace("].[","").Replace("[","").Replace("]","")+")" + Environment.NewLine);
            }

            foreach (DataRow dr in Query.Execute(connectionString, query).Rows)
            {
                md.Append(Environment.NewLine + "## " + dr[0].ToString() + Environment.NewLine);
                md.Append(formatMarkdown(Query.Execute(connectionString, dr[0].ToString())));
            }

            return md.ToString();
        }

        private static StringBuilder formatMarkdown(DataTable dt)
        {
            StringBuilder mdata = new StringBuilder();

            bool hasxml = false;
            int[] colmax = new int[dt.Columns.Count];
            int[] rowmax = new int[dt.Columns.Count];

            foreach (DataRow datarow in dt.Rows)
            {
                int colcount = 1;
                int counth = 0;
                int countr = 0;

                //get max data lengths
                foreach (DataColumn columnM in dt.Columns)
                {
                    if (columnM.ColumnName.Length > counth)
                    {
                        counth = columnM.ColumnName.Length;
                    }

                    try
                    {
                        XmlDocument xml = new XmlDocument();
                        xml.LoadXml(datarow[columnM].ToString());
                        if (xml.InnerXml.Length > 0)
                        {
                            hasxml = true;
                        }
                        continue;
                    }
                    catch
                    { }

                    if (datarow[columnM].ToString().Length > countr)
                    {
                        countr = datarow[columnM].ToString().Length;
                    }
                }

                if (dt.Columns.Count > 3 || hasxml == true)
                {
                    StringBuilder code = new StringBuilder();

                    foreach (DataColumn column in dt.Columns)
                    {                       
                        if (colcount == 1)
                        {
                            mdata.Append(Environment.NewLine);
                            mdata.Append("|" + column.ToString().PadRight(counth).Insert(counth, "|") + datarow[column].ToString().PadRight(countr).Insert(countr, "|") + Environment.NewLine);
                            mdata.Append("|" + "".PadRight(counth, '-').Insert(counth, "|") + "".PadRight(countr, '-').Insert(countr, "|") + Environment.NewLine);
                        }
                        else
                        {
                            try
                            {
                                string codeblock;
                                codeblock = "";

                                XmlDocument xml = new XmlDocument();
                                xml.LoadXml(datarow[column].ToString());
                                codeblock = Markdown.formatXML(xml, 2);
                                if (!(String.IsNullOrEmpty(codeblock)))
                                {
                                    code.Append(Environment.NewLine + "##### " + column.ColumnName + Environment.NewLine);
                                    code.Append(Environment.NewLine + "```" + Environment.NewLine + codeblock + Environment.NewLine + "```" + Environment.NewLine);

                                    if (colcount == dt.Columns.Count)
                                    {
                                        mdata.Append(code);
                                    }
                                    colcount++;
                                    continue;
                                }
                            }
                            catch
                            { }
                        }
                        if (colcount == dt.Columns.Count && hasxml == true)
                        {
                            mdata.Append("|" + column.ToString().PadRight(counth).Insert(counth, "|") + datarow[column].ToString().PadRight(countr).Insert(countr, "|") + Environment.NewLine);
                            mdata.Append(code);
                            code.Length = 0;
                        }
                        else if (dt.Columns.Count > 3 | hasxml == true && colcount > 1)
                        {
                            mdata.Append("|" + column.ToString().PadRight(counth).Insert(counth, "|") + datarow[column].ToString().PadRight(countr).Insert(countr, "|") + Environment.NewLine);
                        }
                        colcount++;
                    }
                }

                if (dt.Columns.Count < 4 && hasxml == false)
                {
                    mdata.Length = 0;
                    mdata.Append(Environment.NewLine);
                    int ir;
                    int ic;

                    //find lengths
                    for (ir = 0; ir < dt.Rows.Count; ir++)
                    {
                        for (ic = 0; ic < dt.Columns.Count; ic++)
                        {
                            if (ir == 0)
                            {
                                if (dt.Columns[ic].ToString().Length > colmax[ic])
                                {
                                    colmax[ic] = dt.Columns[ic].ToString().Length;
                                }

                            }
                            else
                            {
                                if (dt.Rows[ir][ic].ToString().Length > rowmax[ic])
                                {
                                    rowmax[ic] = dt.Rows[ir][ic].ToString().Length;
                                }
                            }
                        }
                    }

                    //Build header###############################
                    for (ic = 0; ic < dt.Columns.Count; ic++)
                    {
                        //build header with col size
                        if (colmax[ic] > rowmax[ic])
                        {
                            if (ic == 0)
                            {
                                mdata.Append("|" + dt.Columns[ic].ToString().PadRight(colmax[ic] + 1).Insert(colmax[ic] + 1, "|"));
                                if (ic == dt.Columns.Count - 1)
                                {
                                    mdata.Append(Environment.NewLine);
                                }
                            }

                            else
                            {
                                mdata.Append(dt.Columns[ic].ToString().PadRight(colmax[ic] + 1).Insert(colmax[ic] + 1, "|"));
                            }
                            if (ic == dt.Columns.Count - 1)
                            {
                                mdata.Append(Environment.NewLine);
                            }
                        }
                        //build header with row size
                        else if (colmax[ic] < rowmax[ic])
                        {
                            if (ic == 0)
                            {
                                mdata.Append("|" + dt.Columns[ic].ToString().PadRight(rowmax[ic] + 1).Insert(rowmax[ic] + 1, "|"));
                                if (ic == dt.Columns.Count - 1)
                                {
                                    mdata.Append(Environment.NewLine);
                                }
                            }
                            else
                            {
                                mdata.Append(dt.Columns[ic].ToString().PadRight(rowmax[ic] + 1).Insert(rowmax[ic] + 1, "|"));
                                if (ic == dt.Columns.Count - 1)
                                {
                                    mdata.Append(Environment.NewLine);
                                }
                            }
                        }
                    }

                    //Build header devide###############################
                    for (ic = 0; ic < dt.Columns.Count; ic++)
                    {
                        //build header with col size
                        if (colmax[ic] > rowmax[ic])
                        {
                            if (ic == 0)
                            {
                                mdata.Append("|" + "".PadRight(colmax[ic] + 1, '-').Insert(colmax[ic] + 1, "|"));
                            }

                            else
                            {
                                mdata.Append("".PadRight(colmax[ic] + 1, '-').Insert(colmax[ic] + 1, "|"));
                            }
                            if (ic == dt.Columns.Count - 1)
                            {
                                mdata.Append(Environment.NewLine);
                            }
                        }
                        //build header with row size
                        else if (colmax[ic] < rowmax[ic])
                        {
                            if (ic == 0)
                            {
                                mdata.Append("|" + "".PadRight(rowmax[ic] + 1, '-').Insert(rowmax[ic] + 1, "|"));
                                if (ic == dt.Columns.Count - 1)
                                {
                                    mdata.Append(Environment.NewLine);
                                }
                            }
                            else
                            {
                                mdata.Append("".PadRight(rowmax[ic] + 1, '-').Insert(rowmax[ic] + 1, "|"));
                                if (ic == dt.Columns.Count - 1)
                                {
                                    mdata.Append(Environment.NewLine);
                                }
                            }
                        }
                    }

                    //Build data###############################
                    for (ir = 0; ir < dt.Rows.Count; ir++)
                    {
                        for (ic = 0; ic < dt.Columns.Count; ic++)
                        {
                            //build row with col size
                            if (colmax[ic] > rowmax[ic])
                            {

                                if (ic == 0)
                                {
                                    mdata.Append("|" + dt.Rows[ir][ic].ToString().PadRight(colmax[ic] + 1).Insert(colmax[ic] + 1, "|"));
                                    if (ic == dt.Columns.Count - 1)
                                    {
                                        mdata.Append(Environment.NewLine);
                                    }
                                }
                                else
                                {
                                    mdata.Append(dt.Rows[ir][ic].ToString().PadRight(colmax[ic] + 1).Insert(colmax[ic] + 1, "|"));
                                    if (ic == dt.Columns.Count - 1)
                                    {
                                        mdata.Append(Environment.NewLine);
                                    }
                                }
                            }
                            //build row with row size
                            if (colmax[ic] < rowmax[ic])
                            {
                                if (ic == 0)
                                {
                                    mdata.Append("|" + dt.Rows[ir][ic].ToString().PadRight(rowmax[ic] + 1).Insert(rowmax[ic] + 1, "|"));
                                    if (ic == dt.Columns.Count - 1)
                                    {
                                        mdata.Append(Environment.NewLine);
                                    }
                                }
                                else
                                {
                                    mdata.Append(dt.Rows[ir][ic].ToString().PadRight(rowmax[ic] + 1).Insert(rowmax[ic] + 1, "|"));
                                    if (ic == dt.Columns.Count - 1)
                                    {
                                        mdata.Append(Environment.NewLine);
                                    }
                                }
                            }
                        }
                    }
                }
            } 

            return mdata;
        }

        private static string formatXML(XmlDocument xml, int indent) 
        { 
            StringWriter stringwriter = new StringWriter();
            XmlTextWriter xmlwriter = new XmlTextWriter(stringwriter);
            xmlwriter.Formatting = Formatting.Indented; 
            xmlwriter.Indentation = indent; 
            xml.WriteContentTo(xmlwriter);
            xmlwriter.Flush();
            stringwriter.Flush();
            return stringwriter.ToString();
        }
    }
}
