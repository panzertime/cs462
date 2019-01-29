ruleset lab3 {
  meta {
    name "Lab 3"
    description <<
Lab 3: Rules, Events and Intermediaries
>>
    author "RT Hatfield"
    logging on
    use module twilio_keys
    use module lab3.twilio alias twilio
        with account_sid = keys:twilio{"account_sid"}
            auth_token = keys:twilio{"auth_token"}
  }
  
  rule test_send_sms {
    select when test new_message
    pre{
      to_field = event:attr("to").klog("To field: ")
    }
    twilio:send_sms(event:attr("to"),
                    event:attr("from"),
                    event:attr("message")
                   )
  }
  rule test_receive_sms {
    select when test get_messages
    pre{
      to_field = event:attr("to").klog("To field: ")
      from_field = event:attr("from").klog("From field: ")
      page_size = event:attr("page_size").klog("Page size: ")
      resp_page = (page_size.isnull() => twilio:retrieve_messages(to_number=to_field, from_number=from_field) | twilio:retrieve_messages(page_size, to_field, from_field))
    }
    send_directive("say", 
      {"message": "Rule works!",
        "content": resp_page
      })
  }
}