--- 
wordpress_id: 29
layout: post
title: "AWProxy: Proxy on steroids"
wordpress_url: http://jonasboner.com/?p=29
---
<h3>Summary</h3>
<p>
Proxies are an important piece in the J2EE puzzle. Since it offers a non-intrusive an more transparent way of weaving in advice/interceptors. However, non of the current proxy implementations utilizes all the rich semantics of AOP (as defined by AspectJ), the expressiveness of a real pointcut pattern language and has the speed of statically compiled code. 
</p>

<p>
<i>AW Proxy</i> is here to try to narrow this gap. It makes use of the rich semantics for AOP in AspectWerkz and is very high-performant due to the use of static compilation (utilizing the AspectWerkz weaver). All wrapped up a very simple and intuitive API.  
</p>

<h3>The need for proxies</h3>
<p>
The two arguments against load-time weaving that we hear the most are:
<ul>
    <li>
    that it is complex - 
    which is an argument that I don't understand, since all you need to do is to add one single VM option when starting up the VM 
    </li>
    <li>
    that the transparency of proxies is hard to beat - 
    which is an argument that I can fully agree on 
    </li>
</ul>
</p>

<p>
Adding the possibility of using <a href="http://aspectwerkz.codehaus.org/index.html">AspectWerkz</a> together with proxies is something that <a href="http://blogs.codehaus.org/people/avasseur/">Alex</a> and I have been talking about for a long time but never implemented due to lack of time. Well, this weekend I took the time and it was actually more simple than I thought. 
</p>

<p>
After a couple of hours coding (taking the <a href="http://cglib.sourceforge.net/">cglib</a> route with its "class proxy", e.g creating a new class on-the-fly that extends the target class and which methods and constructors delegates to the base class' methods, but with the difference that they don't wrap the arguments but pass them on as they are, which gives a lot better performance), I had a working solution. 
</p>

<h3>Introducing AW Proxy</h3>
<p>
The benefit with using the AspectWerkz Proxies compared to the regular load time weaving is that there are no VM options. You simply create your proxy and before it is returned to you it is weaved with the aspects that happens to be available on the classpath at that time.
</p>

<p>
The API is pretty straight forward. All you need is in the 
<pre>
    org.codehaus.aspectwerkz.proxy.Proxy
</pre> 
class which has the following API:
<pre>
    // Returns a new proxy for the class specified
    public static Object newInstance(Class clazz);

    // Returns a new proxy for the class specified, instantiates it by invoking the constructor 
    // with the argument list specified
    public static Object newInstance(Class clazz, Class[] argumentTypes, Object[] argumentValues);

    // Same as above, but with optional parameters for caching and making the proxy advisable 
    public static Object newInstance(Class clazz, boolean useCache, boolean makeAdvisable);

    // Same as above, but with optional parameters for caching and making the proxy advisable 
    public static Object newInstance(Class clazz, Class[] argumentTypes, Object[] argumentValues, 
                                     boolean useCache, boolean makeAdvisable);
</pre>
</p>

<ul>
    <li>
        The <tt>makeAdvisable</tt> argument decides if the proxy instance should be <i>advisable</i>, e.g. be prepared for runtime programmatic deployment. More on this later in this article. 
    </li>
    <li>
        The <tt>useCache</tt> argument decides if the <tt>Proxy</tt> should try to reuse an already compiled proxy class for the specific target class. 

        If you set this flag to <tt>true</tt> then a cached class it is returned (if found) e.g. no new proxy class is compiled. This has both benefits and drawbacks. The benefits being that if there is a new aspect that has been deployed that advises a <b>new</b> join point in the target class then these new join points will not be advised (but already advised join points will be redefined). 

        However if you set this flag to <tt>false</tt> then a new proxy class will be compiled for each invocation of the method, which will make the invocation a bit slower but you will get a completely new proxy class that is advised at <b>all</b> matched join points.  
    </li>
</ul>

<h3>How to use the API?</h3>
<p>
Here is a little example on how to use the <tt>Proxy</tt> API:
<pre>
    // creates and instantiates a new proxy for the class Target
    Target target = (Target) Proxy.newInstance(Target.class, false);
</pre> 
</p>

<p>
That's it! 
</p>

<p>
This <tt>target</tt> instance have now been advised with all the aspects that have been found on the classpath that matches the members of the <tt>Target</tt> class.  
</p>

<h3>Utilizing programmatic runtime deployment</h3>
<p>
As I said before, when you create your proxy it will get automatically weaved with all the matching aspects that are found (on the classpath). This is most of the time what you want and need, but there might be cases when you want to add a specific feature, at runtime, to a specfific instance only. In these cases you need <i>programmatic runtime per instance deployment</i>.
</p>

<p>
One of the new features in the <a href="http://aspectwerkz.codehaus.org/index.html">AspectWerkz 2</a> architecture is that it comes with a full-blown interception framework that allows per instance programmatic deployment with most of  the AOP semantics preserved.
</p>

<p>
In short you will get: 
<br />
Per instance programmatic deployment for <i>before</i>, <i>around</i>, <i>after</i>, <i>after finally</i> and <i>after throwing</i> advice types for <i>call</i>, <i>execution</i>, <i>set</i> and <i>get</i> pointcuts as well as the expressiveness of the AspectWerkz' pointcut pattern language all wrapped up in a very simple and intuitive API.  
</p>

<p>
<pre>
    POJO pojo = new POJO();

    // adds tracing to all methods in the 'pojo' instance
    ((Advisable) pojo).aw_addAdvice(
        "* *.*(..)",
        new BeforeAdvice() {
            public Object invoke(JoinPoint jp) {
                System.out.println("Entering: " + jp.getSignature().toString());
            }
        }
    );
</pre>
</p>

<p>
The advice "interceptors" that are supported are:
<ul>
    <li>
    <tt>AroundAdvice</tt> - works like a regular interceptor and is invoked "around" or "instead-of" the target method invocation or field access/modification.
    </li>
    <li>
    <tt>BeforeAdvice</tt> - is invoked before the actual member invocation
    </li>
    <li>
    <tt>AfterAdvice</tt> - is invoked after the actual member invocation, is invoked both if the method returns normally or with an exception. E.g. can be seen as being invoked in the <tt>finally</tt> block.
    </li>
    <li>
    <tt>AfterReturning</tt> - is invoked after the actual method has returned normally 
    </li>
    <li>
    <tt>AfterThrowingAdvice</tt> - is invoked after the actual method has returned with an exception 
    </li>
</ul>

</p>

<p>
Now we can combine use this feature together with the AW Proxies. All proxies that are created implements the <tt>Advisable</tt> interface which makes it really easy and straightforward to use them together:  
</p>

<h4>Example</h4>
<p>
In this example we create and instantiate a new proxy for the class <tt>Target</tt>, we set it to become <i>advisable</i> (e.g. it will implement the <tt>Advisable</tt> interface transparently), and then we add an <i>after returning</i> advice to all methods that returns an instance of <tt>java.lang.String</tt>.
<pre>

    Advisable target = (Advisable) Proxy.newInstance(Target.class, true, true);
    target.aw_addAdvice(
        "String *.*(..)",
        new AfterReturningAdvice() {
            public void invoke(JoinPoint jp, Object returnValue) {
                // do some stuff     
            }
        }
    );
</pre>
</p>

<h3>Benefits</h3>
<h3>Plain proxies with rich AOP semantics</h3>
<p>
The benefits are, besides a less intrusive and more transparent approach, that you can utilize the rich semantics for AOP (well, not all, see below for limitations) that are supported AspectWerkz. Such as, a rich pointcut expression language, before/after/around advice, deployment modules defined by the <tt>META-INF/aop.xml</tt> file etc. 
</p>

<h3>Very high-performant</h3>
<p>
You will also get the full performance of the AspectWerkz 2 architecture. 
</p>

<p>
If you are interested details of the benchmark we made (and/or run it yourself) then you can read <a href="http://docs.codehaus.org/display/AW/AOP+Benchmark">this paper</a>. 
</p>

<p>
But in short <i>AW Proxy</i> is roughly:
<ul>
    <li>
    25 times faster than <i>Spring AOP</i> for before and after advice  
    </li>
    <li>
    8 times faster than <i>Spring AOP</i> for around advice  
    </li>
    <li>
    16 times faster than <i>dynaop</i> for before and after advice  
    </li>
    <li>
    5 times faster than <i>dynaop</i> for around advice  
    </li>
    <li>
    4 times faster than straight <i>cglib</i> for before and after advice  
    </li>
    <li>
    1.25 times faster than straight <i>cglib</i> for around advice  
    </li>
</ul>
</p>

<h3>Limitations</h3>
<p>
Since it is a proxy approach it only supports <tt>execution</tt> pointcuts and can only advise methods and constructors that is non-private and non-final. E.g not <tt>call</tt>, <tt>set</tt>, <tt>get</tt> or <tt>handler</tt> pointcuts. Advice bound to these pointcut types will simply not affect the class being proxied.
</p>

<h3>Resources</h3>
<p>
This new feature will be available in <i>AspectWerkz 2.0 RC2</i> that will be available soon. Until then you can check out the sources from the <a href="http://aspectwerkz.codehaus.org/cvs.html">CVS</a> and build it yourself (by invoking <tt>ant dist</tt>).
</p>

<p>
There are some samples in the <tt>./src/samples/examples/proxy</tt> dir in the distribution. These can be executed by invoking <tt>ant samples:proxy</tt> from the command line.
</p>

<p>
Enjoy.
</p>
