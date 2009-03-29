package Railsish::Dispatcher;
# ABSTRACT: The first handler for requests.

use Railsish::Router;
use YAML::Any;
use Hash::Merge qw(merge);
use Encode;
use Railsish::CoreHelpers;
use MIME::Base64;
use Crypt::CBC;
use JSON::XS::VersionOneAndTwo;

sub dispatch {
    my ($class, $request) = @_;
    my $path = $request->path;

    $path =~ s/\.([a-z]+)$//;
    my $format = $1 || "html";

    my $method = lc($request->method);
    if ($method eq 'post') {
        if (my $m = $request->param("_method")) {
            $method = lc($m);
        }
    }
    my $matched = Railsish::Router->match(
        $path, conditions => { method => $method }
    );

    my $response = HTTP::Engine::Response->new;
    unless($matched) {
        $response->body("internal server error");
        $response->status(500);
        return $response;
    }

    my $mapping = $matched->mapping;

    my $controller = $mapping->{controller};
    my $action = $mapping->{action} || "index";

    my $controller_class = ucfirst(lc($controller)) . "Controller";
    my $sub = $controller_class->can($action);

    die "action $action is not defined in $controller_class." unless $sub;
    my %params = %{$request->parameters};
    for (keys %params) {
        $params{$_} = Encode::decode_utf8( $params{$_} );
    }

    my $params = merge(\%params, $mapping);

    $Railsish::Controller::params = $params;
    $Railsish::Controller::request = $request;
    $Railsish::Controller::response = $response;
    $Railsish::Controller::controller = $controller;
    $Railsish::Controller::action = $action;
    $Railsish::Controller::format = $format;

    my $cipher = Crypt::CBC->new(
        -key => "railsish",
        -cipher => "Rijndael"
    );

    my $session = {};
    my $session_cookie = $request->cookies->{_railsish_session};
    if ($session_cookie) {
        my $ciphertext_base64   = $session_cookie->value;
        my $ciphertext_unbase64 = decode_base64($ciphertext_base64);
        my $json = $cipher->decrypt($ciphertext_unbase64);
        $session = decode_json($json);
    }

    logger->debug(Dump({session => $session}));

    $Railsish::Controller::session = $session;

    logger->debug(Dump({
        request_path => $path,
        method => $method,
        controller => $controller,
        action => $action,
        params => $request->parameters,
        session => $session
    }));

    $sub->();


    {
        my $json = encode_json($session);
        my $ciphertext = $cipher->encrypt($json);
        my $ciphertext_base64 = encode_base64($ciphertext, '');
        $response->cookies->{_railsish_session} = {
            value => $ciphertext_base64
        };
    }

    return $response;

}

1;

=head1 DESCRIPTION

This class contains the first handler for requests.

=cut
