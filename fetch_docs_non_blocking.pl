#!/usr/bin/perl

use v5.12;

use strict;
use warnings;

use Mojo::UserAgent;
use Mojo::IOLoop;

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


my $delay   = Mojo::IOLoop->delay;
my $step    = 200;
my $counter = 1;

my @pods;

while ( ( ( $counter - 1 ) * $step ) <= scalar @files ) {
    my $start   = ($counter - 1) * $step;
    my $stop    = ($counter * $step) -1;
    
    $stop = $#files if $stop > $#files;
    
    my @sublist = @files[$start .. $stop];
    $counter++;
    
    for my $file ( @sublist ) {
        my $end = $delay->begin(0);
        my $url = $pod . $file . '?content-type=text/x-pod';
 
        $ua->get( $url => sub {
            my ($ua, $pod_request) = @_;
            my $pod_text    = $pod_request->res->body;

            return if !$pod_text;
            return if $pod_text !~ /^=head/m;
        });

        $end->( $file );
    }

    Mojo::IOLoop->start 
        unless Mojo::IOLoop->is_running;
}

