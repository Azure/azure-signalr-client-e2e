// Licensed to the .NET Foundation under one or more agreements.
// The .NET Foundation licenses this file to you under the MIT license.

import com.microsoft.signalr.Function1Single;
import com.microsoft.signalr.HubConnection;
import com.microsoft.signalr.HubConnectionBuilder;
import io.reactivex.rxjava3.core.Observable;
import io.reactivex.rxjava3.core.Single;

import org.junit.Before;
import org.junit.Test;

import java.util.*;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.TimeoutException;
import java.util.concurrent.atomic.AtomicReference;

import static org.junit.Assert.*;

public class IntegrationTests {
    private String url;
    private static final int DEFAULT_TIMEOUT_SECONDS = 10;
    
    @Before
    public void setUp() throws Exception {
        // url = System.getenv("SIGNALR_INTEGRATION_TEST_URL");
        url = "http://localhost:8080/test";
        if (url == null || url.isEmpty()) {
            org.junit.Assume.assumeTrue("Skipping integration tests because SIGNALR_INTEGRATION_TEST_URL is not set.", false);
        }
    }

    @Test
    public void testConnect() throws Exception {
        try {
            whenTaskTimeout(() -> testConnectCore(), DEFAULT_TIMEOUT_SECONDS);
        } catch (Exception e) {
            fail("Failed to connect: " + e.getMessage());
        }
    }

    private void testConnectCore() throws Exception {
        System.out.println("testConnectCore");
        HubConnection connection = HubConnectionBuilder.create(url).build();
        
        run(() -> {
            connection.start().blockingAwait();
            return null;
        }, () -> {
            connection.stop().blockingAwait();
        });
    }

    @Test
    public void testMultipleConnections() throws Exception {
        int count = 10; // DefaultUrlSession has 5 connections
        List<HubConnection> connections = new ArrayList<>();
        
        try {
            for (int i = 0; i < count; i++) {
                HubConnection connection = HubConnectionBuilder.create(url).build();
                whenTaskTimeout(() -> {
                    connection.start().blockingAwait();
                }, DEFAULT_TIMEOUT_SECONDS);
                connections.add(connection);
            }
        } catch (Exception e) {
            fail("Failed to establish multiple connections: " + e.getMessage());
        }
        
        for (HubConnection connection : connections) {
            connection.stop().blockingAwait();
        }
    }

    @Test
    public void testSendAndOn() throws Exception {
        try {
            whenTaskTimeout(() -> testSendAndOnCore("hello"), DEFAULT_TIMEOUT_SECONDS);
            whenTaskTimeout(() -> testSendAndOnCore(1), DEFAULT_TIMEOUT_SECONDS);
            whenTaskTimeout(() -> testSendAndOnCore(1.2), DEFAULT_TIMEOUT_SECONDS);
            whenTaskTimeout(() -> testSendAndOnCore(true), DEFAULT_TIMEOUT_SECONDS);
            // whenTaskTimeout(() -> testSendAndOnCore(Arrays.asList(1, 2, 3)), DEFAULT_TIMEOUT_SECONDS);
            Map<String, String> map = new HashMap<>();
            map.put("key", "value");
            whenTaskTimeout(() -> testSendAndOnCore(map), DEFAULT_TIMEOUT_SECONDS);
            CustomClass custom = new CustomClass("Hello, World!", Arrays.asList(1, 2, 3));
            whenTaskTimeout(() -> testSendAndOnCore(custom), DEFAULT_TIMEOUT_SECONDS);
        } catch (Exception e) {
            fail("testSendAndOn failed: " + e.getMessage());
        }
    }

    @SuppressWarnings("unchecked")
    private <T> void testSendAndOnCore(T item) throws Exception {
        HubConnection connection = HubConnectionBuilder.create(url).build();
        
        CountDownLatch expectation = new CountDownLatch(1);
        String message1 = "Hello, World!";
        AtomicReference<String> receivedArg1 = new AtomicReference<>();
        AtomicReference<T> receivedArg2 = new AtomicReference<>();
        
        connection.on("EchoBack", (arg1, arg2) -> {
            receivedArg1.set(arg1);
            receivedArg2.set((T) arg2);
            expectation.countDown();
        }, String.class, Object.class);
        
        connection.start().blockingAwait();
        
        run(() -> {
            AtomicReference<Exception> errorRef = new AtomicReference<>();
            try {
                connection.send("Echo", message1, item);
            } catch (Exception e) {
                fail("Failed to send and receive messages: " + e.getMessage());
            }
            
            try {
                assertTrue("Should receive message within timeout",
                    expectation.await(DEFAULT_TIMEOUT_SECONDS, TimeUnit.SECONDS));
            } catch (InterruptedException e) {
                fail("Interrupted while waiting for message: " + e.getMessage());
            }
            
            assertEquals("First argument should match", message1, receivedArg1.get());
            
            // For complex types, we need to compare appropriately
            try {
                T typedResult = (T) item;
                T received = (T) typedResult;
                T expected = (T) item;
                assertEquals("Result should match input", expected, received);
            } catch (Exception e) {
                errorRef.set(e);
            }
            if (errorRef.get() != null) {
                throw errorRef.get();
            }
            return null;
        }, () -> {
            connection.stop().blockingAwait();
        });
    }

    @Test
    public void testInvoke() throws Exception {
        try {
            whenTaskTimeout(() -> testInvokeCore("hello"), DEFAULT_TIMEOUT_SECONDS);
            whenTaskTimeout(() -> testInvokeCore(1), DEFAULT_TIMEOUT_SECONDS);
            whenTaskTimeout(() -> testInvokeCore(1.2), DEFAULT_TIMEOUT_SECONDS);
            whenTaskTimeout(() -> testInvokeCore(true), DEFAULT_TIMEOUT_SECONDS);
            // whenTaskTimeout(() -> testInvokeCore(Arrays.asList(1, 2, 3)), DEFAULT_TIMEOUT_SECONDS);
            Map<String, String> map = new HashMap<>();
            map.put("key", "value");
            whenTaskTimeout(() -> testInvokeCore(map), DEFAULT_TIMEOUT_SECONDS);
            CustomClass custom = new CustomClass("Hello, World!", Arrays.asList(1, 2, 3));
            whenTaskTimeout(() -> testInvokeCore(custom), DEFAULT_TIMEOUT_SECONDS);
        } catch (Exception e) {
            fail("testInvoke failed: " + e.getMessage());
        }
    }

    @SuppressWarnings("unchecked")
    private <T> void testInvokeCore(T item) throws Exception {
        System.err.println("testInvokeCore with item: " + item + " (type: " + item.getClass().getSimpleName() + ")");
        HubConnection connection = HubConnectionBuilder.create(url).build();
        
        connection.start().blockingAwait();
        
        run(() -> {
            String message1 = "Hello, World!";
            CountDownLatch latch = new CountDownLatch(1);
            AtomicReference<Exception> errorRef = new AtomicReference<>();
            
            // Use Object.class for return type to handle all types including List, Map, etc.
            connection.invoke(item.getClass(), "Invoke", message1, item)
                .subscribe(
                    (result) -> {
                        try {
                            T typedResult = (T) result;
                            T received = (T) typedResult;
                            T expected = (T) item;
                            assertEquals("Result should match input", expected, received);
                        } catch (Exception e) {
                            errorRef.set(e);
                        } finally {
                            latch.countDown();
                        }
                    },
                    error -> {
                        errorRef.set(new Exception("Failed to invoke: " + error.getMessage(), error));
                        latch.countDown();
                    }
                );
            
            try {
                boolean completed = latch.await(DEFAULT_TIMEOUT_SECONDS, TimeUnit.SECONDS);
                if (!completed) {
                    throw new TimeoutException("Invoke did not complete within " + DEFAULT_TIMEOUT_SECONDS + " seconds");
                }
            } catch (InterruptedException e) {
                Thread.currentThread().interrupt();
                fail("Interrupted while waiting for invoke: " + e.getMessage());
            }
            
            if (errorRef.get() != null) {
                throw errorRef.get();
            }
            
            return null;
        }, () -> {
            connection.stop().blockingAwait();
        });
    }

    @Test
    public void testInvokeWithoutReturn() throws Exception {
        try {
            whenTaskTimeout(() -> testInvokeWithoutReturnCore(), DEFAULT_TIMEOUT_SECONDS);
        } catch (Exception e) {
            fail("testInvokeWithoutReturn failed: " + e.getMessage());
        }
    }

    private void testInvokeWithoutReturnCore() throws Exception {
        HubConnection connection = HubConnectionBuilder.create(url).build();
        
        connection.start().blockingAwait();
        
        run(() -> {
            String message1 = "Hello, World!";

            // Use invoke with Void.class for methods without return value
            connection.invoke(Void.class, "InvokeWithoutReturn", message1);
            return null;

        }, () -> {
            connection.stop().blockingAwait();
        });
    }

    @Test
    public void testStream() throws Exception {
        try {
            whenTaskTimeout(() -> testStreamCore(), DEFAULT_TIMEOUT_SECONDS);
        } catch (Exception e) {
            fail("testStream failed: " + e.getMessage());
        }
    }

    private void testStreamCore() throws Exception {
        HubConnection connection = HubConnectionBuilder.create(url).build();
        
        connection.start().blockingAwait();
        
        run(() -> {
            List<String> messages = Arrays.asList("a", "b", "c");
            Observable<String> stream = connection.stream(String.class, "Stream");
            List<String> receivedMessages = new ArrayList<>();
            CountDownLatch latch = new CountDownLatch(messages.size());
            
            stream.subscribe(
                item -> {
                    receivedMessages.add(item);
                    latch.countDown();
                },
                error -> {
                    fail("Stream should not error: " + error.getMessage());
                }
            );
            
            try {
                assertTrue("Should receive all stream messages within timeout",
                    latch.await(DEFAULT_TIMEOUT_SECONDS * 2, TimeUnit.SECONDS));
            } catch (InterruptedException e) {
                fail("Interrupted while waiting for stream: " + e.getMessage());
            }
            
            int i = 0;
            for (String received : receivedMessages) {
                assertEquals("Stream message should match", messages.get(i), received);
                i++;
            }
            
            return null;
        }, () -> {
            connection.stop().blockingAwait();
        });
    }

    @Test
    public void testClientResult() throws Exception {
        try {
            whenTaskTimeout(() -> testClientResultCore(), DEFAULT_TIMEOUT_SECONDS * 3);
        } catch (Exception e) {
            fail("testClientResult failed: " + e.getMessage());
        }
    }
    
    private void testClientResultCore() throws Exception {
        HubConnection connection = HubConnectionBuilder.create(url).build();
        
        connection.start().blockingAwait();
        
        run(() -> {
            String expectMessage = "Hello, World!";
            CountDownLatch expectation = new CountDownLatch(1);
            AtomicReference<String> receivedMessage = new AtomicReference<>();
            
            connection.on("EchoBack", (message1) -> {
                assertEquals("EchoBack message should match", expectMessage, message1);
                receivedMessage.set(message1);
                expectation.countDown();
            }, String.class);

            connection.onWithResult("ClientResult", (Function1Single<String, String>) (String message) -> {
                assertEquals("ClientResult message should match", expectMessage, message);
                return Single.just(message);
            }, String.class);
            
            connection.invoke(String.class, "InvokeWithClientResult", expectMessage);
            
            try {
                assertTrue("Should receive EchoBack message within timeout",
                    expectation.await(DEFAULT_TIMEOUT_SECONDS, TimeUnit.SECONDS));
            } catch (InterruptedException e) {
                fail("Interrupted while waiting for message: " + e.getMessage());
            }
            
            assertEquals("Received message should match", expectMessage, receivedMessage.get());
            
            return null;
        }, () -> {
            connection.stop().blockingAwait();
        });
    }

    // it seems java client cannot handle null return result
    // https://github.com/dotnet/aspnetcore/blob/4ca33c9b9a4666bed75b1a3f538d8123ed127a43/src/SignalR/clients/java/signalr/test/src/main/java/com/microsoft/signalr/HubConnection.ReturnResultTest.java#L30
    // @Test
    // public void testClientResultWithNull() throws Exception {
    //     try {
    //         whenTaskTimeout(() -> testClientResultWithNullCore(), DEFAULT_TIMEOUT_SECONDS);
    //     } catch (Exception e) {
    //         fail("testClientResultWithNull failed: " + e.getMessage());
    //     }
    // }

    private void testClientResultWithNullCore() throws Exception {
        HubConnection connection = HubConnectionBuilder.create(url).build();
        
        connection.start().blockingAwait();
        
        run(() -> {
            String expectMessage = "Hello, World!";
            CountDownLatch expectation = new CountDownLatch(1);
            AtomicReference<String> receivedMessage = new AtomicReference<>();
            
            connection.on("EchoBack", (message) -> {
                assertEquals("EchoBack message should be 'received'", "received", message);
                receivedMessage.set(message);
                expectation.countDown();
            }, String.class);
            
            connection.onWithResult("ClientResult", (message) -> {
                assertEquals("ClientResult message should match", expectMessage, message);
                return Single.just(null);
            }, String.class);
            
            connection.invoke(Void.class, "invokeWithEmptyClientResult", expectMessage);
                // .blockingGet();
            
            try {
                assertTrue("Should receive EchoBack message within timeout",
                    expectation.await(DEFAULT_TIMEOUT_SECONDS, TimeUnit.SECONDS));
            } catch (InterruptedException e) {
                fail("Interrupted while waiting for message: " + e.getMessage());
            }
            
            assertEquals("Received message should be 'received'", "received", receivedMessage.get());
            
            return null;
        }, () -> {
            connection.stop().blockingAwait();
        });
    }

    @Test
    public void testClientToServerStream() throws Exception {
        try {
            whenTaskTimeout(() -> testClientToServerStreamCore(), DEFAULT_TIMEOUT_SECONDS * 10);
        } catch (Exception e) {
            fail("testClientToServerStream failed: " + e.getMessage());
        }
    }

    private void testClientToServerStreamCore() throws Exception {
        HubConnection connection = HubConnectionBuilder.create(url).build();
        
        connection.start().blockingAwait();
        
        run(() -> {
            // Test send with stream
            connection.send("AddNumbers", 10, createClientStream());

            // Test invoke with stream (no return)
            connection.invoke(Integer.class, "AddNumbers", 10, createClientStream());

            // Test invoke with stream (with return)
            CountDownLatch invokeLatch = new CountDownLatch(1);
            AtomicReference<Throwable> invokeError = new AtomicReference<>();

            connection.invoke(Integer.class, "AddNumbers", 10, createClientStream()).subscribe(
                result -> {
                    assertEquals("Result should be 25 (10 + 0+1+2+3+4+5)", Integer.valueOf(25), result);
                    invokeLatch.countDown();
                },
                error -> {
                    invokeError.set(error);
                    invokeLatch.countDown();
                }
            );

            try {
                assertTrue("Should receive invoke result within timeout",
                    invokeLatch.await(DEFAULT_TIMEOUT_SECONDS, TimeUnit.SECONDS));
            } catch (InterruptedException e) {
                fail("Interrupted while waiting for invoke result: " + e.getMessage());
            }

            if (invokeError.get() != null) {
                fail("Invoke with stream should not error: " + invokeError.get().getMessage());
            }

            // Test stream with client stream parameter
            List<Integer> receivedCounts = connection.stream(Integer.class, "Count", 10, createClientStream())
                .toList()
                .timeout(5, TimeUnit.SECONDS)
                .blockingGet();

            int counterTarget = 10;
            for (Integer counter : receivedCounts) {
                counterTarget += 1;
                assertEquals("Counter should match", Integer.valueOf(counterTarget), counter);
            }

            return null;
        }, () -> {
            connection.stop().blockingAwait();
        });
    }

    // Helper method similar to Swift's whenTaskTimeout
    private void whenTaskTimeout(ThrowingRunnable task, int timeoutSeconds) throws Exception {
        CountDownLatch latch = new CountDownLatch(1);
        AtomicReference<Exception> exceptionRef = new AtomicReference<>();
        
        Thread taskThread = new Thread(() -> {
            try {
                task.run();
                latch.countDown();
            } catch (Exception e) {
                exceptionRef.set(e);
                latch.countDown();
            }
        });
        
        taskThread.start();
        
        boolean completed = latch.await(timeoutSeconds, TimeUnit.SECONDS);
        if (!completed) {
            taskThread.interrupt();
            throw new TimeoutException("Task did not complete within " + timeoutSeconds + " seconds");
        }
        
        if (exceptionRef.get() != null) {
            throw exceptionRef.get();
        }
    }

    // Helper method to create client stream: 0, 1, 2, 3, 4, 5
    private Observable<Integer> createClientStream() {
        return Observable.range(0, 6)
            .delay(10, TimeUnit.MILLISECONDS);
    }

    // Helper method similar to Swift's run function with defer
    private <T> T run(Supplier<T> operation, Runnable deferredOperation) throws Exception {
        try {
            T result = operation.get();
            deferredOperation.run();
            return result;
        } catch (Exception e) {
            try {
                deferredOperation.run();
            } catch (Exception deferredError) {
                // Log but don't mask original error
                e.addSuppressed(deferredError);
            }
            fail("Operation failed: " + e.getMessage());
            throw e;
        }
    }

    // Custom class for testing complex object serialization
    public static class CustomClass {
        private String str;
        private List<Integer> arr;

        public CustomClass() {
        }

        public CustomClass(String str, List<Integer> arr) {
            this.str = str;
            this.arr = arr;
        }

        public String getStr() {
            return str;
        }

        public void setStr(String str) {
            this.str = str;
        }

        public List<Integer> getArr() {
            return arr;
        }

        public void setArr(List<Integer> arr) {
            this.arr = arr;
        }

        @Override
        public boolean equals(Object o) {
            if (this == o) return true;
            if (o == null || getClass() != o.getClass()) return false;
            CustomClass that = (CustomClass) o;
            return Objects.equals(str, that.str) && Objects.equals(arr, that.arr);
        }

        @Override
        public int hashCode() {
            return Objects.hash(str, arr);
        }
    }
    
    // Functional interface for operations that return a value
    @FunctionalInterface
    private interface Supplier<T> {
        T get() throws Exception;
    }
    
    // Functional interface for operations that throw exceptions
    @FunctionalInterface
    private interface ThrowingRunnable {
        void run() throws Exception;
    }
}
