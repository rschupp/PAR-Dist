#!/usr/bin/perl -w
# $File: //member/autrijus/PAR-Dist/t/1-basic.t $ $Author: autrijus $
# $Revision: #1 $ $Change: 6987 $ $DateTime: 2003/07/16 06:14:55 $

use strict;
use Test;

BEGIN { plan tests => 1 }

ok (eval { require PAR::Dist; 1 });

__END__
