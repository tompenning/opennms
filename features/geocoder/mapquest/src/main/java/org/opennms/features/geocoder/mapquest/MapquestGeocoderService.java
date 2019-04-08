/*******************************************************************************
 * This file is part of OpenNMS(R).
 *
 * Copyright (C) 2019-2019 The OpenNMS Group, Inc.
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

package org.opennms.features.geocoder.mapquest;

import java.io.IOException;
import java.io.InputStream;
import java.io.UnsupportedEncodingException;
import java.net.URLEncoder;
import java.util.HashMap;
import java.util.Map;
import java.util.Objects;

import org.apache.http.StatusLine;
import org.apache.http.client.methods.CloseableHttpResponse;
import org.apache.http.client.methods.HttpGet;
import org.apache.http.client.methods.HttpUriRequest;
import org.json.JSONArray;
import org.json.JSONObject;
import org.json.JSONTokener;
import org.opennms.core.web.HttpClientWrapper;
import org.opennms.features.geocoder.Coordinates;
import org.opennms.features.geocoder.GeocoderException;
import org.opennms.features.geocoder.GeocoderResult;
import org.opennms.features.geocoder.GeocoderService;

public class MapquestGeocoderService implements GeocoderService {
    private final String urlTemplate;
    private final String apiKey;
    private boolean useSystemProxy;

    public MapquestGeocoderService(String urlTemplate, String apiKey) {
        this.urlTemplate = urlTemplate;
        this.apiKey = apiKey;
    }

    @Override
    public String getId() {
        return "mapquest";
    }

    @Override
    public GeocoderResult resolveAddress(final String address) {
        try (HttpClientWrapper clientWrapper = HttpClientWrapper.create().dontReuseConnections()) {
            if(useSystemProxy) {
                clientWrapper.useSystemProxySettings();
            }
            final String requestUrl = buildURL(urlTemplate, apiKey, address);
            final HttpUriRequest request = new HttpGet(requestUrl);
            try (CloseableHttpResponse response = clientWrapper.execute(request)) {
                final StatusLine statusLine = response.getStatusLine();
                if (statusLine.getStatusCode() != 200) {
                    return new GeocoderResult(
                        new GeocoderException("MapQuest returned a non-OK response code: " + statusLine.getStatusCode() + " " + statusLine.getReasonPhrase())
                    );
                }
                final InputStream responseStream = response.getEntity().getContent();
                final JSONTokener jsonTokener = new JSONTokener(responseStream);
                final JSONObject jsonObject = new JSONObject(jsonTokener);
                if (jsonObject.has("results")
                        && jsonObject.getJSONArray("results").length() > 0
                        && jsonObject.getJSONArray("results").getJSONObject(0).has("locations")) {
                    final JSONArray locationResults = jsonObject.getJSONArray("results").getJSONObject(0).getJSONArray("locations");
                    if (locationResults.length() > 0) {
                        final JSONObject location = (JSONObject) locationResults.get(0);
                        if (location.has("latLng")) {
                            final double lat = location.getJSONObject("latLng").getDouble("lat");
                            final double lng = location.getJSONObject("latLng").getDouble("lng");
                            return new GeocoderResult(new Coordinates(lng, lat));
                        }
                    }
                }
            }
            return new GeocoderResult();
        } catch (IOException e) {
            return new GeocoderResult(e);
        }
    }

    private String buildURL(String urlTemplate, String apiKey, String addressToResolve) throws UnsupportedEncodingException {
        Objects.requireNonNull(urlTemplate);
        Objects.requireNonNull(apiKey);
        Objects.requireNonNull(addressToResolve);
        final String url = urlTemplate.replaceAll("\\{apiKey\\}", apiKey)
                                .replaceAll("\\{query\\}", URLEncoder.encode(addressToResolve, "UTF-8"));
        return url;

    }

    public void setUseSystemProxy(boolean useSystemProxy) {
        this.useSystemProxy = useSystemProxy;
    }

    @Override
    public Map<String, Object> getProperties() {
        final Map<String, Object> properties = new HashMap<>();
        properties.put("url", urlTemplate);
        properties.put("apiKey", apiKey);
        properties.put("useSystemProxy", useSystemProxy);
        return properties;
    }
}
