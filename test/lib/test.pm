package test;

use strict;
use warnings;

use base 'Mojolicious';

__PACKAGE__->attr(
    'config' => sub { {
        loglevel => 'error',
        secret   => sub { die "You shouldn't forget make your secrets - secret." },
     }
    }
);

sub startup {
    my $self = shift;
    
    $self->routes->namespace('test::Controller');

    $self->config({
            %{$self->config}, 
            %{$self->plugin('json_config' => {file => 'test.conf'})}
    });


    $self->plugin('tag_helpers');

=head Perhabs, you want to use addictions plugins:

    $self->plugin('linked_content');
    $self->plugin('navi_track');

    $self->plugin(
        'db', handler => 'dbi',
        %{$self->config->{'dbi'}},
    );

=cut 

    $self->secret($self->config->{'secret'});

    # Routes
    my $r = $self->routes;

    # Default route
#   $r->route('/')->to('main#index');

}

1;
