using System;
using System.Collections.Generic;
using System.IO;
using System.Text;

namespace dbaid.common
{
    public class MoveList
    {
        public string sourcefile { get; set; }
        public string destfile { get; set; }
    }

    public class FileIo
    {
        public static void move(string sourceFile, string destinationFile)
        {
            if (!Directory.Exists(Path.GetDirectoryName(destinationFile)))
            {
                Directory.CreateDirectory(Path.GetDirectoryName(destinationFile));
            }

            // Ensure that the target does not exist.
            if (File.Exists(destinationFile))
            {
                File.Delete(destinationFile);
            }

            // Move the file.
            File.Move(sourceFile, destinationFile);
        }

        public static List<MoveList> movelist(string sourcePath, string searchFilter, string destinationPath)
        {
            List<MoveList> files = new List<MoveList>();
            
            foreach (string sourceFile in Directory.GetFiles(sourcePath, searchFilter))
            {
                string destinationFile = Path.Combine(destinationPath, Path.GetFileName(sourceFile));

                files.Add(new MoveList
                {
                    sourcefile = Path.Combine(sourcePath, Path.GetFileName(sourceFile)),
                    destfile = Path.Combine(destinationPath, Path.GetFileName(sourceFile))
                });
            }
            return files;
        }

        public static string[] delete(string sourcePath, string searchFilter, DateTime olderThan)
        {
            List<string> files = new List<string>();

            foreach (string file in Directory.GetFiles(sourcePath, searchFilter))
            {
                if (new FileInfo(file).CreationTime < olderThan)
                {
                    File.Delete(file);

                    files.Add(file);
                }
            }

            return files.ToArray();
        }
    }
}
