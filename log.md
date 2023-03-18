结构化日志包括定义良好的格式(通常是JSON)生成日志记录，这为应用程序日志添加了一定程度的组织和一致性，使它们更容易处理。这种日志记录由键-值对组成，它们捕获关于正在记录的事件的相关上下文信息，例如严重级别、时间戳、源代码位置、用户ID或任何其他相关元数据。

本文将深入研究Go中的结构化日志，特别关注最近被接受的旨在将高性能的结构化日志记录级别引入标准库的提案。

我们将从Go现有的日志包及其局限性开始，然后通过涵盖所有最重要的概念来深入研究slog库。我们还将简要讨论Go生态系统中使用最广泛的一些结构化日志库。
![](https://upload-images.jianshu.io/upload_images/21436181-512ab6310a08246c.png?imageMogr2/auto-orient/strip%7CimageView2/2/w/1240)
###Go标准库日志包
在讨论新的结构化日志之前，我们先简要地研究一下标准库日志，它提供了一种将日志消息写入控制台、文件或任何实现io.Writer接口的类型。下面是在Go中编写日志消息的最基本方法:
```go
package main

import "log"

func main() {
    log.Println("Hello from Go application!")
}
```
 Output
```
2023/03/08 11:43:09 Hello from Go application!
```
以上输出包含日志消息和本地时区的时间，该时间戳表示生成条目的时间。Println()方法是预配置的全局Logger可访问的方法之一，它输出到标准错误。其他方法有以下几种:
```go
log.Print()
log.Printf()
log.Fatal()
log.Fatalf()
log.Fatalln()
log.Panic()
log.Panicf()
log.Panicln()
```
上面的Fatal方法和Panic方法的区别在于前者在记录消息后调用os.Exit(1)，而后者调用Panic()。
可以通过log.Default()方法获取默认Logger实例，从而自定义Logger。然后，在返回的Logger上调用相关的方法。下面的例子配置日志写入标准输出而不是标准错误:
```go
func main() {
    defaultLogger := log.Default()
    defaultLogger.SetOutput(os.Stdout)
    log.Println("Hello from Go application!")
}
```
你也可以通过log.New()方法创建一个完全自定义的日志实例，该方法如下所示:
```go
func New(out io.Writer, prefix string, flag int) *Logger
```
第一个参数是Logger生成的日志消息写入的地方，它可以是任何实现io.Writer接口。第二个参数是添加到每个日志消息前的前缀，而第三个指定了一组常量，用于向每个日志消息添加详细信息。
```go
package main

import (
    "log"
    "os"
)

func main() {
    logger := log.New(os.Stdout, "", log.LstdFlags)
    logger.Println("Hello from Go application!")
}
```
上面的Logger实例被配置为打印到标准输出，并且它使用默认的日志实例初始值。因此，输出与之前相同。
output
```go
2023/03/08 11:44:17 Hello from Go application!
```
我们通过向每个日志条目添加应用程序名称、文件名和行号来进一步定制它。这里还将在时间戳中添加微秒，并记录UTC时间而不是本地时间:
```go
logger := log.New(
  os.Stderr,
  "MyApplication: ",
  log.Ldate|log.Ltime|log.Lmicroseconds|log.LUTC|log.Lshortfile,
)
```
output:
```go
MyApplication: 2023/03/08 10:47:12.348478 main.go:14: Hello from Go application!
```
MyApplication:前缀出现在每个日志条目的开头，UTC时间现在包括微秒。输出中还包括文件名和行号，以帮助定位代码库中每条日志的来源。
###标准log包的局限性
尽管Go中的日志包提供了方便的方式来启动日志记录，但由于一些限制，它对于生产环境使用并不理想，例如:
* **缺少日志级别：**日志级别是大多数日志包的主要特性之一，但是Go的日志包中缺少日志级别。所有日志消息都以相同的方式处理，因此很难根据其重要性或严重程度对日志消息进行过滤或分离。
* **不支持结构化日志：**Go中的日志包只输出纯文本消息。它不支持结构化日志，其中日志记录的事件以结构化格式(通常是JSON)表示，随后可以通过编程方式对其进行解析，便于对日志进行监控、警报、审计、创建仪表盘和其他形式的分析。
* **无上下文感知日志：**日志包不支持上下文感知日志，因此很难将上下文信息(例如请求id、用户id和其他变量)自动附加到日志消息中。
* **不支持日志采样：**在高吞吐量应用程序中，日志采样是减少日志量的有用特性。第三方日志库通常提供这种功能，但是Go的内置日志包中没有这种功能。
* **配置项有限：**标准日志包只支持基本的配置项，如设置日志输出的目的地和前缀。高级日志库提供了更多配置机会，例如自定义日志格式、过滤、自动添加上下文数据、启用异步日志记录、错误处理行为等等!

鉴于前面提到的限制，一个新的日志包被称为slog，以填补Go标准库中的现有空白。这个包旨在通过引入带有级别的结构化日志记录来增强Go语言中的日志功能，并为日志创建一个标准接口，其他包可以自由扩展。

###结构化日志包slog
slog包源于Jonathan Amsterdam主导的讨论，该讨论后来促成了描述包的确切设计的建议，一旦它最终确定并在Go版本中实现，预计将放在在log/slog中。在此之前，可以在golang.org/x/exp/slog上找到slog的初步实现。
我们通过介绍它的设计和架构开始讨论。这个包提供了三种你应该熟悉的主要类型:
* **Logger：**使用slog进行结构化日志记录的主要API。它提供了诸如(Info()和Error())之类的级别方法来记录感兴趣的事件。
* **Record：** Logger创建的一个自成体系的日志记录对象。
* **Handler：**该接口一旦实现，就确定日志记录的格式和写入目的地。缺省情况下，这个日志包提供了两个处理程序:TextHandler和JSONHandler。

在本文的以下部分中，我们将更详细地概述每种类型(并提供示例)。值得注意的是，虽然提案已经被接受，但在最终发布之前，一些细节可能会发生变化。要跟随本文中的示例，你可以使用以下命令将slog安装到项目中：
```go
go get golang.org/x/exp/slog@latest
```
###slog日志包使用
这个slog包公开了一个默认Logger，可以通过包上的顶级函数访问。该日志记实例默认为INFO级别，并将纯文本输出记录到标准输出(类似于标准日志包):
```go
package main

import (
    "errors"

    "golang.org/x/exp/slog"
)

func main() {
    slog.Debug("Debug message")
    slog.Info("Info message")
    slog.Warn("Warning message")
    slog.Error("Error message")
}
```
Output:
```
2023/03/15 12:55:56 INFO Info message
2023/03/15 12:55:56 WARN Warning message
2023/03/15 12:55:56 ERROR Error message
```
还可以通过slog.New()方法创建自己的Logger实例。它接受一个非nil的Handler接口，该接口决定日志的格式和写入位置。下面是一个使用内置JSONHandler类型将日志格式化为JSON并将其发送到标准输出的示例:
```go
package main

import (
    "errors"
    "os"

    "golang.org/x/exp/slog"
)

func main() {
    logger := slog.New(slog.NewJSONHandler(os.Stdout))
    logger.Debug("Debug message")
    logger.Info("Info message")
    logger.Warn("Warning message")
    logger.Error("Error message")
}
```
Output:
```go
{"time":"2023-03-15T12:59:22.227408691+01:00","level":"INFO","msg":"Info message"}
{"time":"2023-03-15T12:59:22.227468972+01:00","level":"WARN","msg":"Warning message"}
{"time":"2023-03-15T12:59:22.227472149+01:00","level":"ERROR","msg":"Error message","!BADKEY":"an error"}
```
注意，自定义日志默认是INFO级别的，这就是为什么DEBUG条目被抑制的原因。如果你选择TextHandler代替，每个日志记录将根据logfmt标准格式化:
```go
logger := slog.New(slog.NewTextHandler(os.Stdout))
```
 Output:
```
time=2023-03-15T13:00:11.333+01:00 level=INFO msg="Info message"
time=2023-03-15T13:00:11.333+01:00 level=WARN msg="Warning message"
time=2023-03-15T13:00:11.333+01:00 level=ERROR msg="Error message"
```
###自定义默认logger
如果你想配置默认的日志，最简单的方法是使用slog.SetDefault()方法将默认的记日志实例替换为自定义的:
```go
package main

import (
    "os"

    "golang.org/x/exp/slog"
)

func main() {
    logger := slog.New(slog.NewJSONHandler(os.Stdout))

    slog.SetDefault(logger)

    slog.Info("Info message")
}
```
你现在应该观察到日志方法产生的每个记录都通过JSONHandler路由。
output：
```
{"time":"2023-03-15T13:07:39.105777557+01:00","level":"INFO","msg":"Info message"}
```
注意，SetDefault()方法还会更新日志包使用的默认日志实例，以便使用log. printf()和相关方法的现有应用程序可以切换到结构化日志记录:
```go
logger := slog.New(slog.NewJSONHandler(os.Stdout))

slog.SetDefault(logger)

log.Println("Hello from old logger")
```
Output:
```
{"time":"2023-03-16T15:20:33.783681176+01:00","level":"INFO","msg":"Hello from old logger"}
```
slog.NewLogLogger方法可以将slog.Logger类型实例转为log.Logger实例(例如http.Server.ErrorLog)，如下所示：
```go
handler := slog.NewJSONHandler(os.Stdout)
logger := slog.NewLogLogger(handler, slog.LevelError)

server := http.Server{
  ErrorLog: logger,
}
```
### 为日志添加任意属性
结构化日志的主要优点之一是能够以键/值对的形式向日志添加任意属性。这些属性添加了关于正在记录的日志事件的上下文，这对于故障排除、生成度量或各种其他目的很有用。下面是它如何工作的一个例子:
```go
logger.Info(
  "incoming request",
  "method", "GET",
  "time_taken_ms", 158,
  "path", "/hello/world?q=search",
  "status", 200,
  "user_agent", "Googlebot/2.1 (+http://www.google.com/bot.html)",
)
```
output:
```go
{
  "time":"2023-02-24T11:52:49.554074496+01:00",
  "level":"INFO",
  "msg":"incoming request",
  "method":"GET",
  "time_taken_ms":158,
  "path":"/hello/world?q=search",
  "status":200,
  "user_agent":"Googlebot/2.1 (+http://www.google.com/bot.html)"
}
```
所有级别方法(Info()、Debug()等)都将日志消息作为第一个参数，并使用无限数量的松散类型键/值对。这类似于zap的SugaredLogger API，因为它以额外内存分配为代价优先考虑简便性。如果你不小心，它也会导致问题。最明显的是，键/值对不完整将产生有问题的输出。
```go
logger.Info(
  "incoming request",
  "method", "GET",
  "time_taken_ms",
)
```
由于time_taken_ms键没有对应的值，它将被视为一个带key的值!
Output:
```go
{
  "time": "2023-03-15T13:15:29.956566795+01:00",
  "level": "INFO",
  "msg": "incoming request",
  "method": "GET",
  "!BADKEY": "time_taken_ms"
}
```
这并不好，因为属性不对齐可能会导致创建错误的格式，并且直到需要使用日志时才知道错误。虽然提案建议对方法中可能出现的缺失键/值问题进行详细检查，但在审查过程中还需要格外小心，以确保条目中的每个键/值对都是平衡的，并且类型是正确的。

为了防止这样的错误，最好使用强类型的上下文属性，如下所示:
```go
logger.Info(
  "incoming request",
  slog.String("method", "GET"),
  slog.Int("time_taken_ms", 158),
  slog.String("path", "/hello/world?q=search"),
  slog.Int("status", 200),
  slog.String(
    "user_agent",
    "Googlebot/2.1 (+http://www.google.com/bot.html)",
  ),
)
```
这样更好，因为在编译时将检查每个属性的正确类型。然而，这并不是万无一失的，因为没有什么能阻止你像这样混合强类型和松散类型的键/值对:
```go
logger.Info(
  "incoming request",
  "method", "GET",
  slog.Int("time_taken_ms", 158),
  slog.String("path", "/hello/world?q=search"),
  "status", 200,
  slog.String(
    "user_agent",
    "Googlebot/2.1 (+http://www.google.com/bot.html)",
  ),
)
```
为了保证向日志添加上下文属性时的类型安全，必须像这样使用LogAttrs()方法:
```go
logger.LogAttrs(
  context.Background(),
  slog.LevelInfo,
  "incoming request",
  slog.String("method", "GET"),
  slog.Int("time_taken_ms", 158),
  slog.String("path", "/hello/world?q=search"),
  slog.Int("status", 200),
  slog.String(
    "user_agent",
    "Googlebot/2.1 (+http://www.google.com/bot.html)",
  ),
)
```
这种方法只接受slog.Attr类型的自定义属性，因此不可能出现不平衡的键/值对。然而，它的API更复杂，因为除了日志消息和自定义属性外，还需要传递一个上下文(或nil)和日志级别给方法。
###属性分组
Slog还提供了将多个属性分组到一个名称下的能力。它的显示方式取决于正在使用的处理程序。例如，使用JSONHandler，组被视为一个单独的JSON对象:
```go
logger.LogAttrs(
  context.Background(),
  slog.LevelInfo,
  "image uploaded",
  slog.Int("id", 23123),
  slog.Group("properties",
    slog.Int("width", 4000),
    slog.Int("height", 3000),
    slog.String("format", "jpeg"),
  ),
)
```
Output:
```
{
  "time":"2023-02-24T12:03:12.175582603+01:00",
  "level":"INFO",
  "msg":"image uploaded",
  "id":23123,
  "properties":{
    "width":4000,
    "height":3000,
    "format":"jpeg"
  }
}
```
当你的日志被格式化为键=值对的序列时，组名将被设置为每个键的前缀，如下所示:
output:
```
time=2023-02-24T12:06:20.249+01:00 level=INFO msg="image uploaded" id=23123
  properties.width=4000 properties.height=3000 properties.format=jpeg
```
###创建和使用子日志实例
在程序给定范围内生成的所有记录中包含相同的属性有时是有需求的，这样它们就会出现在所有记录中，而不会在日志点上重复。这就是子日志记录派上用场的地方，因为它们创建了一个继承自父日志实例的新日志上下文，但带有额外的字段。

在slog中创建子日志实例是通过Logger. with()方法完成的，该方法接受强类型和松散类型键/值对的混合，并返回一个新的Logger实例。例如，下面的代码片段，它将程序的进程ID和用于编译它的Go版本添加到program_info属性中的每个日志记录中:
```go
handler := slog.NewJSONHandler(os.Stdout)
buildInfo, _ := debug.ReadBuildInfo()
logger := slog.New(handler).With(
  slog.Group("program_info",
    slog.Int("pid", os.Getpid()),
    slog.String("go_version", buildInfo.GoVersion),

  ),
)
```
有了这个配置，创建的所日志都将包含program_info属性下的指定属性，只要它没有在日志点被覆盖:
```go
logger.Info("image upload successful", slog.String("image_id", "39ud88"))
logger.Warn(
  "storage is 90% full",
  slog.String("available_space", "900.1 MB"),
)
```
Output:
```
{
  "time": "2023-02-26T19:26:46.046793623+01:00",
  "level": "INFO",
  "msg": "image upload successful",
  "program_info": {
    "pid": 229108,
    "go_version": "go1.20"
  },
  "image_id": "39ud88"
}
{
  "time": "2023-02-26T19:26:46.046847902+01:00",
  "level": "WARN",
  "msg": "storage is 90% full",
  "program_info": {
    "pid": 229108,
    "go_version": "go1.20"
  },
  "available_space": "900.1 MB"
}
```
你也可以使用WithGroup()方法创建一个子日志记录器来启动一个组，这样所有添加到日志记录器的属性(包括那些在日志点添加的属性)都将嵌套在组名下面:
```go
handler := slog.NewJSONHandler(os.Stdout)
buildInfo, _ := debug.ReadBuildInfo()
logger := slog.New(handler).WithGroup("program_info")

child := logger.With(
  slog.Int("pid", os.Getpid()),
  slog.String("go_version", buildInfo.GoVersion),
)

child.Info("image upload successful", slog.String("image_id", "39ud88"))
child.Warn(
  "storage is 90% full",
  slog.String("available_space", "900.1 MB"),
)
```
output:
```
{
  "time": "2023-02-26T19:25:35.977851358+01:00",
  "level": "INFO",
  "msg": "image upload successful",
  "group_name": {
    "pid": 227404,
    "go_version": "go1.20",
    "image_id": "39ud88"
  }
}
{
  "time": "2023-02-26T19:25:35.977899791+01:00",
  "level": "WARN",
  "msg": "storage is 90% full",
  "group_name": {
    "pid": 227404,
    "go_version": "go1.20",
    "available_space": "900.1 MB"
  }
}
```
###自定义日志级别
日志包默认提供了四个日志级别，每个级别都对应一个整数值:DEBUG(-4)、INFO(0)、WARN(4)和ERROR(8)。每个级别之间相差4是经过深思熟虑的设计决策，以适应在默认级别之间使用自定义级别的日志记录方案。例如，您可以在INFO和WARN之间创建一个自定义的NOTICE级别，其值为1、2或3。

你可能已经注意到，logger默认配置为INFO级别进行打印日志，这将导致以较低严重级别(例如DEBUG)记录的事件被限制。你可以通过HandlerOptions结构来定制这个行为，如下所示:
 ```go
package main

import (
    "os"

    "golang.org/x/exp/slog"
)

func main() {
    opts := slog.HandlerOptions{
        Level: slog.LevelDebug,
    }

    logger := slog.New(opts.NewJSONHandler(os.Stdout))
    logger.Debug("Debug message")
    logger.Info("Info message")
    logger.Warn("Warning message")
    logger.Error("Error message", errors.New("an error"))
}
```
output:
```
{"time":"2023-03-15T13:43:54.949861653+01:00","level":"DEBUG","msg":"Debug message"}
{"time":"2023-03-15T13:43:54.949924059+01:00","level":"INFO","msg":"Info message"}
{"time":"2023-03-15T13:43:54.949927126+01:00","level":"WARN","msg":"Warning message"}
{"time":"2023-03-15T13:43:54.949929822+01:00","level":"ERROR","msg":"Error message"}
```
注意，这种方法在整个生命周期中修改程序的最小级别。如果你需要动态变化最小日志级别，你必须使用LevelVar类型，如下图所示:
```go
logLevel := &slog.LevelVar{} // INFO

opts := slog.HandlerOptions{
  Level: logLevel,
}

// 可以通过以下方法任意修改日志级别
logLevel.Set(slog.LevelDebug)
```
###创建自定义日志级别
如果你需要的日志级别超出了slog默认提供的级别，你可以通过实现Leveler接口来创建它们，Leveler接口由一个方法定义:
```go
type Leveler interface {
    Level() Level
}
```
通过Level类型很容易实现Leveler接口，如下所示(因为Level本身实现了Leveler):
```go
const (
    LevelTrace  = slog.Level(-8)
    LevelNotice = slog.Level(2)
    LevelFatal  = slog.Level(12)
)
```
一旦像上面那样定义了自定义级别，你可以像下面这样使用它们:
```go
opts := slog.HandlerOptions{
    Level: LevelTrace,
}

logger := slog.New(opts.NewJSONHandler(os.Stdout))

ctx := context.Background()
logger.Log(ctx, LevelTrace, "Trace message")
logger.Log(ctx, LevelNotice, "Notice message")
logger.Log(ctx, LevelFatal, "Fatal level")
```
output:
```
{"time":"2023-02-24T09:26:41.666493901+01:00","level":"DEBUG-4","msg":"Trace level"}
{"time":"2023-02-24T09:26:41.66659754+01:00","level":"INFO+2","msg":"Notice level"}
{"time":"2023-02-24T09:26:41.666602404+01:00","level":"ERROR+4","msg":"Fatal level"}
```
注意每个自定义的level属性是如何根据默认值标记的。这可能不是你想要的，所以你必须使用HandlerOptions类型自定义日志级别名称:
```go
. . .

var LevelNames = map[slog.Leveler]string{
    LevelTrace:      "TRACE",
    LevelNotice:     "NOTICE",
    LevelFatal:      "FATAL",
}

func main() {
    opts := slog.HandlerOptions{
        Level: LevelTrace,
        ReplaceAttr: func(groups []string, a slog.Attr) slog.Attr {
            if a.Key == slog.LevelKey {
                level := a.Value.Any().(slog.Level)
                levelLabel, exists := LevelNames[level]
                if !exists {
                    levelLabel = level.String()
                }

                a.Value = slog.StringValue(levelLabel)
            }

            return a
        },
    }

    . . .
}
```
ReplaceAttr()函数用于自定义程序如何处理日志中的每个键/值对。它可用于自定义键的名称，或以某种方式转换值。在上面的示例中，它用于将自定义日志级别映射到标签。默认值保持不变，但自定义值分别被赋予了TRACE、NOTICE和FATAL标签。
output:
```
{"time":"2023-02-24T09:27:51.747625912+01:00","level":"TRACE","msg":"Trace level"}
{"time":"2023-02-24T09:27:51.747732118+01:00","level":"NOTICE","msg":"Notice level"}
{"time":"2023-02-24T09:27:51.747737319+01:00","level":"FATAL","msg":"Fatal level"}
```
