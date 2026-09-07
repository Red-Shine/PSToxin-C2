# simple program i used to condense all ps1 scripts into a single file
$files=gci *.ps1 -r
$totalcontent=''
foreach($file in $files) {
    $content=gc $file|out-string
    $totalcontent+=$content+"`n"
}
sc totalcontent.ps1 $totalcontent 