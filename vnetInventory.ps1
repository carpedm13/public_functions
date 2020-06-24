$array = @()
foreach ($sub in $subs){
    Set-AzContext -Subscription $sub

    $network = Get-AzVirtualNetwork
    $subnets = $network.subnets
    foreach ($subnet in $subnets){
        $id = $subnet.Id
        $snName = $id.split('/')[10]
        $vnName = $id.split('/')[8]
        $rgName = $id.split('/')[4]
        $addressPrefix = $subnet.ad$arradressprefix
        $array = Update-Array -variableNames 'Resource Group', 'Vnet Name', 'Subnet Name', 'Address Space' `
            -variableValues $rgName, $vnName, $snName, $addressPrefix -existingArray $array
    }
}