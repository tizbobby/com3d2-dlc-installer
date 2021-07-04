# Import-Module -Name ($PSScriptRoot + "\Get-CRC32.ps1")

function Get-CRC32 {
    <#
        .SYNOPSIS
            Calculate CRC.
        .DESCRIPTION
            This function calculates the CRC of the input data using the CRC32 algorithm.
        .EXAMPLE
            Get-CRC32 $data
        .EXAMPLE
            $data | Get-CRC32
        .NOTES
            C to PowerShell conversion based on code in https://www.w3.org/TR/PNG/#D-CRCAppendix
            Author: Øyvind Kallstad
            Date: 06.02.2017
            Version: 1.0
        .INPUTS
            byte[]
        .OUTPUTS
            uint32
        .LINK
            https://communary.net/
        .LINK
            https://www.w3.org/TR/PNG/#D-CRCAppendix
    #>
    [CmdletBinding()]
    param (
        # Array of Bytes to use for CRC calculation
        [Parameter(Position = 0, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [byte[]]$InputObject
    )

    Begin {

        function New-CrcTable {
            [uint32]$c = $null
            $crcTable = New-Object 'System.Uint32[]' 256

            for ($n = 0; $n -lt 256; $n++) {
                $c = [uint32]$n
                for ($k = 0; $k -lt 8; $k++) {
                    if ($c -band 1) {
                        $c = (0xEDB88320 -bxor ($c -shr 1))
                    }
                    else {
                        $c = ($c -shr 1)
                    }
                }
                $crcTable[$n] = $c
            }

            Write-Output $crcTable
        }

        function Update-Crc ([uint32]$crc, [byte[]]$buffer, [int]$length) {
            [uint32]$c = $crc

            if (-not($script:crcTable)) {
                $script:crcTable = New-CrcTable
            }

            for ($n = 0; $n -lt $length; $n++) {
                $c = ($script:crcTable[($c -bxor $buffer[$n]) -band 0xFF]) -bxor ($c -shr 8)
            }

            Write-output $c
        }

        $dataArray = @()
    }

    Process {
        foreach ($item  in $InputObject) {
            $dataArray += $item
        }
    }

    End {
        $inputLength = $dataArray.Length
        Write-Output ((Update-Crc –crc 0xffffffffL –buffer $dataArray –length $inputLength) -bxor 0xffffffffL)
    }
}

# read COM3D2 dir from registry
$targetCom3d2Dir = (Get-ItemProperty -Path "HKCU:\SOFTWARE\KISS\カスタムオーダーメイド3D2" -Name InstallPath).InstallPath.TrimEnd('\')

$exists = Test-Path -LiteralPath "$targetCom3d2Dir\update.lst"
if (-not $exists) {
    Write-Output "Not a valid COM3D2 path: $targetCom3d2Dir"
    exit
}

$targetFileVers = New-Object 'system.collections.generic.dictionary[string,string]'
$content = [IO.File]::ReadLines("$targetCom3d2Dir\update.lst")
$content | ForEach-Object {
    if (-not $_) {
        return
    }
    $r = $_.Split(",")
    $path = $r[0]
    $ver = $r[1]

    $targetFileVers[$path] = $ver
}

$canInstall = @()

Get-ChildItem -Directory -Recurse | ForEach-Object {
    $itemPath = $_.FullName
    $updateLstDir = $itemPath
    $updateLstPath = "$updateLstDir\update.lst"
  
    if (!(Test-Path -LiteralPath $updateLstPath)) {
        return
    }
    
    $dirName = $_.ToString()
    
    # New CREdit format installers, but not relevant for COM3D2, ignore silently
    if ($dirName -eq "cm3d2" -or $dirName -eq "cm3d2cbl" -or $dirName -eq "com3d2cbl" -or $dirName -eq "cre") {
        return
    }
    
    # New CREdit format installers, not implemented yet, ignore with warning
    if ($dirName -eq "com3d2") {
        Write-Warning "$(Resolve-Path -Relative -LiteralPath $itemPath) is in new CREdit format, please install manually"
        return
    }
    
    # CM3D2 installer bundled with COM3D2 DLC, ignore silently
    $regexResult = $dirName | Select-String -Pattern "^cm3d2plg_(oh_)?.*$"
    if ($regexResult) {
        return
    }
    
    # CREdit, COM3D2.5, or COM3D2 Chu-B-Lip installer, ignore silently
    $regexResult = $dirName | Select-String -Pattern "^(creplg|com3d2_5plg|com3d2plg_oh)_.*$"
    if ($regexResult) {
        return
    }
    
    # com3d2plg_dlc346 CM3D2/COM3D2 combo installer without proper name, ignore silently
    if ($dirName -eq "cm3d2plg") {
        return
    }
    
    # Actually check for valid install folder now!
    # com3d2plg_dlc346 has a special format - it has combo CM3D2/COM3D2 installers, and the COM3D2 folder is just called "com3d2plg", so we support that too
    $regexResult = $dirName | Select-String -Pattern "^(com3d2plg_(?!oh_).*|com3d2plg)$"
    if (-not $regexResult) {
        Write-Warning "$(Resolve-Path -Relative -LiteralPath $itemPath) is an installer, but not in the adequate format"
    }

    Write-Output $updateLstDir

    $content = [IO.File]::ReadLines($updateLstPath)
    $content | ForEach-Object {
        $split = $_.Split(",")
        $type = $split[0]
        $fromPath = $split[1]
        $toPath = $split[2]
        $size = $split[3]
        $crc32 = $split[4]
        $ver =  $split[5]

        if ($fromPath -eq 0) {
            $fromPath = "data\$toPath"
        }

        # version check
        $versionCheckPass = 0
        $oldver = "0"
        if ($targetFileVers[$toPath]) {
            $oldver = $targetFileVers[$toPath]
            if ($ver -gt $targetFileVers[$toPath]) {
                $versionCheckPass = 1
            } else {
                # Write-Warning ("[VERSION NOT_MATCH][{0}/{0}] $_ " -f $ver -f $targetFileVers[$toPath])
                $versionCheckPass = 0
            }
        } else {
            $oldver = "0"
            $versionCheckPass = 1
        }
        if ($versionCheckPass -eq 0) {
            return
        }

        # format path
        $_fromPath = "$updateLstDir\$fromPath"
        $_toPath = "$targetCom3d2Dir\$toPath"
        
        $fileSize = (Get-Item -LiteralPath $_fromPath).length
        # size check
        $sizeCheckPass = 0
        if ($size -ne $fileSize) {
            Write-Warning ("[SIZE NOT_MATCH][{0}] $_ " -f $fileSize)
        } else {
            $sizeCheckPass = 1
        }
        if ($sizeCheckPass -eq 0) {
            return
        }

        # crc32 check
        # $file = [IO.File]::ReadAllBytes($_fromPath)
        # $crc32CheckPass = 0
        # $hash = Get-CRC32 $file
        # 
        # # convert int64 to hex with a minimum length of 8
        # $hash = "{0:X8}" -f $hash
        # if ($crc32 -ne $hash) {
        #     Write-Warning "[CRC32 NOT_MATCH][$hash] $_ "
        # } else {
        #     $crc32CheckPass = 1
        # }
        # if ($crc32CheckPass -eq 0) {
        #     return
        # }
        
        $crc32CheckPass = 1

        if ($versionCheckPass -and $sizeCheckPass -and $crc32CheckPass) {
            $canInstall += @{id=$toPath;dirPath=$dirPath;from=$_fromPath;to=$_toPath;fromver=$oldver;tover=$ver}
        }
    }
}

$readyToInstall = New-Object 'system.collections.generic.dictionary[string,Hashtable]'
$canInstall | ForEach-Object {
    if ($readyToInstall[$_.id]) {
        # check upper version
        # Write-Warning ("[{0}:{1}] [{2}:{3}]" -f $readyToInstall[$_.id].dirPath, $readyToInstall[$_.id].tover, $_.dirPath, $_.tover)
        if ($_.tover -gt $readyToInstall[$_.id].tover) {
            $readyToInstall[$_.id] = $_
        }
    } else {
        $readyToInstall[$_.id] = $_
    }
}

$readyToInstall.Values | ForEach-Object {
    Write-Output ("{0} {1} {2} -> {3}" -f $_.dirPath,$_.id,$_.fromver,$_.tover)
}

Write-Output ("Installing to {0}" -f $targetCom3d2Dir)

$ready = Read-Host -Prompt 'Ready?(y/N)'
if ($ready -ne 'y' -or $ready -ne 'Y') {
    exit
}

Write-Output "Begin install"

# start install
$i = 0
$total = $readyToInstall.Values.Count
$readyToInstall.Values | ForEach-Object {
    $i++
    Write-Output ("[$i/$total] {0} {1} {2} -> {3}" -f $_.dirPath,$_.id,$_.fromver,$_.tover)
    New-Item -ItemType File -Path $_.to -Force | Out-Null
    Copy-Item -LiteralPath $_.from -Destination $_.to -Force
    $targetFileVers[$_.id] = $_.tover
}

$updateListContent = ""
$targetFileVers.Keys | ForEach-Object {
    $updateListContent += ("{0},{1}" -f $_, $targetFileVers[$_])
    $updateListContent += [System.Environment]::NewLine
}

# -NoNewline because we already have one
$updateListContent | Out-File -LiteralPath "$targetCom3d2Dir\update.lst" -Force -Encoding "utf8" -NoNewline
