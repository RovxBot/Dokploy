# Setting Up Shared Storage for Docker Swarm with NFS

This guide explains how to set up persistent, shared storage for Docker Swarm using NFS. This ensures your app data is available on any node in the Swarm.

---

## 1. Set Up an NFS Server

- Choose a host to act as your NFS server (can be a dedicated server or a Swarm node).
- Install NFS server (on Ubuntu/Debian):
  ```sh
  sudo apt update
  sudo apt install nfs-kernel-server
  ```
- Create all shared directories for your apps at once:
  ```sh
  sudo mkdir -p \
    /srv/appdata/vaultwarden \
    /srv/appdata/immich/library \
    /srv/appdata/immich/model-cache \
    /srv/appdata/immich/redis-data \
    /srv/appdata/immich/postgres \
    /srv/appdata/jellyfin/config \
    /srv/appdata/jellyfin/cache \
    /srv/appdata/jellyseerr/config \
    /srv/appdata/prowlarr/config \
    /srv/appdata/radarr/config \
    /srv/appdata/sonarr/config \
    /srv/appdata/sabnzbd/config \
    /srv/appdata/homeassistant/config \
    /srv/appdata/homeassistant/mosquitto/config \
    /srv/appdata/homeassistant/mosquitto/data \
    /srv/appdata/homeassistant/mosquitto/log \
    /srv/appdata/homeassistant/nodered
    ----------------------------------- Above this line is done
  sudo mkdir -p \

  sudo chown -R 1000:1000 /srv/appdata
  ```
- Edit `/etc/exports` and add a line to share the entire `/srv/appdata` directory with all your Swarm nodes:
  ```
  /srv/appdata  *(rw,sync,no_subtree_check,no_root_squash)
  ```
  This line allows any client to mount the `/srv/appdata` directory via NFS with read/write access. All your app subfolders will be shared automatically, so you only need this single line for all your appdata.
  
  If you want to restrict access to specific hosts, replace `*` with the IP address or subnet of your Swarm nodes (e.g., `192.168.1.0/24`).
- Apply the export:
  ```sh
  sudo exportfs -ra
  sudo systemctl restart nfs-kernel-server
  ```

---

## 2. Mount the NFS Share on All Swarm Nodes

- On each Swarm node (including the NFS server if it will run containers):
  ```sh
  sudo apt install nfs-common
  sudo mkdir -p /srv/appdata
  sudo mount 192.168.1.192:/srv/appdata /srv/appdata
  ```
  Replace `192.168.1.192` with your NFS server’s IP address.

- To make the mount persistent, add this line to `/etc/fstab` on each node:
  ```
  192.168.1.192:/srv/appdata /srv/appdata nfs defaults 0 0
  ```

---

## 3. Use the Shared Path in Your Compose/Stack Files

- In your compose or stack files, use the appropriate subfolder for each app, e.g.:
  ```yaml
  # Vaultwarden
  - /srv/appdata/vaultwarden:/data:rw
  # Immich
  - /srv/appdata/immich/library:/usr/src/app/upload
  - /srv/appdata/immich/model-cache:/cache
  - /srv/appdata/immich/redis-data:/data
  - /srv/appdata/immich/postgres:/var/lib/postgresql/data
  # Jellyfin
  - /srv/appdata/jellyfin/config:/config
  - /srv/appdata/jellyfin/cache:/cache
  # Jellyseerr
  - /srv/appdata/jellyseerr/config:/app/config
  # Prowlarr
  - /srv/appdata/prowlarr/config:/app/config
  # Radarr
  - /srv/appdata/radarr/config:/app/config
  # Sonarr
  - /srv/appdata/sonarr/config:/app/config
  # SABnzbd
  - /srv/appdata/sabnzbd/config:/app/config
  ```

---

## 4. (Optional) Use Docker Named Volumes with NFS

You can also define named volumes in your stack files for each app, using the same NFS share.

---

## Notes
- Make sure the NFS share is accessible from all Swarm nodes.
- Adjust permissions as needed for your containers (UID 1000 is common).
- For media shares (e.g., Jellyfin), mount your SMB/NFS media folders on all Swarm nodes as described in the Jellyfin SMB guide.

---

sudo ufw allow from 192.168.1.192 to any port nfs
sudo ufw allow from 192.168.1.192 to any port 111
