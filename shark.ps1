# 🦈 shark.ps1 — Ralph-style loop enforcer for the Shark Pattern (Windows/PowerShell)
# Each iteration = one bounded Claude turn. Never blocks >30s per loop.
# Usage: .\shark.ps1 "your task description"
#   or:  .\shark.ps1  (reads task from SHARK_TASK.md if exists)

param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$TaskArgs
)

$ScriptDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$SkillFile   = Join-Path $ScriptDir "SKILL.md"
$StateFile   = Join-Path $ScriptDir "shark-exec\state\pending.json"
$MaxLoops    = if ($env:SHARK_MAX_LOOPS)   { [int]$env:SHARK_MAX_LOOPS }   else { 50 }
$LoopTimeout = if ($env:SHARK_LOOP_TIMEOUT) { [int]$env:SHARK_LOOP_TIMEOUT } else { 25 }  # seconds per turn

# Resolve task
if ($TaskArgs -and $TaskArgs.Count -gt 0) {
    $Task = $TaskArgs -join " "
} elseif (Test-Path (Join-Path $ScriptDir "SHARK_TASK.md")) {
    $Task = Get-Content (Join-Path $ScriptDir "SHARK_TASK.md") -Raw
} else {
    Write-Host "Usage: .\shark.ps1 'task description'"
    Write-Host "  or create SHARK_TASK.md with your task"
    exit 1
}

function Build-Prompt {
    param([int]$CurrentLoop)
    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add((Get-Content $SkillFile -Raw))
    $lines.Add("")
    $lines.Add("---")
    $lines.Add("## Current Task")
    $lines.Add($Task)
    $lines.Add("")
    $lines.Add("## Loop State")
    $lines.Add("Loop: $CurrentLoop / $MaxLoops")
    if (Test-Path $StateFile) {
        $lines.Add("Pending background jobs:")
        $lines.Add((Get-Content $StateFile -Raw))
    }
    $lines.Add("")
    $lines.Add("## Instructions")
    $lines.Add("Follow the Shark Pattern from SKILL.md above.")
    $lines.Add("Each turn MUST complete in under ${LoopTimeout}s.")
    $lines.Add("If your task requires slow operations (>5s), use shark-exec pattern.")
    $lines.Add("Write TASK_COMPLETE to a file named .shark-done when finished.")
    $lines.Add("Write progress to SHARK_LOG.md after each loop.")
    return $lines -join "`n"
}

# Clean up any previous done marker
$DoneFile = Join-Path $ScriptDir ".shark-done"
if (Test-Path $DoneFile) { Remove-Item $DoneFile -Force }

Write-Host "[SHARK] Shark loop starting - task: $Task"
Write-Host "   Max loops: $MaxLoops | Timeout per turn: ${LoopTimeout}s"
Write-Host ""

$CurrentLoop = 0

while ($CurrentLoop -lt $MaxLoops) {
    $CurrentLoop++
    Write-Host "[SHARK] Loop $CurrentLoop/$MaxLoops..."

    $Prompt = Build-Prompt -CurrentLoop $CurrentLoop

    # Write prompt to a temp file (piping large strings via Start-Job is unreliable)
    $TmpPrompt = Join-Path $env:TEMP "shark_prompt_$PID.md"
    [System.IO.File]::WriteAllText($TmpPrompt, $Prompt, [System.Text.Encoding]::UTF8)

    # Run claude via a background job so we can enforce a hard timeout
    $DoneFile = Join-Path $ScriptDir ".shark-done"
    $Job = Start-Job -ScriptBlock {
        param($promptFile, $workDir)
        Set-Location $workDir
        Get-Content $promptFile -Raw | claude --print --permission-mode bypassPermissions
    } -ArgumentList $TmpPrompt, $ScriptDir

    # Wait with hard timeout
    $Completed = Wait-Job -Job $Job -Timeout $LoopTimeout

    if ($null -eq $Completed) {
        # Timed out — kill the job
        Stop-Job  -Job $Job
        Remove-Job -Job $Job -Force
        Write-Host "[TIMEOUT] Turn $CurrentLoop timed out at ${LoopTimeout}s - looping back"
    } else {
        # Collect output
        Receive-Job -Job $Job
        Remove-Job  -Job $Job -Force
    }

    # Clean up temp prompt
    if (Test-Path $TmpPrompt) { Remove-Item $TmpPrompt -Force }

    # Check if task is done
    if (Test-Path $DoneFile) {
        Write-Host ""
        Write-Host "[DONE] Task complete after $CurrentLoop loops"
        Get-Content $DoneFile
        exit 0
    }
}

Write-Host "[WARN] Max loops ($MaxLoops) reached without completion"
exit 1
