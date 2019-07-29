FROM mcr.microsoft.com/powershell

ARG IMAGE_NAME=PSCodacy

LABEL maintainer="Aditya Patwardhan <adityap@microsoft.com>"

RUN pwsh -c Install-Module PSScriptAnalyzer -Force -Confirm:\$false -Scope AllUsers

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
    "\$splat = @{ \
        Recurse     = \$true; \
        Path        = '/src'; \
    }; \
    \
    switch (\$true) { \
        (Test-Path '/src/.codacy.json') { \
            # Get files and rules from .codacy.json \
            \$config = Get-Content '/src/.codacy.json' -Raw | ConvertFrom-Json ;  \
            Write-Verbose \"ConfigFiles (\$(\$config.files.count)): \$(\$config.files)\" -Verbose;  \
            \$files = \$config.files | ForEach-Object { Join-Path '/src' -ChildPath \$_ };  \
            \$rules = \$config.tools | Where-Object { \$_.name -eq 'psscriptanalyzer' } | ForEach-Object { \$_.patterns.patternId }; \
            \
            \$splat.IncludeRule = if (\$null -ne \$rules) { \
                \$rules \
            } \
            else { \
                '*' \
            }; \
            \$splat.ExcludeRule = 'PSUseDeclaredVarsMoreThanAssignments'; \
            break; \
        }; \
    \
        (Test-Path '/src/PSScriptAnalyzerSettings.psd1') { \
            \$splat.Settings = '/src/PSScriptAnalyzerSettings.psd1'; \
            break; \
        }; \
        Default { \
            \$splat.IncludeRule = '*'; \
            \$splat.ExcludeRule = 'PSUseDeclaredVarsMoreThanAssignments'; \
        }; \
    }; \
    \
    if (\$null -eq \$files) { \
        \$output = Invoke-ScriptAnalyzer @splat; \
    } \
    else { \
        \$output = \$files | ForEach-Object { \$splat.Path = \$_; Invoke-ScriptAnalyzer @splat; }; \
    }; \
    \
    \$output | ForEach-Object {  \
        \$fileName = \$_.ScriptPath.Trim('/src/');  \
        \$message = \$_.message;  \
        \$patternId = \$_.RuleName.ToLower();  \
        \$line = \$_.line;  \
        \$result = [ordered] @{ filename = \$fileName; message = \$message; patternId = \$patternId; line = \$line };  \
        \$result | ConvertTo-Json  \
    }"
