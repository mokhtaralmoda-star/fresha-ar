$ErrorActionPreference='Continue'
$root='C:\Users\user\projects\fresha-ar'
$log=Join-Path $root '_fill.log'
function L($m){ ((Get-Date).ToString('HH:mm:ss')+'  '+$m) | Out-File $log -Append -Encoding UTF8 }
$ua='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36'

$job = {
  param($cf,$root,$ua,$log)
  function L($m){ ((Get-Date).ToString('HH:mm:ss')+'  '+$m) | Out-File $log -Append -Encoding UTF8 }
  $list = Get-Content $cf -Encoding UTF8
  $ok=0; $bad=0
  foreach($rel0 in $list){
    $rel = $rel0.Trim() -replace '&#x27;',"'" -replace '&amp;','&'
    if(-not $rel){ continue }
    $dest = Join-Path $root (($rel.TrimStart('/') -replace '/','\') + '\index.html')
    if((Test-Path $dest) -and ((Get-Item $dest).Length -gt 5000)){ $ok++; continue }
    $dir = Split-Path $dest -Parent
    if(-not (Test-Path $dir)){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    $url = 'https://www.fresha.com' + $rel
    $done = $false
    for($k=1; $k -le 3; $k++){
      try{
        $wc = New-Object System.Net.WebClient
        $wc.Headers.Add('User-Agent',$ua)
        $wc.Headers.Add('Referer','https://www.fresha.com/ar')
        $wc.DownloadFile($url,$dest); $wc.Dispose()
        if((Get-Item $dest).Length -gt 5000){ $done = $true; break }
      } catch { Start-Sleep -Seconds (2*$k) }
    }
    if($done){ $ok++ } else { $bad++; if(Test-Path $dest){ Remove-Item $dest -Force -EA 0 } }
    Start-Sleep -Milliseconds 80
  }
  L "worker done ok=$ok bad=$bad"
  "$ok $bad"
}

$jobs = @()
for($i=0; $i -lt 5; $i++){ $jobs += Start-Job -ScriptBlock $job -ArgumentList (Join-Path $root ("_chunk_{0}.txt" -f $i)),$root,$ua,$log }
L 'started 5 workers'
$jobs | Wait-Job | Out-Null
$jobs | ForEach-Object { Receive-Job $_ }
$jobs | Remove-Job
L 'all done'
