package Railsish::View;
use Moose;

has template_root => (
    is => "ro",
    isa => "Str",
    required => 1
);

use Railsish::ViewHelpers ();
require UNIVERSAL::require;
use File::Spec::Functions;

sub render {
    my ($self, @args) = @_;

    my %vars;

    if (@args % 2 == 1) {
	my $thingy = shift @args;
	%vars = @args;

	if ( -f catfile($self->template_root, $thingy) ) {
	    $vars{file} = $thingy;
	}
	else {
	    $vars{file} = $self->resolve_template($thingy);
	}
    } else {
	%vars = @args;
    }

    unless ( $vars{file} =~ m/\.(\w+)$/ ) {
	die "Don't know how to render $vars{file}\n";
    }
    my $view_class = "Railsish::View::$1";
    $view_class->require or die $@;

    my $view_obj = $view_class->new(
	template_root => $self->template_root
    );

    my $output = $view_obj->render(%vars);

    return $output;
}

sub resolve_template {
    my ($self, $thingy) = @_;

    my $dir = $self->template_root;
    my $p = $self->template_root . "/" . $thingy . ".*.*";

    # XXX: TODO: Decide the precedence of multiple matches.
    my @files = glob($p);

    die "Unknown template: $thingy" unless @files;

    my $file = $files[0];
    $file =~  s/^$dir\///;
    return $file;
}

__PACKAGE__->meta->make_immutable;

1;

=head1 SYNOPSIS

    # Explicit
    Railsish::View->render(template => "foo/bar.html.tt2", %vars);

    # Smart
    Railsish::View->render("foo/bar", %vars);

=head1 DESCRIPTION


=cut