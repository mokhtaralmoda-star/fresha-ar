$ErrorActionPreference = 'Continue'
$root = 'C:\Users\user\projects\fresha-ar'
Set-Location $root
$log = Join-Path $root '_night.log'
function L([string]$m){ ((Get-Date).ToString('HH:mm:ss')+'  '+$m) | Out-File -FilePath $log -Append -Encoding UTF8 }
L '=== start ==='

$ua = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36'
function Get-File([string]$rel,[string]$url){
  $dest = Join-Path $root ($rel.Replace('/','\'))
  $dir = Split-Path $dest -Parent
  if(-not (Test-Path $dir)){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  if((Test-Path $dest) -and ((Get-Item $dest).Length -gt 0)){ return 'skip' }
  for($k=1;$k -le 3;$k++){
    try{
      $wc = New-Object System.Net.WebClient
      $wc.Headers.Add('User-Agent',$ua)
      $wc.Headers.Add('Accept','*/*')
      $wc.Headers.Add('Referer','https://www.fresha.com/ar')
      $wc.DownloadFile($url,$dest); $wc.Dispose()
      if((Test-Path $dest) -and ((Get-Item $dest).Length -gt 0)){ return 'ok' }
    } catch { Start-Sleep -Seconds (2*$k) }
  }
  if(Test-Path $dest){ Remove-Item $dest -Force -EA 0 }
  return 'fail'
}

L 'scan refs'
$u = New-Object System.Collections.Generic.HashSet[string]
$i = 0
Get-ChildItem ar,lp/ar -Recurse -File -Filter *.html -EA 0 | ForEach-Object {
  $v = [IO.File]::ReadAllText($_.FullName)
  foreach($m in [regex]::Matches($v,'/_next/[^"''\\ )]+')){
    $val = $m.Value
    if($val -notlike '/_next/image?*'){ $val = ($val -split '\?')[0] }
    [void]$u.Add($val)
  }
  $i++; if($i % 5000 -eq 0){ L "scan $i" }
}
$u | Set-Content _next_all.txt -Encoding UTF8
L "unique $($u.Count)"

$have = New-Object System.Collections.Generic.HashSet[string]
Get-ChildItem _next -Recurse -File -EA 0 | ForEach-Object { [void]$have.Add('/' + $_.FullName.Replace($root+'\','').Replace('\','/')) }
$miss = @($u | Where-Object { $_ -notlike '/_next/image?*' -and -not $have.Contains($_) })
$miss | Set-Content _next_missing2.txt -Encoding UTF8
L "missing $($miss.Count)"

L 'download next chunks'
$ok=0; $bad=0; $n=0
foreach($p in $miss){
  $n++
  $r = Get-File ($p.TrimStart('/')) ('https://www.fresha.com' + $p)
  if($r -eq 'fail'){ $bad++ } else { $ok++ }
  if($n % 100 -eq 0){ L "dl $n ok=$ok bad=$bad" }
  Start-Sleep -Milliseconds 120
}
L "next done ok=$ok bad=$bad"

L 'restore stripped ar pages'
$badf = New-Object System.Collections.Generic.List[string]
Get-ChildItem ar -Recurse -File -Filter *.html -EA 0 | ForEach-Object { if(-not ([IO.File]::ReadAllText($_.FullName) -match '<script')){ $badf.Add($_.FullName) } }
L "stripped $($badf.Count)"
$n=0; $ok=0; $bad=0
foreach($f in $badf){
  $n++
  $rel = $f.Substring($root.Length+1).Replace('\','/')
  $url = 'https://www.fresha.com/' + ($rel -replace 'index\.html$','')
  $r = Get-File $rel $url
  if($r -eq 'fail'){ $bad++ } else { $ok++ }
  if($n % 50 -eq 0){ L "restore $n ok=$ok bad=$bad" }
  Start-Sleep -Milliseconds 120
}
L "restore done ok=$ok bad=$bad"

L 'git add'
git add -A 2>&1 | Out-Null
git -c commit.gpgsign=false commit -qm "restore scripts + next chunks" 2>&1 | Out-Null
git branch -D clean2 2>&1 | Out-Null
git checkout --orphan clean2 2>&1 | Out-Null
git rm -r --cached . -q 2>&1 | Out-Null

L 'batch push'
$files = @()
$files += Get-ChildItem ar,lp/ar,_next,_icons,_sitemaps -Recurse -File -EA 0
$files += Get-ChildItem . -File -EA 0
$files = $files | Where-Object { $_.Name -ne '_night.log' -and $_.Name -ne '_batch.txt' } | ForEach-Object { $_.FullName.Substring($root.Length+1) }
L "files $($files.Count)"
$enc = New-Object System.Text.UTF8Encoding($false)
$batch = New-Object System.Collections.Generic.List[string]
$sz = 0; $bi = 0
foreach($f in $files){
  $len = (Get-Item -LiteralPath $f -EA 0).Length
  $batch.Add($f); $sz += $len
  if($sz -ge 800MB){
    $bi++
    [IO.File]::WriteAllLines((Join-Path $root '_batch.txt'), $batch, $enc)
    git add --pathspec-from-file=_batch.txt 2>&1 | Out-Null
    git -c commit.gpgsign=false commit -qm "batch $bi" 2>&1 | Out-Null
    git push -q origin clean2 2>&1 | Out-Null
    L "batch $bi pushed $([math]::Round($sz/1MB)) MB"
    $batch.Clear(); $sz = 0
  }
}
if($batch.Count){
  $bi++
  [IO.File]::WriteAllLines((Join-Path $root '_batch.txt'), $batch, $enc)
  git add --pathspec-from-file=_batch.txt 2>&1 | Out-Null
  git -c commit.gpgsign=false commit -qm "batch $bi" 2>&1 | Out-Null
  git push -q origin clean2 2>&1 | Out-Null
  L "final batch $bi pushed $([math]::Round($sz/1MB)) MB"
}
L 'force push to main'
git push -f -q origin clean2:main 2>&1 | Out-Null
L '=== done ==='
