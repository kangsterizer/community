"""
Applet: Lyft Bikes
Summary: Display available Lyft bikes
Description: Multi-dock display of available Lyft bikes, supporting different regions.
Author: Guillaume Destuynder
"""

load("render.star", "render")
load("http.star", "http")
load("encoding/base64.star", "base64")
load("time.star", "time")
load("schema.star", "schema")

BIKE_ICON = base64.decode("""
iVBORw0KGgoAAAANSUhEUgAAABAAAAAKCAYAAAC9vt6cAAAAAXNSR0IArs4c6QAAAVhJREFUKFNN
UkFSwkAQ7DnoLfEX+gMeAJVdqgyc9IQ+gAq8JoEPyJGTgdINpQ+QF+gvDCe9jNWzCWUqlWRnu2e6
OyvgJQJA7eanqlW5EetW5DJi8uVJ92UiKtzqCB3UKPnipATvqlSsmQ0gX5EvWuW6LlOr2s5/Mlfs
PCm+ta5Szuj5UYUNaLWukjP33KAXzvfEJnUV06rRRWetLhNT30O6KMT8k0w4LfT+82WrtFCvUsmL
Vm0vqhNkPlPmw+vyZotddSW3BK0SYZ2hmWQVeJfpxfUWv1/3aA5BxDmn4bGw6KfHEX4+73BogjBI
KqfuPcMUwGdOXx7mmB6HqAfvGG/WEOedhlmByXFoaENCoSLYlZQZnQsUmfca2OBjhOfBW2zgvdfX
2dxA5I6f1miaRkiwWh89AO+ooAB9MeHxZtVn4CwgTm1Cw3HxzMSHLeKpAWiZQfMPhBDkD0req4o1
0+/2AAAAAElFTkSuQmCC
""")

LT_ICON = base64.decode("""
iVBORw0KGgoAAAANSUhEUgAAAAwAAAAQCAYAAAAiYZ4HAAAAAXNSR0IArs4c6QAAAPlJREFUOE9V
kkGWwzAIQ6Xs27n/MSdZN/RJAsfNwi+2EYiPSQBF4D5ZKIBevPpj6b7Aypnivd7/LErTkZRIG0c4
rTNvgt76rlBMULYJO96lPMBHdnLWNuwOyad/4viTJ8ot8LnicHy7KQlskc4cLcG6xrY2ATDN6/94
JWmSETSdZWC867JwvBvaLlAFi22abljlB+HenKvd57hoZO3LrS69+8XxCruFOQCCN4WmGh08oS1I
a/c1PWnKme5DaZu0bu7J3k9C2DiUButuyf00RPPvYQ1UYx3GdS7UmYOQrpls81kCeTdL2fDTW0P8
AZO3NNn7GTzj7qk/Fb67Np34msB7lwAAAABJRU5ErkJggg==
""")

WDROP_ICON = base64.decode("""
iVBORw0KGgoAAAANSUhEUgAAAAcAAAAJCAYAAAD+WDajAAAAAXNSR0IArs4c6QAAAJVJREFUKFM9
T8ERwjAMkxZq2AlSnrQwB23eDSzDApB+OCbgww7i7BB8Pt9ZlmWZsCAAAWMummNgAwz2GJYiUpCI
1AfagueQ74K8dwmRSDGQ41Ikl5YlzrFDfn3wvL1Bl/ux7a4xpm3A6brWYTPUtqddh+NlBc2hUCWN
NcfOXP+fwJgf9W6DBKR9oBu0csilziWkfuP4FyFUSHWAip1rAAAAAElFTkSuQmCC
""")

## Lyft stations
# https://gbfs.lyft.com/gbfs/2.3/bay/en/station_information.json
# https://gbfs.lyft.com/gbfs/2.3/bay/en/station_status.json
# https://gbfs.lyft.com/gbfs/2.3/bay/en/free_bike_status.json
# See also https://gbfs.netlify.app/

def get_station_info(area_code, station_sn):
    station_information_url = "https://gbfs.lyft.com/gbfs/2.3/%s/en/station_information.json" % area_code
    station_status_url = "https://gbfs.lyft.com/gbfs/2.3/%s/en/station_status.json" % area_code
    station_info = {"ebikes": -1, "bikes": -1, "capacity": -1, "last_update": -1, "id": "0-0-0-0", "name": "404", "long_name": "404"}

    resp = http.get(station_information_url, ttl_seconds = 86400)
    if resp.status_code != 200:
        fail("HTTP error: %d", resp.status_code)
        return station_info
    info = resp.json()["data"]["stations"]
    for station in info:
        if station["short_name"] == station_sn:
            station_info["name"] = station_sn
            station_info["long_name"] = station["name"]
            station_info["id"] = station["station_id"]
            station_info["capacity"] = int(station["capacity"])
            break

    resp = http.get(station_status_url, ttl_seconds = 120)
    if resp.status_code != 200:
        fail("HTTP error: %d", resp.status_code)
        return station_info

    data = resp.json()["data"]["stations"]
    for station in data:
        if station["station_id"] == station_info["id"]:
            station_info["ebikes"] = int(station["num_ebikes_available"])
            station_info["bikes"] = int(station["num_bikes_available"]) - station_info["ebikes"]

            last_update = time.from_timestamp(int(station["last_reported"]))
            station_info["last_update"] = last_update
            break

    return station_info

def main(config):
    # Ex bay
    area_code = config.get("area_code")
    if area_code == None:
        area_code = "bay"
    # Ex SF-B19, SF-A20
    station_ids = {}
    station_ids[config.get("station_one")] = config.get("station_one_text")
    station_ids[config.get("station_two")] = config.get("station_two_text")
    station_ids["SF-A20"] = "Safeway"
    station_ids["SF-A19"] = "Home"

    stations = []

    # Icon strip
    stations.append(render.Row(
        cross_align="end",
        main_align="space_between",
        expanded=True,
        children=[
                  render.Box(child=render.Image(src=BIKE_ICON, width=8, height=8), width=8, height=8, padding=0),
                  render.Box(width=35-8, height=8, padding=0),
                  render.Image(src=LT_ICON, width=7, height=7),
                  render.Image(src=WDROP_ICON, width=7, height=7)
                  ]
        ),
    )

    print("----{}----".format(station_ids))
    for station_id in station_ids:
        if station_id == None:
            continue
        station_info = get_station_info(area_code, station_id)

        # Station human short name (hsn) must be 8 max len (40px) to fit in the display without scrolling
        station_hsn = station_ids[station_id][:8]
        # Pad the text so that it's well aligned
        pad = 35-len(station_hsn)*5
        if pad  < 0: pad = 0

        print(station_info)
        # Stations
        stations.append(render.Row(
                children = [
                            render.Box(child=render.Text(station_hsn, color="#fa0"),
                                       width=len(station_hsn)*5, height=8),
                            render.Box(width=1+pad, height=8),
                            render.Text(str(station_info["ebikes"]), color="#ff4"),
                            render.Text(str(station_info["bikes"]), color="#ccc")
                            ],
                expanded=True,
                cross_align="end",
                main_align="space_between"
                )
        )

    return render.Root(
        child = render.Column(
            cross_align="end",
            children=stations
        )
    )

def get_schema():
    return schema.Schema(
    version = "1",
    fields = [
        schema.Text(
            id = "area_code",
            name = "Area Code",
            desc = "Area Code for your location (e.g. bay)",
            icon = "map",
            default = "bay"
        ),
        schema.Text(
            id = "station_one",
            name = "Bay Wheels Station short name 1",
            desc = "A Bay Wheels station short name",
            icon = "bicyle",
            default = "SF-A19"
        ),
        schema.Text(
            id = "station_one_text",
            name = "Bay Wheels Station short name 1",
            desc = "A Bay Wheels station short name",
            icon = "bicyle",
            default = "Home"
        ),
        schema.Text(
            id = "station_two",
            name = "Bay Wheels Station short name 2",
            desc = "A Bay Wheels station short name",
            icon = "bicyle",
            default = "SF-A20"
        ),
        schema.Text(
            id = "station_two_text",
            name = "Bay Wheels Station short name 1",
            desc = "A Bay Wheels station short name",
            icon = "bicyle",
            default = "Safeway"
        ),
    ],
)