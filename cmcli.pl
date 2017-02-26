#!/usr/bin/perl -ws

# Copyright 2016 Mariano Dominguez
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
# Version: 2.0
# Use -help for options

use lib qw(/home/m_dominguez/modules/share/perl5/);
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
	$mgmt $impalaQueries $trackCmd $setRackId $hAction $addToCluster);

if ( $version ) {
	print "Cloudera Manager Command-Line Interface\n";
	print "Author: Mariano Dominguez\n";
	print "Version: 2.0\n";
	print "Release date: 02/17/2017\n";
	exit;
}

&usage if $help;
die "-cm is not set. Use -help for options\n" unless $cm;

my %opts = ('cmdId'=>$cmdId, 'cmdAction'=>$cmdAction, 'c'=>$c, 's'=>$s, 'r'=>$r, 'rFilter'=>$rFilter, 'userAction'=>$userAction,
		'hFilter'=>$hFilter, 'log'=>$log, 'setRackId'=>$setRackId, 'hAction'=>$hAction, 'addToCluster'=>$addToCluster);
my %hInfo_opts = ('hRoles'=>$hRoles, 'hChecks'=>$hChecks, 'setRackId'=>$setRackId, 'addToCluster'=>$addToCluster, 'hAction'=>$hAction);

foreach ( keys %opts ) {
	die "-$_ is not set\n" if ( defined $opts{$_} && ( $opts{$_} eq '1' || $opts{$_} =~ /^\s*$/ ) );
}
foreach ( keys %hInfo_opts ) {
	die "-$_ requires -hInfo to be set\n" if ( defined $hInfo_opts{$_} and not $hInfo );
}
if ( $cmdAction ) {
	die "-cmdAction requires -cmdId to be set\n" if not $cmdId;
	die "Command action '$cmdAction' not supported. Use -help for options\n" if $cmdAction !~ /abort|retry/;
}
if ( $userAction ) {
	die "-userAction requires -users to be set\n" if not $users;
	die "User action '$userAction' not supported. Use -help for options\n" if $userAction !~ /add|update|delete/;
}
die "Host action '$hAction' not supported. Use -help for options\n"
		if ( $hAction && $hAction !~ /decommission|recommission|startRoles|enterMaintenanceMode|exitMaintenanceMode|removeFromCluster/ );
die "-trackCmd requires -a, -cmdId or -hAction to be set\n"
		if ( $trackCmd and not $a and not $cmdId and not $hAction );
die "-sChecks and -sMetrics require -s to be set\n" if ( ( $sChecks or $sMetrics ) and not $s );

$s = 'mgmt' if $mgmt;
$s = '^yarn' if ( $yarnApps && !$s );
$s = '^impala' if ( $impalaQueries && !$s );

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
print "API version: $api_version\n" if $d;

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
	if ( $cmdAction ) {
		$cm_url = "$cm_api/commands/$cmdId/$cmdAction";
#		&rest_call('POST', $cm_url, 0);
		$cmd = &rest_call('POST', $cm_url, 1);
	} else {
		$cm_url = "$cm_api/commands/$cmdId";
#		&rest_call('GET', $cm_url, 0);
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
my $action_flag = 1 if ( $a && $a ne '1' );
my @clusters;
my $uuid_host_map = {};
my $role_host_map = {};
if ( defined $hInfo ) {
	my $role_info_flag = 1 if ( defined $rInfo || $action_flag );
	my $hInfo_match = 1;
	my $hInfo_output;
	$hRoles = 1 if ( ( $c && $api_version <= 10 ) || $s || $r );
	undef $rInfo if defined $rInfo;

	if ( $hInfo eq '.' and $action_flag and not $s and not $r ) {
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
				|| ( defined $host_maintenance_mode && $host_maintenance_mode eq $hFilter )
				|| ( defined $host_commission_state && $host_commission_state =~ /$hFilter/i ) );
		}

		my $cluster_flag = 1;
		if ( $role_info_flag and not $c and not $hRoles ) {
			push @clusters, $cluster_name unless ( not defined $cluster_name
							or grep { $_ eq $cluster_name } @clusters
						 	or $cluster_name eq 'No cluster' );
			$cluster_flag = 0;
		}

		$hInfo_output = "$host_name | $host_id | $ip | $rack_id";
		if ( $api_version > 1 ) {
			$hInfo_output .= " | $host_maintenance_mode";
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
						push @clusters, $cluster_name unless ( not defined $cluster_name
										or grep { $_ eq $cluster_name } @clusters );
						$cluster_flag = 0;
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

		if ( $setRackId && $confirmed ) {
			$cm_url = "$cm_api/hosts/$host_id";
			$body_content = "{ \"rackId\" : \"$setRackId\" }";
			&rest_call('PUT', $cm_url, 0, undef, $body_content);
		}

		if ( $addToCluster && $confirmed ) {
			$cm_url = "$cm_api/clusters/$addToCluster/hosts";
			$body_content = "{ \"items\" : [\"$host_id\"] }";
			&rest_call('POST', $cm_url, 0, undef, $body_content);
		}

		if ( $hAction && $confirmed ) {
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
			} elsif ( $hAction eq 'removeFromCluster' ) {
				print "\n";
				if ( defined $cluster_name && $cluster_name ne 'No cluster' ) {
					$cm_url = "$cm_api/clusters/$cluster_name/hosts/$host_id";
					&rest_call('DELETE', $cm_url, 0);
				} else {
					print "$host_name | $host_id not associated with any cluster\n";
				}
				next;
			}
			$body_content = "{ \"items\" : [\"$host_name\"] }" if $hAction =~ /decommission|recommission|startRoles/;
			my $cmd = $body_content ? &rest_call('POST', $cm_url, 1, undef, $body_content) : &rest_call('POST', $cm_url, 1);
			my $id = $cmd->{'id'};
			print "| CMDID: $id\n";
			$trackCmd ? $cmd_list->{$id} = $cmd : &cmd_id(\%{$cmd});
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

	if ( $setRackId ) {
		print "*** Use -confirmed to update the rack ID to $setRackId\n" if not $confirmed;
		exit;
	}

	if ( $addToCluster ) {
		print "*** Use -confirmed to add hosts to $addToCluster\n" if not $confirmed;
		exit;
	}

	if ( $hAction ) {
		print "*** Use -confirmed to execute the $hAction host action\n" if not $confirmed;
		&track_cmd(\%{$cmd_list}) if keys %{$cmd_list};
		exit;
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
	print "$mgmt_name --- $mgmt_state $mgmt_health ";
	print $mgmt_config if $api_version > 5;
	print "\n";

	if ( $a && !defined $rInfo ) {
		my $mgmt_action = ( $a eq '1' ) ? 'list active Cloudera Management Services commands' : $a;
		if ( $a eq '1' || $confirmed ) {
			print "$mgmt_name | ACTION: $mgmt_action ";
			$cm_url = "$cm_api/cm/service/commands";
			my ($cmd, $id);
			if ( $a eq '1' ) {
				print "\n";
#				&rest_call('GET', $cm_url, 0);
				my $items = &rest_call('GET', $cm_url, 1);
				if ( @{$items->{'items'}} ) {
					foreach $cmd ( @{$items->{'items'}} ) {
						$id = $cmd->{'id'};
						$trackCmd ? $cmd_list->{$id} = $cmd : &cmd_id(\%{$cmd});
					}
				} else {
					print "|_ No active commands found\n";
				}
			} else {
				$cm_url .= "/$a";
#				&rest_call('POST', $cm_url, 0);
				$cmd = &rest_call('POST', $cm_url, 1);
				$id = $cmd->{'id'};
				print "| CMDID: $id\n";
				$trackCmd ? $cmd_list->{$id} = $cmd : &cmd_id(\%{$cmd});
			}
		} else {
			print "*** Use -confirmed to execute the $mgmt_action mgmt action\n";
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
			if ( $rFilter ) {
				next unless ( $mgmt_role_state =~ /$rFilter/i
					|| $mgmt_role_health =~ /$rFilter/i
					|| ( defined $mgmt_role_config && $mgmt_role_config =~ /$rFilter/i ) );
			}				

			if ( defined $hInfo ) {
				$host_id = $uuid_host_map->{$host_id};
#				$host_id =~ s/\..*$//; # remove domain name
			}

			++$mgmt_role_list->{$mgmt_role_type}->{'instances'};
			++$mgmt_role_list->{$mgmt_role_type}->{'role_state'}->{$mgmt_role_state} unless $mgmt_role_state =~ /(NA|STARTED)/;
			++$mgmt_role_list->{$mgmt_role_type}->{'role_health'}->{$mgmt_role_health} unless $mgmt_role_health eq 'GOOD';
			++$mgmt_role_list->{$mgmt_role_type}->{'role_config'}->{$mgmt_role_config} if ( $api_version > 5 && $mgmt_role_config ne 'FRESH' );

			my $mgmt_header = "$mgmt_name | $host_id";
			print "$mgmt_header | $mgmt_role_type | $mgmt_role_name --- $mgmt_role_state $mgmt_role_health ";
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

			if ( $action_flag && $confirmed ) {
				print "$mgmt_header | $mgmt_role_name | ACTION: $a ";
				$cm_url = "$cm_api/cm/service/roleCommands/$a";
				$body_content = "{ \"items\" : [\"$mgmt_role_name\"] }";
#				&rest_call('POST', $cm_url, 0, undef, $body_content);
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
		print "*** Use -confirmed to execute the $a role action\n" if $action_flag && !$confirmed;
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
		print "Looking for clusters...\n" if $d;
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
			my $cluster_full_version = $cluster->{'fullVersion'};
			print "$cluster_name >>> $cluster_display_name (CDH $cluster_full_version)";
		}
		if ( $api_version > 10 ) {
			my $cluster_status = $cluster->{'entityStatus'};
			print " --- $cluster_status";
		}
		print "\n";
	}
	
	if ( $a && !$s && !defined $rInfo ) {
		my $cluster_action = ( $a eq '1' ) ? 'list active cluster commands' : $a;
		if ( $a eq '1' || $confirmed ) {
			print "$cluster_name | ACTION: $cluster_action ";
			$cm_url = "$cm_api/clusters/$cluster_name/commands";
			my ($cmd, $id);
			if ( $a eq '1' ) {
				print "\n";
#				&rest_call('GET', $cm_url, 0);
				my $items = &rest_call('GET', $cm_url, 1);
				if ( @{$items->{'items'}} ) {
					foreach $cmd ( @{$items->{'items'}} ) {
						$id = $cmd->{'id'};
						$trackCmd ? $cmd_list->{$id} = $cmd : &cmd_id(\%{$cmd});
					}
				} else {
					print "|_ No active commands found\n";
				}
			} else {
				$cm_url .= "/$a";
#				&rest_call('POST', $cm_url, 0);
				$cmd = &rest_call('POST', $cm_url, 1);
				$id = $cmd->{'id'};
				print "| CMDID: $id\n";
				if ( $trackCmd ) {
					$cmd_list->{$id} = $cmd;
					&track_cmd(\%{$cmd_list});
				} else {
					&cmd_id(\%{$cmd});
				}
			}
		} else {
			print "*** Use -confirmed to execute the $cluster_action cluster action\n";
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
			my ($service_config, $service_clientConfig);
			if ( $api_version > 5 ) {
				$service_config = $cm_services->{'items'}[$i]->{'configStalenessStatus'};
				$service_clientConfig = $cm_services->{'items'}[$i]->{'clientConfigStalenessStatus'};
			}

			print "$service_header ";
			print "| $service_display_name " if $api_version > 1;
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

			if ( $a && !defined $rInfo && ( $a eq '1' || $confirmed ) ) {
				my $service_action = ( $a eq '1' ) ? 'list active service commands' : $a;
				print "$service_header | ACTION: $service_action ";
				$cm_url = "$cm_api/clusters/$cluster_name/services/$service_name/commands";
				my ($cmd, $id);
				if ( $a eq '1' ) {
					print "\n";
#					&rest_call('GET', $cm_url, 0);
					my $items = &rest_call('GET', $cm_url, 1);
					if ( @{$items->{'items'}} ) {
						foreach $cmd ( @{$items->{'items'}} ) {
							$id = $cmd->{'id'};
							$trackCmd ? $cmd_list->{$id} = $cmd : &cmd_id(\%{$cmd});
						}
					} else {
						print "|_ No active commands found\n";
					}
				} else {
					$cm_url .= "/$a";
					$body_content = '{ "items" : [] }' if $a eq 'deployClientConfig';
					$cmd = $body_content ? &rest_call('POST', $cm_url, 1, undef, $body_content) : &rest_call('POST', $cm_url, 1);
					$id = $cmd->{'id'};
					print "| CMDID: $id\n";
					if ( $trackCmd ) {
						$cmd_list->{$id} = $cmd;
					} else {
#						&rest_call('POST', $cm_url, 0);
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
						my $role_commission_state = $cm_roles->{'items'}[$i]->{'commissionState'} if $api_version > 1;
						if ( $rFilter ) {
							next unless ( $role_state =~ /$rFilter/i || $role_health =~ /$rFilter/i
								|| ( defined $role_config && $role_config =~ /$rFilter/i )
								|| ( defined $role_commission_state && $role_commission_state =~ /$rFilter/i ) );
						}

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
						print "$role_commission_state | " if $api_version > 1;
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

						if ( $action_flag && $confirmed ) {
							print "$service_header | $host_id | $role_name | ACTION: $a ";
							my $service_action = 1 if $a =~ /decommission|recommission/;
							if ( $service_action ) {
								$cm_url = "$cm_api/clusters/$cluster_name/services/$service_name/commands/$a";
							} else {
								$cm_url = "$cm_api/clusters/$cluster_name/services/$service_name/roleCommands/$a";
							}
							$body_content = "{ \"items\" : [\"$role_name\"] }";
							my $cmd = &rest_call('POST', $cm_url, 1, undef, $body_content);
							if ( defined $cmd->{'errors'} && @{$cmd->{'errors'}} ) {
								print "\nERROR: $cmd->{'errors'}[0]\n";
								next;
							}
							my $id = $service_action ? $cmd->{'id'} : $cmd->{'items'}[0]->{'id'};
							print "| CMDID: $id\n";
							if ( $trackCmd ) {
								$cmd_list->{$id} = $service_action ? $cmd_list->{$id} = $cmd : $cmd->{'items'}[0];
							} else { 
#								&rest_call('POST', $cm_url, 0, undef, $body_content);
								$service_action ? &cmd_id(\%{$cmd}) : &cmd_id($cmd->{'items'}[0]);
							}
						}
					}
				} # role instance
			} # roles
			print "*** Use -confirmed to execute the $a role action\n" if $action_flag && !$confirmed;
			&role_summary($role_list, $cluster_name, $service_name, undef);
		} # service instance
	} # services
	print "*** Use -confirmed to execute the $a service action\n" if $a and $a ne '1'
									and $service_action_flag
									and not defined $rInfo
									and not $confirmed;
} # clusters

&track_cmd(\%{$cmd_list}) if keys %{$cmd_list};

sub usage {
	print "\nUsage: $0 [-help] [-version] [-d] -cm[=hostname[:port] [-https] [-api[=v<integer>]] [-u=username] [-p=password]\n";
	print "\t[-cmVersion] [-config] [-deployment] [-cmdId=command_id [-cmdAction=abort|retry] [-trackCmd]]\n";
	print "\t[-users[=user_name] [-userAction=delete|(add|update -f=json_file)]]\n";
	print "\t[-c=cluster_name] [-s=service_name [-sChecks] [-sMetrics]]\n";
	print "\t[-rInfo[=host_id] [-r=role_type|role_name] [-rFilter=...] [-rChecks] [-rMetrics] [-log=log_type]]\n";
	print "\t[-hInfo[=...] [-hFilter=...] [-hRoles] [-hChecks] [-setRackId=/...] [-addToCluster=cluster_name] [-hAction=action [-trackCmd]] [-c=...] [-s=...] [-r=...]]\n";
	print "\t[-a[=action] [-confirmed] [-trackCmd]]\n";
	print "\t[-yarnApps[=parameters]]\n";
	print "\t[-impalaQueries[=parameters]]\n";
	print "\t[-mgmt] (<> -s=mgmt)\n\n";

	print "\t -help : Usage\n";
	print "\t -version : Show version information\n";
	print "\t -d : Enable debug mode\n";
	print "\t -cm : CM hostname:port (default: localhost:7180)\n";
	print "\t -https : Use https to communicate with CM (default: http)\n";
	print "\t -api : CM API version -> v<integer> (default: response from <cm>/api/version)\n";
	print "\t -u : CM username (environment variable: \$CM_REST_USER | default: admin)\n";
	print "\t -p : CM password or path to password file (environment variable: \$CM_REST_PASS | default: admin)\n";
	print "\t      *Credendials file* \$HOME/.cm_rest -> Set variables using colon-separated key/value pairs\n";
	print "\t -cmVersion : Display Cloudera Manager and default API versions\n";
	print "\t -users : Display CM users/roles (default: All users)\n";
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
	print "\t -hFilter : Host health summary, entity status, maintenance mode, commission state (regex)\n";
	print "\t -hRoles : Roles associated to host\n";
	print "\t -hChecks : Host health checks\n";
	print "\t -setRackId : Update the rack ID for the given host\n";
	print "\t -addToCluster : Add the given host to a cluster\n";
	print "\t -hAction : Host action\n";
	print "\t            (decommission) Decommission the given host\n";
	print "\t            (recommission) Recommission the given host\n";
	print "\t            (startRoles) Start all the roles on the given host\n";
	print "\t            (enterMaintenanceMode) Put the host into maintenance mode\n";
	print "\t            (exitMaintenanceMode) Take the host out of maintenance mode\n";
	print "\t            (removeFromCluster) Remove the given host from a cluster\n";
	print "\t -c : Cluster name\n";
	print "\t -s : Service name (regex)\n";
	print "\t -r : Role type/name (regex)\n";
	print "\t -rInfo : Role information (regex UUID or set -hInfo | default: all)\n";
	print "\t -rFilter : Role state, health summary, configuration status, commission state (regex)\n";
	print "\t -a : Cluster/service/role action (default: -cluster/services- list active commands, -roles- no action)\n";
	print "\t      Role decommission/recommission is supported\n";
	print "\t -confirmed : Proceed with the command execution\n";
	print "\t -trackCmd : Display the result of all executed asynchronous commands before exiting\n";
	print "\t -sChecks : Service health checks\n";
	print "\t -sMetrics : Service metrics\n";
	print "\t -rChecks : Role health checks\n";
	print "\t -rMetrics : Role metrics\n";
	print "\t -log : Display role log (type: full, stdout, stderr -stacks, stacksBundle for mgmt service-)\n";
	print "\t -yarnApps : Display YARN applications (example: -yarnApps='filter='executing=true'')\n";
	print "\t -impalaQueries : Display Impala queries (example: -impalaQueries='filter='user=<userName>'')\n";
	print "\t -mgmt (-s=mgmt) : Show Cloudera Management Service information (default: disabled)\n\n";
	exit;
}

sub rest_call {
	my ($method, $url, $ret, $fn, $bc) = @_;
	# ret:
	# 0 -> print output
	# 1 -> return output
	# 2 -> write output to file
	
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
		print "$content\n" if ( !$ret || $http_rc ne '200' || $d );
		# Append a new line to the die string to prevent perl from adding the line number and file
		die "The HTTP request was not successfull (response code: $http_rc)" if $http_rc ne '200';
		if ( $ret ) {
			$content = from_json($content) if $url !~ /api\/version/;
#			print Dumper($content);
			return $content;
		}
	}
}

sub role_summary {
	unless ( $action_flag || $log ) {
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
					print "$role_host_map->{$cmd->{$ref}->{'roleName'}} -> " if $hInfo and not $cmdId;
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
