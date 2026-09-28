$null = ni "test.cs"
[IO.File]::WriteAllBytes("test.res", @(0,0,0,0,8,0,0,0))
&"$pwd/compiler/csc" /out:$pwd\test.dll /win32res:test.res /t:library $pwd\test.cs /nologo /o /langversion:7.3 /noconfig /nostdlib
ri "test.cs"
ri "test.res"