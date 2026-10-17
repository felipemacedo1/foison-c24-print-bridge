$ErrorActionPreference='Stop'
$root=Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$version=[IO.File]::ReadAllText((Join-Path $root 'VERSION')).Trim()
$zip=Join-Path $root ('dist/'+$version+'/FoisonC24-v'+$version+'-Win7-x64.zip')
$out=Join-Path $env:TEMP ('foison-shell-zip-'+[Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory $out|Out-Null
$shell=New-Object -ComObject Shell.Application
$source=$shell.NameSpace($zip);$target=$shell.NameSpace($out)
if(-not $source -or -not $target) {throw 'Native Shell ZIP namespace unavailable'}
$target.CopyHere($source.Items(),1556)
$deadline=[DateTime]::UtcNow.AddMinutes(5)
$folder=Join-Path $out ('FoisonC24-v'+$version+'-Win7-x64')
$sums=Join-Path $folder 'SHA256SUMS.txt'
$verified=$false
while([DateTime]::UtcNow -lt $deadline) {
  try {
    if(Test-Path $sums) {
      foreach($line in [IO.File]::ReadAllLines($sums)) {
        if($line -notmatch '^([a-f0-9]{64})  ([A-Za-z0-9_.-]+)$') {throw 'Invalid checksum manifest'}
        $expected=$matches[1];$file=Join-Path $folder $matches[2]
        if((Get-FileHash $file -Algorithm SHA256).Hash.ToLowerInvariant() -ne $expected) {throw 'Not fully extracted or hash mismatch'}
      }
      $verified=$true;break
    }
  } catch { }
  Start-Sleep -Milliseconds 500
}
if(-not $verified) {throw 'Native extraction/hash validation did not complete within 5min'}
Write-Host "PASS native Shell.Application ZIP extraction + all payload hashes on Windows 2022 (NOT Win7). $out"
