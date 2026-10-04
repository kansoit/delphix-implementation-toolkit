# Guía de usuario

## Delphix Implementation Toolkit

Esta guía describe el procedimiento completo para instalar y operar la imagen en una VM.

La VM es temporal y debe tener conectividad hacia los endpoints privados de Delphix. No es
necesario instalar Java, Node.js, Python, npm, jq ni Knap en el sistema operativo.

## Requisitos

- RHEL 9.x, Oracle Linux 9.x o Linux compatible.
- Arquitectura x86-64.
- Podman instalado.
- Acceso de red desde la VM hacia DCT y, cuando corresponda, hacia el Masking Engine.
- Archivo de imagen `delphix-implementation-toolkit-<version>.tar.gz`.

## Instalar Podman

En una VM con repositorios habilitados:

```bash
sudo dnf install -y podman
podman --version
podman info
```

En una VM aislada, Podman y sus dependencias deben obtenerse mediante el procedimiento offline
aprobado para el entorno.

## Cargar la imagen

Validar el archivo de la imagen del contenedor recibido:

```bash
sha256sum --check delphix-implementation-toolkit-<version>.tar.gz.sha256
```

Cargarlo:

```bash
gunzip -c delphix-implementation-toolkit-<version>.tar.gz | podman load
```

Confirmar:

```bash
podman images
```

## Configuración de DCT

Los siguientes comandos deben ejecutarse con el usuario que realiza la instalación y ejecuta
Podman. Crear el directorio de configuración de DCT en su home:

```bash
mkdir -p "$HOME/.dct-toolkit"
chmod 0700 "$HOME/.dct-toolkit"
```

Copiar el archivo de configuración correspondiente al entorno:

```bash
install -m 0644 \
  dct-toolkit.properties \
  "$HOME/.dct-toolkit/dct-toolkit.properties"
```

La estructura esperada del archivo de properties es:

```properties
dctUrl=https://DCT_HOSTNAME_OR_IP/dct
apiKey=<API_KEY_ENCRIPTADA_GENERADA_POR_DCT_TOOLKIT>
# insecureSSL=true
```

No se deben usar literalmente los valores entre `< >`. La propiedad `apiKey` debe ser generada con
`create_config` o copiada desde una configuración válida del DCT Toolkit. Activar `insecureSSL`
únicamente en un entorno de laboratorio con certificado autofirmado.

Para crear el archivo con el toolkit incluido en la imagen, usar el siguiente comando. Reemplazar la
URL de DCT e ingresar la API key cuando se solicite:

```bash
sudo podman run --rm -it \
  --user 0 \
  --hostname dlpx-toolkit \
  --add-host dlpx-toolkit:127.0.0.1 \
  --network host \
  --volume "$HOME/.dct-toolkit:/root/.dct-toolkit:Z" \
  localhost/delphix-implementation-toolkit:<version> \
  /home/delphix/.local/bin/dct-toolkit \
  create_config \
  dctUrl="https://DCT_HOSTNAME_OR_IP/dct" \
  apiKey
```

Para un DCT de laboratorio con certificado autofirmado, agregar `--insecureSSL` después de `apiKey`.

El archivo contiene la dirección de DCT y el token correspondiente al entorno. No es necesario
modificar la imagen para cambiar estos valores.

## Volúmenes

Crear los volúmenes administrados por Podman:

```bash
podman volume create dlpx-helper-db
podman volume create dlpx-helper-files
```

Los volúmenes almacenan:

| Volumen | Contenido |
|---|---|
| `dlpx-helper-db` | Configuración y algoritmos guardados en SQLite |
| `dlpx-helper-files` | Archivos auxiliares y lookups |

## Red y firewall

El contenedor también necesita conectividad de salida hacia DCT y, cuando corresponda, hacia el
Masking Engine. Los puertos de destino requeridos deben estar permitidos por los controles de red
del entorno.

Si la interfaz debe utilizarse desde otra máquina y RHEL u Oracle Linux utiliza `firewalld`, abrir
solamente el puerto publicado:

```bash
sudo firewall-cmd --permanent --add-port=3000/tcp
sudo firewall-cmd --reload
sudo firewall-cmd --list-ports
```

Para una prueba temporal puede omitirse `--permanent`. No se recomienda apagar `firewalld`
completamente; cuando la política del entorno lo permita, restringir el acceso a la red de origen.

## Iniciar el Masking Helper

Para una prueba manual:

```bash
sudo podman run --rm \
  --name delphix-masking-helper \
  --publish 3000:3000 \
  --volume dlpx-helper-db:/opt/delphix-masking-helper/db \
  --volume dlpx-helper-files:/home/delphix/test-files \
  localhost/delphix-implementation-toolkit:<version>
```

La ejecución manual y el servicio Quadlet no deben estar activos al mismo tiempo. Antes de
iniciar una de las modalidades, detener la otra para evitar conflictos por el puerto publicado
y por los volúmenes administrados.

Abrir:

```text
http://<ip-de-la-vm>:3000
```

Verificar:

```bash
curl --fail http://127.0.0.1:3000/api/version
podman logs delphix-masking-helper
```

## Configurar el Masking Engine desde la GUI

La URL, el usuario y la contraseña del Masking Engine se configuran desde la interfaz del helper.
La información queda almacenada en la SQLite del volumen `dlpx-helper-db`.

En una red aislada, ingresar preferentemente la dirección IP del Masking Engine en lugar de un
nombre DNS, salvo que la VM pueda resolverlo correctamente. Incluir en la URL el protocolo y el
puerto requeridos por el entorno.

No se deben definir esas credenciales en el Dockerfile ni en variables de entorno del host.

## Servicio permanente con Quadlet

Antes de activar este servicio, verificar que no exista una ejecución manual activa con el mismo
nombre, puerto o volúmenes. Si existe, detenerla con `podman stop delphix-masking-helper`.

Para que el helper arranque automáticamente, crear:

```text
/etc/containers/systemd/delphix-masking-helper.container
```

Contenido:

```ini
[Unit]
Description=Delphix Implementation Toolkit - Masking Helper
After=network-online.target
Wants=network-online.target

[Container]
Image=localhost/delphix-implementation-toolkit:<version>
ContainerName=delphix-masking-helper
PublishPort=3000:3000
Volume=dlpx-helper-db:/opt/delphix-masking-helper/db
Volume=dlpx-helper-files:/home/delphix/test-files
Environment=PORT=3000

[Service]
Restart=always

[Install]
WantedBy=multi-user.target
```

Activar:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now delphix-masking-helper.service
sudo systemctl status delphix-masking-helper.service
```

Logs:

```bash
sudo journalctl -u delphix-masking-helper.service -f
```

## Generar un reporte de instalación

El reporte se ejecuta bajo demanda, con el helper detenido o funcionando indistintamente:

```bash
mkdir -p "$HOME/delphix-reports"

podman run --rm \
  --user 0 \
  --hostname dlpx-toolkit \
  --add-host dlpx-toolkit:127.0.0.1 \
  --network host \
  --volume "$HOME/delphix-reports:/home/delphix/reports:Z" \
  --volume "$HOME/.dct-toolkit:/root/.dct-toolkit:ro,Z" \
  localhost/delphix-implementation-toolkit:<version> \
  cc-install-report \
    --client "Nombre de la organización" \
    --prefix "0-" \
    --output /home/delphix/reports/informe.md \
    --template /home/delphix/.local/bin/cc_install_report_sp.md \
    --profile-set "ASDD Spanish"
```

El reporte queda directamente en:

```text
$HOME/delphix-reports/informe.md
```

El contenedor puntual del reporte se ejecuta como root únicamente durante esa ejecución efímera.
La configuración se monta en `/root/.dct-toolkit`, que es la ubicación que utiliza Java cuando se
ejecuta con UID 0. El hostname fijo y la entrada de `/etc/hosts` son necesarios porque el cifrado
de la API key de DCT depende del hostname local. La carpeta `$HOME/delphix-reports` se crea en el
sistema anfitrión y se monta como `/home/delphix/reports`, por lo que el archivo queda disponible
en el home del usuario que ejecuta el comando.

## Diagnóstico rápido

```bash
podman ps -a
podman logs delphix-masking-helper
curl --fail http://127.0.0.1:3000/api/version
podman volume ls
```

Si se utiliza Quadlet, consultar los logs con:

```bash
sudo journalctl -u delphix-masking-helper.service -f
```

Si el reporte falla, verificar:

1. Que `$HOME/.dct-toolkit/dct-toolkit.properties` exista.
2. Que el archivo corresponda al entorno correcto.
3. Que la VM tenga conectividad hacia DCT.
4. Que el token no esté vencido.
5. Que el comando `dct-toolkit` responda dentro de la imagen.

## Finalización del proyecto

Antes de destruir la VM, copie los reportes requeridos y cualquier otro entregable. Luego revise
los procedimientos internos aplicables para eliminar:

```bash
podman volume rm dlpx-helper-db dlpx-helper-files
rm -f "$HOME/.dct-toolkit/dct-toolkit.properties"
```

La eliminación de los volúmenes borra la configuración y los datos locales del helper.
