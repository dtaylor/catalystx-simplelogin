package CatalystX::SimpleLogin::Controller::Login;
use Moose;
use Moose::Autobox;
use MooseX::Types::Moose qw/ HashRef ArrayRef ClassName Object /;
use MooseX::Types::Common::String qw/ NonEmptySimpleStr /;
use File::ShareDir qw/module_dir/;
use List::MoreUtils qw/uniq/;
use CatalystX::SimpleLogin::Form::Login;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller::ActionRole'; }

with 'CatalystX::Component::Traits';

__PACKAGE__->config(
    traits => 'Logout',
);

sub BUILD {
    my $self = shift;
    $self->login_form; # Build login form at construction time
}

has 'username_field' => (
    is => 'ro',
    isa => NonEmptySimpleStr,
    required => 1,
    default => 'username',
);

has 'password_field' => (
    is => 'ro',
    isa => NonEmptySimpleStr,
    required => 1,
    default => 'password',
);

has 'remember_field' => (
    is => 'ro',
    isa => NonEmptySimpleStr,
    required => 1,
    default => 'remember',
);

has 'login_error_message' => (
    is => 'ro',
    isa => NonEmptySimpleStr,
    required => 1,
    default => 'Wrong username or password',
);

has 'extra_auth_fields' => (
    isa => ArrayRef[NonEmptySimpleStr],
    is => 'ro',
    default => sub { [] },
);

has login_form_class => (
    isa => ClassName,
    is => 'rw',
    default => 'CatalystX::SimpleLogin::Form::Login',
);

has login_form_class_roles => (
    isa => ArrayRef[NonEmptySimpleStr],
    is => 'ro',
    default => sub  { [] },
);

has login_form => (
    isa => Object,
    is => 'ro',
    lazy_build => 1,
);

has login_form_args => (
    isa => HashRef,
    is => 'ro',
    default => sub { {} },
);

with 'MooseX::RelatedClassRoles' => { name => 'login_form' };

sub _build_login_form {
	my $self = shift;
	$self->apply_login_form_class_roles($self->login_form_class_roles->flatten)
        if scalar $self->login_form_class_roles->flatten; # FIXME - Should MX::RelatedClassRoles
                                                          #         do this automagically?
	return $self->login_form_class->new( $self->login_form_args );
}

sub login
    :Chained('/')
    :PathPart('login')
    :Args(0)
    :ActionClass('REST')
    :Does('FindViewByIsa')
    :FindViewByIsa('Catalyst::View::TT')
{
    my ($self, $c) = @_;
    $c->stash->{additional_template_paths} =
        [ uniq(
            @{$c->stash->{additional_template_paths}||[]},
            module_dir('CatalystX::SimpleLogin::Controller::Login') . '/'
            . 'tt'
        ) ];
    $c->stash->{form} = $self->login_form;
}

sub login_GET {}

sub login_POST {
    my ($self, $c) = @_;

    my $form = $self->login_form;
    my $p = $c->req->body_parameters;
    if ($form->process($p)) {
        if ($c->authenticate({
            $self->username_field => $form->field('username')->value,
            $self->password_field => $form->field('password')->value,
            map { $_ => $form->field($_) } @{ $self->extra_auth_fields },
        })) {
            $c->extend_session_expires(999999999999)
                if $form->field( $self->remember_field )->value;
            $c->res->redirect($self->redirect_after_login_uri($c));
        }
        else{
            $form->field( $self->password_field )->add_error( $self->login_error_message );
        }
    }
}

sub redirect_after_login_uri {
    my ($self, $c) = @_;
    $c->uri_for('/');
}

1;

=head1 NAME

CatalystX::SimpleLogin::Controller::Login - Configurable login controller

=head1 SYNOPSIS

    # For simple useage exmple, see CatalystX::SimpleLogin, this is a
    # full config example
    __PACKAGE__->config(
        'Controller::Login' => {
            login => 'WithRedirect', # Optional, enables redirect-back feature
            actions => {
                login => { # Also optional
                    PathPart => ['theloginpage'], # Change login action to /theloginpage
                },
                logout => {},
            },
        },
    );

=head1 DESCRIPTION

Controller base class which exists to have login roles composed onto it
for the login and logout actions.

=head1 ATTRIBUTES

=head2 username_field

=head2 password_field

=head2 remember_field

=head2

=head1 METHODS

=head2 BUILD

Cause form instance to be built at application startup.

=head2 login

Login action

=head2 login_GET

Displays the login form

=head2 login_POST

Processes a submitted login form, and if correct, logs the user in
and redirects

=head2 redirect_after_login_uri

Defaults to C<< $c->uri_for('/'); >>

=head1 SEE ALSO

=over

=item L<CatalystX::SimpleLogin::ControllerRole::Login::WithRedirect>

=item L<CatalystX::SimpleLogin::Form::Login>

=back

=head1 AUTHORS

See L<CatalystX::SimpleLogin> for authors.

=head1 LICENSE

See L<CatalystX::SimpleLogin> for license.

=cut

