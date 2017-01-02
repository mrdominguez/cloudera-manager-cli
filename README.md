# cloudera-manager-cli
Cloudera Manager command-line interface.

Work in progress... The code and documentation will be posted in the near future.

Here is a preview of the available command options:
```
Usage: ./cmcli.pl [-h] [-d] [-api] -cm[=hostname[:port]] [-u=username] [-p=password]
	[-cmVersion] [-config] [-deployment] [-cmdId=command_id -cmdAction=(abort|retry)]
	[-hInfo[=...] [-hRoles] [-hChecks]]
	[-c=cluster] [-s=service] [-r=role_type] [-rInfo=[host_id]] [-rFilter=...]
	[-a[=action [-confirmed] [-trackCmd]]
	[-sChecks] [-sMetrics] [-rChecks] [-rMetrics]
	[-deployClientConfig]
	[-log=log_type]
	[-yarnApps[=parameters]]
	[-mgmt (<> -s=mgmt)

	 -h : Display usage
	 -d : Enable debug mode
	 -api : CM API version with format 'v<integer>' (default: response from <cm>/api/version)
	 -cm : CM host name:port (default: localhost:7180)
	 -u : CM username (environment variable: $CM_REST_USER | default: admin)
	 -p : CM password or path to password file (environment variable: $CM_REST_PASS | default: admin)
	      *Credendials file* /Users/mdom/.cm_rest -> Set variables using colon-separated key/value pairs
	 -cmVersion : Display Cloudera Manager version
	 -config : Dump configuration to file (CM, Cloudera Management Service and, if -s is set, specific services)
	 -deployment : Retrieve full description of the entire CM deployment
	 -cmdId : Display information on an asynchronous command
	 -cmdAction : (abort) Abort a running command | (retry) Try to rerun a command
	 -hInfo : Display host information (regex UUID, hostname, IP, rackId, health summary, cluster) | default: all)
	 -hRoles : Display roles associated to host
	 -hChecks : Display host health checks
	 -c : Cluster name
	 -s : Service name (regex)
	 -r : Role type/name (regex)
	 -rInfo : Display role information (regex UUDI or set -hInfo | default: all)
	 -rFilter : Role state, health summary, configuration status (regex)
	 -a : Cluster/service/role action (stop, start, restart, etc. | default: -cluster/services- list active commands, -roles- no action)
	 -confirmed : Proceed with the command execution
	 -trackCmd : Display the result of all executed asynchronous commands before exiting (TODO)
	 -sChecks : Display service health checks
	 -sMetrics : Display service metrics
	 -rChecks : Display role health checks
	 -rMetrics : Display role metrics
	 -deployClientConfig : Deploy cluster-wide/service client configuration
	 -log : Display role log (role type: full, stdout, stderr)
	 -yarnApps : Display YARN applications (example: -yarnApps='filter='executing=true'')
	 -impalaQueries : Display Impala queries (TODO)
	 -mgmt (-s=mgmt) : Display Cloudera Management Service information (default: disabled)
```

Additionally, I have created a separate all-purpose REST client to interact with the Cloudera Manager API:
```
Usage: ./cmapi.pl [-h] [-d] [-u=username] [-p=password]
	[-m=method] [-bt=body_type] [-bc=body_content [-i]] [-f=json_file] ResourceUrl

	 -h : Display usage
	 -d : Enable debug mode
	 -u : CM username (environment variable: $CM_REST_USER | default: admin)
	 -p : CM password or path to password file (environment variable: $CM_REST_PASS | default: admin)
	      *Credendials file* /Users/mdom/.cm_rest -> Set variables using colon-separated key/value pairs
	 -m : Method | GET, POST, PUT, DELETE (default: GET)
	 -bt : Body type | array, hash, json (default: hash)
	 -bc : Colon-separated list of property/value pairs for a single object (use ~ as delimiter in array properties if -bt=hash)
	       To set multiple objects, use -bt=json or -f to pass a JSON file
	 -i : Add 'items' property to the body content (on by default if -bt=array)
	 -f : JSON file containing body content (implies -bt=json)
	 ResourceUrl : URL to REST resource (example: [http://]cloudera-manager:7180/api/v10/clusters/)
```


