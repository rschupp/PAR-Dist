use 5.006;
use ExtUtils::MakeMaker 6.46;
# See lib/ExtUtils/MakeMaker.pm for details of how to influence
# the contents of the Makefile that is written.
WriteMakefile(
    NAME           => 'PAR::Dist',
    VERSION_FROM   => 'lib/PAR/Dist.pm',
    ABSTRACT_FROM  => 'lib/PAR/Dist.pm',
    LICENSE        => 'perl_5',
    AUTHOR         => 'Audrey Tang <cpan@audreyt.org>',
    PREREQ_PM      => {
        'File::Find' => '0',
        'File::Path' => '0',
        'File::Spec' => '0',
        'File::Temp' => '0',
    },
    META_MERGE     => {
        resources  => {
            repository => 'https://www.openfoundry.org/svn/par/PAR-Dist',
        }
    },
);

