using System;
using System.Collections.Generic;
using System.Text;

namespace dbaid.common
{
    public class Arguments
    {
        private Dictionary<string, string> _args = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
        private List<string> _flags = new List<string>();

        public Arguments(string[] args)
        {
            if (args.Length % 2 == 0) //Test for positive number of arguments
            {
                for (int i = 0; i < args.Length; i = i + 2)
                {
                    this._args.Add(args[i], args[i + 1]);
                }
            }
            else
                throw new ArgumentOutOfRangeException("args", "Odd number of arguments.");
        }

        public bool ContainsFlag(string flag)
        {
            return this._args.ContainsKey(flag);
        }

        public string GetValue(string flag)
        {
            return this._args[flag];
        }
    }
}
