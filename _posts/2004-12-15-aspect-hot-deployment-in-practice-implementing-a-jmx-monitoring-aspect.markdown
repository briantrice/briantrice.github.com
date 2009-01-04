--- 
wordpress_id: 31
layout: post
title: "Aspect hot deployment in practice: Implementing a JMX monitoring aspect"
wordpress_url: http://jonasboner.com/?p=31
---
<p>
One of the new features in the <a href="http://aspectwerkz.codehaus.org/index.html">AspectWerkz 2</a> architecture is the ability to deploy and undeploy aspects at runtime, e.g. to do "hot" deployment and undeployment. 
</p>

<p>
The implementation is based on <i>HotSwap</i> class redefinition and handles 'change sets' which ensures that the changes to each single join point is atomic. What this means in practice is that if you for example are deploying an aspect which has one before and one after advice, both advising the <b>same</b> join point (method/field etc.) then either <b>both</b> of them will be added <b>or none</b>.
</p>

<p>
The API exposed to the user is very simple and straight forward to use. Everything is handled by the <tt>Deployer</tt> class, which provides the following API for runtime deployment and undeployment of aspects:

<pre>
    DeploymentHandle deploy(Class aspect)
    DeploymentHandle deploy(Class aspect, ClassLoader deployLoader)
    DeploymentHandle deploy(Class aspect, DeploymentScope scope)
    DeploymentHandle deploy(Class aspect, DeploymentScope scope, ClassLoader deployLoader)
    DeploymentHandle deploy(Class aspect, String xmlDef)
    DeploymentHandle deploy(Class aspect, String xmlDef, ClassLoader deployLoader)
    DeploymentHandle deploy(Class aspect, String xmlDef, DeploymentScope scope)
    DeploymentHandle deploy(Class aspect, String xmlDef, DeploymentScope scope, ClassLoader deployLoader)
    void undeploy(Class aspect)
    void undeploy(Class aspect, ClassLoader loader)
    void undeploy(DeploymentHandle deploymentHandle)
</pre>

As you can see you can for example choose to deploy an annotation defined aspect, e.g. a regular Java5 class with AspectWerkz defined annotations (or a regular Java 1.3/1.4 class with AspectWerkz defined JavaDoc annotations, compiled with AspectWerkz's JavaDoc annotation compiler): 

<ul>
    <li>
in the context classloader (just specify the aspect class)
    </li>
    <li>
in an arbitrary class loader (this option is most useful for application server vendors that can garantuee that all the dependecies can be resolved) 
    </li>
    <li>
within a specific <tt>DeploymentScope</tt> (more about this in a minute)  
    </li>
</ul>

You can read more about how you can use the <tt>DeploymentHandle</tt> (that is returned from each of these methods) <a href="http://aspectwerkz.codehaus.org/dynamic_aop.html">here</a>.
</p>

<p>
You also deploy a class without any annotation definition and pass in the definition in XML format. Here you pass in a string containing the <tt>&lt;aspect&gt;...&lt;/aspect&gt;</tt> part of the regular <tt>aop.xml</tt> definition (see the <a href="http://aspectwerkz.codehaus.org/xml_definition.html">online docs</a> for details).
</p>

<h2>Use-case: Implementing a JMX monitoring aspect</h2>
<p>
Now let's take a look at a concrete example on how to hot deploy an aspect that can do some monitoring for us, report that to an JMX MBean and then undeploy it when the monitoring is done. 
</p>

<h3>Writing the aspect</h3>
<p>
So first, here is the (main parts of the) JMX monitoring aspect:
<pre>
    @Aspect
    public class ResponseTimeAspect {

        ... // methods for registering the MBean lazily, member fields etc.

        // the "invocationsToMonitor" pointcut will be defined at deployment time 
        // in the aop.xml file
        @Around("invocationsToMonitor")
        public Object monitor(StaticJoinPoint jp) throws Throwable {
            Signature signature = jp.getSignature();
            long tsStart = System.currentTimeMillis();
            Object result = null;
            try {
                result = jp.proceed();
            } finally {
                // note: this code is using a JMX helper method and  
                // we will have one MBean per jointpoint signature (i.e. method, field, etc.) 
                long tsElapsed = System.currentTimeMillis() - tsStart;
                ObjectInstance mbeanI = registerMBean(signature);
                if (mbeanI != null) {
                    m_mbeanServer.invoke(
                        mbeanI.getObjectName(),
                        "update",
                        new Object[]{new Long(tsElapsed)},
                        new String[]{long.class.getName()}
                    );
                }
            }
            return result;
        }

        public static void enableMonitoring(String pointcut) { ... }

        public static void disableMonitoring() { ... }
    }
</pre>
As you can see, this aspect is defined using Java5 annotations, but if you are using Java 1.3/1.4 you can define the annnotations using JavaDoc (just put the annotation exactly as it is in the JavaDoc for the method/class) and run <tt>AnnotationC</tt> on the class. Then the rest in this article should stay the same. You can read more about the <tt>AnnotationC</tt> compiler <a href="http://aspectwerkz.codehaus.org/attribute_definition.html#Aspect_annotation_compilation">here</a>. 
</p>

<h3>Hot deploy and undeploy the aspect</h3>
<p>
As you can see we have added two static methods to the aspect, these will be used to enable and disable the response time aspect. E.g. deploy it and undeploy it.
</p>

<p>
First we have the <tt>enableMonitoring</tt> method, which enables monitoring in our application, e.g. deploys the monitoring aspect. This method can be invoked at <b>any</b> point in time, all threading issues etc. are handled by the underlying implementation. Here we make use of the XML definition to resolve the annotation definition in the aspects by defining the "abstract pointcut" that we have bound the advice to (the <i>invocationsToMonitor</i> pointcut). 
</p>

<p>
<pre>
    public static void enableMonitoring(String pointcut) {
        String xmlDef = "&lt;aspect&gt;&lt;pointcut name='invocationsToMonitor' expression='" + pointcut + "'/&gt;&lt;/aspect&gt;";
        Deployer.deploy(ResponseTimeAspect.class, xmlDef);
    } 
</pre>
</p>

<p>
Second we have the <tt>disableMonitoring</tt> method which disables monitoring for us, e.g. undeploys the aspect from <b>all</b> the join points where it had been defined (see the concept of <a href="http://aspectwerkz.codehaus.org/dynamic_aop.html"><tt>DeploymentHandle</tt></a>s for a more fine grained undeployment API). 
<pre>
    public static void disableMonitoring() {
        Deployer.undeploy(ResponseTimeAspect.class);
    } 
</pre>
</p>

<h3>Use the aspect to monitor JDBC SQL statements</h3>
<p>
This means that in the user code, all we need to do to enable and disabling this aspect is to invoke these two methods. Here we will monitor the executions of all JDBC statements:
<pre>
    public static void trackResponseTimeOfSqlQueries() {
        ResponseTimeAspect.enableMonitoring("call(* java.sql.Statement+.execute*(..))");

        ... // wait a while to do a recording  

        ResponseTimeAspect.disableMonitoring();
    }
</pre>
</p>

<p>
What this pointcut expression (<tt>call(* java.sql.Statement+.execute*(..))</tt>) actually means is: 
<br />
<ul>
    <li>
Pick out all method calls (<tt>call(..)</tt>)
    </li>
    <li>
to alll methods that has a name that starts with <tt>execute</tt> (<tt>execute*</tt>) 
    </li>
    <li>
that can have any parameter types (<tt>(..)</tt>) or return type (<tt>*</tt>)
    </li>
    <li>
that are in a concrete class that implements the <tt>java.sql.Statement</tt> interface (<tt>java.sql.Statement+</tt>) 
    </li>
</ul>
By basing the pointcut expression on an interface we can be igonrant of how the actual JDBC driver is implemented (concrete subclasses etc.).
</p>

<p>
Note: we could in this specific use-case benefit from retrieving and storing the parameter value to the <tt>execute*(..)</tt> methods, since it is the actual <i>SQL query</i> that we are monitoring the execution time of. This could be done really easy but is out of scope for this article.   
</p>

<p>
So now after doing some monitoring you should be able to easily see the data in any JMX console. For example hook in <i>JConsole</i> which you can read more about in <a href="http://www.onjava.com/pub/a/onjava/2004/09/29/tigerjmx.html">this article</a>.
</p>

<h3>Define a deployment scope</h3>
<p>
Finally, to get this to work in the general case we need to define a <i>deployment scope</i> which defines the set potential join points that we might want to monitor at runtime. 
</p>

<p>
This construct gives you (as a application developer or vendor) control over which join points are exposed to the hot deployment API i.e. helps to prevent usage of the hot deployment facilities in specific areas of the application.   
</p>

<p>
This can be done either in the <tt>META-INF/aop.xml</tt> file or using annotations in the aspect class. In this case we want to make the aspect generic so we will define it in the external XML definition:
<pre>
    &lt;aspectwerkz&gt;
        &lt;system id="monitoring"&gt;
            &lt;deployment-scope name="response_time" expression="call(* sample.deployment..*.*(..))"/&gt;
        &lt;/system&gt;
    &lt;/aspectwerkz&gt;
</pre>
</p>

<p>
Here we have defined a deployment scope that picks out all method calls in our sample application, which means that we can safely deploy our <tt>ResponseTimeAspect</tt> at these points. (We could have added something like <tt>AND within(package..*)</tt> to the expression if we wanted to narrow down the scope.)  
</p>

<p>
In the code above we have an implicit contract that says that we can not define the aspect to be deployed outside a deployment scope. If we do not define a pointcut that is wider than this it is all fine. But we can now use this <i>deployment scope</i> to ensure that we only deploy the aspect at valid points. To do that we need to retrieve a handle to the scope like this (can be done at any point):  
<pre>
    DeploymentScope scope = SystemDefinition.getDefinitionFor(loader, systemId).getDeploymentScope("response_time");
</pre>
</p>

<p>
Now we can use the <tt>DeploymentScope</tt> handle to make a more explicit deployment (e.g. knowing exactly the points where our aspect will be applied): 
<pre>
    Deployer.deploy(ResponseTimeAspect.class, xmlDef, scope);
</pre>
</p>

<h3>Notes on the impact of the deployment scope preparation</h3>
<p>
The preparation made by the <i>deployment scope</i> construct means in practice that we are simply adding a level of indirection by adding a call to a <tt>public static final</tt> method that redirects to the target join point (method, field, constructor). This method will be inlined by all modern JVMs. 
</p>

<p>
When we do undeploy of an aspect, if this aspect is the last one that affects the join point, then the class' bytecode will be reverted to the same state it had before any aspect was deployed.     
</p>

<h3>Resources</h3>

<h4>More info about the JMX ResponseTimeAspect</h4>
<p>
The code for the monitoring aspect is based on the implementation of the <tt>ResponseTimeAspect</tt> in the <a href="http://docs.codehaus.org/display/AWARE">AWare Project</a>. The only difference is that in this example I am defining it using Java5 annotations and I have added the two static methods for doing the deployment and undeployment. You can read more about this aspect <a href="http://docs.codehaus.org/display/AWARE/ResponseTimeAspect">here</a> and the source code for it can be found <a href="https://aspectwerkz-aware.dev.java.net/source/browse/aspectwerkz-aware/components/jmx/main/org/codehaus/aware/jmx/#dirlist">here</a>. 
</p>

<p>
You can also check out the complete AWare project which has some tests for the JMX module. Info about how to check out the sources can be found <a href="https://aspectwerkz-aware.dev.java.net/source/browse/aspectwerkz-aware/">here</a>.
</p>

<h4>More info about the Deployer Module</h4>
<p>
I have not written any specific sample application for this article but if you want you can look at and run the tests for the deployer module in the AspectWerkz distribution. You can download the distribution <a href="http://aspectwerkz.codehaus.org/releases.html">here</a>. The tests are in <tt>./src/jdk15/test</tt> directory and you can run them by invoking <tt>ant test:jdk15</tt> when standing in the AspectWerkz distribution's root dir.
</p>

<p>
The <tt>aspectwerkz*.jar</tt> jars and the dependency jars are in the <tt>./lib</tt> folder in the AspectWerkz distribution.
</p>

Enjoy.
