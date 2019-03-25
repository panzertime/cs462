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
            // change this to do
            //    subscription:established().filter(Tx_role = temp_sensor)
            //    and query ent:sensors by id to find the name
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
                "wellKnown_Rx")
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
          raise wrangler event "subscription" attributes
             { "name" : name,
               "Rx_role": "temp_sensor",
               "Tx_role": "zone",
               "channel_type": "subscription",
               "wellKnown_Tx" : wellKnown
             };
             // save name by Tx instead of by eci
          ent:sensors := ent:sensors.isnull() => {}.put([name], eci) | ent:sensors.put([name], eci)
        }
    }

    rule save_new_subscription {
        select when wrangler subscription_added
        // "You will still need an entity variable to keep track of 
        // names and any other information you need, but you won't use it to 
        // find sensor picos. You can use the subscription Tx channel as a 
        // unique identifier if you need to. Wrangler raises a wrangler 
        // subscription_added event that might be handy to find the Tx."
        //    This may not actually be necessary to do
        //    This may be the best place to print out the Tx_host debug info
        // subscription:established DOES NOT contain names => do need to save them
        //    here. :(
        // nvm we're saving the name earlier. what to do here?
        pre {
            name = "Bob"
        }
        noop()
        always {
          // save the subscription's enrich Tx
            // save the subscription
            // ent:subscriptions :=
            //      {'subscription_role': [Tx_channels]}
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