ruleset manager_profile {
    meta {
        name "Manager Profile Ruleset"
        description <<
        Ruleset
        for Storing Thermometer Manager Metadata
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
        provides
        get_profile
        shares
        get_profile
    }

    global {
        notification_sender = "+19014728912"
        get_profile = function() {
            ent:profile.isnull() => {"threshold":75} | ent:profile
        }
    }

    rule update_profile {
        select when sensor manager_profile_updated
        pre {
            ev = {
            "location" : event:attr("location"),
            "name" : event:attr("name"),
            "threshold" : event:attr("threshold").isnull() => 75 | event:attr("threshold"),
            "notify_number" : event:attr("notify_number").isnull() => "+15555555555" | event:attr("notify_number")
            }.klog("New profile ")
        }
        noop()
        always {
            ent:profile := ev
        }
    }

    rule erase_profile {
        select when sensor clear_profile
        noop()
        always {
            clear ent:profile
        }
    }
    
    rule threshold_notification {
    // move this to 
    // "a profile ruleset to the sensor management pico that contains the SMS 
    // notification number and a means of sending SMS messages to the notification number. "
    select when wovyn threshold_violation
    pre {
      temp = event:attr("temperature")
      time = event:attr("timestamp")
      threshold = event:attr("threshold")
      phone = notification_phone()
      message = "Temperature " + temp + " violated threshold " + threshold + " at " + time
    }
    twilio:send_sms(phone,
      notification_sender,
      message)
  }

}