#!/usr/bin/env perl
use v5.18;use strict;use warnings;use autodie;
use utf8;
use Encode q<encode_utf8>;
use JSON::PP;
use File::Slurp qw<read_file write_file>;
use Mojo::DOM;
use File::Next;
use Time::Moment;
use List::MoreUtils qw<minmax>;

sub MAIN {
    my $json = JSON::PP->new;
    my $files = File::Next::files('data');
    while (defined( my $file = $files->() )) {
        my $mat = {};
        my @seen_t;
        my ($what) = $file =~ m{data/([^/]+)/time-series.json};
        next unless $what;
        my $series = $json->decode(scalar read_file($file, { binmode => ":utf8" }));
        for my $s (@$series) {
            my $t = $s->{target};
            for my $v (@{$s->{values}}) {
                push @seen_t, $v->[1];
                $mat->{$t}{ $v->[1] } = $v->[0];
            }
        }

        my @matrix;
        my ($min,$max) = minmax(@seen_t);
        for my $target (keys %$mat) {
            my $metric = $mat->{$target};
            my @row = ($target);
            my $last_value = 0;
            for ($min..$max) {
                my $v = $metric->{$_} // $last_value;
                push @row, $v;
                $last_value = $v;
            }
            push @matrix, \@row;
        }

        my $file_out = $file =~ s/time-series\.json\z/matrix.csv/r;
        open my $fh_out, ">", $file_out;
        for (@matrix) {
            say $fh_out join(",",@$_);
        }
        close($fh_out);
        say "==> $file_out";
    }
}
MAIN();
