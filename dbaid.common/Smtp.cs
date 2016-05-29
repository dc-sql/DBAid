using System;
using System.Collections.Generic;
using System.Text;
using System.Net.Mail;
using System.IO;
using System.Net;
using System.Net.Security;
using System.Security.Cryptography.X509Certificates;

namespace dbaid.common
{
    public class Smtp
    {
        public static void send(string smtp, string from, string[] recipients, string subject, string body, string[] attachments, long attachmentByteLimit, int attachmentCountLimit, bool enableSsl, bool ignoreSslError, bool emailAnonymous)
        {
            ServicePointManager.ServerCertificateValidationCallback = delegate(object s, X509Certificate certificate, X509Chain chain, SslPolicyErrors sslPolicyErrors)
            {
                if (sslPolicyErrors == SslPolicyErrors.None || ignoreSslError)
                {
                    return true;
                }
                else
                {
                    Console.WriteLine("Certificate error: {0}", sslPolicyErrors);
                    Console.WriteLine(certificate.ToString());
                    return false;
                }
            };

            //IPHostEntry host = Dns.GetHostEntry(smtp);
            SmtpClient client = new SmtpClient(smtp);

            client.EnableSsl = enableSsl;
            client.DeliveryMethod = SmtpDeliveryMethod.Network;

            if (emailAnonymous)
            {
                client.UseDefaultCredentials = false;
            }
            else
            {
                client.UseDefaultCredentials = true;
            }

            List<FileInfo> sendAttachments = new List<FileInfo>();
            List<FileInfo> holdAttachments = new List<FileInfo>();

            foreach (string path in attachments)
            {
                sendAttachments.Add(new FileInfo(path));
            }

            do
            {
                long size = 0;
                holdAttachments.Clear();

                using (MailMessage email = new MailMessage())
                {
                    email.From = new MailAddress(from);
                    email.Subject = subject;
                    email.Body = body;

                    foreach (string to in recipients)
                    {
                        email.To.Add(new MailAddress(to));
                    }

                    foreach (FileInfo fi in sendAttachments)
                    {
                        size = size + fi.Length;

                        if (size <= attachmentByteLimit && email.Attachments.Count < attachmentCountLimit)
                        {
                            email.Attachments.Add(new Attachment(fi.FullName));
                        }
                        else
                        {
                            holdAttachments.Add(fi);
                        }
                    }

                    client.Send(email);
                }

                sendAttachments = new List<FileInfo>(holdAttachments);

            } while (holdAttachments.Count > 0);

            holdAttachments.Clear();
            sendAttachments.Clear();
        }
    }
}
