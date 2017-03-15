#!/usr/bin/perl -ws

# Copyright 2017 Mariano Dominguez
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
# Version: 4.0
# Use -help for options

use strict;
use warnings;
use REST::Client;
use MIME::Base64;
use JSON;
use Data::Dumper;
#use YAML;

BEGIN { $| = 1 }

use vars qw($help $version $d $cmVersion $users $userAction $f $https $api $sChecks $sMetrics $rChecks $rMetrics $config $u $p $cm
	$c $s $r $rInfo $rFilter $yarnApps $log $a $confirmed $cmdId $cmdAction $hInfo $hFilter $hRoles $hChecks $deployment
	$mgmt $impalaQueries $trackCmd $setRackId $deleteHost $addToCluster $removeFromCluster $hAction $run $maintenanceMode $roleConfigGroups
	$slaveBatchSize $sleepSeconds $slaveFailCountThreshold $staleConfigsOnly $unUpgradedOnly $restartRoleTypes);

if ( $version ) {
	print "Cloudera Manager Command-Line Interface\n";
	print "Author: Mariano Dominguez\n";
	print "Version: 4.0\n";
	print "Release date: 03/09/2017\n";
	exit;
}

&usage if $help;
die "-cm is not set. Use -help for options\n" unless $cm;
die "Set -maintenanceMode to YES/NO\n" if ( $maintenanceMode && $maintenanceMode !~ /1|YES|NO/ );

my %opts = ('cmdId'=>$cmdId, 'cmdAction'=>$cmdAction, 'c'=>$c, 's'=>$s, 'r'=>$r, 'rFilter'=>$rFilter, 'userAction'=>$userAction,
		'hFilter'=>$hFilter, 'log'=>$log, 'setRackId'=>$setRackId, 'addToCluster'=>$addToCluster, 'hAction'=>$hAction);
my %hInfo_opts = ('hRoles'=>$hRoles, 'hChecks'=>$hChecks, 'setRackId'=>$setRackId, 'deleteHost'=>$deleteHost,
			'addToCluster'=>$addToCluster, 'removeFromCluster'=>$removeFromCluster, 'hAction'=>$hAction);
my %rr_opts = ('slaveBatchSize'=>$slaveBatchSize, 'sleepSeconds'=>$sleepSeconds, 'slaveFailCountThreshold'=>$slaveFailCountThreshold,
		'staleConfigsOnly'=>$staleConfigsOnly, 'unUpgradedOnly'=>$unUpgradedOnly, 'restartRoleTypes'=>$restartRoleTypes, 'restartRoleNames'=>undef);

foreach ( keys %hInfo_opts ) {
	die "-$_ requires -hInfo to be set\n" if ( defined $hInfo_opts{$_} and not $hInfo );
}
foreach ( keys %rr_opts ) {
	die "-$_ requires -s to be set\n" if ( defined $rr_opts{$_} and not $s );
}
foreach ( keys %opts ) {
	die "-$_ is not set\n" if ( defined $opts{$_} && ( $opts{$_} eq '1' || $opts{$_} =~ /^\s*$/ ) );
}

if ( $cmdAction ) {
	die "-cmdAction requires -cmdId to be set\n" if not $cmdId;
	die "Command action '$cmdAction' not supported. Use -help for options\n" if $cmdAction !~ /abort|retry/;
}
if ( $userAction ) {
	die "-userAction requires -users to be set\n" if not $users;
	die "User action '$userAction' not supported. Use -help for options\n" if $userAction !~ /add|update|delete/;
}

($confirmed, $trackCmd) = (1, 1) if $run;

die "Host action '$hAction' not supported. Use -help for options\n"
		if ( $hAction && $hAction !~ /decommission|recommission|startRoles|enterMaintenanceMode|exitMaintenanceMode/ );
die "-trackCmd requires -a, -cmdId or -hAction to be set\n"
		if ( $trackCmd and not $a and not $cmdId and not $hAction );
die "-sChecks and -sMetrics require -s to be set\n" if ( ( $sChecks or $sMetrics ) and not $s );

$s = 'mgmt' if $mgmt;
$s = '^yarn' if ( $yarnApps and not $s );
$s = '^impala' if ( $impalaQueries and not $s );

my $cm_cred_file = "$ENV{'HOME'}/.cm_rest";
if ( -e $cm_cred_file ) {
	print "Credentials file $cm_cred_file found\n" if $d;
	open my $fh, '<', $cm_cred_file or die "Can't open $cm_cred_file: $!";
	my @cm_cred = grep /CM_REST_/, <$fh>;
	foreach ( @cm_cred ) {
		# colon-separated key/value pair
#		chomp;
#		my ($env_var, $env_val) = split /:/, $_, 2;
		# quote credentials containing white spaces and use the -u/-p options or the environment variables instead of the credentials file
		my ($env_var, $env_val) = $_ =~ /([^\s]*)\s*:\s*([^\s]*)/;
		$ENV{$env_var} = $env_val if ( defined $env_var && defined $env_val );
	}
	close $fh;
} else {
	print "Credentials file $cm_cred_file not found\n" if $d;
}

my $username = $u || $ENV{'CM_REST_USER'} || 'admin';
print "username = $username\n" if $d;

my $password = $p || $ENV{'CM_REST_PASS'} || 'admin';
if ( -e $password ) {
	print "Password file $password found\n" if $d;
	$password = qx/cat $password/ or die;
	chomp($password);
} else {
	print "Password file not found\n" if $d;
}

my $headers = { 'Content-Type' => 'application/json', 'Authorization' => 'Basic ' . encode_base64($username . ':' . $password) };
my $body_content;

my $cm_protocol = $https ? 'https://' : 'http://';
my ($cm_host, $cm_port) = split(/:/, $cm, 2) if $cm ne '1';
$cm_host = 'localhost' if !defined $cm_host;
$cm_port = 7180 if !defined $cm_port;
print "CM protocol = $cm_protocol\nCM host = $cm_host\nCM port = $cm_port\n" if $d;

# http://search.cpan.org/dist/libwww-perl/lib/LWP.pm
$ENV{PERL_LWP_SSL_VERIFY_HOSTNAME}=0 if $https; # disable hostname verification

# http://search.cpan.org/~kkane/REST-Client/lib/REST/Client.pm
my $client = REST::Client->new();
if ( $https ) {
	# http://search.cpan.org/~ether/libwww-perl/lib/LWP/UserAgent.pm#CONSTRUCTOR_METHODS
	$client->getUseragent()->ssl_opts( verify_hostname => 0 ); # this works without explicitly setting PERL_LWP_SSL_VERIFY_HOSTNAME to 0
	$client->getUseragent()->ssl_opts( SSL_verify_mode => 0 ); # optional?
	#$client->getUseragent()->ssl_opts( SSL_verify_mode => SSL_VERIFY_NONE ); # Bareword "SSL_VERIFY_NONE" not allowed while "strict subs" in use
}

my $cm_url = "$cm_protocol$cm_host:$cm_port/api/version";
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

my $cm_api = "$cm_host:$cm_port/api/v$api_version";
if ( $cmVersion ) {
	$cm_url = "$cm_api/cm/version";
	my $cm_version = &rest_call('GET', $cm_url, 1);
	print "CM version: $cm_version->{'version'} (API: v$api_version)\n";
	exit;
}

if ( $users ) {
	$cm_url = "$cm_api/users";
	if ( $userAction ) {
		if ( $userAction =~ /add|update/ ) {
			die "No JSON file provided: Set -f\n" unless $f;
			$body_content = do {
				local $/ = undef;
				open my $fh, "<", $f
				or die "Could not open file $f: $!\n";
				<$fh>;
			};
		}
		my $method;
		if ( $userAction eq 'add' ) {
			print "Adding users from file $f...\n";
			$method = 'POST';
		} elsif ( $userAction eq 'update' ) {
			$method = 'PUT';
			die "-update requires -users to be set to a user_name\n" if $users eq '1'; # assuming that '1' is not a valid username
			print "Updating user $users from file $f...\n";
			$cm_url .= "/$users";
		} elsif ( $userAction eq 'delete' ) {
			$method = 'DELETE';
			die "-delete requires -users to be set to a user_name\n" if $users eq '1';
			die "*** Use -confirmed to delete user $users\n" if not $confirmed;
			print "Deleting user $users...\n";
			$cm_url .= "/$users";
		}
		$userAction eq 'delete' ? &rest_call($method, $cm_url, 0) : &rest_call($method, $cm_url, 0, undef, $body_content);
		exit
	}
	
	$cm_url .= "/$users" if $users ne '1';
	my $user_list = &rest_call('GET', $cm_url, 1);
	if ( $users eq '1' ) {
		for ( my $i=0; $i < @{$user_list->{'items'}}; $i++ ) {
			my $user_name = $user_list->{'items'}[$i]->{'name'};
			my $user_roles = $user_list->{'items'}[$i]->{'roles'};
			print "$user_name : @$user_roles\n";
		}
	} else {
		my $user_name = $user_list->{'name'};
		my $user_roles = $user_list->{'roles'};
		print "$user_name : @$user_roles\n";
	}
	exit;
}

if ( $config && !$s ) {
	print "Retrieving Cloudera Manager settings...\n";
	$cm_url = "$cm_api/cm/config?view=full";
	my $filename = "$cm_host\_cm\_config";
	&rest_call('GET', $cm_url, 2, $filename);
	exit;
}

if ( $deployment ) {
	print "Retrieving full description of the entire CM deployment...\n";
	$cm_url = "$cm_api/cm/deployment";
	my $filename = "$cm_host\_cm\_deployment";
	&rest_call('GET', $cm_url, 2, $filename);
	exit;
}

my $cmd_list;
if ( $cmdId ) {
	my $cmd;
	$cm_url = "$cm_api/commands/$cmdId";
	if ( $cmdAction ) {
		$cm_url .= "/$cmdAction";
		$cmd = &rest_call('POST', $cm_url, 1);
	} else {
		$cmd = &rest_call('GET', $cm_url, 1);
	}

	if ( $trackCmd ) {
		$cmd_list->{$cmd->{'id'}} = $cmd;
		&track_cmd(\%{$cmd_list});
	} else {
		&cmd_id(\%{$cmd})
	}
	exit;
}

$hInfo = '.' if ( ( defined $hInfo && $hInfo eq '1' ) || ( !defined $hInfo && $hFilter ) );
my $list_active_commands = 1 if ( $a and $a eq '1' );
my @clusters;
my $uuid_host_map = {};
my $role_host_map = {};
if ( defined $hInfo ) {
	my $role_info_flag = 1 if ( defined $rInfo || $a );
	my $hInfo_match = 1;
	my $hInfo_output;
	$hRoles = 1 if ( ( $c && $api_version <= 10 ) || $s || $r );
	undef $rInfo if defined $rInfo;

	if ( $hInfo eq '.' and $a and not $s and not $r ) {
		print "When executing a role action, specify a value for -hInfo or set -s or -r; use a cluster/service action otherwise\n";
		exit;
	}

	$cm_url = "$cm_api/hosts?view=full";
	my $hosts = &rest_call('GET', $cm_url, 1);
	my @services;
	my $host_summary;
	for ( my $i=0; $i < @{$hosts->{'items'}}; $i++ ) {
#		$hInfo_match = 0 if ( ( $c && $api_version <= 10 ) || $s || $r );
		$hInfo_match = 0 if $hRoles;
		my $host_id = $hosts->{'items'}[$i]->{'hostId'};
		my $host_name = $hosts->{'items'}[$i]->{'hostname'};
		my $ip = $hosts->{'items'}[$i]->{'ipAddress'};
		my $rack_id = $hosts->{'items'}[$i]->{'rackId'};
		my ($host_health, $host_maintenance_mode, $host_commission_state, $cluster_name, $host_status);
		if ( $api_version > 1 ) {
			$host_health = $hosts->{'items'}[$i]->{'healthSummary'};
			$host_maintenance_mode = $hosts->{'items'}[$i]->{'maintenanceMode'} ? 'YES' : 'NO';
			$host_commission_state = $hosts->{'items'}[$i]->{'commissionState'};
		}
		if ( $api_version > 10 ) {
			$cluster_name = $hosts->{'items'}[$i]->{'clusterRef'}->{'clusterName'} // 'No cluster';
			$host_status = $hosts->{'items'}[$i]->{'entityStatus'};
		}

		next if ( $c && $api_version > 10 && $cluster_name ne $c );
		next unless ( $host_name =~ /$hInfo/ || $ip =~ /$hInfo/ || $rack_id =~ /$hInfo/
				|| ( defined $cluster_name && $cluster_name eq $hInfo )
				|| $host_id =~ /$hInfo/ );

		if ( $hFilter ) {
			next unless ( ( defined $host_health && $host_health =~ /$hFilter/i )
				|| ( defined $host_status && $host_status =~ /$hFilter/i )
				|| ( defined $host_commission_state && $host_commission_state =~ /$hFilter/i ) );
		}
		next if ( defined $host_maintenance_mode
				&& defined $maintenanceMode
				&& $maintenanceMode ne '1'
				&& $host_maintenance_mode ne $maintenanceMode );

		my $cluster_flag = 1;
		if ( $role_info_flag and not $c and not $hRoles ) {
			unless ( not defined $cluster_name
					or grep { $_ eq $cluster_name } @clusters
				 	or $cluster_name eq 'No cluster' ) {
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
					next if ( $c and not defined $cluster_name );
					if ( $c && $cluster_name ne $c ) { next } else { $hInfo_match = 1 if ( not $s and not $r ) };
					if ( $s && $service_name !~ /$s/i ) { next } else { $hInfo_match = 1 if not $r };
					if ( $hRoles ) {
						my $role_name = $sorted[$j]->{'roleName'};
						if ( $r && $role_name !~ /$r/i ) { next } else { $hInfo_match = 1 };
						unless ( $role_info_flag ) {
							$hInfo_output .= "$host_name";
							$hInfo_output .= " | $cluster_name" if defined $cluster_name;
							$hInfo_output .= " | $service_name";
							$hInfo_output .= " | $role_name\n";
						}
					}
					if ( $role_info_flag and not $s ) {
						push @services, $service_name unless grep { $_ eq $service_name } @services;
					}
					if ( $role_info_flag and not $c and $cluster_flag ) {
						unless ( not defined $cluster_name or grep { $_ eq $cluster_name } @clusters ) {
							push @clusters, $cluster_name;
							$cluster_flag = 0;
						}
					}
				}
			} else {
				$hInfo_output .= "$host_name | No roles\n" if $hRoles;
				$hInfo_match = 1 if ( $s and $s eq 'No roles' );
			}
		}

		next unless $hInfo_match;
		$uuid_host_map->{$host_id} = $host_name;
		++$host_summary->{'host_health'}->{$host_health} if ( $api_version > 1 && $host_health ne 'GOOD' );
		++$host_summary->{'host_status'}->{$host_status} if ( $api_version > 10 && $host_status ne 'GOOD_HEALTH' );
		++$host_summary->{'host_commission_state'}->{$host_commission_state} if ( $api_version > 1 && $host_commission_state ne 'COMMISSIONED' );
		print $hInfo_output;

		if ( $confirmed ) {
			$cm_url = "$cm_api/hosts/$host_id";
			my ($host, $host_ref);
			if ( $setRackId ) {
				$body_content = "{ \"rackId\" : \"$setRackId\" }";
				$host = &rest_call('PUT', $cm_url, 1, undef, $body_content);
				print "$host_name | rackId set to '$setRackId'\n";
			} elsif ( $deleteHost ) {
				$host = &rest_call('DELETE', $cm_url, 1);
				print "$host_name | Deleted from the system\n";
			}

			if ( $addToCluster ) {
				$cm_url = "$cm_api/clusters/$addToCluster/hosts";
				$body_content = "{ \"items\" : [\"$host_id\"] }";
				$host_ref = &rest_call('POST', $cm_url, 1, undef, $body_content);
				print "$host_name | Added to '$addToCluster'\n";
			} elsif ( $removeFromCluster ) {
				$cluster_name = $removeFromCluster if $api_version < 11;
				if ( $cluster_name ne 'No cluster' ) {
					$cm_url = "$cm_api/clusters/$cluster_name/hosts/$host_id";
					$host_ref = &rest_call('DELETE', $cm_url, 1);
					print "$host_name | ";
					print $host_ref ? "Removed from '$cluster_name'" : "hostId '$host_id' is not associated with '$cluster_name'";
					print "\n";
				} else {
					print "$host_name | hostId '$host_id' is not associated with any cluster\n";
				}
			}

			if ( $hAction ) {
				print "$host_name | ACTION: $hAction ";
				if ( $hAction eq 'decommission' ) {
					$cm_url = "$cm_api/cm/commands/hostsDecommission"
				} elsif ( $hAction eq 'recommission' ) {
					$cm_url = "$cm_api/cm/commands/hostsRecommission";
				} elsif ( $hAction eq 'startRoles' ) {
					$cm_url = "$cm_api/cm/commands/hostsStartRoles";
				} elsif ( $hAction eq 'enterMaintenanceMode' ) {
					$cm_url = "$cm_api/hosts/$host_id/commands/enterMaintenanceMode";
				} elsif ( $hAction eq 'exitMaintenanceMode' ) {
					$cm_url = "$cm_api/hosts/$host_id/commands/exitMaintenanceMode";
				}
				$body_content = "{ \"items\" : [\"$host_name\"] }" if $hAction =~ /decommission|recommission|startRoles/;
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
				print "$host_name | No health data\n"
			}
		}
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

	if ( not $confirmed ) {
		if ( $setRackId ) {
			print "*** Use -confirmed to update the rackId to '$setRackId' for the selected hosts\n";
		} elsif ( $deleteHost ) {
			print "*** Use -confirmed to delete the selected hosts from Cloudera Manager\n";
		}
		if ( $addToCluster ) {
			print "*** Use -confirmed to add the selected hosts to '$addToCluster'\n";
		} elsif ( $removeFromCluster ) {
			print "*** Use -confirmed to remove the selected hosts from the cluster\n";
		}
	}
	if ( $hAction ) {
		print "*** Use -confirmed or -run to execute the $hAction host action\n" if not $confirmed;
		&track_cmd(\%{$cmd_list}) if keys %{$cmd_list};
	}
	foreach ( keys %hInfo_opts ) {
		exit if ( $_ !~ /hRoles|hChecks/ && $hInfo_opts{$_} );
	}
	
	if ( $role_info_flag ) {
		if ( @services and not $s ) {
			# match exact word -> wrap around \b
			$s = '\b';
			$s .= join '\b|\b', @services;
			$s .= '\b';
		}
		$rInfo = ( $hInfo ne '.' or $hFilter ) ? join '|', keys %{$uuid_host_map} : 1;
	}

#	print "@clusters\n@services\n$c\n$s\n$r\n$rInfo\n";
	exit unless $s;
	exit unless ( $rInfo && ( $c || @clusters || $s =~ /mgmt/ ) );
}

$rInfo = '.' if ( ( defined $rInfo && $rInfo eq '1' ) || ( !defined $rInfo && ( $r || $rFilter ) ) );

if ( $s && $s =~ /mgmt/ ) {
	$cm_url = "$cm_api/cm/service";
	my $mgmt_service = &rest_call('GET', $cm_url, 1);
	my $mgmt_name = $mgmt_service->{'name'};
	my $mgmt_state = $mgmt_service->{'serviceState'};
	my $mgmt_health = $mgmt_service->{'healthSummary'};
	my $mgmt_config = $mgmt_service->{'configStalenessStatus'} if $api_version > 5;
	my $mgmt_maintenance_mode = $mgmt_service->{'maintenanceMode'} ? 'YES' : 'NO' if $api_version > 1;
	print "$mgmt_name ";
	print "| $mgmt_maintenance_mode " if ( $maintenanceMode && $api_version > 1 );
	print "--- $mgmt_state $mgmt_health ";
	print $mgmt_config if $api_version > 5;
	print "\n";

	if ( $a && !defined $rInfo ) {
		my $mgmt_action = $list_active_commands ? 'list active mgmt service commands' : $a;
		if ( $list_active_commands || $confirmed ) {
			print "$mgmt_name | ACTION: $mgmt_action ";
			$cm_url = "$cm_api/cm/service/commands";
			my ($cmd, $id);
			if ( $list_active_commands ) {
				print "\n";
				my $items = &rest_call('GET', $cm_url, 1);
				if ( @{$items->{'items'}} ) {
					foreach $cmd ( sort { $a->{'id'} <=> $b->{'id'} } @{$items->{'items'}} ) {
						if ( $trackCmd ) {
							$id = $cmd->{'id'};
							print "CMDID: $id\n";
							$cmd_list->{$id} = $cmd;
						} else { &cmd_id(\%{$cmd}) }
					}
				} else {
					print "|_ No active commands found\n";
				}
			} else {
				$cm_url .= "/$a";
				$cmd = &rest_call('POST', $cm_url, 1);
				$id = $cmd->{'id'};
				print "| CMDID: $id\n";
				$trackCmd ? $cmd_list->{$id} = $cmd : &cmd_id(\%{$cmd});
			}
		} else {
			print "*** Use -confirmed or -run to execute the $mgmt_action mgmt action\n";
		}
	}

	if ( $config ) {
		print "$mgmt_name | Retrieving Cloudera Management Services configuration...\n";
		$cm_url = "$cm_api/cm/service/config?view=full";
		my $filename = "$cm_host\_mgmt\_config";
		&rest_call('GET', $cm_url, 2, $filename);
		exit;
	}

	my $mgmt_role_list;
	if ( defined $rInfo ) {
		$cm_url = "$cm_api/cm/service/roles";
		my $mgmt_roles = &rest_call('GET', $cm_url, 1);
		for ( my $i=0; $i < @{$mgmt_roles->{'items'}}; $i++ ) {
			my $host_id = $mgmt_roles->{'items'}[$i]->{'hostRef'}->{'hostId'};
			next if ( defined $hInfo and not defined $uuid_host_map->{$host_id} );
			next unless $host_id =~ qr/$rInfo/;
			my $mgmt_role_name = $mgmt_roles->{'items'}[$i]->{'name'};
			my $mgmt_role_type = $mgmt_roles->{'items'}[$i]->{'type'};
			if ( $r ) { next unless ( $mgmt_role_type =~ /$r/i || $mgmt_role_name =~ /$r/i ) };

			my $mgmt_role_state = $mgmt_roles->{'items'}[$i]->{'roleState'};
			my $mgmt_role_health = $mgmt_roles->{'items'}[$i]->{'healthSummary'};
			my $mgmt_role_config = $mgmt_roles->{'items'}[$i]->{'configStalenessStatus'} if $api_version > 5;
			my $mgmt_role_maintenance_mode = $mgmt_roles->{'items'}[$i]->{'maintenanceMode'} ? 'YES' : 'NO' if $api_version > 1;
			if ( $rFilter ) {
				next unless ( $mgmt_role_state =~ /$rFilter/i
					|| $mgmt_role_health =~ /$rFilter/i
					|| ( defined $mgmt_role_config && $mgmt_role_config =~ /$rFilter/i ) );
			}
			next if ( defined $mgmt_role_maintenance_mode
					&& defined $maintenanceMode
					&& $maintenanceMode ne '1'
					&& $mgmt_role_maintenance_mode ne $maintenanceMode );

			if ( defined $hInfo ) {
				$host_id = $uuid_host_map->{$host_id};
#				$host_id =~ s/\..*$//; # remove domain name
			}

			++$mgmt_role_list->{$mgmt_role_type}->{'instances'};
			++$mgmt_role_list->{$mgmt_role_type}->{'role_state'}->{$mgmt_role_state} unless $mgmt_role_state =~ /(NA|STARTED)/;
			++$mgmt_role_list->{$mgmt_role_type}->{'role_health'}->{$mgmt_role_health} unless $mgmt_role_health eq 'GOOD';
			++$mgmt_role_list->{$mgmt_role_type}->{'role_config'}->{$mgmt_role_config} if ( $api_version > 5 && $mgmt_role_config ne 'FRESH' );

			my $mgmt_header = "$mgmt_name | $host_id";
			print "$mgmt_header | $mgmt_role_type ";
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

			if ( $a && ( $list_active_commands || $confirmed ) ) {
				my $mgmt_role_action = $list_active_commands ? 'list active mgmt role commands' : $a;
				print "$mgmt_header | $mgmt_role_name | ACTION: $mgmt_role_action ";
				my ($cmd, $id);
				if ( $list_active_commands ) {
					print "\n";
					$cm_url = "$cm_api/cm/service/roles/$mgmt_role_name/commands";
					my $items = &rest_call('GET', $cm_url, 1);
					if ( @{$items->{'items'}} ) {
						foreach $cmd ( sort { $a->{'id'} <=> $b->{'id'} } @{$items->{'items'}} ) {
							if ( $trackCmd ) {
								$id = $cmd->{'id'};
								print "CMDID: $id\n";
								$cmd_list->{$id} = $cmd;
							} else { &cmd_id(\%{$cmd}) }
						}
					} else {
						print "|_ No active commands found\n";
					}
				} else {
					$cm_url = "$cm_api/cm/service/roleCommands/$a";
					$body_content = "{ \"items\" : [\"$mgmt_role_name\"] }";
					$cmd = &rest_call('POST', $cm_url, 1, undef, $body_content);
					if ( @{$cmd->{'errors'}} ) {
						print "\nERROR: $cmd->{'errors'}[0]\n";
						next;
					}
					$id = $cmd->{'items'}[0]->{'id'};
					print "| CMDID: $id\n";
					$trackCmd ? $cmd_list->{$id} = $cmd->{'items'}[0] : &cmd_id($cmd->{'items'}[0]);
				}
			}
		}
		print "*** Use -confirmed or -run to execute the $a role action\n" if ( $a and not $confirmed and not $list_active_commands );
		&role_summary($mgmt_role_list, undef, undef, $mgmt_name);
	}

	unless ( $s !~ /^(\\b)?mgmt\d*(\\b)?$/ ) {
		&track_cmd(\%{$cmd_list}) if keys %{$cmd_list};
		exit;
	}
}
#print "After the mgmt block...\n";

unless ( @clusters ) {
	if ( $c ) {
		push @clusters, $c;
	} else {
		print "Fetching clusters...\n" if $d;
		$cm_url = "$cm_api/clusters";
		my $cm_clusters = &rest_call('GET', $cm_url, 1);
		for ( my $i=0; $i < @{$cm_clusters->{'items'}}; $i++ ) {
			my $cluster_name = $cm_clusters->{'items'}[$i]->{'name'};
			print "Found cluster '$cluster_name'\n" if $d;
			push @clusters, $cluster_name;
		}
	}
}

# clusters
my $service_header;
foreach my $cluster_name ( @clusters ) {
	if ( $api_version > 5 && !$s && !defined $rInfo ) {
		$cm_url = "$cm_api/clusters/$cluster_name";
		my $cluster = &rest_call('GET', $cm_url, 1);
		my $cluster_name = $cluster->{'name'};
		if ( $api_version > 5 ) {
			my $cluster_display_name = $cluster->{'displayName'};
			my $cluster_maintenance_mode = $cluster->{'maintenanceMode'} ? 'YES' : 'NO' if $api_version > 1;
			my $cluster_full_version = $cluster->{'fullVersion'};
			print "$cluster_name ";
			print "| $cluster_maintenance_mode " if ( $maintenanceMode && $api_version > 1 );
			print ">>> $cluster_display_name (CDH $cluster_full_version)";
		}
		if ( $api_version > 10 ) {
			my $cluster_status = $cluster->{'entityStatus'};
			print " --- $cluster_status";
		}
		print "\n";
	}
	
	if ( $a && !$s && !defined $rInfo ) {
		my $cluster_action = $list_active_commands ? 'list active cluster commands' : $a;
		if ( $list_active_commands || $confirmed ) {
			print "$cluster_name | ACTION: $cluster_action ";
			$cm_url = "$cm_api/clusters/$cluster_name/commands";
			my ($cmd, $id);
			if ( $list_active_commands ) {
				print "\n";
				my $items = &rest_call('GET', $cm_url, 1);
				if ( @{$items->{'items'}} ) {
					foreach $cmd ( sort { $a->{'id'} <=> $b->{'id'} } @{$items->{'items'}} ) {
						if ( $trackCmd ) {
							$id = $cmd->{'id'};
							print "CMDID: $id\n";
							$cmd_list->{$id} = $cmd;
						} else { &cmd_id(\%{$cmd}) }
					}
				} else {
					print "|_ No active commands found\n";
				}
			} else {
				$cm_url .= "/$a";
				$cmd = &rest_call('POST', $cm_url, 1);
				$id = $cmd->{'id'};
				print "| CMDID: $id\n";
				if ( $trackCmd && $id != -1 ) {
					$cmd_list->{$id} = $cmd;
					&track_cmd(\%{$cmd_list});
				} else {
					&cmd_id(\%{$cmd});
				}
			}
		} else {
			print "*** Use -confirmed or -run to execute the $cluster_action cluster action\n";
			print "Set -c to specify a different cluster\n";
		}
		exit;
	}

	$cm_url = "$cm_api/clusters/$cluster_name/services";
	my $cm_services = &rest_call('GET', $cm_url, 1);
	my $service_action_flag = 0;
	# services
	for ( my $i=0; $i < @{$cm_services->{'items'}}; $i++ ) {
		my $service_name = $cm_services->{'items'}[$i]->{'name'};
		my $service_display_name = $cm_services->{'items'}[$i]->{'displayName'} if $api_version > 1;
		$service_header = "$cluster_name | $service_name";
		# service instance
		if ( !$s || $service_name =~ qr/$s/i ) {
			my $service_state = $cm_services->{'items'}[$i]->{'serviceState'};
			my $service_health = $cm_services->{'items'}[$i]->{'healthSummary'};
			my $service_maintenance_mode = $cm_services->{'items'}[$i]->{'maintenanceMode'} ? 'YES' : 'NO' if $api_version > 1;
			my ($service_config, $service_clientConfig);
			if ( $api_version > 5 ) {
				$service_config = $cm_services->{'items'}[$i]->{'configStalenessStatus'};
				$service_clientConfig = $cm_services->{'items'}[$i]->{'clientConfigStalenessStatus'};
			}

			print "$service_header ";
			if ( $api_version > 1 ) {
				print "| $service_maintenance_mode " if $maintenanceMode;
				print "| $service_display_name ";
			}
			print "--- $service_state $service_health ";
			print "$service_config $service_clientConfig" if $api_version > 5;
			print "\n";
	
			$service_action_flag = 1 if $a;
			
			if ( $config ) {
				print "$service_header | Retrieving configuration...\n";
				$cm_url = "$cm_api/clusters/$cluster_name/services/$service_name/config?view=full";
				my $filename = "$cm_host\_$cluster_name\_$service_name\_config";
				&rest_call('GET', $cm_url, 2, $filename);
				print "$service_header | Retrieving client configuration...\n";
				$cm_url = "$cm_api/clusters/$cluster_name/services/$service_name/clientConfig";
				$filename = "$cm_host\_$cluster_name\_$service_name\_client\_config.zip";
				&rest_call('GET', $cm_url, 2, $filename);
				next;
			}
			
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
					$metric_unit = "" if !defined $metric_unit;
					print "$service_header | metrics | $metric_name: $metric_value $metric_unit\n";
				}
			} else {
				$cm_url = "$cm_api/timeseries?query=select * where serviceName=$service_name";
				my $service_metrics = &rest_call('GET', $cm_url, 1);
#				print Dumper($service_metrics);
#				for ( my $i=0; $i < @{$service_metrics->{'items'}}; $i++ ) {
#				for ( my $j=0; $j < @{$service_metrics->{'items'}[$i]->{'timeSeries'}}; $j++ ) {
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
					print "$unit_numerators" if defined $unit_numerators;
					print "/$unit_denominators" if defined $unit_denominators;;
					print "\n";
				} # }
			} }

			if ( $a && !defined $rInfo && ( $list_active_commands || $confirmed ) ) {
				my $service_action = $list_active_commands ? 'list active service commands' : $a;
				print "$service_header | ACTION: $service_action ";
				$cm_url = "$cm_api/clusters/$cluster_name/services/$service_name/commands";
				my ($cmd, $id);
				if ( $list_active_commands ) {
					print "\n";
					my $items = &rest_call('GET', $cm_url, 1);
					if ( @{$items->{'items'}} ) {
						foreach $cmd ( sort { $a->{'id'} <=> $b->{'id'} } @{$items->{'items'}} ) {
							if ( $trackCmd ) {
								$id = $cmd->{'id'};
								print "CMDID: $id\n";
								$cmd_list->{$id} = $cmd;
							} else { &cmd_id(\%{$cmd}) }
						}
					} else {
						print "|_ No active commands found\n";
					}
				} else {
					$cm_url .= "/$a";
					if ( $a eq 'rollingRestart' ) {
						$body_content = &rolling_restart($cluster_name, $service_name);						
					} elsif ( $a eq 'deployClientConfig' ) {
						$body_content = '{ "items" : [] }';
					}
					$cmd = $body_content ? &rest_call('POST', $cm_url, 1, undef, $body_content) : &rest_call('POST', $cm_url, 1);
					$id = $cmd->{'id'};
					print "| CMDID: $id\n";
					if ( $trackCmd && $id != -1 ) {
						$cmd_list->{$id} = $cmd;
					} else {
						&cmd_id(\%{$cmd});
					}
				}
			}

			next unless defined $rInfo;

			$cm_url = "$cm_api/clusters/$cluster_name/services/$service_name/roles";
			my $cm_roles = &rest_call('GET', $cm_url, 1);
			# roles
			my $role_list;
			for ( my $i=0; $i < @{$cm_roles->{'items'}}; $i++ ) {
				my $host_id = $cm_roles->{'items'}[$i]->{'hostRef'}->{'hostId'};
				# role instance
				if ( $host_id =~ qr/$rInfo/ ) {
					my $role_type = $cm_roles->{'items'}[$i]->{'type'};
					my $role_name = $cm_roles->{'items'}[$i]->{'name'};
					if ( !$r || $role_type =~ /$r/i || $role_name =~ /$r/i ) {
						my $role_state = $cm_roles->{'items'}[$i]->{'roleState'};
						my $role_health = $cm_roles->{'items'}[$i]->{'healthSummary'};
						my $role_config = $cm_roles->{'items'}[$i]->{'configStalenessStatus'} if $api_version > 5;
						my $role_config_group = $cm_roles->{'items'}[$i]->{'roleConfigGroupRef'}->{'roleConfigGroupName'} if $api_version > 2;
						my ($role_commission_state, $role_maintenance_mode);
						if ( $api_version > 1 ) {
							$role_maintenance_mode = $cm_roles->{'items'}[$i]->{'maintenanceMode'} ? 'YES' : 'NO';
							$role_commission_state = $cm_roles->{'items'}[$i]->{'commissionState'};
						}
						if ( $rFilter ) {
							next unless ( $role_state =~ /$rFilter/i || $role_health =~ /$rFilter/i
								|| ( defined $role_config && $role_config =~ /$rFilter/i )
								|| ( defined $role_config_group && $role_config_group =~ /$rFilter/i )
								|| ( defined $role_commission_state && $role_commission_state =~ /$rFilter/i ) );
						}
						next if ( defined $role_maintenance_mode
								&& defined $maintenanceMode
								&& $maintenanceMode ne '1'
								&& $role_maintenance_mode ne $maintenanceMode );
						next if ( defined $role_config_group
								&& defined $roleConfigGroups
								&& $roleConfigGroups ne '1'
								&& $role_config_group !~ /$roleConfigGroups/i );

						if ( defined $hInfo ) {
							$host_id = $uuid_host_map->{$host_id};
#							$host_id =~ s/\..*$//; # remove domain name
							$role_host_map->{$role_name} = $host_id;
						}

						++$role_list->{$role_type}->{'instances'};
						++$role_list->{$role_type}->{'role_state'}->{$role_state} unless $role_state =~ /(NA|STARTED)/;
						++$role_list->{$role_type}->{'role_health'}->{$role_health} unless $role_health eq 'GOOD';
						++$role_list->{$role_type}->{'role_config'}->{$role_config} if ( $api_version > 5 && $role_config ne 'FRESH' );
						++$role_list->{$role_type}->{'role_commission_state'}->{$role_commission_state} if ( $api_version > 1 && $role_commission_state ne 'COMMISSIONED' );

						my $role_header = "$service_header | $host_id | $role_type";
						print "$role_header | ";
						print "$role_config_group | " if ( $roleConfigGroups && $api_version > 2 );
						if ( $api_version > 1 ) {
							print "$role_maintenance_mode | " if $maintenanceMode;
							print "$role_commission_state | ";
						}
						print "$role_name --- $role_state $role_health ";
						print $role_config if $api_version > 5;
						print "\n";

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
								$metric_unit = "" if !defined $metric_unit;
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
								print "$unit_numerators" if defined $unit_numerators;
								print "/$unit_denominators" if defined $unit_denominators;;
								print "\n";
								}
						} }

						if ( $log ) {
							if ( $log =~ /^(stdout|stderr|full)$/ ) {
								print "Retrieving $log log...\n\n";
#								my $cluster_name_w_spaces = $cluster_name;
#								$cluster_name_w_spaces =~ s/ /%20/g;
								# curl call (if https, add -k to allow connections to SSL sites without certs)
#								$cm_url = "http://$username:\'$password\'\@$cm_api/clusters/$cluster_name_w_spaces/services/$service_name/roles/$role_name/logs/$log";
								$cm_url = "$cm_api/clusters/$cluster_name/services/$service_name/roles/$role_name/logs/$log";
								&rest_call('GET', $cm_url, 0);
							} else { 
								print "Unknown log type: $log\n";
							}
						}

						if ( $a && ( $list_active_commands || $confirmed ) ) {
							my $role_action = $list_active_commands ? 'list active role commands' : $a;
							print "$service_header | $host_id | $role_name | ACTION: $role_action " unless $a eq 'rollingRestart';
							$cm_url = "$cm_api/clusters/$cluster_name/services/$service_name";
							my ($cmd, $id);
							my $single_cmd = 1;
							if ( $list_active_commands ) {
								print "\n";
								$cm_url .= "/roles/$role_name/commands";
								my $items = &rest_call('GET', $cm_url, 1);
								if ( @{$items->{'items'}} ) {
									foreach $cmd ( sort { $a->{'id'} <=> $b->{'id'} } @{$items->{'items'}} ) {
										if ( $trackCmd ) {
											$id = $cmd->{'id'};
											print "CMDID: $id\n";
											$cmd_list->{$id} = $cmd;
										} else { &cmd_id(\%{$cmd}) }
									}
								} else {
									print "|_ No active commands found\n";
								}
								next;
							} elsif ( $a eq 'rollingRestart' ) {
								$rr_opts{'restartRoleNames'} .= "$role_name,";
								next;
							} elsif ( $a =~ /decommission|recommission/ ) {
								$cm_url .= "/commands/$a";
							} elsif ( $a =~ /enterMaintenanceMode|exitMaintenanceMode/ ) {
								$cm_url = "$cm_api/clusters/$cluster_name/services/$service_name/roles/$role_name/commands/$a";
							} else {
								$cm_url .= "/roleCommands/$a";
								$single_cmd = 0;
							}

							$body_content = "{ \"items\" : [\"$role_name\"] }" if $a !~ /enterMaintenanceMode|exitMaintenanceMode/;
							$cmd = $body_content ? &rest_call('POST', $cm_url, 1, undef, $body_content) : &rest_call('POST', $cm_url, 1);
							if ( defined $cmd->{'errors'} && @{$cmd->{'errors'}} ) {
								print "\nERROR: $cmd->{'errors'}[0]\n";
								next;
							}
							$id = $single_cmd ? $cmd->{'id'} : $cmd->{'items'}[0]->{'id'};
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
			print "*** Use -confirmed or -run to execute the $a role action\n" if ( $a and not $confirmed and not $list_active_commands );
			&role_summary($role_list, $cluster_name, $service_name, undef);
			if ( $a && $confirmed && $a eq 'rollingRestart' ) {
				print "$cluster_name | $service_name | ACTION: $a ";
				$body_content = &rolling_restart($cluster_name, $service_name);
				my $cmd = &rest_call('POST', $cm_url, 1, undef, $body_content);
				my $id = $cmd->{'id'};
				print "| CMDID: $id\n";
				$trackCmd ? $cmd_list->{$id} = $cmd : &cmd_id(\%{$cmd});
				$rr_opts{'restartRoleNames'} = undef;
			}
		} # service instance
	} # services
	print "*** Use -confirmed or -run to execute the $a service action\n" if $a and $service_action_flag
									and not defined $rInfo
									and not $confirmed
									and not $list_active_commands;
} # clusters

&track_cmd(\%{$cmd_list}) if keys %{$cmd_list};

sub usage {
	print "\nUsage: $0 [-help] [-version] [-d] -cm[=hostname[:port] [-https] [-api[=v<integer>]] [-u=username] [-p=password]\n";
	print "\t[-cmVersion] [-config] [-deployment] [-cmdId=command_id [-cmdAction=abort|retry] [-trackCmd]]\n";
	print "\t[-users[=user_name] [-userAction=delete|(add|update -f=json_file)]]\n";
	print "\t[-hInfo[=...] [-hFilter=...] [-hRoles] [-hChecks] [-setRackId=/...|-deleteHost] \\\n";
	print "\t\t[-addToCluster=cluster_name|-removeFromCluster] [-hAction=command_name]]\n";
	print "\t[-c=cluster_name] [-s=service_name [-sChecks] [-sMetrics]]\n";
	print "\t[-rInfo[=host_id] [-r=role_type|role_name] [-rFilter=...] [-rChecks] [-rMetrics] [-log=log_type]]\n";
	print "\t[-maintenanceMode[=YES|NO]] [-roleConfigGroups[=config_group_name]]\n";
	print "\t[-a[=command_name]] [[-confirmed [-trackCmd]]|-run]\n";
	print "\t[-yarnApps[=parameters]]\n";
	print "\t[-impalaQueries[=parameters]]\n";
	print "\t[-mgmt] (<> -s=mgmt)\n\n";

	print "\t -help : Display usage\n";
	print "\t -version : Display version information\n";
	print "\t -d : Enable debug mode\n";
	print "\t -cm : CM hostname:port (default: localhost:7180)\n";
	print "\t -https : Use https to communicate with CM (default: http)\n";
	print "\t -api : CM API version -> v<integer> (default: response from <cm>/api/version)\n";
	print "\t -u : CM username (environment variable: \$CM_REST_USER | default: admin)\n";
	print "\t -p : CM password or path to password file (environment variable: \$CM_REST_PASS | default: admin)\n";
	print "\t      *Credendials file* \$HOME/.cm_rest -> Set variables using colon-separated key/value pairs\n";
	print "\t -cmVersion : Display Cloudera Manager and default API versions\n";
	print "\t -users : Display CM users/roles (default: all)\n";
	print "\t -userAction: User action\n";
	print "\t              (add) Create user (requires -f)\n";
	print "\t              (update) Update user (requires -f)\n";
	print "\t              (delete) Delete user\n";
	print "\t -f: JSON file with user information\n";
	print "\t -config : Dump configuration to file (CM, Cloudera Management Service and, if -s is set, specific services)\n";
	print "\t -deployment : Retrieve full description of the entire CM deployment\n";
	print "\t -cmdId : Retrieve information on an asynchronous command\n";
	print "\t -cmdAction : Command action\n";
	print "\t            (abort) Abort a running command\n";
	print "\t            (retry) Try to rerun a command\n";
	print "\t -hInfo : Host information (regex UUID, hostname, IP, rackId, cluster) | default: all)\n";
	print "\t -hFilter : Host health summary, entity status, commission state (regex)\n";
	print "\t -hRoles : Roles associated to host\n";
	print "\t -hChecks : Host health checks\n";
	print "\t -setRackId : Update the rack ID for the host\n";
	print "\t -deleteHost : Delete the host from Cloudera Manager\n";
	print "\t -addToCluster : Add the host to a cluster\n";
	print "\t -removeFromCluster : Remove the host from a cluster (set to cluster_name if using API v10 or lower)\n";
	print "\t -hAction : Host action\n";
	print "\t            (decommission|recommission) Decommission/recommission the host\n";
	print "\t            (startRoles) Start all the roles on the host\n";
	print "\t            (enterMaintenanceMode|exitMaintenanceMode) Put/take the host into/out of maintenance mode\n";
	print "\t -c : Cluster name\n";
	print "\t -s : Service name (regex)\n";
	print "\t -r : Role type/name (regex)\n";
	print "\t -rInfo : Role information (regex UUID or set -hInfo | default: all)\n";
	print "\t -rFilter : Role state, health summary, configuration status, commission state (regex)\n";
	print "\t -maintenanceMode : Display maintenance mode. Select hosts/roles based on status (default: all -YES/NO-)\n";
	print "\t -roleConfigGroups : Display role configuration group. Select roles based on group names (default: all -regex-) \n";
	print "\t -a : Cluster/service/role action (default: list active commands)\n";
	print "\t      (stop|start|restart|...)\n";
	print "\t      (deployClientConfig) Deploy cluster-wide/service client configuration\n";
	print "\t      (decommission|recommission) Decommission/recommission roles of a service\n";
	print "\t      (enterMaintenanceMode|exitMaintenanceMode) Put/take the cluster/service/role into/out of maintenance mode\n";
	print "\t      (rollingRestart) Rolling restart of roles in a service. Optional arguments:\n";
 	print "\t      -restartRoleTypes : Comma-separated list of role types to restart. If not specified, all startable roles are restarted (default: all)\n";
 	print "\t      -slaveBatchSize : Number of hosts with slave roles to restart at a time (default: 1)\n";
 	print "\t      -sleepSeconds : Number of seconds to sleep between restarts of slave host batches (default: 0)\n";
 	print "\t      -slaveFailCountThreshold : Number of slave host batches that are allowed to fail to restart before the entire command is considered failed (default: 0)\n";
 	print "\t      -staleConfigsOnly : Restart roles with stale configs only (default: false)\n";
 	print "\t      -unUpgradedOnly : Restart roles that haven't been upgraded yet (default: false)\n";
	print "\t -confirmed : Proceed with the command execution\n";
	print "\t -trackCmd : Display the result of all executed asynchronous commands before exiting\n";
	print "\t -run : Shortcut for '-confirmed -trackCmd'\n";
	print "\t -sChecks : Service health checks\n";
	print "\t -sMetrics : Service metrics\n";
	print "\t -rChecks : Role health checks\n";
	print "\t -rMetrics : Role metrics\n";
	print "\t -log : Display role log (type: full, stdout, stderr -stacks, stacksBundle for mgmt service-)\n";
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
		my $rest_debug_output = "<--\n";
		$rest_debug_output .= " method = $method\n" if defined $method;
		$rest_debug_output .= " url = $url\n" if defined $url;
		$rest_debug_output .= " ret = $ret\n" if defined $ret;
		$rest_debug_output .= " fn = $fn\n" if defined $fn;
		$rest_debug_output .= " bc = $bc\n" if defined $bc;
		$rest_debug_output .= "-->\n";
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
		die "Invalid http method: $method";
	}

	my $http_rc = $client->responseCode();
	my $content = $client->responseContent();

	if ( $ret == 2 ) {
		open(my $fh, '>', $fn) or die "Could not open file $fn: $!";
		print $fh $content;
		close $fh;
	} else { 
		print "$content\n" if ( not $ret or $http_rc !~ '2\d\d' or $d );
		# Append a new line to the die string to prevent perl from adding the line number and file
		die "The HTTP request was not successfull (response code: $http_rc)" if $http_rc !~ '2\d\d';
		if ( $ret ) {
			$content = from_json($content) if ( $content && $url !~ /api\/version/ );
#			print Dumper($content);
			return $content;
		}
	}
}

sub role_summary {
	unless ( $a || $log ) {
		my ($role_list, $cluster_name, $service_name, $mgmt_name) = @_;
		my $output = defined $mgmt_name ? $mgmt_name : $service_header;
		foreach my $role ( sort keys %{$role_list} ) {
			print "$output | $role: $role_list->{$role}->{'instances'}";
			print " --- " if keys %{$role_list->{$role}} > 1;
			foreach my $property ( reverse sort keys %{$role_list->{$role}} ) {
				next if $property eq 'instances';
				foreach my $key ( sort keys %{$role_list->{$role}->{$property}} ) {
					print "$key: $role_list->{$role}->{$property}->{$key} ";
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
		print "$cmd->{$property} | " if defined $cmd->{$property};
	}
	foreach my $ref ( @cmd_refs ) {
		if ( $ref eq 'children' ) {
			print "\n";
			if ( defined $cmd->{$ref}->{'items'} ) {
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
					my $host_name = $role_host_map->{$cmd->{$ref}->{'roleName'}} if defined $role_host_map->{$cmd->{$ref}->{'roleName'}};
					print "$host_name -> " if $hInfo and defined $host_name and not $cmdId;
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
				$cm_url = "$cm_api/commands/$id";
				my $cmd = &rest_call('GET', $cm_url, 1);
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
	if ( defined $cmd_list_summary->{'ok'} ) {
		print "OK: $cmd_list_summary->{'ok'}\n";
		foreach my $id ( sort keys %{$cmd_list} ) {
			&cmd_id(\%{$cmd_list->{$id}}) if $cmd_list->{$id}->{'success'};
		}
	}
	if ( defined $cmd_list_summary->{'error'} ) {
		print "Error: $cmd_list_summary->{'error'}\n";
		foreach my $id ( sort keys %{$cmd_list} ) {
			&cmd_id(\%{$cmd_list->{$id}}) unless $cmd_list->{$id}->{'success'};
		}
	}
}

sub rolling_restart {
	my ($cluster_name, $service_name) = @_;
	$cm_url = "$cm_api/clusters/$cluster_name/services/$service_name/commands/rollingRestart";
	$body_content = "{ ";
	my $rr_opts_cnt = 0;
	foreach my $arg ( keys %rr_opts ) {
		++$rr_opts_cnt if defined $rr_opts{$arg};
	}
	foreach my $arg ( keys %rr_opts ) {
		if ( defined $rr_opts{$arg} ) {
			$body_content .= "\"$arg\" : ";
			if ( $arg =~ /restartRoleTypes|restartRoleNames/ ) {
				$rr_opts{$arg} =~ s/\s+//g;
				my @role_types = split /,/, uc $rr_opts{$arg}; # uppercase
				my $role_types_json = join ' , ', map {qq("$_")} @role_types; # double quote
				$body_content .= "[ $role_types_json ]";
			} else {
				$body_content .= "\"$rr_opts{$arg}\"";
			}
			--$rr_opts_cnt;
			$body_content .= ", " if $rr_opts_cnt;
		}
	}
	$body_content .= " }";
	print "$body_content\n" if $d;
	return $body_content;
}
