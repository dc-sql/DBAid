using System;
using Microsoft.SqlServer.Server;
using System.Collections;
using System.Data.SqlTypes;
using System.Security.Cryptography;

public class dbaid
{
    private class rsakey
    {
        private SqlString _private_key;
        private SqlString _public_key;

        public rsakey()
        {
            using (RSACryptoServiceProvider rsa = new RSACryptoServiceProvider())
            {
                this._private_key = rsa.ToXmlString(true);
                this._public_key = rsa.ToXmlString(false);
            }
        }

        public SqlString privatekey()
        {
            return this._private_key;
        }

        public SqlString publickey()
        {
            return this._public_key;
        }
    }

    [SqlFunction(
        DataAccess = DataAccessKind.Read,
        FillRowMethodName = "FillRow",
        TableDefinition = "private_key NVARCHAR(4000), public_key NVARCHAR(4000)")]
    public static IEnumerable generate_rsa_key()
    {
        ArrayList resultCollection = new ArrayList();

        resultCollection.Add(new rsakey());

        return resultCollection;
    }

    public static void FillRow(Object obj, out SqlString private_key, out SqlString public_key)
    {
        rsakey rsa = (rsakey)obj;
        private_key = rsa.privatekey();
        public_key = rsa.publickey();
    }
}
