#!/usr/bin/env perl
use v5.18;use strict;use warnings;use autodie;

use JSON::PP;
use File::Slurp qw<read_file write_file>;
use Mojo::DOM;
use File::Next;
use Time::Moment;

sub epoch {
    my ($t) = @_;
    my $tm = Time::Moment->new(
        year   => substr($t, 0, 4),
        month  => substr($t, 4, 2),
        day    => substr($t, 6, 2),
        hour   => substr($t, 8, 2),
        minute => substr($t, 10, 2),
        second => substr($t, 12, 2),
        offset => 0,
    );
    return $tm->epoch;
}

sub load_number_mapping {
    my @lines = read_file("number-mapping.csv", { binmode => ":utf8" });
    return { map { split(/,/, 2)} @lines };
}

sub MAIN {
    my $metric = {};

    my $files = File::Next::files('data');
    while (defined( my $file = $files->() )) {
        my ($what, $township, $t) = $file =~ m{data/([^/]+)/([^/]+)/([0-9]{14})/page\.html};
        next unless $what && $township && $t;

        my $html = read_file($file, { binmode => ":utf8" });
        my $dom  = Mojo::DOM->new($html);

        $dom->find("tr.trT")->each(
            sub {
                my @cells = $_->find("td")->map('text')->each;
                my ($candidate, $votes) = grep { /\d+/ } @cells;
                $votes =~ s/,//;
                my $target = "${what}.${township}.${candidate}";
                my $epoch  = epoch($t);
                my $line = "${target} $epoch";
                $metric->{$what}{$target} //= {
                    target => $target,
                    what => $what,
                    township_number => $township,
                    candidate => $candidate,
                    values => []
                };
                push @{$metric->{$what}{$target}{values}}, [ $votes, $epoch ];
            }
        );
    }

    my $township_name = load_number_mapping();
    my $json = JSON::PP->new->pretty->canonical;
    for my $what (keys %$metric) {
        for my $target (keys %{$metric->{$what}}) {
            my $v = $metric->{$what}{$target};
            @{$v->{values}} = sort { $a->[1] <=> $b->[1] } @{$v->{values}};
            $v->{township_name} = $township_name->{ $v->{township_number} };
        }
        my $metric_list = [ map { $metric->{$what}{$_} } sort { $a cmp $b } keys %{$metric->{$what}} ];
        my $json_text = $json->encode($metric_list);
        write_file("data/$what/time-series.json", \$json_text);

        open my $ts_fh, ">", "data/${what}/time-series-graphite";
        for (@$metric_list) {
            my $target = $_->{target};
            for (@{$_->{values}}){
                my ($value, $t) = ($_->[0], $_->[1]);
                say $ts_fh "$target $value $t";
            }
        }
        close($ts_fh);
    }
}
MAIN();
