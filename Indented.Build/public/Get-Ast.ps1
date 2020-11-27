function Get-Ast {
    <#
    .SYNOPSIS
        Get the abstract syntax tree for either a file or a scriptblock.
    .DESCRIPTION
        Get the abstract syntax tree for either a file or a scriptblock.
    #>

    [CmdletBinding(DefaultParameterSetName = 'FromPath')]
    [OutputType([System.Management.Automation.Language.ScriptBlockAst])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '')]
    param (
        # The path to a file containing one or more functions.
        [Parameter(Position = 1, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'FromPath')]
        [Alias('FullName')]
        [String]$Path,

        # A script block containing one or more functions.
        [Parameter(ParameterSetName = 'FromScriptBlock')]
        [ScriptBlock]$ScriptBlock,

        [Parameter(DontShow, ValueFromRemainingArguments)]
        $Discard
    )

    process {
        if ($pscmdlet.ParameterSetName -eq 'FromPath') {
            $Path = $pscmdlet.GetUnresolvedProviderPathFromPSPath($Path)

            try {
                $tokens = $errors = @()
                $ast = [System.Management.Automation.Language.Parser]::ParseFile(
                    $Path,
                    [Ref]$tokens,
                    [Ref]$errors
                )
                if ($errors[0].ErrorId -eq 'FileReadError') {
                    throw [InvalidOperationException]::new($errors[0].Message)
                }
            } catch {
                $errorRecord = @{
                    Exception = $_.Exception.GetBaseException()
                    ErrorId   = 'AstParserFailed'
                    Category  = 'OperationStopped'
                }
                Write-Error @ErrorRecord
            }
        } else {
            $ast = $ScriptBlock.Ast
        }

        $ast
    }
}
