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
        use module io.picolabs.subscription alias subscription
        provides
        sensors,
        temperatures,
        last_five_reports
        shares
        sensors,
        temperatures,
        last_five_reports
    }

    global {
        sensors = function() {
            ent:sensors.isnull() => {} | ent:sensors
        }

        temperatures = function() {
          // for debug only!
            ent:sensors.keys().map(function(name){
              {
                  "name" : name,
                  "temperatures" : wrangler:skyQuery(ent:sensors.get([name]), "temperature_store", "temperatures", null)
              }
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
            name = event:attr("name")
            exists = ent:sensors >< name
        }
        if exists then
            send_directive("sensor_already_exists", {
              "name" : name,
              "eci" : ent:sensors.get([name])
            })
        notfired {
            raise wrangler event "child_creation"
                attributes {
                    "name": name,
                    "rids": [
                        "wovyn_base",
                        "sensor_profile",
                        "temperature_store",
                        "gossip"
                    ]
                }
        }
    }

    rule save_new_sensor {
        select when wrangler child_initialized
        pre {
            name = event:attr("name")
            eci = event:attr("eci")
        }
        
        every {
          send_directive("sensor_initialized", {
            "name" : name,
            "eci" : eci
          });
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
            });
        }
        fired {
          ent:sensors := ent:sensors.isnull() => {}.put([name], eci) | ent:sensors.put([name], eci)
        }
    }
    
    rule clear_sensors {
      select when zone clear
      foreach wrangler:children() setting (sensor)
      pre {
        name = sensor.get("name").klog()
      }
      noop()
      always {
        raise sensor event "unneeded_sensor"
          attributes {
            "name": name
          }
      }
    }

    rule remove_sensor {
        select when sensor unneeded_sensor
        pre {
            name = event:attr("name").klog("remove_sensor name")
        }
        if ent:sensors >< name then
          send_directive("deleting_sensor", {
            "name" : name,
            "eci" : ent:sensors.get([name])
          });
        fired {
            raise wrangler event "child_deletion"
              attributes {
                "name" : name
              };
            ent:sensors := ent:sensors.delete([name])
        }
    }

}