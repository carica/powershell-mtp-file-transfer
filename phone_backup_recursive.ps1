#this is an enhanced version of https://github.com/nosalan/powershell-mtp-file-transfer/blob/master/phone_backup.ps1
#it supports backing up nested folders

$ErrorActionPreference = [string]"Stop"
$DestDirForPhotos = [string]"C:\BACKUP\TELEFON_DCIM_ALL"
# $DestDirForCallRecordings = [string]"C:\BACKUP\TELEFON_CALL_RECORDINGS_ALL"
# $DestDirForVoiceRecordings = [string]"C:\BACKUP\TELEFON_VOICE_RECORDINGS_ALL"
# $DestDirForWhatsApp = [string]"C:\BACKUP\TELEFON_WHATSAPP_ALL"
# $DestDirForViber = [string]"C:\BACKUP\TELEFON_VIBER_ALL"
$Summary = [Hashtable]@{NewFilesCount=0; ExistingFilesCount=0}

function New-Dir($path)
{
  if(! (Test-Path -Path $path))
  {
    Write-Host "Creating: $path"
    New-Item -Path $path -ItemType Directory
  }
  else
  {
    Write-Host "Path $path already exist"
  }
}


function Get-SubFolder($params)
{
  $result = $params[0]
  $subPath = $params[1]
  foreach($pathSegment in ($subPath -split "\\"))
  {
    $result = $result.GetFolder.Items() | Where-Object {$_.Name -eq $pathSegment} | Select-Object -First 1
    if($null -eq $result)
    {
      throw "Not found $subPath folder"
    }
  }
  return $result
}


function Get-PhoneMainDir($phoneName)
{
  $o = New-Object -com Shell.Application
  $rootComputerDirectory = $o.NameSpace(0x11)
  $phoneDirectory = $rootComputerDirectory.Items() | Where-Object {$_.Name -eq $phoneName} | Select-Object -First 1
    
  if($null -eq $phoneDirectory)
  {
    throw "Not found '$phoneName' folder in This computer. Connect your phone."
  }
  
  return $phoneDirectory
}


function Get-FullPathOfMtpDir($mtpDir)
{
 $fullDirPath = ""
 $directory = $mtpDir.GetFolder
 while($null -ne $directory)
 {
   $fullDirPath =  -join($directory.Title, '\', $fullDirPath)
   $directory = $directory.ParentFolder;
 }
 return $fullDirPath
}



function Copy-FromPhoneSource-ToBackup($sourceMtpDir, $destDirPath)
{
 New-Dir $destDirPath
 $destDirShell = (New-Object -com Shell.Application).NameSpace($destDirPath)
 $fullSourceDirPath = Get-FullPathOfMtpDir $sourceMtpDir

 
 Write-Host "Copying from: '" $fullSourceDirPath "' to '" $destDirPath "'"
 
 $copiedCount, $existingCount = 0
 
 foreach ($item in $sourceMtpDir.GetFolder.Items())
  {
   $itemName = ($item.Name)
   $fullFilePath = Join-Path -Path $destDirPath -ChildPath $itemName

   if($item.IsFolder)
   {
      Write-Host $item.Name " is folder, stepping into"
      Copy-FromPhoneSource-ToBackup  $item (Join-Path $destDirPath $item.GetFolder.Title)
   }
   elseif(Test-Path $fullFilePath)
   {
      Write-Host "Element '$itemName' already exists"
      $existingCount++;
   }
   else
   {
     $copiedCount++;
     Write-Host ("Copying #{0}: {1}{2}" -f $copiedCount, $fullSourceDirPath, $item.Name)
     $destDirShell.CopyHere($item)
   }
  }
  $script:Summary.NewFilesCount += $copiedCount 
  $script:Summary.ExistingFilesCount += $existingCount 
  Write-Host "Copied '$copiedCount' elements from '$fullSourceDirPath'"
}


$emojiIcon = [System.Convert]::ToInt32("1f423", 16) #🐣
$phoneName = [System.Char]::ConvertFromUtf32($emojiIcon)
$phoneRootDir = Get-PhoneMainDir $phoneName

$internalStorageName = [System.Char]::ConvertFromUtf32([System.Convert]::ToInt32("5185", 16)) + #内
                        [System.Char]::ConvertFromUtf32([System.Convert]::ToInt32("90e8", 16)) + #部
                        [System.Char]::ConvertFromUtf32([System.Convert]::ToInt32("5b58", 16)) + #存
                        [System.Char]::ConvertFromUtf32([System.Convert]::ToInt32("50a8", 16)) #储
# Copy-FromPhoneSource-ToBackup (Get-SubFolder $phoneRootDir "Phone\ACRCalls") $DestDirForCallRecordings
# Copy-FromPhoneSource-ToBackup (Get-SubFolder $phoneRootDir "Phone\VoiceRecorder") $DestDirForVoiceRecordings
# Copy-FromPhoneSource-ToBackup (Get-SubFolder $phoneRootDir "Phone\WhatsApp") $DestDirForWhatsApp
Copy-FromPhoneSource-ToBackup (Get-SubFolder ($phoneRootDir, ($internalStorageName + "\DCIM\Camera"))) $DestDirForPhotos
# Copy-FromPhoneSource-ToBackup (Get-SubFolder $phoneRootDir "Phone\viber") $DestDirForViber
Copy-FromPhoneSource-ToBackup (Get-SubFolder ($phoneRootDir, ($internalStorageName + "\Pictures\WeiXin"))) $DestDirForPhotos

write-host ($Summary | out-string)