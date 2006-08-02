use strict;
use warnings;
use Test::More tests => 4;

use_ok('PAR::Repository::Client');

my @tests = (
	'Math-Symbolic-0.502-x86_64-linux-gnu-thread-multi-5.8.7.par'
	=> ['Math-Symbolic', '0.502', 'x86_64-linux-gnu-thread-multi', '5.8.7'],
	'Math-Symbolic-0.502.tar.gz'
	=> ['Math-Symbolic', '0.502', undef, undef],
	'Foo-0.5.3_1-x86-win32-thread-multi-any_version'
	=> ['Foo', '0.5.3_1', 'x86-win32-thread-multi', 'any_version'],
);

my $obj = bless {} => 'PAR::Repository::Client';
while (@tests) {
	my $str = shift @tests;
	my $res = shift @tests;
	my @res = $obj->parse_dist_name($str);
	is_deeply($res, \@res, "Parsing '$str'");
}
