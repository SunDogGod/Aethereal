# Rebuilds characters from their Blender scripts and refreshes them in Godot.
#   Right-click > Run with PowerShell, or in a terminal:  .\tools\blender\rebuild.ps1 aeneas,kael
#   (several names: commas between them; with spaces only the first one is rebuilt)
# With no names it rebuilds every character. Close the Godot editor first (or reopen the
# project afterwards) so it picks up the new models.
param([string[]]$Names = @("aeneas", "kael", "isabella", "agent", "captain"))

$Blender = "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"
$Godot = "C:\Users\ArmandoSanchez\OneDrive - Ucio IT Services\Documents\Godot_v4.7.2-stable_win64_console.exe"
$Here = Split-Path -Parent $MyInvocation.MyCommand.Path
$Project = Resolve-Path (Join-Path $Here "..\..")

foreach ($n in $Names) {
    $script = Join-Path $Here "$n.py"
    if (Test-Path $script) {
        & $Blender -b --factory-startup -P $script | Select-String "CHARACTER|Error|Traceback"
    } else {
        # No look script yet: the plain grey stand-in.
        & $Blender -b --factory-startup -P (Join-Path $Here "grey_bodies.py") -- $n | Select-String "CHARACTER|Error|Traceback"
    }
}
# Import twice: the first pass meets the new textures before the models that use them.
& $Godot --headless --path $Project --import | Out-Null
& $Godot --headless --path $Project --import | Select-String "ERROR"
& $Godot --headless --path $Project -s res://tools/blender/make_wrapper.gd -- @Names | Select-String "WRAPPER"
