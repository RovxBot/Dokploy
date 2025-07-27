# Mounting SMB Shares for Jellyfin on Docker Swarm Hosts

Follow these steps on each Docker Swarm host to mount your SMB shares for Jellyfin:

## 1. Create Mount Points
```sh
sudo mkdir -p /srv/media/plex
sudo mkdir -p /srv/media/emby
```

## 2. Mount the SMB Shares
Replace `USER` and `PASSWORD` with your actual credentials.
```sh
sudo mount -t cifs //ROV-NET-NAS/Plex\ Media /srv/media/plex -o username=USER,password=PASSWORD,iocharset=utf8,file_mode=0777,dir_mode=0777
sudo mount -t cifs //ROV-NET-RACK/emby_media /srv/media/emby -o username=USER,password=PASSWORD,iocharset=utf8,file_mode=0777,dir_mode=0777
```

## 3. Make the Mounts Persistent (Optional)
Add these lines to `/etc/fstab` on each host:
```
//192.168.1.154/Plex\040Media /srv/media/plex cifs username=USER,password=PASSWORD,iocharset=utf8,file_mode=0777,dir_mode=0777 0 0
//192.168.1.153/emby_media /srv/media/emby cifs username=USER,password=PASSWORD,iocharset=utf8,file_mode=0777,dir_mode=0777 0 0
```
*Note: `\040` represents a space in fstab.*

## 4. Verify the Mounts
```sh
ds -lh /srv/media/plex
ls -lh /srv/media/emby
```
You should see your media files listed.

---

Now, when you deploy Jellyfin, it will have access to your SMB media shares on all Swarm hosts.
