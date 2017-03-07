###Version 3.0 is now available!

The new release includes...
- Rolling restart of services and roles: `-a=rollingRestart`
- Delete hosts from Cloudera Manager: `-deleteHost`
- Remove hosts from clusters for API v10 or lower: `-removeFromCluster`
- Shortcut option (`-run`) for a commonly used combination of switches (namely, `-confirmed -trackCmd`)
- Code enhancements regarding host management
- Minor changes to improve code debugging and readability

Note: Regarding `-removeFromCluster`, this feature was already available in version 2.0 for API v11 via `-hAction=removeFromCluster`. The difference between these two options is that the latter automatically gets the cluster name from `apiHost->clusterRef->clusterName`, whereas the former requires the cluster name to be manually set. Both options will be merged in the next release.

Examples:

* Delete the selected hosts from CM:

    `cmcli.pl -cm=cm_server -hInfo=<perl_regex> -deleteHost`

* Remove the selected hosts from 'cluster2' (if using API v10 or lower):

    `cmcli.pl -cm=cm_server -hInfo=<perl_regex> -removeFromCluster=cluster2`

    If using API v11 or higher, remove hosts from ANY cluster:

    `cmcli.pl -cm=cm_server -hInfo=<perl_regex> -hAction=removeFromCluster`

* Roll restart ALL the roles on the selected hosts:

    `cmcli.pl -cm=cm_server -hInfo=<perl_regex> -a=rollingRestart`

* Roll restart the HBase roles on the selected hosts:

    `cmcli.pl -cm=cm_server -hInfo=<perl_regex> -a=rollingRestart -s=hbase`

* Roll restart the NodeManager roles of the YARN service of 'cluster2' with extra options:

    `cmcli.pl -cm=cm_server -c=cluster2 -s=yarn -a=rollingRestart -slaveBatchSize=3 -sleepSeconds=10 -restartRoleTypes=nodemanager`
    
    `-restartRoleTypes` *is NOT case-sensitive. Check the list of role types [here](https://cloudera.github.io/cm_api/apidocs/v15/path__clusters_-clusterName-_services_-serviceName-_roles.html).*
    
* Roll restart the ResourceManager roles:

    `cmcli.pl -cm=cm_server -c=cluster2 -s=yarn -a=rollingRestart -restartRoleTypes=resourcemanager`

* Roll restart YARN roles with stale configs only:

    `cmcli.pl -cm=cm_server -c=cluster2 -s=yarn -a=rollingRestart -staleConfigsOnly=true`

    *or*

    `cmcli.pl -cm=cm_server -c=cluster2 -s=yarn -rFilter=stale -a=rollingRestart`

* Roll restart NameNode and JournalNode roles:

    `cmcli.pl -cm=cm_server -c=cluster2 -s=hdfs -a=rollingRestart -restartRoleTypes=namenode,journalnode`

    *or*

    `cmcli.pl -cm=cm_server -c=cluster2 -s=hdfs —r='name|journal' -a=rollingRestart`

* Roll restart ALL ZooKeeper and Flume services:

    `cmcli.pl -cm=cm_server -c=cluster2 -s='zoo|flume' -a=rollingRestart`

### ---

## Synopsis

AUTHOR: Mariano Dominguez, <marianodominguez@hotmail.com>

VERSION: 3.0

BUGS: Please report bugs to <marianodominguez@hotmail.com>

The Cloudera Manager CLI (`cmcli.pl`) is a utility that facilitates cluster management and automation from the command-line through the Cloudera Manager REST API.

It is compatible with Cloudera Manager 5.x (API v6 or higher). Most of the functionality should also work (not fully tested) with Cloudera Manager 4.x (API v5 or lower), although you may see `Use of uninitialized value...` messages and/or failures.

A separate REST client (`cmapi.pl`) is provided to call the endpoints not supported by the CLI.

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

These utilities are written in Perl and have been tested using Perl 5.1x.x on RHEL 6.x.

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

Then, add the following line to the code:

`use lib qw(<PREFIX>/share/perl5/);`

## Usage

The only mandatory option for `cmcli.pl` is `-cm` to reference the CM server host, whereas `cmapi.pl` requires `<ResourceUrl>`.

Here is the usage information for both utilities:

```
Usage: ./cmcli.pl [-help] [-version] [-d] -cm[=hostname[:port] [-https] [-api[=v<integer>]] [-u=username] [-p=password]
	[-cmVersion] [-config] [-deployment] [-cmdId=command_id [-cmdAction=abort|retry] [-trackCmd]]
	[-users[=user_name] [-userAction=delete|(add|update -f=json_file)]]
	[-hInfo[=...] [-hFilter=...] [-hRoles] [-hChecks] [-setRackId=/...|-deleteHost] \
		[(-addToCluster|-removeFromCluster)=cluster_name] [-hAction=command_name]]
	[-c=cluster_name] [-s=service_name [-sChecks] [-sMetrics]]
	[-rInfo[=host_id] [-r=role_type|role_name] [-rFilter=...] [-rChecks] [-rMetrics] [-log=log_type]]
	[-a[=command_name]] [[-confirmed [-trackCmd]]|-run]
	[-yarnApps[=parameters]]
	[-impalaQueries[=parameters]]
	[-mgmt] (<> -s=mgmt)

	 -help : Display usage
	 -version : Display version information
	 -d : Enable debug mode
	 -cm : CM hostname:port (default: localhost:7180)
	 -https : Use https to communicate with CM (default: http)
	 -api : CM API version -> v<integer> (default: response from <cm>/api/version)
	 -u : CM username (environment variable: $CM_REST_USER | default: admin)
	 -p : CM password or path to password file (environment variable: $CM_REST_PASS | default: admin)
	      *Credendials file* $HOME/.cm_rest -> Set variables using colon-separated key/value pairs
	 -cmVersion : Display Cloudera Manager and default API versions
	 -users : Display CM users/roles (default: all)
	 -userAction: User action
	              (add) Create user (requires -f)
	              (update) Update user (requires -f)
	              (delete) Delete user
	 -f: JSON file with user information
	 -config : Dump configuration to file (CM, Cloudera Management Service and, if -s is set, specific services)
	 -deployment : Retrieve full description of the entire CM deployment
	 -cmdId : Retrieve information on an asynchronous command
	 -cmdAction : Command action
	            (abort) Abort a running command
	            (retry) Try to rerun a command
	 -hInfo : Host information (regex UUID, hostname, IP, rackId, cluster) | default: all)
	 -hFilter : Host health summary, entity status, maintenance mode, commission state (regex)
	 -hRoles : Roles associated to host
	 -hChecks : Host health checks
	 -setRackId : Update the rack ID for the host
	 -deleteHost : Delete the host from Cloudera Manager
	 -addToCluster : Add the host to a cluster
	 -removeFromCluster : Remove the host from a cluster /compatible with API v10 or lower, implies -hAction=removeFromCluster/
	 -hAction : Host action
	            (decommission|recommission) Decommission/recommission the host
	            (startRoles) Start all the roles on the host
	            (enterMaintenanceMode) Put the host into maintenance mode
	            (exitMaintenanceMode) Take the host out of maintenance mode
	            (removeFromCluster) Remove the host from a cluster /compatible with API v11 or higher, gets clusterRef->clusterName from apiHost/
	 -c : Cluster name
	 -s : Service name (regex)
	 -r : Role type/name (regex)
	 -rInfo : Role information (regex UUID or set -hInfo | default: all)
	 -rFilter : Role state, health summary, configuration status, commission state (regex)
	 -a : Cluster/service/role action (default: -cluster/service- list active commands, -role- no action)
	      (stop|start|restart|...)
	      (deployClientConfig) Deploy cluster-wide/service client configuration
	      (decommission|recommission) Decommission/recommission roles of a service
	      (rollingRestart) Rolling restart of roles in a service. Optional arguments:
	      -restartRoleTypes : Comma-separated list of role types to restart. If not specified, all startable roles are restarted (default: all)
	      -slaveBatchSize : Number of hosts with slave roles to restart at a time (default: 1)
	      -sleepSeconds : Number of seconds to sleep between restarts of slave host batches (default: 0)
	      -slaveFailCountThreshold : Number of slave host batches that are allowed to fail to restart before the entire command is considered failed (default: 0)
	      -staleConfigsOnly : Restart roles with stale configs only (default: false)
	      -unUpgradedOnly : Restart roles that haven't been upgraded yet (default: false)
	 -confirmed : Proceed with the command execution
	 -trackCmd : Display the result of all executed asynchronous commands before exiting
	 -run : Shortcut for '-confirmed -trackCmd'
	 -sChecks : Service health checks
	 -sMetrics : Service metrics
	 -rChecks : Role health checks
	 -rMetrics : Role metrics
	 -log : Display role log (type: full, stdout, stderr -stacks, stacksBundle for mgmt service-)
	 -yarnApps : Display YARN applications (example: -yarnApps='filter='executing=true'')
	 -impalaQueries : Display Impala queries (example: -impalaQueries='filter='user=<userName>'')
	 -mgmt (-s=mgmt) : Cloudera Management Service information (default: disabled)
```
```
Usage: ./cmapi.pl [-help] [-version] [-d] [-u=username] [-p=password]
	[-m=method] [-bt=body_type] [-bc=body_content [-i]] [-f=json_file] <ResourceUrl>

	 -help : Display usage
	 -version : Display version information
	 -d : Enable debug mode
	 -u : CM username (environment variable: $CM_REST_USER | default: admin)
	 -p : CM password or path to password file (environment variable: $CM_REST_PASS | default: admin)
	      *Credendials file* $HOME/.cm_rest -> Set variables using colon-separated key/value pairs
	 -m : Method | GET, POST, PUT, DELETE (default: GET)
	 -bt : Body type | array, hash, json (default: hash)
	 -bc : Colon-separated list of property/value pairs for a single object (use ~ as delimiter in array properties if -bt=hash)
	       To set multiple objects, use -bt=json or -f to pass a JSON file
	 -i : Add 'items' property to the body content (on by default if -bt=array)
	 -f : JSON file containing body content (implies -bt=json)
	 <ResourceUrl> : URL to REST resource (example: [http(s)://]cloudera-manager:7180/api/v15/clusters/)
```

## Setting credentials

CM credentials can be passed by using the `-u` (username) and `-p` (password) options. The `-p` option can be set to the password string itself (**not recommended**) or to a file containing the password:

`$ cmcli.pl -u=username -p=/path/to/password_file -cm=...`

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

## Suported cluster/service/role actions

For a complete list, go to https://cloudera.github.io/cm_api/ and click on **Full API Docs**.

Role actions:
- `/clusters/{clusterName}/services/{serviceName}/roleCommands/{commandName}`
- `/cm/service/roleCommands/{commandName}`

Service actions:
- All `/clusters/{clusterName}/services/{serviceName}/commands/{commandName}` endpoints that don't require *Request Body*, except the following supported commands:
  * `deployClientConfig`
  * `decommission`
  * `recommission`
  * `rollingRestart`
- `/cm/service/commands/{commandName}`

Cluster actions:
- All `/clusters/{clusterName}/commands/{commandName}` endpoints that don't require *Request Body*.

## Cluster/Service/Role output

<https://cloudera.github.io/cm_api/apidocs/v15/ns0_apiCluster.html>

`name >>> displayName (CDH fullVersion) --- entityStatus`

<https://cloudera.github.io/cm_api/apidocs/v15/ns0_apiService.html>

`... | name | displayName --- serviceState healthSummary configStalenessStatus clientConfigStalenessStatus`

<https://cloudera.github.io/cm_api/apidocs/v15/ns0_apiRole.html>

`... | ... | hostId (hostname) | type | commissionState | name --- roleState healthSummary configStalenessStatus` 

## Host output

https://cloudera.github.io/cm_api/apidocs/v15/ns0_apiHost.html

`hostname | hostId | ipAddress | rackId | maintenanceMode | commissionState | clusterRef --- healthSummary entityStatus`

## Command output

https://cloudera.github.io/cm_api/apidocs/v15/ns0_apiCommand.html

`id | name | startTime | endTime | active | success | resultMessage | resultDataUrl | canRetry | clusterRef | serviceRef | roleRef | hostRef`

## How-To

Here are some common use cases:

* Show all managed hosts:

    `$ cmcli.pl -cm=cm_server -hInfo`

* Show hosts not associated to any cluster:

    `$ cmcli.pl -cm=cm_server -hInfo -c='No cluster'`

* Show hosts with no roles:

    `$ cmcli.pl -cm=cm_server -hInfo -s='No roles'`

* Show hosts assigned to the /default rack:

    `$ cmcli.pl -cm=cm_server -hInfo=/default`

* Assign them to rack /rack1:

    `$ cmcli.pl -cm=cm_server -hInfo=/default -setRackId=/rack1`

* Show information about a given host:

    `$ cmcli.pl -cm=cm_server -hInfo=host_name`

* Show role information:

    `$ cmcli.pl -cm=cm_server -hInfo=host_name -hRoles`

* Show all the hosts associated to a given cluster:

    `$ cmcli.pl -cm=cm_server -hInfo -c=cluster_name`

* Decommission the hosts in bad health:

    `$ cmcli.pl -cm=cm_server -c=cluster_name -hFilter=bad -hAction=decommission`

* Show clusters and services:

    `$ cmcli.pl -cm=cm_server`

* Show the Cloudera Management Service instances:

    `$ cmcli.pl -cm=cm_server -mgmt -rInfo`

    *or*

    `$ cmcli.pl -cm=cm_server -s=mgmt -rInfo`

* Show the roles of the HDFS service of 'cluster2':

    `$ cmcli.pl -cm=cm_server -c=cluster2 -s=hdfs -rInfo`

    *To replace the host id (UUID) in the output with the host name, simply add* `-hInfo`.

* Show the DataNode instances:

    `$ cmcli.pl -cm=cm_server -c=cluster2 -s=hdfs -r=datanode`

* Show the stopped DataNodes:

    `$ cmcli.pl -cm=cm_server -c=cluster2 -s=hdfs -r=datanode -rFilter=stopped`

* Start the stopped DataNodes:

    `$ cmcli.pl -cm=cm_server -c=cluster2 -s=hdfs -r=datanode -rFilter=stopped -a=start`

    *To execute the action, use* `-confirmed`. *To check the command execution status, add* `-trackCmd`. *To do both, just use the* `-run` *shortcut instead.*

* Deploy the YARN client configuration at the service level:

    `$ cmcli.pl -cm=cm_server -c=cluster2 -s=yarn -a=deployClientConfig`

* Restart ALL the Flume services:

    `$ cmcli.pl -cm=cm_server -c=cluster2 -s=flume -a=restart`

* Restart the 'flume' service only:

    `$ cmcli.pl -cm=cm_server -c=cluster2 -s='flume$' -a=restart` --> using regex

* Restart the 'hive2' and 'oozie1' services:

    `$ cmcli.pl -cm=cm_server -c=cluster2 -s='hive2|oozie1' -a=restart` --> using regex

* Start all the roles on a given host:

    `$ cmcli.pl -cm=cm_server -hInfo=host_name -hAction=startRoles`

    *or*

    `$ cmcli.pl -cm=cm_server -hInfo=host_name -a=start`

* Decommission the NodeManager instance on a given host:

    `$ cmcli.pl -cm=cm_server -hInfo=host_name -r=nodemanager -a=decommission`

* Restart the DataNode instance on a given host:

    `$ cmcli.pl -cm=cm_server -hInfo=host_name -r=datanode -a=restart`
	
* Restart the agent of the 'flume2' service on a given host:

    `$ cmcli.pl -cm=cm_server -hInfo=host_name -s=flume2 -a=restart`

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
$ cmcli.pl -cm=cm_server -users -userAction=add -f=users.json
Adding users from file users.json...
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
$ cmcli.pl -cm=cm_server -users
admin : ROLE_ADMIN
user1 : ROLE_USER
user2 : ROLE_USER
user3 : ROLE_CONFIGURATOR
user4 : ROLE_OPERATOR
```

* Change password and role for user1:

```
$ cat user1.json 
{
    "password" : "mypassword",
    "roles" : [ "ROLE_ADMIN" ]
}
$ cmcli.pl -cm=cm_server -users=user1 -userAction=update -f=user1.json 
Updating user user1...
{
  "name" : "user1",
  "roles" : [ "ROLE_ADMIN" ]
}
```

* Delete user4:

```
$ cmcli.pl -cm=cm_server -users=user4 -userAction=delete
Deleting user user4...
{
  "name" : "user4",
  "roles" : [ "ROLE_OPERATOR" ]
}
$ cmcli.pl -cm=cm_server -users 
admin : ROLE_ADMIN
user1 : ROLE_ADMIN
user2 : ROLE_USER
user3 : ROLE_CONFIGURATOR
```
