--- 
wordpress_id: 156
layout: post
title: AOP-style Mixin Composition Stacks in Scala
wordpress_url: http://jonasboner.com/2008/02/06/aop-style-mixin-composition-stacks-in-scala/
---
Scala is one those great languages that is scalable. With scalable I mean that it is the language that grows with the user, that it makes simple things easy and hard things possible. A language that is easy to get started and to become productive in, but at the same time a deep language with very powerful constructs and abstractions. 

In this blog post I will try to highlight the power of <a href="http://www.scala-lang.org/intro/mixin.html">Scala's mixins</a> and how you can use mixin composition to get AOP/interceptor-like style of programming. 

First let's define our service interface, modeled as a mixin (in this case without an implementation so similar to Java's interface):

<pre>
trait Stuff {
  def doStuff
}
</pre>

Now let's define two different mixin "interceptors" that implement the service interface. The first one manages logging and the other one transaction demarcation (but for simplicity I am just using a dummy mock for TX stuff for now): 

<pre>
trait LoggableStuff extends Stuff {
  abstract override def doStuff {
    println("logging enter")
    super.doStuff
    println("logging exit")
  }
}

trait TransactionalStuff extends Stuff {
  abstract override def doStuff {
    println("start TX")
    try {
      super.doStuff
      println("commit TX")      
    } catch {
      case e: Exception => 
        println("rollback TX")   
    } 
  }
}
</pre>

As we can see in this example they both override the <code>Stuff.doStuff</code> method. If we look more closely we can see that they follow the same pattern:

<ul>
<li>Enter method (<tt>doStuff</tt>)</li>
<li>Do something (log, start tx etc.)</li>
<li>Invoke the same method on <tt>super</tt> (<tt>super.doStuff</tt>)</li>
<li>Do something (log, commit tx etc.)</li>
</ul>


The trick here is in the semantics of the call to super. Here Scala will invoke the next mixin in a stack of mixins, e.g. the same method in the "next" mixin that have been mixed in. Exactly what f.e. <a href="http://aspectj.org">AspectJ</a> does in its <tt>proceed(..)</tt> method and what Spring does in its interceptors. 

But before we try this out, let's create a concrete implementation of our <code>Stuff</code> service, called <code>RealStuff</code>:

<pre>
class RealStuff {
  def doStuff = println("doing real stuff")
}
</pre>

Now we have everything we need, so let's fire up the Scala REPL and create a component based on the <code>RealStuff</code> class and a mixin stack with support for logging and transactionality. Scala's mixin composition can take place when we instantiate an instance, e.g. it allows us to mix in functionality into specific instances that object creation time for specific object instances.

First let's create a plain <code>RealStuff</code> instance and run it:
<pre>
scala> import stacks._
import stacks._

scala> val stuff = new RealStuff 
stuff: stacks.RealStuff = $anon$1@6732d42

scala> stuff.doStuff
doing real stuff
</pre>

Not too exciting, but let's do it again and this time mix in the <code>LoggableStuff</code> mixin:

<pre>
scala> val stuff2 = new RealStuff with LoggableStuff 
stuff2: stacks.RealStuff with stacks.LoggableStuff = $anon$1@1082d45

scala> stuff2.doStuff
logging enter
doing real stuff
logging exit
</pre>

As you can see the call to <code>RealStuff.doStuff</code> is intercepted and logging is added before we are invoking this method as well as after. Let's now add the <code>TransactionalStuff</code> mixin:

<pre>
scala> val stuff3 = new RealStuff with LoggableStuff with TransactionalStuff
stuff3: stacks.RealStuff with stacks.LoggableStuff with stacks.TransactionalStuff = $anon$1@4512d65

scala> stuff3.doStuff
start TX
logging enter
doing real stuff
logging exit
commit TX
</pre>

As you can see, the semantics for this mixin stack is the exact same as you would get with stacking AspectJ aspects or Spring interceptors. Another interesting aspect is that the whole composition is statically compiled with all its benefits of compile time error detection, performance, potential tool support etc.

This approach is similar to Rickard Oberg's idea on using the so-called <a href="http://www.jroller.com/rickard/date/20031028">Abstract Schema</a> pattern for type-safe AOP in plain Java. 

It is both simple and intuitive to change the order of the mixin "interceptors", simply change the order in which they are applied to the target instance: 

<pre>
scala> val stuff4 = new RealStuff with TransactionalStuff with LoggableStuff
stuff4: stacks.RealStuff with stacks.TransactionalStuff with stacks.LoggableStuff = $anon$1@a20232

scala> stuff4.doStuff
logging enter
start TX
doing real stuff
commit TX
logging exit
</pre>

Finally, just for fun, let's a create a mixin that can retry failing operations. This particular one will catch any exception that the service might throw and retry it three times before giving up:

<pre>
trait RetryStuff extends Stuff {
  abstract override def doStuff {
    var times = 0
    var retry = true
    while (retry) {
      try {
        super.doStuff      
        retry = false
      } catch {
        case e: Exception => 
          if (times < 3) { // retry 3 times
            times += 1
            println("operation failed - retrying: " + times)
          } else {
            retry = false
            throw e 
          }
      }
    }
  }
}</pre>

To test this behavior (as well as the <em>rollback</em> feature in the <code>TransactionalStuff</code>) we can change the <code>RealStuff.getStuff</code> method to throw an exception: 

</pre><pre>
class RealStuff {
  def doStuff {
    println("doing real stuff")
    throw new RuntimeException("expected")
  }
}
</pre>

Now we can try to add this mixin to the beginning of our our stack and run the service:

<pre>
scala> val stuff5 = new RealStuff with RetryStuff with TransactionalStuff  with LoggableStuff
stuff5: stacks.RealStuff with stacks.RetryStuff with stacks.LoggableStuff with stacks.TransactionalStuff = $anon$1@a927d45

scala> stuff5.doStuff
logging enter
start TX
doing real stuff
operation failed - retrying: 1
doing real stuff
operation failed - retrying: 2
doing real stuff
operation failed - retrying: 3
rollback TX
logging exit
</pre>

Pretty neat, right? 

That's all for now. In the next post I will cover a bunch of ways to use Scala's language primitives to do Dependency Injection (DI).
