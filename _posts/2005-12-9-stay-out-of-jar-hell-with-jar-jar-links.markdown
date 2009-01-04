--- 
wordpress_id: 71
layout: post
title: Stay Out of Jar Hell with Jar Jar Links
wordpress_url: http://jonasboner.com/?p=71
---
<p>
<a href="http://tonicsystems.com/products/jarjar/">Jar Jar Links</a> have been part of my Java toolkit ever since we started using it in <a href="http://aspectwerkz.codehaus.org/">AspectWerkz</a> a couple of years ago. It is one of these little gems that deserves more attention, and is your best way out of <em>Jar Hell (TM)</em>. 
</p>

<p>
Basically it is regular <a href="http://ant.apache.org/">Ant's Jar task</a> on steriods, with a lot of small useful features. I will list some of them here.
</p>

<h3>Packaging</h3>
<p>
It works just like the regular Ant Jar task, e.g. you can embed other jars using the <code>zipfileset</code> element, so start using it is a simple matter. Just replace:
</p>
<code lang="xml">
<target name="jar" depends="compile">
    <jar jarfile="dist/example.jar">
        <fileset dir="build/main"/>
    </jar>
</target>
</code>
with:
<code lang="xml">
<target name="jar" depends="compile">
    <taskdef name="jarjar" 
       classname="com.tonicsystems.jarjar.JarJarTask" 
       classpath="lib/jarjar.jar"/>
    <jarjar jarfile="dist/example.jar">
        <fileset dir="build/main"/>
    </jarjar>
</target>
</code>

<p>
But this did not add much value, where it really starts to shine when you start using its feature of prefixing the dependencies.
</p>

<h3>Prefixing of dependencies</h3>

<p>
This is the heart of Jar Jar's value proposition. It allows you to prefix dependencies (the actual package names) that are common and might be used by other libraries. For example in AspectWerkz we prefix the ASM library since it is very common and used in f.e. CGLIB, which can create runtime clashes.

<code lang="xml">
...
<!--    define the jarjar task we use to remap ASM -->
<taskdef name="jarjar" 
  classname="com.tonicsystems.jarjar.JarJarTask" 
  classpath="${basedir}/lib/jarjar-0.3.jar"/>
     <!-- we embed jarjar version of ASM in it -->
     <jarjar destfile="${build.dir}/aw-${version}.jar" 
       manifest="${lib.dir}/manifest.mf">
    <fileset dir="${main.classes}">
        <exclude name="**/aspectwerkz/hook/**/*"/>
    </fileset>
    <zipfileset src="${basedir}/lib/asm-2.1.jar"/>
    <rule pattern="org.objectweb.asm.**" 
       result="org.codehaus.aspectwerkz.@0"/>
</jarjar>
...
</code>

<h3>Remove unwanted dependencies</h3>

</p><p>
Some days ago I <a href="http://jonasboner.com/?p=70">blogged about the problem with Commons Logging</a> and when software depends on it. Well, using Jar Jar, it is actually a simple matter to remove any unwanted dependency altogether. It might not always be the best solution, f.e. you might actually want to have some logging in place, not just use Commons Logging. But is some cases it is very convenient. (Please note that this feature is still experimental.)
</p>

<p>
<a href="http://sixlegs.com/blog">Chris Nokleberg</a> has written more about how to use Jar Jar as a <a href="http://sixlegs.com/blog/java/dependency-killer.html">Dependency Killer</a>.
</p>

<h3>Analysis</h3>

<p>
You can also do some simple, but useful, analysis using Jar Jar. For example finding out which dependencies a library actually has, by either just listing them or use it with graphviz to get a nice graphical view:
</p>

<img src="http://sixlegs.com/misc/depfind.png" alt="Graph of dependencies for a library" />

<p>
It can also find and print out all the strings you are using, good if you want to try to eliminate all your <a href="http://c2.com/cgi/wiki?MagicNumber">magic values</a>.  
</p>

<p>
Read more about these features in the articles <a href="http://sixlegs.com/blog/java/depfind.html">Finding dependencies with JarJar</a> and <a href="http://sixlegs.com/blog/java/string-dumper.html">Dumping strings literals</a>.
</p>

