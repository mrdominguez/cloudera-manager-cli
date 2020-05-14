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

# Cloudera Manager REST API client
# Use -help for options

use strict;
use REST::Client;
use MIME::Base64;
use JSON;
use Data::Dumper;

use vars qw($help $version $u $p $m $d $f $i $bt $bc);

if ( $version ) {
	print "Cloudera Manager REST API client\n";
	print "Author: Mariano Dominguez\n";
	print "Version: 8.2.4\n";
	print "Release date: 05/14/2020\n";
	exit;
}

&usage if $help;
die "Argument <ResourceUrl> is missing\nUse -help for options\n" if @ARGV == 0;

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
my $method = $m || 'GET';
my $body_type = $bt || 'hash';
my $body_content = $bc || undef;

my $url = $ARGV[0];
my $https = 1 if $url =~ /^https/i;

if ( $d ) {
	print "method = $method\n";
	print "body_type = $body_type\n";
	print "url = $url\n";
}

if ( $f ) {
	my $file = $f;
	$body_type = 'json';
	$body_content = do {
	local $/ = undef;
	open my $fh, "<", $file || die "Can't open file $file: $!";
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
# LWP::Protocol::https::Socket: SSL connect attempt failed error:14090086:SSL routines:ssl3_get_server_certificate:certificate verify failed
#$ENV{PERL_LWP_SSL_VERIFY_HOSTNAME}=0 if $https; # disable hostname verification

# http://search.cpan.org/~kkane/REST-Client/lib/REST/Client.pm
my $client = REST::Client->new();
if ( $https ) {
        # http://search.cpan.org/~ether/libwww-perl/lib/LWP/UserAgent.pm#CONSTRUCTOR_METHODS
        $client->getUseragent()->ssl_opts( verify_hostname => 0 ); # or set $ENV{PERL_LWP_SSL_VERIFY_HOSTNAME}
}

if ( $method =~ m/GET/i ) {
	$client->GET($url, $headers); 
} elsif ( $method =~ m/POST/i ) {
	$client->POST($url, $body_content, $headers); 
} elsif ( $method =~ m/PUT/i ) {
	$client->PUT($url, $body_content, $headers); 
} elsif ( $method =~ m/DELETE/i ) {
	$client->DELETE($url, $headers); 
} else {
	die "Invalid method: $method";
}

my $http_rc = $client->responseCode();
my $content = $client->responseContent();

if ( $d ) {
	foreach ( $client->responseHeaders() ) {
		print 'Header: ' . $_ . '=' . $client->responseHeader($_) . "\n";
	}
	print "Response code: $http_rc\n";
	print "Response content:\n";
}
print "$content\n";
print "The request did not succeed [HTTP RC = $http_rc]\n" if $http_rc !~ /2\d\d/;

sub usage {
	print "\nUsage: $0 [-help] [-version] [-d] [-u=username] [-p=password]\n";
	print "\t[-m=method] [-bt=body_type] [-bc=body_content [-i]] [-f=json_file] <ResourceUrl>\n\n";

	print "\t -help : Display usage\n";
	print "\t -version : Display version information\n";
	print "\t -d : Enable debug mode\n";
	print "\t -u : CM username (environment variable: \$CM_REST_USER | default: admin)\n";
	print "\t -p : CM password or path to password file (environment variable: \$CM_REST_PASS | default: admin)\n";
	print "\t      Credentials file: \$HOME/.cm_rest (set env variables using colon-separated key/value pairs)\n";
	print "\t -m : Method | GET, POST, PUT, DELETE (default: GET)\n";
	print "\t -bt : Body type | array, hash, json (default: hash)\n";
	print "\t -bc : Colon-separated list of property/value pairs for a single object (use ~ as delimiter in array properties if -bt=hash)\n";
	# The above makes it possible to set comma-delimited values for properties such as 'dfs_data_dir_list'
	print "\t       To set multiple objects, use -bt=json or -f to pass a JSON file\n";
	print "\t -i : Add the 'items' property to the body content (on by default if -bt=array)\n";
	print "\t -f : JSON file containing body content (implies -bt=json)\n";
	print "\t <ResourceUrl> : URL to REST resource (example: [http://]cm_server_host:7180/api/v15/clusters)\n\n";
	exit;
}
