#include <iostream>
#include <future>
#include <vector>
#include <stdexcept>
#include "signalrclient/hub_connection.h"
#include "signalrclient/hub_connection_builder.h"
#include "signalrclient/signalr_value.h"
#include "signalrclient/hub_protocol.h"
#include "signalrclient/websocket_client.h"
#include "signalrclienttests/test_websocket_client.h"
// #include "signalrclienttests/memory_log_writer.h"

hub_connection create_hub_connection(std::shared_ptr<test_websocket_client> websocket_client = create_test_websocket_client()
    // std::shared_ptr<log_writer> log_writer = std::make_shared<memory_log_writer>(), 
    // trace_level trace_level = trace_level::verbose
)
{
    return hub_connection_builder::create("http://localhost:8080/test")
        // .with_logging(log_writer, trace_level)
        // .with_http_client_factory(create_test_http_client())
        .with_websocket_factory([websocket_client](const signalr_client_config& config)
            {
                websocket_client->set_config(config);
                return websocket_client;
            })
        .build();
}

// 所有执行语句必须在函数内部！
int main()
{
    std::promise<void> start_task;
    
    // 1. 变量定义：在 main 函数内部定义 connection, start_task 等
    signalr::hub_connection connection = create_hub_connection();
    // 2. 注册方法
    connection.on("Echo", [](const std::vector<signalr::value>& m)
    {
        if (!m.empty())
        {
            std::cout << "Received: " << m[0].as_string() << std::endl;
        }
    });

    // 3. 启动连接
    connection.start([&start_task](std::exception_ptr exception) 
    {
        if (exception)
        {
            std::cerr << "Connection failed to start." << std::endl;
        }
        start_task.set_value();
    });

    // 4. 等待启动完成
    try
    {
        start_task.get_future().get();
        std::cout << "Connection established." << std::endl;
    }
    catch (const std::exception& e)
    {
        std::cerr << "Fatal error during connection start: " << e.what() << std::endl;
        return 1;
    }
    

    // 5. 调用服务器方法
    std::promise<void> send_task;
    std::vector<signalr::value> args { signalr::value("Hello world") };
    
    connection.invoke("Echo", args, [&send_task](const signalr::value& value, std::exception_ptr exception) 
    {
        if (exception)
        {
            std::cerr << "Invoke failed." << std::endl;
        }
        send_task.set_value();
    });

    // 6. 等待调用完成
    send_task.get_future().get();


    // 7. 停止连接
    std::promise<void> stop_task;
    connection.stop([&stop_task](std::exception_ptr exception) 
    {
        if (exception)
        {
            std::cerr << "Stop failed." << std::endl;
        }
        stop_task.set_value();
    });

    // 8. 等待停止完成
    stop_task.get_future().get();
    std::cout << "Connection stopped successfully." << std::endl;

    return 0;
}