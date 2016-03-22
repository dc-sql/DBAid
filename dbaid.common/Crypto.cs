using System;
using System.Security.Cryptography;
using System.IO;
using System.IO.Compression;

namespace dbaid.common
{
    public class Crypto
    {
        //  Call this function to remove the key from memory after use for security
        [System.Runtime.InteropServices.DllImport("KERNEL32.DLL", EntryPoint = "RtlZeroMemory")]
        public static extern bool ZeroMemory(IntPtr Destination, int Length);

        private static void CopyStream(Stream input, Stream output)
        {
            byte[] buffer = new byte[4096];
            int read;

            while ((read = input.Read(buffer, 0, buffer.Length)) > 0)
            {
                output.Write(buffer, 0, read);
            }
        }

        public static void encrypt(String publicKey, MemoryStream dataStream, string filepath)
        {
            if (dataStream.Length == 0 || String.IsNullOrEmpty(publicKey) || !Directory.Exists(Path.GetDirectoryName(filepath)))
            {
                throw new ArgumentException("Bad parameters supplied to encrypt method");
            }

            //Create a new instance of the RijndaelManaged class and RSACryptoServiceProvider class.
            using (RijndaelManaged symmetricKey = new RijndaelManaged())
            using (RSACryptoServiceProvider rsa = new RSACryptoServiceProvider())
            {
                // Initialise RijndaelManaged class.
                symmetricKey.KeySize = 256;
                symmetricKey.BlockSize = 256;
                symmetricKey.Mode = CipherMode.CBC;
                symmetricKey.Padding = PaddingMode.ISO10126;
                symmetricKey.GenerateKey();
                symmetricKey.GenerateIV();

                // Initialise RSACryptoServiceProvider with public key.
                rsa.FromXmlString(publicKey);

                // encrypt Rijndael secret key.
                byte[] EncryptedKey = rsa.Encrypt(symmetricKey.Key, false);
                byte[] EncryptedIv = rsa.Encrypt(symmetricKey.IV, false);
                byte[] lenKey = new byte[4];
                byte[] lenIv = new byte[4];
                int lkey = EncryptedKey.Length;
                int liv = EncryptedIv.Length;
                lenKey = BitConverter.GetBytes(lkey);
                lenIv = BitConverter.GetBytes(liv);

                // Create Memmory buffer stream, Crypto Stream, and GZip Stream.
                //using (MemoryStream msOutBuff = new MemoryStream())
                using (FileStream fsOut = new FileStream(filepath, FileMode.Create, FileAccess.Write))
                using (CryptoStream csEncrypt = new CryptoStream(fsOut, symmetricKey.CreateEncryptor(), CryptoStreamMode.Write))
                using (DeflateStream dsCompress = new DeflateStream(csEncrypt, CompressionMode.Compress))
                {
                    // Write Encrypted Rijndael secret key into output stream.
                    fsOut.Write(lenKey, 0, 4);
                    fsOut.Write(lenIv, 0, 4);
                    fsOut.Write(EncryptedKey, 0, lkey);
                    fsOut.Write(EncryptedIv, 0, liv);

                    // Write input stream into compression > Encryption > output stream.
                    dataStream.Position = 0;
                    dataStream.WriteTo(dsCompress);
                }
            }
        }

        public static void decrypt(String privateKey, MemoryStream dataStream, string filepath)
        {
            if (dataStream.Length == 0 || String.IsNullOrEmpty(privateKey) || !Directory.Exists(Path.GetDirectoryName(filepath)))
            {
                throw new ArgumentException("Bad parameters supplied to decrypt method");
            }

            using (RijndaelManaged symmetricKey = new RijndaelManaged())
            using (RSACryptoServiceProvider rsa = new RSACryptoServiceProvider())
            {
                symmetricKey.KeySize = 256;
                symmetricKey.BlockSize = 256;
                symmetricKey.Mode = CipherMode.CBC;
                symmetricKey.Padding = PaddingMode.ISO10126;
                rsa.FromXmlString(privateKey);

                byte[] lenKey = new byte[4];
                byte[] lenIv = new byte[4];

                dataStream.Position = 0;

                dataStream.Seek(0, SeekOrigin.Begin);
                dataStream.Seek(0, SeekOrigin.Begin);

                dataStream.Read(lenKey, 0, 3);
                dataStream.Seek(4, SeekOrigin.Begin);
                dataStream.Read(lenIv, 0, 3);

                int lkey = BitConverter.ToInt32(lenKey, 0);
                int liv = BitConverter.ToInt32(lenIv, 0);
                int startc = 8 + lkey + liv;

                byte[] keyEncrypted = new byte[lkey];
                byte[] ivEncrypted = new byte[liv];

                dataStream.Seek(8, SeekOrigin.Begin);
                dataStream.Read(keyEncrypted, 0, lkey);
                dataStream.Seek(8 + lkey, SeekOrigin.Begin);
                dataStream.Read(ivEncrypted, 0, liv);

                symmetricKey.Key = rsa.Decrypt(keyEncrypted, false);
                symmetricKey.IV = rsa.Decrypt(ivEncrypted, false);

                using (FileStream fsOut = new FileStream(filepath, FileMode.Create, FileAccess.ReadWrite))
                using (CryptoStream csDecrypt = new CryptoStream(dataStream, symmetricKey.CreateDecryptor(), CryptoStreamMode.Read))
                using (DeflateStream dsDecompress = new DeflateStream(csDecrypt, CompressionMode.Decompress))
                {
                    dataStream.Position = startc;
                    CopyStream(dsDecompress, fsOut);
                }
            }
        }
    }
}
