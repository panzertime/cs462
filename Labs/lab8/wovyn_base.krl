ruleset wovyn_base {
  meta {
    name "Woven Thermometer Base Ruleset"
    description <<
      Ruleset
    for Interacting With Wovyn Thermometers
      >>
      author "RT Hatfield"
    logging on
    
    use module sensor_profile
    use module io.picolabs.subscription alias subscription
  }

  global {
    temperature_threshold = function() {
      sensor_profile:get_profile(){"threshold"}
    }
  }

  rule process_heartbeat {
    select when wovyn heartbeat
    pre {
      generic = event:attr("genericThing")
      temp_list = generic.get(["data", "temperature"])
    }
    if not generic.isnull() then
    send_directive("say", {
      "message": "Wovyn's heart is beating",
      "heartbeat_temps": temp_list
    })
    fired {
      raise wovyn event "new_temperature_reading"
        attributes {
          "temperature": temp_list.map(function (a) {
            a.get("temperatureF")
          }).reduce(function (a, b) {
            a + b
          }) / temp_list.length(),
          "timestamp": time:now()
        }
    }
  }
    rule find_high_temps {
    select when wovyn new_temperature_reading
    pre {
      temp = event:attr("temperature").klog("Temp ")
      time = event:attr("timestamp").klog("Time ")
      threshold = temperature_threshold()
      message = (temp > temperature_threshold) => "Threshold violated!" | "Threshold NOT violated!"
    }
    send_directive("say", {
      "message": message,
      "max temp": temp,
      "threshold": threshold
    })
    always {
      raise wovyn event "threshold_violation"
        attributes {
          "temperature": temp,
          "timestamp": time,
          "threshold" : threshold
        } if temp > threshold
    }
  }
  
  rule auto_accept {
    select when wrangler inbound_pending_subscription_added
    fired {
      raise wrangler event "pending_subscription_approval"
        attributes event:attrs
    }
  }
  
  rule join_zone {
    select when sensor join
    pre {
      new_zone_eci = event:attr("eci")
      new_zone_host = event:attr("host")
      name = sensor_profile:get_profile(){"name"}.isnull() => wrangler:randomPicoName() | sensor_profile:get_profile(){"name"}
    }
    event:send(
      {
        "eci": new_zone_eci,
        "domain": "sensor",
        "type": "hello",
        "attrs" : {
          "wellKnown" : subscription:wellKnown_Rx(){"id"},
          "host" : meta:host,
          "name" : name
        }
      }, host=new_zone_host)
  }
  
  rule forward_violation {
    select when wovyn threshold_violation
    foreach subscription:established("Rx_role", "zone") setting (subscription)
      pre {
        thing_subs = subscription.klog("subs")
      }
      event:send({"eci":subscription{"Tx"},
                  "domain":"wovyn", 
                  "type":"threshold_violation", 
                  "attrs":event:attrs}); 
  }

  

}