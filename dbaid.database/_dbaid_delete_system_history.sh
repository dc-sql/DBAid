# These commands need to be run as root or using sudo

# Create required shell script to handle deleting job log files in Linux, as SQL Agent does not have equivalent to CmdExec or PowerShell.
echo -e '#!/bin/sh
find /var/opt/mssql/log/ -name *dbaid*.log -mtime +1 -delete' > /var/opt/mssql/_dbaid_delete_system_history.sh
chown mssql:mssql _dbaid_delete_system_history.sh
chmod 744 _dbaid_delete_system_history.sh

# Create scheduled task to run shell script at 6pm daily.
# First command redirects error output to /dev/null to suppress "no crontab for mssql" message
# NB - There may already be a crontab with the same task running at a different time, if someone changed it from default.
#      In which case, remove any extraneous entries manually.
(crontab -u mssql -l 2>/dev/null ; echo "0 18 * * * /var/opt/mssql/_dbaid_delete_system_history.sh") | awk '!x[$0]++' | crontab -u mssql -

# List crontab for mssql user to check
crontab -u mssql -l
