# List of containers that can be interesting to add

## Grafana

```
grafana:
    container_name: grafana
    image: grafana/grafana:latest
    # user: "999"
    restart: unless-stopped
    network_mode: host
    environment:
      - TZ=${TZ} # timezone, defined in .env
      - GF_SERVER_ROOT_URL:http://metis.local
      - GF_INSTALL_PLUGINS="grafana-clock-panel,grafana-simple-json-datasource,andig-darksky-datasource,grafana-piechart-panel"
    volumes:
      - /etc/localtime:/etc/localtime:ro
      - ./grafana:/var/lib/grafana
    ports:
      - 3000:3000
```
