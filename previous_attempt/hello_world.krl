ruleset hello_world {
  meta {
    name "Hello World"
    description <<
A first ruleset for the Quickstart
>>
    author "not Phil Windley"
    logging on
    shares hello
    key edmunds {
      "key" : "k4ahwak7vvu2m2eftvz3tutg",
      "secret" : "JTwDtptwymwkaeq7jT5KD3Fj"
    }
  }
  
  global {
    hello = function(obj) {
      msg = "Hello " + obj;
      msg
    }
  }
  
  rule hello_world {
    select when echo hello
    send_directive("say") with
      something = "Hello World"
  }
  
  rule hello_monkey {
	select when echo monkey
	pre{
		name = (event:attr("name")) => (event:attr("name")) | "Monkey"
	}
    	send_directive("say") with
		something = "Hello " + name
  }
  
}
