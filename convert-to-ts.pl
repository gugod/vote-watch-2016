#!/usr/bin/env perl
use v5.18;use strict;use warnings;use autodie;
use File::Slurp qw<read_file>;
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

sub MAIN {
    my $files = File::Next::files('data');
    while (defined( my $file = $files->() )) {
        my ($what, $branch, $t) = $file =~ m{data/([^/]+)/([^/]+)/([0-9]{14})/page\.html};
        next unless $what && $branch && $t;

        # say "$what - $branch - $t --- $file";
        my $html = read_file($file, { binmode => ":utf8" });
        my $dom  = Mojo::DOM->new($html);

        open my $ts_fh, ">>", "data/${what}/time-series-graphite";
        $dom->find("tr.trT")->each(
            sub {
                my @cells = $_->find("td")->map('text')->each;
                my ($name, $value) = grep { /\d+/ } @cells;
                $value =~ s/,//;
                my $line = "${what}.${branch}.${name} ${value} " . epoch($t);
                say $ts_fh $line;
            }
        );
        close($ts_fh);
    }
}
MAIN();
