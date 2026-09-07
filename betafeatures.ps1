function str {param($a);$q=get-random ("'",'"');($q+$a+$q)}
function randlist {
	param([switch]$numonly)
	$list=@()
	if ($numonly) {
		$length=get-random(0x10..0x100)
		for($i=0;$i -lt $length; $i++) {
			$list+=get-random ((get-random),(str (randstring)))
		}
	}
	else {
		$length=get-random(0x1..0x10)
		for($i=0;$i -lt $length; $i++) {
			$list+=get-random ((get-random),(str (randstring)))
		}
	}
	for($i=0;$i -lt $length; $i++) {
		
	}
	((get-random('','$','@')) + "($($list-join','))")
}

function randstring {foreach($ewf in (1..(get-random (10..50)))){[string]$string+=[char](get-random ((48..57)+(65..90)+(97..122)))};$string}
function randvar {('$' + (randstring))}
function randparam {
	$pwrap="param(",")"
	$length=get-random(0x1..0x10)
	$list=@()
	for($i=0;$i -lt $length; $i++) {
		$list+=randvar
	}
	($pwrap[0]+($list-join',')+$pwrap[1]),$list
}
function randop {(get-random (' + ',' - ',' * ',' / ',' % ', ' -bor ',' -band ',' -bxor ',' -shl ', ' -shr '))}
function randboolop {'-' + (get-random ('eq','ne','gt','ge','lt','le'))}
function randex {[string](get-random)+(randop)+[string](get-random)}
function randc {"# $(randstr)"}
function randc2 {"<#$(randstr)#>"}

function randvardef {
	param([switch]$usecustomvars, $var1 = randvar, $var2 = randvar)
	if ($usecustomvars) {
		("$var1 = $(get-random (($var1 + ' + ' + (str (randstring))), ($var1 + (randop) + (get-random)), ($var1 + (randop) + $var2)))")
	}
	else {
		("$($var1) = $(get-random ((str (randstring)),(get-random),(randex),(($var1) + (randop) + ($var1)),(randlist)))")
	}
}
function randvarbool {
	param([switch]$usecustomvars, $var1 = randvar, $var2 = randvar)
	if ($usecustomvars) {
		("$var1 $(randboolop) ($(get-random (($var1 + (randop) + (str (randstring))),($var1 + (randop) + (get-random)),($var1 + (randop) + $var2))))")
	}
	else {
		("$(randvar) $(randboolop) ($(get-random ((str (randstring)),(get-random),(randex),((randvar) + randop + (randvar)),(randlist))))")
	}
}
function randfunc {
	$par=randparam
	$param_def=$par[0]
	$param_list=$par[1]
	$funcwrap="function $(randstring) {$($param_def);",";return $($param_list -join',')}"
	$length=get-random(0x1..0x100)
	$funclines=@()
	for($i=0;$i -lt $length; $i++) {
		if (get-random 2) {
			$currentvars=get-random $param_list -c 2
			$rand=randvardef -usecustomvars $currentvars[0] $currentvars[1]
			$rand2=randvardef -usecustomvars  $currentvars[0] $currentvars[1]
			$rand3=randvarbool -usecustomvars  $currentvars[0] $currentvars[1]
			$rand=get-random ($rand,(randc2),(get-random ("if ($($rand3)) {$rand}","if ($($rand3)) {$rand} else {$rand2}","while ($($rand3)) {$rand}","for(`$i=0;`$i -lt $(get-random);`$i++) {$rand + 1}","do {$rand} until ($rand3)","do {$rand} while ($rand3)","try {$rand} catch {$rand2}","try {$rand} catch {$(randvardef -usecustomvars $currentvars[0] $currentvars[1])} finally {$rand2}")))
		}
		else {
			$rand=randvardef
			$rand2=randvardef
			$rand3=randvarbool
			$rand=get-random ($rand,(randc2),(get-random ("if ($($rand3)) {$rand}","if ($($rand3)) {$rand} else {$rand2}","while ($($rand3)) {$rand}","for(`$i=0;`$i -lt $(get-random);`$i++) {$rand + 1}","do {$rand} until ($rand3)","do {$rand} while ($rand3)","try {$rand} catch {$rand2}","try {$rand} catch {$(randvardef)} finally {$rand2}")))
		}
		$funclines+=$rand
	}
	($funcwrap[0]+($funclines-join";")+$funcwrap[1])
}


# it was an interesting idea, but i didn't know how to make it look like administrative code in an automated and non-signatured way, so i decided to just not include it
function Add-DeadCode {
	$length=get-random(0x10..0x200)
	$funclines=@()
	for($i=0;$i -lt $length; $i++) {
		$rand=randvardef
		$rand2=randvardef
		$rand3=randvarbool
		$rand=get-random ($rand,(get-random ("if ($($rand3)) {`n`t$rand`n}","if ($($rand3)) {`n`t$rand`n} else {`n`t$rand2`n}","while ($($rand3)) {`n`t$rand`n}","for(`$i=0;`$i -lt $(get-random);`$i++) {`n`t$rand + 1`n}","try {`n`t$rand`n} catch {`n`t$rand2`n}","try {`n`t$rand`n} catch {`n`t$(randvardef)`n} finally {`n`t$rand2`n}")))
		if (!(get-random 10)) {$rand=randfunc}
		$randlines+=$rand+"`n"
	}
	$randlines-join""
}

# originally was thinking of adding a cflow flattener, turns out its a lot harder making one for PowerShell code than it is for MSIL
# but who knows, maybe someone else can figure this out...
Function Add-CFlowObfuscation {
	param($Payload)
	$statevarname = randstring
	$script=$Payload-split"`n"
	$entrystate=get-random -min 1
	$stateprev=$entrystate
	$scriptobject = foreach ($line in $script) {
		$statemod="$(get-random ('-bor','-band','-bxor')) $(get-random -min 1)"

		$state=iex "$stateprev $statemod"
		[pscustomobject]@{
			line = $line
			statemod = $statemod
			state = $stateprev
		}
		$stateprev=$state
	}
	$endstate=$state
	[array]$logic=@()
	for($i=0;$i-lt$scriptobject.count;$i++) {
		$logic+="$($scriptobject[$i].state) {`n$($scriptobject[$i].line)`n`$$statevarname=`$$statevarname $($scriptobject[$i].statemod)`ncontinue`n}"
	}
	$scrambledlogic=$logic|sort{Get-Random}
	$scriptnew="`$$statevarname=$entrystate`nwhile(`$$statevarname -ne $endstate) {`nswitch (`$$statevarname) {`n$($scrambledlogic-join"`n")`n}`n}"
	return $scriptnew
}