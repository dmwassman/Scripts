'.SYNOPSIS
'	Linux mail command
'.DESCRIPTION
'	Send email similar to Linux mail command
'.NOTES
'.OUTPUT
'	None
'.SYNTAX
'	mail.vbs [/a:<file path>] [/b:<email list>] [/c:<email list>] [/h] [/m:<server<:port>> [/e] [/u:<email>] [/p:<password>]] [/q:<file path>] [/r:<email>] [/s:<subject>] [/t:]<email list>[|<message>]
'.PARAMETER /a:<file path> (optional)
'	Attach the given file to message. Full name to file required
'.PARAMETER /b:<email list> (optional)
'	Send blind carbon copy to list. List should be semicolon-separated list
'.PARAMETER /c:<email list> (optional)
'	Send carbon copy to list. List should be semicolon-separated list
'.PARAMETER /e (optional)
'	Use SSL to send. Must use /m.
'.PARAMETER /h (optional)
'	Send email as HTML. Default is text
'.PARAMETER /m:<server:<port>> (optional)
'	SMTP server name or IP. Default port is 25
'.PARAMETER /p (optional)
'	User password. Used with /m
'.PARAMETER /q:<file path> (optional)
'	Use file as body. Full name to file required
'.PARAMETER /r:<email> (optional)
'	Email FROM field
'.PARAMETER /s:<subject> (optional)
'	Email SUBJECT field
'.PARAMETER /t:<email list> (optional)
'	Email TO field
'.PARAMETER /u:<email> (optional)
'	User name. Used with /m
'.PARAMETER <email list>
'	Emails to send to. List should be semicolon-separated list
'.PARAMETER <message> (optional)
'	Email message if using /t.

Sub subSyntax()
	WScript.Echo "Sends email from the command line."
	WScript.Echo ""
	WScript.Echo "mail.vbs [/a:<file path>] [/b:<email list>] [/c:<email list>] [/h] [/m:<server> [/e] [/p:<port>]] [/q:<file path>] [/r:<email>] [/s:<subject>] [/t:]<email list>[|<message>]"
	WScript.Echo ""
	WScript.Echo "/a 					Attach the given file to message. Full name to file required"
	WScript.Echo "/b:<email list> 		Send blind carbon copy to list. List should be semicolon-separated list"
	WScript.Echo "/c:<email list> 		Send carbon copy to list. List should be semicolon-separated list"
	WScript.Echo "/e					Use SSL. Must be used with /m"
	WScript.Echo "/h 					Send email as HTML. Default is text"
	WScript.Echo "/m:<server:<port>>	SMTP server name or IP. Default port is 25"
	WScript.Echo "/p:<password>				User password. Used with /m"
	WScript.Echo "/q:<file path> 		Use file as body. Full name to file required"
	WScript.Echo "/r:<email>			Email FROM field"
	WScript.Echo "/s:<subject>			Email SUBJECT field"
	WScript.Echo "/t:<email list>		Email TO field"
	WScript.Echo "/u:<email>			User email. Used with /m"
	WScript.Echo "<email list>			Email to send to. List should be semicolon-separated list"
	WScript.Echo "<message>				Email message if using /t"
End Sub

Set objFSO = CreateObject("Scripting.FileSystemObject")

strBody = ""


If WScript.Arguments.Named.Exists("t") Then
	strTo = WScript.Arguments.Named.Item("t")
	If strTo = "" Then
		WScript.Echo "Invalid TO email address"
		subSyntax
		WScript.Quit(1)
	End If
	
	For Each strEmail In Split(strTo,";")
		If strEmail = "" Or Replace(strEmail,"@","") = strEmail Or Len(Replace(strEmail,"@","")) < Len(strEmail) - 1 Or Replace(Mid(strEmail,InStrRev(strEmail,"@")),".","") = Mid(strEmail,InStrRev(strEmail,"@")) Then
			WScript.Echo "Invalid TO email address: " & strEmail
			subSyntax
			WScript.Quit(1)
		End If
	Next
	If InStr(Wscript.Arguments.Item(Wscript.Arguments.Count - 1),"/") <> 1 Then
		strBody = Wscript.Arguments.Item(Wscript.Arguments.Count - 1)
	End If
Else
	strTo = WScript.Arguments.Item(WScript.Arguments.Count - 1)
End If

If WScript.Arguments.Named.Exists("a") Then
	strAttachment = WScript.Arguments.Named.Item("a")
	If strAttachment = "" Then
		WScript.Echo "Invalid attachment"
		subSyntax
		WScript.Quit(2)
	End If
	
	If Not objFSO.FileExists(strAttachment) Then
		WScript.Echo "Attachment file does not exists"
		subSyntax
		WScript.Quit(2)
	End If
Else
	strAttachment = ""
End If

If WScript.Arguments.Named.Exists("b") Then
	strBCC = WScript.Arguments.Named.Item("b")
	If strBCC = "" Then
		WScript.Echo "Invalid BCC email address"
		subSyntax
		WScript.Quit(3)
	End If
	
	For Each strEmail In Split(strBCC,";")
		If strEmail = "" Or Replace(strEmail,"@","") = strEmail Or Len(Replace(strEmail,"@","")) < Len(strEmail) - 1 Or Replace(Mid(strEmail,InStrRev(strEmail,"@")),".","") = Mid(strEmail,InStrRev(strEmail,"@")) Then
			WScript.Echo "Invalid BCC email address: " & strEmail
			subSyntax
			WScript.Quit(3)
		End If
	Next
Else
	strBCC = ""
End If

If WScript.Arguments.Named.Exists("c") Then
	strCC = WScript.Arguments.Named.Item("c")
	If strCC = "" Then
		WScript.Echo "Invalid CC email address"
		subSyntax
		WScript.Quit(4)
	End If
	
	For Each strEmail In Split(strCC,";")
		If strEmail = "" Or Replace(strEmail,"@","") = strEmail Or Len(Replace(strEmail,"@","")) < Len(strEmail) - 1 Or Replace(Mid(strEmail,InStrRev(strEmail,"@")),".","") = Mid(strEmail,InStrRev(strEmail,"@")) Then
			WScript.Echo "Invalid CC email address: " & strEmail
			subSyntax
			WScript.Quit(4)
		End If
	Next
Else
	strCC = ""
End If

If WScript.Arguments.Named.Exists("e") Then
	bolSSL = True
Else
	bolSSL = False
End If

If WScript.Arguments.Named.Exists("h") Then
	bolHTML = True
Else
	bolHTML = False
End If

If WScript.Arguments.Named.Exists("m") Then
	strSMTP = WScript.Arguments.Named.Item("m")
	If strSMTP = "" Then
		WScript.Echo "Invalid SMTP server"
		subSyntax
		WScript.Quit(5)
	End If
	
	If InStr(strSMTP,":") > 0 Then
		intPort = Split(strSMTP,":")(1)
		strSMTP = Split(strSMTP,":")(0)
	Else
		intPort = 25
	End If
	
	If intPort = "" Then
		Wscript.Echo "Invalid port"
		subSyntax
		Wscript.Quit(5)
	End If
Else
	strSMTP = ""
End If

If WScript.Arguments.Named.Exists("q") Then	
	strFile = WScript.Arguments.Named.Item("q")
	If strFile = "" Then
		WScript.Echo "Invalid file"
		subSyntax
		WScript.Quit(6)
	End If
	
	If Not objFSO.FileExists(strFile) Then
		WScript.Echo "File does not exists"
		subSyntax
		Wscript.Quit(6)
	End If
Else
	strFile = ""
End If

If WScript.Arguments.Named.Exists("r") Then
	strFrom = WScript.Arguments.Named.Item("r")
	If strFrom = "" Then
		WScript.Echo "Invalid FROM email address"
		subSyntax
		Wscript.Quit(7)
	End If
	
	If Replace(strFrom,"@","") = strFrom Or Len(Replace(strFrom,"@","")) < Len(strFrom) - 1 Or Replace(Mid(strFrom,InStrRev(strFrom,"@")),".","") = Mid(strFrom,InStrRev(strFrom,"@")) Then
		WScript.Echo "Invalid FROM email address: " & strFrom
		subSyntax
		WScript.Quit(7)
	End If
Else
	Set objAD = CreateObject("ADODB.Connection")
	Set objNet = CreateObject("WScript.Network")

	objAD.Provider = "ADsDSOObject"
	objAD.Open "ADSI"
	Set objADRS = objAD.Execute("SELECT mail FROM 'LDAP://" & objNet.UserDomain & "' WHERE objectClass = 'user' AND samAccountName = '" & objNet.UserName & "'")
	If Not objADRS.EOF Then
		strFrom = objADRS.Fields("mail")
		If Replace(strFrom,"@","") = strFrom Or Len(Replace(strFrom,"@","")) < Len(strFrom) - 1 Or Replace(Mid(strFrom,InStrRev(strFrom,"@")),".","") = Mid(strFrom,InStrRev(strFrom,"@")) Then
			WScript.Echo "Invalid FROM email address: " & strFrom
			subSyntax
			WScript.Quit(7)
		End If
	Else
		WScript.Echo "No FROM email address found"
		subSyntax
		Wscript.Quit(7)
	End If
End If

If WScript.Arguments.Named.Exists("s") Then
	strSubject = WScript.Arguments.Named.Item("s")
Else
	strSubject = ""
End If

If WScript.Arguments.Named.Exists("u") Then
	If WScript.Arguments.Named.Exists("p") Then
		strPassword = WScript.Arguments.Named.Item("p")
	Else
		WScript.Echo "No password"
		subSyntax
		WScript.Quit(8)
	End If

	strUser = WScript.Arguments.Named.Item("u")
	If strUser = "" Or Replace(strUser,"@","") = strUser Or Len(Replace(strUser,"@","")) < Len(strUser) - 1 Or Replace(Mid(strUser,InStrRev(strUser,"@")),".","") = Mid(strUser,InStrRev(strUser,"@")) Then
		WScript.Echo "Invalid user: " & strUser
		subSyntax
		WScript.Quit(8)
	End If
Else
	strUser = ""
	strPassword = ""
End If

Set objMail = CreateObject("CDO.Message")

objMail.Subject = strSubject
objMail.From = strFrom
objMail.To = strTo
If strBCC <> "" Then
	objMail.Bcc = strBCC
End If

If strCC <> "" Then
	objMail.Cc = strCC
End If

If strAttachment <> "" Then
	objMail.AddAttachment strAttachment
End If

If strBody = "" Then
	WScript.Echo "Type email message below. End with ^Z."
	WScript.Echo "--------------------------------------"
	strBody = WScript.StdIn.ReadAll
End If

If strFile <> "" Then
	Set objFile = objFSO.OpenTextFile(strFile,1)
	strBody = strBody & objFile.ReadAll
End If

If bolHTML Then
	objMail.HTMLBody = strBody
Else
	objMail.TextBody = strBody
End If

If strSMTP <> "" Then
	objMail.Configuration.Fields.Item("http://schemas.microsoft.com/cdo/configuration/sendusing") = 2
    objMail.Configuration.Fields.Item("http://schemas.microsoft.com/cdo/configuration/smtpserver") = strSMTP
	objMail.Configuration.Fields.Item("http://schemas.microsoft.com/cdo/configuration/smtpserverport") = intPort
    objMail.Configuration.Fields.Item("http://schemas.microsoft.com/cdo/configuration/smtpusessl") = bolSSL
	If strUser <> "" Then
		objMail.Configuration.Fields.Item("http://schemas.microsoft.com/cdo/configuration/smtpauthenticate") = cdoBasic
		objMail.Configuration.Fields.Item("http://schemas.microsoft.com/cdo/configuration/sendusername") = strUser
		objMail.Configuration.Fields.Item("http://schemas.microsoft.com/cdo/configuration/sendpassword") = strPassword
	End If
	
	objMail.Configuration.Fields.Update
End If

objMail.Send


 
