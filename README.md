### Version 8.2.1 is now available!

- Added basic HTTPS support
- Revised user management logic
- To avoid concurrency issues while refreshing master nodes, the `decommission` and `recommission` actions for both hosts and roles have been revised to use a list of items instead of a single item sequentially

### Version 8.1

- `-cmdAction=abort|retry` safeguarded by the `-confirmed|-run` options
- Rewrote the user management section to make it consistent with the rest of the code:
```
 -userAction: User action
	  (add|update) Create/update user
		-userName : User name
		-userPassword : User password (default: 'changeme')
		-userRole : User role (default: ROLE_USER)
		-f : JSON file to add users in bulk (instead of -userName)
	  (delete) Delete user (args: -userName)
	  (show) Display users (args: [-userName] | default: all)
```
Check the list of [user roles](https://cloudera.github.io/cm_api/apidocs/v15/ns0_apiUser.html).

- Minor changes

### Version 7.0

New service actions:

- Create role config group: `-a=createRoleGroup`
- Update role config group: `-a=updateRoleGroup`
- Delete role config group: `-a=deleteRoleGroup`

Check the list of [service types](https://cloudera.github.io/cm_api/apidocs/v15/path__clusters_-clusterName-_services.html) and [role types](https://cloudera.github.io/cm_api/apidocs/v15/path__clusters_-clusterName-_services_-serviceName-_roles.html).

### Version 6.0

- List the supported service types for a cluster: `-c=<...> -a=serviceTypes`
- List the supported role types for a service: `-s=<...> -a=roleTypes`
- Create cluster: `-a=createCluster`
- Update cluster: `-c=<...> -a=updateCluster`
- Delete cluster: `-c=<...> -a=deleteCluster`
- Create service: `-c=<...> -a=addService`
- Update service: `-s=<...> -a=updateService`
- Delete service: `-s=<...> -a=deleteService`

### Version 5.0

- Create roles: `-hInfo=<...> -addRole=<role_types> -serviceName=<service_name>`
- Delete roles: `-a=deleteRole`
- Display configuration for services (including Cloudera Management), role groups and roles: `-a=getConfig`
- Download service client configuration: `-s=<service_name> -a=getConfig -clientConfig`
- Update configuration: `-a=updateConfig`
- Move roles to a config group: `-a=moveToRoleGroup -roleConfigGroup=<config_group_name>`
- Move roles to the base (default) config group: `-a=moveToBaseGroup`
- Minor improvements

### Version 4.0

- Improved functionality: `-removeFromCluster`
- New options: `-maintenanceMode` and `-roleConfigGroup`
- List active commands for roles (already supported by clusters/services): `-a`
- New role actions (already supported by clusters/services):
  * `-a=enterMaintenanceMode`
  * `-a=exitMaintenanceMode`

### Version 3.0

- Rolling restart of services and roles: `-a=rollingRestart`
- Delete hosts from Cloudera Manager: `-deleteHost`
- Shortcut option (`-run`) for a commonly used combination of switches (namely, `-confirmed -trackCmd`)
- Code enhancements regarding host management
- Minor changes to improve code debugging and readability

### ---

## Synopsis

AUTHOR: Mariano Dominguez, <marianodominguez@hotmail.com>

FEEDBACK/BUGS: Please contact me by email.

The Cloudera Manager CLI (`cmcli.pl`) is a utility that facilitates cluster management and automation from the command-line through the Cloudera Manager REST API.

It is compatible with Cloudera Manager 5 (API v6 or higher). Most of the functionality should also work (not fully tested) with CM 4 (API v5 or lower) as well as CM 6, although there could be unsupported features.

A separate REST client (`cmapi.pl`) is provided to call the endpoints not supported by the CLI. `cmapi.pl` can also be used to get any command's downloadable result data, provided by`resultDataUrl`.

Unless overridden by the `-api` option, `cmcli.pl` will use the default API version available:

http://cloudera.github.io/cm_api/docs/releases/

The `-cmVersion` option shows the default API version for a given CM server host:

```
$ cmcli.pl -cm=<cm_server_host> -cmVersion
CM version: 5.7.4 (API: v12)
```

For information about the Cloudera Manager API, please check the following links:

<https://www.cloudera.com/documentation/enterprise/latest/topics/cm_intro_api.html>

<https://cloudera.github.io/cm_api/apidocs/v15/index.html>

## Installation

These utilities are written in Perl and have been tested using Perl 5.1x.x on RHEL 6 and 7.

Use [cpan](http://perldoc.perl.org/cpan.html) to install the following modules; alternately, download them from the [CPAN Search Site](http://search.cpan.org/) for manual installation:
- **REST::Client**
- **JSON**

Additionally, **LWP::Protocol::https** is required for HTTPS support.

These are the steps to manually compile and install a module to a custom location:

```
tar -xvf JSON-2.90.tar.gz
cd JSON-2.90
perl Makefile.PL PREFIX=/path
make
make install
```

Then, add the following line to the Perl code at the beginning of the `use` block:

`use lib qw(<PREFIX>/share/perl5);`

## Usage

The only required option for `cmcli.pl` is `-cm` to reference the CM server host, whereas `cmapi.pl` requires `<ResourceUrl>`.

Here is the usage information for both utilities:

```
Usage: cmcli.pl [-help] [-version] [-d] [-cm=[hostname]:[port]] [-https] [-api=v<integer>] [-u=cm_user] [-p=cm_password]
	[-cmVersion] [-cmConfig|-deployment] [-cmdId=command_id [-cmdAction=abort|retry]]
	[-userAction=show|add|update|delete [-userName=user_name|-f=json_file -userPassword=password -userRole=user_role]]
	[-hInfo[=...] [-hFilter=...] [-hRoles] [-hChecks] [-removeFromCluster] [-deleteHost] \
	  [-setRackId=/...] [-addToCluster=cluster_name] [-addRole=role_types -serviceName=service_name] [-hAction=command_name]]
	[-c=cluster_name] [-s=service_name [-sChecks] [-sMetrics]]
	[-rInfo[=host_id] [-r=role_type|role_name] [-rFilter=...] [-rChecks] [-rMetrics] [-log=log_type]]
	[-maintenanceMode[=YES|NO]] [-roleConfigGroup[=config_group_name]]
	[-a[=command_name]] [[-confirmed [-trackCmd]]|-run]
	[-yarnApps[=parameters]]
	[-impalaQueries[=parameters]]
	[-mgmt] (<> -s=mgmt)

	 -help : Display usage
	 -version : Display version information
	 -d : Enable debug mode
	 -cm : CM hostname:port (default: localhost:7180, or 7183 if using HTTPS)
	 -https : Use HTTPS to communicate with CM (default: HTTP)
	 -api : CM API version (v<integer> | default: response from <cm>/api/version)
	 -u : CM user name (environment variable: $CM_REST_USER | default: admin)
	 -p : CM password or path to password file (environment variable: $CM_REST_PASS | default: admin)
	      Credentials file: $HOME/.cm_rest (set env variables using colon-separated key/value pairs)
	 -cmVersion : Display Cloudera Manager and default API versions
	 -userAction: User action
	              (add|update) Create/update user
	                -userName : User name
	                -userPassword : User password (default: 'changeme')
	                -userRole : User role (default: ROLE_USER)
	                -f : JSON file to add users in bulk (instead of -userName)
	              (delete) Delete user (args: -userName)
	              (show) Display users (args: [-userName] | default: all)
	 -cmConfig : Save CM configuration to file
	 -deployment : Retrieve full description of the entire CM deployment
	 -cmdId : Retrieve information on an asynchronous command
	 -cmdAction : Command action
	              (abort) Abort a running command
	              (retry) Try to rerun a command
	 -hInfo : Host information (regex UUID, hostname, IP, rackId | default: all)
	 -hFilter : Host health summary, entity status, commission state (regex)
	 -hRoles : Display roles associated with host
	 -hChecks : Host health checks
	 -removeFromCluster : Remove the host from a cluster (set to cluster_name for API v10 or lower)
	 -deleteHost : Delete the host from Cloudera Manager
	 -setRackId : Update the rack ID of the host
	 -addToCluster : Add the host to a cluster
	 -addRole : Create new roles. Comma-separated list of role types (args: -serviceName, [-clusterName] /for API v10 or lower/)
	 -hAction : Host action
	            (decommission|recommission) Decommission/recommission the host
	            (startRoles) Start all the roles on the host
	            (enterMaintenanceMode|exitMaintenanceMode) Put/take the host into/out of maintenance mode
	 -c : Cluster name
	 -s : Service name (regex)
	 -r : Role type/name (regex)
	 -rInfo : Role information (regex UUID or set -hInfo | default: all)
	 -rFilter : Role state, health summary, configuration status, commission state (regex)
	 -maintenanceMode : Display maintenance mode. Select hosts/roles based on status (YES/NO | default: all)
	 -roleConfigGroup : Display role config group in the role information. Select roles based on config group name (regex | default: all)
	 -a : Cluster/service/role action (default: list active commands)
	      (stop|start|restart|refresh|...)
	      (deployClientConfig) Deploy cluster-wide/service client configuration
	      (decommission|recommission) Decommission/recommission roles of a service
	      (enterMaintenanceMode|exitMaintenanceMode) Put/take the cluster/service/role into/out of maintenance mode
	      (deleteRole) Delete a role from a given service
	      (rollingRestart) Rolling restart of roles in a service. Optional arguments:
	        -restartRoleTypes : Comma-separated list of role types to restart. If not set, all startable roles are restarted (default: all)
	        -slaveBatchSize : Number of hosts with slave roles to restart at a time (default: 1)
	        -sleepSeconds : Number of seconds to sleep between restarts of slave host batches (default: 0)
	        -slaveFailCountThreshold : Number of slave host batches that are allowed to fail to restart before the entire command is considered failed (default: 0)
	        -staleConfigsOnly : Restart roles with stale configs only (default: false)
	        -unUpgradedOnly : Restart roles that haven't been upgraded yet (default: false)
	      (getConfig|updateConfig) : Display/update the configuration of services/role config groups/roles
	        Syntax: -a=getConfig [-clientConfig] | [-roleConfigGroup[=config_group_name]] [-propertyName[=property_name]]
	                -a=updateConfig [-roleConfigGroup=config_group_name] -propertyName=property_name [-propertyValue=property_value]
	        -clientConfig : Save service client configuration to file (default: disabled)
	        -roleConfigGroup : Role config group name. If empty, list role config groups for a given service (default: disabled)
	        -propertyName : Configuration parameter canonical name. Required for -updateConfig. Regex filter for -getConfig (default: all)
	        -propertyValue : User-defined value. When absent, the default value (if any) will be used
	        -full : Full view (default view: summary)
	      (createRoleGroup) Create role config group (args: -displayName, -roleType, [-copyFromRoleGroup])
	      (updateRoleGroup) Update role config group (args: -displayName, -copyFromRoleGroup)
	      (deleteRoleGroup) Delete role config group
	      (moveToRoleGroup) Move roles to a config group (args: -roleConfigGroup)
	      (moveToBaseGroup) Move roles to the base role config group
	      (addCluster) Create cluster (args: -clusterName, -displayName, -fullVersion)
	      (updateCluster) Update cluster information (args: -displayName, -fullVersion)
	      (deleteCluster) Delete cluster
	      (serviceTypes) List the supported service types for a cluster
	      (addService) Create service (args: -serviceName, -serviceType, -displayName)
	      (updateService) Update service information (args: -displayName)
	      (deleteService) Delete service
	      (roleTypes) List the supported role types for a service
	 -confirmed : Proceed with the command execution
	 -trackCmd : Display the result of all executed asynchronous commands before exiting
	 -run : Shortcut for '-confirmed -trackCmd'
	 -sChecks : Service health checks
	 -sMetrics : Service metrics
	 -rChecks : Role health checks
	 -rMetrics : Role metrics
	 -log : Display role log (type: full, stdout, stderr /also stacks, stacksBundle for mgmt service/)
	 -yarnApps : Display YARN applications (example: -yarnApps='filter='executing=true'')
	 -impalaQueries : Display Impala queries (example: -impalaQueries='filter='user=<userName>'')
	 -mgmt (-s=mgmt) : Cloudera Management Service information (default: disabled)
```
```
Usage: cmapi.pl [-help] [-version] [-d] [-u=username] [-p=password]
	[-m=method] [-bt=body_type] [-bc=body_content [-i]] [-f=json_file] <ResourceUrl>

	 -help : Display usage
	 -version : Display version information
	 -d : Enable debug mode
	 -u : CM username (environment variable: $CM_REST_USER | default: admin)
	 -p : CM password or path to password file (environment variable: $CM_REST_PASS | default: admin)
	      Credentials file: $HOME/.cm_rest (set env variables using colon-separated key/value pairs)
	 -m : Method | GET, POST, PUT, DELETE (default: GET)
	 -bt : Body type | array, hash, json (default: hash)
	 -bc : Colon-separated list of property/value pairs for a single object (use ~ as delimiter in array properties if -bt=hash)
	       To set multiple objects, use -bt=json or -f to pass a JSON file
	 -i : Add 'items' property to the body content (on by default if -bt=array)
	 -f : JSON file containing body content (implies -bt=json)
	 <ResourceUrl> : URL to REST resource (example: [http://]cloudera-manager:7180/api/v15/clusters/)
```

## Setting credentials

CM credentials can be passed by using the `-u` (username) and `-p` (password) options. The `-p` option can be set to the password string itself (**not recommended**) or to a file containing the password:

`$ cmcli.pl -u=username -p=/path/to/password_file -cm=<cm_server_host>`

Credentials can also be passed by using the `$CM_REST_USER` and `$CM_REST_PASS` environment variables. Just like the `-p` option, the `$CM_REST PASS` environment variable can be set to a file containing the password:

```
export CM_REST_USER=username
export CM_REST_PASS=/path/to/password_file
```

The aforementioned environment variables can be loaded through a credentials file (`$HOME/.cm_rest`), if it exists:

```
$ cat $HOME/.cm_rest
CM_REST_USER:username
CM_REST_PASS:/path/to/password_file
```

NOTE: For passwords containing white spaces, quote them and, instead of using the credentials file, set the `-p` option or `export CM_REST_PASS`.

The preference is as follows (highest first):

1. Options `-u`, `-p`
2. Credentials file
3. Environment variables (using the `export` command)
4. Default credentials (*admin*/*admin*)

## Supported cluster/service/role commands

In addition to the actions listed in the usage section, to execute a command endpoint, set `-a={commandName}` in the appropriate context. These are the supported commands:

Role actions
- `/clusters/{clusterName}/services/{serviceName}/roleCommands/{commandName}`
- MGMT: `/cm/service/roleCommands/{commandName}`

Service actions
- All `/clusters/{clusterName}/services/{serviceName}/commands/{commandName}` endpoints that don't require *Request Body*, except the following supported commands:
  * `deployClientConfig`
  * `decommission`
  * `recommission`
  * `rollingRestart`
- MGMT: `/cm/service/commands/{commandName}`

Cluster actions
- All `/clusters/{clusterName}/commands/{commandName}` endpoints that don't require *Request Body*.

For a complete list of commands, go to https://cloudera.github.io/cm_api/ and click on **Full API Docs > REST**.

## Cluster/Service/Role output

<https://cloudera.github.io/cm_api/apidocs/v15/ns0_apiCluster.html>

`name | maintenanceMode >>> displayName (CDH fullVersion) --- entityStatus`

<https://cloudera.github.io/cm_api/apidocs/v15/ns0_apiService.html>

`... | name | maintenanceMode | displayName --- serviceState healthSummary configStalenessStatus clientConfigStalenessStatus`

<https://cloudera.github.io/cm_api/apidocs/v15/ns0_apiRole.html>

`... | ... | hostId (hostname) | type | roleConfigGroupRef->roleConfigGroupName | maintenanceMode | commissionState | name --- roleState healthSummary configStalenessStatus` 

## Host output

https://cloudera.github.io/cm_api/apidocs/v15/ns0_apiHost.html

`hostname | hostId | ipAddress | rackId | maintenanceMode | commissionState | clusterRef->clusterName --- healthSummary entityStatus`

## Command output

https://cloudera.github.io/cm_api/apidocs/v15/ns0_apiCommand.html

`id | name | startTime | endTime | active | success | resultMessage | resultDataUrl | canRetry | clusterRef | serviceRef | roleRef | hostRef`

## How-To

Here are some common use cases:

* Show all managed hosts:

    `$ cmcli.pl -hInfo`

* Show hosts not associated with any cluster:

    `$ cmcli.pl -hInfo -c='No cluster'`

* Show hosts with no roles:

    `$ cmcli.pl -hInfo -s='No roles'`

* Show hosts assigned to the /default rack:

    `$ cmcli.pl -hInfo=/default`

* Assign them to rack /rack1:

    `$ cmcli.pl -hInfo=/default -setRackId=/rack1`

* Show information about a given host:

    `$ cmcli.pl -hInfo=host_name`

* Show role information:

    `$ cmcli.pl -hInfo=host_name -hRoles`

* Show hosts associated with a given cluster:

    `$ cmcli.pl -hInfo -c=cluster_name`

* Decommission hosts in bad health:

    `$ cmcli.pl -c=cluster_name -hFilter=bad -hAction=decommission`

* Show clusters and services:

    `$ cmcli.pl -cm=cm_server`

* Show the Cloudera Management Service instances:

    `$ cmcli.pl -mgmt -rInfo`

    *or*

    `$ cmcli.pl -s=mgmt -rInfo`

* Show the roles of the HDFS service of 'cluster2':

    `$ cmcli.pl -c=cluster2 -s=hdfs -rInfo`

    *To replace the host id (UUID) in the output with the host name, simply add `-hInfo`.*

* Show the DataNode instances:

    `$ cmcli.pl -c=cluster2 -s=hdfs -r=datanode`

* Show the stopped DataNodes:

    `$ cmcli.pl -c=cluster2 -s=hdfs -r=datanode -rFilter=stopped`

* Start the stopped DataNodes:

    `$ cmcli.pl -c=cluster2 -s=hdfs -r=datanode -rFilter=stopped -a=start`

    *To execute the action, use `-confirmed`. To check the command execution status, add `-trackCmd`. To do both, just use the `-run` shortcut instead.*

* Deploy the YARN client configuration at the service level:

    `$ cmcli.pl -c=cluster2 -s=yarn -a=deployClientConfig`

* Restart all the Flume services:

    `$ cmcli.pl -c=cluster2 -s=flume -a=restart`

* Restart the 'flume' service only:

    `$ cmcli.pl -c=cluster2 -s='flume$' -a=restart` --> using regex

* Restart the 'hive2' and 'oozie1' services:

    `$ cmcli.pl -c=cluster2 -s='hive2|oozie1' -a=restart` --> using regex

* Start all the roles on a given host:

    `$ cmcli.pl -hInfo=host_name -hAction=startRoles`

    *or*

    `$ cmcli.pl -hInfo=host_name -a=start`

* Decommission the NodeManager instance on a given host:

    `$ cmcli.pl -hInfo=host_name -r=nodemanager -a=decommission`

* Restart the DataNode instance on a given host:

	`$ cmcli.pl -hInfo=host_name -r=datanode -a=restart`
	
* Restart the agent of the 'flume2' service on a given host:

    `$ cmcli.pl -hInfo=host_name -s=flume2 -a=restart`

* Create multiple CM users:

```
$ cat users.json 
{
  "items" : [ {
    "name" : "user1",
    "password" : "changeme"
  }, {
    "name" : "user2",
    "password" : "changeme",
    "roles" : [ "ROLE_USER" ]
  }, {
    "name" : "user3",
    "password" : "changeme",
    "roles" : [ "ROLE_CONFIGURATOR" ]
  }, {
    "name" : "user4",
    "password" : "changeme",
    "roles" : [ "ROLE_OPERATOR" ]
  } ]
}
$ cmcli.pl -userAction=add -f=users.json
Loading file users.json...
{
  "items" : [ {
    "name" : "user1",
    "roles" : [ "ROLE_USER" ]
  }, {
    "name" : "user2",
    "roles" : [ "ROLE_USER" ]
  }, {
    "name" : "user3",
    "roles" : [ "ROLE_CONFIGURATOR" ]
  }, {
    "name" : "user4",
    "roles" : [ "ROLE_OPERATOR" ]
  } ]
}
$ cmcli.pl -userAction=show
admin
 ROLE_ADMIN
user1
 ROLE_USER
user2
 ROLE_USER
user3
 ROLE_CONFIGURATOR
user4
 ROLE_OPERATOR
```

* Create a single user (default password: 'changeme') without a JSON file:

```
$ cmcli.pl -userAction=add -userName=user5 -userRole=role_operator
Adding user 'user5'...
{
  "items" : [ {
    "name" : "user5",
    "roles" : [ "ROLE_OPERATOR" ]
  } ]
}
```
*`-userRole` is NOT case-sensitive. Check the list of [user roles](https://cloudera.github.io/cm_api/apidocs/v15/ns0_apiUser.html).*

* Change password and role for 'user1':

```
$ cmcli.pl -userAction=update -userName=user1 -userPassword=new_password -userRole=role_admin 
Updating user 'user1'...
{
  "name" : "user1",
  "roles" : [ "ROLE_ADMIN" ]
}
```

* Delete 'user4':

```
$ cmcli.pl -userAction=delete -userName=user4
Deleting user 'user4'...
{
  "name" : "user4",
  "roles" : [ "ROLE_OPERATOR" ]
}
$ cmcli.pl -userAction=show
admin
 ROLE_ADMIN
user1
 ROLE_ADMIN
user2
 ROLE_USER
user3
 ROLE_CONFIGURATOR
user5
 ROLE_OPERATOR
```

* Delete the selected hosts from CM:

	`cmcli.pl -hInfo=<perl_regex> -deleteHost`

* Remove the selected hosts from ANY cluster (if using API v11 or higher):

	`cmcli.pl -hInfo=<perl_regex> -removeFromCluster`

	*If using API v10 or lower, remove hosts from 'cluster2':*

	`cmcli.pl -hInfo=<perl_regex> -removeFromCluster=cluster2`

* Roll restart all the roles on the selected hosts:

    `cmcli.pl -hInfo=<perl_regex> -a=rollingRestart`

* Roll restart the HBase roles on the selected hosts:

    `cmcli.pl -hInfo=<perl_regex> -a=rollingRestart -s=hbase`

* Roll restart the NodeManager roles of the YARN service of 'cluster2' with extra options:

    `cmcli.pl -c=cluster2 -s=yarn -a=rollingRestart -slaveBatchSize=3 -sleepSeconds=10 -restartRoleTypes=nodemanager`
    
    *`-restartRoleTypes` is NOT case-sensitive. Check the list of [role types](https://cloudera.github.io/cm_api/apidocs/v15/path__clusters_-clusterName-_services_-serviceName-_roles.html) or use `-s=<...> -a=roleTypes`.*
    
* Roll restart the ResourceManager roles:

    `cmcli.pl -c=cluster2 -s=yarn -a=rollingRestart -restartRoleTypes=resourcemanager`

* Roll restart YARN roles with stale configs only:

    `cmcli.pl -c=cluster2 -s=yarn -a=rollingRestart -staleConfigsOnly=true`

    *or*

    `cmcli.pl -c=cluster2 -s=yarn -rFilter=stale -a=rollingRestart`

* Roll restart NameNode and JournalNode roles:

    `cmcli.pl -c=cluster2 -s=hdfs -a=rollingRestart -restartRoleTypes=namenode,journalnode`

    *or*

    `cmcli.pl -c=cluster2 -s=hdfs —r='name|journal' -a=rollingRestart`

* Roll restart all ZooKeeper and Flume services:

    `cmcli.pl -c=cluster2 -s='zoo|flume' -a=rollingRestart`

* Multi-action command: Add hosts to cluster 'cluster2', set rack Id, create HIVESERVER2 and GATEWAY roles (service 'hive1') and enable maintenance mode on the hosts:

    `cmcli.pl -hInfo=<perl_regex> -setRackId=/rack_id -addToCluster=cluster2 -addRole=hiveserver2,gateway -serviceName=hive1 -hAction=enterMaintenanceMode`

    *`-addRole` is NOT case-sensitive. Check the list of [role types](https://cloudera.github.io/cm_api/apidocs/v15/path__clusters_-clusterName-_services_-serviceName-_roles.html) or use `-s=<...> -a=roleTypes`.*

* Delete all the roles from a host:

	`cmcli.pl -hInfo=host_name -a=deleteRole`
	
	*(Follow-up multi-action command) Remove host from the cluster and from CM:*
	
	`cmcli.pl -hInfo=host_name -removeFromCluster -deleteHost`

* Delete the Hive GATEWAY role from a host:

	`cmcli.pl -hInfo=host_name -s=hive -r=gateway -a=deleteRole`

* Display the configuration of the 'flume1' service:

    `cmcli.pl -c=cluster2 -s=flume1 -a=getConfig`

* Download the client configuration of all the Hive services:

    `cmcli.pl -c=cluster2 -s=hive -a=getConfig -clientConfig`

* Display the role config groups of the HDFS service:

    `cmcli.pl -c=cluster2 -s=hdfs -a=getConfig -roleConfigGroup`

* Display the full-view configuration of the default role config group:

    `cmcli.pl -c=cluster2 -s=hdfs -a=getConfig -roleConfigGroup=hdfs1-DATANODE-BASE -full`
    
    *In addition to `name` and `value`, the full view output includes the `validateState`, `validateMessage` and `displayName` properties (see [apiConfig](https://cloudera.github.io/cm_api/apidocs/v15/ns0_apiConfig.html))*

* Update the 'dfs_data_dir_list' property:

    `cmcli.pl -c=cluster2 -s=hdfs -a=updateConfig -roleConfigGroup=hdfs1-DATANODE-BASE -propertyName=dfs_data_dir_list -propertyValue=new_value`

* Override the 'dfs_data_dir_list' property on a given host:

    `cmcli.pl -hInfo=host_name -r=datanode -a=updateConfig -propertyName=dfs_data_dir_list -propertyValue=new_value`

* Reset the 'dfs_data_dir_list' property on a given host to the config group value:

    `cmcli.pl -hInfo=host_name -r=datanode -a=updateConfig -propertyName=dfs_data_dir_list`

* Move the DataNode role on a given host to a different config group:

   	`cmcli.pl -hInfo=host_name -r=datanode -a=moveToRoleGroup -roleConfigGroup=hdfs1-DATANODE-1`

* Move the DataNode role on a given host to the default config group:

	`cmcli.pl -hInfo=host_name -r=datanode -a=moveToBaseGroup`

* Update the Flume Agent configuration file of the default config group:

	`cmcli.pl -c=cluster2 -s=flume1 -a=updateConfig -roleConfigGroup=flume-AGENT-BASE -propertyName=agent_config_file -propertyValue="$(<flume1.conf)"`

	*NOTE: The `flume1.conf` text file must have newline characters escaped to avoid an error like the following:*

	```
	"message" : "Illegal unquoted character ((CTRL-CHAR, code 10)): has to be escaped using backslash to be included in string value
	at [Source: org.apache.cxf.transport.http.AbstractHTTPDestination$1@1874a9cf; line: 1, column: 98]"
	```

	*Here is an easy way to escape newline characters using a Perl one-liner:*

	`perl -npe "s/\n/\\\n/g" flume.conf > flume1.conf`

* Refresh the Flume Agents of the default config group to apply the new configuration file:

	`cmcli.pl -c=cluster2 -s=flume1 -roleConfigGroup=agent-base -rFilter=refreshable -a=refresh`
