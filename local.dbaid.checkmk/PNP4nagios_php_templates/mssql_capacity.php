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

$red        = '#FF0000';
$magenta    = '#FF00FF';
$navy       = '#B7C0E5';
$green      = '#008000';
$yellow     = '#FFFF00';
$orangered  = '#FF4500';
$darkred    = '#8B0000';
$blue       = '#0C64E8';
$darkblue   = '#000099';
$darkorange = '#FF8C00';


$line[1]     = $navy;
$line[2]     = $blue;

$counter = 1;
$maxcounter = 0;
# Main logic

foreach ($DS as $i)
        {
        $maxcounter += 1;
        }

for ($loopcounter = 1; $loopcounter <= $maxcounter; $loopcounter++)
    {
    $datafile = $NAME[$loopcounter];
    $ds_name[$counter] = $datafile;
    $warnmb = $WARN[$loopcounter];
    $critmb = $CRIT[$loopcounter];
    settype($warnmb, "float");
    settype($critmb, "float");
    $warnmbtxt = sprintf("%.2f", $warnmb);
    $critmbtxt = sprintf("%.2f", $critmb);  
    $maxmb = $MAX[$loopcounter];
    $sizemb = sprintf("%.2f", $MAX[$loopcounter]);
    $opt[$counter] = " --vertical-label MB -l 0 -u $maxmb --title '$hostname: $datafile'  ";
    
    $def[$counter] = "DEF:user=$RRDFILE[$loopcounter]:$DS[$loopcounter]:MAX " ;
    $def[$counter] .= "CDEF:var1=user ";

    $loopcounter++;
    $def[$counter] .= "DEF:resv=$RRDFILE[$loopcounter]:$DS[$loopcounter]:MAX " ;
    $def[$counter] .= "CDEF:var2=resv ";
    $def[$counter] .= "AREA:var1$line[1]:\"used     \" ";
    $def[$counter] .= "LINE1:var1$line[1]: " ;
    
    $def[$counter] .= "GPRINT:var1:LAST:\"%10.2lf MB \\n\" " ;
 
    $def[$counter] .= "LINE1:var2$line[2]:\"reserved \" " ;
    
    $def[$counter] .= "GPRINT:var2:LAST:\"%10.2lf MB \\n\" " ;
    $def[$counter] .= "HRULE:$maxmb#003300:\"Max          $sizemb MB \" ";

    $def[$counter] .= "HRULE:$warnmb#ffff00:\"Warning at $warnmbtxt MB \" ";
    $def[$counter] .= "HRULE:$critmb#ff0000:\"Critical at $critmbtxt MB \\n\" ";
    
    $counter++;
    }

?>
