$ErrorActionPreference='Continue'
$root='C:\Users\user\projects\fresha-ar'
Set-Location $root
$log=Join-Path $root '_push2.log'
function L($m){ ((Get-Date).ToString('HH:mm:ss')+'  '+$m) | Out-File $log -Append -Encoding UTF8 }
L 'start'

git add -A -- _next 2>&1 | Out-Null
git -c commit.gpgsign=false commit -qm "untrack _next" 2>&1 | Out-Null
git push -q origin main 2>&1 | Out-Null
L "untrack rc=$LASTEXITCODE"

$files=@()
$files+=Get-ChildItem ar,lp/ar,_icons,_sitemaps -Recurse -File -EA 0
$files+=Get-ChildItem . -File -EA 0
$files=$files | Where-Object { $_.Name -notin @('_push.log','_push2.log','_night.log','_fill.log','_batch.txt') -and $_.Name -notlike '_chunk_*' } | ForEach-Object { $_.FullName.Substring($root.Length+1) }
L "files $($files.Count)"

$enc=New-Object System.Text.UTF8Encoding($false)
$b=New-Object System.Collections.Generic.List[string]; $sz=0; $i=0
foreach($f in $files){
  $sz += (Get-Item -LiteralPath $f -EA 0).Length
  $b.Add($f)
  if($sz -ge 800MB){
    $i++
    [IO.File]::WriteAllLines((Join-Path $root '_batch.txt'),$b,$enc)
    git add --pathspec-from-file=_batch.txt 2>&1 | Out-Null
    git -c commit.gpgsign=false commit -qm "fill batch $i" 2>&1 | Out-Null
    for($r=1;$r -le 3;$r++){ git push -q origin main 2>&1 | Out-Null; if($LASTEXITCODE -eq 0){ break }; Start-Sleep 20 }
    L "b$i $([math]::Round($sz/1MB))MB rc=$LASTEXITCODE"
    $b.Clear(); $sz=0
  }
}
if($b.Count){
  $i++
  [IO.File]::WriteAllLines((Join-Path $root '_batch.txt'),$b,$enc)
  git add --pathspec-from-file=_batch.txt 2>&1 | Out-Null
  git -c commit.gpgsign=false commit -qm "fill batch $i" 2>&1 | Out-Null
  for($r=1;$r -le 3;$r++){ git push -q origin main 2>&1 | Out-Null; if($LASTEXITCODE -eq 0){ break }; Start-Sleep 20 }
  L "final $i rc=$LASTEXITCODE"
}
L 'done'
