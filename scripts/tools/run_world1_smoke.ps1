param(
	[string]$GodotExe = "C:\Users\marks\Documents\Godot_v4.5.1-stable_win64.exe\Godot_v4.5.1-stable_win64_console.exe"
)

if (-not (Test-Path $GodotExe)) {
	Write-Error "Godot executable not found at '$GodotExe'. Pass -GodotExe <path>."
	exit 1
}

& $GodotExe --headless --path . --script res://scripts/tools/world1_smoke.gd
exit $LASTEXITCODE
