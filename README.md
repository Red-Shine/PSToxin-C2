# PSToxin C2

---
this was a big side project of mine that i have decided release for everyone else to enjoy, though i highly doubt it is that entertaining

---
## What is this poorly coded garbage?

it is poorly coded garbage, but it is also a fileless CnC (Command and Control) framework, that uses Discord as its CnC server

it has many features including a remote shell, keylogger and screen logger.

#### Why Discord?

because its a legitimate service, so an antivirus cant just block it

its also disposable, so if a server gets banned, you can always create a new one
#
and its also because i was too lazy to setup my own server when testing this 

---
## Why the name?

idk, i just thought it sounded cool

---
## How to use.

open the "build.ps1" file and replace the values with ones specific to your server

$token is the discord bot token

$clcid is the channel id for the command line channel

$klcid is the channel id for the keylogger

$sccid is the channel id for the screen logger

### Other Configuration Options

$attachment_extension is the extension used by the attachment handler for special encoded bitmap extensions (the default extension is ".png"), see "Attachment Handler" for more details

$use_older_commentgen_system is an advanced option that uses a simpler comment generation system, it is disabled by default

$compile is an option that when enabled, compiles the PowerShell script, it is disabled by default

outputting an exe file instead of a ps1 script

if you care how it exactly works, it basically adds the script as a resource to a minimal 3kb c# stub that loads and executes it

---
## :bomb::collision::sparkles: Features :fire::white_check_mark::gear:

should i spam even more emojis? how about this one :deciduous_tree:

but anyways, here are all the features:

### Main features

these are the main features that automatically included within the generated payload

#### Command Line

this is the core feature that allows you to control the computer remotely

you can type in what ever PowerShell commands you want in addition to some custom ones if you load "extras.ps1"

#### Keylogger

this is a feature that will upload every 200 keystrokes to a specified channel, which should not be the same channel as the command line or screen logger

not much else to say about this one, its just a keylogger

#### Screen Logger

this feature will send a screen of the computer every 5 seconds to a specified channel, which should not be the same channel as the command line or keylogger

#### Attachment Handler

if you upload a file attachment to the command line channel, it will automatically be uploaded to the computer, unless its a .ps1 script, in which it will automatically be executed as code
or if it has the special encoded bitmap extension, what is that?

well, basically if you try upload a file and it is blocked by Discord, you can drag and drop it onto the special "ConvertToBitmap.exe"

this will turn it into a special bitmap that can decoded by the attachment handler, but is literally just a bitmap, making it far less likely to be blocked by Discord
it also looks kinda when you open it in a image viewer

---
### Extra Features

these are command line features that can be accessed by loading "extras.ps1" via the attachment handler

there are a lot of them, so i've split them into categories

#### Info Collection

allows you to gather addition information from the computer

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

#### Automation

allows to control the system as a user would, including mouse and keyboard input

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

#### GDI

these are mostly for fun, they display gdi effects to the screen

gdi-melt -s (duration in seconds)

gdi-flash -s (duration in seconds)

gdi-tunnel -s (duration in seconds)

gdi-stretch -s (duration in seconds)

gdi-blackout -s (duration in seconds)

#### Internal Commands and Variables (Advanced)

these are commands and constants that are mostly for internal use by the other commands, but you can use as well, the only catch is that i will not be documenting any of these

upload -file (file to upload)

load -asm (compressed assembly to be loaded)

getelementbyid -a (id)

getelementbyname -a (name)

GetDateFromWebkitTime -s (time)

GetAllProfiles -DirectoryPath (path)

History_Recovery -path (path) -browser (browser)

Downloads_Recovery -path (path) -browser (browser)

keywordSearchTermsHistory -path (path) -browser (browser)

$element (type: object)

$screen (type: object)

$devices (type: invokable)

$lat (type: double)

$lon (type: double)

$addr (type: string)

---
### Other Utils and Features

these are features that dont fit into either of the other categories

#### Encryption

this feature will individually encrypt strings, methods, types and cmdlets in PSToxin payloads

this feature is possible due the fact that strings can be converted to types using the "[type]" type
and because PowerShell allows method names to be strings

strings can also be interpreted as cmdlets if you use the "&" invoke operator

here is an example:
```
$e = ([type]"Text.Encoding")::"UTF8"."GetString"(@(104, 101, 108, 108, 111, 32, 119, 111, 114, 108, 100))
&"Write-Output" $e
```
it is worth noting that static methods must be invoked with the "invoke" method

here is an example with a static method:
```
$e = ([type]"Text.Encoding")::"UTF8"."GetString"(([type]"Convert")::"FromBase64String"."invoke"("aGVsbG8gd29ybGQ="))
&"Write-Output" $e
```
#
these strings can be encrypted, and the obfuscator will find each string in the payload and encrypt it

in fact, the embedded payloads in "build.ps1" is written in such a way that, aside from keywords, most of the code is actually strings, so almost everything will encrypted
#
there is also a decryption function ($decryptor_func) that is added onto the beginning of every PSToxin payload
this function recieves its own special obfuscation that randomizes the casing of everything

#### Variable Renaming

this feature renames all variables to random gibberish, ensuring every payload is unique

#### Fake Comment Generator

does what you think, it inserts fake comments into the payload

this helps defeat yara signatures and fuzzy hashing

and if your wondering how, it generates these comments using a Markov Chain

it is trained on various powershell administration scripts i scraped from GitHub (aka im larping as a sh!tty ai company)

#### Anti Sandbox and Language Mode Verification

these two work together to ensure the environment it is being ran in is the environment we want to run it in

the anti sandbox feature ensures it is not being ran in a virtual machine by checking one class it randomly selected from a certain set of WMI classes

i go more into detail on how this works in the dev notes for "obfuscate.ps1"
but basically, certain WMI classes will return nothing in virtual environments, while still returning something on regular computers

the language mode verification feature checks if the PowerShell "Language Mode" is "FullLanguage"

the reason why it checks this is that in some cases, AppLocker, WDAC (Windows Defender Application Control) and certain enterprise environments will lock down PowerShell sessions and restrict what they can do by changing the sessions' "Language Mode"

depending on which mode they choose, the things it restricts can range from using .NET types, to almost the whole language

PSToxin uses many of the things these alternate mode's restrict, so if the "$ExecutionContext.SessionState.LanguageMode" variable is anything aside from "FullLanguage", it will immediately exit

#### AMSI and Persistence

after checking for sandboxes and verifying the language mode, PSToxin will disable AMSI (AntiMalware Scan Interface), preventing antivirus from stopping it beyond that point

it will also add an entry to the user's run key, making the name an amalgamation of other startup program names

however, if the user does not have enough programs in startup, it will use a hardcoded name that was randomly generated when the payload was built

because PSToxin is fileless, it will only write its scripts to the registry

and it will write to almost anywhere in the registry

it will randomly iterate through keys and will grab bits and pieces of other registry values in its chosen key

combining them to make it's own registry key

it will do this for each of the 4 scripts it runs

#### Downloader Shortcut Generator

"host.ps1" generates a shortcut that downloads and executes the PSToxin payload from a specified url

#### Compile Scripts

"cam-compile.ps1" and "sql-compile.ps1" are scripts that compile the dll's used in "extras.ps1"

---
## Disclaimer

i am not going to just use the "ThIS Is FoR EDUCAtIONal PurPOseS ONly", because its overused bullsh!t that no one wants to fcking hear

and cause honestly you wont learn much from listening to me yap :skull:
#
Instead, this is what I will say:
I am not responsible for what you choose to do with this software. **Sharing this code is free speech**, and I do not give instuctions on how to do anything illegal. This code can sit on GitHub till the end of time, **it will never hack anyone or anything by itself**. YOU have to be the one to use this, YOU have to be the one to spread this, and YOU have to type in the commands, it will do none of those things for you.

---
