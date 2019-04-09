/*******************************************************************************
 * This file is part of OpenNMS(R).
 *
 * Copyright (C) 2019 The OpenNMS Group, Inc.
 * OpenNMS(R) is Copyright (C) 1999-2019 The OpenNMS Group, Inc.
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

package org.opennms.core.tracing.util;

import java.util.HashMap;
import java.util.Iterator;
import java.util.Map;

import javax.xml.bind.annotation.XmlAccessType;
import javax.xml.bind.annotation.XmlAccessorType;
import javax.xml.bind.annotation.XmlRootElement;

import org.opennms.core.xml.XmlHandler;

import io.opentracing.propagation.TextMap;

@XmlRootElement(name="tracing-info")
@XmlAccessorType(XmlAccessType.FIELD)
public class TracingInfoCarrier implements TextMap {

    private Map<String, String> tracingInfo = new HashMap<>();

    public TracingInfoCarrier(Map<String, String> tracingInfo) {
        this.tracingInfo = tracingInfo;
    }

    public TracingInfoCarrier() {
    }

    @Override
    public Iterator<Map.Entry<String, String>> iterator() {
        throw new UnsupportedOperationException();
    }

    @Override
    public void put(String key, String value) {
        tracingInfo.put(key, value);
    }

    public Map<String, String> getTracingInfo() {
        return tracingInfo;
    }

    public void setTracingInfo(Map<String, String> tracingInfo) {
        this.tracingInfo = tracingInfo;
    }

    public static String marshalTracingInfo(Map<String, String> tracingInfo) {
        TracingInfoMarshaller tracingInfoMarshaller = new TracingInfoMarshaller();
        TracingInfoCarrier tracingInfoCarrier = new TracingInfoCarrier(tracingInfo);
        return tracingInfoMarshaller.marshalRequest(tracingInfoCarrier);
    }

    public static Map<String, String> unmarshaltracinginfo(String tracingInfo) {
        TracingInfoMarshaller tracingInfoMarshaller = new TracingInfoMarshaller();
        TracingInfoCarrier tracingInfoCarrier = tracingInfoMarshaller.unmarshalRequest(tracingInfo);
        return tracingInfoCarrier.getTracingInfo();
    }

    private static class TracingInfoMarshaller {

        private final ThreadLocal<XmlHandler<TracingInfoCarrier>> xmlHandlerThreadLocal = new ThreadLocal<>();

        public TracingInfoMarshaller() {
            XmlHandler xmlHandler = xmlHandlerThreadLocal.get();
            if (xmlHandler == null) {
                xmlHandler = new XmlHandler<>(TracingInfoCarrier.class);
            }
            xmlHandlerThreadLocal.set(xmlHandler);
        }


        public String marshalRequest(TracingInfoCarrier tracingInfo) {
            return xmlHandlerThreadLocal.get().marshal(tracingInfo);
        }

        public TracingInfoCarrier unmarshalRequest(String tracingInfo) {
            return xmlHandlerThreadLocal.get().unmarshal(tracingInfo);
        }
    }
}
