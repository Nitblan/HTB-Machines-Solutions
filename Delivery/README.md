primero hacemos nuestro escaneo de toda la vida, el mismo de siempre 



# Nmap 7.991 scan initiated Sat Oct 10 21:17:00 2026 as: nmap -p- --open -sS --min-rate 5000 -vvv -n -Pn -oG Allports 10.129.95.238
# Ports scanned: TCP(65535;1-65535) UDP(0;) SCTP(0;) PROTOCOLS(0;)
Host: 10.129.95.238 ()	Status: Up
Host: 10.129.95.238 ()	Ports: 80/open/tcp//http///, 135/open/tcp//msrpc///, 445/open/tcp//microsoft-ds///, 5985/open/tcp//wsman///	Ignored State: filtered (65531)


enumeramos servicios internos a ver que nos sale;

# Nmap done at Sat Oct 10 21:17:26 2026 -- 1 IP address (1 host up) scanned in 26.57 seconds
# Nmap 7.991 scan initiated Sat Oct 10 21:17:44 2026 as: nmap -Pn -sVC -p80,135,445,5985 -oN Targeted 10.129.95.238
Nmap scan report for 10.129.95.238
Host is up (0.077s latency).

PORT     STATE SERVICE      VERSION
80/tcp   open  http         Microsoft IIS httpd 10.0
|_http-server-header: Microsoft-IIS/10.0
| http-auth: 
| HTTP/1.1 401 Unauthorized\x0D
|_  Basic realm=MFP Firmware Update Center. Please enter password for admin
| http-methods: 
|_  Potentially risky methods: TRACE
|_http-title: Site doesn't have a title (text/html; charset=UTF-8).
135/tcp  open  msrpc        Microsoft Windows RPC
445/tcp  open  microsoft-ds Microsoft Windows 7 - 10 microsoft-ds (workgroup: WORKGROUP)
5985/tcp open  http         Microsoft HTTPAPI httpd 2.0 (SSDP/UPnP)
|_http-title: Not Found
|_http-server-header: Microsoft-HTTPAPI/2.0
Service Info: Host: DRIVER; OS: Windows; CPE: cpe:/o:microsoft:windows

Host script results:
| smb-security-mode: 
|   account_used: guest
|   authentication_level: user
|   challenge_response: supported
|_  message_signing: disabled (dangerous, but default)
| smb2-security-mode: 
|   3.1.1: 
|_    Message signing enabled but not required
| smb2-time: 
|   date: 2026-10-11T10:17:53
|_  start_date: 2026-10-11T10:14:07
|_clock-skew: mean: 6h59m59s, deviation: 0s, median: 6h59m59s

Service detection performed. Please report any incorrect results at https://nmap.org/submit/ .
# Nmap done at Sat Oct 10 21:18:13 2026 -- 1 IP address (1 host up) scanned in 28.48 seconds

vemos algo interesante, como vemos un smb, sabemos que el ttli es 128 por lo que es una windows estamos enfrentandonos a una maquina windows 



cuando entramos al http, vemos que nos piden credenciales, no las tenemos por lo que simplemente hacemos las de default 


user root y admin 

e ingresamos con admin admin 





@developers Please update theme to the OSTicket before we go live.  Credentials to the server are maildeliverer:Youve_G0t_Mail! 
8:30 AM

Also please create a program to help us stop re-using the same passwords everywhere.... Especially those that are a variant of "PleaseSubscribe!"


maildeliverer@Delivery:~$ cat user.txt 
c7415b55d81ef0c31e59fb26910c869e
maildeliverer@Delivery:~$ 

maildeliverer@Delivery:/opt/mattermost/config$ cat config.json

    "SqlSettings": {
        "DriverName": "mysql",
        "DataSource": "mmuser:Crack_The_MM_Admin_PW@tcp(127.0.0.1:3306)/mattermost?charset=utf8mb4,utf8\u0026readTimeout=30s\u0026writeTimeout=30s",
        "DataSourceReplicas": [],
        "DataSourceSearchReplicas": [],
        "MaxIdleConns": 20,
        "ConnMaxLifetimeMilliseconds": 3600000,
        "MaxOpenConns": 300,
        "Trace": false,
        "AtRestEncryptKey": "n5uax3d4f919obtsp1pw1k5xetq1enez",
        "QueryTimeout": 30,
        "DisableDatabaseSearch": false



| dijg7mcf4tf3xrgxi5ntqdefma | 1608992692294 | 1609157893370 |        0 | root                             | $2a$10$VM6EeymRxJ29r8Wjkr8Dtev0O.1STWb4.4ScG.anuu7v0EFJwgjjO | NULL     |             | root@delivery.htb       |             1 |          |                    |          |          | system_admin system_user |              1 | {}    | {"channel":"true","comments":"never","desktop":"mention","desktop_sound":"true","email":"true","first_name":"false","mention_keys":"","push":"mention","push_status":"away"} |      1609157893370 |                 0 |              0 | en     | {"automaticTimezone":"Africa/Abidjan","manualTimezone":"","useAutomaticTimezone":"true"}      |         0 |           |

System
8:25 AM

@root joined the team.
System
8:28 AM
@root updated the channel display name from: Town Square to: Internal
root
8:29 AM

@developers Please update theme to the OSTicket before we go live.  Credentials to the server are maildeliverer:Youve_G0t_Mail! 

Also please create a program to help us stop re-using the same passwords everywhere.... Especially those that are a variant of "PleaseSubscribe!"
root
9:58 AM

PleaseSubscribe! may not be in RockYou but if any hacker manages to get our hashes, they can use hashcat rules to easily crack all variations of common words or phrases.

contraseña despues de hashcat con el parametro de bcrypt -m 3200

PleaseSubscribe!21



root@Delivery:~# cat /root/root.txt 
40e9946cebcc50253f5efb069e6baf89
root@Delivery:~# 
