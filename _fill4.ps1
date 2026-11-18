$ErrorActionPreference='Continue'
$root='C:\Users\user\projects\fresha-ar'
$log=Join-Path $root '_fill.log'
function L($m){ ((Get-Date).ToString('HH:mm:ss')+'  '+$m) | Out-File $log -Append -Encoding UTF8 }
$ua='Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36'

$all = @()
foreach($c in (Get-ChildItem $root -Filter '_chunk_*.txt')){ $all += Get-Content $c.FullName -Encoding UTF8 }
[array]::Reverse($all)
$todo = @()
foreach($r in $all){
  $rel = $r.Trim() -replace '&#x27;',"'" -replace '&amp;','&'
  if(-not $rel){ continue }
  $dest = Join-Path $root (($rel.TrimStart('/') -replace '/','\') + '\index.html')
  if(-not (Test-Path $dest) -or (Get-Item $dest).Length -lt 5000){ $todo += $rel }
}
L "extra todo $($todo.Count)"

$enc = New-Object System.Text.UTF8Encoding($false)
$chunks = @()
for($i=0; $i -lt 5; $i++){
  $cf = Join-Path $root ("_xchunk_{0}.txt" -f $i)
  $sw = New-Object IO.StreamWriter($cf, $false, $enc)
  for($j=$i; $j -lt $todo.Count; $j+=5){ $sw.WriteLine($todo[$j]) }
  $sw.Close(); $chunks += $cf
}

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
    $done=$false
    for($k=1; $k -le 3; $k++){
      try{
        $wc = New-Object System.Net.WebClient
        $wc.Headers.Add('User-Agent',$ua)
        $wc.Headers.Add('Referer','https://www.fresha.com/ar')
        $wc.DownloadFile($url,$dest); $wc.Dispose()
        if((Get-Item $dest).Length -gt 5000){ $done=$true; break }
      } catch { Start-Sleep -Seconds (2*$k) }
    }
    if($done){ $ok++ } else { $bad++; if(Test-Path $dest){ Remove-Item $dest -Force -EA 0 } }
    Start-Sleep -Milliseconds 80
  }
  L "extra worker done ok=$ok bad=$bad"
}
$jobs=@()
foreach($cf in $chunks){ $jobs += Start-Job -ScriptBlock $job -ArgumentList $cf,$root,$ua,$log }
L 'started 5 extra workers'
$jobs | Wait-Job | Out-Null
$jobs | Remove-Job
L 'extra all done'
