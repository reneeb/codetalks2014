#!/usr/bin/perl

use strict;
use warnings;

use Search::Elasticsearch::Async;
use Promises backend => ['AnyEvent'];

my $es =  Search::Elasticsearch::Async->new(
    cxn_pool   => 'Async::Static::NoPing',
    nodes      => 'api.metacpan.org',
    cxn        => 'Mojo',
);

use Sub::Information as => 'i';
use Data::Printer;

my $r = i( $es->can( 'search' ) );
my %h;
for my $m ( qw/name package code address/ ) {
    $h{$m} = $r->$m();
}
#p %h;

my $scroller = $es->scroll_helper(
    search_type => 'scan',
    scroll      => '5m',
    es          => $es,
    index       => 'v0',
    type        => 'file',
    size        => 5_000,
    on_start    => \&on_start,
    on_error    => \&on_error,
    on_result   => \&on_result,
#    on_results  => \&on_result,
    body => {
        query => { match_all => {} },
        fields => [ qw/name path distribution release/ ],
        filter => {
            and => [
                { term   => { distribution => 'perl'       } },
                { term   => { status       => 'latest'     } },
                { term   => { directory    => 0     } },
                {
                    or => [
                        { prefix => { path => "bin" } },
                        { prefix => { path => "ext" } },
                        { prefix => { path => "cpan" } },
                        { prefix => { path => "dist" } },
                        { prefix => { path => "lib" } },
                    ],
                },
            ],
        },
    }
);

$scroller->start->then( sub{ print "Done" }, sub { print "Warn" } );

sub on_result {
    my (@results) = @_;

    open my $fh, '>>', '/tmp/es.out';
    for my $result ( @results ) {
    print $fh $result->{fields}->{name}, '//',
          $result->{fields}->{path}, '//',
          $result->{fields}->{distribution}, '//',
          $result->{fields}->{release}, $/;
    }
    close $fh;
}

sub on_error { warn shift; }
sub on_start { warn "Start\n" }


