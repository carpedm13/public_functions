function Delete-AzVM{
	<#
		.SYNOPSIS
		Delete-AzVM removes a VM, its associated Disks, NICs, Availability Sets, Network Security Groups, and Public IPs
	
		.PARAMETER vmName
		Name of the VM to delete - Must be present.
		.PARAMETER resourceGroup
		Resource Group containing the VM - If not present, script will search for it.
		.PARAMETER force
		Use the Force switch to not be prompted for deletions
		.EXAMPLE
		Delete-AzVM -vmName VmValue -resourceGroup RgValue -force
		Delete-AZVM will locate VM VmValue in resource group RgValue. Since the Force switch is active it will not prompt for any of the following actions
		If running the VM will be stopped
		The VM will be deleted and information gathered about its disks, NICs, and Availability Set
		The NICs will be located and deleted
		Any associated PIPs will be deleted
		Any NSG no longer in use will be deleted
		The OS Disk will be deleted
		All Data Disks will be deleted
		Any Availability Set not in use will be deleted
	#>

	[CmdletBinding()]
	param (
		[Parameter(Position=0,Mandatory=$True,HelpMessage='Enter the VM Name')]
		[string[]] $vmName,
		[string[]] $resourceGroup = $null,
		[switch] $force
	)

	function Resolve-BoolInput{
		<#
			.SYNOPSIS
			Resolve-BoolInput verifies and translates input into a $true or $false value
			.PARAMETER prompt
			Text to show the user
			.EXAMPLE
			Resolve-BoolInput -prompt Value
			The user will be prompted with the phrase value.
			Their input should consist of any of the following Yes, Y, True, T, No, N, False, F.
			Any other value entered will trigger a re-prompt for an answer.
		#>


		param(
			[Parameter(Position=0)] [string] $prompt
		)

		#Set Allowed Values
		$array_valid_true = @( 'yes', 'y', 'true', 't' )
		$array_valid_false = @( 'no', 'n', 'false', 'f' )
	
		#Validate Input
		$input = Read-Host -Prompt $prompt
		while ($array_valid_true -notcontains $input -and $array_valid_false -notcontains $input){
			$input = Read-Host -Prompt 'Please Enter Yes or No'
		}

		#Return Value
		if ($array_valid_true -contains $input){
			return $true
		}
		else {
			return $false
		}
	}

	#Set Variables
	$arraytype = 'NoteProperty'
	$count = 0

	foreach ($vmEntry in $vmName){
		if ($resourceGroup -ne $null){$resourceGroupEntry = $resourceGroup[$count]}
		else{$resourceGroupEntry = $null}

		#Get List of VMs if no resource group is specified
		if ($resourceGroupEntry -eq $null){
			$vmArray = @()
			$count = 1
  
			Write-Verbose -Message 'Getting VM Information'
			$vms = Get-AzVM
			$vmMatch = $vms | Where-Object {$_.name -eq $vmEntry}
  
			foreach ($vm in $vmMatch){
				$name = $vm.name
				$vmRg = $vm.ResourceGroupName
				$target = New-Object -TypeName System.Object
				$target | Add-Member -MemberType $arraytype -Name 'id' -Value $count
				$target | Add-Member -MemberType $arraytype -Name 'name' -Value $name
				$target | Add-Member -MemberType $arraytype -Name 'resourceGroup' -Value $vmRg
				$vmArray += $target
				$count++
			}

			if ($vmArray.Count -eq 1){
				$vmSelect = $vmArray | Where-Object id -EQ 1
			}
			else{
				$vmArray | Out-Host
				[int] $selection = Read-Host -Prompt 'Select VM To Delete'
				$vmSelect = $vmArray | Where-Object id -EQ $selection
				$vmEntry = $vmSelect.name
			}
			$resourceGroupEntry = $vmSelect.resourceGroup
		}

		#Get VM Status Information
		$vm = Get-AzVM -ResourceGroupName $resourceGroupEntry -Name $vmEntry -Status
		$status = ($vm.Statuses | Where-Object {$_.code -like '*PowerState*'}).DisplayStatus

		#Get Standard VM Information
		$vm = Get-AzVM -ResourceGroupName $resourceGroupEntry -Name $vmEntry

		#Ask to Shutdown VM if not Deallocated
		if ($status -eq 'VM running'){
			Write-Verbose -Message 'VM Still Running'
			if ($force){
				$shutdown = $True
			}
			else{
				$shutdown = Resolve-BoolInput -prompt ('Shut Down VM: {0} ? Yes/No' -f $vmEntry)
			}
			if ($shutdown -eq $false){
				Write-Verbose -Message 'Stopping Process'
				break
			}
			else{
				Write-Verbose -Message ('Shutting Down VM: {0}' -f $vmEntry)
				$stopDetails = $vm | Stop-AzVM -Force
			}
		}

		#Delete VM
		if ($force){
			$deleteVm = $True
		}
		else{
			$deleteVm = Resolve-BoolInput -prompt ('Delete VM: {0} ? Yes/No' -f $vmEntry)
		}
		if ($deleteVm -eq $false){
			Write-Verbose -Message 'Stopping Process'
			break
		}
		else{
			Write-Verbose -Message ('Deleting VM: {0}' -f $vmEntry)
			$deleteVmDetails = $vm | Remove-AzVM -Force
		}

		#Get OS Disk Information
		$osDiskName = ($vm.StorageProfile.OsDisk.ManagedDisk.Id).Split('/')[8]
		$osDiskRg = ($vm.StorageProfile.OsDisk.ManagedDisk.Id).Split('/')[4]
		if ($force){
			$deleteOs = $True
		}
		else{
			$deleteOs = Resolve-BoolInput -prompt ('Delete Disk: {0} ? Yes/No' -f $osDiskName)
		}

		if ($deleteOs -eq $false){
			Write-Verbose -Message ('Keeping Disk: {0}' -f $osDiskName)
		}
		else{
			Write-Verbose -Message ('Removing Disk: {0}' -f $osDiskName)
			$osDisk = Get-AzDisk -ResourceGroupName $osDiskRg -DiskName  $osDiskName
			$deleteOsDetails = $osDisk | Remove-AzDisk -Force
		}

		#Get Data Disk Information
		$datadisks = $vm.StorageProfile.DataDisks
		foreach ($datadisk in $datadisks){
			$datadiskName = $datadisk.name
			$datadiskRg = ($datadisk.ManagedDisk.id).Split('/')[4]
			if ($force){
				$deleteData = $True
			}
			else{
				$deleteData = Resolve-BoolInput -prompt ('Delete Disk: {0} ? Yes/No' -f $datadiskName)
			}
			if ($deleteData -eq $false){
				Write-Verbose -Message ('Keeping Disk: {0}' -f $datadiskName)
			}
			else{
				Write-Verbose -Message ('Removing Disk: {0}' -f $datadiskName)
				$dataDiskInfo =  Get-AzDisk -ResourceGroupName $datadiskRg -DiskName $datadiskName
				$deleteDataDetails = $dataDiskInfo | Remove-AzDisk -Force
			}
		}

		#Get NIC Information
		$nics = $vm.NetworkProfile.NetworkInterfaces.id
		foreach ($nic in $nics){
			$nicName = ($nic).Split('/')[8]
			$nicRg = ($nic).Split('/')[4]
			if ($force){
				$deleteNic = $True
			}
			else{
				$deleteNic =Resolve-BoolInput -prompt ('Delete NIC: {0} ? Yes/No' -f $nicName)
			}
			if ($deleteNic -eq $false){
				Write-Verbose -Message ('Keeping NIC: {0}' -f $nicName)
			}
			else{
				Write-Verbose -Message ('Deleting NIC: {0}' -f $nicName)
				$nicInfo = Get-AzNetworkInterface -ResourceGroupName $nicRg -Name $nicName
				$deleteNicDetails = $nicInfo | Remove-AzNetworkInterface -Force

				#Get/Remove NSG
				$nsg = $nicInfo.NetworkSecurityGroup.Id
				if ($nsg -ne $null){
					$nsgName = ($nsg).Split('/')[8]
					$nsgRg = ($nsg).Split('/')[4]
					$nsgInfo = Get-AzNetworkSecurityGroup -Name $nsgName -ResourceGroupName $nsgRg
					$nsgNics = $nsgInfo.NetworkInterfaces
					$nsgSubnets = $nsgInfo.Subnets
			  
					if ($nsgNics.Count -eq 0 -and $nsgSubnets.Count -eq 0){
						if ($force){
							$deleteNsg = $True
						}
						else{
							$deleteNsg = Resolve-BoolInput -prompt ('Delete NSG: {0} ? Yes/No' -f $nsgName)
						}
						if ($deleteNsg -eq $false){
							Write-Verbose -Message ('Retaining NSG: {0}' -f $nsgName)
						}
						else{
							$deleteNsgDetails = $nsgInfo | Remove-AzNetworkSecurityGroup -force
						}
					}
				}

				#Get/Remove Public IP
				$pips = $nicInfo.IpConfigurations.publicipaddress.Id
				foreach ($pip in $pips){
					$pipName = $pip.Split('/')[8]
					$pipRg = $pip.Split('/')[4]
					if ($force){
						$deletePip = $True
					}
					else{
						$deletePip = Resolve-BoolInput -prompt ('Delete PIP: {0} ? Yes/No' -f $pipName)
					}
					if ($deletePip -eq $false){
						Write-Verbose -Message ('Keeping PIP: {0}' -f $pipName)
					}
					else{
						Write-Verbose -Message ('Deleting PIP: {0}' -f $pipName)
						$pipInfo = Get-AzPublicIpAddress -ResourceGroupName $pipRg -Name $pipName
						$deletePipDetails = $pipInfo | Remove-AzPublicIpAddress -Force
					}
				}
			}
		}

		$avSet = $vm.AvailabilitySetReference.Id
		if ($avSet -eq $null){
			Write-Verbose -Message 'AvSet not found'
		}
		else{
			$avSetName = $avSet.Split('/')[8]
			$avSetRg = $avSet.Split('/')[4]
			$avSetInfo = Get-AzAvailabilitySet -Name $avSetName -ResourceGroupName $avSetRg
			$avSetVms = $avSetInfo.VirtualMachinesReferences
			if ($avSetVms.Count -eq 0){
				if ($force){
					$avSetDelete = $True
				}
				else{
					$avSetDelete = Resolve-BoolInput -prompt ('Delete AvSet: {0} ?  Yes/No' -f $avSetName)
				}
				if ($avSetDelete -eq $false){
					Write-Verbose -Message ('Keeping AV Set: {0}' -f $avSetName)
				}
				else{
					Write-Verbose -Message ('Deleting AV Set: {0}' -f $avSetName)
					$avSetInfo = Get-AzAvailabilitySet -ResourceGroupName $avSetRg -Name $avSetName
					$deleteAvSetDetails = $avSetInfo | Remove-AzAvailabilitySet -Force
				}
			}
			else{
				Write-Verbose -Message ('Availability Set {0} still in use. Skipping Delete.' -f $avSetName)
			}
		}
	  $count++
	}
}