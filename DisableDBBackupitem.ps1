Connect-AzAccount
Set-AzContext -Subscription sub-jda-cld-solutions-01

$DBName = "empty_Retail2019_2_0_0"
$sqlName = "tsac010403001.jdadelivers.com"
$v = "rsv-ac01-eus2-01"
$vRG = "rg-ac01-bu-eus2"
$VMRG = "rg-ac01-ts-eus2"
$RSV = Get-AzRecoveryServicesVault -ResourceGroupName $vRG -Name $v
Set-AzRecoveryServicesVaultContext -Vault $RSV

#$bkpItem = Get-AzRecoveryServicesBackupItem -BackupManagementType AzureWorkload -WorkloadType MSSQL  | Where-Object {$_.ServerName -eq "VMName" -and $_.ParentName -eq "InstanceorAGName"}
$RSV.ID | Set-AzRecoveryServicesVaultProperty -SoftDeleteFeatureState Disable | Out-Null
$SQLInstance = Get-AzRecoveryServicesBackupProtectableItem -workloadType MSSQL -ItemType SQLInstance -VaultId $RSV.ID -ServerName "$sqlName"
$fetchbkp = Get-AzRecoveryServicesBackupItem -Name $DBName -BackupManagementType AzureWorkload -WorkloadType MSSQL -VaultId $RSV.ID -ProtectionState ProtectionStopped | ?{$_.Name -eq "SQLDataBase;MSSQLSERVER;$DBName"}
if($fetchbkp.ProtectionState -eq 'ProtectionStopped')
{
Disable-AzRecoveryServicesBackupProtection -Item $fetchbkp -RemoveRecoveryPoints -Force -VaultId $RSV.ID
}
exit


$containers = Get-AzRecoveryServicesBackupContainer -ContainerType AzureVMAppContainer -BackupManagementType AzureWorkload -VaultId $RSV.ID | ?{$_.Name -eq "SQLDataBase;MSSQLSERVER;$DBName"}
foreach( $container in $containers)
{
$bitems = Get-AzRecoveryServicesBackupItem -WorkloadType MSSQL -Container $container -ProtectionState ProtectionStopped | Where-Object {$_.Name -eq "$DBName"}
 
}














foreach ($container in $containers){
$items = Get-AzRecoveryServicesBackupItem -Container $container -WorkloadType MSSQL -ProtectionStatus Unhealthy
 foreach ($item in $items)
 {
 Enable-AzRecoveryServicesBackupProtection -Item $item
}
}

Disable-AzRecoveryServicesBackupProtection -Item $item -RemoveRecoveryPoints