--- 
wordpress_id: 157
layout: post
title: Erlang-style Supervisor Module for Scala Actors
wordpress_url: http://jonasboner.com/2008/06/16/erlang-style-supervisor-module-for-scala-actors/
---
In this post I will explain how you can build fault-tolerant systems using Scala Actors by arranging them in Supervisor hierarchies using a library for Scala Supervisors that I just released. 

But first, let's recap what Actors are and what makes them useful. 

An actor is an abstraction that implements <a href="http://c2.com/cgi/wiki?MessagePassingConcurrency">Message-Passing Concurrency</a>. Actors have no shared state and are communicating by sending and receiving messages. This is a paradigm that provides a very different and much simpler concurrency model than <a href="http://c2.com/cgi/wiki?SharedStateConcurrency">Shared-State Concurrency</a> (the scheme adopted by C, Java, C# etc.) and making it easier to avoid problems like deadlocks, live locks, thread starvation etc. This makes it possible to write code that is deterministic and <a href="http://en.wikipedia.org/wiki/Side_effect_%28computer_science%29">side-effect-free</a>, something that makes easier to write, test, understand and reason about. Each actor has a mailbox in which it receives incoming messages and can use pattern matching on the messages to decide if a message is interesting and which action to take.  The most well known and successful implementation of actors can be found in the Erlang language (and the OTP platform) where it has been used to implement extremely fault tolerant (<a href="http://ll2.ai.mit.edu/talks/armstrong.pdf ">99.9999999% reliability - 9 nines</a>) and massively concurrent systems (with hundreds of thousand simultaneous actors). 

So what are Supervisor hierarchies? Let's go to the source; <a href="http://www.erlang.org/doc/design_principles/sup_princ.html#5">http://www.erlang.org/doc/design_principles/sup_princ.html#5</a>. 

<blockquote>A supervisor is responsible for starting, stopping and monitoring its child processes. The basic idea of a supervisor is that it should keep its child processes alive by restarting them when necessary.</blockquote>

It has two different restart strategies; <em>All-For-One</em> and <em>One-For-One</em>. Best explained using some pictures (referenced from erlang.org): 

<strong>OneForOne</strong>
<img src="http://www.erlang.org/doc/design_principles/sup4.gif" alt="OneForOne" />

<strong>AllForOne</strong>
<img src="http://www.erlang.org/doc/design_principles/sup5.gif" alt="AllForOne" />

Naturally, the library I have written for Scala is by no means as complete and hardened as Erlang's, but it seems to do a decent job in providing the core functionality. 

The implementation consists of two main abstractions; <code>Supervisor</code> and <code>GenericServer</code>. 

* The Supervisor manages hierarchies of Scala actors and provides fault-tolerance in terms of different restart semantics. The configuration and semantics is almost a 1-1 port of the Erlang Supervisor implementation, explained in the <a href="http://erlang.org">erlang.org</a> doc referenced above. Read this document in order to understand how to configure the Supervisor properly. 

* The GenericServer (which subclasses the Actor class) is a trait that forms the base for a server to be managed by a Supervisor. 

The GenericServer is wrapped by a GenericServerContainer instance providing a necessary indirection needed to be able to fully manage the life-cycle of the GenericServer in an easy way. 

So, let's try it out by writing a small example in which we create a couple of servers, configure them, use them in various ways, kill one of them, see it recover, hotswap its implementation etc. 

(Sidenote: I have <a href="http://jonasboner.com/2007/12/19/hotswap-code-using-scala-and-actors/">written about hotswapping actors</a> before, however this library has taken this approach a but further and provides a more flexible and powerful way of achieving this. Thanks <a href="http://blog.lostlake.org/">DPP</a>.)

This walk-through will only cover some of the API, for more details look at the code or the tests.

<strong>1. Create our server messages</strong>

<pre>
import scala.actors._
import scala.actors.Actor._

import com.jonasboner.supervisor._
import com.jonasboner.supervisor.Helpers._

sealed abstract class SampleMessage
case object Ping extends SampleMessage
case object Pong extends SampleMessage
case object OneWay extends SampleMessage
case object Die extends SampleMessage
</pre>

<strong>2. Create a <code>GenericServer</code></strong>
We do that by extending the <code>GenericServer</code> trait and override the <code>body</code> method.

<pre>
class SampleServer extends GenericServer {

  // This method implements the core server logic and naturally has to be overridden
  override def body: PartialFunction[Any, Unit] = {
    case Ping => 
      println("Received Ping"); reply(Pong)

    case OneWay => 
      println("Received OneWay")

    case Die => 
      println("Received Die..dying...") 
      throw new RuntimeException("Received Die message")
  }

}
</pre>

<code>GenericServer</code> also has some callback life-cycle methods, such as <code>init(..)</code> and <code>shutdown(..)</code>.

<strong>3. Wrap our <code>SampleServer</code> in a <code>GenericServerContainer</code></strong>
Here we also give it a name to be able to refer to it later. We are creating two instances of the same server impl in order to try out multiple server restart in case of failure. 

<pre>
object sampleServer1 extends GenericServerContainer("sample1", () => new SampleServer)
object sampleServer2 extends GenericServerContainer("sample2", () => new SampleServer)
</pre>

<strong>4. Create a <code>Supervisor</code> configuration</strong>
Here we create a <code>SupervisorFactory</code> that is configuring our servers. The configuration mimics the Erlang configuration and defines a general restart strategy for our <code>Supervisor</code> as well as a list of workers (servers) which for each we define a specific life-cycle.

<pre>
object factory extends SupervisorFactory {
  override protected def getSupervisorConfig: SupervisorConfig = {
    SupervisorConfig(
      RestartStrategy(AllForOne, 3, 10000),
       Worker(
        sampleServer1,
        LifeCycle(Permanent, 1000)) ::
       Worker(
        sampleServer2,
        LifeCycle(Permanent, 1000)) ::
      Nil)
  }
}
</pre>

<strong>5. Create a new <code>Supervisor</code></strong>

<pre>
val supervisor = factory.newSupervisor
</pre>

Output: 
<pre>
12:25:30.031 [Thread-2] DEBUG com.jonasboner.supervisor.Supervisor - Configuring supervisor:com.jonasboner.supervisor.Supervisor@860d49
12:25:30.046 [Thread-2] DEBUG com.jonasboner.supervisor.Supervisor - Linking actor [Main$SampleServer$1@1b9240e] to supervisor [com.jonasboner.supervisor.Supervisor@860d49]
12:25:30.062 [Thread-2] DEBUG com.jonasboner.supervisor.Supervisor - Linking actor [Main$SampleServer$1@1808199] to supervisor [com.jonasboner.supervisor.Supervisor@860d49]
12:25:30.062 [main] DEBUG Main$factory$2$ - Supervisor successfully configured
</pre>

<strong>6. Start the <code>Supervisor</code></strong>
This also starts the servers.

<pre>
supervisor ! Start
</pre>

Output: 
<pre>
12:25:30.078 [Thread-8] INFO  com.jonasboner.supervisor.Supervisor - Starting server: Main$sampleServer2$2$@1479feb
12:25:30.078 [Thread-8] INFO  com.jonasboner.supervisor.Supervisor - Starting server: Main$sampleServer1$2$@97a560
</pre>

<strong>7. Try to communicate with the servers.</strong>
Here we try to send a couple one way asynchronous messages to our servers. 
<pre>
sampleServer1 ! OneWay
</pre>

Try to get a reference to our sampleServer2 (by name) from the Supervisor before sending a message.

<pre>
supervisor.getServer("sample2") match {
  case Some(server2) => server2 ! OneWay
  case None => println("server [sample2] could not be found")
}
</pre>

Output: 
<pre>
Received OneWay
Received OneWay
</pre>

<strong>8. Send a message using a future</strong>
Try to send an asynchronous message - receive a future - and wait 100 ms (time-out) for the reply.

<pre>
val future = sampleServer1 !! Ping
val reply1 = future.receiveWithin(100) match {
  case Some(reply) => 
    println("Received reply: " + reply)
  case None => 
    println("Did not get a reply witin 100 ms")
}
</pre>

Output: 
<pre>
Received Ping
Received reply: Pong
</pre>

<strong>9. Kill one of the servers</strong>
Try to send a message (Die) telling the server to kill itself (by throwing an exception).

<pre>
sampleServer1 ! Die
</pre>

Output: 
<pre>
Received Die..dying...
12:25:30.093 [Thread-8] ERROR c.j.supervisor.AllForOneStrategy - Server [Main$SampleServer$1@1b9240e] has failed due to [java.lang.RuntimeException: Received Die message] - scheduling restart - scheme: ALL_FOR_ONE.
12:25:30.093 [Thread-8] DEBUG Main$sampleServer2$2$ - Waiting 1000 milliseconds for the server to shut down before killing it.
12:25:30.093 [Thread-8] DEBUG Main$sampleServer2$2$ - Server [sample2] has been shut down cleanly.
12:25:30.093 [Thread-8] DEBUG c.j.supervisor.AllForOneStrategy - Restarting server [sample2] configured as PERMANENT.
12:25:30.093 [Thread-8] DEBUG com.jonasboner.supervisor.Supervisor - Linking actor [Main$SampleServer$1@166aa18] to supervisor [com.jonasboner.supervisor.Supervisor@860d49]
12:25:30.093 [Thread-8] DEBUG Main$sampleServer1$2$ - Waiting 1000 milliseconds for the server to shut down before killing it.
12:25:30.093 [main] DEBUG com.jonasboner.supervisor.Helpers$ - Future timed out while waiting for actor: Main$SampleServer$1@1b9240e
Expected exception: java.lang.RuntimeException: Time-out
12:25:31.093 [Thread-8] DEBUG c.j.supervisor.AllForOneStrategy - Restarting server [sample1] configured as PERMANENT.
12:25:31.093 [Thread-8] DEBUG com.jonasboner.supervisor.Supervisor - Linking actor [Main$SampleServer$1@1968e23] to supervisor [com.jonasboner.supervisor.Supervisor@860d49]
</pre>

<strong>10. Send an asyncronous message and wait on a future.</strong>

If this call times out, the error handler we define will be invoked - in this case throw an exception. It is likely that this call will time out since the server is in the middle of recovering from failure and we are on purpose defining a very short time-out to trigger this behavior. 

<pre>
val reply2 = try {
  sampleServer1 !!! (Ping, throw new RuntimeException("Time-out"), 10) 
} catch { case e => println("Expected exception: " + e.toString); Pong } 
</pre>

The output of this call (due to the async nature of actors) is interleaved with the logging for the restart of the servers. As you can see the log below can be found in the middle of the restart output.  
<pre>
12:25:30.093 [main] DEBUG com.jonasboner.supervisor.Helpers$ - Future timed out while waiting for actor: Main$SampleServer$1@1b9240e
Expected exception: java.lang.RuntimeException: Time-out
</pre>

Server should be up again. Try the same call again

<pre>
val reply3 = try {
  sampleServer1 !!! (Ping, throw new RuntimeException("Time-out"), 1000) 
} catch { case e => println("Expected exception: " + e.toString); Pong } 
</pre>

Output: 
<pre>
Received Ping
</pre>

Also check that server number 2 is up and healthy.

<pre>
sampleServer2 ! Ping 
</pre>

Output: 
<pre>
Received Ping
</pre>

<strong>11. Try to hotswap the server implementation</strong>
Here we are passing in a completely new implementation of the server logic (doesn't look that different tough, but it can be any piece of scala pattern matching code) to the server's hotswap method. 

<pre>
sampleServer1.hotswap(Some({
  case Ping => 
    println("Hotswapped Ping")
}))
</pre>

<strong>12. Try the hotswapped server out</strong>

<pre>
sampleServer1 ! Ping
</pre>

Output: 
<pre>
Hotswapped Ping
</pre>

<strong>13. Hotswap again
</strong>

<pre>
sampleServer1.hotswap(Some({
  case Pong => 
    println("Hotswapped again, now doing Pong")
    reply(Ping)
}))
</pre>

<strong>14. Send an asyncronous message that will wait on a future (using a different syntax/method).</strong>
Method returns an <code>Option[T]</code> which can be of two different types; <code>Some(result)</code> or <code>None</code>. If we receive <code>Some(result)</code> then we return the result, but if <code>None</code> is received then we invoke the error handler that we define in the <code>getOrElse</code> method. In this case print out an info message (but you could throw an exception or do whatever you like...) and return a default value (<code>Ping</code>). 

<pre>
val reply4 = (sampleServer1 !!! Pong).getOrElse({
  println("Time out when sending Pong")
  Ping
})
</pre>

Output: 
<pre>
Hotswapped again, now doing Pong
</pre>

Same invocation with pattern matching syntax.

<pre>
val reply5 = sampleServer1 !!! Pong match {
  case Some(result) => result
  case None => println("Time out when sending Pong"); Ping  
}
</pre>

Output: 
<pre>
Hotswapped again, now doing Pong
</pre>

<strong>15. Hotswap back to original implementation.</strong>
This is done by passing in <code>None</code> to the hotswap method.

<pre>
sampleServer1.hotswap(None)
</pre>

<strong>16. Test the final hotswap</strong>

<pre>
sampleServer1 !  Ping
</pre>


Output: 
<pre>
Received Ping 
</pre>

<strong>17. Shut down the supervisor and its server(s)</strong>

<pre>
supervisor ! Stop
</pre>

Output: 
<pre>
12:25:31.093 [Thread-6] INFO  com.jonasboner.supervisor.Supervisor - Stopping server: Main$sampleServer2$2$@1479feb
12:25:31.093 [Thread-6] INFO  com.jonasboner.supervisor.Supervisor - Stopping server: Main$sampleServer1$2$@97a560
12:25:31.093 [Thread-6] INFO  com.jonasboner.supervisor.Supervisor - Stopping supervisor: com.jonasboner.supervisor.Supervisor@860d49
</pre>

You can find this code in the <code>sample.scala</code> file in the root directory of the distribution. Run it by invoking:
<pre>
scala -cp target/supervisor-0.3.jar:[dependency jars: slf4j and logback] sample.scala
</pre>

<strong>Check out</strong>
The SCM system used is Git. 

1. Download and install <a href="http://www.google.com/search?q=git">Git</a>
2. Invoke <code>git clone git@github.com:jboner/scala-supervisor.git</code>.

<strong>Build it</strong>
The build system used is Maven 2.

1. Download and install <a href="http://maven.apache.org/">Maven 2</a>. 
2. Step into the root dir <code>scala-supervisor</code>.
3. Invoke <code>mvn install</code>

This will build the project, run all tests, create a jar and upload it to your local Maven repository ready for use.

<strong>Runtime dependencies</strong>
Automatically downloaded my Maven. 

1. Scala 2.7.1-final
2. SLF4J 1.5.2
3. LogBack Classic 0.9.9

That's all to it. 

Have fun.


