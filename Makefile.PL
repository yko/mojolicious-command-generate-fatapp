use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME         => 'Mojolicious::Generate::FatApp',
    AUTHOR       => 'Yaroslav Korshak <ykorshak@gmail.com>',
    VERSION_FROM => 'lib/Mojolicious/Command/Generate/FatApp.pm',
    ABSTRACT     => 'Mojolicious app generator',
    PL_FILES     => {},
    PREREQ_PM    => {
        'Test::More'  => 0,
        'version'     => 0,
        'Mojolicious' => 1.02,
    },
    dist  => {COMPRESS => 'gzip -9f', SUFFIX => 'gz',},
    clean => {FILES    => 'fat-app-*'},
);
