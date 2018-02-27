FROM microsoft/powershell:latest

ARG IMAGE_NAME=PSCodacy

LABEL maintainer="Aditya Patwardhan <adityap@microsoft.com>"

RUN pwsh -c Install-Module PSScriptAnalyzer -Force

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

ENTRYPOINT pwsh -c \
    "\$output = Invoke-ScriptAnalyzer -Path /src -ExcludeRule PSUseDeclaredVarsMoreThanAssignments -Recurse; \
     \$output | % { \
        \$fileName = \$_.ScriptPath.Trim('/src/'); \ 
        \$message = \$_.message; \
        \$patternId = \$_.RuleName.ToLower(); \
        \$line = \$_.line; \
        \$result = [ordered] @{ filename = \$fileName; message = \$message; patternId = \$patternId; line = \$line }; \
        \$result | ConvertTo-Json \
        } \
    "
