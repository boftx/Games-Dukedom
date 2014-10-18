package Games::Dukedom::Signal;

use Moo;
with 'Throwable';

use overload
  q{""}    => 'as_string',
  fallback => 1;

has display => (
    is      => 'ro',
    default => undef,
);

has action => (
    is      => 'ro',
    default => undef,
);

has default => (
    is      => 'ro',
    default => undef,
);

sub as_string {
    my $self = shift;

    return $self->display;
}

1;

__END__

=pod

=head1 NAME

Games::Dukedom::Signal = provide "interrupts" to drive the state-machine

=head1 SYNOPSIS

  
 use Games::Dukedom;
  
 my $game = Games::Dukedom->new();
  

=head1 DESCRIPTION

This module is used to signal the application code that a display or input
action is needed.

=head1 ACCESSORS

=head2 display

=head2 action

=head2 default

=head1 METHODS

=head2 as_string

This method will provide a string representing the error, containing the
error's message.

=head1 AUTHOR

Jim Bacon, E<lt>jim@nortx.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014 by Jim Bacon

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself, either Perl version  or,
at your option, any later version of Perl 5 you may have available.

=cut

