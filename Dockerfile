FROM mcr.microsoft.com/powershell

ARG IMAGE_NAME=PSCodacy

LABEL maintainer="Aditya Patwardhan <adityap@microsoft.com>"

RUN pwsh -c Install-Module PSScriptAnalyzer -Force -Confirm:\$false

RUN pwsh -c " \
\$null = New-Item -Type Directory /docs -Force; \
\$patterns = Get-ScriptAnalyzerRule | Where-Object { \$_.RuleName -ne 'PSUseDeclaredVarsMoreThanAssignments' } ;\
\$codacyPatterns = @(); \
foreach(\$pat in \$patterns) { \
    \$patternId = \$pat.RuleName.ToLower() ;   \
    \$level = if(\$pat.Severity -eq 'Information') { 'Info' } else { \$pat.Severity.ToString() } ;   \
    \$category = if(\$level -eq 'Info') { 'CodeStyle' } else { 'ErrorProne' } ;  \
    \$parameters = @([ordered]@{name = \$patternId; default = 'vars'}) ; \
    \$codacyPatterns += [ordered] @{ patternId = \$patternId; level = \$level; category = \$category; paramters = \$parameters } ;   \
}   \
\$patternFormat = [ordered] @{ name = 'psscriptanalyzer'; patterns = \$codacyPatterns} ;\
\$patternFormat | ConvertTo-Json -Depth 5 | Out-File /docs/patterns.json -Force -Encoding ascii; \
\$newLine = [system.environment]::NewLine; \
\$testFileContent = \"##Patterns: psavoidusingcmdletaliases $newLine function TestFunc {$newLine##Warn: psavoidusingcmdletaliases$newLinegps$newLine}\"; \
New-Item -ItemType Directory /docs/tests -Force | Out-Null ;\
\$testFileContent | Out-File /docs/tests/aliasTest.ps1 -Force"

RUN useradd -ms /bin/bash docker
USER docker
WORKDIR /src

CMD pwsh -c \
    "if (Test-Path '/src/.codacy.json') { \
        \$config = Get-Content '/src/.codacy.json' -Raw | ConvertFrom-Json ; \
        Write-Verbose \"ConfigFiles (\$(\$config.files.count)): \$(\$config.files)\" -Verbose; \
        \$files = \$config.files | ForEach-Object { Join-Path '/src' -ChildPath \$_ }; \
        \$rules = \$config.tools | Where-Object { \$_.name -eq 'psscriptanalyzer'} | ForEach-Object { \$_.patterns.patternId }; \
    } \
    if (\$null -eq \$rules) { \
        \$rules = '*' \
    } \
    Write-Verbose -Verbose \"Rules: \$rules Files: \$files\"; \
    if (\$null -eq \$files) { \
        \$output = Invoke-ScriptAnalyzer -Path /src -IncludeRule \$rules -ExcludeRule PSUseDeclaredVarsMoreThanAssignments -Recurse; \
    } else { \
        \$output = \$files | ForEach-Object { Invoke-ScriptAnalyzer -Path \$_ -IncludeRule \$rules -ExcludeRule PSUseDeclaredVarsMoreThanAssignments -Recurse; } \
    } \
     \$output | % { \
        \$fileName = \$_.ScriptPath.Trim('/src/'); \
        \$message = \$_.message; \
        \$patternId = \$_.RuleName.ToLower(); \
        \$line = \$_.line; \
        \$result = [ordered] @{ filename = \$fileName; message = \$message; patternId = \$patternId; line = \$line }; \
        \$result | ConvertTo-Json \
        } \
    "
