
# HTB - FTP and IIS

## Machine Information

| Information          | Details                            |
| -------------------- | ---------------------------------- |
| Target IP            | 10.129.69.20                       |
| Operating System     | Windows                            |
| Difficulty           | Not specified                      |
| FTP Service          | Microsoft FTP Service              |
| Web Server           | Microsoft IIS 7.5                  |
| Initial Access       | Anonymous FTP and ASPX upload      |
| Privilege Escalation | Metasploit Local Exploit Suggester |
| User Flag            | `db0d40d3d5c036c6d1a5e79afd8a14bb` |
| Root Flag            | `5fc45ba3bb1dc66f1ee3ea78cfe45a91` |

# 1. Reconnaissance

We begin with a full TCP port scan using Nmap. We save the results in grepable format (`-oG`) so that the discovered ports can be extracted programmatically later.

```bash
nmap -p- --open -sS --min-rate 5000 -vvv -n -Pn -oG Allports 10.129.69.20
```

The scan returns two open ports:

```text
# Nmap 7.991 scan initiated Sat Oct 10 18:04:28 2026 as: nmap -p- --open -sS --min-rate 5000 -vvv -n -Pn -oG Allports 10.129.69.20
# Ports scanned: TCP(65535;1-65535) UDP(0;) SCTP(0;) PROTOCOLS(0;)
Host: 10.129.69.20 ()	Status: Up
Host: 10.129.69.20 ()	Ports: 21/open/tcp//ftp///, 80/open/tcp//http///	Ignored State: filtered (65533)
# Nmap done at Sat Oct 10 18:04:55 2026 -- 1 IP address (1 host up) scanned in 26.48 seconds
```

The exposed services are:

* `21/tcp`: FTP
* `80/tcp`: HTTP

Since port 80 is open, we visit the website to inspect its contents. We also notice that the machine appears to be running Windows, which we can investigate further through service fingerprinting and a quick TTL check.

```bash
ping -c 1 10.129.69.20
```

A TTL of 128 is commonly associated with Windows systems. This is a useful clue, although TTL alone cannot conclusively identify the operating system.

# 2. Service Enumeration

We perform a targeted scan against ports 21 and 80 to identify the service versions and run default NSE scripts.

```bash
nmap -Pn -sVC -p21,80 -oN Targeted 10.129.69.20
```

The results are:

```text
# Nmap 7.991 scan initiated Sat Oct 10 18:05:04 2026 as: nmap -Pn -sVC -p21,80 -oN Targeted 10.129.69.20
Nmap scan report for 10.129.69.20
Host is up (0.084s latency).

PORT   STATE SERVICE VERSION
21/tcp open  ftp     Microsoft ftpd
| ftp-anon: Anonymous FTP login allowed (FTP code 230)
| 03-18-17  02:06AM       <DIR>          aspnet_client
| 03-17-17  05:37PM                  689 iisstart.htm
|_03-17-17  05:37PM               184946 welcome.png
| ftp-syst:
|_  SYST: Windows_NT
80/tcp open  http    Microsoft IIS httpd 7.5
| http-methods:
|_ Potentially risky methods: TRACE
|_http-server-header: Microsoft-IIS/7.5
|_http-title: IIS7
Service Info: OS: Windows; CPE: cpe:/o:microsoft:windows

Service detection performed. Please report any incorrect results at https://nmap.org/submit/ .
# Nmap done at Sat Oct 10 18:05:18 2026 -- 1 IP address (1 host up) scanned in 14.14 seconds
```

We have identified two important findings:

* The FTP service allows anonymous authentication.
* The web server is Microsoft IIS 7.5.

The anonymous FTP script also lists files and directories, including `iisstart.htm`, `welcome.png`, and `aspnet_client`.

Anonymous access means that we can inspect the FTP contents without knowing a valid account password. This provides an immediate avenue for further enumeration.

# 3. Anonymous FTP Access

We connect to the FTP server using the `anonymous` account.

```bash
ftp 10.129.69.20
```

When prompted for a username, we enter:

```text
anonymous
```

The server accepts the connection without requiring a meaningful password.

We can now enumerate the available files and directories using commands such as:

```text
ls
dir
```

The contents correspond to files associated with the website. This is particularly interesting because FTP and IIS may be configured to access the same underlying web directory.

If files uploaded through FTP become accessible through IIS, we may be able to upload a server-side script and execute it by requesting the corresponding URL.

# 4. Identifying the FTP-to-Web Upload Path

The target uses Microsoft IIS 7.5 and exposes an `aspnet_client` directory. This suggests that ASP.NET functionality may be present, making an `.aspx` file a potential candidate for testing server-side execution.

The critical point is that **FTP upload access alone does not guarantee remote code execution**. We must verify that the FTP directory maps to a location served by IIS and that the server is configured to execute uploaded ASPX files.

We have reason to investigate this because the FTP directory contains the website's default files.

We can inspect the FTP contents, test file upload permissions, and then check whether an uploaded file is accessible through the web server.

# 5. Uploading an ASPX Reverse Shell

After confirming that the relevant directory is writable and mapped to the website, we can test the ASP.NET execution path with a suitable ASPX shell.

The original approach is to search for a file named:

```text
shell.aspx
```

A reverse shell establishes a connection from the target back to our attacking machine, giving us an interactive command session.

We need to configure the callback address and port to match our attacking machine and start a listener before triggering the uploaded script.

Once the file is uploaded, requesting it through IIS may execute its server-side code. If successful, this provides initial access under the identity of the IIS application pool or other account configured to run the application.

# 6. Upgrading the Session with Meterpreter

A basic reverse shell is useful, but a Meterpreter session provides additional functionality for post-exploitation enumeration.

We therefore choose to use a Windows payload generated with `msfvenom` and establish a Meterpreter session.

The important operational steps are:

1. Generate a Windows payload compatible with the target and the Metasploit listener.
2. Upload the payload through the writable FTP-to-web path.
3. Configure the matching Metasploit handler.
4. Trigger execution through the application.
5. Confirm that the resulting session is a Meterpreter session.

The specific payload format, architecture, and callback settings must match the target environment and listener configuration.

Once the session is established, we enumerate the user's accessible files.

# 7. Retrieving the User Flag

The Meterpreter session allows us to inspect the target filesystem.

The Desktop directory contains the following files:

```text
Mode              Size  Type  Last modified              Name
----              ----  ----  -------------              ----
100666/rw-rw-rw-  282   fil   2017-03-17 08:17:51 -0600  desktop.ini
100444/r--r--r--  34    fil   2026-10-10 18:04:15 -0600  user.txt
```

We read the user flag:

```text
meterpreter > cat user.txt
db0d40d3d5c036c6d1a5e79afd8a14bb
meterpreter >
```

The user flag is:

```text
db0d40d3d5c036c6d1a5e79afd8a14bb
```

This confirms that we have obtained the first flag. The next objective is to determine whether the current security context can be escalated to Administrator.

# 8. Privilege Escalation Enumeration

Metasploit includes a module called `local_exploit_suggester` that checks the current session and operating system information against potential local privilege escalation modules.

The module can identify possible avenues for further investigation, but its suggestions are not proof that a vulnerability is exploitable. Findings must be validated against the target's actual configuration and patch level.

We run the suggester against our Meterpreter session and investigate the results.

During this process, we obtain an elevated session running as Administrator.

The important distinction is that the initial Meterpreter session and the elevated session may run under different security contexts. We must verify the identity of the new session rather than assume that launching the suggester itself grants privileges.

# 9. Retrieving the Root Flag

After obtaining Administrator access, we enumerate the Administrator's Desktop.

```text
Listing: c:\Users\Administrator\Desktop
=======================================

Mode              Size  Type  Last modified              Name
----              ----  ----  -------------              ----
100666/rw-rw-rw-  282   fil   2017-03-17 17:16:53 -0600  desktop.ini
100444/r--r--r--  34    fil   2026-10-10 18:04:15 -0600  root.txt
```

We read the root flag:

```text
meterpreter > cat root.txt
5fc45ba3bb1dc66f1ee3ea78cfe45a91
meterpreter >
```

The root flag is:

```text
5fc45ba3bb1dc66f1ee3ea78cfe45a91
```

We have now retrieved both flags.

# Attack Path

1. Full TCP scan discovers ports 21 and 80.
2. Targeted Nmap scan identifies Microsoft FTP and IIS 7.5.
3. Anonymous FTP access reveals the website's files.
4. FTP write access is investigated to determine whether the web root can be modified.
5. An ASPX reverse shell is uploaded to a web-accessible, executable location.
6. Initial access is established through IIS.
7. A Meterpreter session is obtained for post-exploitation.
8. The user flag is retrieved.
9. Metasploit's `local_exploit_suggester` is used to identify potential privilege escalation paths.
10. An elevated session as Administrator is obtained.
11. The root flag is retrieved from the Administrator's Desktop.

# Vulnerabilities & Techniques

## Anonymous FTP Access

The FTP server permits unauthenticated access, exposing files and directories that can reveal information about the website.

## Potential FTP-to-Web Directory Mapping

If FTP and IIS share a directory and the FTP account has write permissions, uploaded files may become accessible through HTTP. If server-side execution is enabled for the uploaded file type, this can create a remote code execution path.

## ASPX Reverse Shell

An ASPX script can execute server-side code when processed by a suitably configured IIS application. Successful exploitation depends on write access, directory mapping, and execution permissions.

## Meterpreter

Meterpreter provides an interactive post-exploitation session with functionality for filesystem access, system enumeration, and session management.

## Local Privilege Escalation Enumeration

Metasploit's `local_exploit_suggester` identifies candidate local privilege escalation modules based on the session and target information. Each candidate must be verified before its exploitability can be established.

## Administrator Access

The final privilege escalation results in a session running with Administrator privileges, allowing access to the root flag stored on the Administrator's Desktop.

# Lessons Learned

* Grepable Nmap output is useful when building repeatable enumeration workflows.
* Anonymous FTP access should always be investigated for both readable files and write permissions.
* A web server and an FTP service may expose the same underlying files, but this must be verified rather than assumed.
* An ASPX file can be dangerous when uploaded to a writable IIS directory that permits server-side execution.
* A Meterpreter session makes post-exploitation enumeration more convenient, but it does not automatically provide elevated privileges.
* Privilege escalation tools suggest possible vulnerabilities; their results should be validated against the target.
* Always verify the identity of an elevated session and retrieve the flags from the appropriate user directories.

pwned :)))))
