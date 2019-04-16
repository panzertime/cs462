import requests
import json
import random

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




HOST = "192.168.1.182:8080"
ROOT_ECI = "M4QDSuX6vCUDwpYn83hwxA"
ECIS = []

heartbeat = {}
with open('test_data.json') as json_file:
    test_data = json.load(json_file)
    heartbeat = test_data["heartbeat"]

def beat():
    temp = random.randrange(60, 100)
    heartbeat["genericThing"]["data"]["temperature"][0]["temperatureF"] = temp
    return heartbeat

print("Clearing zone")
event(HOST, ROOT_ECI, "zone/clear", None, None)
event(HOST, ROOT_ECI, "zone/clear", None, None)

print("Adding 10 picos")
sensors = 11
for sensor in range(1, sensors):
    name = "Sensor " + str(sensor)
    print("adding " + name)
    ECIS.append(event(HOST, ROOT_ECI, "sensor/new_sensor", {"name" : name}, None)["directives"][0]["options"]["pico"]["eci"])

print("Computing number of edges for desired density: ")
graph_density = 0.14 # 0.134 is minimum for fully-connected
edges = int(graph_density * len(ECIS) * (len(ECIS) - 1) / 2)
# not great, should just connect each to one random other one
edges = 8
print("Creating " + str(edges) + " edges")

for edge in range(edges):
    vertices = random.sample(ECIS, 2)
    attrs = {"eci": vertices[1], "host": HOST}
    event(HOST, vertices[0], "gossip/peer", attrs, None)
