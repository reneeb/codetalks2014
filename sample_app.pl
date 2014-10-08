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
