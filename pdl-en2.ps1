param([int]$Throttle=10,[int]$Delay=250)
$ErrorActionPreference='Continue'
$Repo='C:\Users\user\projects\fresha-ar'
$UA='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36'
$QueueFile = Join-Path $Repo '_data\queue_en2.txt'
$Queue = @(Get-Content $QueueFile -Encoding UTF8 | Where-Object { $_ -match '^/' } | Select-Object -Unique)
Write-Host "في الطابور: $($Queue.Count)"
if($Queue.Count -eq 0){ exit 0 }
$Idx = [hashtable]::Synchronized(@{ v = 0 })
$C   = [hashtable]::Synchronized(@{ ok = 0; err = 0; n = 0 })
$Bag = [System.Collections.Concurrent.ConcurrentBag[string]]::new()
$pool = [runspacefactory]::CreateRunspacePool(1, $Throttle)
$pool.Open()
$jobs = @()
$sb = {
  param($Repo,$UA,$Queue,$Idx,$C,$Bag,$Delay)
  while($true){
    $i = [int]$Idx['v']
    if($i -ge $Queue.Count){ break }
    $Idx['v'] = $i + 1
    $rel = $Queue[$i]
    $dir = Join-Path $Repo ((($rel -replace '^/','') -replace '/','\'))
    $file = Join-Path $dir 'index.html'
    if(Test-Path -LiteralPath $file){ continue }
    if(-not (Test-Path -LiteralPath $dir)){ New-Item -ItemType Directory -Force $dir | Out-Null }
    $url = 'https://www.fresha.com' + $rel
    if($url -match '[^\x00-\x7F]'){ $url = ([uri]$url).AbsoluteUri }
    $done = $false
    for($t=1; $t -le 3 -and -not $done; $t++){
      try{
        $r = Invoke-WebRequest -Uri $url -UserAgent $UA -TimeoutSec 45 -UseBasicParsing -Headers @{ 'Accept-Language'='en' } -ErrorAction Stop
        if($r.StatusCode -eq 200 -and $r.Content.Length -gt 5000){
          [IO.File]::WriteAllText($file, $r.Content, [Text.Encoding]::UTF8)
          $done = $true
        } else { Start-Sleep -Milliseconds 300 }
      } catch { Start-Sleep -Milliseconds (600*$t) }
    }
    if($done){ $C.ok++ } else { $C.err++; $Bag.Add($rel) }
    $C.n++
    if($C.n % 200 -eq 0){ Write-Host "DL $($C.n) ok=$($C.ok) err=$($C.err)" }
    Start-Sleep -Milliseconds $Delay
  }
}
for($k=0; $k -lt $Throttle; $k++){
  $ps = [powershell]::Create()
  $ps.RunspacePool = $pool
  [void]$ps.AddScript($sb).AddArgument($Repo).AddArgument($UA).AddArgument($Queue).AddArgument($Idx).AddArgument($C).AddArgument($Bag).AddArgument($Delay)
  $jobs += [pscustomobject]@{ P = $ps; H = $ps.BeginInvoke() }
}
foreach($j in $jobs){ $j.P.EndInvoke($j.H); $j.P.Dispose() }
$pool.Close()
Write-Host "خلصت: ok=$($C.ok) err=$($C.err)" -ForegroundColor Cyan


