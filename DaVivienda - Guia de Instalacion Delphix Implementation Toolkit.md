---
title: DaVivienda - Guía de Instalación Delphix Implementation Toolkit
client: DaVivienda
profile_set: SV - Decreto 144 - v1
prefix: SV_
image_version: 0.1.0
tags:
  - davivienda
  - delphix
  - masking
  - instalacion
  - el-salvador
---

# DaVivienda - Guía de Instalación Delphix Implementation Toolkit

Esta guía describe el despliegue temporal del `Delphix Implementation Toolkit` para DaVivienda.
La imagen incluye:

- Delphix Masking Helper.
- DCT Toolkit.
- Generador de informes de instalación.
- Java 17, Node.js, Python y las dependencias requeridas.

La configuración de DCT y los datos generados durante la operación permanecen fuera de la imagen,
en el sistema anfitrión.

> [!warning] Alcance temporal
> Esta instalación está pensada para la etapa de implementación y puesta en marcha. No debe
> considerarse una instalación permanente del entorno productivo.

## 1. Recepción del archivo de imagen

Recibir el siguiente archivo:

```text
delphix-implementation-toolkit-0.1.0.tar.gz
```

Guardar el archivo en una carpeta de trabajo, por ejemplo:

```bash
mkdir -p "$HOME/delphix-images"
```

Validar la integridad del archivo recibido. El checksum debe compararse con el valor entregado junto
con la imagen:

```bash
sha256sum "$HOME/delphix-images/delphix-implementation-toolkit-0.1.0.tar.gz"
```

Para la imagen de referencia utilizada en esta guía, el checksum SHA-256 es:

```text
d2e436b2777324b391372741998fd1b61c30002f938be0e68d78bb2426ff20cf
```

> [!danger] No continuar con un archivo que no coincida
> Si el checksum no coincide, solicitar nuevamente el archivo de imagen antes de importarlo.

## 2. Requisitos del sistema anfitrión

El procedimiento está pensado para Oracle Linux o RHEL 9 con Podman instalado.

Verificar:

```bash
podman --version
sudo podman info
```

El sistema debe tener conectividad hacia:

- El servidor DCT.
- El Masking Engine.
- Los puertos requeridos por esos servicios.

No se requiere conectividad a Internet para ejecutar la imagen una vez que fue transportada al
servidor.

## 3. Importar la imagen

Importar la imagen con Podman:

```bash
gzip -dc "$HOME/delphix-images/delphix-implementation-toolkit-0.1.0.tar.gz" \
  | sudo podman load
```

Verificar que la imagen haya sido cargada:

```bash
sudo podman images localhost/delphix-implementation-toolkit
```

Debe aparecer:

```text
localhost/delphix-implementation-toolkit   0.1.0
```

## 4. Configuración del DCT Toolkit

Crear el directorio de configuración en el home del usuario que realiza la instalación:

```bash
mkdir -p "$HOME/.dct-toolkit"
chmod 0700 "$HOME/.dct-toolkit"
```

La estructura del archivo es:

```properties
dctUrl=https://DCT_HOSTNAME_OR_IP/dct
apiKey=<API_KEY_ENCRIPTADA_GENERADA_POR_DCT_TOOLKIT>
# insecureSSL=true
```

La propiedad `apiKey` no debe contener una clave en texto plano. Se recomienda generarla con el
toolkit incluido en la imagen:

```bash
sudo podman run --rm -it \
  --user 0 \
  --hostname dlpx-toolkit \
  --add-host dlpx-toolkit:127.0.0.1 \
  --network host \
  --volume "$HOME/.dct-toolkit:/root/.dct-toolkit:Z" \
  localhost/delphix-implementation-toolkit:0.1.0 \
  /home/delphix/.local/bin/dct-toolkit \
  create_config \
  dctUrl="https://DCT_HOSTNAME_OR_IP/dct" \
  apiKey
```

Ingresar la API key cuando el comando la solicite.

Para un laboratorio con certificado autofirmado, agregar `--insecureSSL` después de `apiKey`:

```bash
  apiKey \
  --insecureSSL
```

Verificar que el archivo exista:

```bash
ls -l "$HOME/.dct-toolkit/dct-toolkit.properties"
```

## 5. Crear los volúmenes persistentes

Crear los volúmenes que conservarán la base SQLite del helper y los archivos auxiliares:

```bash
sudo podman volume create dlpx-helper-db
sudo podman volume create dlpx-helper-files
```

Estos volúmenes permiten que la configuración administrada desde la interfaz web y los archivos de
trabajo sobrevivan al reemplazo del contenedor.

## 6. Iniciar Delphix Masking Helper

Iniciar el contenedor:

```bash
sudo podman run -d \
  --name delphix-masking-helper \
  --publish 3000:3000 \
  --volume dlpx-helper-db:/opt/delphix-masking-helper/db \
  --volume dlpx-helper-files:/home/delphix/test-files \
  localhost/delphix-implementation-toolkit:0.1.0
```

Verificar el estado:

```bash
sudo podman ps --filter name=delphix-masking-helper
curl --fail http://127.0.0.1:3000/api/version
```

La interfaz debe quedar disponible en:

```text
http://IP_DEL_SERVIDOR:3000
```

Si se utiliza `firewalld`, habilitar el puerto 3000:

```bash
sudo firewall-cmd --permanent --add-port=3000/tcp
sudo firewall-cmd --reload
```

No es necesario deshabilitar el firewall.

> [!warning] Ejecución única
> Esta guía utiliza ejecución manual. No iniciar simultáneamente una unidad Quadlet para el mismo
> servicio. Si se utiliza Quadlet, detener y eliminar primero el contenedor manual.

## 7. Configurar Masking Helper

Desde la interfaz web:

1. Agregar el Masking Engine correspondiente.
2. Ingresar la dirección IP del engine, no asumir resolución DNS desde el contenedor.
3. Probar la conexión.
4. Importar o sincronizar la configuración requerida.
5. Confirmar que el Profile Set esté disponible:

   ```text
   SV - Decreto 144 - v1
   ```

6. Confirmar que existan los algoritmos y clasificadores con prefijo `SV_`.

Para el directorio de archivos del servidor utilizar:

```text
/home/delphix/test-files
```

Ese directorio corresponde al volumen `dlpx-helper-files`.

## 8. Generar el informe de instalación

Crear el directorio de salida en el sistema anfitrión:

```bash
mkdir -p "$HOME/delphix-reports"
```

Ejecutar el informe para DaVivienda, utilizando el Profile Set de El Salvador y el prefijo `SV_`:

```bash
sudo podman run --rm \
  --user 0 \
  --hostname dlpx-toolkit \
  --add-host dlpx-toolkit:127.0.0.1 \
  --network host \
  --volume "$HOME/delphix-reports:/home/delphix/reports:Z" \
  --volume "$HOME/.dct-toolkit:/root/.dct-toolkit:ro,Z" \
  localhost/delphix-implementation-toolkit:0.1.0 \
  cc-install-report \
    --client "DaVivienda" \
    --prefix "SV_" \
    --output /home/delphix/reports/davivienda-sv-informe.md \
    --template /home/delphix/.local/bin/cc_install_report_sp.md \
    --profile-set "SV - Decreto 144 - v1"
```

El informe quedará en:

```text
$HOME/delphix-reports/davivienda-sv-informe.md
```

Verificarlo con:

```bash
ls -lh "$HOME/delphix-reports/davivienda-sv-informe.md"
```

El informe debe contener algoritmos `SV_`, clasificadores `SV_` y archivos de consulta como:

```text
sv-direcciones.txt
sv-nombres.txt
sv-apellidos.txt
```

## 9. Diagnóstico básico

Ver logs del helper:

```bash
sudo podman logs --tail 300 delphix-masking-helper
```

Verificar el contenedor y los volúmenes:

```bash
sudo podman ps -a
sudo podman volume ls
```

Si el informe falla, revisar:

1. Que `$HOME/.dct-toolkit/dct-toolkit.properties` exista.
2. Que la URL de DCT sea correcta.
3. Que la API key corresponda al DCT configurado.
4. Que el hostname `dlpx-toolkit` se mantenga igual al generar la configuración y el informe.
5. Que exista conectividad desde el servidor hacia DCT.
6. Que el nombre del Profile Set coincida exactamente con `SV - Decreto 144 - v1`.

## 10. Detener la instalación temporal

Detener el helper:

```bash
sudo podman stop delphix-masking-helper
```

Eliminar el contenedor sin eliminar los volúmenes:

```bash
sudo podman rm delphix-masking-helper
```

Los volúmenes `dlpx-helper-db` y `dlpx-helper-files` deben conservarse mientras sean necesarios.

> [!danger] Eliminación de datos
> No ejecutar `podman volume rm` sin confirmar previamente que la configuración y los archivos de
> trabajo ya no son necesarios.

## Referencias internas

- [[GUIA_USUARIO]]
- [[README]]
- [[DEVELOPER_REQUESTS]]
