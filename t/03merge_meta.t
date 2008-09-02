#!/usr/bin/perl -w

use strict;
use Test;
use vars '$loaded';

BEGIN { $loaded = eval { require PAR::Dist; 1 } };
BEGIN {
  my $tests = 25;
  if ($loaded) {
    my ($y_func) = PAR::Dist::_get_yaml_functions();
    if ($y_func and exists $y_func->{Load}) {
      plan tests => $tests;
      ok(1);
    }
    else {
      plan tests => 1;
      skip("Skip because no YAML loader could be found");
      exit();
    }
  }
  else {
    plan tests => $tests;
    ok(0);
    exit();
  }
}

ok (eval { require PAR::Dist; 1 });

chdir('t') if -d 't';

my @dist = (
  'data/dist1.par',
  'data/dist2.par',
);

my @tmp = map {my $f = $_; $f =~ s/^data\///; $f} @dist;

require File::Copy;
for (0..$#dist) {
  ok(-f $dist[$_]);
  ok(File::Copy::copy($dist[$_], $tmp[$_]));
}

sub cleanup {
  unlink($_) for @tmp;
}
$SIG{INT} = \&cleanup;
$SIG{TERM} = \&cleanup;
END { cleanup(); }

my %provides_expect = (
  "Math::Symbolic::Custom::Transformation" => {
    file => "lib/Math/Symbolic/Custom/Transformation.pm",
    version => "2.01",
  },
  "Math::Symbolic::Custom::Transformation::Group" => {
    file => "lib/Math/Symbolic/Custom/Transformation/Group.pm",
    version => "1.25",
  },
  "Test::Kit" => {
    file => "lib/Test/Kit.pm",
    version => "0.02",
  },
  "Test::Kit::Features" => {
    file => "lib/Test/Kit/Features.pm",
    version => "0.02",
  },
  "Test::Kit::Result" => {
    file => "lib/Test/Kit/Features.pm",
  },
);

PAR::Dist::merge_par(@tmp);

ok(1); # got to this point

my ($y_func) = PAR::Dist::_get_yaml_functions();

my $meta = PAR::Dist::get_meta($tmp[0]);
ok(defined($meta));

my $result = $y_func->{Load}->( $meta );
ok(defined $result);
$result = $result->[0] if ref($result) eq 'ARRAY';
use Data::Dumper;

my $provides = $result->{provides};
ok(ref($provides) eq 'HASH');

foreach my $module (keys %provides_expect) {
  ok(ref($provides->{$module}) eq 'HASH');
  my $modhash = $provides->{$module};
  my $exphash = $provides_expect{$module};

  ok($exphash->{file} eq $modhash->{file});
  if (exists $exphash->{version}) {
    ok($exphash->{version} eq $modhash->{version});
  }
  else {
    ok(!exists($modhash->{version}));
  }
}


__END__
