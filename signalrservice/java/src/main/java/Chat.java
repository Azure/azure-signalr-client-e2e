// Copyright (c) .NET Foundation. All rights reserved.
// Licensed under the Apache License, Version 2.0. See License.txt in the project root for license information.

import com.microsoft.signalr.HubConnection;
import com.microsoft.signalr.HubConnectionBuilder;

public class Chat {
    public static void main(String[] args) throws Exception {
        String url = "http://localhost:8080/test";

        HubConnection hubConnection = HubConnectionBuilder.create(url).build();
        
        hubConnection.start().blockingAwait();

        hubConnection.send("Echo", "hello1", "hello2");

        hubConnection.on("EchoBack", (arg1, arg2) -> {
            System.out.println("EchoBack: " + arg1);
            System.out.println("EchoBack: " + arg2);
        }, String.class, String.class);

        hubConnection.invoke(String.class, "Invoke", "param_invoke_1", "param_invoke_2").subscribe(
            (result) -> {
                System.out.println("Invoke: " + result);
            },
            (error) -> {
                System.out.println("Invoke error: " + error);
            }
        );

        hubConnection.start().blockingAwait();
    }
}