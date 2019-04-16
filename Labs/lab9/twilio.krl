ruleset lab3.twilio {
  meta {
    configure using account_sid = ""
                    auth_token = ""
    provides
        send_sms,
        retrieve_messages
  }
 
  global {
    send_sms = defaction(to, from, message) {
       base_url = <<https://#{account_sid}:#{auth_token}@api.twilio.com/2010-04-01/Accounts/#{account_sid}/>>
       http:post(base_url + "Messages.json", form = {
                "From":from,
                "To":to,
                "Body":message
            })
    }
    retrieve_messages = function(page_size=50, to_number="", from_number="") {
      base_url = <<https://#{account_sid}:#{auth_token}@api.twilio.com/2010-04-01/Accounts/#{account_sid}/>>;
      query_map = {"PageSize" : page_size};
      add_to = function(qm, to) {
        to.isnull() => qm | qm.put("To", to)
      };
      add_from = function(qm, from) {
        from.isnull() => qm | qm.put("From", from)
      };
      get_raw_messages = function(qm, to, from){
        qs = qm.add_to(to).add_from(from).klog("qs is");
        http:get(base_url + "Messages.json", qs).get(["content"]).decode()
      };
      finalize = function(qm, to, from){
        raw_list = get_raw_messages(qm, to, from){"messages"};
        raw_list.map(function(item) {
          newitem = {};
          newitem.put({"date" : item{"date_sent"}}).put({"to": item{"to"}}).put({"from" : item{"from"}}).put({"body" : item{"body"}})
        })
      };
      finalize(query_map, to_number, from_number)
    }
  }
}