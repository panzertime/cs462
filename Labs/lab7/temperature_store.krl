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
      temperature_now,
      temperatures,
      threshold_violations,
      inrange_temperatures
    shares
      temperature_now,
      temperatures,
      threshold_violations,
      inrange_temperatures
  }

  global {
    temperature_now = function() {
      ent:temperature_now.isnull() => 0 | ent:temperature_now
    }
    temperatures = function() {
      ent:temperatures.isnull() => [] | ent:temperatures
    }
    threshold_violations = function() {
      ent:violations.isnull() => [] | ent:violations
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
      ent:temperatures := (ent:temperatures.isnull()) => [ev] | ent:temperatures.append(ev);
      ent:temperature_now := ev.get("temp")
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