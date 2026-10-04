# Delphix Implementation Toolkit

Offline package for temporary Delphix implementation projects.

The OCI image includes `delphix-masking-helper`, `delphix_install_report`, `dct-toolkit`, Node.js 22,
Java 17 JRE, Python 3, `jq`, Knap, and the licensed JAR files required by the Masking Devkit.

The execution host does not need Java, Node.js, Python, npm, jq, or Knap installed. It only needs a
container runtime, preferably Podman on RHEL or Oracle Linux 9.

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
Podman on RHEL/OL 9
└── delphix-implementation-toolkit
    ├── HTTP service: delphix-masking-helper :3000
    ├── /home/delphix/.local/bin/cc-install-report
    ├── /home/delphix/.local/bin/cc_install_report.py
    ├── /home/delphix/.local/bin/cc_install_report_fetch.py
    ├── /home/delphix/.local/bin/cc_install_report_render.py
    └── /home/delphix/.local/bin/cc_install_report_*.md
    ├── /home/delphix/.local/bin/dct-toolkit
    ├── Java 17 JRE
    ├── Node.js 22 + Knap
    ├── Python 3 + jq
    └── Masking Devkit JAR files

External environment configuration
└── $HOME/.dct-toolkit/dct-toolkit.properties
    └── mounted as /root/.dct-toolkit/dct-toolkit.properties for one-off reports
```

The process inside the container runs as the unprivileged `delphix` user.

## Execution VM requirements

The VM must have:

- RHEL 9.x, Oracle Linux 9.x, or a compatible Linux distribution.
- x86-64 architecture for the current `dct-toolkit` build.
- Podman installed from repositories approved for the environment.
- Network connectivity to DCT and, when applicable, to the Masking Engine.
- Enough space for the image, volumes, and reports.

The VM does not require Internet access. The image archive is transferred using the approved
mechanism and loaded with `podman load`.

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

## Building the image

```bash
cd delphix-implementation-toolkit
chmod +x prepare-build-context.sh
./prepare-build-context.sh
podman build --tag localhost/delphix-implementation-toolkit:0.1.0 --file Dockerfile .build-context
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
test files, or the rest of the SDK. The same Dockerfile works with Docker by replacing `podman build`
with `docker build`.

The build requires Internet access or an accessible mirror to download the base image, Debian
Bookworm packages, npm dependencies, and Knap. The execution VM does not need Internet access after
receiving the completed image.

Node.js is not installed from Debian. It comes from the official `node:current-bookworm-slim` image.
The `current` tag selects the latest Current line published by Node.js. To force a base image refresh:

```bash
podman build --pull=always \
  --build-arg NODE_IMAGE=node:current-bookworm-slim \
  --tag localhost/delphix-implementation-toolkit:0.1.0 \
  --file Dockerfile .build-context
```

A specific line can also be selected:

```bash
podman build --pull=always \
  --build-arg NODE_IMAGE=node:24-bookworm-slim \
  --tag localhost/delphix-implementation-toolkit:0.1.0 \
  --file Dockerfile .build-context
```

Record the exact Node.js version after the build because `current` is a moving tag. For a
reproducible delivery, replace it with the exact tag published at that time.

During the build, npm uses `NPM_CONFIG_PREFIX=/usr/local`, with audit, fund, progress, and
update-notifier disabled. This makes the globally installed `knap` available at `/usr/local/bin`.

To pin an approved Knap version:

```bash
podman build --build-arg KNAP_VERSION=latest \
  --tag localhost/delphix-implementation-toolkit:0.1.0 \
  --file Dockerfile .build-context
```

## Masking Helper variables

| Variable | Use | Required |
|---|---|---|
| `PORT` | Helper HTTP port. The default is `3000`. | No |

The Masking Engine URL, username, and password are configured exclusively through the GUI and stored
in the SQLite database in the `dlpx-helper-db` volume. In an isolated network, enter the Masking
Engine IP address rather than a hostname unless the VM has verified DNS access. Include the required
protocol and port in the URL. No AI provider keys or `DLPX_PLUGIN_JAR` are required.

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

## Environment configuration

The following commands must be run by the user who performs the installation and runs Podman.
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

The file contains the DCT address and access token. Never include it in the Dockerfile, an `ARG`,
an `ENV` variable, the repository, or a public image. During a one-off report execution, the host
directory is mounted read-only at `/root/.dct-toolkit`. The report command intentionally runs as
root inside the short-lived container so that the DCT Toolkit and the report renderer use one
consistent configuration and can write to the host output directory. The permanent helper service
continues to run as the internal `delphix` user.

## Podman-managed volumes

```bash
podman volume create dlpx-helper-db
podman volume create dlpx-helper-files
```

| Volume | Internal path | Purpose |
|---|---|---|
| `dlpx-helper-db` | `/opt/delphix-masking-helper/db` | SQLite and helper configuration |
| `dlpx-helper-files` | `/home/delphix/test-files` | Local files and lookups |

## Network and firewall

The container also needs outbound connectivity to DCT and, when applicable, to the Masking Engine.
The required destination ports must be allowed by the network controls for the environment.

If the GUI must be accessed from another machine and the host uses RHEL or Oracle Linux with
`firewalld`, open only the published port:

```bash
sudo firewall-cmd --permanent --add-port=3000/tcp
sudo firewall-cmd --reload
sudo firewall-cmd --list-ports
```

For a temporary test, the rule may be added without `--permanent`. Do not disable `firewalld`
completely; restrict access to the required source network when the environment policy permits it.

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

## Permanent service with Quadlet

Before activating this service, verify that no manual execution is active. If one is active, stop it
with `podman stop delphix-masking-helper`.

Rootful Quadlet definitions belong in `/etc/containers/systemd/`. The rootless location
`~/.config/containers/systemd/` is different.

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

## Security

- The token is not included in the image.
- The properties file is mounted read-only.
- The process runs as `delphix`, not as root.
- The image contains licensed components and must use approved transfer channels.
- Reports may contain sensitive configuration information.
- At project completion, review transferred files and volumes before destroying the VM.

## Compatibility and known limitations

- The current `dct-toolkit` build is a Linux x86-64 static binary.
- The image targets x86-64 hosts.
- The VM needs network access to DCT; the container does not remove this dependency.
- Podman must be available on the host. If not, prepare its RPM packages and dependencies offline.
- The OCI image does not declare `HEALTHCHECK`; validate with `curl /api/version` and
  `systemctl`/`journalctl` when using Quadlet.
- VMware only hosts the Linux VM where Podman runs; the image does not depend on VMware version.

## Pending validations

1. Build the image from the current repositories.
2. Verify Node.js, Java, Python, jq, Knap, and `dct-toolkit` inside the container.
3. Test the helper against a Delphix laboratory environment.
4. Test the report with a non-production properties file.
5. Export the image, load it offline, and repeat the test on RHEL/OL 9.
6. Validate Quadlet and SELinux on the target operating system.
