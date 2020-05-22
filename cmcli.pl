#!/usr/bin/perl -ws

# Copyright 2020 Mariano Dominguez
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Cloudera Manager Command-Line Interface
# Use -help for options

use strict;
use warnings;
use REST::Client;
use MIME::Base64;
use JSON;
use Data::Dumper;
#use YAML;

BEGIN { $| = 1 }

use vars qw($help $version $d $cmVersion $userAction $f $userName $userPassword $userRole $https $api $sChecks $sMetrics $rChecks $rMetrics $cmConfig $u $p $cm
	$c $s $r $rInfo $rFilter $sFilter $yarnApps $log $a $confirmed $cmdId $cmdAction $hInfo $hFilter $hRoles $hChecks $deployment
	$mgmt $impalaQueries $trackCmd $setRackId $deleteHost $addToCluster $removeFromCluster $addRole $serviceName $clusterName
	$hAction $run $maintenanceMode $roleConfigGroup $propertyName $propertyValue $clientConfig $full $displayName $fullVersion $serviceType $roleType
	$slaveBatchSize $sleepSeconds $slaveFailCountThreshold $staleConfigsOnly $unUpgradedOnly $restartRoleTypes $copyFromRoleGroup);

if ( $version ) {
	print "Cloudera Manager Command-Line Interface\n";
	print "Author: Mariano Dominguez\n";
	print "Version: 8.2.6\n";
	print "Release date: 05/22/2020\n";
	exit;
}

&usage if $help;

my %opts = ('cmdAction'=>$cmdAction, 'c'=>$c, 's'=>$s, 'r'=>$r, 'rFilter'=>$rFilter, 'sFilter'=>$sFilter, 'userAction'=>$userAction,
	'hFilter'=>$hFilter, 'log'=>$log, 'setRackId'=>$setRackId, 'addToCluster'=>$addToCluster, 'hAction'=>$hAction,
	'addRole'=>$addRole, 'serviceName'=>$serviceName, 'clusterName'=>$clusterName, 'displayName'=>$displayName,
	'fullVersion'=>$fullVersion, 'serviceType'=>$serviceType, 'roleType'=>$roleType, 'copyFromRoleGroup'=>$copyFromRoleGroup,
	'f'=>$f, 'userName'=>$userName, 'userPassword'=>$userPassword, 'userRole'=>$userRole, 'propertyName'=>$propertyName, 'propertyValue'=>$propertyValue);
my %hInfo_opts = ('hRoles'=>$hRoles, 'hChecks'=>$hChecks, 'setRackId'=>$setRackId, 'deleteHost'=>$deleteHost,
		'addToCluster'=>$addToCluster, 'removeFromCluster'=>$removeFromCluster, 'hAction'=>$hAction, 'addRole'=>$addRole);
my %rr_opts = ('slaveBatchSize'=>$slaveBatchSize, 'sleepSeconds'=>$sleepSeconds, 'slaveFailCountThreshold'=>$slaveFailCountThreshold,
		'staleConfigsOnly'=>$staleConfigsOnly, 'unUpgradedOnly'=>$unUpgradedOnly, 'restartRoleTypes'=>$restartRoleTypes, 'restartRoleNames'=>undef);
my %cluster_opts = ('c'=>$c, 'clusterName'=>$clusterName, 'displayName'=>$displayName, 'fullVersion'=>$fullVersion);
my %service_opts = ('c'=>$c, 's'=>$s, 'serviceName'=>$serviceName, 'displayName'=>$displayName, 'serviceType'=>$serviceType);
my %role_group_opts = ('c'=>$c, 's'=>$s, 'displayName'=>$displayName, 'roleType'=>$roleType, 'roleConfigGroup'=>$roleConfigGroup, 'copyFromRoleGroup'=>$copyFromRoleGroup);
my %user_opts = ('f'=>$f, 'userName'=>$userName, 'userPassword'=>$userPassword, 'userRole'=>$userRole);

foreach ( keys %opts ) {
	die "-$_ is not set\n" if ( $opts{$_} && $opts{$_} eq '1' ) }
unless ( $hInfo ) {
	foreach ( keys %hInfo_opts ) {
		die "-$_ requires -hInfo\n" if $hInfo_opts{$_} } }
unless ( $s || $hInfo ) {
	foreach ( keys %rr_opts ) {
		die "-$_ requires -s or -hInfo\n" if $rr_opts{$_} } }

if ( $userAction ) {
	die "User action '$userAction' not supported. Use -help for options\n" if $userAction !~ /show|add|update|delete/;
	die "Set -f or -userName\n" if ( $userAction eq 'add' && !$f && !$userName );
	die "Set -userName\n" if ( $userAction !~ /show|add/ && !$userName );
	die "Set -userPassword and/or -userRole\n" if ( $userAction eq 'update' && !$userPassword && !$userRole );
} else {
	foreach ( keys %user_opts ) {
		die "-$_ requires -userAction\n" if $user_opts{$_} }
}

if ( $cmdAction ) {
	die "-cmdAction requires -cmdId\n" if !$cmdId;
	die "Command action '$cmdAction' not supported. Use -help for options\n" if $cmdAction !~ /abort|retry/;
}

if ( $hAction && $hAction !~ /decommission|recommission|startRoles|enterMaintenanceMode|exitMaintenanceMode/ ) {
	die "Host action '$hAction' not supported. Use -help for options\n" }
if ( $trackCmd && !$a && !$cmdId && !$hAction ) {
	die "-trackCmd requires -a, -cmdId or -hAction\n" }
die "-sChecks and -sMetrics require -s\n" if ( ( $sChecks || $sMetrics ) && !$s );
die "Set -maintenanceMode to YES/NO\n" if ( $maintenanceMode && $maintenanceMode !~ /1|YES|NO/ );
if ( $a ) {
	if ( $a =~ /createRoleGroup|updateRoleGroup|deleteRoleGroup/ ) {
		foreach ( sort keys %role_group_opts ) {
			next if ( $a eq 'createRoleGroup' && $_ =~ /roleConfigGroup|copyFromRoleGroup/ );
			if ( $a eq 'updateRoleGroup' ) {
				die "Set -displayName and/or -copyFromRoleGroup\n" unless ( $displayName || $copyFromRoleGroup );
				next if $_ eq 'displayName' && $copyFromRoleGroup;
				next if $_ eq 'copyFromRoleGroup' && $displayName;
				next if $_ eq 'roleType';
			}
			next if ( $a eq 'deleteRoleGroup' && $_ !~ /^(c|s|roleConfigGroup)$/ );
			die "Set -$_\n" unless $role_group_opts{$_};
		}
	}
	die "Set -roleConfigGroup to an existing config group\n" if ( $a eq 'moveToRoleGroup' && !$roleConfigGroup );
	die "Set -roleConfigGroup to an existing config group\n" if ( $a eq 'updateConfig'
									&& $roleConfigGroup
									&& $roleConfigGroup eq '1' );
	if ( $a eq 'updateConfig' && !$propertyName ) {
		die "Set -propertyName to a valid property name. If -propertyValue is absent, the default value (if any) will be used\n" }
	if ( $a =~ /addCluster|updateCluster|deleteCluster/ ) {
		foreach ( sort keys %cluster_opts ) {
			next if ( ( ( $a eq 'deleteCluster' ) || ( $a eq 'updateCluster' && $fullVersion ) ) && $_ eq 'displayName' );
			next if ( ( ( $a eq 'deleteCluster' ) || ( $a eq 'updateCluster' && $displayName ) ) && $_ eq 'fullVersion' );
			if ( $a eq 'addCluster' ) {
				next if $_ eq 'c';
			} else {
				next if $_ eq 'clusterName';
			}
			die "Set -$_\n" unless $cluster_opts{$_};
		}
	}
	if ( $a =~ /addService|updateService|deleteService/ ) {
		foreach ( sort keys %service_opts ) {
			next if ( $a eq 'updateService' && $_ =~ /serviceName|serviceType/ );
			next if ( $a eq 'deleteService' && $_ !~ /^(c|s)$/ );
			next if ( $a eq 'addService' && $_ eq 's' );
			die "Set -$_\n" unless $service_opts{$_};
		}
	}
}

($confirmed, $trackCmd) = (1, 1) if $run;
$s = 'mgmt' if $mgmt;
$s = '^yarn' if ( $yarnApps && !$s );
$s = '^impala' if ( $impalaQueries && !$s );

my $cm_cred_file = "$ENV{'HOME'}/.cm_rest";
print "Credentials file $cm_cred_file " if $d;
if ( -e $cm_cred_file ) {
	print "found\n" if $d;
	open my $fh, '<', $cm_cred_file || die "Can't open file $cm_cred_file: $!";
	my @cm_cred = grep /CM_REST_/, <$fh>;
	foreach ( @cm_cred ) {
		# colon-separated key/value pair
#		chomp;
#		my ($env_var, $env_val) = split /:/, $_, 2;
		# quote credentials containing white spaces and use the -u/-p options or the environment variables instead of the credentials file
		my ($env_var, $env_val) = $_ =~ /([^\s]+)\s*:\s*([^\s]+)/;
		$ENV{$env_var} = $env_val if ( defined $env_var && defined $env_val );
	}
	close $fh;
} else {
	print "not found\n" if $d;
}

my $cm_user = $u || $ENV{'CM_REST_USER'} || 'admin';
print "username = $cm_user\n" if $d;

my $cm_password = $p || $ENV{'CM_REST_PASS'} || 'admin';
print "Password file $cm_password " if $d;
if ( -e $cm_password ) {
	print "found\n" if $d;
	$cm_password = qx/cat $cm_password/ || die "Can't get password from file $cm_password\n";
	chomp($cm_password);
} else {
	print "not found\n" if $d;
}

my $headers = { 'Content-Type' => 'application/json', 'Authorization' => 'Basic ' . encode_base64($cm_user . ':' . $cm_password) };
my $body_content;

my $cm_protocol = $https ? 'https' : 'http';
my ($cm_host, $cm_port) = split(/:/, $cm, 2) if ( $cm && $cm ne '1' );
$cm_host = 'localhost' unless $cm_host;
unless ( $cm_port ) {
	$cm_port = $https ? 7183 : 7180
}
print "CM protocol = $cm_protocol\nCM host = $cm_host\nCM port = $cm_port\n" if $d;

# http://search.cpan.org/dist/libwww-perl/lib/LWP.pm
# LWP::Protocol::https::Socket: SSL connect attempt failed error:14090086:SSL routines:ssl3_get_server_certificate:certificate verify failed
#$ENV{PERL_LWP_SSL_VERIFY_HOSTNAME}=0 if $https; # disable hostname verification

# http://search.cpan.org/~kkane/REST-Client/lib/REST/Client.pm
my $client = REST::Client->new();
if ( $https ) {
	# http://search.cpan.org/~ether/libwww-perl/lib/LWP/UserAgent.pm#CONSTRUCTOR_METHODS
	$client->getUseragent()->ssl_opts( verify_hostname => 0 ); # or set $ENV{PERL_LWP_SSL_VERIFY_HOSTNAME}
}

my $cm_url = "$cm_protocol://$cm_host:$cm_port/api/version";
my $api_version;
if ( $cmVersion || !$api ) {
	print "Getting API version from CM... " if $d;
	$api_version = &rest_call('GET', $cm_url, 1);
} else {
	$api_version = $api;
}
$api_version = ($api_version =~ /v(\d+)/) ? $1 : die "Invalid API version format: $api_version";
print "API version = $api_version\n" if $d;

die "-yarnApps is only available since API v6\n" if ( $api_version < 6 && $yarnApps );
die "-impalaQueries is only available since API v4\n" if ( $api_version < 4 && $impalaQueries );

if ( $addRole ) {
	die "-addRole requires -serviceName\n" unless $serviceName;
	die "Set -clusterName for API v10 or lower, or set -addToCluster if the host is not associated with any cluster yet\n" if ( $api_version < 11 && !$clusterName && !$addToCluster );
	$addRole =~ s/\s+//g;
	$addRole = uc $addRole;
} 

my $cm_api = "$cm_protocol://$cm_host:$cm_port/api/v$api_version";
if ( $cmVersion ) {
	$cm_url = "$cm_api/cm/version";
	my $cm_version = &rest_call('GET', $cm_url, 1);
	print "CM version: $cm_version->{'version'} (API: v$api_version)\n";
	exit;
}

if ( $userAction ) {
	die "Set -api=v19 (currently v$api_version) and rerun user action '$userAction'\n" if ( $api_version > 19 && $userAction =~ /add|update/ );
	$cm_url = "$cm_api/users";
	my $method;
	if ( $userAction eq 'show' || $confirmed ) {
		my $user_info = {};
		$user_info->{'name'} = $userName if $userName;
		$user_info->{'password'} = $userPassword if $userPassword;
		$user_info->{'password'} = 'changeme' if ( $userAction eq 'add' && !$userPassword );
		push @{$user_info->{'roles'}}, uc $userRole if $userRole;
		$body_content = to_json($user_info);
		$cm_url .= "/$userName" unless $userAction eq 'add' || ( $userAction eq 'show' && !$userName );
		if ( $userAction eq 'add') {
			if ( $f ) {
				print "Loading file $f...\n";
				$body_content = do {
					local $/ = undef;
					open my $fh, "<", $f || die "Can't open file $f: $!\n";
					<$fh>;
				};
			} elsif ( $userName ) {
				print "Adding user '$userName'...\n";
				$body_content = "{ \"items\" : [ $body_content ] }"
			}
			$method = 'POST';
		} elsif ( $userAction eq 'update' ) {
			print "Updating user '$userName'...\n";
			$method = 'PUT';
		} elsif ( $userAction eq 'delete' ) {
			print "Deleting user '$userName'...\n";
			$method = 'DELETE';
		} elsif ( $userAction eq 'show' ) {
			$method = 'GET';
			my $user_list = &rest_call($method, $cm_url, 1);
			if ( !$userName ) {
				for ( my $i=0; $i < @{$user_list->{'items'}}; $i++ ) {
					my $user_name = $user_list->{'items'}[$i]{'name'};
					print "$user_name\n";
					if ( $api_version <= 19 ) {
						my $user_roles = $user_list->{'items'}[$i]{'roles'};
						print @$user_roles ? " @$user_roles" : " No roles assigned";
					} else {
						foreach my $role ( @{$user_list->{'items'}[$i]{'authRoles'}} ) {
							my $user_role = $role->{'name'};
							print " $user_role";
						}
						print " No roles assigned" if !@{$user_list->{'items'}[$i]{'authRoles'}};
					}
					print "\n";
				}
			} else {
				my $user_name = $user_list->{'name'};
				print "$user_name\n";
				if ( $api_version <= 19 ) {
					my $user_roles = $user_list->{'roles'};
					print @$user_roles ? " @$user_roles" : " No roles assigned";
				} else {
					foreach my $role ( @{$user_list->{'authRoles'}} ) {
						my $user_role = $role->{'name'};
						print " $user_role";
					}
					print " No roles assigned" if !@{$user_list->{'authRoles'}};
				}
				print "\n";
			}
			exit;
		}
		$userAction eq 'delete' ? &rest_call($method, $cm_url, 0) : &rest_call($method, $cm_url, 0, undef, $body_content);
	} else {
		print "# Use -confirmed to execute user action '$userAction'";
		print " : '$userName'" if $userName;
		print "\n";
	}
	exit;
}
	

if ( $cmConfig || $deployment ) {
	my $filename;
	if ( $cmConfig ) {
		print "Retrieving Cloudera Manager settings...\n";
		$cm_url = "$cm_api/cm/config?view=full";
		$filename = "$cm_host\_cm\_config.json";
	} else {
		print "Retrieving full description of the entire CM deployment...\n";
		$cm_url = "$cm_api/cm/deployment";
		$filename = "$cm_host\_cm\_deployment.json";
	}
	&rest_call('GET', $cm_url, 2, $filename);
	print "Saved to $filename\n";
	exit;
}

my $cmd_list;
if ( $cmdId ) {
	my $cmd;
	foreach ( split /,/, $cmdId ) {
		$cm_url = "$cm_api/commands/$_";
		if ( $cmdAction ) {
			if ( $confirmed ) {
				$cm_url .= "/$cmdAction";
				$cmd = &rest_call('POST', $cm_url, 1);
			} else {
				print "# Use -confirmed or -run to execute command action '$cmdAction'\n";
				exit;
			}
		} else {
			$cmd = &rest_call('GET', $cm_url, 1);
		}

		$trackCmd ? $cmd_list->{$cmd->{'id'}} = $cmd : &cmd_id(\%{$cmd});
	}
	&track_cmd(\%{$cmd_list}) if $trackCmd;
	exit;
}

$hInfo = '.' if ( ( $hInfo && $hInfo eq '1' ) || $hFilter );
$roleConfigGroup = '.' if ( $roleConfigGroup && $roleConfigGroup eq '1' );
my $list_active_commands = 1 if ( $a && $a eq '1' );
my @clusters;
my $uuid_host_map = {};
my $role_host_map = {};
if ( $hInfo ) {
	die "-a=$a is not available for roles\n" if ( $a && $a eq 'deployClientConfig' );
	my $role_info_flag = 1 if ( $rInfo || $a );
	my $hInfo_match = 1;
	my $hInfo_output;
	$hRoles = 1 if ( ( $c && $api_version < 11 ) || $s || $r );
	undef $rInfo if $rInfo;

	if ( $hInfo eq '.' && $a && !$s && !$r ) {
		print "When executing a role action, specify a value for -hInfo or set -s or -r; use a cluster/service action otherwise\n";
		exit;
	}

	$cm_url = "$cm_api/hosts?view=full";
	my $hosts = &rest_call('GET', $cm_url, 1);
	my @services;
	my $host_summary;
	my $hostName_list = {};
	for ( my $i=0; $i < @{$hosts->{'items'}}; $i++ ) {
		$hInfo_match = 0 if $hRoles;
		my $host_id = $hosts->{'items'}[$i]->{'hostId'};
		my $host_name = $hosts->{'items'}[$i]->{'hostname'};
		my $ip = $hosts->{'items'}[$i]->{'ipAddress'};
		my $rack_id = $hosts->{'items'}[$i]->{'rackId'};
		my $host_health = $hosts->{'items'}[$i]->{'healthSummary'};
		my $host_maintenance_mode = $hosts->{'items'}[$i]->{'maintenanceMode'} ? 'YES' : 'NO';
		my $host_commission_state = $hosts->{'items'}[$i]->{'commissionState'};
		my ($cluster_name, $host_status);
		if ( $api_version > 10 ) {
			$cluster_name = $hosts->{'items'}[$i]->{'clusterRef'}->{'clusterName'} // 'No cluster';
			$host_status = $hosts->{'items'}[$i]->{'entityStatus'};
		}

		next if ( $c && $api_version > 10 && $cluster_name ne $c );
		next unless ( $host_name =~ /$hInfo/
			|| $ip =~ /$hInfo/
			|| $rack_id =~ /$hInfo/
			|| $host_id =~ /$hInfo/ );

		if ( $hFilter ) {
			next unless ( ( $host_health && $host_health =~ /$hFilter/i )
				|| ( $host_status && $host_status =~ /$hFilter/i )
				|| ( $host_commission_state && $host_commission_state =~ /$hFilter/i ) );
		}

		next if ( $maintenanceMode
			&& $host_maintenance_mode
			&& $maintenanceMode ne '1'
			&& $host_maintenance_mode ne $maintenanceMode );

		my $cluster_flag = 1;
		if ( $role_info_flag && !$c && !$hRoles ) {
			unless ( !$cluster_name
					|| grep { $_ eq $cluster_name } @clusters
				 	|| $cluster_name eq 'No cluster' ) {
				push @clusters, $cluster_name;
				$cluster_flag = 0;
			}
		}

		$hInfo_output = "$host_name | $host_id | $ip | $rack_id";
		if ( $api_version > 1 ) {
			$hInfo_output .= " | $host_maintenance_mode" if $maintenanceMode;
			$hInfo_output .= " | $host_commission_state";
		}
		$hInfo_output .= " | $cluster_name" if $api_version > 10;
		$hInfo_output .= " --- $host_health" if $api_version > 1;
		$hInfo_output .= " $host_status" if $api_version > 10;
		$hInfo_output .= "\n";

		my $service_name;
		if ( $hRoles || $role_info_flag ) {
			if ( @{$hosts->{'items'}[$i]->{'roleRefs'}} ) {
				# use <=> operator to compare numbers
				my @sorted = sort { $a->{'serviceName'} cmp $b->{'serviceName'} } @{$hosts->{'items'}[$i]->{'roleRefs'}};
#				print join("\n", map { $host_name." | ".$_->{'serviceName'}." | ".$_->{'roleName'} } @sorted),"\n";
				for ( my $j=0; $j < @sorted; $j++ ) {
					$cluster_name = $sorted[$j]->{'clusterName'};
					$service_name = $sorted[$j]->{'serviceName'};
					next if ( $c && !$cluster_name );
					if ( $c && $cluster_name ne $c ) { next } else { $hInfo_match = 1 if ( !$s && !$r ) };
					if ( $s && $service_name !~ /$s/i ) { next } else { $hInfo_match = 1 if !$r };
					if ( $hRoles ) {
						my $role_name = $sorted[$j]->{'roleName'};
						if ( $r && $role_name !~ /$r/i ) { next } else { $hInfo_match = 1 };
						unless ( $role_info_flag ) {
							$hInfo_output .= "|_ $host_name";
							$hInfo_output .= " | $cluster_name" if $cluster_name;
							$hInfo_output .= " | $service_name";
							$hInfo_output .= " | $role_name\n";
						}
					}
					if ( $role_info_flag && !$s ) {
						push @services, $service_name unless grep { $_ eq $service_name } @services;
					}
					if ( $role_info_flag && !$c && $cluster_flag ) {
						unless ( !$cluster_name || grep { $_ eq $cluster_name } @clusters ) {
							push @clusters, $cluster_name;
							$cluster_flag = 0;
						}
					}
				}
			} else {
				$hInfo_output .= "|_ $host_name | No roles\n" if $hRoles;
				$hInfo_match = 1 if ( $s && $s eq 'No roles' );
			}
		}

		next unless $hInfo_match;
		$uuid_host_map->{$host_id} = $host_name;
		++$host_summary->{'host_health'}->{$host_health} if ( $api_version > 1 && $host_health ne 'GOOD' );
		++$host_summary->{'host_status'}->{$host_status} if ( $api_version > 10 && $host_status ne 'GOOD_HEALTH' );
		++$host_summary->{'host_commission_state'}->{$host_commission_state} if ( $api_version > 1 && $host_commission_state ne 'COMMISSIONED' );
		print $hInfo_output;

		if ( $confirmed ) {
			my ($host, $host_ref, $role_list);
			if ( $removeFromCluster ) {
				$cluster_name = $removeFromCluster if $api_version < 11;
				if ( $cluster_name ne 'No cluster' ) {
					$cm_url = "$cm_api/clusters/$cluster_name/hosts/$host_id";
					$host_ref = &rest_call('DELETE', $cm_url, 1);
					print "$host_name | ";
					print $host_ref ? "Removed from cluster '$cluster_name'" : "hostId $host_id is not associated with cluster '$cluster_name'";
					print "\n";
				} else {
					print "$host_name | hostId $host_id is not associated with any cluster\n";
				} 
			}

			$cm_url = "$cm_api/hosts/$host_id";
			if ( $deleteHost ) {
				$host = &rest_call('DELETE', $cm_url, 1);
				print "$host_name | Deleted from the system\n";
				next;
			}

			if ( $setRackId ) {
				$body_content = "{ \"rackId\" : \"$setRackId\" }";
				$host = &rest_call('PUT', $cm_url, 1, undef, $body_content);
				print "$host_name | rackId set to $setRackId\n";
			}

			if ( $addToCluster ) {
				$cm_url = "$cm_api/clusters/$addToCluster/hosts";
				$body_content = "{ \"items\" : [\"$host_id\"] }";
				$host_ref = &rest_call('POST', $cm_url, 1, undef, $body_content);
				print "$host_name | Added to cluster '$addToCluster'\n";
			}

			if ( $addRole ) {
				if ( !$clusterName && !$addToCluster ) {
					if ( $cluster_name eq 'No cluster' ) {
						print "$host_name | hostId $host_id is not associated with any cluster\nUse -addToCluster=cluster_name along with -addRole\n";
						next;
					} else {
						$clusterName = $cluster_name;
					}
				} elsif ( $addToCluster ) {
					$clusterName = $addToCluster;
				}
				$cm_url = "$cm_api/clusters/$clusterName/services/$serviceName/roles";
				$body_content = "{ \"items\" : [ ";
				my @role_types = split /,/, $addRole; 
				my @role_types_json;
				foreach my $role ( @role_types ) {
					push @role_types_json, "{ \"hostRef\" : \"$host_id\", \"type\" : \"$role\" }";
				}
				$body_content .= join ', ', @role_types_json;
				$body_content .= " ] }";
				$role_list = &rest_call('POST', $cm_url, 1, undef, $body_content);
				print "$host_name | Added role";
				print "s" if @role_types > 1;
				print " @role_types (service '$serviceName')\n"; 
			}

			if ( $hAction ) {
				print "... $host_name | ACTION: $hAction " unless $hAction =~ /decommission|recommission/;
				$cm_url = "$cm_api/cm/commands";
				if ( $hAction =~ /decommission|recommission/ ) {
					push @{$hostName_list->{'items'}}, $host_name;
					next;
				} elsif ( $hAction eq 'startRoles' ) {
					$cm_url .= "/hostsStartRoles";
					$body_content = "{ \"items\" : [\"$host_name\"] }";
				} elsif ( $hAction =~ /enterMaintenanceMode|exitMaintenanceMode/ ) {
					$cm_url = "$cm_api/hosts/$host_id/commands/$hAction";
				}
				my $cmd = $body_content ? &rest_call('POST', $cm_url, 1, undef, $body_content) : &rest_call('POST', $cm_url, 1);
				my $id = $cmd->{'id'};
				print "| CMDID: $id\n";
				( $trackCmd && $id != -1 ) ? $cmd_list->{$id} = $cmd : &cmd_id(\%{$cmd});
			}
		}

		if ( $hChecks ) {
			if ( @{$hosts->{'items'}[$i]->{'healthChecks'}} ) {
				my @sorted = sort { $a->{'name'} cmp $b->{'name'} } @{$hosts->{'items'}[$i]->{'healthChecks'}};
				print join("\n", map { $host_name." | ".$_->{'name'}." --- ".$_->{'summary'} } @sorted),"\n";
			} else {
				print "$host_name | No health data found\n"
			}
		}
	}
	
	if ( $hAction && $confirmed && $hAction =~ /decommission|recommission/ ) {
		print "... ACTION: $hAction ";
		if ( $hAction eq 'decommission' ) {
			$cm_url .= "/hostsDecommission";
		} elsif ( $hAction eq 'recommission' ) {
			$cm_url .= "/hostsRecommission";
		}
		$body_content = to_json($hostName_list);
		my $cmd = &rest_call('POST', $cm_url, 1, undef, $body_content);
		my $id = $cmd->{'id'};
		print "| CMDID: $id\n";
		( $trackCmd && $id != -1 ) ? $cmd_list->{$id} = $cmd : &cmd_id(\%{$cmd});
	}

	my $num_hosts = keys %{$uuid_host_map};
	print $num_hosts ? "# Number of hosts: $num_hosts" : "# No hosts found";
	print " --- " if keys %{$host_summary} > 0;
	foreach my $property ( sort keys %{$host_summary} ) {
		foreach my $key ( reverse sort keys %{$host_summary->{$property}} ) {
			print "$key: $host_summary->{$property}->{$key} "
		}
	}
	print "\n";
	exit unless $num_hosts;

	while ( !$confirmed ) {
		if ( $removeFromCluster ) {
			print "# Use -confirmed to remove the hosts from the cluster\n";
		}
		if ( $deleteHost ) {
			print "# Use -confirmed to delete the hosts from Cloudera Manager\n";
			last;
		}
		if ( $setRackId ) {
			print "# Use -confirmed to assign rackId '$setRackId'\n";
		}
		if ( $addToCluster ) {
			print "# Use -confirmed to add the hosts to cluster '$addToCluster'\n";
		}
		if ( $addRole ) {
			print "# Use -confirmed to add role $addRole (service '$serviceName') to the hosts\n";
		}
		last;
	}

	if ( $hAction && !$deleteHost ) {
		print "# Use -confirmed or -run to execute host action '$hAction'\n" if !$confirmed;
		&track_cmd(\%{$cmd_list}) if keys %{$cmd_list};
	}

	foreach ( keys %hInfo_opts ) {
		exit if ( $_ !~ /hRoles|hChecks/ && $hInfo_opts{$_} );
	}
	
	if ( $role_info_flag ) {
		if ( @services && !$s ) {
			# match exact word -> wrap around \b
			$s = '\b';
			$s .= join '\b|\b', @services;
			$s .= '\b';
		}
		$rInfo = ( $hInfo ne '.' || $hFilter ) ? join '|', keys %{$uuid_host_map} : 1;
	}

#	print "@clusters\n@services\n$c\n$s\n$r\n$rInfo\n";
	exit unless $s;
	exit unless ( $rInfo && ( $c || @clusters || $s =~ /mgmt/ ) );
}

$rInfo = '.' if ( $rInfo && $rInfo eq '1' ) || ( $r || $rFilter );
$s = '.' if !$rInfo && !$s && ( $sFilter || ( $maintenanceMode && $maintenanceMode ne 1 ) );
die "-a=$a is not available for roles\n" if ( $rInfo && $a && $a eq 'deployClientConfig' );

if ( $s && $s =~ /mgmt/ ) {
	$cm_url = "$cm_api/cm/service";
	my $mgmt_service = &rest_call('GET', $cm_url, 1);
	my $mgmt_name = $mgmt_service->{'name'};
	my $mgmt_type = $mgmt_service->{'type'};
	my $mgmt_state = $mgmt_service->{'serviceState'};
	my $mgmt_health = $mgmt_service->{'healthSummary'};
	my $mgmt_config = $mgmt_service->{'configStalenessStatus'};
	my $mgmt_maintenance_mode = $mgmt_service->{'maintenanceMode'} ? 'YES' : 'NO';
	print "$mgmt_name | $mgmt_type ";
	print "| $mgmt_maintenance_mode " if ( $maintenanceMode && $api_version > 1 );
	print "--- $mgmt_state $mgmt_health ";
	print $mgmt_config if $api_version > 5;
	print "\n";

	if ( $a && !$rInfo ) {
		my $context = 'mgmt service';
		my $mgmt_action = $list_active_commands ? "list active $context commands" : $a;
		if ( $list_active_commands || $confirmed || $a =~ /roleTypes|getConfig/ ) {
			print "... $mgmt_name | ACTION: $mgmt_action ";
			$cm_url = "$cm_api/cm/service";
			if ( $list_active_commands ) {
				&track_active_commands($context);
			} elsif ( $a eq 'getConfig' ) {
				&get_config($cm_url, $propertyName);
			} elsif ( $a eq 'updateConfig' ) {
				&update_config($cm_url, $propertyName, $propertyValue);
			} elsif ( $a eq 'roleTypes' ) {
				print "\n";
				$cm_url .= "/$a";
				my $role_types = &rest_call('GET', $cm_url, 1);
				print map { "$_\n" } sort @{$role_types->{'items'}};
			} else {
				$cm_url .= "/commands/$a";
				my $cmd = &rest_call('POST', $cm_url, 1);
				my $id = $cmd->{'id'};
				print "| CMDID: $id\n";
				$trackCmd ? $cmd_list->{$id} = $cmd : &cmd_id(\%{$cmd});
			}
		} else {
			print "# Use -confirmed or -run to execute mgmt action '$mgmt_action'\n";
		}
	}

	my $mgmt_role_summary;
	if ( $rInfo ) {
		$cm_url = "$cm_api/cm/service/roles";
		my $mgmt_roles = &rest_call('GET', $cm_url, 1);
		for ( my $i=0; $i < @{$mgmt_roles->{'items'}}; $i++ ) {
			my $host_id = $mgmt_roles->{'items'}[$i]->{'hostRef'}->{'hostId'};
			next if ( $hInfo && !$uuid_host_map->{$host_id} );
			next unless $host_id =~ /$rInfo/;
			my $mgmt_role_name = $mgmt_roles->{'items'}[$i]->{'name'};
			my $mgmt_role_type = $mgmt_roles->{'items'}[$i]->{'type'};
			if ( $r ) { next unless ( $mgmt_role_type =~ /$r/i || $mgmt_role_name =~ /$r/i ) };

			my $mgmt_role_state = $mgmt_roles->{'items'}[$i]->{'roleState'};
			my $mgmt_role_health = $mgmt_roles->{'items'}[$i]->{'healthSummary'};
			my $mgmt_role_config = $mgmt_roles->{'items'}[$i]->{'configStalenessStatus'};
			my $mgmt_role_maintenance_mode = $mgmt_roles->{'items'}[$i]->{'maintenanceMode'} ? 'YES' : 'NO';

			if ( $rFilter ) {
				next unless ( $mgmt_role_state =~ /$rFilter/i
					|| $mgmt_role_health =~ /$rFilter/i
					|| ( $mgmt_role_config && $mgmt_role_config =~ /$rFilter/i ) );
			}

			next if ( $maintenanceMode
				&& $mgmt_role_maintenance_mode
				&& $maintenanceMode ne '1'
				&& $mgmt_role_maintenance_mode ne $maintenanceMode );

			if ( $hInfo ) {
				$host_id = $uuid_host_map->{$host_id};
#				$host_id =~ s/\..*$//; # remove domain name
			}

			++$mgmt_role_summary->{$mgmt_role_type}->{'instances'};
			++$mgmt_role_summary->{$mgmt_role_type}->{'role_state'}->{$mgmt_role_state} unless $mgmt_role_state =~ /(NA|STARTED)/;
			++$mgmt_role_summary->{$mgmt_role_type}->{'role_health'}->{$mgmt_role_health} unless $mgmt_role_health eq 'GOOD';
			++$mgmt_role_summary->{$mgmt_role_type}->{'role_config'}->{$mgmt_role_config} if ( $api_version > 5 && $mgmt_role_config ne 'FRESH' );

			my $mgmt_header = "$mgmt_name | $host_id";
			print "|_ $mgmt_header | $mgmt_role_type ";
			print "| $mgmt_role_maintenance_mode " if ( $maintenanceMode && $api_version > 1 );
			print "| $mgmt_role_name --- $mgmt_role_state $mgmt_role_health ";
			print $mgmt_role_config if $api_version > 5;
			print "\n";

			if ( $log ) {
				if ( $log =~ /^(stdout|stderr|full|stacks|stacksBundle)$/ ) {
					print "Retrieving $log log...\n\n";
					$cm_url = "$cm_api/cm/service/roles/$mgmt_role_name/logs/$log";
					&rest_call('GET', $cm_url, 0);
				} else {
					print "Unknown log type: $log\n";
					exit;
				}
			}

			if ( $a && ( $list_active_commands || $confirmed || $a eq 'getConfig' ) ) {
				my $context = 'mgmt role';
				my $mgmt_role_action = $list_active_commands ? "list active $context commands" : $a;
				print "... $mgmt_header | $mgmt_role_name | ACTION: $mgmt_role_action ";
				$cm_url = "$cm_api/cm/service/roles/$mgmt_role_name";
				if ( $list_active_commands ) {
					&track_active_commands($context);
				} elsif ( $a eq 'deleteRole' ) {
					my $role = &rest_call('DELETE', $cm_url, 1);
					print "| Role deleted\n";
				} elsif ( $a eq 'getConfig' ) {
					&get_config($cm_url, $propertyName);
				} elsif ( $a eq 'updateConfig' ) {
					&update_config($cm_url, $propertyName, $propertyValue);
				} else {
					$cm_url = "$cm_api/cm/service/roleCommands/$a";
					$body_content = "{ \"items\" : [\"$mgmt_role_name\"] }";
					my $cmd = &rest_call('POST', $cm_url, 1, undef, $body_content);
					if ( @{$cmd->{'errors'}} ) {
						print "\nERROR: $cmd->{'errors'}[0]\n";
						next;
					}
					my $id = $cmd->{'items'}[0]->{'id'};
					print "| CMDID: $id\n";
					$trackCmd ? $cmd_list->{$id} = $cmd->{'items'}[0] : &cmd_id($cmd->{'items'}[0]);
				}
			}
		}
		print "# Use -confirmed or -run to execute mgmt role action '$a'\n" if ( $a && $a ne 'getConfig' && !$confirmed && !$list_active_commands );
		&display_role_summary($mgmt_role_summary, undef, undef, $mgmt_name);
	}

	unless ( $s !~ /^(\\b)?mgmt\d*(\\b)?$/ ) {
		&track_cmd(\%{$cmd_list}) if keys %{$cmd_list};
		exit;
	}
}
#print "After the mgmt block...\n";

if ( $a && $a eq 'addCluster' ) {
	if ( $confirmed ) {
		$cm_url = "$cm_api/clusters";
		$body_content = "{ \"items\" : [ { \"name\" : \"$clusterName\", \"displayName\" : \"$displayName\", \"fullVersion\" : \"$fullVersion\" } ] }";
		my $cluster = &rest_call('POST', $cm_url, 1, undef, $body_content);
		my $cluster_display_name = $cluster->{'items'}[0]->{'displayName'};
		my $cluster_full_version = $cluster->{'items'}[0]->{'fullVersion'};
		print "Cluster '$clusterName' ";
		print "-> '$cluster_display_name' " if $cluster_display_name;
		print "(CDH $cluster_full_version) " if $cluster_full_version;
		print "created\n";
	} else {
		print "# Use -confirmed to execute action '$a'\n";
	}
	exit;
}

unless ( @clusters ) {
	if ( $c ) {
		push @clusters, $c;
	} else {
		print "Fetching clusters...\n" if $d;
		$cm_url = "$cm_api/clusters";
		my $cm_clusters = &rest_call('GET', $cm_url, 1);
		die "No clusters found\n" unless @{$cm_clusters->{'items'}};
		for ( my $i=0; $i < @{$cm_clusters->{'items'}}; $i++ ) {
			my $cluster_name = $cm_clusters->{'items'}[$i]->{'name'};
			print "Found cluster '$cluster_name'\n" if $d;
			push @clusters, $cluster_name;
		}
	}
}

# clusters
my $service_header;
my $cluster_cnt=scalar @clusters;
print "Number of clusters: $cluster_cnt\n" if $d;

foreach my $cluster_name ( @clusters ) {
	if ( !$s && !$rInfo ) {
		$cm_url = "$cm_api/clusters/$cluster_name";
		my $cluster = &rest_call('GET', $cm_url, 1);
		my $cluster_name = $cluster->{'name'};
		my $cluster_maintenance_mode = $cluster->{'maintenanceMode'} ? 'YES' : 'NO';
		my $cluster_display_name = $cluster->{'displayName'};
		my $cluster_full_version = $cluster->{'fullVersion'};

		print "$cluster_name ";
		print "| $cluster_maintenance_mode " if ( $maintenanceMode && $api_version > 1 );
		print ">>> $cluster_display_name (CDH $cluster_full_version)" if $api_version > 5;
		if ( $api_version > 10 ) {
			my $cluster_status = $cluster->{'entityStatus'};
			print " --- $cluster_status";
		}
		print "\n";
		if ( $a ) {
			my $context = 'cluster';
			my $cluster_action = $list_active_commands ? "list active $context commands" : $a;
			if ( $list_active_commands || $a eq 'serviceTypes' || $confirmed ) {
				print "... $cluster_name | ACTION: $cluster_action ";
				$cm_url = "$cm_api/clusters/$cluster_name";
				my $cluster;
				if ( $list_active_commands ) {
					&track_active_commands($context);
				} elsif ( $a eq 'updateCluster' ) {
					$body_content = "{ ";
					$body_content .= "\"displayName\" : \"$displayName\"" if $displayName;
					$body_content .= ", " if ( $displayName && $fullVersion );
					$body_content .= "\"fullVersion\" : \"$fullVersion\"" if $fullVersion; 
					$body_content .= " }";
					$cluster = &rest_call('PUT', $cm_url, 1, undef, $body_content);
					print "| Cluster updated\n";
				} elsif ( $a eq 'deleteCluster' ) {
					$cluster = &rest_call('DELETE', $cm_url, 1);
					print "| Cluster deleted\n";
				} elsif ( $a eq 'addService' ) {
					$serviceType = uc $serviceType;
					$cm_url .= "/services";
					$body_content = "{ \"items\" : [ { \"name\" : \"$serviceName\", \"displayName\" : \"$displayName\", \"type\" : \"$serviceType\" } ] }";
					my $service = &rest_call('POST', $cm_url, 1, undef, $body_content);
					my $service_display_name = $service->{'items'}[0]->{'displayName'};
					my $service_type = $service->{'items'}[0]->{'type'};
					print "| Service '$serviceName' ";
					print "-> '$service_display_name' " if $service_display_name;
					print "($service_type) " if $service_type;
					print "created\n";
				} elsif ( $a eq 'serviceTypes' ) {
					$cm_url .= "/$a";
					my $service_types = &rest_call('GET', $cm_url, 1);
					print "\n";
					print map { "$_\n" } sort @{$service_types->{'items'}};
				} else {
					$cm_url .= "/commands/$a";
					my $cmd = &rest_call('POST', $cm_url, 1);
					my $id = $cmd->{'id'};
					print "| CMDID: $id\n";
					if ( $trackCmd && $id != -1 ) {
						$cmd_list->{$id} = $cmd;
					} else {
						&cmd_id(\%{$cmd});
					}
				}
				print "Set -c to specify a different cluster\n" if ( !$confirmed && $cluster_cnt > 1 );
				&track_cmd(\%{$cmd_list}) if keys %{$cmd_list};
			} else {
				print "# Use -confirmed or -run to execute cluster action '$cluster_action' : '$cluster_name'\n";
				print "Set -c to specify a different cluster\n" unless ( $a =~ /(Cluster|Service)$/ || $cluster_cnt == 1 );
			}
			exit;
		}
	}

	$cm_url = "$cm_api/clusters/$cluster_name/services";
	my $cm_services = &rest_call('GET', $cm_url, 1);
	my $service_action_flag = 0;
	my $role_action_flag = 0;
	# services
	for ( my $i=0; $i < @{$cm_services->{'items'}}; $i++ ) {
		my $service_name = $cm_services->{'items'}[$i]->{'name'};
		$service_header = "$cluster_name | $service_name";
		# service instance
		if ( !$s || $service_name =~ /$s/i ) {
			my $service_type = $cm_services->{'items'}[$i]->{'type'};
			my $service_state = $cm_services->{'items'}[$i]->{'serviceState'};
			my $service_health = $cm_services->{'items'}[$i]->{'healthSummary'};
			my $service_maintenance_mode = $cm_services->{'items'}[$i]->{'maintenanceMode'} ? 'YES' : 'NO';
			my $service_display_name = $cm_services->{'items'}[$i]->{'displayName'};
			my $service_config = $cm_services->{'items'}[$i]->{'configStalenessStatus'};
			my $service_clientConfig = $cm_services->{'items'}[$i]->{'clientConfigStalenessStatus'};

			if ( $sFilter ) {
				next unless ( $service_state =~ /$sFilter/i || $service_health =~ /$sFilter/i
					|| ( $service_config && $service_config =~ /$sFilter/i )
					|| ( $service_clientConfig && $service_clientConfig =~ /$sFilter/i ) );
			}

			next if ( !$rInfo && $maintenanceMode
				&& $service_maintenance_mode
				&& $maintenanceMode ne '1'
				&& $service_maintenance_mode ne $maintenanceMode );

			print "|_ $service_header | $service_type ";
			if ( $api_version > 1 ) {
				print "| $service_maintenance_mode " if $maintenanceMode;
				print "| $service_display_name ";
			}
			print "--- $service_state $service_health ";
			print "$service_config $service_clientConfig" if $api_version > 5;
			print "\n";
	
			$service_action_flag = 1 if $a;
			
			# Available since API v6
			if ( $yarnApps ) {
				if ( $yarnApps eq '1' ) {
					$cm_url = "$cm_api/clusters/$cluster_name/services/$service_name/yarnApplications";
				} else {
					$cm_url = "$cm_api/clusters/$cluster_name/services/$service_name/yarnApplications?$yarnApps";
				}
				my $applications = &rest_call('GET', $cm_url, 1);
				my @app_properties = ('applicationId', 'name', 'startTime', 'endTime', 'user', 'pool', 'state', 'progress');
				push @app_properties, ('allocatedMemorySeconds', 'allocatedVcoreSeconds', 'allocatedMB', 'allocatedVCores', 'runningContainers');
				if ( @{$applications->{'applications'}} ) {
				for ( my $i=0; $i < @{$applications->{'applications'}}; $i++ ) {
					print "$service_header | apps ";
					my $property_index = 0;
					foreach my $property ( @app_properties ) {
						if ( defined $applications->{'applications'}[$i]->{$property} ) {
							print "| $applications->{'applications'}[$i]->{$property} ";
						}
						print "\n\t" unless $property_index % 7;
						$property_index++;
					}
					print "\n";
				} } else {
					print "$service_header | apps | No applications found\n";
				}
			}

			if ( $impalaQueries ) {
				if ( $impalaQueries eq '1' ) {
					$cm_url = "$cm_api/clusters/$cluster_name/services/$service_name/impalaQueries";
				} else {
					$cm_url = "$cm_api/clusters/$cluster_name/services/$service_name/impalaQueries?$impalaQueries";
				}
				my $queries = &rest_call('GET', $cm_url, 1);
				my @query_properties = ('queryId', 'statement', 'queryType', 'queryState', 'startTime', 'endTime');
				push @query_properties, ('rowsProduced', 'attributes', 'user', 'coordinator', 'database', 'durationMillis', 'warnings');

				if ( @{$queries->{'queries'}} ) {
				for ( my $i=0; $i < @{$queries->{'queries'}}; $i++ ) {
					print "$service_header | queries ";
					my $property_index = 0;
					foreach my $property ( @query_properties ) {
						if ( $property eq 'attributes' ) {
							print "\n\t| $queries->{'queries'}[$i]->{$property}->{'admission_result'} ";
							print "| $queries->{'queries'}[$i]->{$property}->{'oom'} ";
							print "| $queries->{'queries'}[$i]->{$property}->{'stats_missing'} ";
							print "| $queries->{'queries'}[$i]->{$property}->{'session_type'} ";
							print "| $queries->{'queries'}[$i]->{$property}->{'query_status'} ";
						} elsif ( $property eq 'coordinator' ) {
							print "| $queries->{'queries'}[$i]->{$property}->{'hostId'} ";
						} elsif ( defined $queries->{'queries'}[$i]->{$property} ) {
							print "| $queries->{'queries'}[$i]->{$property} ";
						}
						print "\n\t" unless $property_index % 7;
						$property_index++;
					}
					print "\n";
				} } else {
					print "$service_header | queries | No queries found\n";
				}
			}
			
			if ( $sChecks ) {
				for ( my $j=0; $j < @{$cm_services->{'items'}[$i]->{'healthChecks'}}; $j++ ) {
					my $health_check_name = $cm_services->{'items'}[$i]->{'healthChecks'}[$j]->{'name'};
					my $health_check_summary = $cm_services->{'items'}[$i]->{'healthChecks'}[$j]->{'summary'};
					print "$service_header | healthChecks | $health_check_name --- $health_check_summary\n"
				}
			}
			
			if ( $sMetrics ) {
			if ( $api_version < 6 ) {
				$cm_url = "$cm_api/clusters/$cluster_name/services/$service_name/metrics";
				my $service_metrics = &rest_call('GET', $cm_url, 1);
				for ( my $i=0; $i < @{$service_metrics->{'items'}}; $i++ ) {
					my $metric_name = $service_metrics->{'items'}[$i]->{'name'};
					my $last_value_index = $#{$service_metrics->{'items'}[$i]->{'data'}};
					my $metric_value = $last_value_index != -1 ? $service_metrics->{'items'}[$i]->{'data'}[$last_value_index]->{'value'} : '-';
					my $metric_unit = $service_metrics->{'items'}[$i]->{'unit'};
					print "$service_header | metrics | $metric_name: $metric_value $metric_unit\n";
				}
			} else {
				$cm_url = "$cm_api/timeseries?query=select * where serviceName=$service_name";
				my $service_metrics = &rest_call('GET', $cm_url, 1);
#				print Dumper($service_metrics);
				my $i=0;
				for ( my $j=0; $j < @{$service_metrics->{'items'}[$i]->{'timeSeries'}}; $j++ ) {
					my $metric_name = $service_metrics->{'items'}[$i]->{'timeSeries'}[$j]->{'metadata'}->{'metricName'};
					my $entity_name = $service_metrics->{'items'}[$i]->{'timeSeries'}[$j]->{'metadata'}->{'entityName'};
					my $unit_numerators = $service_metrics->{'items'}[$i]->{'timeSeries'}[$j]->{'metadata'}->{'unitNumerators'}[0];
					my $unit_denominators = $service_metrics->{'items'}[$i]->{'timeSeries'}[$j]->{'metadata'}->{'unitDenominators'}[0];
					my $last_value_index = $#{$service_metrics->{'items'}[$i]->{'timeSeries'}[$j]->{'data'}};
					my $metric_value = $last_value_index != -1 ? $service_metrics->{'items'}[$i]->{'timeSeries'}[$j]->{'data'}[$last_value_index]->{'value'} : '-';
					print "$service_header | metrics | ";
					print "$entity_name | " if $service_name ne $entity_name;
					print "$metric_name: $metric_value ";
					print "$unit_numerators" if $unit_numerators;
					print "/$unit_denominators" if $unit_denominators;;
					print "\n";
				}
			} }

			if ( $a && !$rInfo && ( $list_active_commands || $confirmed || $a =~ /roleTypes|getConfig/ ) ) {
				my $context = 'service';
				my $service_action = $list_active_commands ? "list active $context commands" : $a;
				print "... $service_header | ACTION: $service_action ";
				$cm_url = "$cm_api/clusters/$cluster_name/services/$service_name";
				my ($service, $role_config_group);
				if ( $list_active_commands ) {
					&track_active_commands($context);
				} elsif ( $a eq 'createRoleGroup' ) {
					$roleType = uc $roleType;
					my $roleGroupDisplayName = $displayName;
					$displayName =~ s/\s+//g;
					my $roleGroupName = "$service_name-$roleType-$displayName";
					$cm_url .= "/roleConfigGroups";
					$body_content = "{ \"items\" : [ { \"name\" : \"$roleGroupName\", \"displayName\" : \"$roleGroupDisplayName\", \"roleType\" : \"$roleType\"";
					if ( $copyFromRoleGroup ) {
						my $url = $cm_url . "/$copyFromRoleGroup";
						$body_content .= &copy_from($url);
					}
					$body_content .= " } ] }";
					$role_config_group = &rest_call('POST', $cm_url, 1, undef, $body_content);
					print "| Role config group '$role_config_group->{'items'}[0]->{'name'}' created";
					print " (copy from group '$copyFromRoleGroup')" if $copyFromRoleGroup;
					print "\n";
				} elsif ( $a eq 'updateRoleGroup' ) {
					$cm_url .= "/roleConfigGroups/$roleConfigGroup";
					$body_content = "{ \"name\" : \"$roleConfigGroup\"";
					$body_content .= ", \"displayName\" : \"$displayName\"" if $displayName;
					if ( $copyFromRoleGroup ) {
						( my $url = $cm_url ) =~ s/$roleConfigGroup/$copyFromRoleGroup/;
						$body_content .= &copy_from($url);
					}
					$body_content .= " } ] }";
					$role_config_group = &rest_call('PUT', $cm_url, 1, undef, $body_content);
					print "| Role config group '$roleConfigGroup' updated";
					print " (copy from group '$copyFromRoleGroup')" if $copyFromRoleGroup;
					print "\n";
				} elsif ( $a eq 'deleteRoleGroup' ) {
					$cm_url .= "/roleConfigGroups/$roleConfigGroup";
					$role_config_group = &rest_call('DELETE', $cm_url, 1);
					print "| Role config group '$roleConfigGroup' deleted\n";
				} elsif ( $a eq 'getConfig' ) {
					if ( $roleConfigGroup ) {
						$cm_url .= "/roleConfigGroups";
						if ( $roleConfigGroup eq '.' ) {
							print "\n";
							my $role_config_groups = &rest_call('GET', $cm_url, 1);
							foreach my $groups ( sort { $a->{'name'} cmp $b->{'name'} } @{$role_config_groups->{'items'}} ) {
								my $group_name = $groups->{'name'};
								my $group_base = $groups->{'base'} ? 'YES' : 'NO';
								print "$service_header | $group_name | $groups->{'roleType'} | $groups->{'displayName'} | $group_base\n";
								if ( $propertyName ) {
								foreach my $config_property ( sort { $a->{'name'} cmp $b->{'name'} } @{$groups->{'config'}->{'items'}} ) {
									next unless ( $config_property->{'name'} =~ /$propertyName/i );
									print "$config_property->{'name'} = $config_property->{'value'}\n"
								} }
							}
						} else {
							$cm_url .= "/$roleConfigGroup";
							print "| Role config group: $roleConfigGroup";
							&get_config($cm_url, $propertyName);
						}
					} elsif ( $clientConfig ) {
						$cm_url .= "/clientConfig";
						my $filename = "$cm_host\_$cluster_name\_$service_name\_client\_config.zip";
						&rest_call('GET', $cm_url, 2, $filename);
						print "| Saved to $filename\n";
					} else {
						&get_config($cm_url, $propertyName);
					}
				} elsif ( $a eq 'updateConfig' ) {
					if ( $roleConfigGroup ) {
						$cm_url .= "/roleConfigGroups/$roleConfigGroup";
						print "| Role config group: $roleConfigGroup ";
					}
					&update_config($cm_url, $propertyName, $propertyValue);
				} elsif ( $a eq 'updateService' ) {
					$body_content = "{ \"displayName\" : \"$displayName\" }";
					$service = &rest_call('PUT', $cm_url, 1, undef, $body_content);
					print "| Service '$service_name' updated\n";
				} elsif ( $a eq 'deleteService' ) {
					$service = &rest_call('DELETE', $cm_url, 1);
					print "| Service '$service_name' deleted\n";
				} elsif ( $a eq 'roleTypes' ) {
					print "\n";
					$cm_url .= "/$a";
					my $role_types = &rest_call('GET', $cm_url, 1);
					print map { "$_\n" } sort @{$role_types->{'items'}};
				} else {
					$cm_url .= "/commands/$a";
					if ( $a eq 'rollingRestart' ) {
						$body_content = &rolling_restart($cluster_name, $service_name);						
					} elsif ( $a eq 'deployClientConfig' ) {
						$body_content = '{ "items" : [] }';
					}
					my $cmd = $body_content ? &rest_call('POST', $cm_url, 1, undef, $body_content) : &rest_call('POST', $cm_url, 1);
					my $id = $cmd->{'id'};
					print "| CMDID: $id\n";
					if ( $trackCmd && $id != -1 ) {
						$cmd_list->{$id} = $cmd;
					} else {
						&cmd_id(\%{$cmd});
					}
				}
			}

			next unless $rInfo;

			$cm_url = "$cm_api/clusters/$cluster_name/services/$service_name/roles";
			my $cm_roles = &rest_call('GET', $cm_url, 1);
			# roles
			my $role_summary;
			my $roleName_list = {};
			for ( my $i=0; $i < @{$cm_roles->{'items'}}; $i++ ) {
				my $host_id = $cm_roles->{'items'}[$i]->{'hostRef'}->{'hostId'};
				# role instance
				if ( $host_id =~ /$rInfo/ ) {
					my $role_type = $cm_roles->{'items'}[$i]->{'type'};
					my $role_name = $cm_roles->{'items'}[$i]->{'name'};
					if ( !$r || $role_type =~ /$r/i || $role_name =~ /$r/i ) {
						my $role_state = $cm_roles->{'items'}[$i]->{'roleState'};
						my $role_health = $cm_roles->{'items'}[$i]->{'healthSummary'};
						my $role_config = $cm_roles->{'items'}[$i]->{'configStalenessStatus'};
						my $role_config_group = $cm_roles->{'items'}[$i]->{'roleConfigGroupRef'}->{'roleConfigGroupName'};
						my $role_maintenance_mode = $cm_roles->{'items'}[$i]->{'maintenanceMode'} ? 'YES' : 'NO';
						my $role_commission_state = $cm_roles->{'items'}[$i]->{'commissionState'};

						if ( $rFilter ) {
							next unless ( $role_state =~ /$rFilter/i || $role_health =~ /$rFilter/i
								|| ( $role_config && $role_config =~ /$rFilter/i )
								|| ( $role_config_group && $role_config_group =~ /$rFilter/i )
								|| ( $role_commission_state && $role_commission_state =~ /$rFilter/i ) );
						}

						next if ( $maintenanceMode
								&& $role_maintenance_mode
								&& $maintenanceMode ne '1'
								&& $role_maintenance_mode ne $maintenanceMode );

						unless ( $a && $a eq 'moveToRoleGroup' ) {
							next if ( $roleConfigGroup
								&& $role_config_group
								&& $role_config_group !~ /$roleConfigGroup/i );
						}

						if ( $hInfo ) {
							$host_id = $uuid_host_map->{$host_id};
#							$host_id =~ s/\..*$//; # remove domain name
							$role_host_map->{$role_name} = $host_id;
						}

						++$role_summary->{$role_type}->{'instances'};
						++$role_summary->{$role_type}->{'role_state'}->{$role_state} unless $role_state =~ /(NA|STARTED)/;
						++$role_summary->{$role_type}->{'role_health'}->{$role_health} unless $role_health eq 'GOOD';
						++$role_summary->{$role_type}->{'role_config'}->{$role_config} if ( $api_version > 5 && $role_config ne 'FRESH' );
						++$role_summary->{$role_type}->{'role_commission_state'}->{$role_commission_state} if ( $api_version > 1 && $role_commission_state ne 'COMMISSIONED' );

						my $role_header = "$service_header | $host_id | $role_type";
						print "  |_ $role_header | ";
						print "$role_config_group | " if ( $roleConfigGroup && $api_version > 2 );
						if ( $api_version > 1 ) {
							print "$role_maintenance_mode | " if $maintenanceMode;
							print "$role_commission_state | ";
						}
						print "$role_name --- $role_state $role_health ";
						print $role_config if $api_version > 5;
						print "\n";

						$role_action_flag = 1 if $a;

						if ( $rChecks ) {
							for ( my $j=0; $j < @{$cm_roles->{'items'}[$i]->{'healthChecks'}}; $j++ ) {
								my $health_check_name = $cm_roles->{'items'}[$i]->{'healthChecks'}[$j]->{'name'};
								my $health_check_summary = $cm_roles->{'items'}[$i]->{'healthChecks'}[$j]->{'summary'};
								print "$role_header | $role_name | healthChecks | $health_check_name --- $health_check_summary\n"
							}
						}

						if ( $rMetrics ) {
						if ( $api_version < 6 ) {
							$cm_url = "$cm_api/clusters/$cluster_name/services/$service_name/roles/$role_name/metrics";
							my $role_metrics = &rest_call('GET', $cm_url, 1);
							for ( my $i=0; $i < @{$role_metrics->{'items'}}; $i++ ) {
								my $metric_name = $role_metrics->{'items'}[$i]->{'name'};
								my $last_value_index = $#{$role_metrics->{'items'}[$i]->{'data'}};
								my $metric_value = $last_value_index != -1 ? $role_metrics->{'items'}[$i]->{'data'}[$last_value_index]->{'value'} : '-';
								my $metric_unit = $role_metrics->{'items'}[$i]->{'unit'};
								print "$role_header | $role_name | metrics | $metric_name: $metric_value $metric_unit\n";
							}
						} else {
							$cm_url = "$cm_api/timeseries?query=select * where roleName=$role_name";
							my $role_metrics = &rest_call('GET', $cm_url, 1);
							my $i=0;
							for ( my $j=0; $j < @{$role_metrics->{'items'}[$i]->{'timeSeries'}}; $j++ ) {
								my $metric_name = $role_metrics->{'items'}[$i]->{'timeSeries'}[$j]->{'metadata'}->{'metricName'};
								my $entity_name = $role_metrics->{'items'}[$i]->{'timeSeries'}[$j]->{'metadata'}->{'entityName'};
								my $unit_numerators = $role_metrics->{'items'}[$i]->{'timeSeries'}[$j]->{'metadata'}->{'unitNumerators'}[0];
								my $unit_denominators = $role_metrics->{'items'}[$i]->{'timeSeries'}[$j]->{'metadata'}->{'unitDenominators'}[0];
								my $last_value_index = $#{$role_metrics->{'items'}[$i]->{'timeSeries'}[$j]->{'data'}};
								my $metric_value = $last_value_index != -1 ? $role_metrics->{'items'}[$i]->{'timeSeries'}[$j]->{'data'}[$last_value_index]->{'value'} : '-';
								print "$role_header | metrics | ";
								print "$entity_name | " if $role_name ne $entity_name;
								print "$metric_name: $metric_value ";
								print "$unit_numerators" if $unit_numerators;
								print "/$unit_denominators" if $unit_denominators;;
								print "\n";
								}
						} }

						if ( $log ) {
							if ( $log =~ /^(stdout|stderr|full)$/ ) {
								print "Retrieving $log log...\n\n";
#								my $cluster_name_w_spaces = $cluster_name;
#								$cluster_name_w_spaces =~ s/ /%20/g;
								# curl call (if https, add -k to allow connections to SSL sites without certs)
#								$cm_url = "http://$cm_user:\'$cm_password\'\@$cm_api/clusters/$cluster_name_w_spaces/services/$service_name/roles/$role_name/logs/$log";
								$cm_url = "$cm_api/clusters/$cluster_name/services/$service_name/roles/$role_name/logs/$log";
								&rest_call('GET', $cm_url, 0);
							} else { 
								print "Unknown log type: $log\n";
							}
						}

						if ( $a && ( $list_active_commands || $confirmed || $a eq 'getConfig' ) ) {
							my $context = 'role';
							my $role_action = $list_active_commands ? "list active $context commands" : $a;
							print "... $service_header | $host_id | $role_name | ACTION: $role_action " unless $a =~ /rollingRestart|decommission|recommission/;
							$cm_url = "$cm_api/clusters/$cluster_name/services/$service_name";
							my $single_cmd = 1;
							if ( $list_active_commands ) {
								$cm_url .= "/roles/$role_name";
								&track_active_commands($context);
								next;
							} elsif ( $a eq 'rollingRestart' ) {
								$rr_opts{'restartRoleNames'} .= "$role_name,";
								next;
							} elsif ( $a =~ /decommission|recommission/ ) {
								push @{$roleName_list->{'items'}}, $role_name;
								next;
							} elsif ( $a =~ /enterMaintenanceMode|exitMaintenanceMode/ ) {
								$cm_url .= "/roles/$role_name/commands/$a";
							} elsif ( $a eq 'deleteRole' ) {
								$cm_url .= "/roles/$role_name";
								my $role = &rest_call('DELETE', $cm_url, 1);
								print "| Role deleted\n";
								next;
							} elsif ( $a eq 'moveToRoleGroup' ) {
								$cm_url .= "/roleConfigGroups/$roleConfigGroup/roles";
							} elsif ( $a eq 'moveToBaseGroup' ) {
								$cm_url .= "/roleConfigGroups/roles";
							} elsif ( $a =~ /getConfig|updateConfig/ ) {
								$cm_url .= "/roles/$role_name";
								$a eq 'getConfig' ? &get_config($cm_url, $propertyName) : &update_config($cm_url, $propertyName, $propertyValue);
								next;
							} else {
								$cm_url .= "/roleCommands/$a";
								$single_cmd = 0;
							}

							$body_content = "{ \"items\" : [\"$role_name\"] }" if $a !~ /enterMaintenanceMode|exitMaintenanceMode/;
							if ( $a =~ /moveToRoleGroup|moveToBaseGroup/ ) {
								my $role_list = &rest_call('PUT', $cm_url, 1, undef, $body_content);
								print "| Role config group updated\n";
								next;
							}
							my $cmd = $body_content ? &rest_call('POST', $cm_url, 1, undef, $body_content) : &rest_call('POST', $cm_url, 1);
							if ( $cmd->{'errors'} && @{$cmd->{'errors'}} ) {
								print "\nERROR: $cmd->{'errors'}[0]\n";
								next;
							}
							my $id = $single_cmd ? $cmd->{'id'} : $cmd->{'items'}[0]->{'id'};
							print "| CMDID: $id\n";
							if ( $trackCmd && $id != -1 ) {
								$cmd_list->{$id} = $single_cmd ? $cmd_list->{$id} = $cmd : $cmd->{'items'}[0];
							} else { 
								$single_cmd ? &cmd_id(\%{$cmd}) : &cmd_id($cmd->{'items'}[0]);
							}
						}
					}
				} # role instance
			} # roles
			&display_role_summary($role_summary, $cluster_name, $service_name, undef);
			if ( $a && $confirmed && $a =~ /rollingRestart|decommission|recommission/ ) {
				print "... $cluster_name | $service_name | ACTION: $a ";
				$cm_url .= "/commands/$a";
				if ( $a eq 'rollingRestart' ) {
					$body_content = &rolling_restart($cluster_name, $service_name);
					$rr_opts{'restartRoleNames'} = undef;
				} elsif ( $a =~ /decommission|recommission/ ) {
					$body_content = to_json($roleName_list);
				}
				my $cmd = &rest_call('POST', $cm_url, 1, undef, $body_content);
				my $id = $cmd->{'id'};
				print "| CMDID: $id\n";
				$trackCmd ? $cmd_list->{$id} = $cmd : &cmd_id(\%{$cmd});
			}
		} # service instance
	} # services
	if ( $a && $a !~ /roleTypes|getConfig/ && !$confirmed && !$list_active_commands ) {
		if ( $role_action_flag ) {
			print "# Use -confirmed or -run to execute role action '$a'\n" if $role_action_flag;
		} elsif ( $service_action_flag && !$rInfo ) {
			print "# Use -confirmed or -run to execute service action '$a'\n";
		}
	}
} # clusters

&track_cmd(\%{$cmd_list}) if keys %{$cmd_list};

sub usage {
	print "\nUsage: $0 [-help] [-version] [-d] [-cm=[hostname]:[port]] [-https] [-api=v<integer>] [-u=cm_user] [-p=cm_password]\n";
	print "\t[-cmVersion] [-cmConfig|-deployment] [-cmdId=commandId_list [-cmdAction=abort|retry]]\n";
	print "\t[-userAction=show|add|update|delete [-userName=user_name|-f=json_file -userPassword=password -userRole=user_role]]\n";
	print "\t[-hInfo[=host_info] [-hFilter=host_filter] [-hRoles] [-hChecks] [-removeFromCluster] [-deleteHost] \\\n";
	print "\t  [-setRackId=/rack_id] [-addToCluster=cluster_name] [-addRole=role_types -serviceName=service_name] [-hAction=command_name]]\n";
	print "\t[-c=cluster_name] [-s=service_name [-sChecks] [-sMetrics]] [-sFilter=service_filter]\n";
	print "\t[-rInfo[=host_id] [-r=role_type|role_name] [-rFilter=role_filter] [-rChecks] [-rMetrics] [-log=log_type]]\n";
	print "\t[-maintenanceMode[=YES|NO]] [-roleConfigGroup[=config_group_name]]\n";
	print "\t[-a[=command_name]] [-confirmed] [-trackCmd] [-run]\n";
	print "\t[-yarnApps[=parameters]]\n";
	print "\t[-impalaQueries[=parameters]]\n";
	print "\t[-mgmt] (<> -s=mgmt)\n\n";

	print "\t -help : Display usage\n";
	print "\t -version : Display version information\n";
	print "\t -d : Enable debug mode\n";
	print "\t -cm : CM hostname:port (default: localhost:7180, or 7183 if using HTTPS)\n";
	print "\t -https : Use HTTPS to communicate with CM (default: HTTP)\n";
	print "\t -api : CM API version (v<integer> | default: response from <cm>/api/version)\n";
	print "\t -u : CM user name (environment variable: \$CM_REST_USER | default: admin)\n";
	print "\t -p : CM password or path to password file (environment variable: \$CM_REST_PASS | default: admin)\n";
	print "\t      Credentials file: \$HOME/.cm_rest (set env variables using colon-separated key/value pairs)\n";
	print "\t -cmVersion : Display Cloudera Manager and default API versions\n";
	print "\t -userAction: User action\n";
	print "\t              (add|update) Create/update user\n";
	print "\t                -userName : User name\n";
	print "\t                -userPassword : User password (default: 'changeme')\n";
	print "\t                -userRole : User role (default: ROLE_USER)\n"; # List of roles -> https://cloudera.github.io/cm_api/apidocs/v16/ns0_apiUser.html
	print "\t                -f : JSON file to add users in bulk (instead of -userName)\n";
	print "\t              (delete) Delete user (args: -userName)\n";
	print "\t              (show) Display users (args: [-userName] | default: all)\n";
	print "\t -cmConfig : Save CM configuration to file\n";
	print "\t -deployment : Retrieve full description of the entire CM deployment\n";
	print "\t -cmdId : Retrieve information on asynchronous commands (comma-separated list of command IDs)\n";
	print "\t -cmdAction : Command action\n";
	print "\t              (abort) Abort a running command\n";
	print "\t              (retry) Try to rerun a command\n";
	print "\t -hInfo : Host information (regex UUID, hostname, IP, rackId | default: all)\n";
	print "\t -hFilter : Host health summary, entity status, commission state (regex)\n";
	print "\t -hRoles : Display roles associated with host\n";
	print "\t -hChecks : Host health checks\n";
	print "\t -removeFromCluster : Remove the host from a cluster (set to cluster_name for API v10 or lower)\n";
	print "\t -deleteHost : Delete the host from Cloudera Manager\n";
	print "\t -setRackId : Update the rack ID of the host\n";
	print "\t -addToCluster : Add the host to a cluster\n";
	print "\t -addRole : Create new roles. Comma-separated list of role types (args: -serviceName, [-clusterName] /for API v10 or lower/)\n";
	print "\t -hAction : Host action\n";
	print "\t            (decommission|recommission) Decommission/recommission the host\n";
	print "\t            (startRoles) Start all the roles on the host\n";
	print "\t            (enterMaintenanceMode|exitMaintenanceMode) Put/take the host into/out of maintenance mode\n";
	print "\t -c : Cluster name\n";
	print "\t -s : Service name (regex)\n";
	print "\t -r : Role type/name (regex)\n";
	print "\t -rInfo : Role information (regex UUID or set -hInfo | default: all)\n";
	print "\t -rFilter : Role state, health summary, configuration status, commission state (regex)\n";
	print "\t -sFilter : Service state, health summary, configuration status, client configuration status (regex)\n";
	print "\t -maintenanceMode : Display maintenance mode. Select hosts/services/roles based on status (YES/NO | default: all)\n";
	print "\t -roleConfigGroup : Display role config group in the role information. Select roles based on config group name (regex | default: all)\n";
	print "\t -a : Cluster/service/role action (default: list active commands)\n";
	print "\t      (stop|start|restart|refresh|...)\n";
	print "\t      (deployClientConfig) Deploy cluster-wide/service client configuration\n";
	print "\t      (decommission|recommission) Decommission/recommission roles of a service\n";
	print "\t      (enterMaintenanceMode|exitMaintenanceMode) Put/take the cluster/service/role into/out of maintenance mode\n";
	print "\t      (deleteRole) Delete a role from a given service\n";
	print "\t      (rollingRestart) Rolling restart of roles in a service. Optional arguments:\n";
 	print "\t        -restartRoleTypes : Comma-separated list of role types to restart. If not set, all startable roles are restarted (default: all)\n";
 	print "\t        -slaveBatchSize : Number of hosts with slave roles to restart at a time (default: 1)\n";
 	print "\t        -sleepSeconds : Number of seconds to sleep between restarts of slave host batches (default: 0)\n";
 	print "\t        -slaveFailCountThreshold : Number of slave host batches that are allowed to fail to restart before the entire command is considered failed (default: 0)\n";
 	print "\t        -staleConfigsOnly : Restart roles with stale configs only (default: false)\n";
 	print "\t        -unUpgradedOnly : Restart roles that haven't been upgraded yet (default: false)\n";
	print "\t      (getConfig|updateConfig) : Display/update the configuration of services/role config groups/roles\n";
	print "\t        Syntax: -a=getConfig [-propertyName=property_name] [-clientConfig] [-roleConfigGroup[=config_group_name]]\n";
	print "\t                -a=updateConfig [-roleConfigGroup=config_group_name] -propertyName=property_name [-propertyValue=property_value]\n";
	print "\t        -clientConfig : Save service client configuration to file (default: disabled)\n";
	print "\t        -roleConfigGroup : Role config group name. If empty, list role config groups for a given service (default: disabled)\n";
	print "\t        -propertyName : Configuration parameter name. Required for -updateConfig. Regex filter for -getConfig (default: all)\n";
	print "\t        -propertyValue : User-defined value. When absent, the default value (if any) will be used\n";
	print "\t        -full : Full view (default view: summary)\n";
	print "\t      (createRoleGroup) Create role config group (args: -displayName, -roleType, [-copyFromRoleGroup])\n";	# service context
	print "\t      (updateRoleGroup) Update role config group (args: -displayName, -copyFromRoleGroup)\n";		# service context
	print "\t      (deleteRoleGroup) Delete role config group\n";						# service context
	print "\t      (moveToRoleGroup) Move roles to a config group (args: -roleConfigGroup)\n";		# role context
	print "\t      (moveToBaseGroup) Move roles to the base role config group\n";				# role context
	print "\t      (addCluster) Create cluster (args: -clusterName, -displayName, -fullVersion)\n"; 
	print "\t      (updateCluster) Update cluster information (args: -displayName, -fullVersion)\n";	# cluster context
	print "\t      (deleteCluster) Delete cluster\n";							# cluster context
	print "\t      (serviceTypes) List the supported service types for a cluster\n";			# cluster context
	print "\t      (addService) Create service (args: -serviceName, -serviceType, -displayName)\n";		# cluster context
	print "\t      (updateService) Update service information (args: -displayName)\n";			# service context
	print "\t      (deleteService) Delete service\n";							# service context
	print "\t      (roleTypes) List the supported role types for a service\n";				# service context
	print "\t -confirmed : Proceed with command execution\n";
	print "\t -trackCmd : Wait for all asynchronous commands to end before exiting\n";
	print "\t -run : Shortcut for '-confirmed -trackCmd'\n";
	print "\t -sChecks : Service health checks\n";
	print "\t -sMetrics : Service metrics\n";
	print "\t -rChecks : Role health checks\n";
	print "\t -rMetrics : Role metrics\n";
	print "\t -log : Display role log (type: full, stdout, stderr /also stacks, stacksBundle for mgmt service/)\n";
	print "\t -yarnApps : Display YARN applications (example: -yarnApps='filter='executing=true'')\n";
	print "\t -impalaQueries : Display Impala queries (example: -impalaQueries='filter='user=<userName>'')\n";
	print "\t -mgmt (-s=mgmt) : Cloudera Management Service information (default: disabled)\n\n";
	exit;
}

sub rest_call {
	my ($method, $url, $ret, $fn, $bc) = @_;
	# ret:
	# 0 -> print output
	# 1 -> return output
	# 2 -> write output to file

	if ( $d ) {
		my $rest_debug_output = "---\n";
		$rest_debug_output .= " method = $method\n" if $method;
		$rest_debug_output .= " url = $url\n" if $url;
		$rest_debug_output .= " ret = $ret\n" if $ret;
		$rest_debug_output .= " fn = $fn\n" if $fn;
		$rest_debug_output .= " bc = $bc\n" if $bc;
		$rest_debug_output .= "---\n";
		print $rest_debug_output;
	}

	if ( $method =~ m/GET/i ) {
		$client->GET($url, $headers); 
	} elsif ( $method =~ m/POST/i ) {
		$client->POST($url, $bc, $headers); 
	} elsif ( $method =~ m/PUT/i ) {
		$client->PUT($url, $bc, $headers); 
	} elsif ( $method =~ m/DELETE/i ) {
		$client->DELETE($url, $headers); 
	} else {
		die "Invalid method: $method";
	}

	my $http_rc = $client->responseCode();
	my $content = $client->responseContent();

	if ( $ret == 2 ) {
		open(my $fh, '>', $fn) || die "Can't open file $fn: $!";
		print $fh $content;
		close $fh;
	} else { 
		if ( $d ) {
			foreach ( $client->responseHeaders() ) {
				print 'Header: ' . $_ . '=' . $client->responseHeader($_) . "\n";
			}
			print "Response code: $http_rc\n";
			print "Response content:\n";
		}
		print "$content\n" if ( !$ret || $http_rc !~ /2\d\d/ || $d );
		die "The request did not succeed [HTTP RC = $http_rc]\n" if $http_rc !~ /2\d\d/;
		if ( $ret ) {
			$content = from_json($content) if ( $content && $url !~ /api\/version/ );
#			print Dumper($content);
			return $content;
		}
	}
}

sub display_role_summary {
	unless ( $a || $log ) {
		my ($role_summary, $cluster_name, $service_name, $mgmt_name) = @_;
		my $output = $mgmt_name ? $mgmt_name : $service_header;
		foreach my $role ( sort keys %{$role_summary} ) {
			print "$output | $role: $role_summary->{$role}->{'instances'}";
			print " --- " if keys %{$role_summary->{$role}} > 1;
			foreach my $property ( reverse sort keys %{$role_summary->{$role}} ) {
				next if $property eq 'instances';
				foreach my $key ( sort keys %{$role_summary->{$role}->{$property}} ) {
					print "$key: $role_summary->{$role}->{$property}->{$key} ";
				}
			}
			print "\n";
		}
	}
} 

sub cmd_id {
	my $cmd = shift;
	my @cmd_properties = ('id', 'name', 'startTime', 'endTime', 'active', 'success', 'resultMessage', 'resultDataUrl', 'canRetry');
	my @cmd_refs = ('clusterRef', 'serviceRef', 'roleRef', 'hostRef', 'children');
	foreach my $property ( @cmd_properties ) {
#		print "$property: $cmd->{$property} | ";
		print "$cmd->{$property} | " if $cmd->{$property};
	}
	foreach my $ref ( @cmd_refs ) {
		if ( $ref eq 'children' ) {
			print "\n";
			if ( $cmd->{$ref}->{'items'} ) {
				foreach my $cmd_children ( sort { $a->{'id'} <=> $b->{'id'} } @{$cmd->{$ref}->{'items'}} ) {
					print "|_ ";
					&cmd_id(\%{$cmd_children});
				}
			}
		} else {
			next unless ( keys %{$cmd->{$ref}} );
#			print "($ref) ";
			foreach my $key ( keys %{$cmd->{$ref}} ) {
				if ( $ref eq 'roleRef' ) {
					next if ( $key =~ 'clusterName|serviceName' );
					my $host_name = $role_host_map->{$cmd->{$ref}->{'roleName'}} if $role_host_map->{$cmd->{$ref}->{'roleName'}};
					print "$host_name | " if $hInfo && $host_name && !$cmdId;
				}
#				print "$key: $cmd->{$ref}->{$key} ";
				print "$cmd->{$ref}->{$key} ";
			}
			print "| " unless $ref eq 'roleRef';
		}
	}
#	print Dump($cmd); # YAML
#	print Dumper($cmd);
}

sub track_cmd {
	my $cmd_list = shift;
	my $track_pause = 10; # seconds
	my $cmd_list_summary;
	my $first_iteration = 1;
	$cmd_list_summary->{'active'} = keys %{$cmd_list};
	print "Tracking $cmd_list_summary->{'active'} commands\n";
	while ( $cmd_list_summary->{'active'} ) {
		foreach my $id ( sort keys %{$cmd_list} ) {
			next if $cmd_list->{$id}->{'done'};
			unless ( $first_iteration ) {
				my $url = "$cm_api/commands/$id";
				my $cmd = &rest_call('GET', $url, 1);
				$cmd_list->{$id} = $cmd;
			}
			print "CMDID: $id --- ";
			if ( $cmd_list->{$id}->{'active'} ) {
				print "Active ($cmd_list_summary->{'active'})\n";
				&cmd_id(\%{$cmd_list->{$id}});
			} else {
				if ( $cmd_list->{$id}->{'success'} ) {
					++$cmd_list_summary->{'ok'};
					print "OK ($cmd_list_summary->{'ok'})\n";
				} else { 
					++$cmd_list_summary->{'error'};
					print "Error ($cmd_list_summary->{'error'})\n";
				}
				$cmd_list->{$id}->{'done'} = 1;
				--$cmd_list_summary->{'active'};
			}
		}
		$first_iteration = 0;
		if ( $cmd_list_summary->{'active'} ) {
			print "Checking in $track_pause seconds...\n";
			sleep $track_pause;
		}
	}
	print "# CMDID summary\n";
	if ( $cmd_list_summary->{'ok'} ) {
		print "OK: $cmd_list_summary->{'ok'}\n";
		foreach my $id ( sort keys %{$cmd_list} ) {
			&cmd_id(\%{$cmd_list->{$id}}) if $cmd_list->{$id}->{'success'};
		}
	}
	if ( $cmd_list_summary->{'error'} ) {
		print "Error: $cmd_list_summary->{'error'}\n";
		foreach my $id ( sort keys %{$cmd_list} ) {
			&cmd_id(\%{$cmd_list->{$id}}) unless $cmd_list->{$id}->{'success'};
		}
	}
}

sub rolling_restart {
	my ($cluster_name, $service_name) = @_;
	$body_content = "{ ";
	my $rr_opts_cnt = 0;
	foreach my $arg ( keys %rr_opts ) {
		++$rr_opts_cnt if $rr_opts{$arg};
	}
	foreach my $arg ( keys %rr_opts ) {
		if ( $rr_opts{$arg} ) {
			$body_content .= "\"$arg\" : ";
			if ( $arg =~ /restartRoleTypes|restartRoleNames/ ) {
				$rr_opts{$arg} =~ s/\s+//g;
				my @role_types = split /,/, uc $rr_opts{$arg}; # uppercase
				my $role_types_json = join ', ', map { qq("$_") } @role_types; # double quote
				$body_content .= "[ $role_types_json ]";
			} else {
				$body_content .= "\"$rr_opts{$arg}\"";
			}
			--$rr_opts_cnt;
			$body_content .= ", " if $rr_opts_cnt;
		}
	}
	$body_content .= " }";
	return $body_content;
}

sub get_config {
	my ($url, $name, $ret) = @_;
	$url .= "/config";
	$url .= "?view=full" if $full;
	my $config_list = &rest_call('GET', $url, 1);
	return $config_list if $ret;
	print "\n";
	foreach my $config_property ( sort { $a->{'name'} cmp $b->{'name'} } @{$config_list->{'items'}} ) {
		next if ( $name && $config_property->{'name'} !~ /$name/i );
		print "$config_property->{'name'} = ";
		if ( $config_property->{'value'} ) {
			print $config_property->{'value'}
		} else {
			print $config_property->{'default'} if $config_property->{'default'};
		}
		print "\t | $config_property->{'validationState'} " if $config_property->{'validationState'};
		print "($config_property->{'validationMessage'}) " if $config_property->{'validationMessage'};
		print "| $config_property->{'displayName'}" if $config_property->{'displayName'};
		print "\n";
	}
}

sub update_config {
	my ($url, $name, $value) = @_;
	$url .= "/config";
	$body_content = "{ \"items\" : [ { \"name\" : \"$name\" ";
	$body_content .= ", \"value\" : \"$value\" " if $value;
	$body_content .= "} ] }";
	my $config_list = &rest_call('PUT', $url, 1, undef, $body_content);
	print "| Property '$name' ";
	print $value ? "set to '$value'" : "reset";
	print "\n";
}

sub copy_from {
	my $url = shift;
	my $config = &rest_call('GET', $url, 1);
	$config = to_json($config->{'config'});
	return ", \"config\" : $config";
}

sub track_active_commands {
	my $context = shift;
	print "\n";
	$cm_url .= "/commands";
	my $items = &rest_call('GET', $cm_url, 1);
	if ( @{$items->{'items'}} ) {
		foreach my $cmd ( sort { $a->{'id'} <=> $b->{'id'} } @{$items->{'items'}} ) {
			if ( $trackCmd ) {
				my $id = $cmd->{'id'};
				print "CMDID: $id\n";
				$cmd_list->{$id} = $cmd;
			} else { &cmd_id(\%{$cmd}) }
		}
	} else { print "No active $context commands found\n" }
}
