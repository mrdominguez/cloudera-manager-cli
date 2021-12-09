#!/usr/bin/perl -ws

# Copyright 2021 Mariano Dominguez
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

# Cloudera Manager REST API client
# Use -help for options

use strict;
use REST::Client;
use MIME::Base64;
use JSON;
use Data::Dumper;
use IO::Prompter;

use vars qw($help $version $d $u $p $https $cm $noredirect $noauth $m $bt $bc $i $f $dumper $r);

if ( $version ) {
	print "Cloudera Manager REST API client\n";
	print "Author: Mariano Dominguez\n";
	print "Version: 10.5\n";
	print "Release date: 2021-12-09\n";
	exit;
}

&usage if $help;
die "Set -r\nUse -help for options\n" if !$r;

my $cm_cred_file = "$ENV{'HOME'}/.cm_rest";
print "Credentials file $cm_cred_file " if $d;

if ( -e $cm_cred_file ) {
	print "found\n" if $d;
	open my $fh, '<', $cm_cred_file or die "Can't open file $cm_cred_file: $!\n";
	my @cm_cred = grep /CM_REST_/, <$fh>;
	foreach ( @cm_cred ) {
		# Colon-separated key/value pair
		# For credentials containing white spaces, use quotes and -u|-p options
		# or environment variables instead of the credentials file
		my ($env_var, $env_val) = $_ =~ /([^\s]+)\s*:\s*([^\s]+)/;
		$ENV{$env_var} = $env_val if ( defined $env_var && defined $env_val );
	}
	close $fh;
} else {
	print "not found\n" if $d;
}

if ( $d ) {
	print "CM_REST_USER = $ENV{CM_REST_USER}\n" if $ENV{CM_REST_USER};
	print "CM_REST_PASS is set\n" if $ENV{CM_REST_PASS};
}

if ( $u && $u eq '1' ) {
	$u = prompt 'Username [admin]:', -in=>*STDIN, -timeout=>30, -default=>'admin';
	die "Timed out\n" if $u->timedout;
	print "Using default username\n" if $u->defaulted;
}

my $cm_user = $u || $ENV{'CM_REST_USER'} || 'admin';
print "username = $cm_user\n" if $d;

if ( $p && $p eq '1' ) {
	$p = prompt 'Password [admin]:', -in=>*STDIN, -timeout=>30, -default=>'admin', -echo=>'';
	die "Timed out\n" if $p->timedout;
	print "Using default password\n" if $p->defaulted;
}

my $cm_password = $p || $ENV{'CM_REST_PASS'} || 'admin';
print "Password file " if $d;
if ( -e $cm_password ) {
	print "$cm_password found\n" if $d;
	$cm_password = qx/cat $cm_password/ || die "Can't get password from file $cm_password\n";
	chomp($cm_password);
} else {
	print "not found\n" if $d;
}

my $scheme = $https ? 'https' : 'http';
my ($cm_host, $cm_port) = split(/:/, $cm, 2) if ( $cm && $cm ne '1' );

$cm_host = 'localhost' unless $cm_host;
unless ( $cm_port ) {
	$cm_port = $https ?  7183 : 7180
}
$r = $2 if $r =~ /(\/*)(.*)/; # Remove leading slashes if any

my $url = "$scheme://$cm_host:$cm_port";
$url .= "/$r" if $r;

my $headers = { 'Content-Type' => 'application/json' };
$headers->{'Authorization'} = 'Basic ' . encode_base64($cm_user . ':' . $cm_password) unless $noauth;

my $method = $m || 'GET';
my $body_type = $bt || 'hash';
my $body_content = $bc || undef;

if ( $d ) {
	print "method = $method\n";
	print "body_type = $body_type\n";
	print "url = $url\n";
}

if ( $f ) {
	my $filename = $f;
	$body_type = 'json';
	$body_content = do {
		local $/ = undef;
		open my $fh, '<', $filename or die "Can't open file $filename: $!\n";
		<$fh>;
	}
}

$body_content = "{ \"items\" \: $body_content }" if ( !$f && $i && $body_type eq 'json' );

if ( defined $body_content && $body_type ne 'json' ) {
	$body_content =~ s/\s+//g; # remove whitespaces
	my @items = split /:/, $body_content;
	my %item_pairs;
	my %bc;
	if ( $body_type eq 'hash' ) {
		%item_pairs = @items;
		foreach my $property ( keys(%item_pairs) ) {
			if ( $item_pairs{$property} =~ /~/ ) {
				print "$property is an ARRAY : $item_pairs{$property}\n" if $d;
				my @array_value = split /~/, $item_pairs{$property};
				$item_pairs{$property} = \@array_value;
			}	
		}
		my @json_array;
		push @json_array, \%item_pairs;
		%bc = $i ? ( 'items' => \@json_array ) : %item_pairs;
	} elsif ( $body_type eq 'array' ) {
		%bc = ( 'items' => \@items );
	} else {
		die "Invalid body type: $body_type";
	}
	print Dumper(\%bc) if $d;
	$body_content = to_json(\%bc);
}

if ( $d && defined $body_content ) {
	print "body_content = $body_content\n";
}

# http://search.cpan.org/dist/libwww-perl/lib/LWP.pm
#  PERL_LWP_SSL_VERIFY_HOSTNAME
#   The default verify_hostname setting for LWP::UserAgent. If not set the default will be 1. Set it as 0 to disable hostname verification (the default prior to libwww-perl 5.840).
# http://search.cpan.org/~ether/libwww-perl/lib/LWP/UserAgent.pm#CONSTRUCTOR_METHODS
#  verify_hostname => $bool
#   This option is initialized from the PERL_LWP_SSL_VERIFY_HOSTNAME environment variable. If this environment variable isn't set; then verify_hostname defaults to 1.
#$ENV{PERL_LWP_SSL_VERIFY_HOSTNAME}=0;

# SSL connect attempt failed error:14090086:SSL routines:ssl3_get_server_certificate:certificate verify failed

# http://search.cpan.org/~kkane/REST-Client/lib/REST/Client.pm
my $client = REST::Client->new();

while ( $url ) {
	$client->getUseragent()->ssl_opts( verify_hostname => 0 ) if ( $https || $url =~ /^https/i );

	if ( $method =~ m/GET/i ) {
		$client->GET($url, $headers);
	} elsif ( $method =~ m/POST/i ) {
		$client->POST($url, $body_content, $headers);
	} elsif ( $method =~ m/PUT/i ) {
		$client->PUT($url, $body_content, $headers);
	} elsif ( $method =~ m/DELETE/i ) {
		$client->DELETE($url, $headers);
	} else {
		die "Invalid method: $method\n";
	}

	my $http_rc = $client->responseCode();
	my $response_content = $client->responseContent();

	if ( $d ) {
		foreach ( $client->responseHeaders() ) {
			print 'Header: ' . $_ . '=' . $client->responseHeader($_) . "\n";
		}
		print "Response code: $http_rc\n";
		print "Response content:\n" if $response_content;
	}

	if ( $client->responseHeader('location') && !$noredirect ) {
		my $location =  $client->responseHeader('location');
		if ( $location =~ '^/' ) { $url .= $location } else { $url = $location }
		print "Redirecting to $url\n";
	} else {
		undef $url;
	}

	my $is_json;
	if ( $response_content ) {
		$is_json = eval { from_json("$response_content"); 1 };
		$is_json or print "No JSON format detected\n" if $d;
		if ( $is_json && $dumper ) {
			#use JSON::PP qw(decode_json);
			$JSON::PP::true  = 'true';
			$JSON::PP::false = 'false';
			my $decoded_json = decode_json($response_content);
			print Dumper $decoded_json;
		} else {
			print "$response_content\n";
		}
	} else {
		print "No response content\n" if $d;
	}

	print "The request did not succeed [HTTP RC = $http_rc]\n" if $http_rc !~ /2\d\d/;
}

sub usage {
	print "\nUsage: $0 [-help] [-version] [-d] [-u[=username]] [-p[=password]] [-https] [-cm=hostname[:port]]\n";
	print "\t[-noredirect] [-noauth] [-m=method] [-bt=body_type] [-bc=body_content [-i]] [-f=json_file] [-dumper] -r=rest_resource\n\n";

	print "\t -help : Display usage\n";
	print "\t -version : Display version information\n";
	print "\t -d : Enable debug mode\n";
	print "\t -u : CM username (environment variable: \$CM_REST_USER | default: admin)\n";
	print "\t -p : CM password or path to password file (environment variable: \$CM_REST_PASS | default: admin)\n";
	print "\t      Credentials file: \$HOME/.cm_rest (set env variables using colon-separated key/value pairs)\n";
	print "\t -https : Use HTTPS to communicate with CM (default: HTTP)\n";
	print "\t -cm : CM hostname:port (default: localhost:7180, or 7183 if using HTTPS)\n";
	print "\t -noredirect : Do not follow redirects\n";
	print "\t -noauth : Do not add Authorization header\n";
	print "\t -m : Method | GET, POST, PUT, DELETE (default: GET)\n";
	print "\t -bt : Body type | array, hash, json (default: hash)\n";
	print "\t -bc : Body content. Colon-separated list of property/value pairs for a single object (use ~ as delimiter in array properties if -bt=hash)\n";
	# The above makes it possible to set comma-delimited values for properties such as 'dfs_data_dir_list'
	print "\t       To set multiple objects, use -bt=json or -f to pass a JSON file\n";
	print "\t -i : Add the 'items' property to the body content (enabled by default if -bt=array)\n";
	print "\t -f : JSON file containing body content (implies -bt=json)\n";
	print "\t -dumper : Use Data::Dumper to output the JSON response content (default: disabled)\n";
	print "\t -r : REST resource|endpoint (example: /api/v15/clusters)\n\n";
	exit;
}
