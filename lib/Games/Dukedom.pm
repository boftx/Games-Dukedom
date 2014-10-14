package Games::Dukedom;

our $VERSION = 'v0.1_1';

use Data::Dumper;
$Data::Dumper::Sortkeys = 1;
$Data::Dumper::Indent   = 1;

use Storable qw( freeze thaw );
use Carp;

use Games::Dukedom::Signal;

use Moo;
use MooX::StrictConstructor;
use MooX::ClassAttribute;

use MooX::Struct -rw, Unrest => [
    qw(
      +population
      )
  ],
  Land => [
    qw(
      +delta
      +trades
      +spoils
      +price
      +sell_price
      +planted
      )
  ],
  Population => [
    qw(
      +delta
      +starvations
      +levy
      +casualties
      +looted
      +diseased
      +deaths
      +births
      )
  ],
  Grain => [
    qw(
      +delta
      +food
      +trades
      +seed
      +spoilage
      +wages
      +spoils
      +yield
      +expense
      +taxes
      )
  ],
  War => [
    qw(
      +first_strike
      +potential
      +desire
      +will
      +grain_damage
      )
  ];

use constant MAX_FOOD_BONUS => 4;
use constant MAX_SELL_TRIES => 3;
use constant MAX_SALE       => 4000;
use constant MIN_LAND_PRICE => 4;

my @steps = (
    qw(
      init_year
      feed_the_peasants
      starvation_and_unrest
      purchase_land
      war_with_the_king
      grain_production
      kings_levy
      war_with_neigbor
      population_changes
      harvest_grain
      update_unrest
      )
);

my %traits = (
    price => {
        q1 => 4,
        q2 => 7,
    },
    yield => {
        q1 => 4,
        q2 => 8,
    },
    spoilage => {
        q1 => 4,
        q2 => 6,
    },
    levies => {
        q1 => 3,
        q2 => 8,
    },
    war => {
        q1 => 5,
        q2 => 8,
    },
    first_strike => {
        q1 => 3,
        q2 => 6,
    },
    disease => {
        q1 => 3,
        q2 => 8,
    },
    birth => {
        q1 => 4,
        q2 => 8,
    },
    merc_quality => {
        q1 => 8,
        q2 => 8,
    },
);

my $fnr = sub {
    my ( $q1, $q2 ) = @_;

    return int( rand() * ( 1 + $q2 - $q1 ) ) + $q1;
};

my $gauss = sub {
    my ( $q1, $q2 ) = @_;

    my $g0;

    my $q3 = &$fnr( $q1, $q2 );
    if ( &$fnr( $q1, $q2 ) > 5 ) {
        $g0 = ( $q3 + &$fnr( $q1, $q2 ) ) / 2;
    }
    else {
        $g0 = $q3;
    }

    return $g0;
};

my $print_msg = sub {
    my $msg = shift;

    print $msg;

    return;
};

my $input_yn = sub {
    my $default = shift || 'n';

    my $ans = <>;
    chomp($ans);
    $ans ||= $default;

    return unless $ans =~ /^(?:y|n)$/i;

    return lc($ans);
};

my $input_value = sub {
    my $ans = <>;
    chomp($ans);

    return ( $ans !~ /\D/ ) ? $ans : undef;
};

class_has signal => (
    is       => 'ro',
    init_arg => undef,
    default  => 'Games::Dukedom::Signal',
    handles  => 'Throwable',
);

class_has show_msg => (
    is      => 'rw',
    default => sub { $print_msg },
);

class_has get_yn => (
    is      => 'rw',
    default => sub { $input_yn },
);

class_has get_value => (
    is      => 'rw',
    default => sub { $input_value },
);

class_has max_year => (
    is      => 'rw',
    default => 45,
);

class_has war_constant => (
    is      => 'ro',
    default => 1.95,
);

has base_chance => (
    is       => 'ro',
    init_arg => undef,
    default  => sub {
        my $base = {};
        for ( keys(%traits) ) {
            $base->{$_} = &$gauss( $traits{$_}{q1}, $traits{$_}{q2} );
        }
        return $base;
    },
);

has year => (
    is       => 'rwp',
    init_arg => undef,
    default  => 0,
);

has population => (
    is       => 'rwp',
    init_arg => undef,
    default  => 100,
);

has _population => (
    is       => 'ro',
    lazy     => 1,
    clearer  => 1,
    default  => sub { Population->new; },
    init_arg => undef,
);

has grain => (
    is       => 'rwp',
    init_arg => undef,
    default  => 4177,
);

has _grain => (
    is       => 'ro',
    clearer  => 1,
    lazy     => 1,
    default  => sub { Grain->new; },
    init_arg => undef,
);

has land => (
    is       => 'rwp',
    init_arg => undef,
    default  => 600,
);

has _land => (
    is       => 'ro',
    lazy     => 1,
    clearer  => 1,
    default  => sub { Land->new; },
    init_arg => undef,
);

has land_fertility => (
    is       => 'ro',
    init_arg => undef,
    default  => sub {
        {
            100 => 216,
            80  => 200,
            60  => 184,
            40  => 0,
            20  => 0,
            0   => 0,
        };
    },
);

has war => (
    is       => 'rwp',
    init_arg => undef,
    default  => 0,
);

has _war => (
    is       => 'ro',
    lazy     => 1,
    clearer  => 1,
    default  => sub { War->new; },
    init_arg => undef,
);

has yield => (
    is       => 'rwp',
    init_arg => undef,
    default  => 3.95,
);

has unrest => (
    is       => 'rwp',
    init_arg => undef,
    default  => 0,
);

has _unrest => (
    is       => 'ro',
    default  => 0,
    init_arg => undef,
);

has king_unrest => (
    is       => 'rwp',
    init_arg => undef,
    default  => 0,
);

has black_D => (
    is       => 'ro',
    init_arg => undef,
    default  => 0,
);

has input => (
    is      => 'rw',
    clearer => 1,
    default => undef,
);

has _steps => (
    is       => 'lazy',
    init_arg => undef,
    clearer  => 1,
    default  => sub { [@steps] },
);

has status => (
    is       => 'rwp',
    init_arg => undef,
    default  => 'running',
);

has _msg => (
    is       => 'rw',
    init_arg => undef,
    clearer  => 1,
    default  => undef,
);

sub BUILD {
    my $self = shift;

    return;
}

# guarantee we have a clean input if needed. this avoids a potential
# problem if the "clear_" behavior changes.
before throw => sub {
    my $self = shift;
    my %params = @_;

    $self->clear_input;

    return;
};

sub randomize {
    my $self  = shift;
    my $trait = shift;

    return int( &$fnr( -2, 2 ) + $self->base_chance->{$trait} );
}

sub input_is_yn {
    my $self = shift;

    my $value = $self->input;
    chomp($value) if defined($value);

    return !!( defined($value) && $value =~ /^(?:y|n)$/i );
}

sub input_is_value {
    my $self = shift;

    my $value = $self->input;
    chomp($value) if defined($value);

    return !!( defined($value) && ( $value =~ /^(?:\d+)$/ ) );
}

sub next_step {
    my $self = shift;
    my $next = shift;

    croak 'Illegal value for "next_step"' unless $self->can($next);

    return unshift( @{ $self->_steps }, $next );
}

sub play_one_year {
    my $self   = shift;
    my $params = @_;

    while ( @{ $self->_steps } ) {
        my $step = shift( @{ $self->_steps } );

        $self->$step;
        $self->clear_input;
    }

    #print $self->end_of_year_report();

    $self->_clear_steps;
    $self->_clear_population;
    $self->_clear_grain;
    $self->_clear_land;
    $self->_clear_war;

    $self->end_of_game_check;

    return;
}

sub init_year {
    my $self = shift;

#    print "in init_year\n";
#    print Dumper( $self->_steps );

    ++$self->{year};

    $self->_population->delta( $self->population );
    $self->_grain->delta( $self->grain );
    $self->_land->delta( $self->land );

    $self->{_unrest} = 0;

    $self->_land->{price} =
      int( ( 2 * $self->yield ) + $self->randomize('price') - 5 );
    $self->_land->{price} = MIN_LAND_PRICE
      if $self->_land->price < MIN_LAND_PRICE;

    $self->_land->{sell_price} = $self->_land->price;

    $self->{_msg} = $self->summary_report;
    $self->{_msg} .= $self->fertility_report;

    $self->next_step('display_msg');

    return;
}

sub display_msg {
    my $self = shift;

    $self->throw( display => $self->_clear_msg );
}

sub summary_report {
    my $self = shift;

    my $msg = sprintf( "\nYear %d Peasants %d Land %d Grain %d\n",
        $self->year, $self->population, $self->land, $self->grain );

    return $msg;
}

sub fertility_report {
    my $self = shift;

    my $msg = "Land Fertility:\n";
    $msg .= " 100%  80%  60%  40%  20% Depl\n";
    for ( 100, 80, 60, 40, 20, 0 ) {
        $msg .= sprintf( "%5d", $self->land_fertility->{$_} );
    }
    $msg .= "\n";

    return $msg;
}

sub feed_the_peasants {
    my $self = shift;

    my $hint = ( $self->grain / $self->population ) < 11 ? $self->grain : 14;

    $self->next_step('feed_the_peasants')
      and $self->throw(
        display => "Grain for food [$hint]: ",
        request => 'get_value',
        default => $hint,
    ) unless $self->input_is_value;

    my $food = $self->input;

    # shortcut
    $food *= $self->population if ( $food < 100  && $self->grain > $food );

    if ( $food > $self->grain ) {
        $self->next_step('feed_the_peasants');

        $self->throw( display => $self->_insufficient_grain );
    }
    elsif (( ( $food / $self->population ) < 11 )
        && ( $food != $self->grain ) )
    {
        $self->{_unrest} += 3;

        $self->next_step('feed_the_peasants');

        my $msg = "The peasants demonstrate before the castle\n";
        $msg .= "with sharpened scythes\n\n";
        $self->throw( display => $msg );
    }

    $self->_grain->{food} = -$food;
    $self->{grain} += $self->_grain->{food};

    return;
}

sub starvation_and_unrest {
    my $self = shift;

    my $food = -$self->_grain->food;

    my $x1 = $food / $self->population;
    if ( $x1 < 13 ) {
        $self->_population->{starvations} =
          -int( ( $self->population - ( $food / 13 ) ) );
        $self->{population} += $self->_population->starvations;
    }

    # only allow bonus for extra food up to 18HL/peasant
    $x1 -= 14;
    $x1 = MAX_FOOD_BONUS if $x1 > MAX_FOOD_BONUS;

    $self->{_unrest} =
      $self->_unrest - ( 3 * $self->_population->starvations ) - ( 2 * $x1 );

    if ( $self->_population->starvations < 0 ) {
        $self->_msg("Some peasants have starved during the winter\n");
        $self->next_step('display_msg');
    }

    return ( ( $self->_unrest > 88 ) || ( $self->population < 33 ) );
}

sub purchase_land {
    my $self = shift;

    my $land  = $self->_land;
    my $grain = $self->_grain;

    my $msg = sprintf( "Land to buy at %d HL/HA [0]: ", int( $land->{price} ) );
    $self->next_step('purchase_land')
      and $self->throw( display => $msg, request => 'get_value', default => 0 )
      unless $self->input_is_value();

    $self->next_step('sell_land') and return
      unless my $buy = $self->input;

    $self->next_step('purchase_land')
      and $self->throw( display => $self->_insufficient_grain )
      if ( $buy * $land->price > $self->grain );

    $self->land_fertility->{60} += $buy;
    $land->{trades} = $buy;
    $self->{land} += $buy;
    $grain->{trades} = -$buy * $land->{price};
    $self->{grain} += $grain->{trades};

    return;
}

sub sell_land {
    my $self = shift;

    my $land  = $self->_land;
    my $grain = $self->_grain;

    if ( $land->price - $land->sell_price > MAX_SELL_TRIES ) {
        $grain->{trades} = 0;

        $self->throw( display => "Buyers have lost interest\n" );
    }

    my $x1 = 0;
    for ( 100, 80, 60 ) {
        $x1 += $self->land_fertility->{$_};
    }

    my $price = --$land->{sell_price};

    my $msg = sprintf( "Land to sell at %d HL/HA [0]: ", $price );
    $self->next_step('sell_land')
      and $self->throw( display => $msg, request => 'get_value', default => 0 )
      unless $self->input_is_value();

    return unless my $sold = $self->input;

    $self->{_msg} = undef;
    if ( $sold > $x1 ) {
        $self->next_step('display_msg');
        $self->{_msg} = sprintf( "You only have %d HA. of good land\n", $x1 );
    }
    elsif ( ( $grain->{trades} = $sold * $price ) > MAX_SALE ) {
        $self->next_step('display_msg');
        $self->{_msg} = "No buyers have that much grain - sell less\n";
    }
    return if $self->_msg;

    $land->{trades} = -$sold;

    my $valid = 0;
    my $sold_q;
    for ( 60, 80, 100 ) {
        $sold_q = $_;
        if ( $sold <= $self->land_fertility->{$_} ) {
            $valid = 1;
            last;
        }
        else {
            $sold -= $self->land_fertility->{$_};
            $self->land_fertility->{$_} = 0;
        }
    }

    if ( !$valid ) {
        my $msg = "LAND SELLING LOOP ERROR - CONTACT PROGRAM AUTHOR IF\n";
        $msg .= "ERROR IS NOT YOURS IN ENTERING PROGRAM,\n";
        $msg .= "AND SEEMS TO BE FAULT OF PROGRAM'S LOGIC.\n";

        die $msg;
    }

    $self->land_fertility->{$sold_q} -= $sold;
    $self->land += $land->trades;

    $self->_set_status('game_over') if $self->land < 10;

    $msg = '';
    if ( ( $price < MIN_LAND_PRICE ) && $sold ) {
        $grain->{trades} = int( $grain->{trades} / 2 );
        $msg = "\nThe High King appropriates half your earnings\n";
        $msg .= "as punishment for selling at such a low price\n";
    }

    $self->{grain} += $grain->{trades};
    $self->throw( display => $msg ) if $msg;

    return;
}

sub war_with_the_king {
    my $self = shift;

    $self->king_wants_war if $self->king_unrest > 0;

    return if $self->king_unrest > -2;

    my $mercs = int( $self->grain / 100 );

    my $msg = "\nThe King's army is about to attack your duchy\n";
    $msg .= sprintf( "You have hired %d foreign mercenaries\n", $mercs );
    $msg .= "at 100 HL. each (payment in advance)\n\n";

    # the source i ported from used this, but i found another version
    # that used the value i have changed to.
    #if ( ( $self->grain * $mercs ) + $self->population > 2399 ) {
    #if ( ( 8 * $mercs ) + $self->population > 2399 ) {
    if ( ( int($self->randomize('merc_quality')) * $mercs ) + $self->population > 2399 ) {
        $msg .= "Wipe the blood from the crown - you are now High King!\n\n";
        $msg .= "A nearby monarchy threatens war; ";
        $msg .= "how many .........\n\n\n\n";
    }
    else {
        $msg .= "The placement of your head atop the castle gate signifies\n";
        $msg .= "that the High King has abolished your Ducal right\n\n";
    }
    $self->_set_status('game_over');

    $self->{_msg}   = $msg;
    $self->{_steps} = ['display_msg'];

    return;
}

sub king_wants_war {
    my $self = shift;

    return unless $self->king_unrest > 0;

    my $msg = "The King demands twice the royal tax in the\n";
    #$msg .= 'hope of provoking war.  Will you pay? [y/N]: ';
    $msg .= 'hope of provoking war.  Will you pay? [Y/n]: ';

    $self->next_step('king_wants_war')
#      and $self->throw( display => $msg, request => 'get_yn', default => 'N' )
      and $self->throw( display => $msg, request => 'get_yn', default => 'Y' )
      unless $self->input_is_yn;

    my $ans = $self->input;
    #$ans ||= 'N';
    $ans ||= 'Y';

    $self->_set_king_unrest( ( $ans =~ /^n/i ) ? -1 : 2 );

    return;
}

sub grain_production {
    my $self = shift;

    my $done = 0;

    my $pop_plant   = $self->population * 4;
    my $grain_plant = int($self->grain / 2);
    my $max_grain_plant =
      $grain_plant > $self->land ? $self->land : $grain_plant;
    my $max_plant =
      $pop_plant > $max_grain_plant ? $max_grain_plant : $pop_plant;

    my $msg = sprintf( "Land to plant [%d]: ", $max_plant );
    $self->next_step('grain_production')
      and $self->throw(
        display => $msg,
        request => 'get_value',
        default => $max_plant
      ) unless $self->input_is_value();

    my $plant = $self->input || $max_plant;

    my $grain = $self->_grain;
    $msg = '';

    if ( $plant > $self->land ) {
        $msg = "You don't have enough land\n";
        $msg .= sprintf( "You only have %d HA. of land left\n", $self->land );
    }
    if ( $plant > ( 4 * $self->population ) ) {
        $msg = "You don't have enough peasants\n";
        $msg .= sprintf( "Your peasants can only plant %d HA. of land\n",
            4 * $self->population );
    }
    $grain->{seed} = -2 * $plant;
    if ( -$grain->seed > $self->grain ) {
        $msg = $self->_insufficient_grain();
    }

    if ($msg) {
        $self->next_step('grain_production');
        $self->throw( display => $msg );
    }

    $grain->{yield} = $plant;
    $self->_land->{planted} = $plant;
    $self->{grain} += $grain->seed;

    my $tmp_quality = $self->update_land_tables($plant);
    $self->crop_yield_and_losses($tmp_quality);

    return;
}

sub update_land_tables {
    my $self  = shift;
    my $plant = shift;

    my $valid = 0;

    my %tmp_quality = (
        100 => 0,
        80  => 0,
        60  => 0,
        40  => 0,
        20  => 0,
        0   => 0,
    );

    my $quality = $self->land_fertility;

    my $qfactor;
    for (qw( 100 80 60 40 20 0 )) {
        $qfactor = $_;
        if ( $plant <= $quality->{$qfactor} ) {
            $valid = 1;
            last;
        }
        else {
            $plant -= $quality->{$qfactor};
            $tmp_quality{$qfactor} = $quality->{$qfactor};
            $quality->{$qfactor} = 0;
        }
    }

    if ( !$valid ) {
        warn "LAND TABLE UPDATING ERROR - PLEASE CONTACT PROGRAM AUTHOR\n";
        warn "IF ERROR IS NOT A FAULT OF ENTERING THE PROGRAM, BUT RATHER\n";
        warn "FAULT OF THE PROGRAM LOGIC.\n";

        exit(1);
    }

    $tmp_quality{$qfactor} = $plant;
    $quality->{$qfactor} -= $plant;
    $quality->{100} += $quality->{80};
    $quality->{80} = 0;

    for ( 60, 40, 20, 0 ) {
        $quality->{ $_ + 40 } += $quality->{$_};
        $quality->{$_} = 0;
    }

    for ( 100, 80, 60, 40, 20 ) {
        $quality->{ $_ - 20 } += $tmp_quality{$_};
    }

    $quality->{0} += $tmp_quality{0};

    return \%tmp_quality;
}

sub crop_yield_and_losses {
    my $self  = shift;
    my $tmp_q = shift;

    $self->{_msg} = '';

    $self->{yield} = $self->randomize('yield') + 3;
    if ( !( $self->year % 7 ) ) {
        $self->{_msg} .= "Seven year locusts\n";
        $self->{yield} /= 2;
    }

    my $x1 = 0;
    for ( 100, 80, 60, 40, 20 ) {
        $x1 += $tmp_q->{$_} * ( $_ / 100 );
    }

    my $grain = $self->_grain;

    if ( $grain->yield == 0 ) {
        $self->{yield} = 0;
    }
    else {
        $self->{yield} =
          int( $self->yield * ( $x1 / $grain->yield ) * 100 ) / 100;
    }
    $self->{_msg} .= sprintf( "Yield = %0.2f HL./HA.\n", $self->yield );

    $x1 = $self->randomize('spoilage') + 3;
    unless ( $x1 < 9 ) {
        $grain->{spoilage} = -int( ( $x1 * $self->grain ) / 83 );
        $self->{grain} += $grain->{spoilage};
        $self->{_msg} .= "Rats infest the grainery\n";
    }

    $self->next_step('display_msg');

    return;
}

sub kings_levy {
    my $self = shift;

    return if ( $self->population < 67 ) || ( $self->king_unrest == -1 );

    # there is an edge case where entering an invalid answer might allow
    # one to avoid this, but ... who cares
    my $x1 = $self->randomize('levies');
    return if $x1 > ( $self->population / 30 );

    my $msg = sprintf( "The High King requires %d peasants for his estates\n",
        int($x1) );
    $msg .= sprintf( "and mines.  Will you supply them or pay %d\n",
        int( $x1 * 100 ) );
    $msg .= "HL. of grain instead [Y/n]: ";

    $self->next_step('kings_levy')
      and $self->throw( display => $msg, request => 'get_yn', default => 'Y' )
      unless $self->input_is_yn();

    if ( $self->input =~ /^n/i ) {
        $self->_grain->{taxes} = -100 * $x1;
        $self->{grain} += $self->_grain->{taxes};
    }
    else {
        $self->_population->{levy} = -int($x1);
        $self->{population} += $self->_population->{levy};
    }

    return;
}

# TODO: find names for the "magic numbers" and change them to constants
sub war_with_neigbor {
    my $self = shift;

    if ( $self->king_unrest == -1 ) {
        $self->{_msg} = "\nThe High King calls for peasant levies\n";
        $self->{_msg} .= "and hires many foreign mercenaries\n";

        $self->{king_unrest} = -2;
    }
    else {
        my $war = $self->_war;
        $war->{potential} = int( 11 - ( 1.5 * $self->yield ) );
        $war->{potential} = 2 if ( $war->potential < 2 );
        if (   $self->king_unrest
            || ( $self->population <= 109 )
            || ( ( 17 * ( $self->land - 400 ) + $self->grain ) <= 10600 ) )
        {
            $war->{desire} = 0;
        }
        else {
            $self->{_msg} = "\nThe High King grows uneasy and may\n";
            $self->{_msg} .= "be subsidizing wars against you\n";

            $war->{potential} += 2;
            $war->{desire} = $self->year + 5;
        }
        $self->{war} = int( $self->randomize('war') );
        $self->next_step('first_strike')
          unless $self->war > $war->potential;
        $self->_war->{first_strike} =
          int( $war->{desire} + 85 + ( 18 * $self->randomize('first_strike') ) );
    }
    $self->next_step('display_msg') if $self->_msg;

    return;
}

sub first_strike {
    my $self = shift;

    $self->_war->{will} = 1.2 - ( $self->_unrest / 16 );
    my $x5 = int( $self->population * $self->_war->will ) + 13;

    my $msg = "A nearby Duke threatens war; Will you attack first [y/N]? ";

    $self->next_step('first_strike')
      and $self->throw( display => $msg, request => 'get_yn', default => 'N' )
      unless $self->input_is_yn();

    my $population = $self->_population;

    $self->{_msg} = '';
    if ( $self->input !~ /^n/i ) {
        if ( $self->_war->{first_strike} >= $x5 ) {
            $self->next_step('goto_war');
            $self->{_msg} = "First strike failed - you need professionals\n";
            $population->{casualties} = -$self->war - $self->_war->potential - 2;
            $self->_war->{first_strike} += ( 3 * $population->casualties );
        }
        else {
            $self->{_msg} = "Peace negotiations were successful\n";

            $population->{casualties} = -$self->_war->potential - 1;
            $self->_war->{first_strike} = 0;
        }
        $self->{population} += $population->casualties;
        if ( $self->_war->first_strike < 1 ) {
            $self->{_unrest} -=
              ( 2 * $population->casualties ) + ( 3 * $population->looted );
        }
    }
    else {
        $self->next_step('goto_war');
    }
    $self->next_step('display_msg') if $self->_msg;

    return;
}

sub goto_war {
    my $self = shift;

    my $possible = int( $self->grain / 40 );
    $possible = 75 if $possible > 75;
    $possible = 0  if $possible < 0;

    my $msg = "Hire how many mercenaries at 40 HL each [$possible]? ";
    $self->next_step('goto_war')
      and $self->throw(
        display => $msg,
        request => 'get_value',
        default => $possible
      ) unless $self->input_is_value();

    my $hired = $self->input || $possible;

    if ( $hired > 75 ) {
        my $msg = "There are only 75 mercenaries available for hire\n";
        $self->next_step('goto_war');

        $self->throw( display => $msg );
    }

    my $war  = $self->_war;
    my $land = $self->_land;

    $war->{desire} = int( $war->desire * $self->war_constant );
    my $x5 = int( ( $self->population * $war->will ) + ( 7 * $hired ) + 13 );
    my $x6 = $war->desire - ( 4 * $hired ) - int( $x5 / 4 );
    $war->{desire}      = $x5 - $war->desire;
    $land->{spoils} = int( 0.8 * $war->desire );
    if ( -$land->spoils > int( 0.67 * $self->land ) ) {
        $self->{_steps} = [];
        $self->_set_status('game_over');

        my $msg = "You have been overrun and have lost the entire Dukedom\n";
        $msg .= "The placement of your head atop the castle gate\n";
        $msg .= "signifies that ";
        $msg .= "the High King has abolished your Ducal right\n\n";

        $self->throw( display => $msg );
    }

    my $x1 = $land->spoils;

    my $fertility = $self->land_fertility;
    for ( 100, 80, 60 ) {
        my $x3 = int( $x1 / ( 3 - ( 5 - ( $_ / 20 ) ) ) );
        if ( -$x3 <= $fertility->{$_} ) {
            $x5 = $x3;
        }
        else {
            $x5 = -$fertility->{$_};
        }
        $fertility->{$_} += $x5;
        $x1 = $x1 - $x5;
    }
    for ( 40, 20, 0 ) {
        if ( -$x1 <= $fertility->{$_} ) {
            $x5 = $x1;
        }
        else {
            $x5 = -$fertility->{$_};
        }
        $fertility->{$_} += $x5;
        $x1 = $x1 - $x5;
    }

    my $grain = $self->_grain;

    $msg = '';
    if ( $land->spoils < 399 ) {
        if ( $war->desire >= 0 ) {
            $msg             = "You have won the war\n";
            $war->{grain_damage}       = 0.67;
            $grain->{spoils} = int( 1.7 * $land->spoils );
            $self->grain += $grain->spoils;
        }
        else {
            $msg = "You have lost the war\n";
            $war->{grain_damage} = int(($grain->yield / $self->land) * 100) / 100;
        }
        if ( $x6 <= 9 ) {
            $x6 = 0;
        }
        else {
            $x6 = int( $x6 / 10 );
        }
    }
    else {
        $msg = "You have overrun the enemy and annexed his entire Dukedom\n";

        $grain->{spoils} = 3513;
        $self->{grain} += $grain->spoils;
        $x6 = -47;
        $war->{grain_damage} = 0.55;
        if ( $self->king_unrest <= 0 ) {
            $self->{king_unrest} = 1;
            $msg .= "The King fears for his throne and\n";
            $msg .= "may be planning direct action\n";
        }
    }

    $x6 = $self->population if ( $x6 > $self->population );

    my $population = $self->_population;

    $population->{casualties} -= $x6;
    $self->{population}       -= $x6;
    $grain->{yield} += int( $war->grain_damage * $land->spoils );
    $x6 = 40 * $hired;
    if ( $x6 <= $self->grain ) {
        $grain->{wages} = -$x6;

        # what is P[5] (looted) in this case?
    }
    else {
        $grain->{wages} = -$self->grain;
        $population->{looted} = -int( ( $x6 - $self->grain ) / 7 ) - 1;
        $msg .= "There isn't enough grain to pay the mercenaries\n";
    }
    $self->{grain} += $grain->wages;

    --$self->{population} if ( -$population->looted > $self->population );

    $self->{population} += $population->looted;
    $self->{land}       += $land->spoils;
    $self->{_unrest} -=
      ( 2 * $population->casualties ) - ( 3 * $population->looted );

    $self->next_step('display_msg') if $self->{_msg} = $msg;

    return;
}

sub population_changes {
    my $self = shift;

    my $x1 = $self->randomize('disease');

    my $population = $self->_population;
    my $x2;
    if ( $x1 <= 3 ) {
        if ( $x1 != 1 ) {
            $self->{_msg} = "A POX EPIDEMIC has broken out\n";
            $self->next_step('display_msg');

            $x2 = $x1 * 5;
            $population->{diseased} = -int( $self->population / $x2 );
            $self->{population} += $population->diseased;
        }
        elsif ( $self->black_D <= 0 ) {
            $self->{_msg} = "The BLACK PLAGUE has struck the area\n";
            $self->next_step('display_msg');

            $self->{black_D}        = 13;
            $x2                     = 3;
            $population->{diseased} = -int( $self->population / $x2 );
            $self->{population} += $population->diseased;
        }
    }

    $x1 = $population->looted ? 4.5 : $self->randomize('birth') + 4;

    $population->{births} = int( $self->population / $x1 );
    $population->{deaths} = int( 0.3 - ( $self->population / 22 ) );
    $self->{population} += $population->deaths + $population->births;

    --$self->{black_D};

    return;
}

sub harvest_grain {
    my $self = shift;

    my $grain = $self->_grain;

    $grain->{yield} = int( $self->yield * $grain->yield );
    $self->{grain} += $grain->yield;
    my $x1 = $grain->yield - 4000;

    $grain->{expense} = -int( 0.1 * $x1 ) if $x1 > 0;

    $grain->{expense} -= 120;
    $self->{grain} += $grain->expense;

    return if $self->king_unrest < 0;

    $x1 = -int( $self->land / 2 );
    $x1 = ( 2 * $x1 ) if $self->king_unrest >= 2;

    if ( -$x1 > $self->grain ) {
        $self->{_msg} = "You have insufficient grain to pay the royal tax\n";
        $self->{_msg} .= "the High King has abolished your Ducal right\n\n";
        $self->next_step('display_msg');

        $self->_set_status('game_over');
        return 1;
    }
    $grain->{taxes} += $x1;
    $self->{grain}  += $x1;

    return;
}

sub update_unrest {
    my $self = shift;

    $self->{unrest} = int( $self->unrest * 0.85 ) + $self->_unrest;

    return;
}

sub end_of_game_check {
    my $self = shift;

    my $msg = '';

    if (   ( $self->grain < 429 )
        || ( $self->_unrest > 88 )
        || ( $self->unrest > 99 ) )
    {
        $msg = "\nThe peasants tire of war and starvation\n";
        $msg .= "You are deposed!\n\n";
    }
    elsif ( $self->population < 33 ) {
        $msg = "You have so few peasants left that\n";
        $msg .= "the High King has abolished your Ducal right\n\n";
    }
    elsif ( $self->land < 199 ) {
        $msg = "You have so little land left that\n";
        $msg .= "the High King has abolished your Ducal right\n\n";
    }
    elsif ( $self->year >= 45 && !$self->king_unrest ) {
        $msg = "You have reached the age of mandatory retirement\n\n";
    }

    $self->_set_status('game_over') and $self->throw( display => $msg )
      if $msg;

    return;
}

sub game_over {
    my $self = shift;

    return !!( $self->status eq 'game_over' );
}

sub _insufficient_grain {
    my $self = shift;

    my $msg = "You don't have enough grain\n";
    $msg .= sprintf( "You have %d HL. of grain left,\n", $self->grain );

    $msg .= sprintf( "Enough to buy %d HA. of land\n",
        int( $self->grain / $self->_land->{price} ) )
      if $self->_land->{price} >= MIN_LAND_PRICE;

    $msg .=
      sprintf( "Enough to plant %d HA. of land\n\n", int( $self->grain / 2 ) );

    return $msg;
}

sub end_of_year_report {
    my $self = shift;


    my $msg = "\n";
    for ( sort( keys( %{ $self->_population } ) ) ) {
        $msg .= sprintf( "%-20.20s %d\n", $_, $self->_population->$_ );
    }
    $msg .= sprintf( "%-20.20s %d\n\n", "Peasants at end", $self->population );

    for ( sort( keys( %{ $self->_land } ) ) ) {
        $msg .= sprintf( "%-20.20s %d\n", $_, $self->_land->$_ );
    }
    $msg .= sprintf( "%-20.20s %d\n\n", "Land at end", $self->land );

    for ( sort( keys( %{ $self->_grain } ) ) ) {
        $msg .= sprintf( "%-20.20s %d\n", $_, $self->_grain->$_ );
    }
    $msg .= sprintf( "%-20.20s %d\n\n", "Grain at end", $self->grain );

    for ( sort( keys( %{ $self->_war } ) ) ) {
        $msg .= sprintf( "%-20.20s %d\n", $_, $self->_war->$_ );
    }
    $msg .= sprintf( "%-20.20s %d\n\n", "War factor", $self->war );

    return $msg;
}

1;

__END__

=head1 NAME

Games::Dukedom - The classic big-iron game

=head1 SYNOPSIS

  use Games::Dukedom;

=head1 DESCRIPTION

This is an implementation of the classic game of "Dukedom". It is intended
to be display agnostic so that it can be used not only by command line
scripts such as the one included but also by graphical UIs such as Tk
or web sites.

=head1 AUTHOR

Jim Bacon, E<lt>jim@nortx.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2014 by Jim Bacon

This library is free software; you can redistribute it and/or modify it
under the same terms as Perl itself, either Perl version  or,
at your option, any later version of Perl 5 you may have available.

=cut
