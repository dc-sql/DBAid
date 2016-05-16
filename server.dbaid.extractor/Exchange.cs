using System;
using System.Collections.Generic;
using System.IO;
using Microsoft.Exchange.WebServices.Data;
using dbaid.common;

namespace server.dbaid.extractor
{
    class Exchange
    {
        public static void DownloadAttachement(string mailaddress, string subject, string outfolder, string logFile, bool logVerbose)
        {
            ExchangeService exservice = new ExchangeService(ExchangeVersion.Exchange2010_SP2);
            exservice.UseDefaultCredentials = true;
            exservice.AutodiscoverUrl(mailaddress);
            FolderId folderid = new FolderId(WellKnownFolderName.Inbox, mailaddress);
            Folder inbox = Folder.Bind(exservice, folderid);
            SearchFilter.SearchFilterCollection sfcollection = new SearchFilter.SearchFilterCollection(LogicalOperator.And);
            SearchFilter.IsEqualTo sfir = new SearchFilter.IsEqualTo(EmailMessageSchema.IsRead, false);
            sfcollection.Add(sfir);
            SearchFilter.IsEqualTo sfha = new SearchFilter.IsEqualTo(EmailMessageSchema.HasAttachments, true);
            sfcollection.Add(sfha);
            //SearchFilter.ContainsSubstring sffrm = new SearchFilter.ContainsSubstring(EmailMessageSchema.From, from); No longer needed as multiple addresses will send emails.
            //sfcollection.Add(sffrm);
            SearchFilter.IsGreaterThanOrEqualTo sfdt = new SearchFilter.IsGreaterThanOrEqualTo(ItemSchema.DateTimeReceived, DateTime.Now.AddDays(-31));
            sfcollection.Add(sfdt);
            SearchFilter.ContainsSubstring sfsub = new SearchFilter.ContainsSubstring(ItemSchema.Subject, subject);
            sfcollection.Add(sfsub);

            //Initialise loop variables
            int pagesize = 100;
            int offset = 0;
            bool moreitems = true;

            //Load emails and download attachments
            while (moreitems)
            {
                ItemView view = new ItemView(pagesize, offset, OffsetBasePoint.Beginning);
                FindItemsResults<Item> finditems = inbox.FindItems(sfcollection, view);

                if (finditems.TotalCount > 0)
                {
                    Log.message(LogEntryType.INFO, "DBAidExtractor", "Found " + finditems.TotalCount.ToString() + " mail items.", logFile);
                }
                else
                {
                    Log.message(LogEntryType.INFO, "DBAidExtractor", "No more mail items found.", logFile);
                    break;
                }

                foreach (EmailMessage item in finditems.Items)
                {
                    try
                    {
                        item.Load();

                        foreach (FileAttachment attach in item.Attachments)
                        {

                            attach.Load();
                            FileStream file = null;

                            try
                            {
                                file = new System.IO.FileStream(Path.Combine(outfolder, attach.Name), FileMode.Create);
                                file.Write(attach.Content, 0, attach.Content.Length);
                            }
                            catch (Exception ex)
                            {
                                Log.message(LogEntryType.WARNING, "DBAidExtractor", ex.Message + (logVerbose ? " - " + ex.StackTrace : ""), logFile);
                                continue;
                            }
                            finally
                            {
                                file.Flush();
                                file.Close();
                            }

                            Log.message(LogEntryType.INFO, "DBAidExtractor", "Downloaded Attachment:" + outfolder + "\\" + attach.Name, logFile);
                        }

                        item.IsRead = true;
                        item.Update(ConflictResolutionMode.AlwaysOverwrite);
                    }
                    catch (Exception ex)
                    {
                        Log.message(LogEntryType.WARNING, "DBAidExtractor", ex.Message + (logVerbose ? " - " + ex.StackTrace : ""), logFile);
                        continue;
                    }
                }

                if (finditems.MoreAvailable == false)
                {
                    moreitems = false;
                }
            }
        }
    }
}
