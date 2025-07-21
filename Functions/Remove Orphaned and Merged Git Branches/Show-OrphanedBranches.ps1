function Show-OrphanedBranches {
  <#
    .SYNOPSIS
    Lists local branches that track deleted remote branches and merged branches
    
    .DESCRIPTION
    This function shows you which branches would be deleted without actually deleting them.
    It can search through subdirectories to find git repositories.
    
    .PARAMETER Recurse
    Search through all subdirectories for git repositories
  #>
  param(
    [switch]$Recurse
  )
    
  $gitRepos = @()
    
  if ($Recurse) {
    # Find all git repositories in subdirectories
    $gitRepos = Get-ChildItem -Directory -Recurse | Where-Object { 
      Test-Path (Join-Path $_.FullName ".git") -PathType Container 
    }
        
    if ($gitRepos.Count -eq 0) {
      Write-Host "No git repositories found in subdirectories." -ForegroundColor Yellow
      return
    }
        
    Write-Host "🔍 Found $($gitRepos.Count) git repository/repositories:" -ForegroundColor Cyan
    foreach ($repo in $gitRepos) {
      Write-Host "  • $($repo.FullName)" -ForegroundColor Gray
    }
    Write-Host ""
  }
  else {
    # Check current directory only
    if (-not (Test-Path ".git" -PathType Container) -and -not (git rev-parse --git-dir 2>$null)) {
      Write-Host "Not in a git repository. Use -Recurse to search subdirectories." -ForegroundColor Yellow
      return
    }
    $gitRepos = @([PSCustomObject]@{ FullName = (Get-Location).Path })
  }
    
  # Collections to store all branches from all repositories
  $allOrphanedBranches = @()
  $allMergedBranches = @()
    
  foreach ($repo in $gitRepos) {
    $originalLocation = Get-Location
    try {
      Set-Location $repo.FullName
      if (-not $Recurse) {
        Write-Host "🔍 Analyzing branches in: $($repo.FullName)" -ForegroundColor Cyan
      }
            
      # Fetch latest remote information and prune deleted branches
      git fetch --prune --quiet
            
      # Get all local branches that track remote branches
      $localBranchesWithRemotes = git branch -vv | Where-Object { $_ -match '\[.*\]' }
            
      # Find orphaned branches (tracking deleted remotes)
      foreach ($branch in $localBranchesWithRemotes) {
        if ($branch -match '^\*?\s*(\S+)\s+\w+\s+\[([^:\]]+)(?::|.*gone.*)\]') {
          $branchName = $matches[1]
                    
          if ($branch -match 'gone') {
            $allOrphanedBranches += [PSCustomObject]@{
              Name       = $branchName
              Status     = "Remote deleted"
              Repository = $repo.FullName
            }
          }
        }
      }
            
      # Find merged branches
      # Find merged branches
      $defaultBranch = "main"
      # Try to determine the default branch
      if (git show-ref --verify --quiet refs/heads/master) {
        $defaultBranch = "master"
      }
            
      # Get merged branches (excluding current branch and default branches)
      $mergedBranchNames = git branch --merged | Where-Object { 
        $_ -notmatch '\*' -and $_ -notmatch 'master|main' 
      } | ForEach-Object { $_.Trim() }
            
      foreach ($branchName in $mergedBranchNames) {
        $allMergedBranches += [PSCustomObject]@{
          Name       = $branchName
          Status     = "Merged into $defaultBranch"
          Repository = $repo.FullName
        }
      }
            
      # Display results for individual repository (non-recurse mode)
      if (-not $Recurse) {
        if ($allOrphanedBranches.Count -gt 0 -or $allMergedBranches.Count -gt 0) {
          Write-Host "`n📋 Branch Analysis Results for: $($repo.FullName)" -ForegroundColor White
          Write-Host "=" * 80 -ForegroundColor Gray
                    
          if ($allOrphanedBranches.Count -gt 0) {
            Write-Host "`n🗑️  Orphaned Branches (tracking deleted remotes):" -ForegroundColor Red
            $allOrphanedBranches | Format-Table Name, Status -AutoSize
          }
                    
          if ($allMergedBranches.Count -gt 0) {
            Write-Host "`n✅ Merged Branches:" -ForegroundColor Yellow
            $allMergedBranches | Format-Table Name, Status -AutoSize
          }
                    
          $totalBranches = $allOrphanedBranches.Count + $allMergedBranches.Count
          Write-Host "📊 Summary: $totalBranches branch(es) could be cleaned up in this repository" -ForegroundColor Cyan
        }
        else {
          Write-Host "✅ No branches to cleanup in: $($repo.FullName)" -ForegroundColor Green
        }
      }
            
    }
    catch {
      Write-Host "❌ Error analyzing repository $($repo.FullName): $($_.Exception.Message)" -ForegroundColor Red
    }
    finally {
      Set-Location $originalLocation
    }
  }
    
  # Display combined results for recurse mode
  if ($Recurse) {
    $allBranches = $allOrphanedBranches + $allMergedBranches
        
    if ($allBranches.Count -gt 0) {
      Write-Host "`n📋 All Branches That Can Be Cleaned Up:" -ForegroundColor White
      Write-Host "=" * 80 -ForegroundColor Gray
            
      if ($allOrphanedBranches.Count -gt 0) {
        Write-Host "`n🗑️  Orphaned Branches (tracking deleted remotes):" -ForegroundColor Red
        $allOrphanedBranches | Format-Table Name, Status, Repository -AutoSize
      }
            
      if ($allMergedBranches.Count -gt 0) {
        Write-Host "`n✅ Merged Branches:" -ForegroundColor Yellow
        $allMergedBranches | Format-Table Name, Status, Repository -AutoSize
      }
            
      Write-Host "📊 Summary: $($allBranches.Count) branch(es) total across $($gitRepos.Count) repository/repositories" -ForegroundColor Cyan
      Write-Host "`nUse 'Remove-DeletedRemoteBranches -Recurse' to clean up all repositories." -ForegroundColor Gray
    }
    else {
      Write-Host "✅ No branches to cleanup in any repository." -ForegroundColor Green
    }
  }
  else {
    if ($allOrphanedBranches.Count -gt 0 -or $allMergedBranches.Count -gt 0) {
      Write-Host "`nUse 'Remove-DeletedRemoteBranches' to clean them up." -ForegroundColor Gray
    }
  }
}