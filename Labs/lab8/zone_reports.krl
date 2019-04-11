ruleset zone_reports {
    meta {
        name "Thermometer Cowboy Reporter"
        description <<
        Ruleset
        for Managing Zone Reports
        >>
        author "RT Hatfield"
        logging on
        use module io.picolabs.wrangler alias wrangler
        use module io.picolabs.subscription alias subscription
    }

    global {
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

        populate_report_template = function(req_id, tx) {
          report = {"temperature_sensors" : [tx],
                      "responding" : [],
                      "temperatures" : []
                    }
          ent:reports := ent:reports.isnull() => {req_id: report} | (ent:reports.get([req_id]).isnull() => ent:reports.)
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
          }
          event:send({"eci":subscription{"Tx"},
                  "domain":"sensor", 
                  "type":"report_wanted", 
                  "attrs":{
                    "req_id":req_id
                  }
                }); 
          always {
            populate_report_template(req_id, subscription{"Tx"});
            ent:req_id := ent:req_id + 1 on final
          }
      }
    }

    rule collect_report {
      select when sensor report 
      if ent:reports >< event:attr("req_id") then
        pre {
          req_id = event:attr("req_id")
          temperatures = event:attr("temperatures")
          Rx = event:attr("sensor") 
          reports = ent:reports
        }
        noop()
        always {
          report = ent:reports.get(["req_id"])
          report{"responding"}.append(Rx)
          report{"temperatures"}.append(temperatures)
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

}