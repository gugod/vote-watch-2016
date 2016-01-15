use v5.14;

use FindBin;
use JSON::PP;
use HTTP::Tiny;
use File::Path qw<make_path>;
use File::Slurp qw<write_file read_file>;

my $json = JSON::PP->new;
my $watchlist = $json->decode( scalar read_file("${FindBin::Bin}/watchlist.json") );

my $http = HTTP::Tiny->new;
for my $k (keys %$watchlist) {
    my $url = $watchlist->{$k};
    say "$k => $url";
        
    my $now = time;
    my ($sec, $min, $hour, $mday, $mon, $year) = gmtime(time);
    $year += 1900;
    $mday += 1;

    my $output_dir = "data/$k/${year}${mon}${mday}${hour}${min}${sec}";
    make_path($output_dir) unless -d $output_dir;


    my $res = $http->get($url);
    my $res_dump = $json->encode($res);
    write_file "${output_dir}/http-response.json", $res_dump;
    if ($res->{success}) {
        write_file "${output_dir}/page.html", $res->{content};        
    }
}
