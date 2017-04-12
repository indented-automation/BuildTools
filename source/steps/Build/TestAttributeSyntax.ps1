BuildTask TestAttributeSyntax -Stage Build -Properties {
    Order          = 1
    Implementation = {
        $hasSyntaxErrors = $false
        foreach ($path in 'public', 'private', 'InitializeModule.ps1') {
            $path = Join-Path 'source' $path
            if (Test-Path $path) {
                Get-ChildItem $path -Filter *.ps1 -File -Recurse |
                    Where-Object { $_.Extension -eq '.ps1' -and $_.Length -gt 0 } |
                    ForEach-Object {
                        $tokens = $null
                        [ParseError[]]$parseErrors = @()
                        $ast = [Parser]::ParseInput(
                            (Get-Content $_.FullName -Raw),
                            $_.FullName,
                            [Ref]$tokens,
                            [Ref]$parseErrors
                        )

                        # Test attribute syntax
                        $attributes = $ast.FindAll( {
                                param( $ast )
                                
                                $ast -is [AttributeAst]
                            },
                            $true
                        )
                        foreach ($attribute in $attributes) {
                            if ($type = $attribute.TypeName.FullName -as [Type]) {
                                $propertyNames = $type.GetProperties().Name

                                if ($attribute.NamedArguments.Count -gt 0) {
                                    foreach ($argument in $attribute.NamedArguments) {
                                        if ($argument.ArgumentName -notin $propertyNames) {
                                            $message = 'Invalid property name in attribute declaration: {0} at line {1}, character {2}' -f
                                                $argument.ArgumentName,
                                                $argument.Extent.StartLineNumber,
                                                $argument.Extent.StartColumnNumber

                                            $errorRecord = New-Object System.Management.Automation.ErrorRecord(
                                                (New-Object ArgumentException $message),
                                                'InvalidAttributeArgument',
                                                'InvalidArgument',
                                                $attribute
                                            )

                                            Write-Error -ErrorRecord $errorRecord

                                            $hasSyntaxErrors = $true
                                        }
                                    }
                                }
                            } else {
                                $message = 'Invalid attribute declaration: {0} at line {1}, character {2}' -f
                                    $attribute.TypeName.FullName,
                                    $attribute.Extent.StartLineNumber,
                                    $attribute.Extent.StartColumnNumber

                                $errorRecord = New-Object System.Management.Automation.ErrorRecord(
                                    (New-Object ArgumentException $message),
                                    'InvalidAttribute',
                                    'InvalidArgument',
                                    $attribute
                                )

                                Write-Error -ErrorRecord $errorRecord
                            }
                        }
                    }
            }
        }
        if ($hasSyntaxErrors) {
            throw 'TestSyntax failed'
        }
    }
}