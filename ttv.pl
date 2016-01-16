use v5.14;

use FindBin;
use JSON::PP;
use HTTP::Tiny;
use File::Path qw<make_path>;
use File::Slurp qw<write_file read_file>;

my $now = time;
my $json = JSON::PP->new->pretty->canonical;
my $http = HTTP::Tiny->new;
my $res = $http->get("http://elect2016.ftv.com.tw/json/p.txt?_=$now");

my ($sec, $min, $hour, $mday, $mon, $year) = gmtime($now);
$year += 1900;
$mon += 1;
my $output_dir = sprintf('data/%s/%s/%04d%02d%02d%02d%02d%02d', "ttv", "p.txt.json", $year, $mon, $mday, $hour, $min, $sec);

make_path($output_dir) unless -d $output_dir;

my $res_dump = $json->encode($res);
write_file "${output_dir}/http-response.json", $res_dump;
if ($res->{success}) {
    write_file "${output_dir}/p.txt.json", $res->{content};        
}
