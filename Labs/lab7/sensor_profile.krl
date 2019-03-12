ruleset sensor_profile {
    meta {
        name "Thermometer Profile Ruleset"
        description <<
        Ruleset
        for Storing Thermometer Metadata
        >>
        author "RT Hatfield"
        logging on
        provides
        get_profile
        shares
        get_profile
    }

    global {
        get_profile = function() {
            ent:profile.isnull() => {"threshold":75} | ent:profile
        }
    }

    rule update_profile {
        select when sensor profile_updated
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

}