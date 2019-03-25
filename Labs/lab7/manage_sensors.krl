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
        temperatures
        shares
        sensors,
        temperatures
    }

    global {
        sensors = function() {
            ent:sensors.isnull() => {} | ent:sensors
        }
        
        temperatures = function() {
            subscription:established("Rx_role", "temp_sensor").map(function(sub){
                {
                  "name":ent:sensors.get([sub{"Tx"}]),
                  "temperatures":wrangler:skyQuery(sub{"Tx"}, 
                        "temperature_store", 
                        "temperatures", 
                        null)
                }
            })
        }

        get_threshold = function() {
            75
        }

    }

    rule add_sensor {
        select when sensor new_sensor
        pre {
            name = event:attr("name")
            exists = ent:sensors.values() >< name
        }
        if exists then
            send_directive("sensor_already_exists", {
              "name" : name
            })
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
            name = event:attr("name")
            eci = event:attr("eci")
            wellKnown = wrangler:skyQuery(eci, "io.picolabs.subscription",
                "wellKnown_Rx"){"id"}
        }
        
        every {
          send_directive("sensor_initialized", {
            "name" : name,
            "eci" : eci,
            "wellKnown_Rx" : wellKnown
          });
          event:send({
                "eci": eci,
                "eid": "update-profile",
                "domain": "sensor",
                "type": "profile_updated",
                "attrs": {
                    "threshold" : get_threshold(),
                    "location" : "",
                    "name" : name
                }
            });
        }
        fired {
          raise wrangler event "subscription" attributes
             { "name" : name,
               "Rx_role": "temp_sensor",
               "Tx_role": "zone",
               "channel_type": "subscription",
               "wellKnown_Tx" : wellKnown
             };
        }
    }

    rule save_new_subscription {
        select when wrangler subscription_added
        pre {
          remoteHost = event:attr("Tx_host")
          name = event:attr("name")
          Tx  = event:attr("Tx")
        }
        
        send_directive("sensor_added", {
            "remoteHost" : remoteHost
          })
          always {
            ent:sensors := ent:sensors.isnull() => {}.put([Tx], name) | ent:sensors.put([Tx], name)
          }
    }

    rule accept_introductions {
      select when unknowable null_event
        // ??? need to rewatch the video
        // Use event attributes to identify which sensor pico to introduce.  Make sure the auto subscription is working.
        
    }

    rule remove_sensor {
        select when sensor unneeded_sensor
        pre {
            name = event:attr("name")
        }
        if ent:sensors.values() >< name then
          send_directive("deleting_sensor", {
            "name" : name
          });
        fired {
            raise wrangler event "child_deletion"
              attributes {
                "name" : name
              };
        }
    }

}