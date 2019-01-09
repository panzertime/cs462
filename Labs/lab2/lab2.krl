ruleset lab2 {
  meta {
    name "Lab 2"
    description <<
Lab 2: sending and checking SMS via Twilio
>>
    author "RT Hatfield"
    logging on
    use module twilio_keys
    use module lab2.twilio alias twilio
        with account_sid = keys:twilio{"account_sid"}
            auth_token = keys:twilio{"auth_token"}
  }
  
  rule test_send_sms {
    select when test new_message
    twilio:send_sms(event:attr("to"),
                    event:attr("from"),
                    event:attr("message")
                   )
  }
}