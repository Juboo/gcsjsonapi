#!/usr/bin/perl

use strict;
use warnings;
use JSON;
use Data::Dumper;
use POSIX;
use Google::API::Client;
use OAuth2::Client;

my $service = Google::API::Client->new->build('storage', 'v1beta1');
my $secrets = 'client_secrets.json';
my $dat_file = 'token.dat';
my $auth = OAuth2::Client->new_from_client_secrets($secrets, $service->{auth_doc});
my @access_token = get_or_restore_token($dat_file, $auth);

&list_methods;
exit(0);

my($opt, $bucket, $obj) = @ARGV;
if ($bucket !~ 'edermask' && $bucket !~ 'gkubed' && $bucket !~ 'rabbimike' && $bucket !~ 'jub' && $bucket !~ 'wuboo') {
    die "Specified bucket '$bucket' does not exist!";
}
if ($opt =~ 'errything') {
    &list_errything;
}
elsif ($opt =~ 'buckets') {
    &list_buckets;
}
elsif ($opt =~ 'objects') {
    &list_objects($bucket);
}
elsif ($opt =~ 'get') {
    &list_objects($bucket);
    print 'Object: ';
    $obj = <STDIN>; chomp($obj);
    &get_objects($bucket, $obj);
}
else {
    die "Invalid argument: $opt";
}

sub list_errything {
    my $total = 0;
    my $res = $service->buckets->list(
	body => {
	    projectId => '88286670785',
	}
	)->execute({ auth_driver => $auth });

    for (my $x = 0; $x < scalar(@{$res->{items}}); $x++) {
	print "==> BUCKET: ${$res->{items}}[$x]->{id}\n";
	my $bucket = ${$res->{items}}[$x]->{id};
	my $req = $service->objects->list(
	    body => {
		bucket => "$bucket",
	    }
	    )->execute({ auth_driver => $auth });
	for (my $y = 0; $y < scalar(@{$req->{items}}); $y++) {
	    print "\t--> ${$req->{items}}[$y]->{id} ".ceil(${$req->{items}}[$y]->{media}->{length} / 1024)." KB\n";
	    $total += ${$req->{items}}[$y]->{media}->{length};
	}
    }
    print "Total size: ".ceil($total / 1024)." KB\n";
}

sub list_buckets {
    my $res = $service->buckets->list(
	body => {
	    projectId => '88286670785',
	}
	)->execute({ auth_driver => $auth });

    # print Dumper($res);
    for (my $x = 0; $x < scalar(@{$res->{items}}); $x++) {
	print ${$res->{items}}[$x]->{id}."\n";
    }
}

sub list_objects {
    my $bucket = shift;
    my $res = $service->objects->list(
	body => {
	    bucket => "$bucket",
	}
	)->execute({ auth_driver => $auth });

    # print Dumper($res);
    for (my $x = 0; $x < scalar(@{$res->{items}}); $x++) {
    print ${$res->{items}}[$x]->{id}." ".ceil(${$res->{items}}[$x]->{media}->{length} / 1024)." KB\n";
    }
}

sub get_objects {
    my($bucket, $obj) = @_;
    my $res = $service->objects->get(
	body => {
	    bucket => $bucket,
	    object => $obj,
	}
	)->execute({ auth_driver => $auth });
    my @filename = split('/', $obj);
    open(FILE, ">$filename[-1]") || die "$filename[-1]: $!";
    binmode FILE; # for MSDOS derivations.
    print FILE $res;
    close(FILE);
    print "$filename[-1] saved in current directory.\n";
}

sub list_methods {
    my $res = $service->bucketAccessControls->list(
	body => {
	    bucket => 'wuboo',
	}
	)->execute({ auth_driver => $auth });
    print Dumper($res);
}

### OAuth 2.0 shit ###
sub get_or_restore_token {
    my ($file, $auth_driver) = @_;
    my $access_token;
    if (-f $file) {
        open(my $fh, "<$file");
        if ($fh) {
            local $/;
            $access_token = JSON->new->decode(<$fh>);
            close($fh);
        }
        $auth_driver->token_obj($access_token);
    }
    else {
        my $auth_url = $auth_driver->authorize_uri;
        print "Go to the following link in your browser: $auth_url";

        print 'Enter verification code: ';
        my $code = <STDIN>; chomp($code);
        $access_token = $auth_driver->exchange($code);
    }
    return $access_token;
}

sub store_token {
    my ($file, $auth_driver) = @_;
    my $access_token = $auth_driver->token_obj;
    open(my $fh, ">$file");
    if ($fh) {
        require JSON;
        print $fh JSON->new->encode($access_token);
        close($fh);
    }
}
