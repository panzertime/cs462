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
        
        get_reports = function() {
        }

        last_five_reports = function() {
          ent:reports
          /*
          keys = ent:reports.keys();
          keys = keys.splice(0, keys.length()-6);
          keys.reduce(function(tgt, k) {
            src = ent:reports.get([k]);
            src.set(["temperature_sensors"], src{"temperature_sensors"}.length());
            src.set(["responding"], src{"responding"}.length());
            tgt = tgt.isnull() => {"reports":{}} | tgt;
            tgt.put(["reports",k], src);
            tgt.put(["report_time"], time:now())
          })
          */
        }
    }

    rule request_report {
      select when zone report
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
            ent:reports := ent:reports.isnull() => {} | ent:reports;
            report = ent:reports.get([req_id]).isnull() => 
                    {"temperature_sensors" : [],
                      "responding" : [],
                      "temperatures" : []
                    } | ent:reports.get([req_id]); 
            report = report.set(["temperature_sensors"], report{"temperature_sensors"}.append(tx));
            ent:reports := ent:reports.get([req_id]).isnull() =>
                    ent:reports.put([req_id], report) |
                    ent:reports.set([req_id], report);
                    
            ent:req_id := ent:req_id.isnull() => 2 | ent:req_id + 1 on final
          }
    }
  

    rule collect_report {
      select when sensor report 
      pre {
          req_id = event:attr("req_id").as("String")
          temperatures = event:attr("temperatures").klog("temperatures: ")
          Rx = event:attr("sensor").klog("sensor-submitted rx: ")
        }
      if ent:reports >< req_id then
        noop()
      fired {
        report = ent:reports.get([req_id]);
        report = report.set(["responding"], report{"responding"}.append(Rx));
        report = report.set(["temperatures"], report{"temperatures"}.append(temperatures));
        ent:reports := ent:reports.set([req_id], report)
      }
    }

    rule clear_reports {
      select when zone clear_reports
      noop()
      always{
        clear ent:reports
      }
    }
    
    rule clear_reqs {
      select when zone clear_requests
      noop()
      always{
        clear ent:req_id
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