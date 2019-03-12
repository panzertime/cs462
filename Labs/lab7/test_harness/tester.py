import requests
import json

def event(host, eci, event, attrs, body):
    url = "http://" + host + "/sky/event/" + eci + "/0/" + event
    if body:
        try:
            r = requests.get(url, params=attrs, json=body)
            return r.json()
        except Exception as e:
            print("Can't raise event because {0}".format(e))
    else:
        try:
            r = requests.get(url, params=attrs)
            return r.json()
        except Exception as e:
            print("Can't raise event because {0}".format(e))

def query(host, eci, ruleset, function, attrs):
    url = "http://" + host + "/sky/cloud/" + eci + "/" + ruleset + "/" + function
    try:
        r = requests.get(url, params=attrs)
        return r.json()
    except Exception as e:
        print("Can't make query because {0}".format(e))




HOST = "192.168.56.102:8080"
ROOT_ECI = "KsnGoaY1NsTGqjDN9Q1rHC"
ECIS = []

heartbeat = {}
with open('test_data.json') as json_file:
    test_data = json.load(json_file)
    heartbeat = test_data["heartbeat"]

print("Trying to create duplicates")
ret = event(HOST, ROOT_ECI, "sensor/new_sensor", {"name" : "Sensor"}, None)
ret = event(HOST, ROOT_ECI, "sensor/new_sensor", {"name" : "Sensor"}, None)
if ret["directives"][0]["name"] == 'Pico_Created':
    print("Failed: duplicate picos allowed")
    exit()
print("Passed")

print("Trying to delete the pico")
ret = event(HOST, ROOT_ECI, "sensor/unneeded_sensor", {"name" : "Sensor"}, None)
if ret["directives"][1]["name"] != "notifying child of intent to destroy":
    print("Failed: no Wrangler deletion directive")
    exit()
print("Passed")

print("Querying temperatures at root pico")
if query(HOST, ROOT_ECI, "manage_sensors", "temperatures", None):
    print("Started with unclean slate: failure.")
    exit()

print("Adding four picos")
ECIS.append(event(HOST, ROOT_ECI, "sensor/new_sensor", {"name" : "Sensor 1"}, None)["directives"][0]["options"]["pico"]["eci"])
ECIS.append(event(HOST, ROOT_ECI, "sensor/new_sensor", {"name" : "Sensor 2"}, None)["directives"][0]["options"]["pico"]["eci"])
ECIS.append(event(HOST, ROOT_ECI, "sensor/new_sensor", {"name" : "Sensor 3"}, None)["directives"][0]["options"]["pico"]["eci"])
ECIS.append(event(HOST, ROOT_ECI, "sensor/new_sensor", {"name" : "Sensor 4"}, None)["directives"][0]["options"]["pico"]["eci"])
print("Sending a temp to each")
for eci in ECIS:
    event(HOST, eci, "wovyn/heartbeat", None, heartbeat)
print("Querying temperatures at root pico")
res = len(query(HOST, ROOT_ECI, "manage_sensors", "temperatures", None))
if res != 4:
    print("Expected 4 temps, saw {0}".format(res))
    exit()
print("Trying to delete the last sensor")
ret = event(HOST, ROOT_ECI, "sensor/unneeded_sensor", {"name" : "Sensor 4"}, None)
if ret["directives"][1]["name"] != "notifying child of intent to destroy":
    print("Failed: no Wrangler deletion directive")
    exit()
ECIS.pop()
print("Sending a temp to each")
for eci in ECIS:
    event(HOST, eci, "wovyn/heartbeat", None, heartbeat)
print("Querying temperatures at root pico")
ret = query(HOST, ROOT_ECI, "manage_sensors", "temperatures", None)
res = len(ret)
if res != 3:
    print("Expected 3 sensors, saw {0}".format(res))
    exit()
for sensor in ret:
    if len(sensor["temperatures"]) != 2:
        print("Expected 2 temps, saw {0}".format(len(sensor)))
        exit()
print("trying to add Sensor 5")
ECIS.append(event(HOST, ROOT_ECI, "sensor/new_sensor", {"name" : "Sensor 5"}, None)["directives"][0]["options"]["pico"]["eci"])
print("Sending a temp to each")
for eci in ECIS:
    event(HOST, eci, "wovyn/heartbeat", None, heartbeat)
print("Querying temperatures at root pico")
ret = query(HOST, ROOT_ECI, "manage_sensors", "temperatures", None)
res = len(ret)
if res != 4:
    print("Expected 4 sensors, saw {0}".format(res))
    exit()
for sensor in ret[:-1]:
    if len(sensor["temperatures"]) != 3:
        print("Expected 3 temps, saw {0}".format(len(sensor)))
        exit()
if len(ret[-1]["temperatures"]) != 1:
    print("Expected 1 temps, saw {0}".format(len(sensor)))
    exit()
print("Getting the profile from the last pico")
ret = query(HOST, ECIS[-1], "sensor_profile", "get_profile", None)
if ret["location"]:
    print("Default location is blank, but this one is not")
    exit()
if ret["name"] != "Sensor 5":
    print("Name mismatch")
    exit()
if ret["threshold"] != 75:
    print("Threshold mismatch")
    exit()
if ret["notify_number"] != "+19014513614":
    print("Phone mismatch")
    exit()

print("All checks passed")
