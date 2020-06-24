function Add-LinuxUser{
    param(
        [string[]] $device,
        [string[]] $username,
        [System.Management.Automation.PSCredential] $credential = $null,
        [string] $adminPassword,
        [switch] $sudoAccess
    )

    #Include Update-Array Function
    function Update-Array{
    param(
        [string[]] $variableNames,
        [string[]] $variableValues,
        [parameter(ValueFromPipeline = $true)][PSCustomObject[]] $existingArray = $null
    )

    Process{
        #Set Variables
        $count = 0
        #Import Existing array, or create new blank array
        if ($existingArrayName = $null){
            $workingArray = @()
        }
        else{
            $workingArray += $existingArray
        }
    }
    
    End{
    
        #Create Add Object
        $workingTarget = New-Object -TypeName System.Object
    
        #Parse Array Values
        foreach ($variableName in $variableNames){
            #Get Appropriate Value Data
            $value = $variableValues[$count]
        
            #Create Array Entry
            $workingTarget | Add-Member -MemberType NoteProperty -Name $variableName -Value $value

            #Increment Count
            $count++
        }

        #Add New information to array
        $workingArray += $workingTarget

        return $workingArray
    }
}

    #Add Necessary Types
    Add-Type -AssemblyName System.web

    #Get Creds if not present
    if ($Credential -eq $null){
        Write-Host 'No credentials present'
        $credential = Get-Credential -Message "Please Enter Existing User Credentials"
    }

    #Get Users - Create array of information
    foreach ($name in $username){
        $password = [System.Web.Security.Membership]::GeneratePassword(12, 1) -replace 'O|o|0|I|1|\|', '-' 
        $userArray = $userArray | Update-Array -variableNames 'username', 'password' -variableValues $name, $password
    }

    $userArray | Out-Host

    #Parse devices and add accounts to all
    foreach ($item in $device){
        $session = New-SSHSession -ComputerName $item -Credential $credential -Port 22

        $stream = New-SSHShellStream -Index 0
        $command = ($password | ConvertTo-SecureString -AsPlainText -Force)
        Invoke-SSHStreamExpectSecureAction -ShellStream $stream -Command 'sudo -i' -ExpectString 'Password:' -SecureAction ($command) -Verbose
        $stream.Read()

        foreach ($user in $userArray){
            $name = $user.name
            $password = $user.password

            #Create the new user
            $command = ('useradd {0}' -f $name)
            Invoke-SSHCommand -SSHSession $session -Command $command

            #Set the new user password
            $command = ('echo {0} | passwd --stdin {1}' -f $password, $name)
            Invoke-SSHCommand -SSHSession $session -Command $command
            
            #Force password change
            $command = ('passwd -e {0}' -f $name)
            Invoke-SSHCommand -SSHSession $session -Command $command
            
            if ($sudoAccess){
                #Add user to sudoers
                $command = ('usermod -aG wheel {0}' -f $name)
                Invoke-SSHCommand -SSHSession $session -Command $command
            }
        }

        $session | Remove-SSHSession
    }
}