#!/usr/bin/perl

use v5.12;

use strict;
use warnings;

use Mojo::UserAgent;
use Mojo::IOLoop;
use Mojolicious::Lite;

my $ua       = Mojo::UserAgent->new;
my $base     = 'http://api.metacpan.org/v0/';
my $dist     = '/RENEEB/OTRS-OPM-Analyzer-0.03/';
my $source   = $base . 'source' . $dist;
my $pod      = $base . 'pod' . $dist;

get blocking => sub {
    my $self     = shift;

    my $request  = $ua->get( $source . 'MANIFEST' );
    my $manifest = $request->res->body;

    my @files;

    LINE:
    for my $line ( split /\n/, $manifest ) {
        my ($file, $comment) = split /\s+/, $line;

        next LINE if !$file || $file !~ /p(?:m|l|od)\z/;
        push @files, $file;
    }

    my @pods;
    FILE:
    for my $file ( @files ) {
        my $pod_request = $ua->get( $pod . $file . '?content-type=text/x-pod' );
        my $pod_text    = $pod_request->res->body;

        next FILE if !$pod_text;
        next FILE if $pod_text !~ /^=head/m;

        my ($title) = $pod_text =~ m{ =head\d \s+ NAME \s+ ([^\n]+) \s+ =head }xms;

        push @pods, $title;
    }

    $self->render( json => \@pods );
};

get non_blocking => sub {
    my $self     = shift;

    my $request  = $ua->get( $source . 'MANIFEST' );
    my $manifest = $request->res->body;

    my @files;

    LINE:
    for my $line ( split /\n/, $manifest ) {
        my ($file, $comment) = split /\s+/, $line;

        next LINE if !$file || $file !~ /p(?:m|l|od)\z/;
        push @files, $file;
    }

    $self->render_later;

    my $delay = Mojo::IOLoop->delay;
    $delay->on( finish => sub {
        my ($delay, @txs) = @_;

        my @pods;

        FILE:
        for my $pod_request ( @txs ) {
            my $pod_text    = $pod_request->res->body;

            next FILE if !$pod_text;
            next FILE if $pod_text !~ /^=head/m;

            my ($title) = $pod_text =~ m{ =head\d \s+ NAME \s+ ([^\n]+) \s+ =head }xms;

            push @pods, $title;
        }

        $self->render( json => \@pods );
    });

    my @urls = map{ $pod . $_ . '?content-type=text/x-pod' }@files;
    $ua->get( $_ => $delay->begin ) for @urls;
};

app->start;

__END__
$ ./wrk -t8 -d30s -c 10 http://127.0.0.1:3000/blocking
Running 30s test @ http://127.0.0.1:3000/blocking
  8 threads and 10 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency     1.44s     1.66s    2.88s   100.00%
    Req/Sec     0.00      0.00     0.00    100.00%
  10 requests in 30.02s, 13.29KB read
  Socket errors: connect 0, read 8, write 0, timeout 101
Requests/sec:      0.33
Transfer/sec:     453.29B


$ ./wrk -t8 -d30s -c 10 http://127.0.0.1:3000/non_blocking
Running 30s test @ http://127.0.0.1:3000/non_blocking
  8 threads and 10 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency     3.47s     1.14s    5.58s    65.38%
    Req/Sec     0.00      0.00     0.00    100.00%
  79 requests in 30.02s, 92.91KB read
  Socket errors: connect 0, read 0, write 0, timeout 42
Requests/sec:      2.63
Transfer/sec:      3.10KB
