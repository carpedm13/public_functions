function Suspend-AzVM {
    param(
        [string[]] $vmName,
        [string[]] $resourceGroupName
    )

    $count = 0
    foreach ($vm in $vmName){
        $resourceGroup = $resourceGroupName[$count]
        
        #GET VM INFORMATION
        $vmInfo = Get-AzVM -ResourceGroupName $resourceGroup -Name $vm
        #STOP VM IF RUNNING
        Stop-AzVM -Name $vm -ResourceGroupName $resourceGroup -Force
        
        #CHANGE OS DISK SKU
        $osDiskId = $vmInfo.StorageProfile.OsDisk.ManagedDisk.id
        $diskName = $osDiskId.Split('/')[8]
        $diskRg = $osDiskId.Split('/')[4]
        $osDiskInfo = Get-AzDisk -ResourceGroupName $diskRg -DiskName $diskName
        $osDiskConfig = New-AzDiskUpdateConfig -SkuName Standard_LRS -DiskSizeGB $osDiskInfo.DiskSizeGB
        Update-AzDisk -ResourceGroupName $diskRg -DiskName $diskName -DiskUpdate $osDiskConfig

        #UPDATE DATA DISKS SKU
        $dataDisks = $vmInfo.StorageProfile.DataDisks.id
        foreach ($dataDisk in $dataDisks){
             $diskName = $dataDisk.Split('/')[8]
            $diskRg = $dataDisk.Split('/')[4]

            $dataDiskInfo = Get-AzDisk -ResourceGroupName $diskRg -DiskName $diskName
            $dataDiskConfig = New-AzDiskUpdateConfig -SkuName Standard_LRS -DiskSizeGB $dataDiskInfo.DiskSizeGB
            Update-AzDisk -ResourceGroupName $diskRg -DiskName $diskName -DiskUpdate $dataDiskConfig
        }

        $count++
    }
}