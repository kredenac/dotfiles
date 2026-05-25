# Open-CopilotQuad.ps1
# Splits the current Windows Terminal pane into a 2x2 grid, running
# `c` (agency copilot --yolo) in each pane. All panes start in C:\repos.
#
# Wired up via the "Copilot 2x2" profile in WindowsTerminal-settings.json.

$repos = 'C:\repos'

# Spawn three sibling panes in the current window. This script's own pane
# becomes the 4th. Backtick-semicolons escape the `;` so PowerShell passes
# them through to wt.exe as action separators rather than statement terminators.
#
# Layout flow:
#   [A]  --split-V-->  [A|B]
#        --focus left-->  (back to A)
#        --split-H-->  [[A/C]|B]
#        --focus right-->  (to B)
#        --split-H-->  [[A/C]|[B/D]]
#        --focus first-->  (back to A, where this script is running)
wt -w 0 split-pane -V -d $repos pwsh.exe -NoExit -Command c `; move-focus left `; split-pane -H -d $repos pwsh.exe -NoExit -Command c `; move-focus right `; split-pane -H -d $repos pwsh.exe -NoExit -Command c `; move-focus first

Set-Location $repos
c
