# LightDM Graphical → Shell → Graphical Cycle on Fedora Server

This guide describes how to set up a LightDM-based login loop that:
- Starts with a graphical login (LightDM)
- Power off the screen after 1 minute of inactivity on the LightDM greeter
- Authenticates the user
- Drops them into a console shell (tty1)
- Returns to LightDM automatically after they log out

---

## 🔧 Prerequisites

- Fedora Server with `Xorg` installed (`sudo dnf install xorg-x11-server-Xorg xset xinit`)
- `LightDM` with a greeter (e.g., `lightdm-gtk-greeter`)
- A local user (replace `youruser` with your actual username)
- Root/sudo access

---

## 🚀 Step-by-Step Setup

### 1. Install and Enable LightDM

```bash
sudo dnf install lightdm lightdm-gtk-greeter
sudo systemctl enable lightdm.service
```

---

### 2. Create a Custom LightDM Session

Create `/usr/share/xsessions/shellsession.desktop`:

```ini
[Desktop Entry]
Name=Console Login
Comment=Drop to virtual console after authentication
Exec=/usr/local/bin/lightdm-shellswitch.sh
Type=Application
NoDisplay=true
```

Force LightDM to use this session in `/etc/lightdm/lightdm.conf.d/10-shellsession.conf`:

```ini
[Seat:*]
user-session=shellsession
greeter-session=lightdm-gtk-greeter
```

---

### 3. Create the Shell Switch Script

Create `/usr/local/bin/lightdm-shellswitch.sh`:

```bash
#!/bin/bash
# Switch to tty1 then stop LightDM and 
sudo systemctl start tty1-autologin
/usr/bin/chvt 1
echo -e "\033c" > /dev/tty1

sudo systemctl stop lightdm
```

Make it executable:

```bash
sudo chmod +x /usr/local/bin/lightdm-shellswitch.sh
```

---

### 4. Allow Passwordless Commands

Create `/etc/sudoers.d/lightdm-shellswitch` with:

```bash
sudo visudo -f /etc/sudoers.d/lightdm-shellswitch
```

Add:

```sudoers
youruser ALL=(root) NOPASSWD: /usr/bin/systemctl stop lightdm
youruser ALL=(root) NOPASSWD: /usr/bin/systemctl start lightdm
youruser ALL=(root) NOPASSWD: /usr/bin/systemctl start tty1-autologin
```

Replace `youruser` with your actual username.

---

### 5. Enable tty1 Autologin

Create a custom autologin service: `/etc/systemd/system/tty1-autologin.service`:

```ini
[Unit]
Description=Autologin to tty1 after LightDM session
After=systemd-user-sessions.service
After=lightdm.service
Before=getty@tty1.service
Conflicts=getty@tty1.service

[Service]
ExecStart=-/sbin/agetty --autologin youruser tty1 linux
StandardInput=tty
StandardOutput=tty
Restart=no
TTYPath=/dev/tty1
TTYReset=yes
TTYVHangup=yes
KillMode=process
IgnoreSIGPIPE=no

[Install]
WantedBy=multi-user.target
```

Replace `youruser` with your actual username.

Then, disable the `tty1-autologin` unit from auto-starting:

```bash
sudo systemctl disable tty1-autologin.service
```
This ensures it **won’t activate on boot**, only when triggered by your script.

---

### 6. Restart LightDM on Logout (via `.zlogout`)

In your user’s home directory, edit `~/.zlogout`:

```zsh
# ~/.zlogout
if [[ "$(tty)" == "/dev/tty1" ]] && systemctl is-system-running --quiet; then
  sudo systemctl start lightdm
fi
```

> ✅ This ensures LightDM only restarts when:
> - The shell was running on tty1
> - The system is not shutting down
> - You're not logging out from SSH

---

### 7. Auto-Blank & Power-Off the Login Screen

To power off the screen after 1 minute of inactivity on the LightDM greeter:

#### 1. Create DPMS Setup Script

Create `/usr/local/bin/lightdm-dpms.sh`:

```bash
#!/bin/bash
# Configure X screensaver and DPMS for LightDM greeter
export DISPLAY=:0
export XAUTHORITY=/var/run/lightdm/root/:0

xset s 60 60         # Start screensaver after 60s
xset +dpms           # Enable DPMS
xset dpms 0 0 60     # Power off after 60s
```

Make it executable:

```bash
sudo chmod +x /usr/local/bin/lightdm-dpms.sh
```

#### 2. Hook into LightDM

Create `/etc/lightdm/lightdm.conf.d/60-dpms.conf`:

```ini
[Seat:*]
display-setup-script=/usr/local/bin/lightdm-dpms.sh
```

Restart LightDM:

```bash
sudo systemctl daemon-reload
sudo systemctl restart lightdm
```

### 8. (Optional) Debug Logging

To debug `.zlogout`, add:

```zsh
echo "[.zlogout] tty=$(tty), user=$USER, state=$(systemctl is-system-running)" >> ~/.zlogout.log
```

---

## ✅ Behavior Summary

| Scenario              | LightDM Restarts? |
|-----------------------|-------------------|
| Graphical login via LightDM → tty1 logout | ✅ Yes |
| SSH login & logout    | ❌ No              |
| Shutdown or reboot    | ❌ No              |
| Logout from other ttys| ❌ No              |

---

## 🧼 Cleanup Notes

To revert the setup:
- Set LightDM to default session again
- Remove `/usr/share/xsessions/shellsession.desktop`
- Remove `/usr/local/bin/lightdm-shellswitch.sh`
- Remove `~/.zlogout` logic
- Disable LightDM service

---

## 🧠 Motivation

This setup is useful for:
- Power off the screen after 1 minute of inactivity on the LightDM greeter
- Minimal systems with occasional GUI needs
- Secure shell-only environments with optional graphical access
- Debugging or kiosk-like workflows where GUI is used only for auth

---

Happy cycling between shells and GUIs! 🎛️
