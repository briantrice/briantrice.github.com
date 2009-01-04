--- 
wordpress_id: 27
layout: post
title: "Spring and AspectWerkz: A Happy Marriage v2"
wordpress_url: http://jonasboner.com/?p=27
---
<p>
The <a href="http://aspectwerkz.codehaus.org/index.html">AspectWerkz 2</a> architecture has been designed to be an <i>Extensible Aspect Container</i>, which can deploy and run arbitrary aspects. You can read more about the details in <a href="http://www.theserverside.com/articles/article.tss?l=AspectWerkzP1">this article</a>.
</p>

<p>
In this article I will show you how you can make use of this container to run <a href="http://www.springframework.org/">Spring AOP</a> aspects more performant plus utilize the annotation-driven AOP in AspectWerkz along with its more expressive pointcut pattern language. 
</p>

<p>
In this article I am using Spring as an example but everything covered here applies to all frameworks that implements the <a href="http://aopalliance.sourceforge.net/">AOP Alliance</a> interfaces (e.g. dynaop, JoyAop, JAC etc.).
</p>

<h3>Write a regular Spring advice</h3>
<p>
First we write a regular spring advice that implements authentication:
<pre>
    public class AuthenticationAdvice implements MethodBeforeAdvice {

        public void before(Method m, Object[] args, Object target) throws Throwable {
            // try to authenticate the user
            // if not authenticated throw a SecurityException  
        }
    } 
</pre>
</p>

<h3>Define the advice using Java 5 annotations</h3>
<p>
In this example we will not define this advice using the slightly verbose Spring config file. But make use of Java 5 annotations. In AspectWerkz you have a set of predefined annotations that we can use, f.e. one for each advice type. The advice we have implemented here is a <i>before advice</i> so we will use the <tt>@Before</tt> annotation when defining the advice:
<pre>
    public class AuthenticationAdvice implements MethodBeforeAdvice {

        @Before("authenticationPoints")
        public void before(Method m, Object[] args, Object target) {
            // try to authenticate the user
            // if not authenticated throw a SecurityException  
        }
    } 
</pre>
Here we bind the advice to the pointcut named <tt>"authenticationPoints"</tt>, this pointcut will pick out all the points where we want authentication to take place. However we do not define this pointcut yet. Since we want to make this aspect reusable, then it is better to just compile it, put it in a jar and then at deployment time resolve this definition by defining the pointcut in the external <tt>META-INF/aop.xml</tt> file. 
</p>

<p>
We can of course choose to not define the pointcut in an external XML file but directly in the <tt>Before</tt> annotation like this: 
<pre>
    @Before("call(@RestrictedOperation * *.*(..))")
    public void before(Method m, Object[] args, Object target) {
        ... 
    }
</pre>
if we think that that is beneficial. (Then the <tt>META-INF/aop.xml</tt> only have to define the aspect class name, see below for details). 
</p>

<h3>Define the pointcut in the external aop.xml file</h3>
<p>
Now all we need to do put this advice to work is to write the little <tt>META-INF/aop.xml</tt> file.
In this case there are two things that we need to define there:
<ul>
    <li>
    we need to tell the AspectWerkz container that it should deploy this Spring advice as a regular AspectWerkz aspect 
    </li>
    <li>
    we need to resolve the definition by defining the "authenticationPoints" pointcut
    </li>
</ul>
Example:
<pre>
    &lt;aspectwerkz&gt;
        &lt;system id="spring-extension-sample"&gt;
            &lt;aspect class="my.application.aspects.AuthenticationAdvice"&gt;
                &lt;pointcut name="authenticationPoints" expression="call(@RestrictedOperation * *.*(..))" /&gt;
            &lt;/aspect&gt;
        &lt;/system&gt;
    &lt;/aspectwerkz&gt;
</pre>
Here we defined the pointcut to pick out all method calls to a method that is marked with the annotation <tt>@RestrictedOperation</tt>.    
</p>

<p>
Note that we are using a <i>call</i> pointcut here, which means that this advice will execute on the client side and not the server (something that is not possible with regular spring aop which only supports <i>execution</i> pointcuts). This can be beneficial in many situations, it can f.e. can save us a remove call from the client to the server, or take some load off the server if the client is executing in a separate VM, etc.
</p>

<h3>Start up the application</h3>
<p>
The last thing we need to do is to add two VM options:
<ul>
    <li>
    we need to register the <i>Aspect Model</i> implementation for the Spring extension in the AspectWerkz container. This is done like this:
    <br />  
    <tt>-Daspectwerkz.extension.aspectmodels=org.codehaus.aspectwerkz.transform.spring.SpringAspectModel</tt>
    </li>
    <li>
    we need to register the AspectWerkz weaver agent:  
    <br />  
    <tt>-javaagent:lib/aspectwerkz-jdk5-RC2.jar</tt>
    </li>
</ul>
You also need to put the <tt>aspectwerkz-core-RC2.jar</tt>, <tt>aspectwerkz-RC2.jar</tt>, <tt>aw-ext-spring-0.1.jar</tt> and <tt>aw-ext-aopalliance-0.1.jar</tt> plus the regular AspectWerkz dependency jars on the classpath. (You find the aspectwerkz jars in the aspectwerkz distribution and the aw-ext-*.jar jars you need to build yourself (see Resources for details).
</p>

<p>
The you can start up the application as usual using <tt>java ...</tt>.
</p>

<p>
We have been thinking of providing a way of defining the spring aspect model on the application level (per <tt>META-INF/aop.xml</tt> file) and not only on the VM level (using a VM option). If there is interest in this, please get back to us and we will add support for this.
</p>

<!--p>
This means that we can start up the application like this:
<pre>
    # set AspectWerkz version and libs dependancies
    set VERSION=2.0.RC1
    set DEPS=... // AspectWerkz dependancies - see bin/setEnv for the complete list

    # all AspectWerkz jar, and dependancies
    set AW_PATH=aspectwerkz-core-$VERSION.jar:aspectwerkz-$VERSION.jar:$DEPS

    # -javaagent option
    # adapth the path to aspectwerkz-core-$VERSION.jar as required
    java -javaagent:lib/aspectwerkz-jdk5-$VERSION.jar -cp $AW_PATH:... \
         -Daspectwerkz.extension.aspectmodels=org.codehaus.aspectwerkz.transform.spring.SpringAspectModel \ 
         ... my.application.Main 
</pre>


<h3>What about my Spring bean config file, dependency injection etc?</h3>
<p>
Good news is that you can still use your regular Spring bean config file and let Spring do its job, with dependency injection, bean configurations etc.  
</p>

<p>
AspectWerkz has a pluggable factory mechanism for the aspect instantiation and life-cycle management. We have written a factory for the Spring framework that allows you to use Spring to configure your aspects/advice just as usual. Read more about that <a href="http://blogs.codehaus.org/people/jboner/archives/000826_spring_and_aspectwerkz_a_happy_marriage.html">here</a>.
</p>

<h3>Much better performance</h3>
<p>
Apart from allowing defining your aspects using Java5 annotations and using the semantics of the AspectWerkz pointcut language and weaver, you will also get <b>much</b> better performance (ranging between 1300 to 50 percent). I won't go into detail on that here but you can read more about it in <a href="http://docs.codehaus.org/display/AW/AOP+Benchmark">this article</a>. 
</p>

<h3>Drawbacks</h3>
<p>
Everything has tradoffs and there are of course some drawbacks in using the <i>AspectWerkz Extensible Aspect Container</i> as the runtime environment for your Spring aspects/advice: 
<ul>
    <li>
    You will weave the actual target classes - this is a more intrusive way of doing the weaving, which in some cases perhaps is not beneficial
    </li>
    <li>
    You need a couple of extra VM options when you start up your application.
    </li>
    <li>
    You need one extra XML (very tiny) config file - the <tt>META-INF/aop.xml</tt> file
    </li>
</ul>
</p>

<h3>Resources</h3>
<p>
I have not written any specific sample application for this article but if you want you can look at and run the tests in the AspectWerkz distribution. You can download the distribution <a href="http://aspectwerkz.codehaus.org/releases.html">here</a>. The tests are in <tt>./src/compiler-extensions/spring/src/test</tt> directory and you can run them by invoking <tt>ant test</tt> when standing in the <tt>./src/compiler-extensions/spring</tt> directory. However these tests does not use the Java5 annotation syntax but only the XML definition to define the aspects. But you should be able to modify the tests as you like.
</p>

<p>
The <tt>aspectwerkz*.jar</tt> jars and the dependency jars are in the <tt>./lib</tt> folder in the AspectWerkz distribution, but the <tt>aw-ext-*.jar</tt> jars you need to build yourself. This is done by stepping into the  <tt>./src/compiler-extensions/spring</tt> directory and type <tt>ant dist</tt> then the jar will be put into the <tt>./src/compiler-extensions/spring/lib</tt> directory, use same procedure to build the AOP Alliance extension jar.  
</p>

Enjoy.
