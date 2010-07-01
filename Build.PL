use strict;
use warnings;
use Module::Build;

my $builder = Module::Build->new(
    module_name         => 'Mojolicious::Generate::FatApp',
    license             => 'perl',
    dist_author         => 'Yaroslav Korshak <ykorshak@gmail.com>',
    dist_version_from   => 'lib/Mojolicious/Command/Generate/FatApp.pm',
    requires => {
        'Test::More' => 0,
        'version'    => 0,
    },
    add_to_cleanup      => [ 'fat-app-*' ],
);

$builder->create_build_script();
