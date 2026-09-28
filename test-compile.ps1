Add-Type -a System.Windows.Forms
$test = @"
using System;
using System.Windows.Forms;

static class Program {
	private static void Main() {
		MessageBox.Show("Hello world!", "Test");
	}
}
"@
sc 'test.cs' $test
[IO.file]::WriteAllBytes("$pwd\test.res", @(0,0,0,0,8,0,0,0))
$asm = [Windows.Forms.Form].Assembly.Location
&"$pwd/compiler/csc" /out:$pwd\test.exe /win32res:test.res /t:winexe /r:$asm $pwd\test.cs /nologo /o /langversion:7.3
ri "test.cs"
ri "test.res"