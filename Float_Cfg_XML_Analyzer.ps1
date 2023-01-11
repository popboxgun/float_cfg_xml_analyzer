
<#! 
    
  Instructions
    - Run file in Powershell (double clicking might work).  Keep filter_list.txt in same folder as .ps1 file
        - If the powershell gives an error run the following in a PowerShell Window
            Set-ExecutionPolicy Bypass
    - Select exported .XML Float Config, it will output a .html file in the same folder as the float config .XML file that was selected
!#>

#Open file/folder dialog box to get users float cfg file
Add-Type -AssemblyName System.Windows.Forms

$FileBrowser = New-Object System.Windows.Forms.OpenFileDialog -Property @{ 
    InitialDirectory = [Environment]::GetFolderPath('Desktop') 
    Filter = 'XML File (*.xml)|*.xml'
    Title = 'Select Config file to open'
}

$null = $FileBrowser.ShowDialog()

#assign variable for input file
$XMLInput = $filebrowser.filename

#strip .xml from output file (put it back in on save)
$OutputFile = $XMLInput -replace ".{4}$"

#get config file content
$configxml = [xml](Get-Content $XMLInput)

#Download latest settings.xml file 
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/vedderb/vesc_pkg/main/float/float/conf/settings.xml" -Outfile .\settings.xml

#Download Defaults file
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/vedderb/vesc_pkg/main/float/float/conf/conf_default.h" -Outfile .\conf_default.h

$defaults = (Get-Content .\conf_default.h)
$defaults = $defaults | where {$_ -like "#define*"}
$defaults = $defaults -replace '#define '

#get settings file content
$settingsxml = [xml](Get-Content .\settings.xml)

#declare output array
$Output = @()

#grab settings names
$settings = $settingsxml.ConfigParams.Params | get-member -MemberType Property | Select-Object Name 

$redStyle = 'style="background-color:Red"'
$yellowStyle = 'style="background-color:Yellow"'
$greenStyle = 'style="background-color:Green"'


#loop through each setting
foreach ($setting in $settings) {
  #grab description for recommended range and clean up
  $description = $settingsxml.ConfigParams.Params.($setting.name).description
  $description2 = $description -replace '<[^>]+>',''
  $recommended = $description2 | Select-String -Pattern "Recommended Values:.*\d" | % {$_.Matches.Value}

  #clean up description output
  $desctrim = $description2.Trim()
  $desctrim2 = $desctrim.Trimstart('p, li { white-space: pre-wrap; }')
  $desctrim3 = $desctrim2.Trim()
  
  #get default settings
  $searchstr = $settingsxml.ConfigParams.Params.($setting.name).cDefine
  if ($SearchStr) { $default = $defaults | Where-Object {$_ -like "$SearchStr *"} | Select-Object -First 1
    $defaultvalue = $default.split()[-1]
  } else {
    $defaultvalue = 'None'
  }

  $configvalue = $configxml.CustomConfiguration.($setting.name)

  #Add to array
  $output += New-Object PsObject -Property ([ordered]@{'Parameter Name' = $setting.name;'Default Value' = $defaultvalue;'Current Value' = $configvalue;'Recommended Value' = $recommended;'Help Description' = $desctrim3})

}



#Header for HTML export
$Header = @"
<style>
TABLE {margin: auto; border-width: 1px; border-style: solid; border-color: black; border-collapse: collapse;}
TD {border-width: 1px; padding: 3px; border-style: solid; border-color: black;}
.red    {background-color: #ff0000; text-align: right;}
.yellow {background-color: #ffcc00; text-align: right;}
.green  {background-color: #33cc00; text-align: right;}
</style>
"@



$Output | ConvertTo-Html -Head $Header | Out-File $outputfile"_analyzer.html"