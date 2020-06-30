# homebrew-webcam-temperature

A script and set of systemd services to monitor FV temperature using a webcam and Raspberry Pi.

This is based directly off [this](https://www.anfractuosity.com/projects/fermentation-temperature-control-with-inkbird-308/) blog post and code.

## Installation

Assumes you have nginx, ssocr and telegraf installed (use `apt` where possible to get the systemd unit files set up for you.
Assumes you have a working webcam and `fswebcam` works to take a photo from it.

Fork [this repository](github.com/lukebond/homebrew-webcam-temperature.git) and edit the batch name variable at the top (used to graph each brew in influxdb cloud2). The scripts below will constantly sync the rpi checkout out repo to remote head (continuous delivery!), allowing you to edit code remotely.
If you don't want this, don't enable the sync service and timer with systemd.

Sign up for an InfluxDB Cloud2 account and create a bucket called `fermentation-temps`. Grab your token, org and username (email) from there for Telegraf config later.

```
whoami # assumes user `pi`
sudo mkdir -p /opt/pi/images
sudo chown -R pi:pi /opt/pi
cd ~
git clone github.com/lukebond/homebrew-webcam-temperature.git # fork the repo on github and use your own copy, otherwise you'll get my changes due to the sync!
cd homebrew-webcam-temperature
sudo ln -s /home/pi/homebrew-webcam-temperature/services/fv-temp-monitor.service /etc/systemd/system/fv-temp-monitor.service
sudo ln -s /home/pi/homebrew-webcam-temperature/services/fv-repo-sync.service /etc/systemd/system/fv-repo-sync.service # warning: syncs to HEAD of git repo!
sudo ln -s /home/pi/homebrew-webcam-temperature/services/fv-repo-sync.timer /etc/systemd/system/fv-repo-sync.timer
sudo ln -s /home/pi/homebrew-webcam-temperature/services/nginx/fv-images.conf /etc/nginx/conf.d/fv-images.conf
sudo systemctl daemon-reload
sudo systemctl enable fv-{temp-monitor,repo-sync}.service fv-repo-sync.timer nginx
sudo systemctl start fv-{temp-monitor,repo-sync}.service fv-repo-sync.timer nginx
```

Then edit your telegraf config (`/etc/telegraf/telegraf.conf`):

- Find this section:
  ```
  # # Configuration for sending metrics to InfluxDB
  [[outputs.influxdb_v2]]
  ```
- Set the URL to your cloud2 URL: `urls = ["https://eu-central-1-1.aws.cloud2.influxdata.com/"]`
- Set your access token, taken from the UI: `token = "YOUR TOKEN HERE"`
- Set your organisation, probably your cloud2 login email address: `organization = "user@email.com"`
- Set your bucket likewise: `bucket = "fermentation-temps"`
- Restart Telegraf: `systemctl restart telegraf`

The script will store images `last-good.png` and `last-bad.png` that you can access via the Nginx web server to debug the `ssocr` cropping coordinates.
Find your Pi's IP address and point your browser to it on port 80. You will see the photo from the last successful `ssocr` in `last-good.png` with a green
rectangle drawn on it showing the current crop coordinates, and the last photo that failed to read with ssocr in `last-bad.png` with a red rectangle.
This enables you to tweak the webcam's position to get the coords right, or to change the coords in the script if needed (you can change the code in Github
and wait 15mins for the code to sync, or SSH into the Pi and run the `sync.sh` script to sync immediately. Don't edit the code on the host because you'll
lose your changes on the next sync.
