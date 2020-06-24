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