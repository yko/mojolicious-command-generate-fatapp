# Copyright (C) 2010-2011, Yaroslav Korshak.

package Mojolicious::Command::Generate::FatApp;

use Mojo::Base 'Mojo::Command';
use strict;

use Getopt::Long;
use FindBin;
use Mojo::ByteStream 'b';

our $VERSION = '0.01_5';

# TODO make templates configurable

has description => <<'EOF';
Generate fat application.
EOF

has usage => <<"EOF";
usage: $0 generate fat_app [OPTIONS] [NAME]
options:

--examples,     Generate example controller and model.
 -e

--controller,   Generate controller in existing application.
 -c

EOF

sub run {
    my $self = shift;

    local @ARGV = @_ if @_;

    my %opts;

    GetOptions(
        'examples|e'  => \$opts{examples},
        'controller|c'  => \$opts{controller},
    );


    my $class = shift(@ARGV) || 'FatApp';

    if ($opts{controller}) {
        die "No options allowed with 'controller'" if grep($_, values(%opts)) > 1;
        my $app = $ENV{MOJO_APP};
        return generate_controller($self, $class, $app)
    }

    my $name = $self->class_to_file($class);

    # Script
    $self->render_to_rel_file('mojo', "$name/script/$name", $class);
    $self->chmod_file("$name/script/$name", oct('0744'));

    # Appclass
    my $app = $self->class_to_path($class);
    $self->render_to_rel_file('appclass', "$name/lib/$app", $class);

    # Controller
    my $controller = "${class}::Controller";
    my $path       = $self->class_to_path($controller);
    $self->render_to_rel_file('controller', "$name/lib/$path", $controller);

    $self->create_rel_dir("$name/lib/$class/Controller");

    if ($opts{examples}) {
        $path =~ s/\.pm$//;
        $self->render_to_rel_file('controller_example', "$name/lib/$path/Example.pm", 'Example', $controller);
    }

    # Model
    my $model = "${class}::Model";
    $path     = $self->class_to_path($model);

    $self->render_to_rel_file('model', "$name/lib/$path", $model);

    $self->create_rel_dir("$name/lib/$class/Model");

    # Test
    $self->render_to_rel_file('test_lib', "$name/t/lib/Test/$class.pm", $class);
    $self->render_to_rel_file('test', "$name/t/basic.t", $class);

    # Log
    $self->create_rel_dir("$name/log");

    # Static
    $self->create_rel_dir("$name/public");
    $self->create_rel_dir("$name/public/js");
    $self->create_rel_dir("$name/public/css");
    $self->create_rel_dir("$name/public/img");

    # Layout and Templates
    $self->renderer->line_start('%%');
    $self->renderer->tag_start('<%%');
    $self->renderer->tag_end('%%>');
    $self->render_to_rel_file('layout',
        "$name/templates/layouts/default.html.ep");

    $self->render_to_rel_file('config',
      $name . '/' . b($class)->decamelize . ".conf");
}

sub generate_controller {
    my ($self, $class, $app) = @_;
    require Mojo::Home;
    my $home = Mojo::Home->new;
    my $lib = $home->lib_dir;
    die "Unable to locate libdir" unless $lib;

    my $controller = "${app}::Controller::" . b($class)->camelize;
    my $path       = $self->class_to_path($controller);

    $self->render_to_rel_file(
        'controller_example', "$lib/$path",
        b($class)->camelize,  "${app}::Controller"
    );

    $self->create_rel_dir("templates/" . b($class)->decamelize);

    $self->render_to_rel_file('controller_test',
        "t/controller/" . b($class)->decamelize . ".t",
        "${app}::Controller::${class}", $app);
}

1;

__DATA__
@@ mojo
% my $class = shift;
#!/usr/bin/env perl

use strict;
use warnings;

use File::Basename 'dirname';
use File::Spec;

use lib join '/', File::Spec->splitdir(dirname(__FILE__)), 'lib';
use lib join '/', File::Spec->splitdir(dirname(__FILE__)), '..', 'lib';

use Mojolicious::Commands;

# Application
$ENV{MOJO_APP} = '<%= $class %>';

# Start commands
Mojolicious::Commands->start;
@@ test_lib
% my $class = shift;
package Test::<%= $class %>;

use strict;
use warnings;

use base 'Test::Mojo';
require Test::More;
require <%= $class %>;

sub new {
    my $self = shift->SUPER::new(@_);
    $self->app(<%= $class %>->new) unless $self->app;

    return $self;
}

sub import {
    my $class = shift;
    my $caller = caller;
    eval "package $caller; Test::More->import(\@_);";

    $ENV{MOJO_EXE} = 'script/<%= b($class)->decamelize %>';
}

1;
@@ appclass
% my $class = shift;
package <%= $class %>;

use Mojo::Base 'Mojolicious';

has controller_class => '<%= $class %>::Controller';
has config => sub {
    {   loglevel => 'error',
        mode     => 'production'
    };
};

sub startup {
    my $self = shift;

    $self->routes->namespace('<%= $class %>::Controller');

    $self->config(
<% %>        {   %{$self->config},
<% %>            %{$self->plugin('json_config' => {ext => 'conf'})}
        }
    );

    $self->apply_config;
    $self->setup_routes;
    $self->preload_controller;
}

sub preload_controller {
    my $self = shift;
    my $controller = $self->controller_class;
    my $e = Mojo::Loader->new->load($controller);

    if (ref $e) {
        die qq/Loading base controller class "$controller" failed: $e/;
    }
}

sub setup_routes {
    my $self = shift;

    # Routes
    my $r = $self->routes;

    # Default route
#   $r->route('/')->to('main#index');
}

sub apply_config {
    my $self = shift;

    # Avoid double-configuration
    return if $self->{_configured}++;

    # Set up default layout for all templates
    $self->defaults(layout => $self->config->{'layout'})
        if $self->config->{'layout'};

    # Set log level
    $self->log->level($self->config->{'loglevel'})
        if $self->config->{'loglevel'};

    # Set application mode
    $self->mode($self->config->{'mode'})
        if $self->config->{'mode'};

    # Set secret passphrase for signed cookies
    $self->secret($self->config->{'secret'});
}

has secret => sub {
    exit warn "Looks like you forget to set up secret passphrase."
      . "See http://mojolicio.us/perldoc?Mojolicious#secret\n";
};


1;

<% %>__END__

=head1 <%= $class %> Application

=head2 startup()

This method inits <%= $class %> application, loads plugins and sets up routes.

=head2 Configuration

Configuration file <%= Mojo::ByteStream->new($class)->camelize %>.conf can be used to configure application.

Here's default options reference:

=over 4

=item loglevel

Minimal level of message to be logged.

Possible values:

    debug, info, warn, error, fatal

Default value: error

=item mode

The operating mode for your application.

Supported values:

    develompment, production

But you can define any other mode, see L<Mojolicious> documentation.

Default value: production

=item layout

This option sets default layout to be used in all your templates.
In initial config it set to 'default'.

To override this setting you can set up layou per template:

<% %>    % layout 'non-default-layout';

If you not want to use any layout, you should set layout to undef in yout template:

<% %>    % layout undef;

=back
=cut
@@ controller
% my $class = shift;
package <%= $class %>;

use Mojo::Base '<%= shift || 'Mojolicious::Controller' %>';

1;
@@ controller_test
% my $class = shift;
% my $appclass = shift;
#!/usr/bin/env perl

use strict;
use warnings;

use lib 't/lib', '../lib';

use Test::<%= $appclass %> tests => 3;

use_ok('<%= $class %>');

my $c = new_ok('<%= $class %>');

# Controller actions
can_ok $c, qw/index/;

my $t = Test::<%= $appclass %>->new;

# Preform further tests

@@ controller_example
% my $class = shift;
% my $namespace = shift;
package <%= $namespace . '::' . $class %>;

use Mojo::Base '<%= $namespace %>';

=head2 index
Default action

    GET /

=cut

sub index {
    my $c = shift;
}

1;
@@ model
% my $class = shift;
package <%= $class %>;

use strict;
use warnings;

1;

@@ test
% my $class = shift;
#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 3;
use Test::Mojo;

use_ok('<%= $class %>');
use_ok('<%= $class %>::Controller');
use_ok('<%= $class %>::Model');

@@ layout
<!doctype html>
<html>
<head>
 <title>Welcome</title>
</head>
<body>
%== content;
</body>
</html>
@@ config
{
    "mode": "development",
    "loglevel": "debug",
    "layout": "default"
}
__END__
=head1 NAME

Mojolicious::Command::Generate::FatApp - App Generator Command

=head1 SYNOPSIS

You can run from command line:

    mojollicious generate fat_app my_fat_app

Or use in your Perl code:

    use Mojolicious::Command::Generate::FatApp;

    my $app = Mojolicious::Command::Generate::FatApp->new;
    $app->run(@ARGV);

=head1 DESCRIPTION

L<Mojolicious::Command::Generate::FatApp> is a application generator,
based on L<Mojolicious::Command::Generate::App>.

=head1 ATTRIBUTES

L<Mojolicious::Command::Generate::FatApp> inherits all attributes from
L<Mojo::Command> and implements the following new ones.

=head2 C<description>

    my $description = $app->description;
    $app            = $app->description('Foo!');

Short description of this command, used for the command list.

=head2 C<usage>

    my $usage = $app->usage;
    $app      = $app->usage('Foo!');

Usage information for this command, used for the help screen.

=head1 METHODS

L<Mojolicious::Command::Generate::FatApp> inherits all methods from
L<Mojo::Command> and implements the following new ones.

=head2 C<run>

    $app->run(@ARGV);

Run this command.

=head1 SEE ALSO

L<Mojolicious::Command::Generate::App>, L<Mojolicious>, L<Mojolicious::Guides>,
L<http://mojolicious.org>.

=head1 AUTHOR

Yaroslav Korshak  C<< <ykorshak@gmail.com> >>

=cut
