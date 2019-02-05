ruleset wovyn_base {
  meta {
    name "Woven Thermometer Base Ruleset"
    description <<
      Ruleset
    for Interacting With Wovyn Thermometers
      >>
      author "RT Hatfield"
    logging on
    use module twilio_keys
    use module lab3.twilio alias twilio
    with account_sid = keys:twilio {
      "account_sid"
    }
    auth_token = keys:twilio {
      "auth_token"
    }
  }

  global {
    temperature_threshold = 70
    notification_phone = "+19014513614"
    notification_sender = "+19014728912"
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
      message = (temp > temperature_threshold) => "Threshold violated!" | "Threshold NOT violated!"
    }
    send_directive("say", {
      "message": message,
      "max temp": temp,
      "threshold": temperature_threshold
    })
    always {
      raise wovyn event "threshold_violation"
        attributes {
          "temperature": temp,
          "timestamp": time
        } if temp > temperature_threshold
    }
  }

  rule threshold_notification {
    select when wovyn threshold_violation
    pre {
      temp = event:attr("temperature")
      time = event:attr("timestamp")
      message = "Temperature " + temp + " violated threshold " + temperature_threshold + " at " + time
    }
    twilio:send_sms(notification_phone,
      notification_sender,
      message)
  }

}