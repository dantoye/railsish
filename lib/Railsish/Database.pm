package Railsish::Database;
# ABSTRACT: Talks to database

use Moose;
use KiokuDB;
use Railsish::CoreHelpers;
use YAML::Any qw(LoadFile);

has 'config' => (
    is  => "ro",
    isa => "HashRef",
    lazy_build => 1,
    required => 1
);

has 'dsn' => (
    isa => "Str",
    is  => "rw",
    lazy_build => 1
);

has 'kioku' => (
    is => "rw",
    lazy_build => 1
);

sub _build_config {
    my $self = shift;
    my $file = app_root(config => "database.yml");

    die "config/database.yml does not exist\n"
	unless -f $file;

    my $all_config = LoadFile($file);
    return $all_config->{development};
}

sub _build_dsn {
    my $self = shift;
    my $dsn = $ENV{RAILSISH_TEST_DSN} || $self->config->{dsn};
    return $dsn;
}

sub _build_kioku {
    my $self = shift;
    my $config = $self->config;

    return KiokuDB->connect(
	$self->dsn,
	create => 1,
	user => $config->{user},
	password => $config->{password}
    );
}

sub search {
    my ($self, @args) = @_;
    my $kioku = $self->kioku;
    my $kioku_scope = $kioku->new_scope;

    $kioku->search({ (@args) });
}

sub store {
    my ($self, $obj) = @_;
    my $kioku = $self->kioku;
    my $kioku_scope = $kioku->new_scope;
    $kioku->store($obj);
}

__PACKAGE__->meta->make_immutable;

1;