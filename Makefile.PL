use inc::Module::Install;

name	    ('PAR-Dist');
author	    ('Audrey Tang (autrijus@autrijus.org)');
abstract    ('Create and manipulate PAR distributions');
version_from('lib/PAR/Dist.pm');

requires    'Cwd'        => '0';
requires    'File::Find' => '0';
requires    'File::Path' => '0';
requires    'File::Spec' => '0';
requires    'File::Temp' => '0';

license	    ('perl');

&WriteAll   ( sign => 1 );

