
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

#strip extension from output file
$OutputFile = $XMLInput -replace ".{4}$"

#get float config file content
$configxml = [xml](Get-Content $XMLInput)

#Download latest settings.xml file 
Invoke-WebRequest -Uri "https://raw.githubusercontent.com/vedderb/vesc_pkg/main/float/float/conf/settings.xml" -Outfile .\settings.xml

#Download Defaults file then filter it
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

#declare colors
$redStyle = 'style="background-color:Red"'
$yellowStyle = 'style="background-color:Yellow"'
$greenStyle = 'style="background-color:Green"'


#loop through each setting
foreach ($setting in $settings) {
  #grab description for recommended range and clean up
  $description = $settingsxml.ConfigParams.Params.($setting.name).description
  $description = $description -replace '<[^>]+>',''
  $recommended = $description | Select-String -Pattern "Recommended Values:.*\d" | % {$_.Matches.Value}

  #clean up description output
  $desctrim = $description.Trim()
  $desctrim = $desctrim.Trimstart('p, li { white-space: pre-wrap; }')
  $desctrim = $desctrim.Trim()
  
  #get default settings
  $searchstr = $settingsxml.ConfigParams.Params.($setting.name).cDefine
  if ($SearchStr) { $default = $defaults | Where-Object {$_ -like "$SearchStr *"} | Select-Object -First 1
    $defaultvalue = $default.split()[-1]
  } else {
    $defaultvalue = 'None'
  }

  $configvalue = $configxml.CustomConfiguration.($setting.name)

  #Add to array
  $output += New-Object PsObject -Property ([ordered]@{'Parameter Name' = $setting.name;'Default Value' = $defaultvalue;'Current Value' = $configvalue;'Recommended Value' = $recommended;'Help Description' = $desctrim})

}


#Code for HTML color, credit here: https://petri.com/adding-style-powershell-html-reports/
$fragments = @()

[xml]$html = $Output | ConvertTo-Html -Fragment

for ($i=1;$i -le $html.table.tr.count-1;$i++) {
  if ($html.table.tr[$i].td[2] -ne $html.table.tr[$i].td[1]) {
    $class = $html.CreateAttribute("class")
    $class.value = 'red'
    $html.table.tr[$i].childnodes[2].attributes.append($class) | out-null
  }
}

$fragments+= $html.InnerXml

#Content for HTML export
$convertParams = @{
  head = @"
  <style>
    TABLE {margin: auto; border-width: 1px; border-style: solid; border-color: black; border-collapse: collapse;}
    TD {border-width: 1px; padding: 3px; border-style: solid; border-color: black;}
    .red    {background-color: #ff0000; text-align: right;}
    .yellow {background-color: #ffcc00; text-align: right;}
    .green  {background-color: #33cc00; text-align: right;}
  </style>
"@
body = $fragments
}


ConvertTo-Html @convertParams | Out-File $outputfile"_analyzer.html"