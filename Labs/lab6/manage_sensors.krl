ruleset manage_sensors {
    meta {
        name "Thermometer Cowboy"
        description <<
        Ruleset
        for Managing Sensors
        >>
        author "RT Hatfield"
        logging on
        use module io.picolabs.wrangler alias wrangler
    }

    global {
        remember_sensor = function(name, eci) {
            ent:sensors.isnull() => {name : eci} | ent:sensors.put([name], eci)
        }

        forget_sensor = function(name) {
            // figure this out
        }

        sensors = function() {
            ent:sensors.isnull() => {} | ent:sensors
        }

        get_temperatures = function() {
            ent:sensors.keys().reduce(function(acc, name){
                acc.put(
                    {
                        "name" : name,
                        "temperatures" : wrangler.skyQuery(eci, "temperature_store", "temperatures", null)
                    }
                )
            })
        }

        get_threshold = function() {
            75
        }

        get_number = function() {
            "+19014513614"
        }
    }

    rule add_sensor {
        select when sensor new_sensor
        pre {
            name = event:attrs("name")
            exists = ent:sensors.keys() <> name
        }
        if name <> ent:sensors.keys() then
            send_directive("sensor_already_exists", {name: ent:sensors.get([name])})
        notfired {
            raise wrangler event "child_creation"
                attributes {
                    "name": name,
                    "rids": [
                        "wovyn_base",
                        "sensor_profile",
                        "temperature_store"
                    ]
                }
        }
    }

    rule save_new_sensor {
        select when wrangler child_initialized
        pre {
            name = event:attrs("name")
            eci = event:attrs("eci")
        }
        send_directive("sensor_initialized", {name: eci})
        fired {
            remember_sensor(name, eci)
            event:send({
                "eci": eci,
                "eid": "update-profile",
                "domain": "sensor",
                "type": "profile_updated",
                "attrs": {
                    "threshold" : get_threshold(),
                    "location" : "",
                    "name" : name,
                    "notify_number" : get_number()
                }
            })
        }
    }

    rule remove_sensor {
        select when sensor unneeded_sensor
        // delete the pico in the event attrs
        // deletes the entity variable for this pico
    }

}