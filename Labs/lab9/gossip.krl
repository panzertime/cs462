ruleset gossip {
  meta {
    name "Woven Thermometer Gossip Ruleset"
    description <<
      Ruleset
    for Gossiping With Wovyn Thermometers
      >>
      author "RT Hatfield"
    logging on
    
    use module io.picolabs.wrangler alias wrangler
    use module io.picolabs.subscription alias subscription
    use module sensor_profile
    use module temperature_store
    
    provides 
      temps,
      peers,
      seen
    shares
      temps,
      peers,
      seen
  }

  global {
    temps = function() {
      get_rumors()
    }
    peers = function() {
      get_peers()
    }
    seen = function() {
      get_seen()
    }
    
    get_peers = function() {
      // {peer_id : subscription_id}
      ent:peers.isnull() => {} | ent:peers
    }
    
    get_sequence = function() {
      ent:sequence.isnull() => 0 | ent:sequence
    }
    
    get_rumors = function() {
      // {peer_id : messageid: message}
      ent:rumors.isnull() => {} | ent:rumors
    }
    
    get_peer_seen = function() {
      // {peerId: origin: max_sequence}
      ent:peer_seen.isnull() => {} | ent:peer_seen
    }
    
    get_seen = function() {
      // {origin: highest sequence}
      ent:seen.isnull() => {} | ent:seen
    }
    
    get_message_id = function() {
      meta:picoId.as("String") + ":" + get_sequence().as("String")
    }
    
    prepareMessage = function(node, type) {
      rumor = get_rumor(node{"peer_id"});
      // if we can't get a fresh rumor for that peer (i.e. everyone is caught up)
      // we default to sending a seen message. if we have peers that need rumors,
      // they should show up here first and have a 50/50 chance of getting one
      type = rumor.isnull() => "seen" | ["rumor", "seen"][random:integer(1)];
      body = (type == "seen") =>  get_seen() | rumor; 
      {
        "eci": node{"Tx"},
        "domain": "gossip",
        "type": type,
        "attrs": {
          "node": meta:picoId,
          "body": body
        }
      }
    }
    
    get_rumor = function(peer_id) {
      // given this peer ID, pick something they haven't seen and send it
      p_seen = get_peer_seen().get(peer_id);
      rumor = get_rumors().values().reduce(function(acc, rumors){
        acc.append(rumors)
      }, []).filter(function(rumor){
        origin = rumor{"SensorID"};
        sequence = rumor{"MessageID"}.split(":")[1].as("Number");
        sequence > p_seen.get(origin).defaultsTo(-1)
      }).head();
      rumor.values()[0]
    }
    
    select_unseen = function(seen) {
      // takes map of seen messages, returns array of messages to forward
      get_rumors().values().reduce(function(acc, rumors){
        acc.append(rumors.values())
      }, []).filter(function(rumor){
        origin = rumor{"SensorID"};
        sequence = rumor{"MessageID"}.split(":")[1].as("Number");
        sequence > seen.get(origin).defaultsTo(-1)
      })
    }
    
    store_rumor = function(rumor) {
      rumors = get_rumors().get(rumor{"SensorID"}).defaultsTo({});
      rumors = rumors.put([rumor{"MessageID"}], rumor);
      get_rumors().put([rumor{"SensorID"}], rumors);
    }
      
      
    heartbeat_update = function(event, peer_id) {
      // basically check if we sent a rumor, and if so, we update the peer seen
      body = event{"body"};
      event{"type"} == "rumor" => 
          update_peer_seen(peer_id, body{"SensorID"}, body{"MessageID"}.split(":")[1].as("Number")) |
          get_peer_seen()
    }
    
    update_peer_seen = function(peer_id, origin, sequence) {
      max_seq = get_peer_seen().get([peer_id, origin]).defaultsTo(0);
      new_seq = (sequence >= max_seq) => new_seq | max_seq;
      get_peer_seen().put([peer_id, origin], new_seq)
    }
    
    update_peer_after_seen = function(peer_id, messages) {
      peer_seen = get_peer_seen();
      messages.reduce(function(acc, rumor) {
        origin = rumor{"SensorID"};
        sequence = rumor{"MessageID"}.split(":")[1];
        max_seq = acc.get([peer_id, origin]).defaultsTo(0);
        new_seq = (sequence >= max_seq) => new_seq | max_seq;
        acc.put([peer_id, origin], new_seq)
      }, peer_seen)
    }
    
    update_seen = function(origin, sequence) {
      // somehow this is getting called with own-origin. gotta figure it out
      max_seq = get_seen().get(origin).defaultsTo(0);
      new_seq = (sequence - max_seq == 1) => new_seq | max_seq;
      get_seen().put(origin, new_seq)
    }
    
    start_rumor = function(temp, time) {
      {
        "MessageID": get_message_id(),
        "SensorID": meta:picoId.as("String"),
        "Temperature": temp,
        "Timestamp": time
      }
    }
    
    getPeer = function() {
      score_peer = function(peer) {
        // one point for each sensor they have less info on than we do
        keys = get_seen().keys().union(get_peer_seen(peer).keys());
        keys.reduce(function(score, key){
          diff = get_seen().get(key).defaultsTo(-1) - 
                 get_peer_seen().get(key).defaultsTo(-1);
          diff > 0 => score + 1 | score
        }, 0)
      };
      peers = get_peer_seen().filter(function(peer) {
        score_peer(peer) > 0 || peer.keys().length() == 0
      });
      
      // pick randomly from the reduced set if we can, the main set otherwise
      // random choice means everyone gets a chance, though when we have 
      // rumors to send they get to go before seens get sent to peers who have
      // our rumors already
      // i.e. we don't update ourselves until we've updated our friends
      peer_id = (peers.length() == 0) =>
        get_peers().keys()[random:integer(get_peers().keys().length() - 1)] |
        peers.keys()[random:integer(peers.length().keys() - 1)];

      sub = subscription:established("Id", get_peers(){"peer_id"})[0];
      {
        "peer_id": peer_id,
        "Tx": sub{"Tx"},
        "Rx": sub{"Rx"},
        "Tx_host": sub{"Tx_host"}
      }
    }
    
    pump_velocity = function() {
      n = 15;
      time:add(time:now(), {"seconds": n})
    }
    
    respondToSeen = defaction(messages, Tx, host) {
      msg = messages.head()
      if not msg.isnull() then
      every {
        event:send({
          "eci": Tx.klog("Tx"),
          "domain": "gossip",
          "type": "rumor",
          "attrs": {
            "node": meta:picoId,
            "body": msg
          }
        }, host);
        respondToSeen(messages.tail(), Tx, host)
      }
    }
  }

  rule process_heartbeat {
    select when gossip heartbeat
    pre {
      peer = getPeer()
      event = prepareMessage(peer)
    }
    if not event{"eci"}.isnull() then
    event:send(event, host=peer{"Tx_host"});
    fired {
      ent:peer_seen := heartbeat_update(event, peer{"peer_id"}); 
    } finally {
      schedule gossip event "heartbeat" at pump_velocity()
    }
  }
  
  rule autostart {
    select when wrangler ruleset_added where rids >< meta:rid
    always {
      schedule gossip event "heartbeat" at pump_velocity()
    }
  }
  
  rule process_rumor {
    select when gossip rumor
    pre {
      rumor = event:attr("body")
      peer_id = event:attr("node")
      origin = rumor{"SensorID"}
      message_id = rumor{"MessageID"}
      sequence = message_id.split(":")[1].as("Number")
    }
    if (sequence > get_seen().get(origin).defaultsTo(-1)) then
      noop();
    fired {
      ent:rumors := store_rumor(rumor);
      ent:seen := update_seen(origin, sequence);
      ent:peer_seen := update_peer_seen(peer_id, origin, sequence);
    }
  }
  
  rule process_seen {
    select when gossip seen
    pre {
      seen = event:attr("body")
      peer_id = event:attr("node")
      sub = subscription:established("Id", get_peers().get(peer_id))[0]
      messages = select_unseen(seen)
    }
    
    if messages.length() > 0 then
    respondToSeen(messages, sub{"Tx"}, sub{"Tx_host"})
    
    fired{
      ent:peers_seen := update_peer_after_seen(peer_id, messages)
    }
  }
  
  rule increment_sequence {
    select when wovyn new_temperature_reading
    pre {
      temp = event:attr("temperature")
      time = event:attr("timestamp")
      rumor = start_rumor(temp, time)
    }
    noop();
    always {
      ent:rumors := store_rumor(rumor);
      ent:sequence := get_sequence() + 1;
      ent:seen := update_seen(meta:picoId, get_sequence())
    }
  }
  
  

  rule auto_accept {
    select when wrangler inbound_pending_subscription_added
    fired {
      raise wrangler event "pending_subscription_approval"
        attributes event:attrs
    }
  }
  
  rule request_peer {
    select when gossip peer
    pre {
      new_peer_eci = event:attr("eci")
      new_peer_host = event:attr("host")
      name = sensor_profile:get_profile(){"name"}.isnull() => wrangler:randomPicoName() | sensor_profile:get_profile(){"name"}
    }
    event:send(
      {
        "eci": new_peer_eci,
        "domain": "gossip",
        "type": "hello",
        "attrs" : {
          "wellKnown" : subscription:wellKnown_Rx(){"id"},
          "host" : meta:host,
          "ids" : [meta:picoId],
          "name" : name
        }
      }, host=new_zone_host)
  }

  rule accept_peer {
    select when gossip hello
    pre {
        wellKnown = event:attr("wellKnown")
        name = event:attr("name")
        host = event:attr("host").isnull() => meta:host | event:attr("host")
        ids = event:attr("ids").append(meta:picoId)
      }
      noop();
      fired {
        raise wrangler event "subscription" attributes
             { "name" : name,
               "peer_ids" : ids,
               "Rx_role": "node",
               "Tx_role": "node",
               "channel_type": "subscription",
               "wellKnown_Tx": wellKnown,
               "Tx_host": host
             };
      }
  }

  rule save_new_subscription {
    select when wrangler subscription_added
    pre {
      remoteHost = event:attr("Tx_host").klog("Remote host: ")
      name = event:attr("name")
      id  = event:attr("Id")
      peer_id = event:attr("peer_ids").difference(meta:picoId)[0]
    }
    send_directive("sensor_subscribed", {
        "remoteHost" : remoteHost
      })
    always {
      ent:peer_seen := get_peer_seen().put([peer_id], {});
      ent:peers := get_peers().put([peer_id], id)
    }
  }


}