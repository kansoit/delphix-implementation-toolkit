# Vendor files

This directory is reserved for externally supplied files that are required to prepare the OCI
build context but cannot be downloaded automatically or committed to this repository.

## DCT Toolkit binary

The image includes the official `dct-toolkit` binary so that the installation-report generator can
query Data Control Tower (DCT). Masking Helper does not require this binary.

Obtain the binary from the authorized Delphix/Perforce distribution portal using an account and
license approved for the environment. Do not download it from an unapproved mirror and do not
commit it to GitHub or GitLab.

Save the downloaded file with this exact path and name:

```text
vendor/dct-toolkit
```

Set its executable permission:

```bash
chmod 0755 vendor/dct-toolkit
```

Validate the file before preparing the build context:

```bash
file vendor/dct-toolkit
vendor/dct-toolkit --help
```

The preparation script verifies that this path exists and copies the binary into the image as:

```text
/home/delphix/.local/bin/dct-toolkit
```

If the binary is missing, `prepare-build-context.sh` stops with an error. The script never
downloads it automatically.

## DCT properties file

The DCT properties file is runtime configuration, not a build input. It contains the DCT URL and
an environment-specific encrypted API key. It must not be copied into the image, committed to Git,
or included in a public image archive.

The image-generation workflow does not require this file. Create it only on the host where an
installation report will be generated, following the instructions in the main README and the user
guides. The standard runtime location is:

```text
$HOME/.dct-toolkit/dct-toolkit.properties
```

The repository provides only a non-secret template:

```text
vendor/dct-toolkit.properties.example
```

Its structure is:

```properties
dctUrl=https://DCT_HOSTNAME_OR_IP/dct
apiKey=<ENCRYPTED_API_KEY_GENERATED_BY_DCT_TOOLKIT>
# insecureSSL=true
```

Do not place a real API key in `vendor/`. The `.gitignore` rules exclude local properties files.

## Build-context summary

Before running `prepare-build-context.sh`, the only required vendor file is:

```text
vendor/dct-toolkit
```

The properties template is documentation only. The real properties file is mounted read-only into
the short-lived report container when a report is generated.
