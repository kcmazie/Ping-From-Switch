<!---
<head>
<meta name="google-site-verification" content="SiI2B_QvkFxrKW8YNvNf7w7gTIhzZsP9-yemxArYWwI" />
</head>
-->
[![Minimum Supported PowerShell Version][powershell-minimum]][powershell-github]&nbsp;&nbsp;
[![GPLv3 license](https://img.shields.io/badge/License-GPLv3-blue.svg)](http://perso.crans.org/besson/LICENSE.html)&nbsp;&nbsp;
[![made-with-VSCode](https://img.shields.io/badge/Made%20with-VSCode-1f425f.svg)](https://code.visualstudio.com/)&nbsp;&nbsp;
![GitHub watchers](https://img.shields.io/github/watchers/kcmazie/Cisco-Device-Inventory?style=plastic)

[powershell-minimum]: https://img.shields.io/badge/PowerShell-5.1+-blue.svg 
[powershell-github]:  https://github.com/PowerShell/PowerShell
<span style="background-color:black">
# $${\color{Cyan}Powershell \space "Ping-From-Switch.ps1"}$$

#### $${\color{orange}Original \space Author \space : \space \color{white}Kenneth \space C. \space Mazie \space \color{lightblue}(kcmjr \space AT \space kcmjr.com)}$$

## $${\color{grey}Description:}$$ 
This script will SSH into the "source" Cisco switch and initiate a number of ICMP "pings" to a list of targets.
  Response times are gathered into an HTML report that is emailed and/or immediately displayed.  Average ping 
  times are tracked over time for each seperate target switch and displayed during subsequent runs.  If no 
  source IP is included in the configuration file you are prompted for one. 

Options like user, password, the source IP, and target list are externalized in a companion XML file so that nothing sensitive is contained within the script itself.

## $${\color{grey}Notes:}$$ 
* Normal operation is with no command line options.
* Powershell 5.1 is the minimal version required.
* The Powershell Posh-SSH module from the Powershell Gallery is required.

## $${\color{grey}Arguments:}$$ 
Command line options for testing: 
| Option | Description | Default Setting
| --------------------------- | ---------------------------------------------------------------------- | ----------------- |
| Console     | Set to true to enable local console result display. | Defaults to false | 
| Debug       | Generates extra console output for debugging. | Defaults to false | 

## $${\color{grey}Configuration:}$$ 
The script takes virtually all configuration from the companion XML file.  As previously noted the file must exist and if not found the script will abort.  A message will pop-up showing the basic settings should the file not be found.

The XML file broken down into multiple sections each of which falls under the section heading of "Settings".

* $${\color{darkcyan}"General"  Section:}$$ This section sets the run parameters such as username and password (or encrypted files to use), folder locations, email recipients, etc.
* $${\color{darkcyan}"Credentials"  Section:}$$ This section stores hard coded credentials or if left blank you will be shown a credential prompt.  If encrypted, pre-stored credentials are desired, use this: https://github.com/kcmazie/CredentialsWithKey
* $${\color{darkcyan}"Email"  Section:}$$ This section stores email addresses of potential status email recipients.
* $${\color{darkcyan}"Targets"  Section:}$$ This section lists ping targets and their description seperated by a semicolon.  
 
```xml
<?xml version="1.0" encoding="utf-8"?>
<Settings>
<Settings>
    <General>
        <Domain>company.org</Domain>
        <SourceIP>10.10.10.1</SourceIP>
        <BrowserEnable>$true</BrowserEnable>
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
</Settings>
```
   
### $${\color{grey}Screenshots:}$$ 
* Coming soon.
   
<!-- ![Initial GUI](https://github.com/kcmazie/Site-Check/blob/main/Screenshot1.jpg "Initial GUI") -->
  
### $${\color{grey}Warnings:}$$ 
* None. 

### $${\color{grey}Enhancements:}$$ 
Some possible future enhancements are:
* N/A

### $${\color{grey}Legal:}$$ 
Public Domain. Modify and redistribute freely. No rights reserved. 
SCRIPT PROVIDED "AS IS" WITHOUT WARRANTIES OR GUARANTEES OF ANY KIND. USE AT YOUR OWN RISK. NO TECHNICAL SUPPORT PROVIDED.

That being said, please let me know if you find bugs, have improved the script, or would like to help. 

### $${\color{grey}Credits:}$$  
Code snippets and/or ideas came from many sources including but not limited to the following: 
* Code snippets and/or ideas came from too many sources to list...
  
### $${\color{grey}Version \\& Change History:}$$ 
* Last Update by  : Kenneth C. Mazie 
  * Initial Release : v1.00 - 09-20-24 - Original release
  * Change History  : v1.10 - 00-00-00 - 
 </span>
