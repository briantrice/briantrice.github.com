--- 
wordpress_id: 5
layout: post
title: "AOP in practice: Transparent persistence for POJOs"
wordpress_url: http://jonasboner.com/?p=5
---
<p/>
Using the new techniques of AOP and the
<a href="http://aspectwerkz.sourceforge.net/">AspectWerkz</a> framework there is actually
pretty easy to implement transparent persistence for Plain Old Java Objects (POJOs).
<br/>
This example has been implemented using <a href="http://www.coyotegulch.com/jisp/">JISP</a>
as persistence engine and can be checked out along with the
<a href="http://aspectwerkz.sourceforge.net/">AspectWerkz</a>
distribution from the <a href="http://aspectwerkz.sourceforge.net/cvs.html/">CVS</a>.
(Please note that the
<a href="http://aspectwerkz.sourceforge.net/documentation.html">documentation</a>
is not all up to date).

<p/>
First we have to write a <code>PostAdvice</code> similar to this one:

<pre>
public final class DirtyFieldCheckAdvice extends PostAdvice {

    public DirtyFieldCheckAdvice() {
        super();
    }

    // is being executed when a field has become dirty
    public void execute(final JoinPoint joinPoint) {
        FieldJoinPoint jp = (FieldJoinPoint)joinPoint;
        try {
            PersistenceManager.store(jp.getTargetObject());
        } catch (PersistenceManagerException e) {
            throw new WrappedRuntimeException(e);
        }
    }
}
</pre>

So, what did we just do? Well, we created a field advice that extended the
<code>PostAdvice</code> class. The <code>PostAdvice</code> abstract base
class guarantees that the <code>void execute(final JoinPoint joinPoint)</code>
will be executed after that a field has been set (modified).

<p/>
The second step is to tell the
<a href="http://aspectwerkz.sourceforge.net/">AspectWerkz</a>
system which fields we want to monitor. This is specified in the XML definition file:

<pre>
&lt;aspectwerkz>

    &lt;introduction name="persistable"
        interface="aspectwerkz.extension.persistence.Persistable"/&gt;

    &lt;advice name="makePersistent"
        class="aspectwerkz.extension.persistence.DirtyFieldCheckAdvice"
        deploymentModel="perJVM"/&gt;

    &lt;aspect class="domain.*"&gt;
        &lt;introduction-ref name="persistable"/&gt;
        &lt;pointcut type="setField" pattern=".*"&gt;
            &lt;advice-ref name="makePersistent"/&gt;
        &lt;/pointcut&gt;
    &lt;/aspect&gt;


&lt;/aspectwerkz&gt;
</pre>

In this file we first define an
<a href="http://aspectwerkz.sourceforge.net/documentation.html#Introductions">Introduction</a>
for the "marker interface"
<code>aspectwerkz.extension.persistence.Persistable</code> (that will be used by the
persistence engine to select which objects that should be treated as persistent and
which should be treated as transient).

<p/>
Next we define our
<a href="http://aspectwerkz.sourceforge.net/documentation.html#Advices">Advice</a>
by giving it a name, mapping it to the full
class name of the advice and specifying the
<a href="http://aspectwerkz.sourceforge.net/documentation.html#Deployment models">deploymentModel</a>,
(which can be seen as the "scope" for the advice). There are four different
deployment models available:
<ul>
    <li>
        <code>perJVM</code> - one sole instance per Java Virtual
        Machince. Basically the same thing as a singleton class.
    </li>
    <li>
        <code>perClass</code> - one instance per class.
    </li>
    <li>
        <code>perInstance</code> - one instance per class instance.
    </li>
    <li>
        <code>perThread</code> - one instance per thread.
    </li>
</ul>

<p/>
Then we have to specify where to apply the <code>Introduction</code>, i.e.
which objects we want to mark as persistable and which fields we want to monitor
using our <code>Advice</code>.
<p/>
This is done by by defining an
<a href="http://aspectwerkz.sourceforge.net/documentation.html#Aspects">Aspect</a>
with a pattern matching the classes we want to make persistable.
In this <code>Aspect</code> we added a reference to our <code>Introduction</code> (which tells the system that it should apply this <code>Introduction</code> to all classes matching the pattern for the <code>Aspect</code>)
and defined a <code>Pointcut</code> for the fields we are interested in (in this case all fields in all classes matching the pattern).
<p/>
The <a href="http://aspectwerkz.sourceforge.net/documentation.html#Pointcuts">Pointcut</a>
is defined by specifying the type of the <code>Advice</code> (in this
case <code>setField</code> since we want to know when a field has been modified), the <code>pattern</code> for the fields we want the monitor (as a regular expression) and last but not least a reference to to the <code>Advice</code>s we want to apply to this <code>Pointcut</code>.

<p/>
The only thing that is left for getting the whole thing to work is to implement the persistence manager class. This example is based on
<a href="http://www.coyotegulch.com/jisp/">JISP</a> but the implementation is made pluggable so it would be a simple task to add support for RDBMS, JDO or whatever.

<p/>
If you choose to check out the example, you can run it using
<a href="http://maven.apache.org/">Maven</a> by executing
<code>maven aspectwerkz:samples:transparentpersistence</code>.
<p/>
