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
      // return collected temperatures
    }
    threshold_violations = function() {
      // return collected violations
    }
    inrange_temperatures = function() {
      // return collected temperatures, minus violations
    }
  }

  rule collect_temperatures {
    select when wovyn new_temperature_reading
    // store event attrs in persistent entity variable
  }

  rule collect_threshold_violations {
    select when wovyn threshold_violation
    // store event attrs in persistent entity variable
  }

  rule clear_temperatures {
    select when sensor reading_reset
    // reset temperatures stored by collect_* rules
  }

}