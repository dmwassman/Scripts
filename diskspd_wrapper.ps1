<#
.SYNOPSIS
    Wrapper for diskspd to perform standard disk performance testing.
.DESCRIPTION
    Executes diskspd with a set of predefined workloads for one or more
    drives.  The script creates a temporary Data folder on every drive
    (if needed), runs the tests, and writes the result logs next to
    the script.
.EXAMPLE
    PS> .\diskspd_wrapper.ps1 -Drives 'D','E' -Tests '-w100 -r -b64K -d60 -w60 -t8 -o8 -L','-r -b64K -d60 -w60 -t8 -o8 -L'
    Run write and read tests on drives D and E
.INPUTS
    System.String[]
.OUTPUTS
    • Disk Performance Logs in the directory containing the script
    • Error log file in the same directory
.PARAMETER Drives
    List of drive letters to test (e.g. @('E','F')).  The parameter
    is mandatory and is validated to ensure the drive exists and
    that a “Data” sub‑folder is present or can be created.
.PARAMETER Tests
    Array of “title:args” strings that specify the workload name
    and the arguments to pass to diskspd.  If omitted, three
    standard workloads are used:
        - Sequential:   -w50 -Sh -si -b1M -d120 -W60 -t8 -o8 -L
        - Medium:       -w50 -Sh -r -b64K -d120 -W60 -t8 -o16 -L
        - Small:        -w50 -Sh -r -b8K -d120 -W60 -t8 -o32 -L
.NOTES
    Author: David Wassman
    Date:  November 6, 2025
.LINK
    https://github.com/microsoft/diskspd
.LINK
    https://portal.nutanix.com/page/documents/kbs/details?targetId=kA00e000000XmXnCAK
#>

[CmdletBinding()]
Param(
    # Mandatory list of one or more drive letters.
    [Parameter(
        Mandatory=$true,
        Position=0,
        ValueFromPipeline=$true,
        HelpMessage="Enter a comma‑delimited list of drive letters to test."
    )]
    [ValidateScript({
        # Validation runs once per supplied drive letter.
        foreach($drive in $_){
            # 1. Does the drive exist?
            if(!(Test-Path "$($drive):\")){
                throw [System.Management.Automation.ValidationMetadataException]"$($drive): does not exit."
            }
            # 2. Is the “Data” folder present?  If not, try to create it.
            elseif(!(Test-Path "$($drive):\Data")){
                try{
                    New-Item -Path "$($drive):\Data" -Type Directory | Out-Null
                    $true
                }catch{
                    throw [System.Management.Automation.ValidationMetadataException]"Could not create '$($drive):\Data' folder."
                }
            }else{
                # 3. Test that the folder is writable.
                try{
                    $file = "$($drive):\Data\diskspd_temp"
                    [io.file]::OpenWrite($file).Close()
                    [io.file]::Delete($file)
                    $true
                }catch{
                    throw [System.Management.Automation.ValidationMetadataException]"Path '$($drive):\Data' is not writeable."
                }
            }
        }
    })]
    [string[]]$Drives,

    # Optional list of workload definitions.
    [Parameter(
        Mandatory=$false,
        Position=2,
        HelpMessage="Enter a title:comma‑delimited list of testing arguments for DiskSpd."
    )]
    [string[]]$Tests=$()
)

# If Args were not supplied, create the default set of workloads.
if(!($PSBoundParameters.ContainsKey('Tests'))){
    $Tests = "Sequential:-w50 -Sh -si -b1M -d120 -W60 -t8 -o8 -L","Medium:-w50 -Sh -r -b64K -d120 -W60 -t8 -o16 -L","Small:-w50 -Sh -r -b8K -d120 -W60 -t8 -o32 -L"
}

# Loop over each drive supplied by the user.
foreach($drive in $Drives){
    # Build the file name and paths used for each test.
    $file  = "$($drive):\Data\$($(Get-Volume -DriveLetter $drive).FileSystemLabel)_$($drive)_diskspd.dat"
    $report = ".\$($(Get-Volume -DriveLetter $drive).FileSystemLabel)_$($drive)"    
    $log   = ".\diskspd_wrapper_error.log"

    # Compute the maximum amount of data to test.
    # 10 % of free space, rounded down to the nearest MB.
    [int]$size = ( (Get-PSDrive -Name $drive).Free * 0.10 ) / 1MB

    # A “duration” for the block‑size test; roughly 5 s per MB.
    [int]$duration = $size / 200

    # If a previous data file does not exist, create a new one.
    if(!(Test-Path $file)){
        Start-Process -FilePath ".\diskspd.exe" -ArgumentList "-w100","-Zr","-d$($duration)","-c$($size)M","$($file)" -NoNewWindow -RedirectStandardError $log -RedirectStandardOutput "NUL" -Wait | Out-Null
    }

    # ------------------------------------------------------------
    # Run each workload defined in $Args against the current drive.
    # ------------------------------------------------------------
    foreach($test in $Tests){
        # Separate the “title” part from the actual arguments.
        if($test.Contains(":")){
            $testName = "$($test.Split(":")[0])"   # e.g. "Sequential"
        }else{
            # Sometimes a title may not be supplied; use the raw string.
            $testName = $test.Replace(" ","").Replace("-","_")
        }

        # Split the argument string into an array suitable for Start‑Process.
        [string[]]$testList = $test.Split(":")[1].Split(" ")
        # Add the full path to the data file to the argument list.
        $testList += $file

        # Keep track of the report file name for this test.
        $report += "_$($testName).txt"

        # Inform the user that the test is starting.
        Write-Output "Running test $($testName) for: $($drive)"

        # Execute diskspd with the prepared arguments.  
        # Notice the redirection of stderr/stdout to the log and result file.
        Start-Process -FilePath ".\diskspd.exe" -ArgumentList $testList -NoNewWindow -RedirectStandardError $log -RedirectStandardOutput $report -Wait | Out-Null

        # Inform the user when the test is complete.
        Write-Output "Test $($testName) run completed for $($drive)."

        # Reset the report path for the next test.
        $report = ".\$($(Get-Volume -DriveLetter $drive).FileSystemLabel)_$($drive)"    

    }
    # Clean up the temporary data file if it still exists.
    if(Test-Path $file){
        Remove-Item -Path $file
    }
}