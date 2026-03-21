; Ctrl+Alt+V = remove newlines from clipboard and paste
^!v::
{
    A_Clipboard := StrReplace(StrReplace(A_Clipboard, "`r`n", " "), "`n", " ")
    Send "^v"
}
