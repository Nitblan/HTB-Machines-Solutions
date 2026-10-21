openssl s_client -connect 10.129.228.97:443 

sslscan https://brainfuck.htb/ 

ssh2john id_rsa > id_rsa.hash

john id_rsa.hash --wordlist=/usr/share/wordlists/seclists/Passwords/Leaked-Databases/rockyou.txt

