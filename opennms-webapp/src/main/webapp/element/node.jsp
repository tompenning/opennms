<%--
/*******************************************************************************
 * This file is part of OpenNMS(R).
 *
 * Copyright (C) 2006-2012 The OpenNMS Group, Inc.
 * OpenNMS(R) is Copyright (C) 1999-2012 The OpenNMS Group, Inc.
 *
 * OpenNMS(R) is a registered trademark of The OpenNMS Group, Inc.
 *
 * OpenNMS(R) is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published
 * by the Free Software Foundation, either version 3 of the License,
 * or (at your option) any later version.
 *
 * OpenNMS(R) is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with OpenNMS(R).  If not, see:
 *      http://www.gnu.org/licenses/
 *
 * For more information contact:
 *     OpenNMS(R) Licensing <license@opennms.org>
 *     http://www.opennms.org/
 *     http://www.opennms.com/
 *******************************************************************************/

--%>

<%@page import="org.opennms.web.enlinkd.LldpElementNode"%>
<%@page import="org.opennms.web.enlinkd.OspfElementNode"%>
<%@page import="org.opennms.web.enlinkd.IsisElementNode"%>
<%@page import="org.opennms.web.enlinkd.BridgeElementNode"%>
<%@page import="org.opennms.web.enlinkd.EnLinkdElementFactory"%>
<%@page language="java"
	contentType="text/html"
	session="true"
	import="
        java.util.*,
        java.net.*,
        java.sql.SQLException,
        org.opennms.core.soa.ServiceRegistry,
        org.opennms.core.utils.InetAddressUtils,
        org.opennms.netmgt.config.PollOutagesConfigFactory,
        org.opennms.netmgt.config.poller.outages.Outage,
        org.opennms.netmgt.model.OnmsNode,
        org.opennms.netmgt.poller.PathOutageManagerJdbcImpl,
        org.opennms.web.api.Authentication,
        org.opennms.web.asset.Asset,
        org.opennms.web.asset.AssetModel,
        org.opennms.web.element.*,
        org.opennms.web.navigate.*,
        org.opennms.web.svclayer.ResourceService,
        org.springframework.util.StringUtils,
        org.springframework.web.context.WebApplicationContext,
        org.springframework.web.context.support.WebApplicationContextUtils"
%>
<%@taglib uri="http://java.sun.com/jsp/jstl/core" prefix="c" %>
<%@taglib uri="http://java.sun.com/jsp/jstl/functions" prefix="fn" %>


<%!private int m_telnetServiceId;
    private int m_sshServiceId;
    private int m_httpServiceId;
    private int m_dellServiceId;
    private int m_snmpServiceId;
    private ResourceService m_resourceService;
	private AssetModel m_model = new AssetModel();

	public void init() throws ServletException {
        try {
            m_telnetServiceId = NetworkElementFactory.getInstance(getServletContext()).getServiceIdFromName("Telnet");
        } catch (Throwable e) {
            throw new ServletException("Could not determine the Telnet service ID", e);
        }        

        try {
            m_sshServiceId = NetworkElementFactory.getInstance(getServletContext()).getServiceIdFromName("SSH");
        } catch (Throwable e) {
            throw new ServletException("Could not determine the SSH service ID", e);
        } 

        try {
            m_httpServiceId = NetworkElementFactory.getInstance(getServletContext()).getServiceIdFromName("HTTP");
        } catch (Throwable e) {
            throw new ServletException("Could not determine the HTTP service ID", e);
        }

        try {
            m_dellServiceId = NetworkElementFactory.getInstance(getServletContext()).getServiceIdFromName("Dell-OpenManage");
        } catch (Throwable e) {
            throw new ServletException("Could not determine the Dell-OpenManage service ID", e);
        }

        try {
            m_snmpServiceId = NetworkElementFactory.getInstance(getServletContext()).getServiceIdFromName("SNMP");
        } catch (Throwable e) {
            throw new ServletException("Could not determine the SNMP service ID", e);
        }

		final WebApplicationContext webAppContext = WebApplicationContextUtils.getRequiredWebApplicationContext(getServletContext());
		m_resourceService = (ResourceService) webAppContext.getBean("resourceService", ResourceService.class);
    }

	public static String getStatusStringWithDefault(OnmsNode node_db) {
        String status = ElementUtil.getNodeStatusString(node_db);
        if (status != null) {
            return status;
        } else {
            return "Unknown";
        }
    }
    
    public static String findServiceAddress(int nodeId, int serviceId, ServletContext servletContext) throws SQLException, UnknownHostException {
        Service[] services = NetworkElementFactory.getInstance(servletContext).getServicesOnNode(nodeId, serviceId);
        if (services == null || services.length == 0) {
            return null;
        }
        
        List<InetAddress> ips = new ArrayList<InetAddress>();
        for (Service service : services) {
            ips.add(InetAddressUtils.addr(service.getIpAddress()));
        }

        InetAddress lowest = InetAddressUtils.getLowestInetAddress(ips);

        if (lowest != null) {
            return lowest.getHostAddress();
        } else {
            return null;
        }
    }
    
    public static Collection<Map<String, String>> createLinkForService(int nodeId, int serviceId, String linkText, String linkPrefix, String linkSuffix, ServletContext servletContext) throws SQLException, UnknownHostException {
        String ip = findServiceAddress(nodeId, serviceId, servletContext);
        if (ip == null) {
            return new ArrayList<Map<String,String>>();
        }
        
        Map<String, String> map = new HashMap<String, String>();
        map.put("text", linkText);
        map.put("url", linkPrefix + ip + linkSuffix);
        return Collections.singleton(map);
    }%>

<%
	OnmsNode node_db = ElementUtil.getNodeByParams(request, getServletContext());
    int nodeId = node_db.getId();
    
    Map<String, Object> nodeModel = new TreeMap<String, Object>();
    nodeModel.put("id", Integer.toString(nodeId));
    nodeModel.put("label", node_db.getLabel());
    nodeModel.put("foreignId", node_db.getForeignId());
    nodeModel.put("foreignSource", node_db.getForeignSource());

    List<Map<String, String>> links = new ArrayList<Map<String, String>>();
    links.addAll(createLinkForService(nodeId, m_telnetServiceId, "Telnet", "telnet://", "", getServletContext()));
    links.addAll(createLinkForService(nodeId, m_sshServiceId, "SSH", "ssh://", "", getServletContext()));
    links.addAll(createLinkForService(nodeId, m_httpServiceId, "HTTP", "http://", "/", getServletContext()));
    links.addAll(createLinkForService(nodeId, m_dellServiceId, "OpenManage", "https://", ":1311", getServletContext()));
    nodeModel.put("links", links);

    Asset asset = m_model.getAsset(nodeId);
    nodeModel.put("asset", asset);
    if (asset != null && asset.getBuilding() != null && asset.getBuilding().length() > 0) {
        nodeModel.put("statusSite", asset.getBuilding());
    }
    
    nodeModel.put("lldp",    EnLinkdElementFactory.getInstance(getServletContext()).getLldpElement(nodeId));
    nodeModel.put("ospf",    EnLinkdElementFactory.getInstance(getServletContext()).getOspfElement(nodeId));
    nodeModel.put("isis",    EnLinkdElementFactory.getInstance(getServletContext()).getIsisElement(nodeId));
    nodeModel.put("bridges", EnLinkdElementFactory.getInstance(getServletContext()).getBridgeElements(nodeId));

    nodeModel.put("resources", m_resourceService.findNodeChildResources(node_db));
    nodeModel.put("vlans", NetworkElementFactory.getInstance(getServletContext()).getVlansOnNode(nodeId));
    nodeModel.put("criticalPath", PathOutageManagerJdbcImpl.getInstance().getPrettyCriticalPath(nodeId));
    nodeModel.put("noCriticalPath", PathOutageManagerJdbcImpl.NO_CRITICAL_PATH);
    nodeModel.put("admin", request.isUserInRole(Authentication.ROLE_ADMIN));
    
    // get the child interfaces
    Interface[] intfs = NetworkElementFactory.getInstance(getServletContext()).getActiveInterfacesOnNode(nodeId);
    if (intfs != null) { 
        nodeModel.put("intfs", intfs);
    } else {
        nodeModel.put("intfs", new Interface[0]);
    }

    Service[] snmpServices = NetworkElementFactory.getInstance(getServletContext()).getServicesOnNode(nodeId, m_snmpServiceId);
    if (snmpServices != null && snmpServices.length > 0) {
        for (Interface intf : intfs) {
            if ("P".equals(intf.getIsSnmpPrimary())) {
                nodeModel.put("snmpPrimaryIntf", intf);
                break;
            }
        }
    }
    
    nodeModel.put("status", getStatusStringWithDefault(node_db));
    nodeModel.put("showIpRoute", NetworkElementFactory.getInstance(getServletContext()).isRouteInfoNode(nodeId));
    nodeModel.put("showBridge", NetworkElementFactory.getInstance(getServletContext()).isBridgeNode(nodeId));
    nodeModel.put("showRancid","true".equalsIgnoreCase(Vault.getProperty("opennms.rancidIntegrationEnabled")));
    
    nodeModel.put("node", node_db);
    
    if(!(node_db.getForeignSource() == null) && !(node_db.getForeignId() == null)) {
        nodeModel.put("parentRes", node_db.getForeignSource() + ":" + node_db.getForeignId());
        nodeModel.put("parentResType", "nodeSource");
    } else {
        nodeModel.put("parentRes", Integer.toString(nodeId));
        nodeModel.put("parentResType", "node");
    }

    pageContext.setAttribute("model", nodeModel);

	final WebApplicationContext webAppContext = WebApplicationContextUtils.getRequiredWebApplicationContext(getServletContext());
	final ServiceRegistry registry = webAppContext.getBean(ServiceRegistry.class);

	final List<String> renderedLinks = new ArrayList<String>();
	final Collection<ConditionalPageNavEntry> navLinks = registry.findProviders(ConditionalPageNavEntry.class, "(Page=node)");
	for (final ConditionalPageNavEntry link : navLinks) {
	    final DisplayStatus displayStatus = link.evaluate(request, node_db);
	    if (displayStatus == null) continue;
	    if (displayStatus == DisplayStatus.DISPLAY_NO_LINK) {
	        renderedLinks.add(link.getName());
	    } else if (displayStatus == DisplayStatus.DISPLAY_LINK) {
	        renderedLinks.add("<a href=\"" + link.getUrl().replace("%nodeid%", ""+nodeId) + "\">" + link.getName() + "</a>");
	    }
	}
	
	pageContext.setAttribute("navEntries", renderedLinks);

    final List<String> schedOutages = new ArrayList<String>();
    PollOutagesConfigFactory f = PollOutagesConfigFactory.getInstance();
    for (final Outage outage : f.getOutages()) {
        if (f.isCurTimeInOutage(outage)) {
            boolean inOutage = f.isNodeIdInOutage(nodeId, outage);
            if (!inOutage) {
                for (final Interface i : intfs) {
                    if (f.isInterfaceInOutage(i.getIpAddress(), outage)) {
                        inOutage = true;
                        break;
                    }
                }
            }
            if (inOutage) {
                final String name = outage.getName();
                final String link = "<a href=\"admin/sched-outages/editoutage.jsp?name=" + name + "\">" + name + "</a>";
                schedOutages.add(request.isUserInRole(Authentication.ROLE_ADMIN) ? link : name);
            }
        }
    }

	pageContext.setAttribute("schedOutages", schedOutages.isEmpty() ? null : StringUtils.collectionToDelimitedString(schedOutages, ", "));
%>

<%@page import="org.opennms.core.resource.Vault"%>
<jsp:include page="/includes/header.jsp" flush="false" >
  <jsp:param name="title" value="Node" />
  <jsp:param name="headTitle" value="${model.label}" />
  <jsp:param name="headTitle" value="ID ${model.id}" />
  <jsp:param name="headTitle" value="Node" />
  <jsp:param name="breadcrumb" value="<a href='element/index.jsp'>Search</a>" />
  <jsp:param name="breadcrumb" value="Node" />
  <jsp:param name="enableExtJS" value="false"/>
</jsp:include>

<script type="text/javascript">
function confirmAssetEdit() {
  var confirmText = "You are about to edit asset fields for a node that was provisioned " +
    "through a requisition. Any edits made here will be rolled back the next " +
    "time the requisition \"${model.node.foreignSource}\" is " +
    "synchronized (typically every 24 hours) or the node manually rescanned.\n\n" +
    "To learn the best way to make permanent asset changes, talk to your " +
    "OpenNMS administrator.";
<c:if test="${model.foreignSource != null}">
<% if (!request.isUserInRole(Authentication.ROLE_READONLY)) { %>
    return confirm(confirmText);
<% } else { %>
    return true;
<% } %>
</c:if>
<c:if test="${model.foreignSource == null}">
  return true;
</c:if>
}
</script>

<div class="onms">
<h2>Node: ${model.label} (ID: ${model.id})</h2>
<c:if test="${model.foreignSource != null}">
<h2><em>Created via provisioning requisition <strong>${model.foreignSource} (foreignId: ${model.foreignId})</strong></em></h2>
</c:if>
<c:if test="${model.foreignSource == null}">
<h2><em>Not a member of any provisioning requisition</em></h2>
</c:if>
<div id="linkbar">
  <ul class="o-menu">
    <c:url var="eventLink" value="event/list">
      <c:param name="filter" value="node=${model.id}"/>
    </c:url>
    <li class="o-menuitem">
      <a href="<c:out value="${eventLink}"/>">View Events</a>
    </li>

    <c:url var="alarmLink" value="alarm/list.htm">
      <c:param name="filter" value="node=${model.id}"/>
    </c:url>
    <li class="o-menuitem">
      <a href="<c:out value="${alarmLink}"/>">View Alarms</a>
    </li>
    
    <c:url var="outageLink" value="outage/list.htm">
      <c:param name="filter" value="node=${model.id}"/>
    </c:url>
    <li class="o-menuitem">
      <a href="<c:out value="${outageLink}"/>">View Outages</a>
    </li>
    
    <c:url var="assetLink" value="asset/modify.jsp">
      <c:param name="node" value="${model.id}"/>
    </c:url>
    <li class="o-menuitem">
      <a href="<c:out value="${assetLink}"/>" onclick="return confirmAssetEdit()">Asset Info</a>
    </li>

    <c:if test="${! empty model.statusSite}">
      <c:url var="siteLink" value="siteStatusView.htm">
        <c:param name="statusSite" value="${model.statusSite}"/>
      </c:url>
      <li class="o-menuitem">
        <a href="<c:out value="${siteLink}"/>">Site Status</a>
      </li>
    </c:if>

    <c:forEach items="${model.links}" var="link">
      <li class="o-menuitem">
        <a href="<c:out value="${link.url}"/>">${link.text}</a>
      </li>
    </c:forEach>
    
    <c:if test="${! empty model.resources}">
      <c:url var="resourceGraphsUrl" value="graph/chooseresource.htm">
        <c:param name="parentResourceType" value="${model.parentResType}"/>
        <c:param name="parentResource" value="${model.parentRes}"/>
        <c:param name="reports" value="all"/>
      </c:url>
      <li class="o-menuitem">
        <a href="<c:out value="${resourceGraphsUrl}"/>">Resource Graphs</a>
      </li>
    </c:if>
    
    <c:if test="${model.admin}">
      <c:url var="rescanLink" value="element/rescan.jsp">
        <c:param name="node" value="${model.id}"/>
      </c:url>
      <li class="o-menuitem">
        <a href="<c:out value="${rescanLink}"/>">Rescan</a>
      </li>
      
      <c:url var="adminLink" value="admin/nodemanagement/index.jsp">
        <c:param name="node" value="${model.id}"/>
      </c:url>
      <li class="o-menuitem">
        <a href="<c:out value="${adminLink}"/>">Admin</a>
      </li>

      <c:if test="${! empty model.snmpPrimaryIntf}">
        <c:url var="updateSnmpLink" value="admin/updateSnmp.jsp">
          <c:param name="node" value="${model.id}"/>
          <c:param name="ipaddr" value="${model.snmpPrimaryIntf.ipAddress}"/>
        </c:url>
        <li class="o-menuitem">
          <a href="<c:out value="${updateSnmpLink}"/>">Update SNMP</a>
        </li>
      </c:if>
      
      <c:url var="createOutage" value="admin/sched-outages/editoutage.jsp">
	<c:param name="newName" value="${model.label}"/>
	<c:param name="addNew" value="true"/>
	<c:param name="nodeID" value="${model.id}"/>
      </c:url>
      <li class="o-menuitem">
        <a href="<c:out value="${createOutage}"/>">Schedule Outage</a>
      </li>
    </c:if>
    
    <c:forEach items="${navEntries}" var="entry">
      <li class="o-menuitem">
      	<c:out value="${entry}" escapeXml="false" />
      </li>
    </c:forEach>
  </ul>
</div>
</div>

<c:if test="${! empty schedOutages}">
  <table class="o-box">
    <tr class="CellStatus">
      <td align="left" class="Critical">
        <b>This node is currently affected by the following scheduled outages: </b> ${schedOutages}
      </td>
    </tr>
  </table>
</c:if>

<% String showNodeStatusBar = System.getProperty("opennms.nodeStatusBar.show", "false");
   if (Boolean.parseBoolean(showNodeStatusBar)) { %>
<jsp:include page="/includes/nodeStatus-box.jsp?nodeId=${model.id}" flush="false" />
<% } %>

<div class="TwoColLeft">
  
  

  <!-- Asset box, if info available --> 
  <c:if test="${! empty model.asset && (! empty model.asset.description || ! empty model.asset.comments)}">
    <h3 class="o-box">Asset Information</h3>
    <table class="o-box">
      <tr>
        <th>Description</th>
        <td>${model.asset.description}</td>
      </tr>
      
      <tr>
        <th>Comments</th>
        <td>${model.asset.comments}</td>
      </tr>
    </table>
  </c:if>

  <!-- SNMP box, if info available -->
  <c:if test="${! empty model.node.sysObjectId}">
    <h3 class="o-box">SNMP Attributes</h3>
    <table class="o-box">
      <tr>
        <th>Name</th>
        <td>${model.node.sysName}</td>
      </tr>
      <tr>
        <th>sysObjectID</th>
        <td>${model.node.sysObjectId}</td>
      </tr>
      <tr>
        <th>Location</th>
        <td>${model.node.sysLocation}</td>
      </tr>
      <tr>
        <th>Contact</th>
        <td>${model.node.sysContact}</td>
      </tr>
      <tr>
        <th valign="top">Description</th>
        <td valign="top">${model.node.sysDescription}</td>
      </tr>
    </table>
  </c:if>

  <!-- Lldp box, if info available --> 
  <c:if test="${! empty model.lldp }">
    <h3 class="o-box">Lldp Information</h3>
    <table class="o-box">
      <tr>
        <th>chassis id</th>
        <td>${model.lldp.lldpChassisIdString}</td>
      </tr>
      <tr>
        <th>sysname</th>
        <td>${model.lldp.lldpSysName}</td>
      </tr>
      <tr>
        <th>create time</th>
        <td>${model.lldp.lldpCreateTime}</td>
      </tr>
      <tr>
        <th>last poll time</th>
        <td>${model.lldp.lldpLastPollTime}</td>
      </tr>
    </table>
  </c:if>

  <!-- Bridge box if available -->
  <c:if test="${! empty model.bridges}">
    <c:forEach items="${model.bridges}" var="bridge">
    <h3 class="o-box">Bridge Information
  		<c:if test="${! empty bridge.vlan}">
  		 vlanid ${bridge.vlan}
  		</c:if>
  		<c:if test="${! empty bridge.vlanname}">
  		  (${bridge.vlan})
  		</c:if>
    </h3>
    <table class="o-box">
      <tr>
        <th>base bridge address</th>
        <td>${bridge.baseBridgeAddress}</td>
      </tr>
      <tr>
        <th>base number of ports</th>
        <td>${bridge.baseNumPorts}</td>
      </tr>
      <tr>
        <th>base type</th>
        <td>${bridge.baseType}</td>
      </tr>
 	<c:if test="${! empty bridge.stpProtocolSpecification}">
      <tr>
        <th>stp protocol specification</th>
        <td>${bridge.stpProtocolSpecification}</td>
      </tr>
  	</c:if>
 	<c:if test="${! empty bridge.stpPriority}">
      <tr>
        <th>stp priority</th>
        <td>${bridge.stpPriority}</td>
      </tr>
  	</c:if>
 	<c:if test="${! empty bridge.stpDesignatedRoot}">
      <tr>
        <th>stp designated root</th>
        <td>${bridge.stpDesignatedRoot}</td>
      </tr>
  	</c:if>
 	<c:if test="${! empty bridge.stpRootCost}">
      <tr>
        <th>stp root cost</th>
        <td>${bridge.stpRootCost}</td>
      </tr>
  	</c:if>
 	<c:if test="${! empty bridge.stpRootPort}">
      <tr>
        <th>stp root port</th>
        <td>${bridge.stpRootPort}</td>
      </tr>
  	</c:if>
      <tr>
        <th>create time</th>
        <td>${bridge.bridgeNodeCreateTime}</td>
      </tr>
      <tr>
        <th>last poll time</th>
        <td>${bridge.bridgeNodeLastPollTime}</td>
      </tr>
    </table>
    </c:forEach>
  </c:if>

  <!-- Ospf box, if info available -->
  <c:if test="${! empty model.ospf }">
    <h3 class="o-box">Ospf Information</h3>
    <table class="o-box">
      <tr>
        <th>Router Id</th>
        <td>${model.ospf.ospfRouterId}</td>
      </tr>
      <tr>
        <th>Version Number</th>
        <td>${model.ospf.ospfVersionNumber}</td>
      </tr>
      <tr>
        <th>Admin Status</th>
        <td>${model.ospf.ospfAdminStat}</td>
      </tr>
      <tr>
        <th>create time</th>
        <td>${model.ospf.ospfCreateTime}</td>
      </tr>
      <tr>
        <th>last poll time</th>
        <td>${model.ospf.ospfLastPollTime}</td>
      </tr>
    </table>
  </c:if>

  <!-- IsIs box, if info available -->
  <c:if test="${! empty model.isis }">
    <h3 class="o-box">Is-Is Information</h3>
    <table class="o-box">
      <tr>
        <th>Sys ID</th>
        <td>${model.isis.isisSysID}</td>
      </tr>
      <tr>
        <th>Admin State</th>
        <td>${model.isis.isisSysAdminState}</td>
      </tr>
      <tr>
        <th>create time</th>
        <td>${model.isis.isisCreateTime}</td>
      </tr>
      <tr>
        <th>last poll time</th>
        <td>${model.isis.isisLastPollTime}</td>
      </tr>
    </table>
  </c:if>

  <!-- Critical Path info, if info available -->
  <c:if test="${model.criticalPath != model.noCriticalPath}">
    <h3 class="o-box">Path Outage - Critical Path</h3>
    <div class="boxWrapper">
      <ul class="plain o-box">
        <li>
          ${model.criticalPath}
        </li>
      </ul>           
    </div>    
  </c:if>
	
	<!-- Availability box -->
	<c:if test="${fn:length( model.intfs ) < 10}">
    <jsp:include page="/includes/nodeAvailability-box.jsp" flush="false" >
      <jsp:param name="node" value="${model.id}" />
    </jsp:include>
    </c:if> 

  <script type="text/javascript">
    var nodeId = ${model.id}
  </script>
  <div id="interface-panel-gwt">
    <h3 class="o-box">Node Interfaces</h3>
    <opennms:interfacelist id="gwtnodeList"></opennms:interfacelist>
    <div name="opennms-interfacelist" id="gwtnodeList-ie"></div>
  </div>
	
  <!-- Vlan box if available -->
  <c:if test="${! empty model.vlans}">
    <h3 class="o-box">VLAN Information</h3>
    <table class="o-box">
      <thead>
        <tr>
          <th>Vlan ID</th>
          <th>Vlan Name</th>
          <th>Vlan Type</th>
          <th>Vlan Status</th>
          <th>Status</th>
          <th>Last Poll Time</th>
        </tr>
      </thead>
  
      <c:forEach items="${model.vlans}" var="vlan">
        <tr>
          <td>${vlan.vlanId}</td>
          <td>${vlan.vlanName}</td>
          <td>${vlan.vlanTypeString}</td>
          <td>${vlan.vlanStatusString}</td>
          <td>${vlan.statusString}</td>
          <td>${vlan.lastPollTime}</td>
        </tr>
      </c:forEach>
    </table>
  </c:if>

  
</div>

<div class="TwoColRight">
  
  <!-- general info box -->
  <h3 class="o-box">General (Status: ${model.status})</h3>
  <div class="boxWrapper">
    <ul class="plain o-box">
      <c:if test="${model.showRancid}">
        <c:url var="rancidLink" value="inventory/rancid.htm">
          <c:param name="node" value="${model.id}"/>
        </c:url>
        <li>
          <a href="<c:out value="${rancidLink}"/>">View Node Rancid Inventory Info </a>
        </li>
      </c:if>

      <c:if test="${model.showIpRoute}">
        <c:url var="ipRouteLink" value="element/routeipnode.jsp">
          <c:param name="node" value="${model.id}"/>
        </c:url>
        <li>
          <a href="<c:out value="${ipRouteLink}"/>">View Node IP Route Info</a>
        </li>
      </c:if>
     
      <c:if test="${model.showBridge}">
        <c:url var="bridgeLink" value="element/bridgenode.jsp">
          <c:param name="node" value="${model.id}"/>
        </c:url>
        <li>
          <a href="<c:out value="${bridgeLink}"/>">View Node Bridge/STP Info</a>
        </li>
      </c:if>

      <c:url var="detailLink" value="element/linkednode.jsp">
        <c:param name="node" value="${model.id}"/>
      </c:url>
      <li>
        <a href="<c:out value="${detailLink}"/>">View Node Link Detailed Info</a>
      </li>
    </ul>	     
  </div>
  
  <!-- Category box -->
  <jsp:include page="/includes/nodeCategory-box.htm" flush="false" >
    <jsp:param name="node" value="${model.id}" />
  </jsp:include>
  
  <!-- notification box -->
  <jsp:include page="/includes/notification-box.jsp" flush="false" >
    <jsp:param name="node" value="${model.id}" />
  </jsp:include>
  
  <!-- events list  box -->
  <c:url var="eventListUrl" value="event/list">
    <c:param name="filter" value="node=${model.id}"/>
  </c:url>
  <jsp:include page="/includes/eventlist.jsp" flush="false" >
    <jsp:param name="node" value="${model.id}" />
    <jsp:param name="throttle" value="5" />
    <jsp:param name="header" value="<a href='${eventListUrl}'>Recent Events</a>" />
    <jsp:param name="moreUrl" value="${eventListUrl}" />
  </jsp:include>
  
  <!-- Recent outages box -->
  <jsp:include page="/outage/nodeOutages-box.htm" flush="false"> 
    <jsp:param name="node" value="${model.id}" />
  </jsp:include>
</div>

<jsp:include page="/includes/footer.jsp" flush="false" />
