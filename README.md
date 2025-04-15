

<p align="center">
<img src="https://i.imgur.com/PYsbwqj.png" width="450" height="164" align="center">
</p>

# Garmin Grafana

A docker container to fetch data from Garmin servers and store the data in a local influxdb database for appealing visualization with Garfana.

If you are a **Fitbit user**, please check out the [sister project](https://github.com/arpanghosh8453/fitbit-grafana) made for Fitbit

## Dashboard Example

![Dashboard](https://github.com/arpanghosh8453/garmin-grafana/blob/main/Grafana_Dashboard/Garmin-Grafana-Dashboard-Preview.png?raw=true)

## Features

- Automatic data collection from Garmin
- Collects comprehensive health metrics including:
  - Heart Rate Data
  - Hourly steps Heatmap
  - Daily Step Count
  - Sleep Data and patterns (SpO2, Breathing rate, Sleep movements, HRV)
  - Sleep regularity heatmap (Visualize sleep routine)
  - Stress Data 
  - Body Battery data
  - Calories
  - Sleep Score
  - Activity Minutes and HR zones
  - Activity Timeline (workouts)
  - GPS data from workouts (track, pace, altitude, HR)
  - And more...
- Automated data fetching in regular interval (set and forget)
- Historical data backfilling

## Install with Docker (Recommended)

1. Create a folder named `garmin-fetch-data`, cd into the folder, create a `compose.yml` file with the content of the given [compose-example.yml](./compose-example.yml) ( Change the environment variables accordingly )

2. if you modify the docker volumes to bind mounts in the compose file for persistent storage, please check the troubleshooting section below if you get read/write permission denied or file not found errors.

3. You can use two additional environment variables `GARMINCONNECT_EMAIL` and `GARMINCONNECT_BASE64_PASSWORD` to add the login information directly. otherwise you will need to enter them in the initial setup phase when prompted. Please note that the password must be encoded with [Base64](http://base64encode.org/) when using the `GARMINCONNECT_BASE64_PASSWORD` ENV variable. This is to ensure your Garmin Connect password is not in plaintext in the compose file. The script will decode it and use it when required. If you set these two ENV variables and do not have two factor authentication (via SMS or email), you can directly jump to `step 5`

4. If you did not set up the email and password ENV variables or have 2FA enabled, you must run the following command first to get the Email, password and 2FA code prompt interactively: `docker pull thisisarpanghosh/garmin-fetch-data:latest && docker compose run --rm garmin-fetch-data`. Enter the Email, Password (the characters will be visible when you type to avoid confusion, so find some privacy. If you paste the password, make sure there is no trailing space or unwanted characters), and 2FA code (if you have that enabled). Once you see the successful authentication message followed by successful data fetching in the stdout log, exit out with `ctrl + c`. This will automatically remove this orphan container as this was started with the `--rm` flag. You need to login like this **only once**. The script will [save the session Authentication tokens](https://github.com/cyberjunky/python-garminconnect/issues/213#issuecomment-2213292471) in the container's internal `/home/appuser/.garminconnect` folder for future use. That token can be used for all the future requests as long as it's valid (expected session token lifetime is about [one year](https://github.com/cyberjunky/python-garminconnect/issues/213), as Garmin seems to use long term valid access tokens instead of short term valid {access token + refresh token} pairs). This helps in reusing the authentication without logging in every time when the container starts, as that leads to `429 Client Error`, when login is attempted repeatedly from the same IP address. If you run into `429 Client Error` during your first login attempt with this script, please refer to the troubleshooting section below. 

5. Finally run : `docker compose up -d` ( to launch the full stack in detached mode ). Thereafter you should check the logs with `docker compose logs --follow` to see any potential error from the containers. This will help you debug the issue, if there is any (specially read/write permission issues). if you are using docker volumes, there are little chance of this happending as file permissions will be managed by docker. For bind mounts, if you are having permission issues, please check the troubleshooting section.

7. Now you can check out the `http://localhost:3000` to reach Grafana (by default), do the initial setup with the default username `admin` and password `admin`, add influxdb as the data source, the influxdb hostname should be `influxdb` with port `8086`. Test the connection to make sure the influxdb is up and reachable (you are good to go if it finds the measurements when you test the connection)

8. To use the Grafana dashboard, please use the [JSON file](https://github.com/arpanghosh8453/garmin-grafana/blob/main/Grafana_Dashboard/Garmin-Grafana-Dashboard.json) downloaded directly from GitHub or use the import code **23245** to pull them directly from the Grafana dashboard cloud.

---

This project is made for InfluxDB 1.11, as Flux queries on influxDB 2.x can be problematic to use with Grafana at times. In fact, InfluxQL is being reintroduced in InfluxDB 3.0, reflecting user feedback. Grafana also has better compatibility/stability with InfluxQL from InfluxDB 1.11. Moreover, there are statistical evidence that Influxdb 1.11 queries run faster compared to influxdb 2.x. Since InfluxDB 2.x offers no clear benefits for this project, there are no plans for a migration.

Example `compose.yml` file contents is given here for a quick start.

```yaml
services:
  garmin-fetch-data:
    restart: unless-stopped
    image: thisisarpanghosh/garmin-fetch-data:latest
    container_name: garmin-fetch-data
    depends_on:
      - influxdb
    volumes:
      - garmin_tokens_data:/home/appuser/.garminconnect # (persistant tokens storage) - you can use bind mounts as well (read troubleshooting)
    environment:
      - INFLUXDB_HOST=influxdb
      - INFLUXDB_PORT=8086
      - INFLUXDB_USERNAME=influxdb_user # user should have read/write access to INFLUXDB_DATABASE
      - INFLUXDB_PASSWORD=influxdb_secret_password
      - INFLUXDB_DATABASE=GarminStats
      - GARMINCONNECT_EMAIL=your_garminconnect_email # optional, read the setup docs
      - GARMINCONNECT_BASE64_PASSWORD=your_base64_encoded_garminconnect_password # optional, must be Base64 encoded, read setup docs
      - UPDATE_INTERVAL_SECONDS=300 # Default update check interval is set to 5 minutes
      - LOG_LEVEL=INFO # change to DEBUG to get DEBUG logs

  influxdb:
    restart: unless-stopped
    container_name: influxdb
    hostname: influxdb
    environment:
      - INFLUXDB_DB=GarminStats
      - INFLUXDB_USER=influxdb_user
      - INFLUXDB_USER_PASSWORD=influxdb_secret_password
      - INFLUXDB_DATA_INDEX_VERSION=tsi1
    ports:
      - '8086:8086'
    volumes:
      - influxdb_data:/var/lib/influxdb
    image: 'influxdb:1.11'

  grafana:
    restart: unless-stopped
    container_name: grafana
    hostname: grafana
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=admin
    volumes:
      - grafana_data:/var/lib/grafana
    ports:
      - '3000:3000'
    image: 'grafana/grafana:latest'

volumes:
  influxdb_data:
  grafana_data:
  garmin_tokens_data:

```

## Historical data fetching (bulk update)

Please note that this process is intentionally rate limited with a 5 second wait period between each day update to ensure the Garmin servers are not overloaded with requests when using bulk update. You can update the value with `RATE_LIMIT_CALLS_SECONDS` ENV variable in the `garmin-fetch-data` container, but lowering it is not recommended, 

#### Procedure

1. Please run the above docker based installation steps `1` to `4` first (to set up the Garmin Connect login session tokens if not done already).

2. Stop the running container and remove it with `docker compose down` if running already

3. Run command `docker compose run --rm -e MANUAL_START_DATE=YYYY-MM-DD -e MANUAL_END_DATE=YYYY-MM-DD garmin-fetch-data` to update the data between the two dates. You need to replace the `YYYY-MM-DD` with the actual dates in that format, for example `docker compose run --rm -e MANUAL_START_DATE=2025-04-12 -e MANUAL_END_DATE=2025-04-14 garmin-fetch-data`. The `MANUAL_END_DATE` variable is optional, if not provided, the script assumes it to be the current date. `MANUAL_END_DATE` must be in future to the `MANUAL_START_DATE` variable passed, and in case they are same, data is still pulled for that specific date. 

4. Please note that the bulk data fetching is done in **reverse chronological order**. So you will have recent data first and it will keep going back until it hits `MANUAL_START_DATE`. You can have this running in background. If this terminates after some time unexpectedly, you can check back the last successful update date from the container stdout logs and use that as the `MANUAL_END_DATE` when running bulk update again as it's done in reverse chronological order.

4. After successful bulk fetching, you will see a `Bulk update success` message and the container will exit and remove itself automatically. 

5. Now you can run the regular periodic update with `docker compose up -d`


## Troubleshooting

- The issued session token is apparently [valid only for 1 year](https://github.com/cyberjunky/python-garminconnect/issues/213) or less. Therefore, the automatic fetch will fail after the token expires. If you are using it more than one year, you may need to stop, remove and redeploy the container (follow the same instructions for initial setup, you will be asked for the username and password + 2FA code again). if you are not using MFA/2FA (SMS or email one time code), you can use the `GARMINCONNECT_EMAIL` and `GARMINCONNECT_BASE64_PASSWORD` (remember, this is [base64 encoded](http://base64encode.org/) password, not plaintext) ENV variables in the compose file to give this info directly, so the script will be able to re-generate the tokens once they expire. Unfortunately, if you are using MFA/2FA, you need to enter the one time code manually after rebuilding the container every year when the tokens expire to keep the script running (Once the session token is valid again, the script will automatically back-fill the data you missed)

- If you are getting `429 Client Error` after a few login tries during the initial setup, this is an indication that you are being rate limited based on your public IP. Garmin has a set limit for repeated login attempts from the same IP address to protect your account. You can wait for a few hours or a day, or switch to a different wifi network outside your home (will give you a new public IP) or just simply use mobile hotspot (will give you a new public IP as well) for the initial login attempt. This should work in theory as [discussed here](https://github.com/matin/garth/discussions/60).

- If you want to bind mount the docker volumes for the `garmin-fetch-data` container, please keep in mind that the script runs with the internal user `appuser` with uid and gid set as 1000. So please chown the bind mount folder accordingly. Also, `grafana` container requires the bind mount folders to be owned by `472:472` and `influxdb:1.11` container requires the bind mount folders to be owned by `1500:1500`

- If the Activities details (GPS, Pace, HR, Altitude) are not appearing on the dashboard, make sure to select an Activity listed on the top left conner of the Dashboard (In the `Activity with GPS` variable dropdown). If you see no values are available there, but in the log you see the activities are being pulled successfully, then it's due to a Grafana Bug. Go to the dashboard variable settings, and please ensure the correct datasource is selected for the variable and the query is set to `SHOW TAG VALUES FROM "ActivityGPS" WITH KEY = "ActivitySelector" WHERE $timeFilter`. Once you set this properly after the dashboard import, the values should show up correctly in the dropdown and you will be able to select specific Activity and view it's stats on the dashboard. 

## Credits

This project is made possible by **generous community contribution** towards the [gofundme](https://gofund.me/0d53b8d1) advertised in [this post](https://www.reddit.com/r/Garmin/comments/1jucwhu/update_free_and_open_source_garmin_grafana/) on Reddit's [r/garmin](https://www.reddit.com/r/Garmin) community. I wanted to build this tool for a long time, but funds were never sufficient for me to get a Garmin, because they are pretty expensive. With the community donations, I was able to buy a `Garmin Vivoactive 6` and built this tool open to everyone. if you are using this tool and enjoy it, please remember what made this possible! Huge shoutout to the [r/garmin](https://www.reddit.com/r/Garmin) community for being generous, trusting me and actively supporting my idea!

## Dependencies

- [python-garminconnect](https://github.com/cyberjunky/python-garminconnect) by [cyberjunky](https://github.com/cyberjunky) : Garmin Web API wrapper

- [garth](https://github.com/matin/garth) by [martin](https://github.com/matin) : Used for Garmin SSO Authentication

## Support me

If you enjoy the project and love how it works with simple setup, please consider supporting me with a coffee ❤ for making this open source and accessible to everyone. You can view and analyze more detailed health statistics with this setup than paying a connect+ subscription fee to Garmin.

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/A0A84F3DP)

## Star History

[![Star History Chart](https://api.star-history.com/svg?repos=arpanghosh8453/garmin-grafana&type=Date)](https://www.star-history.com/#arpanghosh8453/garmin-grafana&Date)
