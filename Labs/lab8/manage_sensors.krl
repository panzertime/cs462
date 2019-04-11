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

        last_five_reports = function() {
          /*
get the keys of the map
sort the keys
splice(0,keys.length() - 6)
reduce(function(tgt, k) {
src = ent:req_id{k}
src.set(["temperature_sensors"], src{"temperature_sensors"}.length())
src.set(["responding"], src{"responding"}.length())
tgt = tgt.isnull() => {} | tgt
tgt.put([k], src)
}
/*
          // get the 5 last reports, send those back, if more than five, 
          // set entity variable to just those five
          // (may be easier to not do this, but have an event that clears the log)
          /*
          // EXCEPT:
          // make the sensors and responding be LISTS of the Rx's and Tx's, for matching
          // and on sending, "collapse" them to just counts
          ent:reports := {<report_id>: {"temperature_sensors" : 4,
                  "responding" : 4,
                  "temperatures" : [<temperature reports from sensors>]
                 }
}
*/      
          null
        }

        


    }

    rule request_report {
      select when zone report
      /*
      You will need a rule in the  manage_sensors ruleset that sends an event to each sensor pico (and only sensors) in the collection notifying them that a new temperature report is needed. Be sure there's a correlation ID in the event sent to the sensor picos and that it's propagated. 
      */
        foreach subscription:established("Rx_role", "temp_sensor") setting (subscription)
          pre {
            req_id = ent:req_id.isnull() => 1 | ent:req_id
            tx = subscription{"Tx"}
          }
          event:send({"eci":tx,
                  "domain":"sensor", 
                  "type":"report_wanted", 
                  "attrs":{
                    "req_id":req_id
                  }
                }); 
          always {
            report = ent:reports.get([req_id]).isnull() => 
                    {"temperature_sensors" : [],
                      "responding" : [],
                      "temperatures" : []
                    } | ent:reports.get([req_id]);
            report.set(["temperature_sensors"], report{"temperature_sensors"}.append(tx));
            ent:reports := ent:reports.set([req_id], report);
          
            ent:req_id := ent:req_id + 1 on final
          }
    }
  

    rule collect_report {
      select when sensor report 
      pre {
          req_id = event:attr("req_id")
          temperatures = event:attr("temperatures")
          Rx = event:attr("sensor") 
          reports = ent:reports
        }
      if ent:reports >< req_id then
      noop()
      always {
        report = ent:reports.get(["req_id"]);
        report{"responding"}.append(Rx);
        report{"temperatures"}.append(temperatures);
        ent:reports := ent:reports.set(["req_id"], report)
      }
    }

    rule clear_reports {
      select when zone clear_reports
      noop()
      always{
        clear ent:reports
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
                "wellKnown_Rx"){"id"}.klog("wellKnown of new sensor is: ")
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
          remoteHost = event:attr("Tx_host").klog("Remote host: ")
          name = event:attr("name")
          Tx  = event:attr("Tx")
        }
        
        send_directive("sensor_subscribed", {
            "remoteHost" : remoteHost
          })
          always {
            ent:sensors := ent:sensors.isnull() => {}.put([Tx], name) | ent:sensors.put([Tx], name)
          }
    }

    rule introduce_new_sensor {
      select when sensor hello
      pre {
        wellKnown = event:attr("wellKnown")
        name = event:attr("name")
        host = event:attr("host").isnull() => meta:host | event:attr("host")
      }
      noop();
      fired {
        raise wrangler event "subscription" attributes
             { "name" : name,
               "Rx_role": "temp_sensor",
               "Tx_role": "zone",
               "channel_type": "subscription",
               "wellKnown_Tx": wellKnown,
               "Tx_host": host
             };
      }
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