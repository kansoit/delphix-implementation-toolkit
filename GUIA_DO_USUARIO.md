# Guia do usuário

## Delphix Implementation Toolkit

Este guia descreve como instalar e operar a imagem em uma VM.

A VM é temporária e deve ter conectividade com os endpoints privados da Delphix. Não é necessário
instalar Java, Node.js, Python, npm, jq ou Knap no sistema operacional.

## Requisitos

- Qualquer distribuição Linux compatível com Podman ou Docker Engine instalado.
- Arquitetura x86-64.
- Acesso de rede da VM ao DCT e, quando aplicável, ao Masking Engine.
- Arquivo de imagem `delphix-implementation-toolkit-<version>.tar.gz`.

## Instalar o Podman

Em uma VM Linux baseada em RPM com repositórios habilitados:

```bash
sudo dnf install -y podman fuse-overlayfs slirp4netns
podman --version
sudo podman info
```

Em uma VM isolada, obtenha o Podman e suas dependências pelo procedimento offline aprovado.

## Instalar o Docker Engine

No Debian, instale o Docker Engine pelo [repositório oficial do Docker](https://docs.docker.com/engine/install/debian/):

```bash
sudo apt-get update
sudo apt-get install -y ca-certificates curl
sudo install -m 0755 -d /etc/apt/keyrings
sudo curl -fsSL https://download.docker.com/linux/debian/gpg \
  -o /etc/apt/keyrings/docker.asc
sudo chmod a+r /etc/apt/keyrings/docker.asc

sudo tee /etc/apt/sources.list.d/docker.sources > /dev/null <<EOF
Types: deb
URIs: https://download.docker.com/linux/debian
Suites: $(. /etc/os-release && echo "$VERSION_CODENAME")
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc
EOF

sudo apt-get update
sudo apt-get install -y docker-ce docker-ce-cli containerd.io \
  docker-buildx-plugin docker-compose-plugin
sudo systemctl enable --now docker
sudo docker run hello-world
```

Para outras distribuições, siga o procedimento oficial correspondente. Use Podman ou Docker nos
comandos seguintes; não execute os dois contêineres do helper simultaneamente com a mesma porta e
os mesmos volumes.

## Carregar a imagem

Valide o arquivo da imagem do contêiner recebido:

```bash
sha256sum --check delphix-implementation-toolkit-<version>.tar.gz.sha256
```

Carregue a imagem:

```bash
gunzip -c delphix-implementation-toolkit-<version>.tar.gz | podman load
sudo podman images
```

Equivalente com Docker:

```bash
gunzip -c delphix-implementation-toolkit-<version>.tar.gz | sudo docker load
sudo docker images
```

## Configuração do DCT e dos relatórios

O Masking Helper não requer o DCT Toolkit nem um arquivo de properties do DCT. A URL, o usuário e
a senha do Masking Engine são configurados pela GUI.

A configuração a seguir só é necessária para gerar relatórios de instalação. Crie o diretório de
configuração do DCT no home do usuário que executa o relatório:

```bash
mkdir -p "$HOME/.dct-toolkit"
chmod 0700 "$HOME/.dct-toolkit"
install -m 0644 dct-toolkit.properties \
  "$HOME/.dct-toolkit/dct-toolkit.properties"
```

A estrutura esperada do arquivo de properties é:

```properties
dctUrl=https://DCT_HOSTNAME_OR_IP/dct
apiKey=<API_KEY_CRIPTOGRAFADA_GERADA_PELO_DCT_TOOLKIT>
# insecureSSL=true
```

Não use literalmente os valores entre `< >`. A propriedade `apiKey` deve ser gerada com
`create_config` ou copiada de uma configuração válida do DCT Toolkit. Ative `insecureSSL` somente
em um ambiente de laboratório com certificado autoassinado.

Para criar o arquivo com o toolkit incluído na imagem, use o comando a seguir. Substitua a URL do
DCT e informe a API key quando solicitado:

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

Para um DCT de laboratório com certificado autoassinado, acrescente `--insecureSSL` depois de
`apiKey`.

Equivalente com Docker:

```bash
sudo docker run --rm -it \
  --user 0 \
  --hostname dlpx-toolkit \
  --add-host dlpx-toolkit:127.0.0.1 \
  --network host \
  --volume "$HOME/.dct-toolkit:/root/.dct-toolkit" \
  delphix-implementation-toolkit:<version> \
  /home/delphix/.local/bin/dct-toolkit \
  create_config \
  dctUrl="https://DCT_HOSTNAME_OR_IP/dct" \
  apiKey
```

O arquivo contém o endereço do DCT e o token de acesso do ambiente. Não é necessário modificar a
imagem quando esses valores forem alterados.

Esses volumes não são criados durante a construção da imagem. O Masking Helper os utiliza durante a
execução para conservar dados locais:

- `dlpx-helper-db` armazena o banco SQLite e a configuração do helper.
- `dlpx-helper-files` armazena os arquivos do servidor e os lookups.

Eles são montados em `/opt/delphix-masking-helper/db` e `/home/delphix/test-files`,
respectivamente.

## Volumes

```bash
sudo podman volume create dlpx-helper-db
sudo podman volume create dlpx-helper-files
```

Equivalente com Docker:

```bash
sudo docker volume create dlpx-helper-db
sudo docker volume create dlpx-helper-files
```

| Volume | Conteúdo |
|---|---|
| `dlpx-helper-db` | `/opt/delphix-masking-helper/db` — configuração SQLite e algoritmos salvos |
| `dlpx-helper-files` | `/home/delphix/test-files` — arquivos do servidor e lookups |

## Rede e firewall

O contêiner também precisa de conectividade de saída para o DCT e, quando aplicável, para o
Masking Engine. As portas de destino necessárias devem ser permitidas pelos controles de rede do
ambiente.

### firewalld

Se a GUI precisar ser acessada de outra máquina e o host usar `firewalld`, abra somente a porta
publicada:

```bash
sudo firewall-cmd --permanent --add-port=3000/tcp
sudo firewall-cmd --reload
sudo firewall-cmd --list-ports
```

Para um teste temporário, omita `--permanent`. Não desative o `firewalld` completamente; restrinja
o acesso à rede de origem necessária quando a política do ambiente permitir.

### ufw

Se o host usar `ufw`, permita a porta publicada e verifique as regras ativas:

```bash
sudo ufw allow 3000/tcp
sudo ufw status verbose
```

Quando possível, restrinja a regra à rede de origem necessária. Para um teste temporário, remova-a
depois com:

```bash
sudo ufw delete allow 3000/tcp
```

## Iniciar o Masking Helper

Para um teste manual:

```bash
sudo podman run --rm \
  --name delphix-masking-helper \
  --publish 3000:3000 \
  --volume dlpx-helper-db:/opt/delphix-masking-helper/db \
  --volume dlpx-helper-files:/home/delphix/test-files \
  localhost/delphix-implementation-toolkit:<version>
```

A execução manual e o serviço Quadlet não devem estar ativos ao mesmo tempo. Pare uma modalidade
antes de iniciar a outra para evitar conflitos na porta publicada e nos volumes administrados.

Abra `http://<ip-da-vm>:3000` e verifique:

```bash
curl --fail http://127.0.0.1:3000/api/version
sudo podman logs delphix-masking-helper
```

Equivalente com Docker:

```bash
sudo docker run -d \
  --name delphix-masking-helper \
  --publish 3000:3000 \
  --volume dlpx-helper-db:/opt/delphix-masking-helper/db \
  --volume dlpx-helper-files:/home/delphix/test-files \
  delphix-implementation-toolkit:<version>
sudo docker logs delphix-masking-helper
```

## Configurar o Masking Engine pela GUI

Configure a URL, o usuário e a senha do Masking Engine pela interface do helper. As informações
ficam armazenadas no banco SQLite do volume `dlpx-helper-db`.

Em uma rede isolada, prefira informar o endereço IP do Masking Engine em vez de um nome DNS, salvo
quando a VM tiver a resolução DNS verificada. Inclua na URL o protocolo e a porta exigidos pelo
ambiente.

Não defina essas credenciais no Dockerfile nem nas variáveis de ambiente do host.

Depois que o helper estiver em funcionamento, abra `Settings > General` na GUI e defina **Server
file directory** com o valor:

```text
/home/delphix/test-files
```

Este é o diretório onde ficam os lookup files. Use o caminho absoluto para que ele corresponda ao
volume montado `dlpx-helper-files`.

## Serviço permanente com Quadlet

Antes de ativar o serviço, verifique se não existe uma execução manual ativa com o mesmo nome,
porta ou volumes. Se existir, pare-a com `podman stop delphix-masking-helper`.

Crie:

```text
/etc/containers/systemd/delphix-masking-helper.container
```

Quadlet é uma funcionalidade do Podman. O Docker não utiliza Quadlet; com Docker, use o comando
manual anterior ou uma definição equivalente de Docker Compose ou de serviço do sistema.

Use:

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

Ative o serviço e consulte os logs:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now delphix-masking-helper.service
sudo systemctl status delphix-masking-helper.service
sudo journalctl -u delphix-masking-helper.service -f
```

## Serviço com Docker Compose

O Docker não utiliza Quadlet. Para manter o helper como um serviço Docker, crie
`docker-compose.yml`:

```yaml
services:
  masking-helper:
    image: delphix-implementation-toolkit:<version>
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

Antes de iniciar o Compose, verifique se não há um helper manual ou Quadlet em execução:

```bash
sudo docker compose -f docker-compose.yml up -d
sudo docker compose -f docker-compose.yml ps
sudo docker compose -f docker-compose.yml logs -f masking-helper
sudo docker compose -f docker-compose.yml down
```

Os volumes administrados são mantidos ao executar `down`. Não acrescente `--volumes` enquanto a
configuração e os arquivos locais do helper ainda forem necessários.

## Gerar um relatório de instalação

O relatório é uma operação pontual e pode ser executado com o helper parado ou em execução:

```bash
mkdir -p "$HOME/delphix-reports"

sudo podman run --rm \
  --user 0 \
  --hostname dlpx-toolkit \
  --add-host dlpx-toolkit:127.0.0.1 \
  --network host \
  --volume "$HOME/delphix-reports:/home/delphix/reports:Z" \
  --volume "$HOME/.dct-toolkit:/root/.dct-toolkit:ro,Z" \
  localhost/delphix-implementation-toolkit:<version> \
  cc-install-report \
    --client "Nome da organização" \
    --prefix "0-" \
    --output /home/delphix/reports/relatorio.md \
    --template /home/delphix/.local/bin/cc_install_report_sp.md \
    --profile-set "ASDD Spanish"
```

Equivalente com Docker:

```bash
mkdir -p "$HOME/delphix-reports"
sudo docker run --rm \
  --user 0 \
  --hostname dlpx-toolkit \
  --add-host dlpx-toolkit:127.0.0.1 \
  --network host \
  --volume "$HOME/delphix-reports:/home/delphix/reports" \
  --volume "$HOME/.dct-toolkit:/root/.dct-toolkit:ro" \
  delphix-implementation-toolkit:<version> \
  cc-install-report \
    --client "Nome da organização" \
    --prefix "0-" \
    --output /home/delphix/reports/relatorio.md \
    --template /home/delphix/.local/bin/cc_install_report_sp.md \
    --profile-set "ASDD Spanish"
```

O relatório será gravado em `$HOME/delphix-reports/relatorio.md`.

O contêiner pontual do relatório é executado como root somente durante essa execução efêmera. A
configuração é montada em `/root/.dct-toolkit`, que é o local usado pelo Java quando executado com
UID 0. O hostname fixo e a entrada em `/etc/hosts` são necessários porque a criptografia da API
key do DCT depende do hostname local. A pasta `$HOME/delphix-reports` é criada no anfitrião e
montada como `/home/delphix/reports`; assim, o arquivo permanece no home do usuário que executa o comando.

## Diagnóstico

```bash
sudo podman ps -a
sudo podman logs delphix-masking-helper
curl --fail http://127.0.0.1:3000/api/version
sudo podman volume ls
```

Com Docker:

```bash
sudo docker ps -a
sudo docker logs delphix-masking-helper
sudo docker volume ls
```

Para consultar os logs do Quadlet, use `sudo journalctl -u delphix-masking-helper.service -f`.

Se o relatório falhar, verifique se o arquivo de propriedades existe e corresponde ao ambiente,
se a VM alcança o DCT, se o token está válido e se o `dct-toolkit` responde dentro da imagem.

## Finalização do projeto

Copie os relatórios e demais entregáveis antes de destruir a VM. Depois, revise os procedimentos
aplicáveis:

```bash
sudo podman volume rm dlpx-helper-db dlpx-helper-files
rm -f "$HOME/.dct-toolkit/dct-toolkit.properties"
```

Com Docker:

```bash
sudo docker volume rm dlpx-helper-db dlpx-helper-files
rm -f "$HOME/.dct-toolkit/dct-toolkit.properties"
```

A remoção dos volumes elimina a configuração e os dados locais do helper.
