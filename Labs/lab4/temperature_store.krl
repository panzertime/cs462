ruleset temperature_store {
  meta {
    name "Temperature Storage Base Ruleset"
    description <<
      Ruleset
    for Storing Temperature Measurements
      >>
      author "RT Hatfield"
    logging on
    provides
      temperatures,
      threshold_violations,
      inrange_temperatures
    shares
      temperatures,
      threshold_violations,
      inrange_temperatures
  }

  global {
    temperatures = function() {
      ent:temperatures
    }
    threshold_violations = function() {
      ent:violations
    }
    inrange_temperatures = function() {
      ent:temperatures.filter(function(temp) {
        not ent:violations >< temp
      })
    }
  }

  rule collect_temperatures {
    select when wovyn new_temperature_reading
    pre {
      ev = {
        "temp": event:attr("temperature"),
        "time": event:attr("timestamp")
      }.klog("Temperature collected ")
    }
    noop()
    always {
      ent:temperatures := (ent:temperatures.isnull()) => [ev] | ent:temperatures.append(ev)
    }
  }

  rule collect_threshold_violations {
    select when wovyn threshold_violation
    pre {
      ev ={
        "temp": event:attr("temperature"),
        "time": event:attr("timestamp")
      }.klog("Violation collected ")
    }
    noop()
    always {
      ent:violations := (ent:violations.isnull()) => [ev] | ent:violations.append(ev)
    }
  }

  rule clear_temperatures {
    select when sensor reading_reset
    noop()
    always {
      clear ent:temperatures;
      clear ent:violations
    }
  }
  
}