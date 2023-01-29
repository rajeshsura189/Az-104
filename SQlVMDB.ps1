Connect-AzAccount
Set-AzContext -Subscription sub-by-cld-solutions-eus2-02
# Set the CSV input file path
$inputFilePath = "C:\Users\LENOVO\Downloads\test1.csv"

# Set the CSV output file path
$outputFilePath = "C:\Users\LENOVO\Downloads\output.csv"

# Read the input from the CSV file
$master = Import-Csv -Path "C:\Users\LENOVO\Downloads\test1.csv"

# Create an empty array to store the output
$output = @()
# Loop through each row in the CSV file
foreach ($row in $master) {
    # Set the SQL VM name, database name, availability group name, backup policy name, and backup vault name
    $sqlVmName = $row.SQLVmName
    $databaseName = $row.Database
    $backupVaultName = $row.BackupVault
    $backupPolicyName = $row.BackupPolicy
    $resourceGroupName = $row.resourceGroupName
# Get the backup vault context
    $backupVault = Get-AzRecoveryServicesVault -Name $backupVaultName -ResourceGroupName $resourceGroupName
    Set-AzRecoveryServicesVaultContext -Vault $backupVault
   
try {
# Assign the backup policy to the SQL VM
$pols = Get-AzRecoveryServicesBackupProtectionPolicy -VaultId $backupVault.ID -WorkloadType MSSQL -BackupManagementType AzureWorkload | ?{$_.Name -eq "$backupPolicyName"}
$targetPolicy = Get-AzRecoveryServicesBackupProtectionPolicy -VaultId $backupVault.ID -Name $backupPolicyName
$containers = Get-AzRecoveryServicesBackupContainer -VaultId $backupVault.ID -ContainerType AzureVMAppContainer -BackupManagementType AzureWorkload -FriendlyName $sqlVmName
#$DiscoveredSQLDB = Get-AzRecoveryServicesBackupProtectableItem -workloadType MSSQL -ItemType SQLDataBase -VaultId $backupVault.ID -ServerName "$sqlVmName.jdadelivers.com"
foreach($container in $containers){
$bkpItems = Get-AzRecoveryServicesBackupItem -WorkloadType MSSQL -VaultId $backupVault.ID -Container $container | ?{$_.Name -eq "SQLDataBase;mssqlserver;$databaseName"}
foreach($bkpItem in $bkpItems) {
Enable-AzRecoveryServicesBackupProtection -Item $bkpItem -Policy $targetPolicy -VaultId $backupVault.ID
Backup-AzRecoveryServicesBackupItem -Item $bkpItem
}
}
# Add the result to the output array
        $output += New-Object PSObject -Property @{
            SQLVmName = $sqlVmName
            Database = $databaseName
            BackupPolicy = $backupPolicyName
            BackupVault = $backupVaultName
            Result = "Success"
        }
} catch {
        # Add the result to the output array
        $output += New-Object PSObject -Property @{
            SQLVmName = $sqlVmName
            Database = $databaseName
            BackupPolicy = $backupPolicyName
            BackupVault = $backupVaultName
            Result = "Failed"
            ErrorCode = $_.Exception.ErrorCode
        }
    }
}


# Export the output to a CSV file
$output | Export-Csv -Path $outputFilePath -NoTypeInformation

     