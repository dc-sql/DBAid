using System;
using System.IO;

namespace dbaid.common
{
    public enum LogEntryType
    {
        ERROR,
        WARNING,
        INFO
    }

    public class Log
    {
        public static void licenseHeader()
        {
            string[] license = new string[]
            {
                @"  ____________________________________________________ ",
                @" |    _____       _______       _____ ____  __  __    |",
                @" |   |  __ \   /\|__   __|/\   / ____/ __ \|  \/  |   |",
                @" |   | |  | | /  \  | |  /  \ | |   | |  | | \  / |   |",
                @" |   | |  | |/ /\ \ | | / /\ \| |   | |  | | |\/| |   |",
                @" |   | |__| / ____ \| |/ ____ \ |___| |__| | |  | |   |",
                @" |   |_____/_/    \_\_/_/    \_\_____\____/|_|  |_|   |",             
                @" |                                                    |",
                @" | GNU General Public License version 3 (GPLv3)       |",
                @" | https://github.com/dc-sql/DBAid                    |",
                @" |____________________________________________________|",
            };

            foreach (string line in license)
            {
                Console.WriteLine(line);
            }

            Console.WriteLine();
        }

        public static void helpArgConnectionString()
        {
            Console.WriteLine("Connection-string argument example:");
            Console.WriteLine("program.exe \"Server=localhost;Database=_dbaid;Trusted_Connection=True;\"");
            Console.WriteLine();
        }

        public static void message(LogEntryType type, string source, string message, string logFile)
        {
            DateTime dt = DateTime.Now;

            switch (type)
            {
                case LogEntryType.ERROR:
                    Console.ForegroundColor = ConsoleColor.Red;
                    break;
                case LogEntryType.WARNING:
                    Console.ForegroundColor = ConsoleColor.Magenta;
                    break;
                default:
                    Console.ForegroundColor = ConsoleColor.White;
                    break;
            }

            Console.WriteLine("{0}\t{1}\t{2}\t{3}", dt, type, source, message);

            try
            {
                using (FileStream fs = new FileStream(logFile, FileMode.Append, FileAccess.Write, FileShare.Write))
                using (StreamWriter sw = new StreamWriter(fs))
                {
                    sw.WriteLine("{0}\t{1}\t{2}\t{3}", dt, type, source, message);
                }
            }
            catch (Exception ex)
            {
                Console.ForegroundColor = ConsoleColor.Red;
                Console.WriteLine(ex.Message);
                Console.ForegroundColor = ConsoleColor.White;
            }
        }
    }
}
