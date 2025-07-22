# Remove Orphaned and Merged Git Branches

This folder contains PowerShell scripts to help you identify and clean up local Git branches that are either:
- Tracking deleted remote branches (orphaned)
- Already merged into the main branch

## Functions

- **Show-OrphanedBranches.ps1**  
  Lists local branches that are orphaned or merged.  
  _Does not delete branches—just shows what can be cleaned up._

- **Remove-DeletedRemoteBranches.ps1**  
  Deletes local branches identified as orphaned or merged.  
  _Supports a `-WhatIf` mode to preview deletions._

## Usage

### Show-OrphanedBranches

```powershell
.\Show-OrphanedBranches.ps1
```
- Lists orphaned and merged branches in the current repository.

```powershell
.\Show-OrphanedBranches.ps1 -Recurse
```
- Searches all subdirectories for Git repositories and lists branches to clean up.

### Remove-DeletedRemoteBranches

```powershell
.\Remove-DeletedRemoteBranches.ps1
```
- Deletes orphaned and merged branches in the current repository.

```powershell
.\Remove-DeletedRemoteBranches.ps1 -Recurse
```
- Cleans up branches in all found repositories under subdirectories.

```powershell
.\Remove-DeletedRemoteBranches.ps1 -WhatIf
```
- Shows what would be deleted, without actually deleting branches.

## Notes

- Both scripts automatically detect repositories and default branches (`main` or `master`).
- Use the `-Recurse` parameter to operate on multiple repositories at once.
- Always run `Show-OrphanedBranches.ps1` first to review what will be deleted.

## More Information

For a detailed explanation and background on these scripts, see: [Streamline Your Git Workflow: Semi-Automated Branch Cleanup with PowerShell](https://rksolutions.nl/streamline-your-git-workflow-semi-automated-branch-cleanup-with-powershell/)