# Copyright (C) 2010, Yaroslav Korshak.
 
package Mojolicious::Command::Generate::FatApp;

use warnings;
use strict;

use base 'Mojo::Command';

our $VERSION = '0.0.1';

# TODO make templates configurable

__PACKAGE__->attr(description => <<'EOF');
Generate fat application.
EOF

__PACKAGE__->attr(usage => <<"EOF");
usage: $0 generate fat_app [NAME]
EOF

sub run {
    my ($self, $class) = @_;
    $class ||= 'FatApp';

    my $name = $self->class_to_file($class);

    # Script
    $self->render_to_rel_file('mojo', "$name/script/$name", $class);
    $self->chmod_file("$name/script/$name", 0744);

    # Appclass0
    my $app = $self->class_to_path($class);
    $self->render_to_rel_file('appclass', "$name/lib/$app", $class);

    # Controller
    my $controller = "${class}::Controller";
    my $path       = $self->class_to_path($controller);
    $self->render_to_rel_file('controller', "$name/lib/$path", $controller);

    $self->create_rel_dir("$name/lib/$class/Controller");

    # Model
    my $model = "${class}::Model";
    $path     = $self->class_to_path($model);

    $self->render_to_rel_file('model', "$name/lib/$path", $model);

    $self->create_rel_dir("$name/lib/$class/Model");

    # Test
    $self->render_to_rel_file('test', "$name/t/basic.t", $class);

    # Log
    $self->create_rel_dir("$name/log");

    # Layout and Templates
    $self->renderer->line_start('%%');
    $self->renderer->tag_start('<%%');
    $self->renderer->tag_end('%%>');
    $self->render_to_rel_file('not_found',
        "$name/templates/not_found.html.ep");
    $self->render_to_rel_file('exception',
        "$name/templates/exception.html.ep");
    $self->render_to_rel_file('layout',
        "$name/templates/layouts/default.html.ep");

    $self->render_to_rel_file('config',
      $name . '/' . Mojo::ByteStream->new($class)->decamelize . ".conf");
}

1;

__DATA__
@@ mojo
% my $class = shift;
#!/usr/bin/env perl

use strict;
use warnings;

use FindBin;

use lib "$FindBin::Bin/../lib";
use lib "$FindBin::Bin/../../lib";

use Mojolicious::Commands;

# Application
$ENV{MOJO_APP} = '<%= $class %>';

# Start commands
Mojolicious::Commands->start;

@@ appclass
% my $class = shift;
package <%= $class %>;

use strict;
use warnings;

use base 'Mojolicious';

__PACKAGE__->attr(
    'config' => sub {
        {   loglevel => 'error',
            mode     => 'production',
            layout   => 'default',
        };
    }
);

sub startup {
    my $self = shift;
    
    $self->routes->namespace('<%= $class %>::Controller');

    $self->config({
            %{$self->config}, 
            %{$self->plugin('json_config' => {file => '<%= Mojo::ByteStream->new($class)->decamelize %>.conf'})}
    });

    $self->log->level($self->config->{'loglevel'});
    $self->mode($self->config->{'mode'});

    $self->defaults(layout => $self->config->{'layout'});

    $self->plugin('tag_helpers');

=for Perhaps, you want to use addictions plugins:

    $self->plugin('linked_content');
    $self->plugin('navi_track');

    $self->plugin(
        'db', handler => 'dbi',
        %{$self->config->{'dbi'}},
    );

=cut 

    $self->secret($self->config->{'secret'}) or
        die "You shouldn't forget make your secrets - secret.";

    # Routes
    my $r = $self->routes;

    # Default route
#   $r->route('/')->to('main#index');

}

1;
@@ controller
% my $class = shift;
package <%= $class %>;

use strict;
use warnings;

use base 'Mojolicious::Controller';

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

use Test::More tests => 5;
use Test::Mojo;

use_ok('<%= $class %>');
use_ok('<%= $class %>::Controller');
use_ok('<%= $class %>::Model');

@@ not_found
<!doctype html><html>
    <head><title>Not Found</title></head>
    <body>
        The page you were requesting
        "<%= $self->req->url->path || '/' %>"
        could not be found.
    </body>
</html>
@@ exception
<!doctype html><html>
% my $s = $self->stash;
% my $e = $self->stash('exception');
% delete $s->{inner_template};
% delete $s->{exception};
% my $dump = dumper $s;
% $s->{exception} = $e;
    <head>
	    <title>Exception</title>
	    <style type="text/css">
	        body {
		        font: 0.9em Verdana, "Bitstream Vera Sans", sans-serif;
	        }
	        .snippet {
                font: 115% Monaco, "Courier New", monospace;
	        }
	    </style>
    </head>
    <body>
        <% if ($self->app->mode eq 'development') { %>
	        <div>
                This page was generated from the template
                "templates/exception.html.ep".
            </div>
            <div class="snippet"><pre><%= $e->message %></pre></div>
            <div>
                <% for my $line (@{$e->lines_before}) { %>
                    <div class="snippet">
                        <%= $line->[0] %>: <%= $line->[1] %>
                    </div>
                <% } %>
                <% if ($e->line->[0]) { %>
                    <div class="snippet">
	                    <b><%= $e->line->[0] %>: <%= $e->line->[1] %></b>
	                </div>
                <% } %>
                <% for my $line (@{$e->lines_after}) { %>
                    <div class="snippet">
                        <%= $line->[0] %>: <%= $line->[1] %>
                    </div>
                <% } %>
            </div>
            <div class="snippet"><pre><%= $dump %></pre></div>
        <% } else { %>
            <div>Page temporarily unavailable, please come back later.</div>
        <% } %>
    </body>
</html>
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
    "loglevel": "debug"
}
__END__
=head1 NAME

Mojolicious::Command::Generate::FatApp - App Generator Command

=head1 SYNOPSIS

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
