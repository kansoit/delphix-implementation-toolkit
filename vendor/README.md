# Archivos de vendor

Esta carpeta contiene archivos externos necesarios para preparar la imagen.

## dct-toolkit

Descargar `dct-toolkit` desde el portal oficial de Perforce/DCT usando una cuenta autorizada y
guardarlo con este nombre exacto:

```text
vendor/dct-toolkit
```

Luego asignar permisos de ejecución:

```bash
chmod 0755 vendor/dct-toolkit
```

El script `prepare-build-context.sh` toma el binario desde esta ubicación y lo incorpora a la
imagen como:

```text
/home/delphix/.local/bin/dct-toolkit
```

## dct-toolkit.properties

El archivo `dct-toolkit.properties` contiene la URL/IP de DCT y el token específico de cada cliente.
No se copia a la imagen y no debe publicarse ni confirmarse en Git.

Puede guardarse localmente como:

```text
vendor/dct-toolkit.properties
```

Para facilitar la preparación se incluye un ejemplo sin secretos:

```text
vendor/dct-toolkit.properties.example
```
