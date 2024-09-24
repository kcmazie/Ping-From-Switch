<#==============================================================================
         File Name : Ping-From-Switch.ps1
   Original Author : Kenneth C. Mazie (kcmjr AT kcmjr.com)
                   : 
       Description : Script will SSH into the "source" Cisco switch and initiate a number of ICMP "pings"
                   : to a list of targets.  Response times are gathered into an HTML report that is emailed
                   : and/or immediately displayed.  Average ping times are tracked over time for each seperate
                   : target switch and displayed during subsequent runs.  If no source IP is included in the 
                   : configuration file you are prompted for one.
                   : 
             Notes : Normal operation is with no command line options.  If pre-stored credentials 
                   : are desired use this: https://github.com/kcmazie/CredentialsWithKey. If not included
                   : in the config file you will be prompted.
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
                   : Ping explenation text adapted from: https://www.virginmedia.com/blog/gaming/what-is-a-good-ping
                   : 
    Last Update by : Kenneth C. Mazie                                           
   Version History : v1.00 - 09-20-24 - Original release
    Change History : v1.10 - 00-00-00 - 
                   : #>
        $ScriptVer = "1.00"    <#--[ Current version # used in script ]--
==============================================================================#>
