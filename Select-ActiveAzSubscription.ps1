function Select-ActiveAzSubscription{
  <#
    .SYNOPSIS
    Select-AzureSubscription checks your Azure login status, logs you in, and provides a list of all Subscriptions you have access to.
    A new subscription can be selected simply by entering its ID number.
    
    .OUTPUTS
    Select-AzureSubscription returns the context for your selected subscription.
  #>


  $context = Get-AzContext
  if ($context -eq $null){
    Write-Output -InputObject 'You are not logged in - Running Login-AzAccount'
    Connect-AzAccount
  }
  $arraytype = 'NoteProperty'
  $subscriptions = get-azsubscription
  $subCount = 1
  Write-Output -InputObject 'Select Subscription'
  $Array = @()

  foreach ($subscription in $subscriptions){
    $target = New-Object -TypeName System.Object
    $target | Add-Member -MemberType $arraytype -Name 'id' -Value $subCount
    $target | Add-Member -MemberType $arraytype -Name 'name' -Value $subscription.Name
    $target | Add-Member -MemberType $arraytype -Name 'subscription' -Value $subscription.Id
    $array += $target
    $subCount++
  }

  #Write Array to Output
  $Array | out-host

  #READ HOST
  [uint16]$select = Read-Host -Prompt 'Enter Selection Number'
  $value = ($Array | Where-Object id -EQ $select).subscription
  $context = Set-AzContext -subscriptionid $value
  return $context
}