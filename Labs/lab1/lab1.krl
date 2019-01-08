ruleset hello_world {
  meta {
    name "Hello World"
    description <<
A first ruleset for the Quickstart
>>
    author "Phil Windley"
    logging on
    shares hello
  }
  
  global {
    hello = function(obj) {
      msg = "Hello " + obj;
      msg
    }
  }
  
  rule hello_world {
    select when echo hello
    send_directive("say", {"something": "Hello World"})
  }

  rule hello_monkey {
    select when echo monkey
    pre{
      name = event:attr("name").defaultsTo("Monkey").klog("the name attribute: ")
    }
    send_directive("say", {"something": "Hello " + name})
  }

  rule hello_monkey_ternary {
    select when echo monkey_t
    pre{
      name = ((event:attr("name")) => (event:attr("name")) | "Monkey").klog("the name attribute: ")
    }
    send_directive("say", {"something": "Hello " + name})
  }
}