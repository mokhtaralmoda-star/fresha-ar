param([int]$Batch=1000)
$ErrorActionPreference='Continue'
$Repo='C:\Users\user\projects\fresha-ar'
$UA='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36'
Set-Location $Repo
$urls = New-Object 'System.Collections.Generic.HashSet[string]'
foreach($f in @('ar_links_ok.txt','ar_lp_links.txt')){
  $p = Join-Path $HOME $f
  if(-not (Test-Path $p)){ continue }
  $t = [IO.File]::ReadAllText($p, [Text.Encoding]::UTF8)
  foreach($m in [regex]::Matches($t, '/lp/ar/bt/[^\s"' + [char]39 + '\\<>]+')){
    $v = $m.Value.TrimEnd('/')
    if($v -match '^/lp/ar/bt/[^/]+/[a-z]{2}-.+$'){ [void]$urls.Add($v) }
  }
}
$all = @($urls)
$todo = New-Object System.Collections.Generic.List[string]
$have = 0
foreach($u in $all){
  $p = Join-Path $Repo ((($u -replace '^/','') -replace '/','\'))
  if(Test-Path (Join-Path $p 'index.html')){ $have++; continue }
  $todo.Add($u)
}
Write-Host "موجود: $have   ناقص: $($todo.Count)"
if($todo.Count -eq 0){ exit 0 }

$ok=0; $err=0; $n=0
foreach($rel in $todo){
  if($n -ge 800){ break }
  $n++
  $dir = Join-Path $Repo ((($rel -replace '^/','') -replace '/','\'))
  if(-not (Test-Path $dir)){ New-Item -ItemType Directory -Force $dir | Out-Null }
  $url = 'https://www.fresha.com' + $rel
  if($url -match '[^\x00-\x7F]'){ $url = ([uri]$url).AbsoluteUri }
  $done=$false
  for($t=1; $t -le 3 -and -not $done; $t++){
    try{
      $r = Invoke-WebRequest -Uri $url -UserAgent $UA -TimeoutSec 45 -UseBasicParsing -Headers @{ 'Accept-Language'='ar' } -ErrorAction Stop
      if($r.StatusCode -eq 200 -and $r.Content.Length -gt 5000 -and $r.Content -match 'lang="ar"'){
        [IO.File]::WriteAllText((Join-Path $dir 'index.html'), $r.Content, [Text.Encoding]::UTF8)
        $done=$true; $ok++
      } else { Start-Sleep -Milliseconds 400 }
    } catch { Start-Sleep -Milliseconds (800*$t) }
  }
  if(-not $done){ $err++ }
  if($n % 50 -eq 0){ Write-Host "DL $n ok=$ok err=$err" }
  Start-Sleep -Milliseconds 300
}
Write-Host "خلصت: ok=$ok err=$err" -ForegroundColor Cyan







