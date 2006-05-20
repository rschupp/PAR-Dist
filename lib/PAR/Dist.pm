# $File: //member/autrijus/PAR-Dist/lib/PAR/Dist.pm $ $Author: autrijus $
# $Revision: #11 $ $Change: 9530 $ $DateTime: 2004/01/01 05:24:09 $

package PAR::Dist;
require Exporter;
use vars qw/$VERSION @ISA @EXPORT/;

$VERSION    = '0.09';
@ISA	    = 'Exporter';
@EXPORT	    = qw/ blib_to_par install_par uninstall_par sign_par verify_par /;

use strict;
use File::Spec;

=head1 NAME

PAR::Dist - Create and manipulate PAR distributions

=head1 VERSION

This document describes version 0.08 of PAR::Dist, released February 13, 2006.

=head1 SYNOPSIS

As a shell command:

    % perl -MPAR::Dist -eblib_to_par

In programs:

    use PAR::Dist;

    my $dist = blib_to_par();	# make a PAR file using ./blib/
    install_par($dist);		# install it into the system
    uninstall_par($dist);	# uninstall it from the system
    sign_par($dist);		# sign it using Module::Signature
    verify_par($dist);		# verify it using Module::Signature

    install_par("http://foo.com/DBI-1.37-MSWin32-5.8.0.par"); # works too
    install_par("http://foo.com/DBI-1.37"); # auto-appends archname + perlver
    install_par("cpan://SMUELLER/PAR-0.91"); # uses CPAN author directory

=head1 DESCRIPTION

This module creates and manipulates I<PAR distributions>.  They are
architecture-specific B<PAR> files, containing everything under F<blib/>
of CPAN distributions after their C<make> or C<Build> stage, a
F<META.yml> describing metadata of the original CPAN distribution, 
and a F<MANIFEST> detailing all files within it.  Digitally signed PAR
distributions will also contain a F<SIGNATURE> file.

The naming convention for such distributions is:

    $NAME-$VERSION-$ARCH-$PERL_VERSION.par

For example, C<PAR-Dist-0.01-i386-freebsd-5.8.0.par> corresponds to the
0.01 release of C<PAR-Dist> on CPAN, built for perl 5.8.0 running on
C<i386-freebsd>.

=head1 FUNCTIONS

Five functions are exported by default.  They can take either a hash of
named arguments, a single argument (taken as C<$path> by C<blib_to_par>
and C<$dist> by other functions), or no arguments (in which case
the first PAR file in the current directory is used).

Therefore, under a directory containing only a single F<test.par>, all
invocations below are equivalent:

    % perl -MPAR::Dist -e"install_par( dist => 'test.par' )"
    % perl -MPAR::Dist -e"install_par( 'test.par' )"
    % perl -MPAR::Dist -einstall_par;

If C<$dist> resembles a URL, C<LWP::Simple::mirror> is called to mirror it
locally under C<$ENV{PAR_TEMP}> (or C<$TEMP/par/> if unspecified), and the
function will act on the fetched local file instead.  If the URL begins
with C<cpan://AUTHOR/>, it will be expanded automatically to the author's CPAN
directory (e.g. C<http://www.cpan.org/modules/by-authors/id/A/AU/AUTHOR/>).

If C<$dist> does not have a file extension beginning with a letter or
underscore, a dash and C<$suffix> ($ARCH-$PERL_VERSION.par by default)
will be appended to it.

=head2 blib_to_par

Takes key/value pairs as parameters or a single parameter indicating the
path that contains the F<blib/> subdirectory.

Builds a PAR distribution from the F<blib/> subdirectory under C<path>, or
under the current directory if unspecified.  If F<blib/> does not exist,
it automatically runs F<Build>, F<make>, F<Build.PL> or F<Makefile.PL> to
create it.

Returns the filename or the generated PAR distribution.

Valid parameters are:

=over 2

=item path

Sets the path which contains the F<blib/> subdirectory from which the PAR
distribution will be generated.

=item name, version, suffix

These attributes set the name, version platform specific suffix
of the distribution. Name and version can be automatically
determined from the distributions F<META.yml> or F<Makefile.PL> files.

The suffix is generated from your architecture name and your version of
perl by default.

=item dist

The output filename for the PAR distribution.

=back

=cut

sub blib_to_par {
    @_ = (path => @_) if @_ == 1;

    my %args = @_;
    require Config;

    my $path	= $args{path};
    my $dist	= File::Spec->rel2abs($args{dist}) if $args{dist};
    my $name	= $args{name};
    my $version	= $args{version};
    my $suffix	= $args{suffix} || "$Config::Config{archname}-$Config::Config{version}.par";
    my $cwd;

    if (defined $path) {
	require Cwd;
	$cwd = Cwd::cwd();
	chdir $path;
    }

    _build_blib() unless -d "blib";

    my @files;
    open MANIFEST, ">blib/MANIFEST" or die $!;
    open META, ">blib/META.yml" or die $!;
    
    require File::Find;
    File::Find::find( sub {
	next unless $File::Find::name;
        (-r && !-d) and push ( @files, substr($File::Find::name, 5) );
    } , 'blib' );

    print MANIFEST join(
	"\n",
	'    <!-- accessible as jar:file:///NAME.par!/MANIFEST in compliant browsers -->',
	(sort @files),
	q(    # <html><body onload="var X=document.body.innerHTML.split(/\n/);var Y='<iframe src=&quot;META.yml&quot; style=&quot;float:right;height:40%;width:40%&quot;></iframe><ul>';for(var x in X){if(!X[x].match(/^\s*#/)&&X[x].length)Y+='<li><a href=&quot;'+X[x]+'&quot;>'+X[x]+'</a>'}document.body.innerHTML=Y">)
    );
    close MANIFEST;

    if (open(OLD_META, "META.yml")) {
        while (<OLD_META>) {
            if (/^distribution_type:/) {
                print META "distribution_type: par\n";
            }
            else {
                print META $_;
            }

	    if (/^name:\s+(.*)/) {
		$name ||= $1;
		$name =~ s/::/-/g;
	    }
	    elsif (/^version:\s+(.*)/) {
		$version ||= $1;
	    }
        }
        close OLD_META;
	close META;
    }
    elsif ((!$name or !$version) and open(MAKEFILE, "Makefile")) {
	while (<MAKEFILE>) {
	    if (/^DISTNAME\s+=\s+(.*)$/) {
		$name ||= $1;
	    }
	    elsif (/^VERSION\s+=\s+(.*)$/) {
		$version ||= $1;
	    }
	}
    }

    my $file = "$name-$version-$suffix";
    unlink $file if -f $file;

    print META << "YAML" if fileno(META);
name: $name
version: $version
build_requires: {}
conflicts: {}
dist_name: $file
distribution_type: par
dynamic_config: 0
generated_by: 'PAR::Dist version $PAR::Dist::VERSION'
license: unknown
YAML
    close META;

    mkdir('blib', 0777);
    chdir('blib');
    _zip(dist => File::Spec->catfile(File::Spec->updir, $file)) or die $!;
    chdir(File::Spec->updir);

    unlink "blib/MANIFEST";
    unlink "blib/META.yml";

    $dist ||= File::Spec->catfile($cwd, $file) if $cwd;

    if ($dist and $file ne $dist) {
        rename( $file => $dist );
        $file = $dist;
    }

    my $pathname = File::Spec->rel2abs($file);
    if ($^O eq 'MSWin32') {
        $pathname =~ s!\\!/!g;
        $pathname =~ s!:!|!g;
    };
    print << ".";
Successfully created binary distribution '$file'.
Its contents are accessible in compliant browsers as:
    jar:file://$pathname!/MANIFEST
.

    chdir $cwd if $cwd;
    return $file;
}

sub _build_blib {
    if (-e 'Build') {
	system($^X, "Build");
    }
    elsif (-e 'Makefile') {
	system($Config::Config{make});
    }
    elsif (-e 'Build.PL') {
	system($^X, "Build.PL");
	system($^X, "Build");
    }
    elsif (-e 'Makefile.PL') {
	system($^X, "Makefile.PL");
	system($Config::Config{make});
    }
}

=head2 install_par

Installs a PAR distribution into the system, using
C<ExtUtils::Install::install_default>.

=cut

sub install_par {
    my %args = &_args;
    _install_or_uninstall(%args, action => 'install');
}

=head2 uninstall_par

Uninstalls all previously installed contents of a PAR distribution,
using C<ExtUtils::Install::uninstall>.

=cut

sub uninstall_par {
    my %args = &_args;
    _install_or_uninstall(%args, action => 'uninstall');
}

sub _install_or_uninstall {
    my %args = &_args;
    my $name = $args{name};
    my $action = $args{action};
    my ($dist, $tmpdir) = _unzip_to_tmpdir( dist => $args{dist}, subdir => 'blib' );

    if (!$name) {
	open (META, 'blib/META.yml') or return;
	while (<META>) {
	    next unless /^name:\s+(.*)/;
	    $name = $1; last;
	}
	close META;
    }

    if (-d 'script') {
	require ExtUtils::MY;
	foreach my $file (glob("script/*")) {
	    next unless -T $file;
	    ExtUtils::MY->fixin($file);
	    chmod(0555, $file);
	}
    }

    $name =~ s{::|-}{/}g;
    require ExtUtils::Install;

    my $rv;
    if ($action eq 'install') {
	$rv = ExtUtils::Install::install_default($name);
    }
    elsif ($action eq 'uninstall') {
	require Config;
	$rv = ExtUtils::Install::uninstall(
	    "$Config::Config{installsitearch}/auto/$name/.packlist"
	);
    }

    File::Path::rmtree([$tmpdir]);
    return $rv;
}

=head2 sign_par

Digitally sign a PAR distribution using C<gpg> or B<Crypt::OpenPGP>,
via B<Module::Signature>.

=cut

sub sign_par {
    my %args = &_args;
    _verify_or_sign(%args, action => 'sign');
}

=head2 verify_par

Verify the digital signature of a PAR distribution using C<gpg> or
B<Crypt::OpenPGP>, via B<Module::Signature>.

Returns a boolean value indicating whether verification passed; C<$!>
is set to the return code of C<Module::Signature::verify>.

=cut

sub verify_par {
    my %args = &_args;
    $! = _verify_or_sign(%args, action => 'verify');
    return ( $! == Module::Signature::SIGNATURE_OK() );
}

sub _unzip {
    my %args = &_args;
    my $dist = $args{dist};
    my $path = $args{path} || File::Spec->curdir;
    return unless -f $dist;

    if (eval { require Archive::Zip; 1 }) {
        my $zip = Archive::Zip->new;
	$SIG{__WARN__} = sub { print STDERR $_[0] unless $_[0] =~ /\bstat\b/ };
        return unless $zip->read($dist) == Archive::Zip::AZ_OK()
                  and $zip->extractTree('', "$path/") == Archive::Zip::AZ_OK();
    }
    else {
        return if system(unzip => $dist, '-d', $path);
    }
}

sub _zip {
    my %args = &_args;
    my $dist = $args{dist};

    if (eval { require Archive::Zip; 1 }) {
        my $zip = Archive::Zip->new;
        $zip->addTree( File::Spec->curdir, '' );
        $zip->writeToFileNamed( $dist ) == Archive::Zip::AZ_OK() or die $!;
    }
    else {
        system(qw(zip -r), $dist, File::Spec->curdir) and die $!;
    }
}

sub _args {
    unshift @_, (glob('*.par'))[0] unless @_;
    @_ = (dist => @_) if @_ == 1;
    my %args = @_;

    $args{name} ||= $args{dist};
    $args{dist} .= '-' . do {
	require Config;
	$args{suffix} || "$Config::Config{archname}-$Config::Config{version}.par"
    } unless !$args{dist} or $args{dist} =~ /\.[a-zA-Z_][^.]*$/;

    $args{dist} = _fetch(dist => $args{dist})
	if ($args{dist} and $args{dist} =~ m!^\w+://!);
    return %args;
}

my %escapes;
sub _fetch {
    my %args = @_;
    require LWP::Simple;

    $ENV{PAR_TEMP} ||= File::Spec->catdir(File::Spec->tmpdir, 'par');
    mkdir $ENV{PAR_TEMP}, 0777;
    %escapes = map { chr($_) => sprintf("%%%02X", $_) } 0..255 unless %escapes;

    $args{dist} =~ s{^cpan://((([a-zA-Z])[a-zA-Z])[-_a-zA-Z]+)/}
		    {http://www.cpan.org/modules/by-authors/id/\U$3/$2/$1\E/};

    my $file = $args{dist};
    $file =~ s/([^\w\.])/$escapes{$1}/g;
    $file = File::Spec->catfile( $ENV{PAR_TEMP}, $file);
    my $rc = LWP::Simple::mirror( $args{dist}, $file );

    if (!LWP::Simple::is_success($rc)) {
	die "Error $rc: ", LWP::Simple::status_message($rc), " ($args{dist})\n";
    }

    return $file if -e $file;
    return;
}

sub _verify_or_sign {
    my %args = &_args;

    require File::Path;
    require Module::Signature;
    die "Module::Signature version 0.25 required"
	unless Module::Signature->VERSION >= 0.25;

    require Cwd;
    my $cwd = Cwd::cwd();
    my $action = $args{action};
    my ($dist, $tmpdir) = _unzip_to_tmpdir($args{dist});
    $action ||= (-e 'SIGNATURE' ? 'verify' : 'sign');

    if ($action eq 'sign') {
	open FH, '>SIGNATURE' unless -e 'SIGNATURE';
	open FH, 'MANIFEST' or die $!;

	local $/;
	my $out = <FH>;
	if ($out !~ /^SIGNATURE(?:\s|$)/m) {
	    $out =~ s/^(?!\s)/SIGNATURE\n/m;
	    open FH, '>MANIFEST' or die $!;
	    print FH $out;
	}
	close FH;

	$args{overwrite}	= 1 unless exists $args{overwrite};
	$args{skip}		= 0 unless exists $args{skip};
    }

    my $rv = Module::Signature->can($action)->(%args);
    _zip(dist => $dist) if $action eq 'sign';
    File::Path::rmtree([$tmpdir]);

    chdir($cwd);
    return $rv;
}

sub _unzip_to_tmpdir {
    my %args = &_args;

    require File::Temp;

    my $dist   = File::Spec->rel2abs($args{dist});
    my $tmpdir = File::Temp::mkdtemp(File::Spec->catdir(File::Spec->tmpdir, "parXXXXX")) or die $!;
    my $path = $tmpdir;
    $path = File::Spec->catdir($tmpdir, $args{subdir}) if defined $args{subdir};
    _unzip(dist => $dist, path => $path);

    chdir $tmpdir;
    return ($dist, $tmpdir);
}

1;

=head1 SEE ALSO

L<PAR>, L<ExtUtils::Install>, L<Module::Signature>, L<LWP::Simple>

=head1 AUTHORS

Autrijus Tang E<lt>autrijus@autrijus.orgE<gt>

PAR has a mailing list, E<lt>par@perl.orgE<gt>, that you can write to;
send an empty mail to E<lt>par-subscribe@perl.orgE<gt> to join the list
and participate in the discussion.

Please send bug reports to E<lt>bug-par@rt.cpan.orgE<gt>.

=head1 COPYRIGHT

Copyright 2003, 2004, 2006 by Audrey Tang E<lt>autrijus@autrijus.orgE<gt>.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>

=cut
