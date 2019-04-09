/*******************************************************************************
 * This file is part of OpenNMS(R).
 *
 * Copyright (C) 2016 The OpenNMS Group, Inc.
 * OpenNMS(R) is Copyright (C) 1999-2016 The OpenNMS Group, Inc.
 *
 * OpenNMS(R) is a registered trademark of The OpenNMS Group, Inc.
 *
 * OpenNMS(R) is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as published
 * by the Free Software Foundation, either version 3 of the License,
 * or (at your option) any later version.
 *
 * OpenNMS(R) is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Affero General Public License for more details.
 *
 * You should have received a copy of the GNU Affero General Public License
 * along with OpenNMS(R).  If not, see:
 *      http://www.gnu.org/licenses/
 *
 * For more information contact:
 *     OpenNMS(R) Licensing <license@opennms.org>
 *     http://www.opennms.org/
 *     http://www.opennms.com/
 *******************************************************************************/

package org.opennms.core.rpc.camel;

import static org.opennms.core.tracing.api.TracerConstants.TAG_LOCATION;
import static org.opennms.core.tracing.api.TracerConstants.TAG_RPC_FAILED;
import static org.opennms.core.tracing.api.TracerConstants.TAG_SYSTEM_ID;
import static org.opennms.core.tracing.api.TracerConstants.TAG_TIMEOUT;

import java.util.Map;
import java.util.concurrent.CompletableFuture;

import org.apache.camel.Endpoint;
import org.apache.camel.EndpointInject;
import org.apache.camel.Exchange;
import org.apache.camel.ExchangeTimedOutException;
import org.apache.camel.ProducerTemplate;
import org.apache.camel.component.direct.DirectConsumerNotAvailableException;
import org.apache.camel.spi.Synchronization;
import org.opennms.core.tracing.util.TracingInfoCarrier;
import org.opennms.core.logging.Logging;
import org.opennms.core.logging.Logging.MDCCloseable;
import org.opennms.core.rpc.api.RemoteExecutionException;
import org.opennms.core.rpc.api.RequestRejectedException;
import org.opennms.core.rpc.api.RequestTimedOutException;
import org.opennms.core.rpc.api.RpcClient;
import org.opennms.core.rpc.api.RpcClientFactory;
import org.opennms.core.rpc.api.RpcModule;
import org.opennms.core.rpc.api.RpcRequest;
import org.opennms.core.rpc.api.RpcResponse;
import org.opennms.core.tracing.api.TracerRegistry;
import org.opennms.core.utils.SystemInfoUtils;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;

import io.opentracing.Span;
import io.opentracing.Tracer;
import io.opentracing.propagation.Format;

public class CamelRpcClientFactory implements RpcClientFactory {

    private static final Logger LOG = LoggerFactory.getLogger(CamelRpcClientFactory.class);

    private String location;

    @EndpointInject(uri = "direct:executeRpc", context = "rpcClient")
    private ProducerTemplate template;

    @EndpointInject(uri = "direct:executeRpc", context = "rpcClient")
    private Endpoint endpoint;

    @Autowired
    private TracerRegistry tracerRegistry;


    @Override
    public <S extends RpcRequest, T extends RpcResponse> RpcClient<S,T> getClient(RpcModule<S,T> module) {
        return new RpcClient<S,T>() {
            @Override
            public CompletableFuture<T> execute(S request) {
                if (request.getLocation() == null || request.getLocation().equals(location)) {
                    // The request is for the current location, invoke it directly
                    return module.execute(request);
                }
                // Save the context map and restore it on callback
                final Map<String, String> clientContextMap = Logging.getCopyOfContextMap();
                final Tracer tracer = tracerRegistry.getTracer();
                Span span = tracer.buildSpan(module.getId()).start();
                span.setTag(TAG_LOCATION, request.getLocation());
                if(request.getSystemId() != null) {
                    span.setTag(TAG_SYSTEM_ID, request.getSystemId());
                }
                TracingInfoCarrier tracingInfoCarrier = new TracingInfoCarrier();
                tracer.inject(span.context(), Format.Builtin.TEXT_MAP, tracingInfoCarrier);
                // Wrap the request in a CamelRpcRequest and forward it to the Camel route
                final CompletableFuture<T> future = new CompletableFuture<>();
                try {
                    template.asyncCallbackSendBody(endpoint, new CamelRpcRequest<>(module, request, tracingInfoCarrier.getTracingInfo()), new Synchronization() {
                        @Override
                        public void onComplete(Exchange exchange) {
                            try (MDCCloseable mdc = Logging.withContextMapCloseable(clientContextMap)) {
                                final T response = module.unmarshalResponse(exchange.getOut().getBody(String.class));
                                if (response.getErrorMessage() != null) {
                                    future.completeExceptionally(new RemoteExecutionException(response.getErrorMessage()));
                                    span.setTag(TAG_RPC_FAILED, "true");
                                    span.log(response.getErrorMessage());
                                } else {
                                    future.complete(response);
                                }
                            } catch (Throwable ex) {
                                LOG.error("Unmarshalling a response in RPC module {} failed.", module, ex);
                                future.completeExceptionally(ex);
                                span.setTag(TAG_RPC_FAILED, "true");
                                span.log(ex.getMessage());
                            }
                            span.finish();
                            // Ensure that future log statements on this thread are routed properly
                            Logging.putPrefix(RpcClientFactory.LOG_PREFIX);
                        }

                        @Override
                        public void onFailure(Exchange exchange) {
                            try (MDCCloseable mdc = Logging.withContextMapCloseable(clientContextMap)) {
                                final ExchangeTimedOutException timeoutException = exchange.getException(ExchangeTimedOutException.class);
                                final DirectConsumerNotAvailableException directConsumerNotAvailableException = exchange.getException(DirectConsumerNotAvailableException.class);
                                if (timeoutException != null) {
                                    // Wrap timeout exceptions within a RequestTimedOutException
                                    future.completeExceptionally(new RequestTimedOutException(exchange.getException()));
                                    span.setTag(TAG_TIMEOUT, "true");
                                } else if (directConsumerNotAvailableException != null) {
                                    // Wrap consumer not available exceptions with a RequestRejectedException
                                    future.completeExceptionally(new RequestRejectedException(exchange.getException()));
                                } else {
                                    future.completeExceptionally(exchange.getException());
                                }
                            }
                            span.setTag(TAG_RPC_FAILED, "true");
                            span.log(exchange.getException().getMessage());
                            span.finish();
                            // Ensure that future log statements on this thread are routed properly
                            Logging.putPrefix(RpcClientFactory.LOG_PREFIX);
                        }
                    });
                } catch (IllegalStateException e) {
                    try (MDCCloseable mdc = Logging.withContextMapCloseable(clientContextMap)) {
                        // Wrap ProducerTemplate exceptions with a RequestRejectedException
                        future.completeExceptionally(new RequestRejectedException(e));
                        span.setTag(TAG_RPC_FAILED, "true");
                        span.log(e.getMessage());
                        span.finish();
                    }
                    // Ensure that future log statements on this thread are routed properly
                    Logging.putPrefix(RpcClientFactory.LOG_PREFIX);
                }
                return future;
            }
        };
    }

    public TracerRegistry getTracerRegistry() {
        return tracerRegistry;
    }

    public void setTracerRegistry(TracerRegistry tracerRegistry) {
        this.tracerRegistry = tracerRegistry;
    }

    public void setLocation(String location) {
        this.location = location;
    }

    public void start() {
        tracerRegistry.init(SystemInfoUtils.getInstanceId());
    }

    public void stop() {
        //pass
    }
}
