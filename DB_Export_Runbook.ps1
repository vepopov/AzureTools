$cred = Get-AutomationPSCredential –Name "your_AD_account_name"
Add-AzureAccount -Credential $cred
# The name of the server on which the source database resides.
$ServerName = "your_source_server_name"

# The name of the source database (the database to copy). 
$DatabaseName = "your_source_db_name" 

# The name of the server that hosts the target database. This server must be in the same Azure subscription as the source database server. 
$PartnerServerName = "your_dest_server_name"

# The name of the target database (the name of the copy).
$PartnerDatabaseName = "your_temp_dest_db_name"

$currentDate = Get-Date
$BlobName = "your_desired_prefix_" + $currentDate.Year + "_" + $currentDate.Month + "_" + $currentDate.Day + "_" + $currentDate.Hour + "_" + $currentDate.Minute + "_" + $currentDate.Second  +  ".bacpac"
	
$StorageName = "your_storage_name"
$ContainerName = "your_storage_container_name"
$StorageKey = "your_storage_key"
	
Start-AzureSqlDatabaseCopy -ServerName $ServerName -DatabaseName $DatabaseName -PartnerDatabase $PartnerDatabaseName
Write-Output ""
$i = 0
$secs = 0
do
{
    $check = Get-AzureSqlDatabaseCopy -ServerName $ServerName -DatabaseName $DatabaseName -PartnerDatabase $PartnerDatabaseName
	
    $i = $check.PercentComplete
    Write-Output "Database Copy ($PartnerDatabaseName) not complete in $secs seconds..."
    
	$secs += 10
    Start-Sleep -s 10
}
while($i -ne $null)

$azpwd = ConvertTo-SecureString 'your_db_password' -AsPlainText -Force;
$dbcred = New-Object System.Management.Automation.PSCredential -ArgumentList 'your_db_admin_name', $azpwd

$SqlCtx = New-AzureSqlDatabaseServerContext -ServerName $ServerName -Credential $dbcred

$StorageCtx = New-AzureStorageContext -StorageAccountName $StorageName -StorageAccountKey $StorageKey
$Container = Get-AzureStorageContainer -Name $ContainerName -Context $StorageCtx

$exportRequest = Start-AzureSqlDatabaseExport -SqlConnectionContext $SqlCtx -StorageContainer $Container -DatabaseName $PartnerDatabaseName -BlobName $BlobName
$exportStatus = Get-AzureSqlDatabaseImportExportStatus -Request $exportRequest

Write-Output ""
$secs = 0
do
{
	write-output "Exporting the database copy not complete in $secs seconds..."
	$secs += 20
	Start-Sleep -s 20
	$exportStatus = Get-AzureSqlDatabaseImportExportStatus -Request $exportRequest
} while ($exportStatus.Status -ne "completed")

Write-Output ""
Write-Output "Removing database $PartnerDatabaseName ..."
Remove-AzureSqlDatabase -ServerName $ServerName -DatabaseName $PartnerDatabaseName -Force
Write-Output ""
Write-Output "Job completed!"