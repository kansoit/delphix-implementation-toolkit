# Delphix Implementation Toolkit

Offline package for temporary Delphix implementation projects.

The OCI image includes `delphix-masking-helper`, `delphix_install_report`, `dct-toolkit`, the current
Node.js line, Java 17 JRE, Python 3, `jq`, Knap, and the licensed JAR files required by the Masking
Devkit.

The execution host does not need Java, Node.js, Python, npm, jq, or Knap installed. It only needs a
container runtime. The image was created and functionally tested with Podman on Oracle Linux 9. As
an OCI image, it is expected to run on other Linux distributions with either Podman or Docker.

## Scope

The execution VM is temporary and is used during implementation. The image does not replace the
Masking Engine or Data Control Tower (DCT). The container requires network connectivity to the
private Delphix endpoints used by the scripts.

The image is shared across environments. Environment-specific information remains outside the image:

- DCT IP address or URL.
- Access token.
- Other `dct-toolkit` properties.
- Generated reports.
- The helper SQLite database and local files, when they must be retained during the project.

## Architecture

```text
delphix-implementation-toolkit
├── Masking Helper
│   ├── HTTP service on :3000
│   ├── /opt/delphix-masking-helper
│   ├── SQLite database at /opt/delphix-masking-helper/db
│   ├── server files at /home/delphix/test-files
│   └── Masking Devkit JAR files and Java runner
├── DCT Toolkit at /home/delphix/.local/bin/dct-toolkit
├── Installation reporting tools at /home/delphix/.local/bin/
└── Runtime dependencies: Node.js, Python, jq, Knap, and Java 17

External environment configuration
└── $HOME/.dct-toolkit/dct-toolkit.properties
    └── mounted as /root/.dct-toolkit/dct-toolkit.properties for one-off reports
```

The process inside the container runs as the unprivileged `delphix` user.

## Execution VM requirements

The VM must have:

- Any compatible Linux distribution with Podman or Docker installed.
- x86-64 architecture for the current `dct-toolkit` build.
- Podman or Docker installed according to the operating system's approved package procedure.
- Network connectivity to DCT and, when applicable, to the Masking Engine.
- Enough space for the image, volumes, and reports.

The VM does not require Internet access. The image archive is transferred using the approved
mechanism and loaded with the selected container runtime.

## Build sources

The Dockerfile uses these sources outside this project:

```text
../delphix-masking-helper
../delphix_install_report
../Masking_Devkit_23.0.0
```

In addition, `prepare-build-context.sh` takes `dct-toolkit` from `vendor/dct-toolkit`. This binary
must be downloaded from the authorized Perforce/DCT portal; see [vendor/README.md](vendor/README.md).

The toolkit path inside the image is always `/home/delphix/.local/bin/dct-toolkit`.

### Masking Devkit JAR files

The image includes the required JAR files from the official Delphix Continuous Compliance Masking
Devkit version `23.0.0`, located in:

```text
../Masking_Devkit_23.0.0/sdkTools/lib
```

The build preparation script copies only the required runtime libraries into:

```text
.build-context/delphix-masking-helper/lib
```

The current selection is:

```text
ant-1.10.13.jar
commons-codec-1.11.jar
commons-compiler-3.1.6.jar
commons-lang-2.6.jar
delphix-algorithm-plugin-2026.5.0-FINAL.jar
failureaccess-1.0.3.jar
guava-33.6.0-jre.jar
jackson-annotations-2.21.jar
jackson-core-2.21.5.jar
jackson-databind-2.21.5.jar
jackson-datatype-jdk8-2.21.5.jar
jackson-datatype-jsr310-2.21.5.jar
jackson-module-jsonSchema-2.21.5.jar
janino-3.1.6.jar
masking-extensibility-api-2026.5.0-FINAL.jar
```

The remainder of the Devkit is deliberately not copied into the image. The preparation script
fails if any required JAR is missing from the official Devkit directory.

## Building the image

```bash
cd delphix-implementation-toolkit
chmod +x prepare-build-context.sh
./prepare-build-context.sh
```

The build and runtime validation documented in this project were performed with Podman on Oracle
Linux 9. Docker is also supported by the same OCI image and equivalent Docker commands are
provided for other Linux distributions, although the Docker execution path was not the primary
validation environment for this project.

Build with Podman:

```bash
podman build --pull=always \
  --tag localhost/delphix-implementation-toolkit:0.1.0 \
  --file Dockerfile .build-context
```

Build with Docker:

```bash
docker build --pull \
  --tag delphix-implementation-toolkit:0.1.0 \
  --file Dockerfile .build-context
```

The script copies only the required files. It does not copy `node_modules`, local SQLite databases,
local test files, or the remainder of the Masking Devkit.

The Dockerfile uses an intermediate build stage. The final image receives only:

- The helper JavaScript backend and its `package.json`.
- Production npm dependencies.
- The compiled frontend and its runtime knowledge file.
- Required `classifiers`, `presets`, and their data/documentation files.
- `java-runner/AlgorithmRunner.jar`.
- The 15 selected Masking Devkit JAR files.
- Reporting scripts and templates.
- `dct-toolkit`.

The final image does not contain frontend source files, development dependencies, build tools, local
test files, or the rest of the SDK. The same Dockerfile is intended to work with Docker by replacing
the Podman commands with their Docker equivalents.

The build requires Internet access or an accessible mirror to download the base image, Debian
Bookworm packages, npm dependencies, and Knap. The execution VM does not need Internet access after
receiving the completed image.

Node.js is obtained from the official `node:current-bookworm-slim` base image, not from Debian
packages. The Podman command above refreshes that base image on every build.

If a specific Node.js major line is required, select it explicitly:

```bash
podman build --pull=always \
  --build-arg NODE_IMAGE=node:24-bookworm-slim \
  --tag localhost/delphix-implementation-toolkit:0.1.0 \
  --file Dockerfile .build-context
```

Record the exact Node.js version used for a delivery. The `current` tag moves over time, while a
specific tag makes the build easier to reproduce.

The build configures npm to install global tools under `/usr/local` and disables npm audit, fund,
progress, and update notifications. The default Knap version is `latest`; an approved version can
be selected with `--build-arg KNAP_VERSION=<version>`.

## Masking Helper variables

| Variable | Use | Required |
|---|---|---|
| `PORT` | Helper HTTP port. The default is `3000`. | No |

The Masking Engine URL, username, and password are configured exclusively through the GUI and stored
in the SQLite database in the `dlpx-helper-db` volume. In an isolated network, enter the Masking
Engine IP address rather than a hostname unless the VM has verified DNS access. Include the required
protocol and port in the URL. No AI provider keys or `DLPX_PLUGIN_JAR` are required.

After the helper is running, open `Settings > General` in the GUI and set **Server file directory**
to:

```text
/home/delphix/test-files
```

This is where the lookup files live. Use the absolute path above so it matches the mounted
`dlpx-helper-files` volume.

For Quadlet, the port can be declared explicitly:

```ini
[Container]
Environment=PORT=3000
```

## Image verification

```bash
podman run --rm --entrypoint bash \
  localhost/delphix-implementation-toolkit:0.1.0 \
  -lc 'node --version; java -version; python3 --version; jq --version; knap --version; /home/delphix/.local/bin/dct-toolkit --help || true'
```

Verify the JAR files as well:

```bash
podman run --rm --entrypoint bash \
  localhost/delphix-implementation-toolkit:0.1.0 \
  -lc 'find /opt/delphix-masking-helper/lib -maxdepth 1 -name "*.jar" -printf "%f\\n" | sort'
```

Docker equivalents:

```bash
docker run --rm --entrypoint bash \
  delphix-implementation-toolkit:0.1.0 \
  -lc 'node --version; java -version; python3 --version; jq --version; knap --version; /home/delphix/.local/bin/dct-toolkit --help || true'

docker run --rm --entrypoint bash \
  delphix-implementation-toolkit:0.1.0 \
  -lc 'find /opt/delphix-masking-helper/lib -maxdepth 1 -name "*.jar" -printf "%f\\n" | sort'
```

## Offline export

```bash
podman save --output delphix-implementation-toolkit-0.1.0.tar \
  localhost/delphix-implementation-toolkit:0.1.0
gzip -9 delphix-implementation-toolkit-0.1.0.tar
sha256sum delphix-implementation-toolkit-0.1.0.tar.gz > delphix-implementation-toolkit-0.1.0.tar.gz.sha256
```

On the execution VM:

```bash
sha256sum --check delphix-implementation-toolkit-0.1.0.tar.gz.sha256
gunzip -c delphix-implementation-toolkit-0.1.0.tar.gz | podman load
```

Docker export/import equivalent:

```bash
docker save \
  --output delphix-implementation-toolkit-0.1.0.tar \
  delphix-implementation-toolkit:0.1.0
gzip -9 delphix-implementation-toolkit-0.1.0.tar
sha256sum delphix-implementation-toolkit-0.1.0.tar.gz > delphix-implementation-toolkit-0.1.0.tar.gz.sha256
```

On the execution host:

```bash
sha256sum --check delphix-implementation-toolkit-0.1.0.tar.gz.sha256
docker load --input delphix-implementation-toolkit-0.1.0.tar.gz
```

## DCT Toolkit and report configuration

Masking Helper does not require `dct-toolkit` or a DCT properties file. Its Masking Engine URL,
username, and password are configured through the GUI and stored in the helper SQLite database.

The following configuration is required only when using `delphix_install_report` or the bundled DCT
Toolkit. Run these commands as the user who performs the report operation with Podman or Docker.
Create the DCT configuration directory in that user's home directory:

```bash
mkdir -p "$HOME/.dct-toolkit"
chmod 0700 "$HOME/.dct-toolkit"
install -m 0644 dct-toolkit.properties \
  "$HOME/.dct-toolkit/dct-toolkit.properties"
```

The expected properties-file structure is:

```properties
dctUrl=https://DCT_HOSTNAME_OR_IP/dct
apiKey=<ENCRYPTED_API_KEY_GENERATED_BY_DCT_TOOLKIT>
# insecureSSL=true
```

Do not use the placeholders literally. The `apiKey` value should be written by `create_config` or
copied from a valid DCT Toolkit configuration. Enable `insecureSSL` only for a lab environment with
a self-signed certificate.

If the file must be generated with the bundled toolkit, write it directly to the operator's host
directory. Replace the URL with the DCT URL and enter the API key when prompted:

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

For a lab DCT using a self-signed certificate, append `--insecureSSL` to `create_config`. Do not
use `--env HOME=/home/delphix` with this command: when running as UID 0, Java resolves its home as
`/root`, and that is why the host directory is mounted at `/root/.dct-toolkit`.

After creating the file, make it readable by the operator and verify its ownership:

```bash
sudo chown "$(id -u):$(id -g)" "$HOME/.dct-toolkit/dct-toolkit.properties"
sudo chmod 0644 "$HOME/.dct-toolkit/dct-toolkit.properties"
```

The file contains the DCT address and access token for report generation. Keep it outside the
repository and the container image. When a report is generated, the host directory is mounted
read-only at `/root/.dct-toolkit` inside the temporary report container. This temporary container
runs as root so it can read the configuration and write the report to the host. The permanent
Masking Helper service continues to run as the internal `delphix` user.

Docker equivalent for generating the configuration:

```bash
docker run --rm -it \
  --user 0 \
  --hostname dlpx-toolkit \
  --add-host dlpx-toolkit:127.0.0.1 \
  --network host \
  --volume "$HOME/.dct-toolkit:/root/.dct-toolkit:Z" \
  delphix-implementation-toolkit:0.1.0 \
  /home/delphix/.local/bin/dct-toolkit \
  create_config \
  dctUrl="https://DCT_HOSTNAME_OR_IP/dct" \
  apiKey
```

## Managed volumes

The image build does not create or require these volumes. At runtime, Masking Helper uses two
managed volumes to retain its local data:

- `dlpx-helper-db` for the SQLite database and helper configuration.
- `dlpx-helper-files` for server files and lookup files.

They are mounted at `/opt/delphix-masking-helper/db` and `/home/delphix/test-files`, respectively.

```bash
podman volume create dlpx-helper-db
podman volume create dlpx-helper-files
```

Docker equivalent:

```bash
docker volume create dlpx-helper-db
docker volume create dlpx-helper-files
```

| Volume | Internal path | Purpose |
|---|---|---|
| `dlpx-helper-db` | `/opt/delphix-masking-helper/db` | SQLite and helper configuration |
| `dlpx-helper-files` | `/home/delphix/test-files` | Local files and lookups |

## Network and firewall

The container also needs outbound connectivity to DCT and, when applicable, to the Masking Engine.
The required destination ports must be allowed by the network controls for the environment.

### firewalld

If the GUI must be accessed from another machine and the host uses `firewalld`, open only the
published port:

```bash
sudo firewall-cmd --permanent --add-port=3000/tcp
sudo firewall-cmd --reload
sudo firewall-cmd --list-ports
```

For a temporary test, the rule may be added without `--permanent`. Do not disable `firewalld`
completely; restrict access to the required source network when the environment policy permits it.

### ufw

If the host uses `ufw`, allow the published port and verify the active rules:

```bash
sudo ufw allow 3000/tcp
sudo ufw status verbose
```

When possible, restrict the rule to the required source network instead of allowing all sources.
For a temporary test, remove the rule afterwards with:

```bash
sudo ufw delete allow 3000/tcp
```

## Manual helper execution

```bash
podman run --rm \
  --name delphix-masking-helper \
  --publish 3000:3000 \
  --volume dlpx-helper-db:/opt/delphix-masking-helper/db \
  --volume dlpx-helper-files:/home/delphix/test-files \
  localhost/delphix-implementation-toolkit:0.1.0
```

Manual execution and the Quadlet service must not be active at the same time. Stop one mode before
starting the other to avoid conflicts over the published port and managed volumes.

```bash
curl --fail http://127.0.0.1:3000/api/version
podman logs delphix-masking-helper
```

Docker equivalent for the manual helper container:

```bash
docker run -d \
  --name delphix-masking-helper \
  --publish 3000:3000 \
  --volume dlpx-helper-db:/opt/delphix-masking-helper/db \
  --volume dlpx-helper-files:/home/delphix/test-files \
  delphix-implementation-toolkit:0.1.0
```

The Docker command is provided for portability; the helper was functionally tested with Podman.

## Permanent service with Quadlet

Before activating this service, verify that no manual execution is active. If one is active, stop it
with `podman stop delphix-masking-helper`.

For a rootful Quadlet service on a systemd-based Linux host, place the definition in
`/etc/containers/systemd/`. The rootless location `~/.config/containers/systemd/` is different.

Quadlet is specific to Podman. Docker does not use Quadlet; use the Docker manual execution example
or an equivalent Docker Compose/service definition.

```ini
[Unit]
Description=Delphix Implementation Toolkit - Masking Helper
After=network-online.target
Wants=network-online.target

[Container]
Image=localhost/delphix-implementation-toolkit:0.1.0
ContainerName=delphix-masking-helper
PublishPort=3000:3000
Volume=dlpx-helper-db:/opt/delphix-masking-helper/db
Volume=dlpx-helper-files:/home/delphix/test-files

[Service]
Restart=always

[Install]
WantedBy=multi-user.target
```

Save as `/etc/containers/systemd/delphix-masking-helper.container` and activate:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now delphix-masking-helper.service
sudo systemctl status delphix-masking-helper.service
sudo journalctl -u delphix-masking-helper.service -f
```

The service does not run the report generator permanently.

## Docker Compose service

Docker does not use Quadlet. To keep the helper running as a Docker service, create
`docker-compose.yml`:

```yaml
services:
  masking-helper:
    image: delphix-implementation-toolkit:0.1.0
    container_name: delphix-masking-helper
    ports:
      - "3000:3000"
    volumes:
      - dlpx-helper-db:/opt/delphix-masking-helper/db
      - dlpx-helper-files:/home/delphix/test-files
    restart: unless-stopped

volumes:
  dlpx-helper-db:
    name: dlpx-helper-db
  dlpx-helper-files:
    name: dlpx-helper-files
```

Before starting Compose, verify that no manual or Quadlet helper container is running. Start and
stop the service with:

```bash
sudo docker compose -f docker-compose.yml up -d
sudo docker compose -f docker-compose.yml ps
sudo docker compose -f docker-compose.yml logs -f masking-helper
sudo docker compose -f docker-compose.yml down
```

The named volumes are retained by `down`. Do not add `--volumes` unless the helper configuration
and local files are no longer needed.

## Report generation

The report is a one-off operation:

```bash
mkdir -p "$HOME/delphix-reports"
sudo podman run --rm \
  --user 0 \
  --hostname dlpx-toolkit \
  --add-host dlpx-toolkit:127.0.0.1 \
  --network host \
  --volume "$HOME/delphix-reports:/home/delphix/reports:Z" \
  --volume "$HOME/.dct-toolkit:/root/.dct-toolkit:ro,Z" \
  localhost/delphix-implementation-toolkit:0.1.0 \
  cc-install-report \
    --client "Organization name" \
    --prefix "0-" \
    --output /home/delphix/reports/report.md \
    --template /home/delphix/.local/bin/cc_install_report_sp.md \
    --profile-set "ASDD Spanish"
```

The one-off report container runs as root only inside the short-lived container. This is intentional:
the DCT Toolkit resolves its configuration from the root Java home (`/root/.dct-toolkit`) and the
renderer must write to the host-owned output directory. The permanent helper service still runs as
the internal `delphix` user. The fixed hostname and `/etc/hosts` entry are required because DCT API
key encryption is tied to the local hostname.

`$HOME/delphix-reports` is created on the host and is mounted into the container as
`/home/delphix/reports`. The generated report therefore remains in the home directory of the user
who runs the command.

Docker equivalent for the one-off report:

```bash
mkdir -p "$HOME/delphix-reports"
docker run --rm \
  --user 0 \
  --hostname dlpx-toolkit \
  --add-host dlpx-toolkit:127.0.0.1 \
  --network host \
  --volume "$HOME/delphix-reports:/home/delphix/reports:Z" \
  --volume "$HOME/.dct-toolkit:/root/.dct-toolkit:ro,Z" \
  delphix-implementation-toolkit:0.1.0 \
  cc-install-report \
    --client "Organization name" \
    --prefix "0-" \
    --output /home/delphix/reports/report.md \
    --template /home/delphix/.local/bin/cc_install_report_sp.md \
    --profile-set "ASDD Spanish"
```

This Docker report command has not been functionally validated in this project.

## Security

- The token is not included in the image.
- The properties file is mounted read-only.
- The permanent Masking Helper process runs as `delphix`, not as root. The one-off report container
  intentionally runs as root to read the DCT configuration and write the report output.
- The image contains licensed components and must use approved transfer channels.
- Reports may contain sensitive configuration information.
- At project completion, review transferred files and volumes before destroying the VM.

## Compatibility and known limitations

- The current `dct-toolkit` build is a Linux x86-64 static binary.
- The image targets x86-64 hosts.
- The VM needs network access to DCT; the container does not remove this dependency.
- Podman or Docker must be available on the host. If the host is isolated, prepare the selected
  runtime and its dependencies through the approved offline procedure.
- The OCI image does not declare `HEALTHCHECK`; validate with `curl /api/version` and
  `systemctl`/`journalctl` when using Quadlet.

## Pending validations

1. Build the image from the current repositories.
2. Verify Node.js, Java, Python, jq, Knap, and `dct-toolkit` inside the container.
3. Test the helper against a Delphix laboratory environment.
4. Test the report with a non-production properties file.
5. Export the image, load it offline, and repeat the test on the target operating system.
6. Validate Quadlet and SELinux on the target operating system.
