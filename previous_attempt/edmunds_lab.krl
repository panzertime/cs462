ruleset edmunds_lab {
  meta {
    name "Edmunds lab"
    description <<
Edmunds lab stuff
>>
    author "not Phil Windley"
    use module keys
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
