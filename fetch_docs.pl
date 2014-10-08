#!/usr/bin/perl

use v5.12;

use strict;
use warnings;

use Mojo::UserAgent;

my $ua       = Mojo::UserAgent->new;
my $base     = 'http://api.metacpan.org/v0/';
my $perl     = '/SHAY/perl-5.20.1/';
my $source   = $base . 'source' . $perl;
my $pod      = $base . 'pod' . $perl;
my $request  = $ua->get( $source . 'MANIFEST' );
my $manifest = $request->res->body;

my @files;

open my $fh, '>', '/tmp/fetch_docs.out';

LINE:
for my $line ( split /\n/, $manifest ) {
    my ($file, $comment) = split /\s+/, $line;

    next LINE if !$file || $file !~ /p(?:m|l|od)\z/;
    push @files, $file;
#    say $fh $file;
}


my @pods;
FILE:
for my $file ( @files ) {
    my $pod_request = $ua->get( $pod . $file . '?content-type=text/x-pod' );
    my $pod_text    = $pod_request->res->body;

    next FILE if !$pod_text;
    next FILE if $pod_text !~ /^=head/m;

    #push @pods, $pod_text;
#    say $fh $pod_text;
}

