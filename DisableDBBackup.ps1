$vault = Get-AzureRmRecoveryServicesVault -ResourceGroupName "ressource group name" -Name "vault name"
Set-AzureRmRecoveryServicesVaultContext -Vault $vault
$containers = Get-AzureRmRecoveryServicesBackupContainer -ContainerType AzureVMAppContainer -Status Registered

foreach ($container in $containers)
{
    $items = Get-AzureRmRecoveryServicesBackupItem -Container $container -WorkloadType MSSQL
    foreach ($item in $items)
    {
        Disable-AzureRmRecoveryServicesBackupProtection -item $item -RemoveRecoveryPoints -Force
    }
}



------------------------------------------------------------------------
 Connect-AzAccount -Tenant "YourTenantID" -Subscription "Yoursubscription"

$Vault = Get-AzRecoveryServicesVault -Name “YourVaultName” -ResourceGroupName “VaultResourcegroup”

 Set-AzRecoveryServicesVaultContext -Vault $vault

$bkpItem = Get-AzRecoveryServicesBackupItem -BackupManagementType AzureWorkload -WorkloadType MSSQL -VaultId $Vault.ID | Where-Object {$_.ServerName -eq "VMName" -and $_.ParentName -eq "InstanceorAGName"}

  foreach($item in $bkpitem)

{

   $DBItem = Get-AzRecoveryServicesBackupItem -WorkloadType MSSQL -BackupManagementType AzureWorkload -Name $item.Name

 Disable-AzRecoveryServicesBackupProtection -Item $DBItem -RemoveRecoveryPoints -Force

 }

------------------------------------------------------------------------------

Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings "true"
 
## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 
## Disable soft delete for the Azure Backup Recovery Services vault
 
Set-AzRecoveryServicesVaultProperty -Vault $vault.ID -SoftDeleteFeatureState Disable
 
Write-Host ($writeEmptyLine + " # Soft delete disabled for Recovery Service vault " + $vault.Name + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine
 
## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 
## Check if there are backup items in a soft-deleted state and reverse the delete operation
 
$containerSoftDelete = Get-AzRecoveryServicesBackupItem -BackupManagementType AzureVM -WorkloadType AzureVM -VaultId $vault.ID | Where-Object {$_.DeleteState -eq "ToBeDeleted"}
 
foreach ($item in $containerSoftDelete) {
    Undo-AzRecoveryServicesBackupItemDeletion -Item $item -VaultId $vault.ID -Force -Verbose
}
 
Write-Host ($writeEmptyLine + "# Undeleted all backup items in a soft deleted state in Recovery Services vault " + $vault.Name + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine
 
## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 
## Stop protection and delete data for all backup-protected items
 
$containerBackup = Get-AzRecoveryServicesBackupItem -BackupManagementType AzureVM -WorkloadType AzureVM -VaultId $vault.ID | Where-Object {$_.DeleteState -eq "NotDeleted"}
 
foreach ($item in $containerBackup) {
    Disable-AzRecoveryServicesBackupProtection -Item $item -VaultId $vault.ID -RemoveRecoveryPoints -Force -Verbose
}
 
Write-Host ($writeEmptyLine + "# Deleted backup date for all cloud protected items in Recovery Services vault " + $vault.Name + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine
 
## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 
## Delete the Recovery Services vault
 
Remove-AzRecoveryServicesVault -Vault $vault -Verbose
 
Write-Host ($writeEmptyLine + "# Recovery Services vault " + $vault.Name + " deleted" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine
 
## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 
## Delete the resource groups holding the Recovery Services vault and the one used for the instant recovery and this without confirmation
 
Get-AzResourceGroup -Name $rgBackup | Remove-AzResourceGroup -Force -Verbose
Get-AzResourceGroup -Name $rgBackupInstanRecovery | Remove-AzResourceGroup -Force -Verbose
 
Write-Host ($writeEmptyLine + "# Resource groups " + $vault.ResourceGroupName + " and " + $rgBackupInstanRecovery + " deleted" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor2 $writeEmptyLine
 
## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
 
## Write script completed
 
Write-Host ($writeEmptyLine + "# Script completed" + $writeSeperatorSpaces + $currentTime)`
-foregroundcolor $foregroundColor1 $writeEmptyLine
 
## ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
