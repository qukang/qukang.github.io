---
title: storm初探
date: 2019-01-16 16:31:28
tags:
---

# storm初探
## 关于流式计算
流式计算是一种区别于传统的离线计算的一种计算方式。  
传统的离线计算通常是将数据采集存放到本地的数据库或者磁盘文件中，然后统一的分时间点的进行批量计算，最后将计算结果输出或者保存到数据库中，这种计算方式往往是离线进行，对于实时性要求很低，在某些场景下不太适合，比如在快速采集当前的实时网站数据时。  
当我们的业务场景对于实时性要求非常高，往往需要采用流失计算。  
  
实时计算的数据流：  
数据采集  ===》  数据存储 ===》 离线计算 ===》 数据存储  
流式计算的数据流：  
数据采集  ===》  流式计算 ===》 数据输出

第一步采集到的数据在流式计算的过程中是不会进行存储的。

## 关于Storm
Storm是一个专门用于流式计算的框架，比较流行的流失计算框架主要有Storm，Flink，Spark Streaming等等，相对于其他的框架而言，Storm属于比较成熟的流式计算框架。
此外，由于所在业务使用的框架就是Storm，所以借助这个机会，好好的学习一下这个框架。  

## Storm 的基本概念

* **Tuple** Storm流中传输用的基本单位，一般用于Spout和Bolt的数据传输
* **Spout** Storm流的数据起始点，相当于一棵树的根节点
* **Bolt** Storm流的数据处理节点，数据流一般是从Spout流向Bolt，或者从Bolt流向Bolt
* **Component** 组成Topology的节点都称为Component，Spout和Bolt都是Component
* **Sstream** 数据在Spout和Bolt的流动组成了一支完整的Stream
* **Topology** Spout和Bolt可以根据数据的流向组成一个完整的有向无环图。这个拓扑结构被称为Topology

## 第一个简单的例子——单词统计


### Storm的开发引入

利用IDEA创建一个新的Maven工程，在pom.xml里面写入storm的maven配置：  
```xml
<dependencies>
    <dependency>
        <groupId>org.apache.storm</groupId>
        <artifactId>storm-core</artifactId>
        <version>1.0.0</version>
        <scope>compile</scope>
    </dependency>
</dependencies>
```
这样就成功的引入了Storm了。这里使用的Storm 1.0.0的版本。


### 单词统计的基本思路

SentenceSpout => SplitSentenceBolt => WordCountBolt

### 基本的Topology建立

```Java
TopologyBuilder builder = new TopologyBuilder();

builder.setSpout("sentenceSpout", new SentenceSpout(), 5);
builder.setBolt("splitSentenceBolt", new SplitSentenceBolt(), 8)
        .shuffleGrouping("sentenceSpout");
builder.setBolt("wordCountBolt", new WordCountBolt(), 12)
        .fieldsGrouping("splitSentenceBolt", new Fields("word"));
```
简单的几个步骤，一个完整的Topology就建立起来了。主要是新建一个TopologyBuilder的对象，利用该对象的setSpout方法添加Spout，也就是数据源。利用该对象的setBolt来添加Bolt，也就是处理数据的节点。
```Java
public SpoutDeclarer setSpout(String id, IRichSpout spout, Number parallelism_hint)
public BoltDeclarer setBolt(String id, IRichBolt bolt, Number parallelism_hint)
```
这两个方法的参数很好理解，第一个参数是ID，在这个Topology中唯一代表了即将添加的Spout或者Bolt。第二个参数是Spout或者Bolt的一个实例，具体的Spout类和Bolt类如何实现我们下面会进一步介绍，第三个参数是paramlleism_hint，表示这个Spout需要的并行任务数量。

可以看到，我们设定了5个数据获取任务（sentenceSpout），然后8个并行的分割任务（splitSentenceBolt），以及12个并行的统计任务（wordCountBolt）。

此外，可以发现在设置完Bolt之后还调用了shuffleGrouping和fieldsGrouping两个方法，这两个方法都是InputDeclarer接口的方法，setBolt和setSpout返回的两个对象都实现了这个接口。
首先，查看一下shuffleGrouping的解释：   
```Java
/**
* Tuples are randomly distributed across the bolt's tasks in a way such that
* each bolt is guaranteed to get an equal number of tuples.
* @param componentId
* @return
*/
public T shuffleGrouping(String componentId);
```
也就是说，shuffleGrouping的作用就是保证从componentId代表的Component的流量能够被随机平均分配到该Bolt的所有任务中。

然后我们来看一下fieldsGrouping的解释：
```Java
/**
 * The stream is partitioned by the fields specified in the grouping.
 * @param componentId
 * @param fields
 * @return
 */
public T fieldsGrouping(String componentId, Fields fields);
```
也就是说，在应用这个方法后，从这个节点开始就要根据Fields切分componentId的流量。


### Spout的建立

接下来，介绍一下如何建立一个简单的Spout。首先，Spout是整个Topology的源头，一般来说，可以是从Redis，Kafka等各种数据源中获取数据，我们这里为了简单，采用随机的生成的模拟数据，

```Java
public class SentenceSpout extends BaseRichSpout {

    private SpoutOutputCollector spoutOutputCollector;
    private Random random;

    public void open(Map conf, TopologyContext context, SpoutOutputCollector collector) {
        spoutOutputCollector = collector;
        random = new Random();
    }

    public void nextTuple() {
        Utils.sleep(100);
        String[] sentences = new String[] {
                sentence("I am Qu Kang"),
                sentence("hello world"),
                sentence("At last we shall have revange"),
                sentence("Storm is so amazing"),
                sentence("I have a poker face"),
        };
        final String sentence = sentences[random.nextInt(sentences.length)];
        System.out.println("Emitting tuple: " + sentence);
        spoutOutputCollector.emit(new Values(sentence));
    }

    protected String sentence(String input){
        return input;
    }

    public void declareOutputFields(OutputFieldsDeclarer declarer) {
        declarer.declare(new Fields("sentence"));
    }
}
```

针对Spout，首先对于上面的代码进行简单的梳理，具体的细节以后再介绍.   

首先是open方法，这个方法在当前Task初始化的时候自动被调用,一般都用来进行参数的初始化。在这里我们将SpoutOutputCollector进行初始化，同时初始化一个随机数Random对象。

最重要的是nextTuple，该方法会发射一个新的元组（Tuple）到Topology,如果没有新的元组发射，则直接返回。在方法内部我们进行随机的参数生成，然后通过spoutOutputCollector.emit(new Values(sentence))发射新的数据Tuple到数据流中，这个Tuple会在接下来的Bolt中接收到并进行进一步的处理。
> 注意任务Spout的nextTuple方法都不要实现成阻塞的，因为storm是在相同的线程中调用spout的方法。   

最后是declareOutputFields方法，这个方法用于声明当前Spout的Tuple发送流。比如说，上面的
`spoutOutputCollector.emit(new Values(sentence));`发送了的Tuple只包含一个sentence元素，那么就可以在declareOutputFields中利用`declarer.declare(new Fields("sentence"));`声明发送的Tuple内容。如果是发送了两部分内容，比如说：`collector.emit(new Values(word, count));`，则可以用`declarer.declare(new Fields("word", "count"));`进行声明.