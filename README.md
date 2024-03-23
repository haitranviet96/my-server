# My Data Center Server Build

-

# STEP TO SETUP SERVER

## 1. Install Ferdora Server

- Download iso package from Fedora.
- Copy it to 2 USB (or one copy on your connected drive). Use 1 USB as a boot drive. 1 USB as a storage contain iso file to install from
- Plug it in. Boot in 1 USB. Use other as Source file
- With 250GB storage, divide partition like this:
  - root ( / ) (ext4) : 150GiB
  - user (/user/home) (ext4) : 80GiB
  - swap: 2GiB
  - biosboot: 1MiB (if necessary)
- Setup root password
- Setup user+password (must)
- Continue to install
- When it done check if everything work
  - Get ip address by
  ```
  ip addr
  ```
  - Test SSH: use other computer to SSH over local
  ```
  ssh <user>@<ipaddr>
  ```
  - Test Cockpit available at `http://<ipaddr>:9090`

## 2. Install Tailscale

- https://tailscale.com/kb/1050/install-fedora
- Test if it working with Cockpit and SSH

## 3. Install Docker

- Clean old Docker

```bash
sudo dnf remove docker \
                  docker-client \
                  docker-client-latest \
                  docker-common \
                  docker-latest \
                  docker-latest-logrotate \
                  docker-logrotate \
                  docker-selinux \
                  docker-engine-selinux \
                  docker-engine
```

- Install the `dnf-plugins-core` package (which provides the commands to manage your DNF repositories) and set up the repository.

```
sudo dnf -y install dnf-plugins-core
sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
```

- Install Docker Engine, containerd, and Docker Compose:

```
sudo dnf install docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

- Start Docker.

```
sudo systemctl start docker
```

- Verify that the Docker Engine installation is successful by running the hello-world image.

```
sudo docker run hello-world
```

## 4. Disable SELinux
https://access.redhat.com/documentation/en-us/red_hat_enterprise_linux/6/html/security-enhanced_linux/sect-security-enhanced_linux-enabling_and_disabling_selinux-disabling_selinux

## 5. Install other applications
```
sudo dnf install git
```

## 6. Install GitHub Self-hosted Runner

- Get runner: https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners/adding-self-hosted-runners
- Setup services: https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners/configuring-the-self-hosted-runner-application-as-a-service

## 7. Install NVIDIA drivers & CUDA support

- Follow instruction here: https://rpmfusion.org/Howto/NVIDIA

## 8. Setup Wake on LAN
- Enable Wake on LAN in BIOS
- Verify and setup server if needed like this: https://wiki.archlinux.org/title/Wake-on-LAN 
- Follow instruction here: https://www.cyberciti.biz/tips/linux-send-wake-on-lan-wol-magic-packets.html