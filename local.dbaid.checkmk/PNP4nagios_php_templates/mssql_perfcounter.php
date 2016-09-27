<?php
# +------------------------------------------------------------------+
# |             ____ _               _        __  __ _  __           |
# |            / ___| |__   ___  ___| | __   |  \/  | |/ /           |
# |           | |   | '_ \ / _ \/ __| |/ /   | |\/| | ' /            |
# |           | |___| | | |  __/ (__|   <    | |  | | . \            |
# |            \____|_| |_|\___|\___|_|\_\___|_|  |_|_|\_\           |
# |                                                                  |
# | Copyright Mathias Kettner 2013             mk@mathias-kettner.de |
# +------------------------------------------------------------------+
#
# This file is part of Check_MK.
# The official homepage is at http://mathias-kettner.de/check_mk.
#
# check_mk is free software;  you can redistribute it and/or modify it
# under the  terms of the  GNU General Public License  as published by
# the Free Software Foundation in version 2.  check_mk is  distributed
# in the hope that it will be useful, but WITHOUT ANY WARRANTY;  with-
# out even the implied warranty of  MERCHANTABILITY  or  FITNESS FOR A
# PARTICULAR PURPOSE. See the  GNU General Public License for more de-
# ails.  You should have  received  a copy of the  GNU  General Public
# License along with GNU Make; see the file  COPYING.  If  not,  write
# to the Free Software Foundation, Inc., 51 Franklin St,  Fifth Floor,
# Boston, MA 02110-1301 USA.

setlocale(LC_ALL, "POSIX");

# RRDtool Options
#$servicedes=$NAGIOS_SERVICEDESC

$magenta    = '#FF00FF';

$line[1]    = $magenta;

$counter = 1;
$maxcounter = 0;
# Main logic

foreach ($DS as $i)
        {
        $maxcounter += 1;
        }

# Main logic
for ($loopcounter = 1; $loopcounter <= $maxcounter; $loopcounter++)
    {
      $warnval = $WARN[$loopcounter];
      $critval = $CRIT[$loopcounter];
      $currentval = $ACT[$loopcounter];
      
      settype($warnval, "float");
      settype($critval, "float");
      settype($currentval, "float");
      
      $warntxt = sprintf("%.2f", $warnval);
      $crittxt = sprintf("%.2f", $critval); 
   
      if($critval > $currentval)
      {
	      $opt[$loopcounter] = "--vertical-label 'SQL' -l 0 -u $critval  --title '$NAME[$loopcounter]' ";
	      $def[$loopcounter] = "DEF:counter=$RRDFILE[$loopcounter]:$DS[$loopcounter]:MAX "; 
	      $def[$loopcounter] .= "LINE1:counter$line[1]:\"ctr \" "; 
	      $def[$loopcounter] .= "GPRINT:counter:LAST:\"Last\: %8.2lf ctr \" ";
        $def[$loopcounter] .= "GPRINT:counter:AVERAGE:\"Avg\: %8.2lf ctr \" ";
	      $def[$loopcounter] .= "GPRINT:counter:MAX:\"Max\: %8.2lf ctr \" ";
        $def[$loopcounter] .= "HRULE:$warnval#ffff00:\"Warning at $warntxt \" ";
        $def[$loopcounter] .= "HRULE:$critval#ff0000:\"Critical at $crittxt \" ";

      }
      else
      {
	      $opt[$loopcounter] = "--vertical-label 'SQL' -l 0  --title '$NAME[$loopcounter]' ";
	      $def[$loopcounter] = "DEF:counter=$RRDFILE[$loopcounter]:$DS[$loopcounter]:MAX "; 
	      $def[$loopcounter] .= "LINE1:counter$line[1]:\"ctr \" "; 
	      $def[$loopcounter] .= "GPRINT:counter:LAST:\"Last\: %8.2lf ctr \" ";
        $def[$loopcounter] .= "GPRINT:counter:AVERAGE:\"Avg\: %8.2lf ctr \" ";
	      $def[$loopcounter] .= "GPRINT:counter:MAX:\"Max\: %8.2lf ctr \" ";
        $def[$loopcounter] .= "HRULE:$warnval#ffff00:\"Warning at $warntxt \" ";
        $def[$loopcounter] .= "HRULE:$critval#ff0000:\"Critical at $crittxt \" ";
      }
      
    }
 
?>

