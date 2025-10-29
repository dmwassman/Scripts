<#
NAME: set_photo.ps1
PURPOSE: Set AD photo or default as user profile image. Runs as SYSTEM from Scheduled Task
DATE: 2018.05.24
BY: David Wassman

LOGS
#|DATE|BY|LOG
================================================================================================================================================
================================================================================================================================================
#>

Add-Type -AssemblyName System.Drawing
# Pull all profiles loaded in registry
$(Get-ChildItem -Path Registry::HKEY_USERS -ErrorAction SilentlyContinue).Name | where{$(Test-Path -Path "Registry::$_\Volatile Environment")} | foreach{
    # Get SID from registry key
    $strSID = $_.Replace("HKEY_USERS\","")
    # Get user from Volatile Environment values
    $strUser = Get-ItemPropertyValue -Path "Registry::$_\Volatile Environment" -Name "USERNAME"
    $strUser

    if($(Get-ItemPropertyValue -Path "Registry::$_\Volatile Environment" -Name "USERDOMAIN") -ne "$env:COMPUTERNAME"){
        $strDomain = Get-ItemPropertyValue -Path "Registry::$_\Volatile Environment" -Name "USERDNSDOMAIN"
        # Get AD photo for account
        $objPhoto = [ADSISearcher]"(&(objectCategory=User)(SAMAccountName=$strUser))"
        $objPhoto.SearchRoot = "LDAP://$strDomain"
        $objPhoto = $($($objPhoto).FindOne().Properties).thumbnailphoto
        # Get profile folder IT folder
        $strPath = "$(Get-ItemPropertyValue -Path "Registry::$_\Volatile Environment" -Name "USERPROFILE")\IT"
    
        # Create hidden IT folder in user profile folder
        if(!(Test-Path -Path $strPath)){
            $(New-Item -Path $strPath -Type Directory).Attributes = "Hidden"
        }

        # Target registry key for images
        $strKey = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AccountPicture\Users\$strSID"
        # Value template
        $strValue = "Image{0}"

        if(!(Test-Path -Path $strKey)){
            # Key doesnt exist. Must be new user. Add photo
            $null = New-Item -Path $strKey
            $bolPhoto = $true
        }elseif($objPhoto -ne $null){
            if($(Get-ItemPropertyValue -Path $strKey -Name "Image32") -eq "$env:SYSTEMDRIVE\IT\Ology_Icon.png"){
                # Key is set to default image when there is an AD photo to use
                $bolPhoto = $true
            }elseif($(Get-ItemPropertyValue -Path $strKey -Name "Image32") -ne "$strPath\Image32.png"){
                # Key is set to unauthorized picture
                $bolPhoto = $true
            }else{
                # Key exists and set correctly
                $bolPhoto = $false
            }
        }else{
            $bolPhoto = $true
        }



        if($bolPhoto){
            # Add photo to user profile
            if([bool]$objPhoto){    
                # Add AD Photo
                $strFile = "$strPath\Image{0}.png"
                # Save AD photo locally
                $strTemp = $([string]::Format($strFile,""))
                $objPhoto | Set-Content -Path $strTemp -Encoding Byte -Force
                # Load local photo to resize
                $objPhoto = [System.Drawing.Image]::FromFile($strTemp)
    
                foreach($intSize in  @(32,40,48,96,192,200,240,448)){
                    # Create image for each size using value template
                    $strImage = [string]::Format($strFile,$intSize)
                    # Creae image object to manipulate image size and scale accordingly
                    $objImage = New-Object System.Drawing.Bitmap($intSize,$intSize)
                    $objGraph = [System.Drawing.Graphics]::FromImage($objImage)      
                    $objGraph.DrawImage($objPhoto,0,0,$intSize,$intSize)
                    $objImage.Save([string]::Format($strImage,$intSize))
   
                    # Set Registry key values to the new photo images
                    $null = New-ItemProperty -Path $strKey -Name $([string]::Format($strValue,$intSize)) -Value $strImage -Force 
                }

                # Remove photo objects
                $objImage.Dispose()
                $objPhoto.Dispose()
                # Delete temp photo
                Remove-Item -Path $strTemp -Force -Confirm:$false
            }else{
                # Add default photo
                foreach($intSize in  @(32,40,48,96,192,200,240,448)){
                    $null = New-ItemProperty -Path $strKey -Name $([string]::Format($strValue,$intSize)) -Value "$env:SYSTEMDRIVE\IT\Ology_Icon.png" -Force 
                }
            }
       }
    }
}

# SIG # Begin signature block
# MIIZgQYJKoZIhvcNAQcCoIIZcjCCGW4CAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUZU3b45GG2hTtEUsVn6JQlMYc
# 5rCgghSUMIIEhDCCA2ygAwIBAgIQQhrylAmEGR9SCkvGJCanSzANBgkqhkiG9w0B
# AQUFADBvMQswCQYDVQQGEwJTRTEUMBIGA1UEChMLQWRkVHJ1c3QgQUIxJjAkBgNV
# BAsTHUFkZFRydXN0IEV4dGVybmFsIFRUUCBOZXR3b3JrMSIwIAYDVQQDExlBZGRU
# cnVzdCBFeHRlcm5hbCBDQSBSb290MB4XDTA1MDYwNzA4MDkxMFoXDTIwMDUzMDEw
# NDgzOFowgZUxCzAJBgNVBAYTAlVTMQswCQYDVQQIEwJVVDEXMBUGA1UEBxMOU2Fs
# dCBMYWtlIENpdHkxHjAcBgNVBAoTFVRoZSBVU0VSVFJVU1QgTmV0d29yazEhMB8G
# A1UECxMYaHR0cDovL3d3dy51c2VydHJ1c3QuY29tMR0wGwYDVQQDExRVVE4tVVNF
# UkZpcnN0LU9iamVjdDCCASIwDQYJKoZIhvcNAQEBBQADggEPADCCAQoCggEBAM6q
# gT+jo2F4qjEAVZURnicPHxzfOpuCaDDASmEd8S8O+r5596Uj71VRloTN2+O5bj4x
# 2AogZ8f02b+U60cEPgLOKqJdhwQJ9jCdGIqXsqoc/EHSoTbL+z2RuufZcDX65OeQ
# w5ujm9M89RKZd7G3CeBo5hy485RjiGpq/gt2yb70IuRnuasaXnfBhQfdDWy/7gbH
# d2pBnqcP1/vulBe3/IW+pKvEHDHd17bR5PDv3xaPslKT16HUiaEHLr/hARJCHhrh
# 2JU022R5KP+6LhHC5ehbkkj7RwvCbNqtMoNB86XlQXD9ZZBt+vpRxPm9lisZBCzT
# bafc8H9vg2XiaquHhnUCAwEAAaOB9DCB8TAfBgNVHSMEGDAWgBStvZh6NLQm9/rE
# JlTvA73gJMtUGjAdBgNVHQ4EFgQU2u1kdBScFDyr3ZmpvVsoTYs8ydgwDgYDVR0P
# AQH/BAQDAgEGMA8GA1UdEwEB/wQFMAMBAf8wEQYDVR0gBAowCDAGBgRVHSAAMEQG
# A1UdHwQ9MDswOaA3oDWGM2h0dHA6Ly9jcmwudXNlcnRydXN0LmNvbS9BZGRUcnVz
# dEV4dGVybmFsQ0FSb290LmNybDA1BggrBgEFBQcBAQQpMCcwJQYIKwYBBQUHMAGG
# GWh0dHA6Ly9vY3NwLnVzZXJ0cnVzdC5jb20wDQYJKoZIhvcNAQEFBQADggEBAE1C
# L6bBiusHgJBYRoz4GTlmKjxaLG3P1NmHVY15CxKIe0CP1cf4S41VFmOtt1fcOyu9
# 08FPHgOHS0Sb4+JARSbzJkkraoTxVHrUQtr802q7Zn7Knurpu9wHx8OSToM8gUmf
# ktUyCepJLqERcZo20sVOaLbLDhslFq9s3l122B9ysZMmhhfbGN6vRenf+5ivFBjt
# pF72iZRF8FUESt3/J90GSkD2tLzx5A+ZArv9XQ4uKMG+O18aP5cQhLwWPtijnGMd
# ZstcX9o+8w8KCTUi29vAPwD55g1dZ9H9oB4DK9lA977Mh2ZUgKajuPUZYtXSJrGY
# Ju6ay0SnRVqBlRUa9VEwggTmMIIDzqADAgECAhBiXE2QjNVC+6supXM/8VQZMA0G
# CSqGSIb3DQEBBQUAMIGVMQswCQYDVQQGEwJVUzELMAkGA1UECBMCVVQxFzAVBgNV
# BAcTDlNhbHQgTGFrZSBDaXR5MR4wHAYDVQQKExVUaGUgVVNFUlRSVVNUIE5ldHdv
# cmsxITAfBgNVBAsTGGh0dHA6Ly93d3cudXNlcnRydXN0LmNvbTEdMBsGA1UEAxMU
# VVROLVVTRVJGaXJzdC1PYmplY3QwHhcNMTEwNDI3MDAwMDAwWhcNMjAwNTMwMTA0
# ODM4WjB6MQswCQYDVQQGEwJHQjEbMBkGA1UECBMSR3JlYXRlciBNYW5jaGVzdGVy
# MRAwDgYDVQQHEwdTYWxmb3JkMRowGAYDVQQKExFDT01PRE8gQ0EgTGltaXRlZDEg
# MB4GA1UEAxMXQ09NT0RPIFRpbWUgU3RhbXBpbmcgQ0EwggEiMA0GCSqGSIb3DQEB
# AQUAA4IBDwAwggEKAoIBAQCqgvGEqVvYcbXSXSvt9BMgDPmb6dGPdF5u7uspSNjI
# vizrCmFgzL2SjXzddLsKnmhOqnUkcyeuN/MagqVtuMgJRkx+oYPp4gNgpCEQJ0Ca
# WeFtrz6CryFpWW1jzM6x9haaeYOXOh0Mr8l90U7Yw0ahpZiqYM5V1BIR8zsLbMaI
# upUu76BGRTl8rOnjrehXl1/++8IJjf6OmqU/WUb8xy1dhIfwb1gmw/BC/FXeZb5n
# OGOzEbGhJe2pm75I30x3wKoZC7b9So8seVWx/llaWm1VixxD9rFVcimJTUA/vn9J
# AV08m1wI+8ridRUFk50IYv+6Dduq+LW/EDLKcuoIJs0ZAgMBAAGjggFKMIIBRjAf
# BgNVHSMEGDAWgBTa7WR0FJwUPKvdmam9WyhNizzJ2DAdBgNVHQ4EFgQUZCKGtkqJ
# yQQP0ARYkiuzbj0eJ2wwDgYDVR0PAQH/BAQDAgEGMBIGA1UdEwEB/wQIMAYBAf8C
# AQAwEwYDVR0lBAwwCgYIKwYBBQUHAwgwEQYDVR0gBAowCDAGBgRVHSAAMEIGA1Ud
# HwQ7MDkwN6A1oDOGMWh0dHA6Ly9jcmwudXNlcnRydXN0LmNvbS9VVE4tVVNFUkZp
# cnN0LU9iamVjdC5jcmwwdAYIKwYBBQUHAQEEaDBmMD0GCCsGAQUFBzAChjFodHRw
# Oi8vY3J0LnVzZXJ0cnVzdC5jb20vVVROQWRkVHJ1c3RPYmplY3RfQ0EuY3J0MCUG
# CCsGAQUFBzABhhlodHRwOi8vb2NzcC51c2VydHJ1c3QuY29tMA0GCSqGSIb3DQEB
# BQUAA4IBAQARyT3hBeg7ZazJdDEDt9qDOMaSuv3N+Ntjm30ekKSYyNlYaDS18Ash
# U55ZRv1jhd/+R6pw5D9eCJUoXxTx/SKucOS38bC2Vp+xZ7hog16oYNuYOfbcSV4T
# p5BnS+Nu5+vwQ8fQL33/llqnA9abVKAj06XCoI75T9GyBiH+IV0njKCv2bBS7vzI
# 7bec8ckmONalMu1Il5RePeA9NbSwyVivx1j/YnQWkmRB2sqo64sDvcFOrh+RMrjh
# JDt77RRoCYaWKMk7yWwowiVp9UphreAn+FOndRWwUTGw8UH/PlomHmB+4uNqOZrE
# 6u4/5rITP1UDBE0LkHLU6/u8h5BRsjgZMIIE/jCCA+agAwIBAgIQK3PbdGMRTFpb
# MkryMFdySTANBgkqhkiG9w0BAQUFADB6MQswCQYDVQQGEwJHQjEbMBkGA1UECBMS
# R3JlYXRlciBNYW5jaGVzdGVyMRAwDgYDVQQHEwdTYWxmb3JkMRowGAYDVQQKExFD
# T01PRE8gQ0EgTGltaXRlZDEgMB4GA1UEAxMXQ09NT0RPIFRpbWUgU3RhbXBpbmcg
# Q0EwHhcNMTkwNTAyMDAwMDAwWhcNMjAwNTMwMTA0ODM4WjCBgzELMAkGA1UEBhMC
# R0IxGzAZBgNVBAgMEkdyZWF0ZXIgTWFuY2hlc3RlcjEQMA4GA1UEBwwHU2FsZm9y
# ZDEYMBYGA1UECgwPU2VjdGlnbyBMaW1pdGVkMSswKQYDVQQDDCJTZWN0aWdvIFNI
# QS0xIFRpbWUgU3RhbXBpbmcgU2lnbmVyMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8A
# MIIBCgKCAQEAv1I2gjrcdDcNeNV/FlAZZu26GpnRYziaDGayQNungFC/aS42Lwpn
# P0ChSopjNZvQGcx0qhcZkSu1VSAZ+8AaOm3KOZuC8rqVoRrYNMe4iXtwiHBRZmns
# d/7GlHJ6zyWB7TSCmt8IFTcxtG2uHL8Y1Q3P/rXhxPuxR3Hp+u5jkezx7M5ZBBF8
# rgtgU+oq874vAg/QTF0xEy8eaQ+Fm0WWwo0Si2euH69pqwaWgQDfkXyVHOaeGWTf
# dshgRC9J449/YGpFORNEIaW6+5H6QUDtTQK0S3/f4uA9uKrzGthBg49/M+1BBuJ9
# nj9ThI0o2t12xr33jh44zcDLYCQD3npMqwIDAQABo4IBdDCCAXAwHwYDVR0jBBgw
# FoAUZCKGtkqJyQQP0ARYkiuzbj0eJ2wwHQYDVR0OBBYEFK7u2WC6XvUsARL9jo2y
# VXI1Rm/xMA4GA1UdDwEB/wQEAwIGwDAMBgNVHRMBAf8EAjAAMBYGA1UdJQEB/wQM
# MAoGCCsGAQUFBwMIMEAGA1UdIAQ5MDcwNQYMKwYBBAGyMQECAQMIMCUwIwYIKwYB
# BQUHAgEWF2h0dHBzOi8vc2VjdGlnby5jb20vQ1BTMEIGA1UdHwQ7MDkwN6A1oDOG
# MWh0dHA6Ly9jcmwuc2VjdGlnby5jb20vQ09NT0RPVGltZVN0YW1waW5nQ0FfMi5j
# cmwwcgYIKwYBBQUHAQEEZjBkMD0GCCsGAQUFBzAChjFodHRwOi8vY3J0LnNlY3Rp
# Z28uY29tL0NPTU9ET1RpbWVTdGFtcGluZ0NBXzIuY3J0MCMGCCsGAQUFBzABhhdo
# dHRwOi8vb2NzcC5zZWN0aWdvLmNvbTANBgkqhkiG9w0BAQUFAAOCAQEAen+pStKw
# pBwdDZ0tXMauWt2PRR3wnlyQ9l6scP7T2c3kGaQKQ3VgaoOkw5mEIDG61v5MzxP4
# EPdUCX7q3NIuedcHTFS3tcmdsvDyHiQU0JzHyGeqC2K3tPEG5OfkIUsZMpk0uRlh
# dwozkGdswIhKkvWhQwHzrqJvyZW9ljj3g/etfCgf8zjfjiHIcWhTLcuuquIwF4Mi
# KRi14YyJ6274fji7kE+5Xwc0EmuX1eY7kb4AFyFu4m38UnnvgSW6zxPQ+90rzYG2
# V4lO8N3zC0o0yoX/CLmWX+sRE+DhxQOtVxzhXZIGvhvIPD+lIJ9p0GnBxcLJPufF
# cvfqG5bilK+GLjCCBhwwggUEoAMCAQICEz8AAANKmwXbmZXN7qsAAAAAA0owDQYJ
# KoZIhvcNAQELBQAwcjETMBEGCgmSJomT8ixkARkWA2NvbTEgMB4GCgmSJomT8ixk
# ARkWEG5hbm90aGVyYXBldXRpY3MxFjAUBgoJkiaJk/IsZAEZFgZzZWN1cmUxITAf
# BgNVBAMTGHNlY3VyZS1DQTE4NTAtV08wSVRSVC1DQTAeFw0xOTA0MjIxMjA5Mjha
# Fw0yMDA0MjExMjA5MjhaMBgxFjAUBgNVBAMTDURhdmlkIFdhc3NtYW4wggEiMA0G
# CSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQC302VfvJsDoy7lrliFfqtzgY7M6NU8
# PFECPhQGYYjCnvGKGb+UXDZrf7GYLpvD16ynoJGtc/5PKWEqVLuN2jeRy/rfMDoS
# VF5fH0AQSJwIzF+ZbocTFn9H7+OMB8lCmMPgdnLl6LWnI34aST5Tfv4TJmMoC8pz
# yhi0bATB89WP0R0eR56RCZhNJldTmrMCwYA3wgwdMZhO2K8KDQf3yn+Amxxfvg50
# iJiLr78NB/Ga0dlfNaQiKXSo982gzD6POe0gZfvp+QRtMCrbPgH4UF32u9M9pSDX
# +5rW1SK94BGu7/0GXD22VPYY3AlXNAseD0SR2O8ZDtF0Df4WCgKMKSpdAgMBAAGj
# ggMDMIIC/zA9BgkrBgEEAYI3FQcEMDAuBiYrBgEEAYI3FQiBx6ZhhPKJUIbRkSuD
# guoL2aMvgROHwsUihuPoGgIBZAIBETATBgNVHSUEDDAKBggrBgEFBQcDAzAOBgNV
# HQ8BAf8EBAMCB4AwDAYDVR0TAQH/BAIwADAbBgkrBgEEAYI3FQoEDjAMMAoGCCsG
# AQUFBwMDMFsGA1UdEQRUMFKgNAYKKwYBBAGCNxQCA6AmDCRkd2Fzc21hbkBzZWN1
# cmUubmFub3RoZXJhcGV1dGljcy5jb22BGmRhdmlkLndhc3NtYW5Ab2xvZ3liaW8u
# Y29tMB0GA1UdDgQWBBQKRHp+B+F/u0tWN8cggJdN0+VDCTAfBgNVHSMEGDAWgBRk
# ZQLW/WrDGo0OU7J/uAvBnl5+9TCB8AYDVR0fBIHoMIHlMIHioIHfoIHchoHZbGRh
# cDovLy9DTj1zZWN1cmUtQ0ExODUwLVdPMElUUlQtQ0EsQ049Y2ExODUwLXdvMGl0
# cnQsQ049Q0RQLENOPVB1YmxpYyUyMEtleSUyMFNlcnZpY2VzLENOPVNlcnZpY2Vz
# LENOPUNvbmZpZ3VyYXRpb24sREM9c2VjdXJlLERDPW5hbm90aGVyYXBldXRpY3Ms
# REM9Y29tP2NlcnRpZmljYXRlUmV2b2NhdGlvbkxpc3Q/YmFzZT9vYmplY3RDbGFz
# cz1jUkxEaXN0cmlidXRpb25Qb2ludDCB3QYIKwYBBQUHAQEEgdAwgc0wgcoGCCsG
# AQUFBzAChoG9bGRhcDovLy9DTj1zZWN1cmUtQ0ExODUwLVdPMElUUlQtQ0EsQ049
# QUlBLENOPVB1YmxpYyUyMEtleSUyMFNlcnZpY2VzLENOPVNlcnZpY2VzLENOPUNv
# bmZpZ3VyYXRpb24sREM9c2VjdXJlLERDPW5hbm90aGVyYXBldXRpY3MsREM9Y29t
# P2NBQ2VydGlmaWNhdGU/YmFzZT9vYmplY3RDbGFzcz1jZXJ0aWZpY2F0aW9uQXV0
# aG9yaXR5MA0GCSqGSIb3DQEBCwUAA4IBAQAB0EuNUhdORgKZKq/Z35XIz31e9S78
# GsDnZN2WtctRJrMqEcj3r1o/WYhSmprOsv68iJ94YmbXcXaSAu7WPbHosS0ADX33
# 4SwGny20xHQbpu3quHfamPlMeTIfGKjh/nfV9GucXZEu+dgtbOd8CcvQrUUBjhGW
# 6rrjuV/YY1Iu8LvXUmtq3CGEx61yimiHFyD30kfdkxbbbW+8QMOJD6SQFqAWUsdJ
# Iv8OJ+MTm53Qk3j0HbO4nbjpsb8ioCFAYBBhU2HFBQHGXdmzVYUV8mxoaRQNq/Y7
# N4x5MsKrGoyx00F6NOkt4vPjTkwmQhCoBctpLbl6JbpmPzMXOdde3kwWMYIEVzCC
# BFMCAQEwgYkwcjETMBEGCgmSJomT8ixkARkWA2NvbTEgMB4GCgmSJomT8ixkARkW
# EG5hbm90aGVyYXBldXRpY3MxFjAUBgoJkiaJk/IsZAEZFgZzZWN1cmUxITAfBgNV
# BAMTGHNlY3VyZS1DQTE4NTAtV08wSVRSVC1DQQITPwAAA0qbBduZlc3uqwAAAAAD
# SjAJBgUrDgMCGgUAoHgwGAYKKwYBBAGCNwIBDDEKMAigAoAAoQKAADAZBgkqhkiG
# 9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIB
# FTAjBgkqhkiG9w0BCQQxFgQUl1reHWMNuJPwv4Bs5MJHAer7WrEwDQYJKoZIhvcN
# AQEBBQAEggEAtDJts3cTgDCi525vE2DwE1MJskAaz3RW7Q2f43Yz/c+jwcUHgkU+
# ADK+msSTKoDo8eIFLmidoNUOcEKcD7tX372H5RNrjYK6j0G6jTWTeB7iri3L2EGk
# xYh0vUyXKygEoyYxXshl0VcVLnRrQcsqxJ1gBARD2myqTE1XToS86p8BwOozxYEn
# qriQ4MM8dWVcw6wKiqbOKzpU8lJ107A8CRPFKgmhqqJjlZYHw1QHiWO/4CUvlxwZ
# HFJSdmxnVGlSLbrBvlvkzoI8BRvEe+DZopoWe0bAtGk0gOERTkvsxz6IEhohxYcL
# iMJsnEMx2R6jhjP29lnqw1hc9DGcjfOXNaGCAigwggIkBgkqhkiG9w0BCQYxggIV
# MIICEQIBATCBjjB6MQswCQYDVQQGEwJHQjEbMBkGA1UECBMSR3JlYXRlciBNYW5j
# aGVzdGVyMRAwDgYDVQQHEwdTYWxmb3JkMRowGAYDVQQKExFDT01PRE8gQ0EgTGlt
# aXRlZDEgMB4GA1UEAxMXQ09NT0RPIFRpbWUgU3RhbXBpbmcgQ0ECECtz23RjEUxa
# WzJK8jBXckkwCQYFKw4DAhoFAKBdMBgGCSqGSIb3DQEJAzELBgkqhkiG9w0BBwEw
# HAYJKoZIhvcNAQkFMQ8XDTE5MTExNTE1MzgwM1owIwYJKoZIhvcNAQkEMRYEFAj9
# czIrd0LCVlbrliFYYewonVDmMA0GCSqGSIb3DQEBAQUABIIBAFD2iiyoZdrZRs9C
# uYNW4IaBKWgwDoKjk9AyKrZHJsySSIaXzCr4bkWBdrLpobtpVz/Q9DmAbOEJMR2v
# qPx8XTzZJVEL2FobiYpjyachVJdqfDmNi0wIF9vDHDrlriDE9qr3eD8lg2f1kwgg
# l4IPUH3AzQLLEJJFc8NOYAhbSuq8F3KYNCuiPXV1c7/k4Wf84UWHwpbl7GZEycF4
# h2+QgiLW5MW5fbFNXBxWQ2LqC+Vz6EHTNSFN4kmplxFsdeAG+ze+b0Gg2+7i2Z8x
# FIxvFypiE2Nh54CdoL5A+0GPhdRPVzB5MlB6+j5yzbhG7lFAxc3YL3C4Wwd3PZix
# +Foi5Tg=
# SIG # End signature block
