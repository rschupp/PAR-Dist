#!/usr/bin/perl
# $File: //member/autrijus/PAR-Dist/t/0-signature.t $ $Author: autrijus $
# $Revision: #1 $ $Change: 6987 $ $DateTime: 2003/07/16 06:14:55 $

use strict;
print "1..1\n";

if (!-s 'SIGNATURE') {
    print "ok 1 # skip - No signature file found\n";
}
elsif (!eval { require Socket; Socket::inet_aton('pgp.mit.edu') }) {
    print "ok 1 # skip - Cannot connect to the keyserver\n";
}
elsif (!eval { require Module::Signature; 1 }) {
    warn "# Next time around, consider installing Module::Signature,\n".
	 "# so you can verify the integrity of this distribution.\n";
    print "ok 1 # skip - Module::Signature not installed\n";
}
else {
    (Module::Signature::verify() == Module::Signature::SIGNATURE_OK())
	or print "not ";
    print "ok 1 # Valid signature\n";
}

__END__
