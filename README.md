# RPi SSH Tunnel

Scripts to configure and install an SSH tunnel on a RPi.

This may be useful on scenarios where a RPi is deployed inside a LAN with limited connectivity **from** the Internet due to lack of access to the router / firewall configuration or the impossibility of getting a static IP.

This comprises two actors:

* The **RPi** that lives in the LAN and initiates the tunnel.
* A **remote public server** with an exposed SSH service that will serve as the entry point to the tunnel.

## Configuration steps

### Generate RPi key

First, we need to generate an SSH key pair in the RPi. This key will be used to authenticate the RPi in the remote public server.

> Please check that the key hasn't been generated already.

```
pi@raspberrypi ~ $ sudo ssh-keygen
Generating public/private rsa key pair.
Enter file in which to save the key (/root/.ssh/id_rsa): 
Created directory '/root/.ssh'.
Enter passphrase (empty for no passphrase): 
Enter same passphrase again: 
Your identification has been saved in /root/.ssh/id_rsa.
Your public key has been saved in /root/.ssh/id_rsa.pub.
The key fingerprint is:
a8:c1:95:5d:51:a0:f1:01:47:db:e1:da:33:80:4c:a7 root@raspberrypi
The key's randomart image is:
+---[RSA 2048]----+
|        +oO+o    |
|       = X = .   |
|      o E + o    |
|   . . .   +     |
|    o . S . +    |
|     o       o   |
|    .            |
|                 |
|                 |
+-----------------+
```

Once this is done, you may check the public key with:

```
pi@raspberrypi ~ $ sudo cat /root/.ssh/id_rsa.pub
ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDgPfyqujI9GQckCB1SGRsrdTooOm9znf2nBSIOGThjkzlDBVEYJiTREEXisR2pLtE9FqDMOrnqR9LxTAYujhbr9FLSpWZvOKy0rofUbRhp2SrA1FGZ1nH+XM+HwM1OjQFAFiQGLbI/kLU6JKiibjjA7km1bUvIS+zjyoSBMEnj1dIX6wdtQzOtRSVyOZ4maYfE5RAIG1dLfrcs4xMuBgHIjCuZtLbFILP/TrkS6pSAg/GlQv5Wkm617iSwY2QoYQz1c+qXmtqGHXjjlbyS6rj6IfvSVy27krEGKrw2kgfFt+OzTvV7Tmg5paQg0RrmPyMZlCvV2xhKm/4h85eAvdO9 root@raspberrypi
```

### Add RPi key to remote server

Then, we need to append the RPi public key to the `~/.ssh/authorized_keys` remote file. This will enable password-less SSH access from the RPi to the remote public server.

The following configuration options are highly recommended to restrict the tunnel and decrease the risk of it being used by a malicious user to obtain undesired access to the remote server:

Option | Description | Value
--- | --- | ---
`no-pty` | Prevents tty allocation (a request to allocate a pty will fail). | *None*
`no-user-rc` | Disables execution of *~/.ssh/rc*. | *None*
`no-X11-forwarding` | Forbids X11 forwarding when this key is used for authentication. Any X11 forward requests by the client will return an error. | *None*
`command` | Specifies that the	command	is executed whenever this key is used for authentication. The command supplied by the user (if any) is ignored. | `/bin/cat`
`permitopen` | Limit local port forwarding with ssh(1) -L such that it may only connect to the specified host and port. | `255.255.255.255:9`

These options defined as an environment variable:

```
export AUTHORIZED_KEYS_OPTIONS="no-pty,no-user-rc,no-X11-forwarding,permitopen=\"255.255.255.255:9\",command=\"/bin/cat\""
```

Assumming that the `RPI_PUB_KEY` variable contains the RPi public key we may append the key to the `~/.ssh/authorized_keys` as follows:

```
echo "${AUTHORIZED_KEYS_OPTIONS} ${RPI_PUB_KEY}" >> ~/.ssh/authorized_keys
```

Now check that the connection works but PTY allocation fails (due to the `no-pty` option):

```
$ ssh remote.user@remote.hostname
PTY allocation request failed on channel 0
```

### Run service installation script

The last step consists in running an installation script that will basically install an *autossh*-based *systemd* service named `autossh-tunnel.service`. This service will take care of auto starting the tunnel on boot and keeping it always open.

This script needs a couple of configuration variables:

Environment variable | Description
--- | ---
`SSH_TUNNEL_REMOTE_PORT` | Remote public server port in which the tunnel should be exposed.
`SSH_TUNNEL_CONNECTION` | Remote public server user and hostname with optional *ssh* connection arguments (e.g. `user@hostname -p 2222`).

```
sudo SSH_TUNNEL_REMOTE_PORT=22221 SSH_TUNNEL_CONNECTION=user@192.168.2.27 ./run.sh
```

We may use the `systemctl` command to manage `autossh-tunnel.service` like any other *systemd* service. For example, to check the service status:

```
root@rpi:/home/pi# systemctl status autossh-tunnel.service
● autossh-tunnel.service - AutoSSH tunnel service on remote port 22221
   Loaded: loaded (/etc/systemd/system/autossh-tunnel.service; enabled)
   Active: active (running) since Thu 2017-06-22 14:13:35 CEST; 56s ago
 Main PID: 2845 (autossh)
   CGroup: /system.slice/autossh-tunnel.service
           ├─2845 /usr/lib/autossh/autossh -M 0 -o ServerAliveInterval 90 -o ServerAliveCountMax 3 -NR 22221:localhost:22 user@192.168.2.27
           └─2849 /usr/bin/ssh -o ServerAliveInterval 90 -o ServerAliveCountMax 3 -NR 22221:localhost:22 user@192.168.2.27

Jun 22 14:13:35 rpi systemd[1]: Started AutoSSH tunnel service on remote port 22221.
Jun 22 14:13:35 rpi autossh[2845]: port set to 0, monitoring disabled
Jun 22 14:13:35 rpi autossh[2845]: starting ssh (count 1)
Jun 22 14:13:35 rpi autossh[2845]: ssh child pid is 2849
Jun 22 14:14:18 rpi systemd[1]: Started AutoSSH tunnel service on remote port 22221.
Jun 22 14:14:20 rpi systemd[1]: Started AutoSSH tunnel service on remote port 22221.
```

You may validate that the tunnel is working OK by connecting to the remote public server and trying to log back into the RPi through the tunnel. Based on the previous example:

```
ssh pi@localhost -p 22221
```
