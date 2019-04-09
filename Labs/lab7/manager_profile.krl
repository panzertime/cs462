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
        from_phone = "+19014728912"
        
        
        to_phone = function() {
            ent:profile.isnull() => "+19014513614" | ent:profile
        }
    }

    rule update_profile {
        select when sensor manager_profile_updated
        
        always {
            ent:profile := event:attr("notify_number").isnull() => "+19014513614" | event:attr("notify_number")
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
      select when wovyn threshold_violation
        pre {
          temp = event:attr("temperature")
          time = event:attr("timestamp")
          threshold = event:attr("threshold")
          message = "Temperature " + temp + " violated threshold " + threshold + " at " + time
        }
        twilio:send_sms(to_phone(),
          from_phone,
          message)
    }

}