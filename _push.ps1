$ErrorActionPreference='Continue'
$root='C:\Users\user\projects\fresha-ar'
Set-Location $root
git config core.longpaths true
$log=Join-Path $root '_push.log'
function L($m){ ((Get-Date).ToString('HH:mm:ss')+'  '+$m) | Out-File $log -Append -Encoding UTF8 }
L 'start'
git add -A 2>&1 | Out-Null
git -c commit.gpgsign=false commit -qm "arabic mirror full" 2>&1 | Out-Null
git branch -D clean 2>&1 | Out-Null
git checkout --orphan clean 2>&1 | Out-Null
git rm -r --cached . -q 2>&1 | Out-Null
$files=@()
$files+=Get-ChildItem ar,lp/ar,_next,_icons,_sitemaps -Recurse -File -EA 0
$files+=Get-ChildItem . -File -EA 0
$files=$files | Where-Object { $_.Name -notin @('_push.log','_night.log','_batch.txt') } | ForEach-Object { $_.FullName.Substring($root.Length+1) }
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
    git -c commit.gpgsign=false commit -qm "b$i" 2>&1 | Out-Null
    for($r=1;$r -le 3;$r++){ git push -q origin clean 2>&1 | Out-Null; if($LASTEXITCODE -eq 0){ break }; Start-Sleep 20 }
    L "b$i $([math]::Round($sz/1MB))MB rc=$LASTEXITCODE"
    $b.Clear(); $sz=0
  }
}
if($b.Count){
  $i++
  [IO.File]::WriteAllLines((Join-Path $root '_batch.txt'),$b,$enc)
  git add --pathspec-from-file=_batch.txt 2>&1 | Out-Null
  git -c commit.gpgsign=false commit -qm "b$i" 2>&1 | Out-Null
  for($r=1;$r -le 3;$r++){ git push -q origin clean 2>&1 | Out-Null; if($LASTEXITCODE -eq 0){ break }; Start-Sleep 20 }
  L "final $i rc=$LASTEXITCODE"
}
L 'force main'
git push -f -q origin clean:main 2>&1 | Out-Null
L "done rc=$LASTEXITCODE"
