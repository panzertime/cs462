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

# use random.sample(ECIS, 2) to connect 2 picos at a time


print("Adding 8 picos")
ECIS.append(event(HOST, ROOT_ECI, "sensor/new_sensor", {"name" : "Sensor 1"}, None)["directives"][0]["options"]["pico"]["eci"])
ECIS.append(event(HOST, ROOT_ECI, "sensor/new_sensor", {"name" : "Sensor 2"}, None)["directives"][0]["options"]["pico"]["eci"])
ECIS.append(event(HOST, ROOT_ECI, "sensor/new_sensor", {"name" : "Sensor 3"}, None)["directives"][0]["options"]["pico"]["eci"])
ECIS.append(event(HOST, ROOT_ECI, "sensor/new_sensor", {"name" : "Sensor 4"}, None)["directives"][0]["options"]["pico"]["eci"])
ECIS.append(event(HOST, ROOT_ECI, "sensor/new_sensor", {"name" : "Sensor 5"}, None)["directives"][0]["options"]["pico"]["eci"])
ECIS.append(event(HOST, ROOT_ECI, "sensor/new_sensor", {"name" : "Sensor 6"}, None)["directives"][0]["options"]["pico"]["eci"])
ECIS.append(event(HOST, ROOT_ECI, "sensor/new_sensor", {"name" : "Sensor 7"}, None)["directives"][0]["options"]["pico"]["eci"])
ECIS.append(event(HOST, ROOT_ECI, "sensor/new_sensor", {"name" : "Sensor 8"}, None)["directives"][0]["options"]["pico"]["eci"])
#ECIS.append(event(HOST, ROOT_ECI, "sensor/new_sensor", {"name" : "Sensor 9"}, None)["directives"][0]["options"]["pico"]["eci"])
#ECIS.append(event(HOST, ROOT_ECI, "sensor/new_sensor", {"name" : "Sensor 10"}, None)["directives"][0]["options"]["pico"]["eci"])
#ECIS.append(event(HOST, ROOT_ECI, "sensor/new_sensor", {"name" : "Sensor 11"}, None)["directives"][0]["options"]["pico"]["eci"])
#ECIS.append(event(HOST, ROOT_ECI, "sensor/new_sensor", {"name" : "Sensor 12"}, None)["directives"][0]["options"]["pico"]["eci"])
#ECIS.append(event(HOST, ROOT_ECI, "sensor/new_sensor", {"name" : "Sensor 13"}, None)["directives"][0]["options"]["pico"]["eci"])
#ECIS.append(event(HOST, ROOT_ECI, "sensor/new_sensor", {"name" : "Sensor 14"}, None)["directives"][0]["options"]["pico"]["eci"])
#ECIS.append(event(HOST, ROOT_ECI, "sensor/new_sensor", {"name" : "Sensor 15"}, None)["directives"][0]["options"]["pico"]["eci"])
#ECIS.append(event(HOST, ROOT_ECI, "sensor/new_sensor", {"name" : "Sensor 16"}, None)["directives"][0]["options"]["pico"]["eci"])

print("Computing number of edges for desired density: ")
graph_density = 0.18 # 0.134 is minimum for fully-connected
edges = int(graph_density * len(ECIS) * (len(ECIS) - 1) / 2)
# not great, should just connect each to one random other one
#edges = 16
print("Creating " + str(edges) + " edges")

for edge in range(edges):
    vertices = random.sample(ECIS, 2)
    attrs = {"eci": vertices[1], "host": HOST}
    event(HOST, vertices[0], "gossip/peer", attrs, None)


#for src in ECIS:
#    if random.choice([True, True, True, False]):
#        continue
#    dst = src
#    while dst == src:
#        dst = random.choice(ECIS)
#    attrs = {"eci": dst, "host": HOST}
#    event(HOST, src, "gossip/peer", attrs, None)

#for src in random.shuffle(ECIS)


#print("Sending a temp to each")
#for eci in ECIS:
#    event(HOST, eci, "wovyn/heartbeat", None, beat())