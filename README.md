### Table of Contents

[Release Notes](https://github.com/mrdominguez/cloudera-manager-cli/blob/master/README.md#release-notes)  
[Synopsis](https://github.com/mrdominguez/cloudera-manager-cli/blob/master/README.md#synopsis)  
[Sample Output](https://github.com/mrdominguez/cloudera-manager-cli/blob/master/README.md#sample-output)  
[Installation](https://github.com/mrdominguez/cloudera-manager-cli/blob/master/README.md#installation)  
[Setting Credentials](https://github.com/mrdominguez/cloudera-manager-cli/blob/master/README.md#setting-credentials)  
[Usage](https://github.com/mrdominguez/cloudera-manager-cli/blob/master/README.md#usage)  
[Supported Cluster/Service/Role Commands](https://github.com/mrdominguez/cloudera-manager-cli/blob/master/README.md#supported-clusterservicerole-commands)  
[Cluster/Service/Role Output](https://github.com/mrdominguez/cloudera-manager-cli/blob/master/README.md#clusterservicerole-output)  
[Host Output](https://github.com/mrdominguez/cloudera-manager-cli/blob/master/README.md#host-output)  
[Command Output](https://github.com/mrdominguez/cloudera-manager-cli/blob/master/README.md#command-output)  
[How-To](https://github.com/mrdominguez/cloudera-manager-cli/blob/master/README.md#how-to)

## Release Notes
### Version 10.5 is now available!
- Changes to CM REST client (`cmrest.pl`):
  * Support for redirections
  * Added option to not use `Authorization` header in the HTTP request

```
-noredirect : Do not follow redirects
-noauth : Do not add Authorization header
```

### Version 10.4
- Changes to CM REST client (`cmrest.pl`):
  * All arguments are now flag-based (see [Usage](https://github.com/mrdominguez/cloudera-manager-cli/blob/master/README.md#usage))
  * New output format: `-dumper : Use Data::Dumper to output the JSON response content (default: disabled)`

### Version 10.3

- Added new option to `-sFilter`:
```
-sClient : Apply service filter only to client configuration status (default: disabled)
```
- Prompt for username and/or password if no value is given in the command line:
```
$ cmcli.pl -u -p
Username [admin]: mdom
Password [admin]: ****
```
- New ` -userAction` commands:
```
	(reset) Reset user password and role to default values (args: -userName)
	(sessions) Display interactive user sessions
	(expireSessions) Expire user session (args: -userName)
```
- Prompt for password and role when adding or updating a CM user:
```
$ cmcli.pl -userAction=update -userName=mdom -userPassword -userRole
Enter password [changeme]: ****
Re-enter password [changeme]: ****
Enter role [ROLE_USER]: ROLE_ADMIN
Updating user 'mdom'...
```

### Version 10

- Collect diagnostics data for YARN applications:  
```
-a=diagData
	-appId : Comma-separated list of application IDs
	-ticketNumber : Cloudera Support ticket number (default: empty)
	-comments : Comments to add to the support bundle (default: empty)
``` 
- Download command's downloadable result data, if any exists: `-download` (enables `-trackCmd`)
- Save role log to file: `-log=log_type -download`
- New `-yarnApps` options:
  * `-attributes`
  * `-kill -appId=app_id`
- New `-impalaQueries` options:
  * `-attributes`
  * `-queryId=query_id [-format=text|thrift] [-cancel]`
- Added unattended installation script for RHEL-based distributions (see [Installation](https://github.com/mrdominguez/cloudera-manager-cli/blob/master/README.md#installation) section for details)

### Version 9

- New service filters: `-sFilter`, `-maintenanceMode`
- Added support for:
  * Automatic URL redirection
  * HTTPS protocol: `-https`
  * Comma-separated list of command IDs: `-cmdId`
- Show HTTP response code and headers in debug mode (`-d`)
- Revised user management logic
- Updated `decommission` and `recommission` actions for both hosts and roles to use a list of items instead of a single item sequentially (to avoid concurrency issues while refreshing master nodes)
- Overall code improvements

### Version 8

- `-cmdAction=abort|retry` safeguarded by `-confirmed|-run` options
- Rewrote the user management section to make it consistent with the rest of the code:
```
-userAction: User action (default: show)
	(show) Display users (args: [-userName] | default: all)
	(add|update) Create/update user
		-userName : User name
		-userPassword : User password (default: 'changeme')
		-userRole : User role (default: ROLE_USER)
		-f : JSON file to add users in bulk (instead of -userName)
	(delete) Delete user (args: -userName)
```
Check the list of [user roles](https://cloudera.github.io/cm_api/apidocs/v19/ns0_apiUser.html)
- Minor code changes

### Version 7

*New service actions*
- Create role config group: `-a=createRoleGroup`
- Update role config group: `-a=updateRoleGroup`
- Delete role config group: `-a=deleteRoleGroup`

Check the list of [service types](https://cloudera.github.io/cm_api/apidocs/v19/path__clusters_-clusterName-_services.html) and [role types](https://cloudera.github.io/cm_api/apidocs/v19/path__clusters_-clusterName-_services_-serviceName-_roles.html)

### Version 6

- List the supported service types for a cluster: `-c=... -a=serviceTypes`
- List the supported role types for a service: `-s=... -a=roleTypes`
- Create cluster: `-a=createCluster`
- Update cluster: `-c=... -a=updateCluster`
- Delete cluster: `-c=... -a=deleteCluster`
- Create service: `-c=... -a=addService`
- Update service: `-s=... -a=updateService`
- Delete service: `-s=... -a=deleteService`

### Version 5

- Create roles: `-hInfo=... -addRole=role_types -serviceName=service_name`
- Delete roles: `-a=deleteRole`
- Display configuration for services (including Cloudera Management), role groups and roles: `-a=getConfig`
- Download service client configuration: `-s=service_name -a=getConfig -clientConfig`
- Update configuration: `-a=updateConfig`
- Move roles to a config group: `-a=moveToRoleGroup -roleConfigGroup=config_group_name`
- Move roles to the base (default) config group: `-a=moveToBaseGroup`
- Minor code improvements

### Version 4

- Improved functionality: `-removeFromCluster`
- New options: `-maintenanceMode`, `-roleConfigGroup`

*The following features are already supported for clusters/services*
- List active role commands: `-a`
- New role actions:
  * `-a=enterMaintenanceMode`
  * `-a=exitMaintenanceMode`

### Version 3

- Rolling restart of services and roles: `-a=rollingRestart`
- Delete hosts from Cloudera Manager: `-deleteHost`
- Alias for a commonly used combination of switches: `-run` ≡ `-confirmed -trackCmd`
- Code enhancements regarding host management
- Improved code debugging and readability

## Synopsis

AUTHOR: Mariano Dominguez  
<marianodominguez@hotmail.com>  
https://www.linkedin.com/in/marianodominguez

FEEDBACK/BUGS: Please contact me by email.

The Cloudera Manager CLI (`cmcli.pl`) is a utility that facilitates cluster management and automation from the command-line through the Cloudera Manager REST API.

It is compatible with Cloudera Manager 5 and higher (API v6 and after).

Use the general purpose CM REST client (`cmrest.pl`) to call the endpoints not supported by the CM CLI and to get any command's downloadable result data (`resultDataUrl`).

Unless overridden by the `-api` option, `cmcli.pl` will utilize the default API version available:

https://cloudera.github.io/cm_api/docs/releases/

The `-cmVersion` option shows the default API version for a given CM server host:
```
$ cmcli.pl -cm=cm_server_host -cmVersion
CM version: 5.7.4 (API: v12)
```

For information about the Cloudera Manager API, please check the following links:

<https://www.cloudera.com/documentation/enterprise/latest/topics/cm_intro_api.html>

<https://cloudera.github.io/cm_api/apidocs/v19/index.html>

*NOTE: Replace the API version in the URLs accordingly*

## Sample Output

By default, if not set explicitly, `-cm` points to `localhost:7180` (or `7183` if `https` is enabled):
```
$ cmcli.pl
Redirecting to https://localhost:7183/...
Cluster 1 >>> Cluster 1 (6.3.3) --- GOOD_HEALTH
|_ Cluster 1 | zookeeper | ZOOKEEPER | ZooKeeper --- STARTED GOOD FRESH FRESH
|_ Cluster 1 | oozie | OOZIE | Oozie --- STARTED GOOD FRESH FRESH
|_ Cluster 1 | hue | HUE | Hue --- STARTED GOOD FRESH FRESH
|_ Cluster 1 | hdfs | HDFS | HDFS --- STARTED GOOD FRESH FRESH
|_ Cluster 1 | impala | IMPALA | Impala --- STARTED GOOD FRESH FRESH
|_ Cluster 1 | yarn | YARN | YARN (MR2 Included) --- STARTED GOOD FRESH FRESH
|_ Cluster 1 | hive | HIVE | Hive --- STARTED GOOD FRESH FRESH
|_ Cluster 1 | spark_on_yarn | SPARK_ON_YARN | Spark --- STARTED GOOD FRESH FRESH
|_ Cluster 1 | sentry | SENTRY | Sentry --- STARTED GOOD FRESH FRESH
|_ Cluster 1 | kudu | KUDU | Kudu --- STARTED GOOD FRESH FRESH
|_ Cluster 1 | hbase | HBASE | HBase --- STARTED GOOD FRESH FRESH
$
$ cmcli.pl -hInfo -s=hive -rInfo
Redirecting to https://localhost:7183/...
node1.localdomain | 6c1df663-ec34-4367-8420-8477a2524791 | 192.168.0.191 | /default | COMMISSIONED | Cluster 1 --- GOOD GOOD_HEALTH
node2.localdomain | 2e68d2f3-dd4e-4f6e-8dbb-17e68bd63948 | 192.168.0.192 | /default | COMMISSIONED | Cluster 1 --- GOOD GOOD_HEALTH
node3.localdomain | 46bd1ea9-5ac6-4540-96da-9041d7bfb1c6 | 192.168.0.193 | /default | COMMISSIONED | Cluster 1 --- GOOD GOOD_HEALTH
# Number of hosts: 3
|_ Cluster 1 | hive | HIVE | Hive --- STARTED GOOD FRESH FRESH
  |_ Cluster 1 | hive | node2.localdomain | HIVESERVER2 | COMMISSIONED | hive-HIVESERVER2-560991e0d064f19d3f49e994bb334d90 --- STARTED GOOD FRESH
  |_ Cluster 1 | hive | node1.localdomain | HIVEMETASTORE | COMMISSIONED | hive-HIVEMETASTORE-1a2349b677ff4b7d158c0bc05441898c --- STARTED GOOD FRESH
  |_ Cluster 1 | hive | node3.localdomain | GATEWAY | COMMISSIONED | hive-GATEWAY-c430b17e260c846cab6867cd28f78e13 --- NA GOOD FRESH
  |_ Cluster 1 | hive | node1.localdomain | GATEWAY | COMMISSIONED | hive-GATEWAY-1a2349b677ff4b7d158c0bc05441898c --- NA GOOD FRESH
  |_ Cluster 1 | hive | node2.localdomain | GATEWAY | COMMISSIONED | hive-GATEWAY-560991e0d064f19d3f49e994bb334d90 --- NA GOOD FRESH
Cluster 1 | hive | GATEWAY: 3
Cluster 1 | hive | HIVEMETASTORE: 1
Cluster 1 | hive | HIVESERVER2: 1
$
$ cmcli.pl -https -mgmt
mgmt | MGMT --- STARTED GOOD FRESH
$
```

## Installation

These utilities are written in *Perl* and have been tested using version *5.1x.x* on *RHEL 6/7*, as well as *macOS Sierra (10.12)* and after.

Use [cpan](http://perldoc.perl.org/cpan.html) to install the following modules; alternately, download them from the [CPAN Search Site](http://search.cpan.org/) for manual installation:
- **REST::Client**
- **JSON**
- **IO::Prompter** (for username/password prompt)

Additionally, **LWP::Protocol::https** is required for HTTPS support.

The following is an example of an unattended installation script for RHEL-based distributions:
```
#!/bin/bash

sudo yum -y install git cpan gcc openssl openssl-devel

REPOSITORY=cloudera-manager-cli
cd; git clone https://github.com/mrdominguez/$REPOSITORY

cd $REPOSITORY
chmod +x *.pl
ln -s cmcli.pl cmcli
ln -s cmrest.pl cmrest

cd; grep "PATH=.*$REPOSITORY" .bashrc || echo -e "\nexport PATH=\"\$HOME/$REPOSITORY:\$PATH\"" >> .bashrc

echo | cpan
. .bashrc

perl -MCPAN -e 'my $c = "CPAN::HandleConfig"; $c->load(doit => 1, autoconfig => 1); $c->edit(prerequisites_policy => "follow"); $c->edit(build_requires_install_policy => "yes"); $c->commit'
cpan CPAN::Meta::Requirements CPAN
cpan Module::Metadata JSON REST::Client IO::Prompter

cmcli -help
echo "Run 'source ~/.bashrc' to refresh environment variables"
```

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

## Setting Credentials

Cloudera Manager credentials can be passed by using the `-u` (username) and `-p` (password) options. The `-p` option can be set to the password string itself (**not recommended**) or to a file containing the password:

`$ cmcli.pl -u=username -p=/path/to/password_file -cm=cm_server_host`

Both username and password values are optional. If no value is provided, there will be a prompt for one.

Credentials can also be passed by using the `$CM_REST_USER` and `$CM_REST_PASS` environment variables. Just like the `-p` option, the `$CM_REST_PASS` environment variable can be set to a file containing the password:
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

NOTE: Quote passwords containing white spaces and, instead of using the credentials file, set the `-p` option or `export CM_REST_PASS`.

The preference is as follows (highest first):

1. Options `-u`, `-p`
2. Credentials file
3. Environment variables (using the `export` command)
4. Default credentials (*admin*/*admin*)

## Usage

**cmcli.pl**
```
Usage: cmcli.pl [-help] [-version] [-d] [-cm=[hostname]:[port]] [-https] [-api=v<integer>] [-u[=username]] [-p[=password]]
	[-cmVersion] [-cmConfig|-deployment] [-cmdId=command_ids [-cmdAction=abort|retry]]
	[-userAction=user_action [-userName=user_name|-f=json_file -userPassword[=password] -userRole[=user_role]]]
	[-hInfo[=host_info] [-hFilter=host_filter] [-hRoles] [-hChecks] [-removeFromCluster] [-deleteHost] \
	  [-setRackId=/rack_id] [-addToCluster=cluster_name] [-addRole=role_types -serviceName=service_name] [-hAction=host_action]]
	[-mgmt] [-c=cluster_name] [-s=service_name [-sChecks] [-sMetrics]] [-sFilter=service_filter [-sClient]]
	[-rInfo[=host_id] [-r=role_type|role_name] [-rFilter=role_filter] [-rChecks] [-rMetrics] [-log=log_type]]
	[-maintenanceMode[=YES|NO]] [-roleConfigGroup[=config_group_name]]
	[-a[=action]] [-confirmed] [-trackCmd] [-download] [-run]
	[-yarnApps[=parameters] [-attributes] [-kill -appId=app_id]]
	[-impalaQueries[=parameters] [-attributes] [-queryId=query_id [-format=text|thrift] [-cancel]]

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
	 -userAction: User action (default: show)
                      (show) Display user details (args: [-userName] | default: all)
                      (add|update) Create/update user
                        -userName : User name
                        -userPassword : User password (default: 'changeme')
                        -userRole : User role (default: ROLE_USER)
                        -f : JSON file to add users in bulk (instead of -userName)
                      (delete) Delete user (args: -userName)
                      (reset) Reset user password and role to default values (args: -userName)
                      (sessions) Display interactive user sessions
                      (expireSessions) Expire user session (args: -userName)
	 -cmConfig : Save CM configuration to file
	 -deployment : Retrieve full description of the entire CM deployment
	 -cmdId : Retrieve information on asynchronous commands (comma-separated list of command IDs)
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
	 -addRole : Create new roles. Comma-separated list of role types (args: -serviceName /-clusterName for API v10 or lower/)
	 -hAction : Host action
	            (decommission|recommission) Decommission/recommission the host
	            (startRoles) Start all the roles on the host
	            (enterMaintenanceMode|exitMaintenanceMode) Put/take the host into/out of maintenance mode
	 -c : Cluster name
	 -s : Service name (regex)
	 -r : Role type/name (regex)
	 -rInfo : Role information (regex UUID, superseded by -hInfo | default: all)
	 -rFilter : Role state, health summary, configuration status, commission state (regex)
	 -sFilter : Service state, health summary, configuration status, client configuration status (regex)
	   -sClient : Apply service filter only to client configuration status (default: disabled)
	 -maintenanceMode : Display maintenance mode. Select hosts/services/roles based on status (YES/NO | default: all)
	 -roleConfigGroup : Display role config group in the role information. Select roles based on config group name (regex | default: all)
	 -a : Cluster/Service/Role action (default: list active commands)
	      (stop|start|restart|refresh|...)
	      (deployClientConfig) Deploy cluster-wide/service client configuration
	      (decommission|recommission) Decommission/recommission roles of a service
	      (enterMaintenanceMode|exitMaintenanceMode) Put/take the cluster/service/role into/out of maintenance mode
	      (deleteRole) Delete a role from a given service
	      (rollingRestart) Rolling restart of roles in a service
	        -restartRoleTypes : Comma-separated list of role types to restart. If not set, all startable roles are restarted (default: all)
	        -slaveBatchSize : Number of hosts with slave roles to restart at a time (default: 1)
	        -sleepSeconds : Number of seconds to sleep between restarts of slave host batches (default: 0)
	        -slaveFailCountThreshold : Number of slave host batches that are allowed to fail to restart before the entire command is considered failed (default: 0)
	        -staleConfigsOnly : Restart roles with stale configs only (default: false)
	        -unUpgradedOnly : Restart roles that haven't been upgraded yet (default: false)
	      (getConfig|updateConfig) : Display/update the configuration of services/roles
	        Syntax: -a=getConfig [-propertyName=property_name] [-clientConfig] [-roleConfigGroup[=config_group_name]]
	                -a=updateConfig [-roleConfigGroup=config_group_name] -propertyName=property_name [-propertyValue=property_value]
	        -clientConfig : Save service client configuration to file (default: disabled)
	        -roleConfigGroup : Role config group name. If empty, list role config groups for a given service (default: disabled)
	        -propertyName : Configuration parameter name. Required for -updateConfig. Regex filter for -getConfig (default: all)
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
	      (diagData) Collect diagnostics data for YARN applications
	        -appId : Comma-separated list of application IDs
	        -ticketNumber : Cloudera Support ticket number (default: empty)
	        -comments : Comments to add to the support bundle (default: empty)
	 -confirmed : Proceed with command execution
	 -trackCmd : Wait for all asynchronous commands to end before exiting (default: disabled)
	 -download : Download command's downloadable result data, if any exists (enables -trackCmd, default: disabled)
	 -run : Alias for '-confirmed -trackCmd'
	 -sChecks : Service health checks
	 -sMetrics : Service metrics
	 -rChecks : Role health checks
	 -rMetrics : Role metrics
	 -log : Display role log (type: full, stdout, stderr /stacks, stacksBundle for mgmt service/)
	   -download : Save role log to file
	 -yarnApps : Display YARN applications (default: filter=empty, from=5_minutes, to=now, limit=100, offset=0)
	   -attributes : List of attributes that the Service Monitor can associate with YARN applications
	   -kill : Kill YARN application (-appId)
	 -impalaQueries : Display Impala queries (default: filter=empty, from=5_minutes, to=now, limit=100, offset=0)
	   -attributes : List of attributes that the Service Monitor can associate with Impala queries
	   -queryId : Return query details
	     -format : text (default) | thrift
	     -cancel : Cancel Impala query
	 -mgmt : Alias for '-s=mgmt', Cloudera Management Service (default: disabled)
```

**cmrest.pl**
```
Usage: cmrest.pl [-help] [-version] [-d] [-u[=username]] [-p[=password]] [-https] [-cm=hostname[:port]]
	[-noredirect] [-noauth] [-m=method] [-bt=body_type] [-bc=body_content [-i]] [-f=json_file] [-dumper] -r=rest_resource

	 -help : Display usage
	 -version : Display version information
	 -d : Enable debug mode
	 -u : CM username (environment variable: $CM_REST_USER | default: admin)
	 -p : CM password or path to password file (environment variable: $CM_REST_PASS | default: admin)
	      Credentials file: $HOME/.cm_rest (set env variables using colon-separated key/value pairs)
	 -https : Use HTTPS to communicate with CM (default: HTTP)
	 -cm : CM hostname:port (default: localhost:7180, or 7183 if using HTTPS)
	 -noredirect : Do not follow redirects
	 -noauth : Do not add Authorization header
	 -m : Method | GET, POST, PUT, DELETE (default: GET)
	 -bt : Body type | array, hash, json (default: hash)
	 -bc : Body content. Colon-separated list of property/value pairs for a single object (use ~ as delimiter in array properties if -bt=hash)
	       To set multiple objects, use -bt=json or -f to pass a JSON file
	 -i : Add the 'items' property to the body content (enabled by default if -bt=array)
	 -f : JSON file containing body content (implies -bt=json)
	 -dumper : Use Data::Dumper to output the JSON response content (default: disabled)
	 -r : REST resource|endpoint (example: /api/v15/clusters)
```

## Supported Cluster/Service/Role Commands

In addition to the actions listed in the usage section, to execute a command endpoint, set `-a={commandName}` in the appropriate context. These are the supported commands:

*Role actions*
- `/clusters/{clusterName}/services/{serviceName}/roleCommands/{commandName}`
- MGMT: `/cm/service/roleCommands/{commandName}`

*Service actions*
- All `/clusters/{clusterName}/services/{serviceName}/commands/{commandName}` endpoints that don't require *Request Body*, except the following supported commands:
  * `deployClientConfig`
  * `decommission`
  * `recommission`
  * `rollingRestart`
  * `yarnApplicationDiagnosticsCollection` (aliased by `diagData`)
- MGMT: `/cm/service/commands/{commandName}`

*Cluster actions*
- All `/clusters/{clusterName}/commands/{commandName}` endpoints that don't require *Request Body*.

## Cluster/Service/Role Output

<https://cloudera.github.io/cm_api/apidocs/v19/ns0_apiCluster.html>

`name | maintenanceMode >>> displayName (fullVersion) --- entityStatus`

<https://cloudera.github.io/cm_api/apidocs/v19/ns0_apiService.html>

`... | name | maintenanceMode | displayName --- serviceState healthSummary configStalenessStatus clientConfigStalenessStatus`

<https://cloudera.github.io/cm_api/apidocs/v19/ns0_apiRole.html>

`... | ... | hostId (hostname) | type | roleConfigGroupRef->roleConfigGroupName | maintenanceMode | commissionState | name --- roleState healthSummary configStalenessStatus` 

## Host Output

https://cloudera.github.io/cm_api/apidocs/v19/ns0_apiHost.html

`hostname | hostId | ipAddress | rackId | maintenanceMode | commissionState | clusterRef->clusterName --- healthSummary entityStatus`

## Command Output

https://cloudera.github.io/cm_api/apidocs/v19/ns0_apiCommand.html

`id | name | startTime | endTime | active | success | resultMessage | resultDataUrl | canRetry | clusterRef | serviceRef | roleRef | hostRef`

## How-To

* Show all managed hosts:

	`cmcli.pl -hInfo`

* Show hosts not associated with any cluster:

	`cmcli.pl -hInfo -c='No cluster'`

* Show hosts with no roles:

	`cmcli.pl -hInfo -s='No roles'`

* Show hosts assigned to the /default rack:

	`cmcli.pl -hInfo=/default`

* Assign them to rack /rack1:

	`cmcli.pl -hInfo=/default -setRackId=/rack1`

* Show information about a given host:

	`cmcli.pl -hInfo=host_name`

* Show role information:

	`cmcli.pl -hInfo=host_name -hRoles`

* Show hosts associated with a given cluster:

	`cmcli.pl -hInfo -c=cluster_name`

* Decommission hosts in bad health:

	`cmcli.pl -c=cluster_name -hFilter=bad -hAction=decommission`

* Show clusters and services:

	`cmcli.pl`

	`cmcli.pl -cm=cm_server_host`

* Show the Cloudera Management Service instances:

	`cmcli.pl -mgmt -rInfo`

	*or*

	`cmcli.pl -s=mgmt -rInfo`

* Deploy the client configuration of any service with stale status:

	`cmcli.pl -sFilter=stale -a=deployClientConfig`

* Restart the services with stale configuration:

	`cmcli.pl -sFilter=stale -a=restart`

* Show the roles of the HDFS service:

	`cmcli.pl -s=hdfs -rInfo`

    *To replace the host id (UUID) in the output with the host name, simply add `-hInfo`.*

* Show the DataNode instances:

	`cmcli.pl -s=hdfs -r=datanode`

* Show the stopped DataNodes:

	`cmcli.pl -s=hdfs -r=datanode -rFilter=stopped`

* Start the stopped DataNodes:

	`cmcli.pl -s=hdfs -r=datanode -rFilter=stopped -a=start`

    *To execute the action, use `-confirmed`. To check the command execution status, add `-trackCmd`. To do both, just use the `-run` alias instead.*

* Deploy the YARN client configuration at the service level:

	`cmcli.pl -s=yarn -a=deployClientConfig`

* Restart all the Flume services:

	`cmcli.pl -s=flume -a=restart`

* Restart the 'flume' service only:

	`cmcli.pl -s='flume$' -a=restart`

* Restart the 'hive2' and 'oozie1' services:

	`cmcli.pl -s='hive2|oozie1' -a=restart`

* Start all the roles on a given host:

	`cmcli.pl -hInfo=host_name -hAction=startRoles`

	*or*

	`cmcli.pl -hInfo=host_name -a=start`

* Decommission the NodeManager instance on a given host:

	`cmcli.pl -hInfo=host_name -r=nodemanager -a=decommission`

* Restart the DataNode instance on a given host:

	`cmcli.pl -hInfo=host_name -r=datanode -a=restart`
	
* Restart the agent of the 'flume2' service on a given host:

	`cmcli.pl -hInfo=host_name -s=flume2 -a=restart`

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
$ cmcli.pl -userAction ( ≡ cmcli.pl -userAction=show)
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
*`-userRole` is NOT case-sensitive. Check the list of [user roles](https://cloudera.github.io/cm_api/apidocs/v19/ns0_apiUser.html).*

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
$ cmcli.pl -userAction
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

	`cmcli.pl -hInfo=... -deleteHost`

* Remove the selected hosts from ANY cluster (if using API v11 or higher):

	`cmcli.pl -hInfo=... -removeFromCluster`

	*If using API v10 or lower, remove hosts from 'cluster1':*

	`cmcli.pl -hInfo=... -removeFromCluster=cluster1`

* Roll restart all the roles on the selected hosts:

 	`cmcli.pl -hInfo=... -a=rollingRestart`

* Roll restart the HBase roles on the selected hosts:

 	`cmcli.pl -hInfo=... -a=rollingRestart -s=hbase`

* Roll restart the NodeManager roles of the YARN service with extra options:

 	`cmcli.pl -s=yarn -a=rollingRestart -slaveBatchSize=3 -sleepSeconds=10 -restartRoleTypes=nodemanager`
    
	*`-restartRoleTypes` is NOT case-sensitive. Check the list of [role types](https://cloudera.github.io/cm_api/apidocs/v19/path__clusters_-clusterName-_services_-serviceName-_roles.html) or use `-s=... -a=roleTypes`.*
    
* Roll restart the ResourceManager roles:

 	`cmcli.pl -s=yarn -a=rollingRestart -restartRoleTypes=resourcemanager`

* Roll restart YARN roles with stale configs only:

 	`cmcli.pl -s=yarn -a=rollingRestart -staleConfigsOnly=true`

	*or*

 	`cmcli.pl -s=yarn -rFilter=stale -a=rollingRestart`

* Roll restart NameNode and JournalNode roles:

 	`cmcli.pl -s=hdfs -a=rollingRestart -restartRoleTypes=namenode,journalnode`

	*or*

 	`cmcli.pl -s=hdfs —r='name|journal' -a=rollingRestart`

* Roll restart all ZooKeeper and Flume services:

 	`cmcli.pl -s='zoo|flume' -a=rollingRestart`

* Multi-action command: Add hosts to cluster 'cluster1', set rack Id, create HIVESERVER2 and GATEWAY roles (service 'hive1') and enable maintenance mode on the hosts:

 	`cmcli.pl -hInfo=... -setRackId=/rack_id -addToCluster=cluster1 -addRole=hiveserver2,gateway -serviceName=hive1 -hAction=enterMaintenanceMode`

	*`-addRole` is NOT case-sensitive. Check the list of [role types](https://cloudera.github.io/cm_api/apidocs/v19/path__clusters_-clusterName-_services_-serviceName-_roles.html) or use `-s=... -a=roleTypes`.*

* Delete all the roles from a host:

	`cmcli.pl -hInfo=host_name -a=deleteRole`
	
	*(Follow-up multi-action command) Remove host from the cluster and from CM:*
	
	`cmcli.pl -hInfo=host_name -removeFromCluster -deleteHost`

* Delete the Hive GATEWAY role from a host:

	`cmcli.pl -hInfo=host_name -s=hive -r=gateway -a=deleteRole`

* Display the summary configuration of the 'flume1' service:

 	`cmcli.pl -s=flume1 -a=getConfig`

* Download the client configuration of all the Hive services:

 	`cmcli.pl -s=hive -a=getConfig -clientConfig`

* Display the role config groups of the HDFS service:

 	`cmcli.pl -s=hdfs -a=getConfig -roleConfigGroup`

* Display the full configuration of the default role config group:

 	`cmcli.pl -s=hdfs -a=getConfig -roleConfigGroup=hdfs1-DATANODE-BASE -full`
    
	*In addition to `name` and `value`, the full view output includes the `validateState`, `validateMessage` and `displayName` properties (see [apiConfig](https://cloudera.github.io/cm_api/apidocs/v19/ns0_apiConfig.html))*

* Update the 'dfs_data_dir_list' property:

 	`cmcli.pl -s=hdfs -a=updateConfig -roleConfigGroup=hdfs1-DATANODE-BASE -propertyName=dfs_data_dir_list -propertyValue=new_value`

* Override the 'dfs_data_dir_list' property on a given host:

 	`cmcli.pl -hInfo=host_name -r=datanode -a=updateConfig -propertyName=dfs_data_dir_list -propertyValue=new_value`

* Reset the 'dfs_data_dir_list' property on a given host to the config group value:

 	`cmcli.pl -hInfo=host_name -r=datanode -a=updateConfig -propertyName=dfs_data_dir_list`

* Move the DataNode role on a given host to a different config group:

   	`cmcli.pl -hInfo=host_name -r=datanode -a=moveToRoleGroup -roleConfigGroup=hdfs1-DATANODE-1`

* Move the DataNode role on a given host to the default config group:

	`cmcli.pl -hInfo=host_name -r=datanode -a=moveToBaseGroup`

* Update the Flume Agent configuration file of the default config group:

	`cmcli.pl -s=flume1 -a=updateConfig -roleConfigGroup=flume-AGENT-BASE -propertyName=agent_config_file -propertyValue="$(<flume1.conf)"`

	*NOTE: The `flume1.conf` text file must have newline characters escaped to avoid an error like the following:*

	```
	"message" : "Illegal unquoted character ((CTRL-CHAR, code 10)): has to be escaped using backslash to be included in string value
	at [Source: org.apache.cxf.transport.http.AbstractHTTPDestination$1@1874a9cf; line: 1, column: 98]"
	```

	*Here is an easy way to escape newline characters using a Perl one-liner:*

	`perl -npe "s/\n/\\\n/g" flume.conf > flume1.conf`

* Refresh the Flume Agents of the default config group to apply the new configuration file:

	`cmcli.pl -s=flume1 -roleConfigGroup=agent-base -rFilter=refreshable -a=refresh`

* List YARN applications (with complex filter) from a certain date until now and return a maximum of 50:

	`cmcli.pl -yarnApps='filter=(executing=false and user=mdom)&from=2020-06-06&limit=50'`

* Collect application logs for multiple jobs:

	`cmcli.pl -a=diagData -appId=job_1591424769429_0001,job_1591424769429_0002 -download`
