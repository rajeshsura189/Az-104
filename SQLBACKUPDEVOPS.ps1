function sqlbackup{

Param(
    [Parameter(Mandatory)]
    [string] $DatabaseVmName,

    [Parameter(Mandatory)]
    [string] $DatabaseVmNameRG,

    [Parameter(Mandatory)]
    [string] $RecoveryServicesVault,

    [Parameter(Mandatory)]
    [string] $RecoveryServicesVaultRG,

    [Parameter(Mandatory)]
    [string] $SQLDataBaseBackupPolicy
)

try {
# Fetch the Vault Details
Get-AzRecoveryServicesVault -Name "$RecoveryServicesVault" | Set-AzRecoveryServicesVaultContext
Write-Host "------------------------------------------------------------------------------"

# Fetch Vault ID
$RecoveryVaultID = Get-AzRecoveryServicesVault -ResourceGroupName "$RecoveryServicesVaultRG" -Name "$RecoveryServicesVault" | select -ExpandProperty ID
Write-Host "* RecoveryVaultID : "$RecoveryVaultID
Write-Host "------------------------------------------------------------------------------"

# Fetch Vault Location
# $RecoveryVaultLocation = Get-AzRecoveryServicesVault -ResourceGroupName "rg-aa02-bu-ause" -Name "$RecoveryServicesVault" | select -ExpandProperty Location
# Write-Host "RecoveryVaultLocation : "$RecoveryVaultLocation

# Fetch VM Details
Write-Host "* Fetch VM Details"
$DatabaseVM = Get-AzVM -ResourceGroupName $DatabaseVmNameRG -Name $DatabaseVmName

# Fetch VM ID
Write-Host "* Fetched Database VM ID : "$DatabaseVM.ID
Write-Host "------------------------------------------------------------------------------"

##############################################
# Registering the service
Write-Host "* Registering the SQL service of the VM to Azure Backup"
Write-Host "------------------------------------------------------------------------------"

Register-AzRecoveryServicesBackupContainer -ResourceId $DatabaseVM.ID -BackupManagementType AzureWorkload -WorkloadType MSSQL -VaultId $RecoveryVaultID -Force
###############################################

# Fetching the Backup Policy Details
Write-Host "* Fetching the Backup Policy Details"
Write-Host "------------------------------------------------------------------------------"
$BackupPolicy = Get-AzRecoveryServicesBackupProtectionPolicy -Name "$SQLDataBaseBackupPolicy"
Write-Host "* BackupPolicy Details : "$BackupPolicy
Write-Host "------------------------------------------------------------------------------"

# Fetching the DB's
Write-Host "* Discovering all the Database's of the server"
Write-Host "------------------------------------------------------------------------------"

# Discover all the DB's on the VM
$DiscoveredSQLDB = Get-AzRecoveryServicesBackupProtectableItem -workloadType MSSQL -ItemType SQLDataBase -VaultId $RecoveryVaultID -ServerName "$DatabaseVmName.jdadelivers.com"
Write-Host "* Discovered Database Names : "$DiscoveredSQLDB.Name
Write-Host "------------------------------------------------------------------------------"

# Assigning the DB Names to a Variable to Loop
$Alldbnames = $DiscoveredSQLDB.Name
if($Alldbnames -eq $null){
    Write-Host "** No Database's Found on Server to Discover **"
	# Calling EnableAutoProtect Function
	EnableAutoProtect -DatabaseVmName $DatabaseVmName -RecoveryVaultID $RecoveryVaultID -SQLDataBaseBackupPolicy $SQLDataBaseBackupPolicy
	exit
}

# Enabling the Backup for a particular DB on the VM
Write-Host "* Enabling the Backup for all the DB's on the SQL VM"
Write-Host "------------------------------------------------------------------------------"
$count = 1
foreach ($dbname in $Alldbnames.Split(" "))
{
    Write-Host "------------------------------------------------------------------------------"
	Write-Host "Backing up DatabaseName $count - $dbname"
	Write-Host "------------------------------------------------------------------------------"
    $BackupDBDetails = Get-AzRecoveryServicesBackupProtectableItem -workloadType MSSQL -ItemType SQLDataBase -VaultId $RecoveryVaultID -Name "$dbname" -ServerName "$DatabaseVmName.jdadelivers.com"
    $count++
    try {
    Enable-AzRecoveryServicesBackupProtection -ProtectableItem $BackupDBDetails -Policy $BackupPolicy
        }
   catch { 
        $er = $_.Exception
		$ermsg = $er.Message 
		Write-Host "--------------------------------------------------------------"
		Write-Host "CATCH BLOCK MESSAGE : "$ermsg
		Write-Host "--------------------------------------------------------------"
		
		if ($ermsg -like "*Azure Backup service is not able to connect to the SQL instance.*") {
			Write-Host "------------------------------------------------------------------------------"
			Write-Host "* Running the invoke command to add the missing service account into the SQL Server"
			Write-Host "------------------------------------------------------------------------------"
			
			#####################################################################
			# Invoking the Add_SysAdmin_NT_SERVICE Script on the DB server
			#####################################################################
			Write-Host "Running Invoke command to Add_SysAdmin_NT_SERVICE Script on the DB server"
			Write-Host "------------------------------------------------------------------------------"
			
            $sql_user = 'jdadelivers\_MGMT_PRD_SQL_APP';
            $sql_password = (Get-AzKeyVaultSecret -VaultName $VaultName -Name 'SQLApp' -ErrorAction Stop).SecretValueText

            $cmd = "& Invoke-AzVMRunCommand -ResourceGroupName '$DatabaseVmNameRG' -Name '$DatabaseVmName' -CommandId 'RunPowerShellScript' -ScriptPath '$here\Add_sql_NT_service.ps1' -Parameter @{'sqlserver' = '$DatabaseVmName'; 'sql_user' = '$sql_user'; 'sql_password' = '$sql_password' }";
            echo $cmd
            $tmp = Invoke-Expression $cmd
            echo "Invoke Response of Add_sql_NT_service" $tmp
		
			Write-Host "Sleeping for 1 min"
			Write-Host "------------------------------------------------------------------------------"
			start-sleep -seconds 60
			
			Write-Host "------------------------------------------------------------------------------"
			Write-Host "Unregistering the SQL Server"
			Write-Host "------------------------------------------------------------------------------"
			$RSQLContainer = Get-AzRecoveryServicesBackupContainer -ContainerType AzureVMAppContainer -FriendlyName $DatabaseVmName -VaultId $RecoveryVaultID
			Unregister-AzRecoveryServicesBackupContainer -Container $RSQLContainer -VaultId $RecoveryVaultID
			
            Write-Host "------------------------------------------------------------------------------"
            Write-Host "Sleeping for 5 min"
			Write-Host "------------------------------------------------------------------------------"
			start-sleep -seconds 180
		
		    Write-Host "* calling Function SQL BACKUP FUNCTION to Configure Backup"
        
		    Write-Host "------------------------------------------------------------------------------"
		    sqlbackup -DatabaseVmName $DatabaseVmName -DatabaseVmNameRG $DatabaseVmNameRG -RecoveryServicesVault $RecoveryServicesVault -RecoveryServicesVaultRG $RecoveryServicesVaultRG -SQLDataBaseBackupPolicy $SQLDataBaseBackupPolicy
		
			#########################################################
            }
        }
}
# Calling EnableAutoProtect Function
EnableAutoProtect -DatabaseVmName $DatabaseVmName -RecoveryVaultID $RecoveryVaultID -SQLDataBaseBackupPolicy $SQLDataBaseBackupPolicy
}
catch {
    $e = $_.Exception
    $emsg = $e.Message 
	Write-Host "--------------------------------------------------------------"
    Write-Host "CATCH BLOCK MESSAGE : "$emsg
    Write-Host "--------------------------------------------------------------"
    if ($emsg -like "*The specified workload is already registered in the given resource ID*") {
        Write-Host "------------------------------------------------------------------------------"
        Write-Host "* The Server/Node is already registered to the the Recovery Service Vault : $RecoveryServicesVault"
        Write-Host "* calling Function EnableAutoProtect to try Enable Auto Protect"
        Write-Host "------------------------------------------------------------------------------"
        EnableAutoProtect -DatabaseVmName $DatabaseVmName -RecoveryVaultID $RecoveryVaultID -SQLDataBaseBackupPolicy $SQLDataBaseBackupPolicy
    }
	
	
#####################################################
    elseif ($emsg -like "*Visual C++ Redistributable for Visual Studio 2012 Update 4 installation failed on the machine*" -and ($cpperror -eq 0)) {
        Write-Host "------------------------------------------------------------------------------"
		Write-Host "------------------------------------------------------------------------------"
        Write-Host "* The Server/Node has an INTERNAL ERROR ON C++ Sleeping for 15 min and will re-initiate the Backup Again"
        Write-Host "* calling Function SQL BACKUP FUNCTION to Configure Backup"
        Write-Host "------------------------------------------------------------------------------"
		Write-Host "------------------------------------------------------------------------------"
        Write-Host "Waiting for 15 min before we trigger the initial backup"
        Write-Host "------------------------------------------------------------------------------"
		Write-Host "------------------------------------------------------------------------------"
        
        start-sleep -seconds 900
		   
		$cpperror++;
		
		Write-Host "* calling Function SQL BACKUP FUNCTION to Configure Backup"
        Write-Host "------------------------------------------------------------------------------"
		Write-Host "------------------------------------------------------------------------------"
		sqlbackup -DatabaseVmName $DatabaseVmName -DatabaseVmNameRG $DatabaseVmNameRG -RecoveryServicesVault $RecoveryServicesVault -RecoveryServicesVaultRG $RecoveryServicesVaultRG -SQLDataBaseBackupPolicy $SQLDataBaseBackupPolicy
		
    }
    else {
        Write-Host "------------------------------------------------------------------------------"
		Write-Host "------------------------------------------------------------------------------"
        Write-Host "* New Type of error recorded Please check the Logs Manually"
        Write-Host "------------------------------------------------------------------------------"
		Write-Host "------------------------------------------------------------------------------"		
    }
#####################################################		
	
}
}

####################################################################################
# Function EnableAutoProtect
####################################################################################
function EnableAutoProtect{
Param(
    [Parameter(Mandatory)]
    [string] $DatabaseVmName,

    [Parameter(Mandatory)]
    [string] $RecoveryVaultID,

    [Parameter(Mandatory)]
    [string] $SQLDataBaseBackupPolicy
)
try {
# Fetch the SQL Instance & Enable Auto Protection
Write-Host "* Enabling Auto Protection for the SQL Server"
Write-Host "------------------------------------------------------------------------------"
Write-Host "Database Server Name : " $DatabaseVmName
Write-Host "Recovery vault ID : " $RecoveryVaultID
Write-Host "Backup Policy Name : " $SQLDataBaseBackupPolicy

$BackupPolicy1 = Get-AzRecoveryServicesBackupProtectionPolicy -Name "$SQLDataBaseBackupPolicy"
Write-Host "* BackupPolicy Details : "$BackupPolicy1

$SQLInstance = Get-AzRecoveryServicesBackupProtectableItem -workloadType MSSQL -ItemType SQLInstance -VaultId $RecoveryVaultID -ServerName "$DatabaseVmName.jdadelivers.com"
Write-Host "* SQL Instance Details : " $SQLInstance

Enable-AzRecoveryServicesBackupAutoProtection -InputItem $SQLInstance -BackupManagementType AzureWorkload -WorkloadType MSSQL -Policy $BackupPolicy1 -VaultId $RecoveryVaultID

# Enable AG AutoProtect
    Write-Host "------------------------------------------------------------------------------"
    Write-Host "** Checking for Availability Group Cluster **"
    Write-Host "------------------------------------------------------------------------------"

$AgSQLInstance = Get-AzRecoveryServicesBackupProtectableItem -workloadType MSSQL -ItemType SQLAvailabilityGroup -VaultId $RecoveryVaultID
Write-Host "* AG SQL Instance Details : " $AgSQLInstance

if ($AgSQLInstance -eq $null){
    Write-Host "------------------------------------------------------------------------------"
    Write-Host "** No Availability Group Cluster Found to Enable Auto Protect **"
    Write-Host "------------------------------------------------------------------------------"
    }
else {
    Write-Host "------------------------------------------------------------------------------"
    Write-Host "** Availability Group Cluster Found Enabling the Auto Protect **"
    Write-Host "------------------------------------------------------------------------------"
    Enable-AzRecoveryServicesBackupAutoProtection -InputItem $AgSQLInstance -BackupManagementType AzureWorkload -WorkloadType MSSQL -Policy $BackupPolicy1 -VaultId $RecoveryVaultID
}

}
catch {
    $_.Exception
    }
}

####################################################################################
# Function TriggerInitialBackup
####################################################################################
function TriggerInitialBackup{
Param(

    [Parameter(Mandatory)]
    [string] $RecoveryServicesVault,

    [Parameter(Mandatory)]
    [string] $RecoveryServicesVaultRG
)

try {
	# Fetch the Vault Details
	Get-AzRecoveryServicesVault -Name "$RecoveryServicesVault" | Set-AzRecoveryServicesVaultContext
	
    Write-Host "-------------------------------------------------------------------------------------------------------"
    Write-Host "** CHECKING & TRIGGERING THE INITIAL BACKUP ON THE DATABASE's WHICH WAS NEWLY ADDED INTO BACKUP POLICY **"
    Write-Host "-------------------------------------------------------------------------------------------------------"

	# Fetch Vault ID
	$RecoveryVaultID = Get-AzRecoveryServicesVault -ResourceGroupName "$RecoveryServicesVaultRG" -Name "$RecoveryServicesVault" | select -ExpandProperty ID
	Write-Host "* RecoveryVaultID : "$RecoveryVaultID
	Write-Host "------------------------------------------------------------------------------"

	$fetchbkp = Get-AzRecoveryServicesBackupItem -BackupManagementType AzureWorkload -WorkloadType MSSQL -VaultId $RecoveryVaultID -ProtectionState IRPending
	$endDate = (Get-Date).AddDays(7).ToUniversalTime()
	foreach ($eachbkpitem in $fetchbkp){
		Backup-AzRecoveryServicesBackupItem -Item $eachbkpitem -BackupType Full -EnableCompression -VaultId $RecoveryVaultID -ExpiryDateTimeUTC $endDate
	}
}
catch {
    $_.Exception
}
}

$requests = Get-Requests -ConnectionString $ConnectionString -rid $rid -gmsarequest True
$requests
foreach ($request in $requests) {
    $ProductCode = $($request.ProductIds).PadLeft(2,"0");
    $CustomerCode = $request.CUSTOMERABBR
    $productGroup = $request.ProductAbbr
    $EnvironmentCode = $request.ENVNOMENCLATURE
    $gMSAAccountName = $CustomerCode + $EnvironmentCode + $ProductCode + '$';
    $rg = $request.CustomerRG;
    $cust_name = $request.CustomerName;
    $cust_name = '"' + $cust_name + '"'
    echo $cust_name
    $customerName = $request.CustomerName
    $TierCode = $($request.TierAbbr).PadLeft(2,"0")
    $vmPrefix = "$($request.envnomenclature)$($Request.CustomerAbbr)$ProductCode$TierCode";
    $ServerIndex = [int]$request.ServerStartingNumber;

$dbtiers = @("03","12","16")
        if (-not($dbtiers.contains($TierCode))) {
            Write-Output "Ignoring the TierCode: $TierCode";
            continue;
        }

    $listOflocations = @{
                "eastus2"   = "eus2";
                "centralus" = "cus";
                "eastus"    = "eus";
                "westus"    = "wus";
                "westeurope" = "euw";
                "northeurope" = "eun";
                "australiaeast" = "aue";
                "australiasoutheast" = "ause";
                "eastasia" = "ae";
                "southeastasia" = "ase";
            }

$env=@{
	"pr" = "prod";
	"ts" = "nprd";
	"dv" = "nprd";
	"dm" = "nprd";
	"tr" = "nprd";
	"sh" = "nprd";
	"qa" = "nprd";
	"tl" = "nprd";
	"pc" = "nprd";
	"pt" = "nprd";
	"ua" = "nprd";
	"sb" = "nprd";

}

$p=$env[$request.envnomenclature]; 
    echo $request.Location
    $number=1
    $envSet = "{0:D2}" -f $number
    $locAbbr = $listOflocations[$request.Location];       
    $a = 0 
    $RecoveryVaultName = "rsv-$($request.CustomerAbbr)-$locAbbr-$envSet"
    $RecoveryVaultResourceGroup = "rg-$($request.CustomerAbbr)-bu-$locAbbr"  
    $SQLDataBaseBackupPolicy = "pol-$($request.CustomerAbbr)-$p-sql-$locAbbr-01"
   
    $always_on_first_node = $true;

    while($a -lt $request.VmCount)
        {
        $ServerNumber = [string]$ServerIndex;
        $ServerNumber = $ServerNumber.PadLeft(3,"0");
        $Server = "$vmPrefix$ServerNumber"

        if($TierCode -eq 16){
			if($always_on_first_node){
				$ServerNumber = [string]$ServerIndex;
				$ServerNumber = $ServerNumber.PadLeft(3,"0");
				$Server = "$vmPrefix$ServerNumber"+"n1"
                $always_on_first_node=$false
			} else {
				$tmp = $ServerIndex - 1;
				$ServerNumber = [string]$tmp;
				$ServerNumber = $ServerNumber.PadLeft(3,"0");
				$Server = "$vmPrefix$ServerNumber"+"n2"
			}
		}
        
        Write-Host "------------------------------------------------------------------------------"
        Write-Host "Tier ID : "$TierCode
        Write-Host "Request ID : " $rid
        Write-Host "DB Server Name : " $Server
        Write-Host "Server RG Name : " $rg
        Write-Host "Recovery Vault Name : "$RecoveryVaultName
        Write-Host "Recovery Vault RG Name : "$RecoveryVaultResourceGroup
        Write-Host "BackupPolicy Name : "$SQLDataBaseBackupPolicy

<#

        #####################################################################
        # Invoking the Add_SysAdmin_NT_SERVICE Script on the DB server
        #####################################################################
	    Write-Host "Running Invoke command to Add_SysAdmin_NT_SERVICE Script on the DB server"
	    Write-Host "------------------------------------------------------------------------------"

	    $cmd = "& Invoke-AzVMRunCommand -ResourceGroupName '$rg' -Name '$Server' -CommandId 'RunPowerShellScript' -ScriptPath '$here\Add_SysAdmin_NT_SERVICE.ps1' -AsJob";
	
	    echo $cmd
	    $tmp = Invoke-Expression $cmd
	    echo "Invoke Response of Add_SysAdmin_NT_SERVICE script" $tmp
	
	    Write-Host "Waiting for 2 min before we trigger the SQL backup"
	    Write-Host "------------------------------------------------------------------------------"
	    start-sleep -seconds 120
        #########################################################

#>


        # calling the SQLBackup Function
        Write-Host "Calling SQL Backup Function"
        Write-Host "------------------------------------------------------------------------------"
        sqlbackup -DatabaseVmName $Server -DatabaseVmNameRG $rg -RecoveryServicesVault $RecoveryVaultName -RecoveryServicesVaultRG $RecoveryVaultResourceGroup -SQLDataBaseBackupPolicy $SQLDataBaseBackupPolicy
        
        Write-Host "Waiting for 1 min before we trigger the initial backup"
        Write-Host "------------------------------------------------------------------------------"
        
        start-sleep -seconds 60

        Write-Host "Calling TriggerInitialBackup Function"
        Write-Host "------------------------------------------------------------------------------"
        TriggerInitialBackup -RecoveryServicesVault $RecoveryVaultName -RecoveryServicesVaultRG $RecoveryVaultResourceGroup

        $ServerIndex++;
        $a++;
        }
}