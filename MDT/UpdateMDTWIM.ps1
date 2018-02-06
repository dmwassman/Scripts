<#
.SYNOPSIS 
    Offline patching of MDT WIM files from WSUS   
.DESCRIPTION 
    Using WSUS, the script will do the following for each valid WIM in the MDT deployment share:
        1) Mount the WIM
        2) Search WSUS for all approved updates for $TARGETGROUP and the product 
        3) Process update files:
            a) If $FILE.success.txt exists, check the mounted WIM to see if the update is currently installed.
            THis make sure new images get updates previously processed.
            b) If $FILE.failure.txt exists, read the $FILE.failure.txt and process the error count. If less 
            than $FAILURECOUNT, retry patch and increment error count if fails
            c) Else, download the update and process the patch. Create $FILE.success.txt if sucessfull or exists.
            Create $FILE.failure.txt if not
        4) Remove packages that are unapproved and remove folder
.NOTES 
    Requirements:
        Latest AIK installed
        WSUS manager installed
        MDT deployment share
    File Name: 
        UpdateMDTWIM.ps1
    By: 
        David Wassman
    Logs:
    
.OUTPUTS 
    None
.PARAMETER ServerName (optional)
    WSUS server to connect to. Defaults to local machine or WSUS server in registry
.PARAMETER ServerPort (optional)
    WSUS port to connect to. Default: 8531
.PARAMETER TargetGroup (0)
    Name of WSUS computer target group
.PARAMETER Path (1)
    Path to a vaild MDT deployment share. Must have at least one Windows image
.PARAMETER NoSSL (optional)
    Switch to turn off SSL for the WSUS server connection
.PARAMETER DisplayTitlesOnly (optional)
    Outputs name of update files instead of patching WIM image
.PARAMETER FailureCount (optional)
    Number of failures to reprocess. Default: 3
#>
[CmdletBinding()]

Param 
(
    [Parameter(mandatory=$false)]
    [ValidateScript({Test-Connection -Quiet -Count 2 -ComputerName $_})]
    [string]
    $ServerName = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey(
                    "LocalMachine", 
                    $env:COMPUTERNAME
                  ).OpenSubKey(
                    "Software\Policies\Microsoft\Windows\WindowsUpdate"
                  ).GetValue(
                    "WUServer"
                  ).Split("/")[-1].Split(":")[0],
    [Parameter(mandatory=$false)]
    [ValidateRange(0,65535)]
    [Int32]
    $ServerPort = 8531,
    [Parameter(position=0, mandatory=$true)]
    [string]$TargetGroup,
    [Parameter(position=1, mandatory=$true)]
    [ValidateScript({ Test-Path "$_\Operating Systems\*\sources\install.wim"})]
    [string]$Path,
    [switch]$NoSSL,
    [switch]$DisplayTitlesOnly,
    [int]$FailureCount = 3
)

try{
    [void](Import-Module 'C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\DISM\dism.psd1' -Force -ErrorAction SilentlyContinue -WarningAction SilentlyContinue)
}catch{}


function addUpdate{
    $package = $args[0]
    $mount = $args[1]
    $file = $args[2]
    $id = $args[3]
    $count = $args[4]

    $output = New-Object -TypeName PSObject
    $output | Add-Member -NotePropertyName Save -NotePropertyValue $false
    $output | Add-Member -NotePropertyName Message -NotePropertyValue ""


    try{
        $package = $(Get-WindowsPackage -Path $mount -PackagePath "$file").PackageName
    }catch{}

    if($package -ne $null){
        if(!(Get-WindowsPackage -Path $mount | where{$_.PackageName -eq $package})){
            try{
                Write-Verbose "Installing $package..."
                [void](Add-WindowsPackage -Path $mount -PackagePath "$file" -ErrorAction SilentlyContinue -WarningAction SilentlyContinue)
                $output.Message = "Successfully installed $package."
                "$package;$id" > "$file.success.txt"
                $output.Save = $true
                if(Test-Path -Path "$file.failure.txt"){
                    Remove-Item -Path "$file.failure.txt" -Force
                }
            }catch{
                $count = $count + 1
                Write-Verbose "Count = $count"
                Write-Verbose "$file.failure.txt"
                "$count;$id" > "$file.failure.txt"
                if(Test-Path -Path "$file.success.txt"){
                    Remove-Item -Path "$file.success.txt" -Force
                }
                $output.Message = "Failed to install $package"
            
            }
        }else{
            $output.Message = "$package already installed in WIM."
            "$package;$id" > "$file.success.txt"
            if(Test-Path -Path "$file.failure.txt"){
                Remove-Item -Path "$file.failure.txt" -Force
            }
        }
       
    }else{
        $output.Message = "Unable to query image."
    }
    Remove-Item -Path "$file" -Force
    return $output
}

# Prepare folder structure if needed
$parent = $Path.Substring(0,$Path.LastIndexOf("\"))
$mount = "$parent\Mount"
if(!(Test-Path -Path $mount)){
    Write-Verbose "Creating $parent\Mount."
    [void](New-Item -Path $parent\Mount -ItemType Directory)
    Write-Output "Created $parent\Mount."
}

if(!(Test-Path -Path $parent\Files)){
    Write-Verbose "Creating $parent\Files."
    [void](New-Item -Path $parent\Files -ItemType Directory)
    Write-Output "Created $parent\Files."
}

if(!(Test-Path -Path $parent\Files\Updates)){
    Write-Verbose "Creating $parent\Files\Updates."
    [void](New-Item -Path $parent\Files\Updates -ItemType Directory)
    Write-Output "Created $parent\Files\Updates."
}

$scratch = "$parent\Files\Scratch"

if(!(Test-Path -Path $scratch)){
    Write-Verbose "Creating $scratch"
    [void](New-Item -Path $scratch -ItemType Directory)
    Write-Output "Created $scratch."
}

[void][Reflection.Assembly]::LoadWithPartialName("Microsoft.UpdateServices.Administration")
Write-Verbose "Connecting to WSUS Server $ServerName`:$ServerPort"
try {
    $wsus = [Microsoft.UpdateServices.Administration.AdminProxy]::GetUpdateServer($ServerName, -not $NoSSL, $ServerPort)
    Write-Output "Connected to $ServerName`:$ServerPort."
} catch {
    #A login error is non-terminating, so we need to make it terminating
    throw $_
}
$updateScope = New-Object Microsoft.UpdateServices.Administration.UpdateScope
$updateScope.ApprovedStates="Any"
$group = $wsus.GetComputerTargetGroups() | where{$_.Name -eq $TargetGroup}
if($group -ne $null){
    Write-Verbose "Adding $TargetGroup to scope."
    [void]($updateScope.ApprovedComputerTargetGroups.Add($group))
    Write-Output "Added $TargetGroup group to scope."

    Get-ChildItem -Path "$Path\Operating Systems\" -Directory | where{Test-Path -Path "$($_.Fullname)\sources\install.wim"} | foreach{
        $image = "$($_.Fullname)\sources\install.wim"
         
        Get-WindowsImage -ImagePath $image | foreach{
            $index = $_.ImageIndex
            $product = $(Get-WindowsImage -ImagePath $image -Index $index).ImageName.Replace(" Standard","").Replace(" Enterprise","").Replace(" Datacenter","").Replace(" Professional","")
            $updates = "$parent\Files\Updates\$TargetGroup\$product"
            
             Write-Progress -Activity "Patching $product" -Status "Mounting $image WIM" -PercentComplete 0

            if(!(Test-Path -Path $updates)){
                Write-Verbose "Creating $updates."
                [void](New-Item -Path $updates -ItemType Directory)
                Write-Output "Created $updates."
            }

            if(!(Get-WindowsImage -Mounted | where{$_.ImagePath -eq $image -and $_.Path -eq $mount -and $_.ImageIndex -eq $index})){
                $bolSave = $false     
                Get-WindowsImage -Mounted | foreach{
                    if($_.ImagePath -eq $image){
                        Write-Output "$image is already mounted. Dismounting and discarding."
                        [void](Dismount-WindowsImage -Path $_.Path -Discard -ErrorAction SilentlyContinue)
                    }
                }
                Get-WindowsImage -Mounted | foreach{
                    if($_.Path -eq $mount){
                        Write-Output "Mount path is in use. Dismounting and discarding."
                        [void](Dismount-WindowsImage -Path $_.Path -Discard -ErrorAction SilentlyContinue)
                    }
                }

                Get-WindowsImage -Mounted | foreach{
                    if($_.Path -eq $mount){
                        if($_.MountStatus -eq "Invalid"){
                            Write-Output "Mount path is invalid. Cleaning up."
                            [void](&"C:\Windows\System32\Dism.exe" /cleanup-Wim)
                        }
                    }
                }
                Write-Output "Mounting $image to $mount"
                [void](Mount-WindowsImage -Path $mount -ImagePath $image -Index $index -ScratchDirectory $scratch)
                Write-Progress -Activity "Patching $product"
            }else{
                $bolSave = $true            
            }
            $count = 0
            $files = $($wsus.GetUpdateApprovals($updateScope)).UpdateId.UpdateId.Guid | Get-Unique
            $number = $($files | Measure-Object).Count
            $files | foreach{
                $id = $_
                Get-WsusUpdate -UpdateServer $wsus -UpdateId $_ | foreach{
                    if($_.Products -notcontains $product){
                        $number = $number + 1
                    }else{
                       

                        $($wsus.SearchUpdates($_.Update.Title).GetInstallableItems().Files.FileUri.AbsoluteUri) | foreach{
                            $count = $count + 1     

                            [int]$failure = 0
                            $http = $_
                            $file = $http.substring($http.LastIndexOf("/") + 1)
                            $folder = $updates + "\" + $file.substring(0,$file.LastIndexOf("_")).Replace("-express","")
                            [int]$progress = $count/$number
        
                            
                            
                           
                        
                            if($file.ToUpper().substring($file.length - 4) -eq ".CAB"){
                                Write-Progress -Activity "Patching $product" -Status "Processing $file" -PercentComplete $progress
                                if(Test-Path -Path "$folder\$file.success.txt"){
                                    Get-Content -Path "$folder\$file.success.txt" | foreach{
                                        $package = $_.Split(";")[0]
                                        if(!(Get-WindowsPackage -Path $mount -PackageName $package)){
                                            if($DisplayTitlesOnly){
                                                Write-Output $file
                                            }else{
                                                Invoke-WebRequest -Uri $http -OutFile "$folder\$file" 
                                                $patch = addUpdate $package $mount "$folder\$file" $id $failure
                                                if($patch.Save){
                                                    $bolSave = $true
                                                }
                                                Write-Output $patch.Message
                                            }
                                        }else{
                                            Write-Output "$package already installed in WIM."
                                        }
                                    }
                                }elseif(Test-Path -Path "$folder\$file.failure.txt"){
                                    Get-Content -Path "$folder\$file.failure.txt" | foreach{
                                        $failure = [int]$_.Split(";")[0]
                                        if($failure -lt $FailureCount){
                                            if($DisplayTitlesOnly){
                                                Write-Output $file
                                            }else{
                                                Invoke-WebRequest -Uri $http -OutFile "$folder\$file"
                                                $patch = addUpdate $package $mount "$folder\$file" $id $failure 
                                                if($patch.Save){
                                                    $bolSave = $true
                                                }
                                                Write-Output $patch.Message
                                            }
                                        }
                                    }
                                }else{
                                    if(!(Test-Path -Path $folder)){
                                        Write-Verbose "Creating $folder."
                                        [void](New-Item -Path $folder -ItemType Directory)
                                        Write-Output "Created $folder."
                                    }
                                    if($DisplayTitlesOnly){
                                        Write-Output $file
                                    }else{
                                        Invoke-WebRequest -Uri $http -OutFile "$folder\$file"
                                        $patch = addUpdate $package $mount "$folder\$file" $id $failure
                                        if($patch.Save){
                                            $bolSave = $true
                                        }
                                        Write-Output $patch.Message
                                    }
                                }
                                Write-Output "Processed $file."
                            }
                        }
                   }
                }
                      
            }
    
            Write-Progress -Activity "Patching $product" -Status "Removing unapproved patches" -PercentComplete $progress

            if(!($DisplayTitlesOnly)){
                $files = Get-ChildItem -Path "$updates\*\*.txt" -Recurse 
                $number = $($files | Measure-Object).Count + $number
                $files | foreach{
                    $folder = $_.DirectoryName
                    Get-Content -Path $_.FullName | foreach{
                        $package = $_.Split(";")[0]
                        $id = $_.Split(";")[1]
                        if(!(($wsus.GetUpdateApprovals($updateScope)).UpdateId.UpdateId.Guid | Get-Unique | where{$_ -eq $id})){
                            $count = $count + 1
                            [int]$progress = $count/$number
                            Write-Progress -Activity "Patching $product" -Status "Removing unapproved patches" -PercentComplete $progress
                                  
                            if(Get-WindowsPackage -Path $mount -PackageName $package){
                                try{
                                    Write-Progress -Activity "Patching $product" -Status "Removing $package" -PercentComplete $progress
                                    [void](Remove-WindowsPackage -Path $mount -PackageName $package -ScratchDirectory $scratch)
                                    $bolSave = $true
                                    Write-Output "Removed $package."
                                }catch{
                                    Write-Output "Failed to remove $package."
                                }


                            }
                            Write-Progress -Activity "Patching $product" -Status "Removing $folder" -PercentComplete $progress
                            Remove-Item -Path $folder -Force -Recurse
                        }
                    }
                }
            }

            $progress = 100
             Write-Progress -Activity "Patching $product" -Status "Completed processing update files" -PercentComplete $progress


            if($bolSave){
                Write-Output "Dismounting and saving $image."
                [void](Dismount-WindowsImage -Path $mount -Save)
            }else{
                Write-Output "No new updates. Dismounting and discarding $image."
                [void](Dismount-WindowsImage -Path $mount -Discard)
            }
            Get-WindowsImage -Mounted | foreach{
                if($_.Path -eq $mount){
                    if($_.MountStatus -eq "Invalid"){
                        Write-Output "Mount path is invalid. Cleaning up."
                        [void](&"C:\Windows\System32\Dism.exe" /cleanup-Wim)
                    }
                }
            }

            

        }
    }
}else{
    Write-Error "Target Group does not exist"
}
 

