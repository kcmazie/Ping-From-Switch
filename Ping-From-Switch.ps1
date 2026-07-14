<#==============================================================================
         File Name : Ping-From-Switch.ps1
   Original Author : Kenneth C. Mazie (kcmjr AT kcmjr.com)
                   : 
       Description : Script will SSH into the "source" Cisco switch and initiate a number of ICMP "pings" to a
                   : list of targets defined in the external config file.  Response times are gathered into an 
                   : HTML report that is emailed and/or immediately displayed.  A running average of the last two
                   : script runs are tracked for each target switch and displayed during each runs.  On the initial 
                   : the average ping is logged as a baseline that is displayed at each run.  The baseline may be 
                   : updated when desired.  If no source IP is included in the configuration file you are prompted 
                   : for one.  A new option has been added to use a GUI by use of a commandline option.
                   : 
             Notes : Normal operation is with no command line options.  If pre-stored credentials 
                   : are desired use this: https://github.com/kcmazie/CredentialsWithKey. If not included
                   : in the config file you will be prompted.  Note that GUI option is being forced to TRUE.
                   :
      Requirements : Requires the Posh-SSH module from the PowerShell gallery.  Script installs it if
                   : not found.  Otherwise https://www.powershellgallery.com/packages/Posh-SSH
                   : 
   Option Switches : See descriptions above.
                   :
          Warnings : None.
                   :   
             Legal : Public Domain. Modify and redistribute freely. No rights reserved.
                   : SCRIPT PROVIDED "AS IS" WITHOUT WARRANTIES OR GUARANTEES OF 
                   : ANY KIND. USE AT YOUR OWN RISK. NO TECHNICAL SUPPORT PROVIDED.
                   : That being said, feel free to ask if you have questions...
                   :
           Credits : Code snippets and/or ideas came from many sources including...
                   : https://stackoverflow.com/questions/71760114/posh-ssh-script-on-cisco-devices
                   : Ping explanation text adapted from: https://www.virginmedia.com/blog/gaming/what-is-a-good-ping
                   : 
    Last Update by : Kenneth C. Mazie                                           
   Version History : v1.00 - 09-20-24 - Original release
    Change History : v1.10 - 09-26-24 - Fixed some minor typos.  Added color to explenation.  Added color thresholds 
                   :                    to  XML file.  Moved ping count to XML.
                   : v1.11 - 09-27-24 - Expanded on explenation of what "ping" is.
                   : v1.20 - 01-14-25 - Added check to compensate for my goofy folder structure when loading in browser.
                   : v2.00 - 07-13-26 - Added GUI option.  Added baseline tracking
                   #>
                   $ScriptVer = "2.00"    
                   <#--[ Current version # used in script ]--
==============================================================================#>
Param(
    [switch]$Console = $false,         #--[ Set to true to enable local console result display. Defaults to false ]--
    [switch]$Debug = $False,           #--[ Generates extra console output for debugging.  Defaults to false ]--
    [Switch]$Gui = $False,             #--[ Setting to $true enables the GUI input ]--  
    [Switch]$SourceIP = ""             #--[ Switch IP to target ]--            
    )
Clear-Host
#Requires -version 5

#--[ Variables ]---------------------------------------------------------------
$DateTime = Get-Date -Format MM-dd-yyyy_HH:mm:ss  

#==[ RUNTIME TESTING OPTION VARIATIONS ]========================================
#$Console = $true
#$Debug = $True 
$Gui = $True
If($Debug){
    $Console = $true
}
#==============================================================================

if (!(Get-Module -Name posh-ssh*)) {    
    Try{  
        import-module -name posh-ssh
    }Catch{
        Write-host "-- Error loading Posh-SSH module." -ForegroundColor Red
        Write-host "Error: " $_.Error.Message  -ForegroundColor Red
        Write-host "Exception: " $_.Exception.Message  -ForegroundColor Red
    }
}

#==[ Functions ]===============================================================
Function SendEmail ($MessageBody,$ExtOption) { 
    $Smtp = New-Object Net.Mail.SmtpClient($ExtOption.SmtpServer,$ExtOption.SmtpPort) 
    $Email = New-Object System.Net.Mail.MailMessage  
    $Email.IsBodyHTML = $true
    $Email.From = $ExtOption.EmailSender
    If ($ExtOption.ConsoleState){  #--[ If running out of an IDE console, send only to the user for testing ]-- 
        $Email.To.Add($ExtOption.EmailAltRecipient)  
    }Else{       
        $Email.To.Add($ExtOption.EmailRecipient)  
        # $Email.To.Add($ExtOption.EmailAltRecipient)   #--[ In case this user isn't part of the group email ]--   
    }

    $Email.Subject = "Ping Latency Report"
    $Email.Body = $MessageBody
    $ErrorActionPreference = "stop"
    Try {
        $Smtp.Send($Email)
        If ($ExtOption.ConsoleState){Write-Host `n"--- Email Sent ---" -ForegroundColor red }
    }Catch{
        Write-host "-- Error sending email --" -ForegroundColor Red
        Write-host "Error Msg     = "$_.Error.Message
        StatusMsg  $_.Error.Message "red" $ExtOption
        Write-host "Exception Msg = "$_.Exception.Message
        StatusMsg  $_.Exception.Message "red" $ExtOption
        Write-host "Local Sender  = "$ThisUser
        Write-host "Recipient     = "$ExtOption.EmailRecipient
        Write-host "SMTP Server   = "$ExtOption.SmtpServer
        add-content -path $psscriptroot -value  $_.Error.Message
    }
}

Function GetSSH ($TargetIP,$Command,$Credential){
    Get-SSHSession | Select-Object SessionId | Remove-SSHSession | Out-Null  #--[ Remove any existing sessions ]--
    New-SSHSession -ComputerName $TargetIP -AcceptKey -Credential $Credential | Out-Null
    $Session = Get-SSHSession -Index 0 
    $Stream = $Session.Session.CreateShellStream("dumb", 0, 0, 0, 0, 1000)
    $Stream.Write("terminal Length 0 `n")
    Start-Sleep -Milliseconds 60
    $Stream.Read() | Out-Null
    $Stream.Write("$Command`n")
    sleep -millisec 100
    $ResponseRaw = $Stream.Read()
    $Response = $ResponseRaw -split "`r`n" | ForEach-Object{$_.trim()}
    while (($Response[$Response.Count -1]) -notlike "*#") {
        Start-Sleep -Milliseconds 60
        $ResponseRaw = $Stream.Read()
        $Response = $ResponseRaw -split "`r`n" | ForEach-Object{$_.trim()}
    }
    Return $Response
}

Function GetConsoleHost ($ExtOption){  #--[ Detect if we are using a script editor or the console ]--
    Switch ($Host.Name){
        'consolehost'{
            $ExtOption | Add-Member -MemberType NoteProperty -Name "ConsoleState" -Value $False -force
            $ExtOption | Add-Member -MemberType NoteProperty -Name "ConsoleMessage" -Value "PowerShell Console detected." -Force
        }
        'Windows PowerShell ISE Host'{
            $ExtOption | Add-Member -MemberType NoteProperty -Name "ConsoleState" -Value $True -force
            $ExtOption | Add-Member -MemberType NoteProperty -Name "ConsoleMessage" -Value "PowerShell ISE editor detected." -Force
        }
        'PrimalScriptHostImplementation'{
            $ExtOption | Add-Member -MemberType NoteProperty -Name "ConsoleState" -Value $True -force
            $ExtOption | Add-Member -MemberType NoteProperty -Name "COnsoleMessage" -Value "PrimalScript or PowerShell Studio editor detected." -Force
        }
        "Visual Studio Code Host" {
            $ExtOption | Add-Member -MemberType NoteProperty -Name "ConsoleState" -Value $True -force
            $ExtOption | Add-Member -MemberType NoteProperty -Name "ConsoleMessage" -Value "Visual Studio Code editor detected." -Force
        }
    }
    If ($ExtOption.ConsoleState){
        StatusMsg "Detected session running from an editor..." "Cyan" $ExtOption
    }
    Return $ExtOption
}

Function LoadConfig ($Config, $ExtOption){
    If ($Config -ne "failed"){
        $ExtOption | Add-Member -Force -MemberType NoteProperty -Name "Domain" -Value $Config.Settings.General.Domain    
        $ExtOption | Add-Member -Force -MemberType NoteProperty -Name "SourceIP" -Value $Config.Settings.General.SourceIP
        $ExtOption | Add-Member -Force -MemberType NoteProperty -Name "BrowserEnable" -Value $Config.Settings.General.BrowserEnable  
        $ExtOption | Add-Member -Force -MemberType NoteProperty -Name "Badping" -Value $Config.Settings.General.BadPing  
        $ExtOption | Add-Member -Force -MemberType NoteProperty -Name "PoorPing" -Value $Config.Settings.General.PoorPing  
        $ExtOption | Add-Member -Force -MemberType NoteProperty -Name "Repeat" -Value $Config.Settings.General.Repeat
        $ExtOption | Add-Member -Force -MemberType NoteProperty -Name "CredDrive" -Value $Config.Settings.Credentials.CredDrive
        $ExtOption | Add-Member -Force -MemberType NoteProperty -Name "PasswordFile" -Value $Config.Settings.Credentials.PasswordFile
        $ExtOption | Add-Member -Force -MemberType NoteProperty -Name "KeyFile" -Value $Config.Settings.Credentials.KeyFile
        $ExtOption | Add-Member -Force -MemberType NoteProperty -Name "EmailRecipient" -Value $Config.Settings.Email.EmailRecipient
        $ExtOption | Add-Member -Force -MemberType NoteProperty -Name "SmtpServer" -Value $Config.Settings.Email.SmtpServer
        $ExtOption | Add-Member -Force -MemberType NoteProperty -Name "EmailAltRecipient" -Value $Config.Settings.Email.EmailAltRecipient
        $ExtOption | Add-Member -Force -MemberType NoteProperty -Name "EmailSender" -Value $Config.Settings.Email.EmailSender
        $ExtOption | Add-Member -Force -MemberType NoteProperty -Name "EmailEnable" -Value $Config.Settings.Email.EmailEnable
        $ExtOption | Add-Member -Force -MemberType NoteProperty -Name "NewBaseline" -Value $False
        $ExtOption | Add-Member -Force -MemberType NoteProperty -Name "Columns" -Value 8  #--[ Total columns in report ]--
        $Targets = $Config.SelectNodes('//Target') | Select-Object -Expand '#text'
        $ExtOption | Add-Member -Force -MemberType NoteProperty -Name "TargetList" -Value $Targets
        $ExtOption = GetConsoleHost $ExtOption
    }Else{
        StatusMsg "MISSING XML CONFIG FILE.  File is required.  Script aborted..." " Red" $True
        $Message = (
'--[ External XML config file example ]-----------------------------------
--[ To be named the same as the script and located in the same folder as the script ]--
--[ Email settings in example are for future use.                                   ]--

<?xml version="1.0" encoding="utf-8"?>
<Settings>
    <General>
        <Domain>company.org</Domain>
        <SourceIP>10.10.10.1</SourceIP>
        <BrowserEnable>$true</BrowserEnable>
        <BadPing>100</BadPing>
        <PoorPing>50</PoorPing>
        <Repeat>15</Repeat>
    </General>
    <Credentials>
  		<CredDrive>c:</CredDrive>
        <PasswordFile>Pass.txt</PasswordFile>
        <KeyFile>Key.txt</KeyFile>
    </Credentials>    
    <Email>
        <EmailEnable>$true</EmailEnable>
        <EmailSender>InformationTechnology@company.org</EmailSender>
        <EmailRecipient>me@company.org</EmailRecipient>
        <EmailAltRecipient>you@company.org</EmailAltRecipient>
        <SmtpServer>mailserver.company.org</SmtpServer>
        <SmtpPort>25</SmtpPort>
    </Email>
    <Targets>
        <Target>10.1.1.1;Gateway</Target>
        <Target>10.1.1.2;Site Switch</Target>
    </Targets>    
</Settings> ')
Write-host $Message -ForegroundColor Yellow
    }
    Return $ExtOption
}

Function IsValidIPv4Address ($ip) {
    return ($ip -match "^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$" -and [bool]($ip -as [ipaddress]))
}

Function StatusMsg ($Msg, $Color, $ExtOption){
    If ($Null -eq $Color){
        $Color = "Magenta"
    }
    If ($ExtOption.Console){
        Write-Host "-- Script Status: " -NoNewline -ForegroundColor "Magenta"
        Write-host $Msg -ForegroundColor $Color
        }
    $Msg = ""
}

Function KillForm ($Form) {
    $Form.Close()
    $Form.Dispose()
}

Function Credentials ($ExtOption){
    #--[ Prepare Credentials ]--
    $UN = $Env:USERNAME
    $DN = $Env:USERDOMAIN
    $UID = $DN+"\"+$UN

    #--[ Test location of encrypted files, remote or local ]--
    If ($Null -eq $ExtOption.PasswordFile){
        $Credential = Get-Credential -Message 'Enter an appropriate Domain\User and Password to continue.'
        $ExtOption | Add-Member -Force -MemberType NoteProperty -Name "Credential" -Value $Credential
    }Else{
        If (Test-Path -path ($ExtOption.CredDrive+'\'+$ExtOption.PasswordFile)){
            $PF = ($ExtOption.CredDrive+'\'+$ExtOption.PasswordFile)
            $KF= ($ExtOption.CredDrive+'\'+$ExtOption.KeyFile)
        }Else{
            $PF = ($PSScriptRoot+'\'+$ExtOption.PasswordFile)
            $KF = ($PSScriptRoot+'\'+$ExtOption.KeyFile)
        }
        $Base64String = (Get-Content $KF)
        $ByteArray = [System.Convert]::FromBase64String($Base64String)
        $Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $UID, (Get-Content $PF | ConvertTo-SecureString -Key $ByteArray)
        $ExtOption | Add-Member -Force -MemberType NoteProperty -Name "Credential" -Value $Credential
    }
    Return $ExtOption
}

Function GetTargets ($ExtOption){
    <#--[ Future Use ]--
    $ListFileName = "$PSScriptRoot\IPlist.txt"
    If (Test-Path -Path $ListFileName){  
        $IPList = @()
        $IPList = Get-Content $ListFileName  
        StatusMsg "IP text file was found, loading IP list from it..." "green" $ExtOption
    }ElseIf ($ExtOption.TargetList -ne ""){
        $TargetList = $ExtOption.TargetList
    }Else{    
        Write-host "-- No IP list found...  Aborting." -ForegroundColor Red
        Break;Break;Break
    }#>

    If ($ExtOption.SourceIP -eq ""){
        [void][System.Reflection.Assembly]::LoadWithPartialName('Microsoft.VisualBasic')
        $SourceIP = [Microsoft.VisualBasic.Interaction]::InputBox("Please enter your target switch IP below...", "Target switch IP", "IP Address")
        $ExtOption | Add-Member -Force -MemberType NoteProperty -Name "SourceIP" -Value $SourceIP
    }

    If (!(IsValidIPv4Address $ExtOption.SourceIP)){
        STatusMsg "  --- No Valid Source IP.  Exiting ---" "red" $ExtOption
        Exit
    }
    Return $ExtOption
}

Function MainProcess ($ExtOption){
    StatusMsg "-- Begin --" "Cyan" $ExtOption
    $SourceIP = $ExtOption.SourceIP 
    StatusMsg ('Processing Target Switch: ['+$SourceIP+']') "Green" $ExtOption

    If (Test-Path -PathType leaf ("$PSScriptRoot\$SourceIP-Tracker.log")){
        $ObjTracker = Get-Content -path ("$PSScriptRoot\$SourceIP-Tracker.log") | ConvertFrom-StringData
    }Else{
        write-host "tracker failed"
        exit
    }

    #--[ Begin Processing of IP List ]--------------------------------------------
    $ErrorActionPreference = "stop"
    $Tracker = @()
    If (Test-Connection -ComputerName $SourceIP -count 1 -BufferSize 16 -Quiet){
        $Connection = $True
    }Else{
        Start-Sleep -Seconds 2
        If (Test-Connection -ComputerName $SourceIP -count 1 -BufferSize 16 -Quiet){
            $Connection = $True
        }Else{
            StatusMsg "--- No Connection ---" "Red" $ExtOption
            Exit
        }
    }

$HtmlData = '
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html>
<head>
<meta name="viewport" content="width=device-width, initial-scale=1">
</head>
<body>
    <div class="content">
    <table border-collapse="collapse" border="3" cellspacing="0" cellpadding="5" width="100%" bgcolor="#E6E6E6" bordercolor="black">
        <tr><td colspan='+$ExtOption.Columns+'><center><H2><font color=darkcyan><strong>Ping Latency Report</h2></td></tr>
        <tr><td colspan='+$ExtOption.Columns+'><center><strong>All pings are being initiated directly <u>from</u> switch '+$SourceIP+' </strong></center></td></tr>
        <tr>
            <td><strong><center>Source IP</center></td>
            <td><strong><center>Source Description</center></td>
            <td><strong><center>% success of '+$ExtOption.Repeat+' pings</center></td>
            <td><strong><center>Fastest of '+$ExtOption.Repeat+' Pings</center></td>
            <td><strong><center>Slowest of '+$ExtOption.Repeat+' Pings</center></td>            
            <td><strong><center>Average of '+$ExtOption.Repeat+' Pings</center></td>
            <td><strong><center>Running Average Ping</center></td>
            <td><strong><center>Current Baseline Ping</center></td>
            </tr>
'
    If ($Connection){
        ForEach ($IP in $ExtOption.TargetList){
            $HtmlData += '<tr>'
            $HtmlData += '<td>'+$IP.Split(";")[0]+'</td>'  #--[ column 1 / IP Address]--
            $HtmlData += '<td>'+$IP.Split(";")[1]+'</td>'  #--[ column 2 / Host name]--

            $Command = 'ping '+$IP.Split(";")[0]+' repeat '+$ExtOption.Repeat
            $Response = GetSSH $SourceIP $Command $ExtOption.Credential

            ForEach ($Line in $Response){
                If ($Line -like "*Success*"){
                    $Msg = "-- Ping Results to IP "+$IP.Split(";")[0]+" ("+$IP.Split(";")[1]+")"
                    StatusMsg $Msg "cyan" $ExtOption
                    $Percent = $Line.Split(" ")[3]
                    $Min =  ($Line.Split(" ")[9]).Split("/")[0]
                    $Av =  ($Line.Split(" ")[9]).Split("/")[1]
                    $Max =  ($Line.Split(" ")[9]).Split("/")[2]

                    If ([int]$Percent -lt $ExtOption.PoorPing){
                        $Msg = "  -- Out of "+$ExtOption.Repeat+" pings "+$Percent+" percent were successful."
                        StatusMsg $Msg "Yellow" $ExtOption    
                        $HtmlData += '<td><font color="red"><strong>'+$Percent+' %</font></strong></td>'   #--[ column 3 ]--
                    }Else{
                        $Msg = "  -- Out of "+$ExtOption.Repeat+" pings "+$Percent+" percent were successful."    #--[ column 3 ]--
                        StatusMsg $Msg "green" $ExtOption    
                        $HtmlData += '<td><font color="green">'+$Percent+' %</td>' 
                    }

                    #--[ Current Fastest ping (column 4) ]--
                    If ([int]$Min -ge $ExtOption.BadPing){
                        StatusMsg "  -- Fastest response $Min ms" "red" $ExtOption
                        $HtmlData += '<td><font color=red><strong>'+$Min+' ms</strong></font></td>' 
                    }ElseIf ([int]$Min -ge $ExtOption.PoorPing){
                        StatusMsg "  -- Fastest response $Min ms" "yellow" $ExtOption
                        $HtmlData += '<td><font color=orange><strong>'+$Min+' ms</strong></font></td>'
                    }Else{
                        StatusMsg "  -- Fastest response $Min ms" "green" $ExtOption
                        $HtmlData += '<td><font color=green>'+$Min+' ms</font></td>' 
                    }
                
                    #--[ Current Slowest ping (column 5) ]--
                    If ([int]$Max -ge $ExtOption.BadPing){
                        StatusMsg "  -- Average response $Max ms" "red" $ExtOption
                        $HtmlData += '<td><font color=red><strong>'+$Max+' ms</strong></font></td>' 
                    }ElseIf ([int]$Max -ge $ExtOption.PoorPing){
                        StatusMsg "  -- Average response $Max ms" "yellow" $ExtOption
                        $HtmlData += '<td><font color=orange><strong>'+$Max+' ms</strong></font></td>'
                    }Else{
                        StatusMsg "  -- Slowest response $Max ms" "green" $ExtOption
                        $HtmlData += '<td><font color=green>'+$Max+' ms</font></td>' 
                    }

                    #--[ Current Average ping (column 6) ]--
                    If ([int]$Av -ge $ExtOption.BadPing){
                        StatusMsg "  -- Average response $Av ms" "red" $ExtOption
                        $HtmlData += '<td><font color=red><strong>'+$Av+' ms</strong></font></td>' 
                    }ElseIf ([int]$Av -ge $ExtOption.PoorPing){
                        StatusMsg "  -- Average response $Av ms" "yellow" $ExtOption
                        $HtmlData += '<td><font color=orange><strong>'+$Av+' ms</strong></font></td>' 
                    }Else{
                        StatusMsg "  -- Average response $Av ms" "green" $ExtOption
                        $HtmlData += '<td><font color=green>'+[int]$Av+' ms</font></td>'  
                    }

                    #--[ Running average ping (column 7) ]--
                    [int]$RunAv = (([int]$Av)+(($ObjTracker.($IP.Split(";")[0])).Split("_")[0]))/2
                    If ([int]$RunAv -ge $ExtOption.BadPing){
                        StatusMsg "  -- Running Average $RunAv ms" "red" $ExtOption
                        $HtmlData += '<td><font color=red><strong>'+$RunAv+' ms</strong></font></td>' 
                    }ElseIf ([int]$RunAv -ge $ExtOption.PoorPing){
                        StatusMsg "  -- Running Average $RunAv ms" "yellow" $ExtOption
                        $HtmlData += '<td><font color=orange><strong>'+$RunAv+' ms</strong></font></td>'
                    }Else{
                        StatusMsg "  -- Running Average $RunAv ms" "green" $ExtOption
                        $HtmlData += '<td><font color=green>'+$RunAv+' ms</font></td>' 
                    }

                    #--[ Baseline value (column 8) ]--
                    If ($ExtOption.NewBaseline){
                        $Baseline = [int]$RunAv
                    }Else{
                        If ($Null -eq $ObjTracker.($IP.Split(";")[0]).Split("_")[1]){
                            write-host "--[ No baseline exists ]--"
                            $Baseline = $RunAv
                            #--[ Add new baseline ]--
                            $Tracker += ($IP.Split(";")[0])+"="+$RunAv+"_"+$Baseline
                        }Else{
                            $Baseline = [int]($ObjTracker.($IP.Split(";")[0]).Split("_")[1])
                            #--[ Perpetuate the pre-existing baseline ]--
                            $Tracker += ($IP.Split(";")[0])+"="+$RunAv+"_"+$Baseline                 
                        }
                        StatusMsg "  -- Baseline $Baseline ms" "green" $ExtOption
                        $HtmlData += '<td><font color=green>'+$Baseline+' ms</font></td>' 
                    }
                }
            }
            $HtmlData += '</tr>'
        }
    }Else{
        StatusMsg "--- No Connection ---" "Red" $ExtOption
        break;break;break
    }

    If (Test-Path -PathType leaf ("$PSScriptRoot/$SourceIP-Tracker.log")){
        Remove-Item -Path ("$PSScriptRoot/$SourceIP-Tracker.log") -Force
    }
    Add-Content -Path "$PSScriptRoot/$SourceIP-Tracker.log" -Value $Tracker

$HtmlData += "<tr><td colspan="+$ExtOption.Columns+"><h3>Ping results explained:</h3>For simplicity this explanation is from the viewpoint of an 
Internet gamer.  Gamers typically require high speed and low latency connections or they are unable to compete online.  The same can be 
said for network connections at work, a higher ping or latency will cause your applications to be slow or lock up.  Basically the 
lower your ping, the faster your connection.  A lower ping will make a gamer more competitive, and your applications perform better.  
That's the general rule, but we can narrow it down more specifically. <br><hr>
<font color=green>A ""Professional"" ping is 10ms or lower (0.01 seconds):</font><br>For competitive gamers in battles and tournaments, the slightest delay 
could mean game over. They want the lowest possible ping, so they're not dropping points or shots because of lag or glitches.<br><hr>
<font color=green>A ""Pretty decent"" ping is under 20ms (0.02 seconds):</font><br>Some gamers' idea of fun is live streaming their gameplay.  They aim for a 
ping as quick as this. At this level they experience crisp visuals and instant actions with no lag, or choppiness.<br><hr>
<font color=green>A ""Perfectly average"" ping is between 20ms-50ms (0.02-0.05 seconds):</font><br>Gamers will try to get below 50ms for playing ultra-competitive 
first person shooter and racing games.  Most employer networks should be easily able to match this speed.<br><hr>
<font color=orange>A ""Poor"" ping is between 50ms-100ms (0.05-0.1 seconds):</font><br>A 100ms or lower ping can be tolerable. But when you're lagging this much, 
you'll lose the sense that you're playing in real time.  At work you can see slow load times in applications.  This ping range and lag 
often mean you're connected to a distant server. Depending on your game (or application) and its settings, you might be able to connect 
to a closer server to improve your ping.<br><hr>
<font color=red>An ""Unplayable"" ping is between 100ms-300ms (0.1-0.3 seconds):</font><br>Long delays are expected in this range. In fact, some online games 
reject your connection altogether when you're at 170ms or more. Massively multiplayer online games are playable with a high ping, but 
you'll still want to stay below 250ms. For real-time strategy games or player vs player, you'll need to stay below 150ms. If your ping 
is this high, you may want to consider another network provider.  At work this would indicate a serious issue with the network.</td>
</tr></td></tr>
<tr><td colspan="+$ExtOption.Columns+"><font color=darkcyan><center>Report generated at: $DateTime &nbsp;&nbsp;-&nbsp;&nbsp; Script Version: $ScriptVer</center></font></td></tr>
</table></div>"

    StatusMsg "Clearing run variables." "magenta" $ExtOption
    Remove-variable Response -ErrorAction "SilentlyContinue" 

    $HtmlData += '</body></html>'

    $Report = "$PSScriptRoot/Report.html"
    If (Test-Path -PathType leaf $Report){
        Remove-Item -Path $Report -Force
    }

    Add-Content -Path $Report -Value $HtmlData 
    Try{
        If ($ExtOption.BrowserEnable){
            iex $Report
        }
    }Catch{
        StatusMsg "Error loading report locally in browser." "red" $ExtOption
    }

    If ($ExtOption.EmailEnable){
        SendEmail $HtmlData $ExtOption
    }
}

#=[ End of Functions ]========================================================

#--[ Load external XML options file ]------------------------------------------------
$ExtOption = New-Object -TypeName psobject 
If ($Console){
    $ExtOption | Add-Member -Force -MemberType NoteProperty -Name "Console" -Value $True 
}
If ($Debug){
    $ExtOption | Add-Member -Force -MemberType NoteProperty -Name "Debug" -Value $True 
}
If ($Null -ne $TargetIP){
    $ExtOption | Add-Member -Force -MemberType NoteProperty -Name "SourceIP" -Value $SourceIP 
}

$ConfigFile = $PSScriptRoot+"\"+($MyInvocation.MyCommand.Name.Split("_")[0]).Split(".")[0]+".xml"
If (Test-Path $ConfigFile){                          #--[ Error out if configuration file doesn't exist ]--
    StatusMsg "Reading XML config file..." "Cyan" $ExtOption    
    [xml]$Config = Get-Content $ConfigFile           #--[ Read & Load XML ]--  
    $ExtOption = LoadConfig $Config $ExtOption
}Else{
    LoadConfig "failed"
    StatusMsg "MISSING XML CONFIG FILE.  File is required.  Script aborted..." " Red" 
    break;break;break
}

$ExtOption = Credentials $ExtOption

If ($Gui){
    #--[ Prep GUI ]------------------------------------------------------------------
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    [System.Windows.Forms.Application]::EnableVisualStyles()
    $Icon = [System.Drawing.SystemIcons]::Information

#   $ScreenSize = (Get-WmiObject -Class Win32_DesktopMonitor | Select-Object ScreenWidth,ScreenHeight)  --[ Depricated ]--
    $ScreenSize = (Get-CimInstance -Class Win32_DesktopMonitor | Select-Object ScreenWidth,ScreenHeight)

    If ($ScreenSize.Count -gt 1){  #--[ Detect multiple monitors ]--
        StatusMsg "More than 1 monitor detected..." "Magenta"
        ForEach ($Resolution in $ScreenSize){
            If ($Null -ne $Resolution.ScreenWidth){
                $ScreenWidth = $Resolution.ScreenWidth
                $ScreenHeight = $Resolution.ScreenHeight
                Break
            }
        }
    }Else{
        $ScreenWidth = $Resolution.ScreenWidth
        $ScreenHeight = $Resolution.ScreenHeight
    }

    #--[ Define Form ]--------------------------------------------------------------
    [int]$FormWidth = 300
    [int]$FormHeight = 150
    [int]$FormHCenter = ($FormWidth / 2)   # 170 Horizontal center point
    [int]$FormVCenter = ($FormHeight / 2)  # 209 Vertical center point
    [int]$ButtonHeight = 25
    [int]$TextHeight = 20

    #--[ Create Form ]---------------------------------------------------------------------
    $Form = New-Object System.Windows.Forms.Form    
    $Form.AutoSize = $False
    $Form.Size = [System.Drawing.Size]::new($FormWidth, $FormHeight)
    $Notify = New-Object system.windows.forms.notifyicon
    $Notify.icon = $Icon              #--[ NOTE: Available tooltip icons are = warning, info, error, and none
    $Notify.visible = $true
    $Form.Text = "Script Version: $ScriptName v$ScriptVer"
    $Form.StartPosition = "CenterScreen"
    $Form.KeyPreview = $true
    $Form.Add_KeyDown({if ($_.KeyCode -eq "Escape"){$Form.Close();$Stop = $true}})
    #$ButtonFont = new-object System.Drawing.Font("Microsoft Sans Serif Regular",9,[System.Drawing.FontStyle]::Bold)

    #--[ Form Title Label ]-----------------------------------------------------------------
    $FormLabelBox = new-object System.Windows.Forms.Label
    $FormLabelBox.Location = [System.Drawing.Point]::new(-37, 2)
    $FormLabelBox.size = new-object System.Drawing.Size(350,25)
    $FormLabelBox.TextAlign = 2 
    $FormLabelBox.Font = [System.Drawing.Font]::new("Segoe UI", 11)
    $FormLabelBox.Text = "Ping-from-Switch GUI Mode"
    $Form.Controls.Add($FormLabelBox)

    #--[ IP Address Label ]-----------------------------------------------------------------
    $Label1 = new-object System.Windows.Forms.Label
    $Label1.Text = "Target Switch IP:"
    $Label1.Location = [System.Drawing.Point]::new(30, 32)
    $Label1.Size = new-object System.Drawing.Size(90, 23) 
    $Form.Controls.Add($Label1)

    #--[ IP Address Textbox ]---------------------------------------------------------------
    $TextBox1 = new-object System.Windows.Forms.TextBox
    $TextBox1.Text = "        < IP Address >        "
    $TextBox1.TabIndex = 2
    $TextBox1.ForeColor = 'DarkCyan'
    $TextBox1.Location = [System.Drawing.Point]::new(120, 29)
    $TextBox1.Size = new-object System.Drawing.Size(125,25)
    $TextBox1.Add_GotFocus({
        $TextBox1.Text = ''
        $TextBox1.ForeColor = 'DarkGreen' #Black'
    })
    $Form.Controls.Add($TextBox1)

    #--[ Checkbox ]---------------------------------------------------------------------------
    $CheckBox1 = New-Object System.Windows.Forms.CheckBox
    $CheckBox1.Text = "Check here to update baseline."
    $CheckBox1.TabIndex = 3
    $CheckBox1.Location = [System.Drawing.Point]::new(53, 50)
    $CheckBox1.Size = new-object System.Drawing.Size(200,25)
    $Form.Controls.Add($CheckBox1)

    #--[ CLOSE Button ]------------------------------------------------------------------------
    $BoxLength = 100
    $ButtonLineLoc = $FormHeight-75
    $CloseButton = new-object System.Windows.Forms.Button
    $CloseButton.Location = [System.Drawing.Point]::new(155, $ButtonLineLoc)
    $CloseButton.Size = new-object System.Drawing.Size($BoxLength,$ButtonHeight)
    $CloseButton.TabIndex = 1
    $CloseButton.Text = "Cancel/Close"
    $CloseButton.Add_Click({
        KillForm $Form
    })
    $Form.Controls.Add($CloseButton)

    #--[ EXECUTE Button ]--------------------------------------------------------------
    $ExecuteButton = new-object System.Windows.Forms.Button
    $ExecuteButton.Location = [System.Drawing.Point]::new(25, $ButtonLineLoc)
    $ExecuteButton.Size = new-object System.Drawing.Size($BoxLength,$ButtonHeight)
    $ExecuteButton.Enabled = $true 
    $ExecuteButton.Text = "Execute"
    $ExecuteButton.TabIndex = 4
    $ExecuteButton.Add_Click({
        $cnt = 5
        If (!(IsValidIPv4Address $TextBox1.Text.Trim())){
            While ($cnt -gt 0){
                $TextBox1.Text = ""
                Start-sleep -Milliseconds 500
                $TextBox1.Text = "  - Enter an IP Address -"
                Start-Sleep -Milliseconds 500
                $Cnt--
            }
        }Else{
            If ($CheckBox1.checked){
                $ExtOption | Add-Member -Force -MemberType NoteProperty -Name "NewBaseline" -Value $True
            }
            $ExtOption | Add-Member -Force -MemberType NoteProperty -Name "SourceIP" -Value $TextBox1.Text.Trim()
            $Form.Close()
            MainProcess $ExtOption
        }
    })
    $Form.Controls.Add($ExecuteButton)

    #--[ Open Form ]-------------------------------------------------------------
    $Form.topmost = $true
    $Form.Add_Shown({$Form.Activate()})
    [void] $Form.ShowDialog()
    if($Stop -eq $true){
        $Form.Close();break;break
    }
}Else{
    GetTargets $ExtOption
    MainProcess $ExtOption
}
Write-Host ""
StatusMsg "--- COMPLETED ---" "red" $ExtOption
 
