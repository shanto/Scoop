param (
    [switch]$Uninstall
)

$Name = "SSH Agent Bridge"
$progs = "$env:AppData\Microsoft\Windows\Start Menu\Programs"
$stp = "$progs\Startup\$Name.lnk"

if ((Test-Path $stp) -and $Uninstall) {
    Remove-Item -Path $stp -Force
    Return
}

$bin = ($manifest.bin | Select-Object -First 1) -replace '\.exe$', '-noconsole.exe'
$sh = New-Object -ComObject WScript.Shell
$sc = $sh.CreateShortcut($stp)
$sc.TargetPath = "${dir}\${bin}"
$sc.Arguments = "-from cygwin,pageant,pageant-pipe -cygwin-socket `"%LOCALAPPDATA%/ssh-agent-bridge-cw.sock`" -to pipe"
$sc.Save()
$sh.Run("`"$stp`"")
