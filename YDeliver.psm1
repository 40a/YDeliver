#Requires -Version 2.0
Set-StrictMode -Version 2.0

Import-Module "$PSScriptRoot\Lib\psake\psake.psm1" -Force
Import-Module "$PSScriptRoot\lib\PowerYaml\PowerYaml.psm1" -Force
. "$PSScriptRoot\CommonFunctions\Get-Configuration.ps1"
. "$PSScriptRoot\CommonFunctions\Resolve-PathExpanded.ps1"
. "$PSScriptRoot\CommonFunctions\Write-ColouredOutput.ps1"

function Invoke-YBuild {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0, Mandatory = 0)][string[]] $tasks = @('Help'), 
        [Parameter(Position = 1, Mandatory = 0)][string] $buildVersion = "1.0.0",
        [Parameter(Position = 2, Mandatory = 0)][string] $rootDir = $pwd,
        [Parameter(Position = 3, Mandatory = 0)][switch] $listTasks
        )

    $buildFile = "$PSScriptRoot\YBuild\Build.Tasks.ps1"

    if($listTasks){
        Get-AvailableTasks $buildFile -Full
        return
    }

    $global:rootDir = $rootDir
    $global:yDir = $PSScriptRoot
    . "$PSScriptRoot\Conventions\Defaults.ps1"

    $buildConfig = Get-BuildConfiguration $rootDir

    Invoke-Psake $buildFile `
        -nologo `
        -framework $conventions.framework `
        -taskList $tasks `
        -parameters @{
            "buildVersion" = $buildVersion;
            "buildConfig" = $buildConfig;
            "conventions" = $conventions;
            "rootDir" = $rootDir;
    }

    if(-not $psake.build_success) { throw "YBuild failed!" }
}

function Invoke-YFlow {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0, Mandatory = 0)][string] $name = "default", 
        [Parameter(Position = 1, Mandatory = 0)][string] $rootDir = $pwd,
        [Parameter(Position = 2, Mandatory = 0)][switch] $listFlows,
        [Parameter(ParameterSetName = 'YBuild', Position = 3)][string] $buildVersion = "1.0.0"
        )

    $config = Get-Configuration $rootDir workflows
    $workflows = $config.workflow

    if($listFlows){
        return Out-WorkFlows $workflows
    }

    if(-not $workflows[$name]){
        throw "The workflow $name is not defined in your configuration"
    }

    $ybuildTasks = $workflows.$name.ybuild

    if($ybuildTasks){
        Invoke-YBuild $ybuildTasks $buildVersion
    }

}

function Invoke-YScaffold {
    [CmdletBinding()]
    param(
        [Parameter(Position = 0, Mandatory = 1)][string] $component, 
        [Parameter(Position = 1, Mandatory = 0)][string] $rootDir = $pwd,
        [Parameter(Position = 2, Mandatory = 0)][switch] $force
        )

    $componentPath = "$PSScriptRoot\YScaffold\$component"

    if(-not (Test-Path $componentPath -PathType Container)){
        throw "No scaffolding found for the component $component"
    }

    Write-ColouredOutput "Component $component" Yellow
    $config = Get-Configuration $componentPath config

    $config.Files.GetEnumerator() | %{ 
        $file = Split-Path $_.Name -Leaf
        $source = Join-Path "$componentPath\Files" $_.Name
        $destination = Join-Path (Expand-String $_.Value) $file
        Install-ScaffoldFile $source $destination -force:$force
    }
}

function Get-AvailableTasks($buildFile){
    Invoke-Psake $buildFile -docs -nologo
}

function Out-WorkFlows($workflows){
    $workflows.keys
}

function Install-ScaffoldFile($source, $destination, $force) {
    if((-not $force) -and (Test-Path $destination -PathType Leaf)){
        return "Exists $destination"
    }

    Copy-Item $source -Destination $destination -force:$force
    "{0} $destination" -f (?: $force "Replace" "Create")
}

function ?:([bool]$condition, $first, $second){
    if($condition){ return $first}
    $second
}

Export-ModuleMember -function Invoke-YBuild, Invoke-YFlow, Invoke-YScaffold