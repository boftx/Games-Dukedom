package Games::Dukedom::Signal;

use Moo;
with 'Throwable';

has display => (
    is => 'ro',
    default => undef,
);

has request => (
    is => 'ro',
    default => undef,
);

has default => (
    is => 'ro',
    default => undef,
);

1;

__END__

