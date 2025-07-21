function Remove-DeletedRemoteBranches {
  <#
    .SYNOPSIS
    Removes local branches that track deleted remote branches and merged branches
    
    .DESCRIPTION
    This function actually deletes the branches that Show-OrphanedBranches identifies.
    It can search through subdirectories to find git repositories.
    
    .PARAMETER Recurse
    Search through all subdirectories for git repositories
    
    .PARAMETER WhatIf
    Show what would be deleted without actually deleting
  #>
  param(
    [switch]$Recurse,
    [switch]$WhatIf
  )
    
  $gitRepos = @()
    
  if ($Recurse) {
    $gitRepos = Get-ChildItem -Directory -Recurse | Where-Object { 
      Test-Path (Join-Path $_.FullName ".git") -PathType Container 
    }
        
    if ($gitRepos.Count -eq 0) {
      Write-Host "No git repositories found in subdirectories." -ForegroundColor Yellow
      return
    }
  }
  else {
    if (-not (Test-Path ".git" -PathType Container) -and -not (git rev-parse --git-dir 2>$null)) {
      Write-Host "Not in a git repository. Use -Recurse to search subdirectories." -ForegroundColor Yellow
      return
    }
    $gitRepos = @([PSCustomObject]@{ FullName = (Get-Location).Path })
  }
    
  foreach ($repo in $gitRepos) {
    $originalLocation = Get-Location
    try {
      Set-Location $repo.FullName
      Write-Host "🧹 Cleaning branches in: $($repo.FullName)" -ForegroundColor Cyan
            
      git fetch --prune --quiet
            
      # Remove orphaned branches
      $localBranchesWithRemotes = git branch -vv | Where-Object { $_ -match '\[.*gone.*\]' }
      foreach ($branch in $localBranchesWithRemotes) {
        if ($branch -match '^\*?\s*(\S+)') {
          $branchName = $matches[1]
          if ($WhatIf) {
            Write-Host "Would delete orphaned branch: $branchName" -ForegroundColor Yellow
          }
          else {
            git branch -D $branchName
            Write-Host "Deleted orphaned branch: $branchName" -ForegroundColor Red
          }
        }
      }
            
      # Remove merged branches
      $currentBranch = git branch --show-current
      $mergedBranchNames = git branch --merged | Where-Object { 
        $_ -notmatch '\*' -and $_ -notmatch 'master|main' 
      } | ForEach-Object { $_.Trim() }
            
      foreach ($branchName in $mergedBranchNames) {
        if ($WhatIf) {
          Write-Host "Would delete merged branch: $branchName" -ForegroundColor Yellow
        }
        else {
          git branch -d $branchName
          Write-Host "Deleted merged branch: $branchName" -ForegroundColor Green
        }
      }
    }
    catch {
      Write-Host "❌ Error cleaning repository $($repo.FullName): $($_.Exception.Message)" -ForegroundColor Red
    }
    finally {
      Set-Location $originalLocation
    }
  }
}