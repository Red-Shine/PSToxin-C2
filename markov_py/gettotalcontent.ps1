$files=gci *.ps1 -r
$totalcontent = ''
foreach($file in $files) {
	$content = gc $file | Out-String
	$totalcontent += "$content`n"
}
sc totalcontent.ps1 $totalcontent 