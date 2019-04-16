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