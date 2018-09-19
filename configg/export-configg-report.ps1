Param(
    [parameter(Mandatory=$true)]
    [string]$SQLServer = '.'
)

$database = '_dbaid'
$getProcedureSql = "SELECT 'EXEC [configg].' + QUOTENAME([name]) AS [procedure] FROM sys.objects WHERE[type] = 'P' AND SCHEMA_NAME([schema_id]) = 'configg'"

CD $PSScriptRoot

#region: Example Stored Procedure code
<# This PowerShell script expects two datatables. The first must select heading, subheading, and comment. You can pass blank strings if you like " '' as [comment] ". The second is the datatable you want converted to a markdown table

CREATE PROCEDURE [configg].[get_instance_databases]
AS
BEGIN
	SET NOCOUNT ON;

	SELECT 'Instance' AS [heading], 'Databases' AS [subheading], 'This is a list of databases on the instance' AS [comment]
    
    SELECT * FROM sys.databases
END
GO
#>
#endregion

#region: Functions
function convertto-htmlList {
[cmdletbinding()]
    Param(            
        [parameter(Mandatory=$true)]
        [xml]$xml
    )
    $line = '<ul>'

    foreach($element in $xml.table.row) {
        $parts = @()

        $line = $line + '<li>'

        foreach ($attribute in $element.Attributes) {
            $line = $line + $attribute.Name.Replace('_','\_') + '=' + $attribute.'#text'.Replace('_','\_') + '; '
        }

        $line = $line + '</li>'

        if ($element.codeblock) {
            $line = $line + '````' + $element.codeblock + '````'
        }
    }
    $line = $line + '</ul>'

    $line.Replace("`n",' ').Replace("`r",' ')
}

function convertto-markdownTable {
[cmdletbinding()]
    Param(            
        [parameter(Mandatory=$true)]
        [system.Data.DataTable]$inputObject
    )

    $md = [System.Text.StringBuilder]::new()

    $columns = $inputObject.Columns.ColumnName

    # Output Headers
    foreach($col in $columns) {
        $md.Append("| $col ") | Out-Null
    }

    $md.AppendLine("|") | Out-Null

    foreach($col in $columns) {
        $md.Append("|:---") | Out-Null
    }

    $md.AppendLine("|") | Out-Null

    foreach ($row in $inputObject.Rows) {
        foreach ($col in $columns) {
            if ($row[$col] -ilike '<table>*<row*</table>*') { 
                $line = '| ' + (convertto-htmlList $row[$col]) + ' '
            }
            else {
                $line = '| ' + $row[$col] + ' '
            }

            $md.Append($line) | Out-Null
        }

        $md.AppendLine("|") | Out-Null
    }

    $md.ToString()
}
#endregion 

$procedures = Invoke-Sqlcmd -ServerInstance "$SQLServer" -Database "$database" -Query "$getProcedureSql"
$collection = @()

foreach($proc in $procedures) {
    [array]$result = @() 
    $test = @('heading', 'subheading', 'comment')

    $result = Invoke-Sqlcmd -ServerInstance . -Database '_dbaid' -Query $proc.procedure -OutputAs DataTables
    
    if ($result) {
        if ($result.Length -eq 2) {
            if (-not (Compare-Object -ReferenceObject $result[0].Columns.ColumnName -DifferenceObject $test)) {

                if ($result[1]) {
                    $row = New-Object PSObject -property @{heading = $result[0].heading;subheading = $result[0].subheading;comment = $result[0].comment;datatable = $result[1]}

                    $collection += $row
                }
            }
        }
    }
}

$toc = [System.Text.StringBuilder]::new()
$md = [System.Text.StringBuilder]::new()
$group = $collection | Sort-Object -Property heading, subheading | Group-Object -Property heading

foreach ($section in $group) { 
    $heading = $section.Group.heading | Sort-Object -Unique
    $toc.AppendLine("[$heading](#$($heading.Replace(' ','-').ToLower()))  ") | Out-Null
    $md.AppendLine("## $heading  ") | Out-Null

    $subGroups = $section.Group | Select subheading, comment, datatable | Sort-Object -Property subheading | Group-Object -Property subheading

    foreach ($subSection in $subGroups) {
        $subHeading = $subSection.Group.subheading | Sort-Object -Unique
        
        $toc.AppendLine("&nbsp;&nbsp;&nbsp;&nbsp;[$subHeading](#$($subHeading.Replace(' ','-').ToLower()))  ") | Out-Null
        $md.AppendLine("### $subHeading  ") | Out-Null

        $dataTables = $subSection.Group | Select comment, datatable

        foreach ($table in $dataTables) {
            $comment = $table.comment
            $datatable = $table.datatable

            if ($comment.Length -gt 0) {
                $md.AppendLine("$comment  ") | Out-Null
            }
            
            $md.AppendLine("") | Out-Null #Blank line needed to render table

            $ret = convertto-markdownTable $datatable
            $md.Append($ret) | Out-Null
        }
    }
}
$title = '# [' + (Invoke-Sqlcmd -ServerInstance $SQLServer -Query 'EXEC [_dbaid].[system].[get_instance_tag]')[0] + ']'

$title
''
$toc.ToString()
''
$md.ToString()
# SIG # Begin signature block
# MIIFnQYJKoZIhvcNAQcCoIIFjjCCBYoCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUP4pqpTHME1WMsnAvypw+Xhsj
# FNugggMzMIIDLzCCAhegAwIBAgIQIi8ovuNN07NB5ThYZrUt5TANBgkqhkiG9w0B
# AQsFADAfMR0wGwYDVQQDDBR3YXluZXRAZGF0YWNvbS5jby5uejAeFw0xODA5MTMw
# MzUxMjBaFw0xOTA5MTMwNDExMjBaMB8xHTAbBgNVBAMMFHdheW5ldEBkYXRhY29t
# LmNvLm56MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAtHhtPAtrSCHY
# I10PEzEnVju5VjIMFzjJrjimhQwMGpjkVHWK+kMg18+wM8oY+hr6fOIyzAD/kZWY
# qOlmlb1PiKG/cqKk0B7dcAeDiGlKdzhmFP5tqzbzYNLmIlGlPlknjop3SW75LBZN
# RydiTbCZeRqwLCdw4xocyUbeA6ptzbPhhDuamVKl0+WW83LAAdnabQ/Om4mz4N7F
# sOlzxOG0kANpUX4hPiZjgc4AanrDM7IFtOD+mzn9/UaJ1tWsdVd9zDLTiDkYG1Ub
# b8ZSyln1IXQIV25caUHwYL/awcXTRo8dmwHPy9j4L9sPV/VOMe/Ght4s9+LfZwCJ
# X5NIzZzcXQIDAQABo2cwZTAOBgNVHQ8BAf8EBAMCB4AwEwYDVR0lBAwwCgYIKwYB
# BQUHAwMwHwYDVR0RBBgwFoIUd2F5bmV0QGRhdGFjb20uY28ubnowHQYDVR0OBBYE
# FAlE3KmQeXvUv76jngfKtEWTg5FhMA0GCSqGSIb3DQEBCwUAA4IBAQAKmh1sIPxG
# +kzgsJl7wfTuoS4C2bM31T/H04e1yscI34BwSRi2IqAlD0e/F6/xEamh0EcXXiri
# Ge8uvSuHdU3OeilF2EuB8yhffDjQWQMojfesqmdRKHsLJ3jdbn2don+WhVT2YZww
# ccsQ3HxOay1j4SfpDFMADhWELx2kHgrVYr9mIMfzn4GaQreM5cDhcnNoQfrfeEKp
# jCS7Mtgx6JWUlnrOnCeepoihqurrn45CtgA9D2ilTw8CzaKIU1guLS1oxHbkRF1B
# qUaMwdweDGm1UdCYwP9OtU216PUwbQeHx05KKrTs7PuZixuoVz61nQBlj8WgZl+S
# u5hRrpRssGCXMYIB1DCCAdACAQEwMzAfMR0wGwYDVQQDDBR3YXluZXRAZGF0YWNv
# bS5jby5uegIQIi8ovuNN07NB5ThYZrUt5TAJBgUrDgMCGgUAoHgwGAYKKwYBBAGC
# NwIBDDEKMAigAoAAoQKAADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgor
# BgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAjBgkqhkiG9w0BCQQxFgQURQhrnxei
# rvs5ho9HZk1a9xKxgE0wDQYJKoZIhvcNAQEBBQAEggEADX2wRpX6ZlKNNnLeW3pT
# Amiimbr1P8uPVXcsJkAu4E/tUhq0nxHu5/ZQUzAsXZN70Yc3dD30I2Ir5zMmMQL6
# dO82SuStYiCpiGLtGj21tskaMgvbzRsMTCpxEwJc9Qn935qSZVEgnF8fCrlSv1cQ
# U2nhdwalgN3zH5WyuuJMmkzDr2qV/miQAUqoO6dFQ1aPU5Sp7Knzt8M+1/6aYo8R
# yRmTMJ/6gr9h7mMRLsqjDjRT/RZABNJGuPRoQcbxJnA0LfXHnrPW2GC67UeDEByS
# tMWymRdYyGBK/VcFLLaoYi3NEDB7HvQxqvHJtIm1SZp/5m3rkoCwggYgS9WOWpj3
# 1g==
# SIG # End signature block
