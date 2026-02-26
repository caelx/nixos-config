import re
import os

content = """Host jitsi1
    Hostname 10.250.130.125
    User root
    ProxyCommand ssh bastion-corp -W %h:%p

Host rsync2
    Hostname 10.250.20.170
    User user
    ProxyCommand ssh bastion-corp -W %h:%p

Host rchat1
    Hostname 10.250.130.112
    User root
    ProxyCommand ssh bastion-corp -W %h:%p

Host pritunl
    Hostname 10.250.200.10
    User ubuntu
    ProxyCommand ssh bastion-corp -W %h:%p

Host tiredtitan
    Hostname 10.250.130.131
    User ubuntu
    ProxyCommand ssh bastion-corp -W %h:%p

Host tiredtitan-minio
    Hostname 10.250.130.132
    User ubuntu
    ProxyCommand ssh bastion-corp -W %h:%p

Host tiredtitan2
    Hostname 10.250.130.132
    User user
    ProxyCommand ssh bastion-corp -W %h:%p

Host keycloak
    Hostname 10.250.130.130
    User ubuntu
    LocalForward 127.0.0.1:8443 127.0.0.1:8443
    LocalForward 127.0.0.1:9000 127.0.0.1:9000
    ProxyCommand ssh bastion-corp -W %h:%p

Host sftpgo-photo
    Hostname upload.thevisualstorytellers.com
    User ubuntu

Host sftpgo-dev
    Hostname upload.monolithtechnologies.com
    User ubuntu

Host sftpgo-photo2
    Hostname 3.142.41.19
    User ubuntu

Host bastion-corp
    Hostname 10.250.20.243
    User jochmann

Host sonar-prod
    Hostname 104.238.146.191
    User root

Host zap-api-dev
    Hostname 155.138.244.82
    User root

Host es-master-1
    Hostname localhost
    Port 2222
    LocalForward 127.0.0.1:9200 127.0.0.1:9200
    ProxyCommand ssh app-1 -W %h:%p

Host es-data-1
    Hostname 172.26.0.11
    ProxyCommand ssh es-master-1 -W %h:%p

Host es-data-2
    Hostname 172.26.0.12
    ProxyCommand ssh es-master-1 -W %h:%p

Host es-data-3
    Hostname 172.26.0.13
    ProxyCommand ssh es-master-1 -W %h:%p

Host pve-1
    User root
    Hostname 192.168.20.200
    LocalForward 127.0.0.1:8006 127.0.0.1:8006
    ProxyCommand ssh es-master-1 -W %h:%p

Host app-1
    Hostname 10.0.4.99
    ProxyCommand ssh bastion1 -W %h:%p

Host mlapi-1
    User ubuntu
    Hostname localhost
    Port 2223
    ProxyCommand ssh app-1 -W %h:%p

Host bastion1
    Hostname 54.189.37.121

Host kraken-prod-db
    User root
    Hostname 137.220.48.58
    LocalForward 127.0.0.1:6379 127.0.0.1:6379

Host kraken-prod-1
    User root
    Hostname 137.220.48.99

Host kraken-prod-2
    User root
    Hostname 45.32.202.242

Host kraken-dev-1
    User root
    Hostname 216.128.128.193

Host kraken-dev-2
    User root
    Hostname 45.76.56.216

Host scanner-01
    User ubuntu
    Hostname 3.144.223.0

Host scanner-02
    User ubuntu
    Hostname 3.142.143.211

Host scanner-03
    User ubuntu
    Hostname 18.221.142.182

Host scanner-04
    User ubuntu
    Hostname 18.191.29.71

Host scanner-05
    User ubuntu
    Hostname 3.144.180.97

Host scanner-06
    User ubuntu
    Hostname 54.180.101.131

Host scanner-07
    User ubuntu
    Hostname 54.180.105.122

Host scanner-08
    User ubuntu
    Hostname 43.200.182.95

Host scanner-09
    User ubuntu
    Hostname 15.164.97.100

Host scanner-10
    User ubuntu
    Hostname 3.34.181.144

Host scanner-11
    User ubuntu
    Hostname 54.194.43.67

Host scanner-12
    User ubuntu
    Hostname 3.250.156.41

Host scanner-13
    User ubuntu
    Hostname 63.35.251.14

Host scanner-14
    User ubuntu
    Hostname 34.240.252.97

Host scanner-15
    User ubuntu
    Hostname 34.243.67.229

Host scanner-16
    User ubuntu
    Hostname 35.183.29.63

Host scanner-17
    User ubuntu
    Hostname 3.96.174.40

Host scanner-18
    User ubuntu
    Hostname 35.183.102.96

Host scanner-19
    User ubuntu
    Hostname 15.222.253.172

Host scanner-20
    User ubuntu
    Hostname 3.99.247.52

Host 10.*
    ProxyCommand ssh bastion-corp -W %h:%p

Host 192.168.8.1
    HostKeyAlgorithms=+ssh-rsa
    PubkeyAcceptedAlgorithms=+ssh-rsa

Host 192.168.18.1
    HostKeyAlgorithms=+ssh-rsa
    PubkeyAcceptedAlgorithms=+ssh-rsa

Host 192.168.100.1
    HostKeyAlgorithms=+ssh-rsa
    PubkeyAcceptedAlgorithms=+ssh-rsa

Host storm-eagle
    User cael
    Hostname 104.5.66.11
    Port 2222
    LocalForward 127.0.0.1:443 127.0.0.1:443

Host *
    User james.ochmann
    IdentityFile ~/.ssh/id_ed25519
    ControlMaster auto
    ControlPath "~/.ssh/+%h-%p-%r"
    ControlPersist 5m
    ServerAliveInterval 60
    ServerAliveCountMax 30
    GSSAPIAuthentication no
    Compression yes
    ForwardAgent yes
    StrictHostKeyChecking accept-new
    UserKnownHostsFile ~/.ssh/known_hosts
    AddKeysToAgent yes
"""

blocks = re.split(r'\n(?=Host )', content.strip())
for block in blocks:
    lines = block.strip().split('\n')
    if not lines: continue
    match = re.match(r'Host\s+(.+)', lines[0])
    if match:
        hostname = match.group(1).strip()
        # Sanitize filename (replace * with wildcard)
        filename = hostname.replace('*', 'default')
        filename = re.sub(r'[^a-zA-Z0-9.-]', '_', filename)
        with open(f'old/ssh_hosts/{filename}', 'w') as f:
            f.write(block.strip() + '\n')
