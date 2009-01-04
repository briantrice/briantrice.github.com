--- 
wordpress_id: 155
layout: post
title: Clustering Scala Actors with Terracotta
wordpress_url: http://jonasboner.com/2008/01/25/clustering-scala-actors-with-terracotta/
---
<h2>Introduction</h2>

A month ago I wrote an introductory post about <a href="http://lamp.epfl.ch/~phaller/actors.html">Scala Actors</a>: <a href="http://jonasboner.com/2007/12/19/hotswap-code-using-scala-and-actors/">HotSwap Code using Scala and Actors</a>. For you who don't know what it is I don't want to start by reading the previous post let's briefly recap what Actors are and what you can use them for.

An Actor is an abstraction that implements <a href="http://c2.com/cgi/wiki?MessagePassingConcurrency">Message-Passing Concurrency</a>. Actors have no shared state and are communicating by sending and receiving messages. This is a paradigm that provides a very different and much simple concurrency model than <a href="http://c2.com/cgi/wiki?SharedStateConcurrency">Shared-State Concurrency</a> (the scheme adopted by C, Java, C# etc.) and is avoiding most of the latter one's complexity and problems. This makes it possible to write code that is deterministic and side-effect-free, something that makes it easier to write, test, understand and reason about. Each Actor has a mailbox in which it receives incoming messages and normally uses pattern matching on the messages to decide if a message is interesting if action is needed.

Scala's Actors are based on Doug Lea's <a href="http://gee.cs.oswego.edu/dl/papers/fj.pdf">Fork/Join library</a> and have for example been used very effectively in the excellent <a href="http://liftweb.net"><em>lift</em></a> web framework to among other things to enable <a href="http://en.wikipedia.org/wiki/Comet_(programming)">Comet</a> style (push/streaming ajax) development. Actors allows us to, in a simple and uniformed way, parallelize applications using multiple threads, something that helps us take advantage of all the new dual/quad/... core or SMP machines that we are starting to get now days. But this also poses challenges; how can we make applications build on this "new" programming model highly available and how can we scale them out, if necessary. Would it not be cool if we could not only parallelize our application onto multiple threads but also onto multiple machines? 

Note: <a href="http://erlang.org">Erlang</a>, the most successful implementation of Actors to date, solves the challenges in building fault-tolerant and highly available systems in an elegant way using supervisor hierarchies. Nothing prevents an implement of this strategy in Scala Actors, all the primitives (like link, trap_exit etc.) already exists. 

I have spent some time last weeks looking into if would make sense to utilize <a href="http://terracotta.org">Terracotta</a> to cluster the Scala Actors library to give a platform on which we can both scale Actors out in a distributed fashion and ensure full fault tolerance and high-availability. The result of this exercise have been successful and I'm happy to announce that they work very nice together. I will now spend the remainder of this post on walking you through a simple example in how to cluster a Scala Actor using Terracotta.

<h2>Check out the code from SVN</h2>

But before we do anything, let my point you to the <a href="http://svn.terracotta.org/svn/forge/projects/labs/tim-scala-actors-2.6.1/">SVN repository</a> where you can fetch the Terracotta Integration Module (TIM) that I have implemented for Scala Actors. You can check it out anonymously by invoking:

<pre>
svn co http://svn.terracotta.org/svn/forge/projects/labs/tim-scala-actors-2.6.1/
</pre>

When that is done, step into <code>tim-scala-actors-2.6.1/trunk</code> and invoke <code>mvn install</code> (the last command requires that you have <a href="http://maven.apache.org/">Maven</a> installed). it'll take a while for Maven to download all its dependencies but after a while you will have a shiny new TIM for Scala Actors installed in your local Maven repository (usually in <code>~/.m2</code>). The sample that we will discuss in the next sections is available in the <code>src/samples/scala</code> directory with the sample configuration in the <code>src/samples/resources</code> directory. 

<h2>Write an Actor</h2>

Now, let's write a little <code>Cart</code> actor. This actor response to two different messages <code>AddItem(item)</code> and <code>Tick</code>. The former one adds an item to the <code>Cart</code> while the latter one triggers the <code>Cart</code> to print out its content (I'll let you know why it's called <code>Tick</code> in a second):

<pre>
// Messages
case object Tick
case class AddItem(item: String)
  
class Cart extends Actor {
  private[this] var items: List[String] = Nil 

  def act() {
    loop {
      react {
        case AddItem(item) =>
          items = item :: items
        case Tick =>
          println("Items: " + items)
      }
    }
  }
  
  def ping = ActorPing.scheduleAtFixedRate(this, Tick, 0L, 5000L)
}
</pre>

As you see the state is held by a Scala <code>var</code>, which holds onto a <code>List</code> (immutable). In <code>react</code> we wait for the next incoming message and if it is of type <code>AddItem</code> then we grab the item and append it to the list with all our items, but if the message is of type <code>Tick</code> we simply print the list of items out. Simple enough. But what is this method <code>ping</code> doing? It uses an object called <code>ActorPing</code> to schedule that a <code>Tick</code> should be sent to the <code>Cart</code> every 5 seconds (<code>ActorPing</code> is shamelessly stolen from <a href="http://blog.lostlake.org/">Dave Pollak's</a> <em>lift</em>).

<h2>Configuration</h2>

In order to cluster the <code>Cart</code> actor we have to write two things. First a hack, a simple configuration file in which declare which actors we want to cluster. This is something that later should be put into the regular <code>tc-config.xml</code> file, but for now we have to live with it. So let's create a file with one single line, stating the fully qualified name of the <code>Cart</code> actor; <pre> samples.Cart </pre> We can either name this file <code>clustered-scala-actors.conf</code> and put it in root directory of the application or name it whatever we want and feed it to Terracotta using the <code>-Dclustered.scala.actors.config=[path to the file]</code> JVM property. Second, we have to write the regular Terracotta configuration file (tc-config.xml). Here we essentially have to define three things; the TIM for Scala Actors, locks to guard our mutable state and finally which classes should be included for bytecode instrumentation.

Starting with the TIM for Scala Actors. Here we define the version on the module as well as the URL to our Maven repository (in a short while we will put this jar in the Terracotta Maven repository and then you would not have to point out a local one).

<pre>
&lt;modules&gt;
 &lt;repository&gt;file:///Users/jonas/.m2/repository&lt;/repository&gt;
 &lt;module name="clustered-scala-actors-2.6.1" version="2.6.0.SNAPSHOT"/&gt;
&lt;/modules&gt;
</pre>

Now we have to define the locks, which in Terracotta, also marks the transaction boundaries. The <code>Cart</code> has one mutable field (the <code>var</code> named <code>items</code>) that we need to ensure is guarded correctly and has transactional semantics. For each var Scala generates a setter and a getter. The getter is named the same as the field while the getter has the name suffixed with <code>_$eq</code>. That gives us the following lock definition:

<pre>
&lt;locks&gt;
  &lt;named-lock&gt;
    &lt;lock-name&gt;cart_items_write&lt;/lock-name&gt;
    &lt;lock-level&gt;write&lt;/lock-level&gt;
    &lt;method-expression&gt;* samples.Cart.items_$eq(..)&lt;/method-expression&gt;
  &lt;/named-lock&gt;
  &lt;named-lock&gt;
    &lt;lock-name&gt;cart_items_read&lt;/lock-name&gt;
    &lt;lock-level&gt;read&lt;/lock-level&gt;
    &lt;method-expression&gt;* samples.Cart.items()&lt;/method-expression&gt;
  &lt;/named-lock&gt;
&lt;/locks&gt;
</pre>

We have to define a pair like this for each mutable <strong>user defined</strong> field in a clustered actor (not the standard one's that are common for all Scala Actors, those are automatically defined). 

It important to understand the TIM automatically clusters the Actor's mailbox, which means that no messages will ever be lost - providing full fault-tolerance.

Finally we have to define the classes that we need to include for instrumentation. This naturally includes our application classes, e.g. the classes that are using our <code>Cart</code> actor in one way or the other. Those are picked out by the pattern like: <code>'samples.*'</code>. We also have to include all the Scala runtime and library classes that we are referencing from the message is that we send. In our case that means the classes that are used to implement the <code>List</code> abstraction in Scala. Here is the full listing:

<pre>
&lt;instrumented-classes&gt;
 &lt;include&gt;
   &lt;class-expression&gt;samples.*&lt;/class-expression&gt;
 &lt;/include&gt;
 &lt;include&gt;
   &lt;class-expression&gt;scala.List&lt;/class-expression&gt;
 &lt;/include&gt;
 &lt;include&gt;
   &lt;class-expression&gt;scala.$colon$colon&lt;/class-expression&gt;
 &lt;/include&gt;
 &lt;include&gt;
   &lt;class-expression&gt;scala.Nil$&lt;/class-expression&gt;
 &lt;/include&gt;
&lt;/instrumented-classes&gt;
</pre>

I could have included these (and many more) classes in the TIM, but since Terracotta adds a tiny bit of overhead to each class that it instruments I took the decision that it would be better to let the user explicitly define the classes that needs to be instrumented and leave the other ones alone. Since you can pretty much put any valid Scala data or abstraction in an actor message, it is very likely that you will have to declare some includes, else Terracotta will throw an exception (which is expected) with a message listing the XML snippet that you have to put in the tc-config.xml file. So don't panic if things blow up. 

<h2>Enable Terracotta</h2>

Last but not least, we need to enable Terracotta in the Scala runtime (if you are planning to run the application in a Terracotta enabled application server, then you can skip this section - however I think it might still be useful to be able to try the application out in the Scala REPL). The simplest way of doing that is to do some minor changes to the <code>scala</code> command. First, let's step down into the <code>scala/bin</code> directory and make a copy of the <code>scala</code> command called <code>tc-scala</code>, then scroll down all the way to the bottom. As you can see it is just a wrapper around the regular <code>java</code> command, which makes things pretty easy for us. We start by defining some environmental variables (here showing my local settings):

<pre>
TC_SCALA_ACTORS_CONFIG_FILE=/Users/jonas/src/java/tc-forge/projects/tim-scala-actors-2.6.1/trunk/src/samples/resources/clustered-scala-actors.conf
TC_CONFIG_FILE=/Users/jonas/src/java/tc-forge/projects/tim-scala-actors-2.6.1/trunk/src/samples/resources/tc-config.xml
TC_INSTALL_DIR=/Users/jonas/src/java/tc/code/base/build/dist/terracotta-trunk-rev6814
TC_BOOT_JAR="$TC_INSTALL_DIR"/lib/dso-boot/dso-boot-hotspot_osx_150_13.jar
TC_TIM_SCALA_ACTORS_JAR=/Users/jonas/.m2/repository/org/terracotta/modules/clustered-scala-actors-2.6.1/2.6.0-SNAPSHOT/clustered-scala-actors-2.6.1-2.6.0-SNAPSHOT.jar
</pre>

When these variables have been defined we can replace the existing invocation of <code>java</code> with the following:

<pre>
${JAVACMD:=java} ${JAVA_OPTS:=-Xmx256M -Xms256M} \
 -Xbootclasspath/p:"$TC_BOOT_JAR" \
 -Dtc.install-root="$TC_INSTALL_DIR" \
 -Dtc.config="$TC_CONFIG_FILE" \
 -Dclustered.scala.actors.config="$TC_SCALA_ACTORS_CONFIG_FILE" \
 -Dscala.home="$SCALA_HOME" \
 -Denv.classpath="$CLASSPATH" \
 -Denv.emacs="$EMACS" \
 -cp "$BOOT_CLASSPATH":"$EXTENSION_CLASSPATH":"$TC_TIM_SCALA_ACTORS_JAR" \
 scala.tools.nsc.MainGenericRunner  "$@"
</pre>

<h2>Let's run it</h2>

Enough hacking. Now let's try it out. I think that the best way of learning new things in Scala is to use its REPL, so let's start that up, this time with Terracotta enabled. But before we do that we have to start up the Terracotta server by stepping into the bin directory in the Terracotta installation and invoke:

<pre>
$ ./start-tc-server.sh
</pre>

<strong>Note:</strong> you need to grab Terracotta from SVN trunk to get the bits that work with the Scala TIM. See instructions on how to <a href="http://www.terracotta.org/confluence/display/wiki/Source+Repository">check out the sources</a> and <a href="http://www.terracotta.org/confluence/display/devdocs/Building+Terracotta">how to build it</a>.

Now, we can start up the Terracotta enabled Scala REPL:

<pre>
$ tc-scala
2008-01-25 07:42:11,643 INFO - Terracotta trunk-rev6814, as of 20080124-140101 (Revision 6814 by jonas@homer from trunk)
2008-01-25 07:42:12,136 INFO - Configuration loaded from the file at '/Users/jonas/src/java/tc-forge/projects/tim-scala-actors-2.6.1/trunk/src/samples/resources/tc-config.xml'.
2008-01-25 07:42:12,325 INFO - Log file: '/Users/jonas/terracotta/client-logs/scala/actors/20080125074212303/terracotta-client.log'.
Parsing scala actors config file: /Users/jonas/src/java/tc-forge/projects/tim-scala-actors-2.6.1/trunk/src/samples/resources/clustered-scala-actors.conf
Configuring clustering for Scala Actor: samples.Cart
Welcome to Scala version 2.6.0-final.
Type in expressions to have them evaluated.
Type :help for more information.

scala&gt;
</pre>

Here we can see that it has found and connected to the Terracotta server, found our <code>clustered-scala-actors.conf</code> config file and configured clustering for one Scala Actor; <code>samples.Cart</code>.

Let's have some fun and start up another REPL in another terminal window. In each of these we do the following; import our classes, create a new <code>Cart</code> (Actor) and start up the Actor. 

<pre>
scala&gt; import samples._              
import samples._

scala&gt; val cart = new Cart
cart: samples.Cart = samples.Cart@81af82

scala&gt; cart.start
res0: scala.actors.Actor = samples.Cart@81af82

scala&gt; 
</pre>

Now we have a distributed Actor just waiting to be fed with some messages. We don't want to make it disappointed so let's now add a bunch of bananas and apples to the <code>Cart</code>, and then feed it with a <code>Tick</code> message to make it print out the result:

<pre>
scala&gt; cart ! AddItem("bananas")

scala&gt; cart ! AddItem("apples")

scala&gt; cart ! Tick

scala&gt; Items: List(apples, bananas)

scala&gt; 
</pre>

Ok, so far no news. But comes the moment of truth, let's take the other REPL and fire of a <code>Tick</code>:

<pre>
scala&gt; cart ! Tick

scala&gt; Items: List(apples, bananas)

scala&gt; 
</pre>

Yippee, it works. Now we can invoke the <code>ping</code> method to schedule a <code>Tick</code> (to print out status) every 5 seconds.

<pre>
scala&gt; cart.ping
res2: java.util.concurrent.ScheduledFuture = java.util.concurrent.ScheduledThreadPoolExecutor$ScheduledFutureTask@3a4388

scala&gt; Items: List(apples, bananas)

scala&gt; Items: List(apples, bananas)

scala&gt; cart ! AddItem("football")

scala&gt; Items: List(football, apples, bananas)

...
</pre>
 
<h2>How to define scope of the clustered Actor?</h2>

The Scala Actors TIM currently supports three different scopes; <code>instance</code>, <code>class</code> and <code>custom</code>. The scope is defined by appending a colon ':' and the type of scope after the FQN of the Actor in the <code>clustered-scala-actors.conf</code>. If no scope is defined then the Actor is assumed to have scope <code>instance</code>. For example: 

<pre>
com.biz.Foo:custom
com.biz.Bar:class
com.biz.Baz:instance  
com.biz.Bam
</pre>

The default scope named <code>instance</code> means that the Scala TIM is transparently intercepting the instantiation (f.e. <code>new Cart</code>) of all the Actors that you declare in the <code>clustered-scala-actors.conf</code> file. Each clustered Actor <strong>instance</strong> will have a unique identity across the cluster and each time this specific instance is created (f.e. when a new node joins the cluster) then the clustered instance with this specific identity will be handed out. The TIM distinguishes between actors of the same type but instantiated in different code paths. To take an example, let's create one object <code>ActorFactory</code> with one single method <code>create</code>: 

<pre>
object ActorFactory {
  def create: Actor = new MyActor
}
</pre>

If we now have two classes <code>Foo</code> and <code>Bar</code> as follows:

<pre>
class Foo {
  val actor = ActorFactory.create
}

class Bar {
  val actor = ActorFactory.create
}
</pre>

Then <code>Foo</code> and <code>Bar</code> will have two distinct clustered Actors each with a unique but cluster-wide identity. 

The <code>class</code> scope lets all Actors of a the same type share Actor instance, so each time an Actor of a specific type is created the same clustered one will be handed out. 

Finally we have the <code>custom</code> scope. Which, as it sounds, allows custom user defined scoping. 
  
<h2>How to define custom scoped Actors?</h2>

If you want more control over scope and life-cycle of a specific Actor then you can define it to have <code>custom</code> scope in the <code>clustered-scala-actors.conf</code> file and create a factory in which you bind each Actor to whatever scope you wish. But now you have to create some data structure that is holding on to your Actors in the factory and explicitly define it to be a root in the <code>tc-config.xml</code> file. The factory might look something like this:

<pre>
// Cart factory, allows mapping an instance to any ID
object Cart {
  
  // This instance is the custom Terracotta root
  private[this] val instances: Map[Any, Cart] = new HashMap

  def newInstance(id: Any): Cart = {
    instances.get(id) match {
      case Some(cart) => cart
      case None => 
        val cart = new Cart
        instances += (id -> cart)
        cart
    }
  }
}
</pre>

This means that we have to add some more configuration elements to our Terracotta configuration. First we need to add the root <code>samples.Cart$.instances</code> (<code>Cart$</code> is the name of Scala's compiled <code>Cart</code> companion object, all companion objects compiles to a class with the name of the original class suffixed with <code>$</code>):

<pre>
&lt;roots&gt;
  &lt;root&gt;
    &lt;field-name&gt;samples.Cart$.instances&lt;/field-name&gt;
  &lt;/root&gt;
&lt;/roots&gt;
</pre>

Then we have to add locking for the <code>Cart.newInstance(..)</code> method and finally a whole bunch of new include statements for all the Scala types that are referenced by the <code>scala.collection.mutable.HashMap</code> that we used as root:

<pre>
...  
&lt;named-lock&gt;
  &lt;lock-name&gt;Cart_newInstance&lt;/lock-name&gt;
  &lt;lock-level&gt;write&lt;/lock-level&gt;
  &lt;method-expression&gt;* samples.Cart$.newInstance(..)&lt;/method-expression&gt;
&lt;/named-lock&gt;

...
          
&lt;include&gt;
  &lt;class-expression&gt;scala.collection.mutable.HashMap&lt;/class-expression&gt;
&lt;/include&gt;
&lt;include&gt;
  &lt;class-expression&gt;scala.runtime.BoxedAnyArray&lt;/class-expression&gt;
&lt;/include&gt;
&lt;include&gt;
  &lt;class-expression&gt;scala.runtime.BoxedArray&lt;/class-expression&gt;
&lt;/include&gt;
&lt;include&gt;
  &lt;class-expression&gt;scala.collection.mutable.DefaultEntry&lt;/class-expression&gt;
&lt;/include&gt;
  
...
</pre>

That's pretty much all there's to it. Check out the code, play with it and come back with feedback, bug reports, patches etc. 

Enjoy. 









































