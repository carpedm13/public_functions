$vms = Get-AzVM

$array = @()
$arrayMemberType = 'NoteProperty'

foreach ($vm in $vms){
  $vmName = $vm.Name
  $vmRg = $vm.ResourceGroupName
  $vmSize = $vm.HardwareProfile.VmSize
  $nics = $vm.NetworkProfile.NetworkInterfaces.id
  Write-Host "Getting Info For $vmName"

  $osDisk = $vm.StorageProfile.OsDisk.ManagedDisk.Id
  $osDiskName = $osDisk.split('/')[8]
  $osDiskRg = $osDisk.split('/')[4]
  $osDiskInfo = Get-AzDisk -ResourceGroupName $osDiskRg -DiskName $osDiskName
  $osDiskSku = $osDiskInfo.Sku.Name

  foreach ($nic in $nics){
    $nicName = $nic.split('/')[8]
    $nicRg = $nic.split('/')[4]

    $networkInterface = Get-AzNetworkInterface -ResourceGroupName $nicRg -Name $nicName
    $ipForward = $networkInterface.EnableIPForwarding
    $accelNet = $networkInterface.EnableAcceleratedNetworking
    $ipAddress = $networkInterface.IpConfigurations.PrivateIpAddress

    $arrayTarget = New-Object -TypeName System.Object
    $arrayTarget | Add-Member -MemberType $arrayMemberType -Name 'VM' -Value $vmName
    $arrayTarget | Add-Member -MemberType $arrayMemberType -Name 'VM RG' -Value $vmRg
    $arrayTarget | Add-Member -MemberType $arrayMemberType -Name 'VM Size' -Value $vmSize
    $arrayTarget | Add-Member -MemberType $arrayMemberType -Name 'IP Address' -Value $ipAddress
    $arrayTarget | Add-Member -MemberType $arrayMemberType -Name 'Nic Name' -Value $nicName
    $arrayTarget | Add-Member -MemberType $arrayMemberType -Name 'NIC RG' -Value $nicRg
    $arrayTarget | Add-Member -MemberType $arrayMemberType -Name 'IP Forwarding' -Value $ipForward
    $arrayTarget | Add-Member -MemberType $arrayMemberType -Name 'Accelerated Networking' -Value $accelNet
    $arrayTarget | Add-Member -MemberType $arrayMemberType -Name 'OS Disk SKU' -Value $osDiskSku
    $arrayTarget | epcsv -NoTypeInformation -Path C:\working\coreVmInfo.csv -Append
  }
  
}

#$array | Export-Csv -NoTypeInformation -Path C:\working\coreVmInfo.csv