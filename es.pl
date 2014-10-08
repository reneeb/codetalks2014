#!/usr/bin/perl

use strict;
use warnings;

use Search::Elasticsearch;

my $es =  Search::Elasticsearch->new(
    cxn_pool   => 'Static::NoPing',
    nodes      => 'api.metacpan.org'
);

my $scroller = $es->scroll_helper(
    search_type => 'scan',
    scroll      => '5m',
    index       => 'v0',
    type        => 'file',
    size        => 5_000,
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

my $ctr = 0;
while ( my $result = $scroller->next ) {
    print $result->{fields}->{name}, '//',
          $result->{fields}->{path}, '//',
          $result->{fields}->{distribution}, '//',
          $result->{fields}->{release}, $/;

    $ctr++;
}

print $ctr,"\n";
