package Games::Dukedom;

use Data::Dumper;
$Data::Dumper::Sortkeys = 1;
$Data::Dumper::Indent   = 1;

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
  ];

our $VERSION = 'v0.1_1';

my %limits = (
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
);

my $fnr = sub {
    my ( $q1, $q2 ) = @_;

    return int( rand() * ( 1 + $q2 - $q1 ) ) + $q1;
};

# my gut tells me that the randomization is overly complex and could be
# be replaced by a much simpler method
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
    is => 'ro',
    default => 1.95,
);

has _base_chance => (
    is       => 'ro',
    init_arg => undef,
    default  => sub {
        my $base = {};
        for ( keys(%limits) ) {
            $base->{$_} = &$gauss( $limits{$_}{q1}, $limits{$_}{q2} );
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
    init_arg => undef,
);

has grain => (
    is       => 'rwp',
    init_arg => undef,
    default  => 4177,
);

has _grain => (
    is       => 'ro',
    init_arg => undef,
);

has land => (
    is       => 'rwp',
    init_arg => undef,
    default  => 600,
);

has _land => (
    is       => 'ro',
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
    init_arg => undef,
    default  => 0,
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

sub BUILD {
    my $self = shift;

    return;
}

sub randomize {
    my $self   = shift;
    my $factor = shift;

    return int( &$fnr( -2, 2 ) + $self->_base_chance->{$factor} );
}

sub play_one_year {
    my $self = shift;

    {
        #last if end_of_game_check();

        #last_year_report();

        $self->init_year;
        $self->fertility_report;

        last if $self->feed_the_peasants;
        last if !$self->purchase_land && $self->sell_land;
        last if $self->war_with_the_king;

        $self->grain_production();

        last if $self->war();

        $self->population_changes();

        last if $self->harvest_grain();

        #$self->update_unrest();
    }

    return;
}

sub init_year {
    my $self = shift;

    ++$self->{year};

    $self->{_population} = Population->new();
    $self->{_grain}      = Grain->new();
    $self->{_land}       = Land->new();
    $self->{_unrest}     = 0;

    my $land = $self->_land;
    $land->{price} =
      int( ( 2 * $self->yield ) + $self->randomize('price') - 5 );
    $land->{price} = 4 if $land->price < 4;

    my $msg = sprintf( "\nYear %d Peasants %d Land %d Grain %d\n",
        $self->year, $self->population, $self->land, $self->grain );
    &{ $self->show_msg }($msg);

    return;
}

sub fertility_report {
    my $self = shift;

    &{$self->show_msg}( "Land Fertility:\n" );
    &{$self->show_msg}( " 100%  80%  60%  40%  20% Depl\n" );
    for ( 100, 80, 60, 40, 20, 0 ) {
        &{$self->show_msg}( sprintf( "%5d", $self->land_fertility->{$_} ) );
    }
    &{$self->show_msg}("\n");
}

sub feed_the_peasants {
    my $self = shift;

    my $food;
    while ( 1 ) {
        &{$self->show_msg}('Grain for food [14]: ');
        next unless defined($food = &{$self->get_value});

        $food ||= 14;
        $food *= $self->population if ( $food < 100 );
        if ( $food > $self->grain ) {
            $self->insufficientGrain();
            next;
        }

        if (   ( ( $food / $self->population ) < 11 )
            && ( $food != $self->grain ) )
        {
            my $msg = "The peasants demonstrate before the castle\n";
            $msg .= "with sharpened scythes\n\n";
            &{$self->show_msg}($msg);

            $self->{_unrest} += 3;
            next;
        }

        $self->_grain->{food} = -$food;
        $self->{grain} += $self->_grain->{food};

        last;
    }

    return $self->starvation_and_unrest($food);
}

sub starvation_and_unrest {
    my $self = shift;
    my $food = shift;

    my $x1   = $food / $self->population;
    if ( $x1 < 13 ) {
        &{$self->show_msg}("Some peasants have starved during the winter\n");
        $self->_population->{starvations} =
          -int( ( $self->population - ( $food / 13 ) ) );
        $self->{population} += $self->_population->starvations;
    }

    $x1 -= 14;
    $x1 = 4 if $x1 > 4;
    $self->{_unrest} =
      $self->_unrest - ( 3 * $self->_population->starvations ) - ( 2 * $x1 );
    if ( $self->_unrest > 88 ) {
        $self->deposed;
        return (1);
    }
    return ( $self->end_of_game_check() ) if ( $self->population < 33 );

    return;
}

sub purchase_land {
    my $self = shift;

    my $land  = $self->_land;
    my $grain = $self->_grain;

    my $msg = sprintf("Land to buy at %d HL/HA [0]: ", int( $land->{price} ));

    my $bought = 0;
    while (1) {
        &{$self->show_msg}($msg);

        next unless defined(my $buy = &{$self->get_value});
        last unless $buy ||= 0;

        if ( $buy * $land->price > $self->grain ) {
            $self->insufficientGrain();
        }
        else {
            $bought = 1;

            $self->land_fertility->{60} += $buy;
            $land->{trades} = $buy;
            $self->{land} += $buy;
            $grain->{land_purchase} = -$buy * $land->{price};
            $self->{grain} += $grain->{land_purchase};

            last;
        }
    }

    return !!$bought;
}

sub sell_land {
    my $self = shift;

    my $land = $self->_land;
    my $grain = $self->_grain;

    my $price = $land->price;

    my $x1 = 0;
    for ( 100, 80, 60 ) {
        $x1 += $self->land_fertility->{$_};
    }

    my $sold  = 0;
    my $valid = 0;
    for ( 1 .. 3 ) {
        --$price;
        my $msg = sprintf( "Land to sell at %d HL/HA [0]: ", $price );
        &{$self->show_msg}($msg);
        next unless defined($sold = &{$self->get_value});

        $sold ||= 0;
        if ( $sold > $x1 ) {
            $msg = sprintf( "But you only have %d HA. of good land\n", $x1 );
            &{$self->show_msg}($msg);
        }
        else {
            $grain->{land_purchase} = $sold * $price;
            if ( $grain->{land_purchase} > 4000 ) {
                print "No buyers have that much grain - sell less\n";
            }
            else {
                $valid = 1;
                last;
            }
        }
    }

    if ( !$valid ) {
        &{$self->show_msg}("Buyers have lost interest\n");
        $sold = 0;
        $grain->{land_purchase} = 0;
    }

    $land->{trades} = -$sold;

    $valid = 0;
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
        print "LAND SELLING LOOP ERROR - CONTACT PROGRAM AUTHOR IF\n";
        print "ERROR IS NOT YOURS IN ENTERING PROGRAM,\n";
        print "AND SEEMS TO BE FAULT OF PROGRAM'S LOGIC.\n";
        exit(1);
    }

    $self->land_fertility->{$sold_q} -= $sold;
    $self->land += $land->trades;

    return end_of_game_check() if $self->land < 10;

    if ( ($price < 4) && $sold ) {
        $grain->{land_purchase} /= 2;
        my $msg = "The High King appropriates half your earnings\n";
        $msg .= "as punishment for selling at such a low price\n";
        &{$self->show_msg}($msg);
    }

    $self->{grain} += $grain->{land_purchase};

    return 0;
}

sub war_with_the_king {
    my $self = shift;

    #return if $self->king_unrest != -2;
    return if $self->king_unrest > -2;

    my $x1 = $self->grain / 100;

    my $msg = "The King's army is about to attack your duchy\n";
    $msg .= sprintf( "You have hired %8.2f foreign mercenaries\n", $x1 );
    $msg .= "at 100 HL. each (payment in advance)\n";
    &{$self->show_msg}($msg);

    if ( ($self->grain * $x1) + $self->population > 2399 ) {
        $msg = "Wipe the blood from the crown - you are now High King!\n\n";
        $msg .= "A nearby monarchy threatens war; ";
        $msg .= "how many .........\n\n\n\n";
        &{$self->show_msg}($msg);

        exit;
    }
    else {
        $msg = "The placement of your head atop the castle gate signifies\n";
        $msg .= "that the High King has abolished your Ducal right\n\n";
        &{$self->show_msg}($msg);

        return 1;
    }
}

sub grain_production {
    my $self = shift;

    my $done = 0;

    my $pop_plant   = $self->population * 4;
    my $grain_plant = $self->grain / 2;
    my $max_grain_plant =
      $grain_plant > $self->land ? $self->land : $grain_plant;
    my $max_plant =
      $pop_plant > $max_grain_plant ? $max_grain_plant : $pop_plant;

    my $msg = sprintf("Land to plant [%d]: ", $max_plant);

    my $grain = $self->_grain;

    my $plant;
    while ( !$done ) {
        &{$self->show_msg}($msg);
        next unless defined( $plant = &{$self->get_value} );

        $plant ||= $max_plant;
        if ( $plant > $self->land ) {
            $self->notEnoughLand();
            next;
        }
        if ( $plant > ( 4 * $self->population ) ) {
            $self->notEnoughPeasants();
            next;
        }
        $grain->{seed} = -2 * $plant;
        if ( -$grain->seed > $self->grain ) {
            $self->insufficientGrain();
            next;
        }
        $done = 1;
    }
    $grain->{yield} = $plant;
    $self->{grain} += $grain->seed;

    my $tmp_quality = $self->update_land_tables($plant);
    $self->crop_yield_and_losses($tmp_quality);

    return;
}

sub update_land_tables {
    my $self = shift;
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
        print "LAND TABLE UPDATING ERROR - PLEASE CONTACT PROGRAM AUTHOR\n";
        print "IF ERROR IS NOT A FAULT OF ENTERING THE PROGRAM, BUT RATHER\n";
        print "FAULT OF THE PROGRAM LOGIC.\n";
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
    my $self = shift;
    my $tmp_q = shift;

    $self->{yield} = $self->randomize('yield') + 3;
    if ( !( $self->year % 7 ) ) {
        printf("Seven year locusts\n");
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
          int( $self->yield* ( $x1 / $grain->yield ) * 100 ) / 100;
    }
    &{$self->show_msg}(sprintf( "Yield = %0.2f HL./HA.\n", $self->yield));

    $x1 = $self->randomize('spoilage') + 3;
    return if ( $x1 < 9 );

    $grain->{spoilage} = -int( ( $x1 * $self->grain ) / 83 );
    $self->{grain} += $grain->{spoilage};
    &{$self->show_msg}("Rats infest the grainery\n");

    return if ( $self->population < 67 ) || ( $self->king_unrest == -1 );

    $x1 = $self->randomize('levies');
    return if $x1 > ( $self->population / 30 );

    my $msg = sprintf( "The High King requires %d peasants for his estates\n", int($x1) );
    $msg .= sprintf( "and mines.  Will you supply them or pay %d\n", int( $x1 * 100 ) );
    $msg .= "HL. of grain instead [y/N]: ";
    &{$self->show_msg}($msg);

    my $ans = &{$self->get_yn};
    $ans ||= 'N';
    if ( $ans =~ /^n/i ) {
        $grain->{taxes} = -100 * $x1;
        $self->{grain} += $grain->{taxes};
        return;
    }
    $self->_population->{levy} = -int($x1);
    $self->{population} += $self->_population->{levy};

    return;
}

sub war {
    my $self = shift;

    if ( $self->king_unrest == -1 ) {
        my $msg = "The High King calls for peasant levies\n";
        $msg .= "and hires many foreign mercenaries\n";
        &{$self->show_msg}($msg);

        $self->{king_unrest} = -2;
        return;
    }

    my $x1 = int( 11 - ( 1.5 * $self->yield) );
    $x1 = 2 if ( $x1 < 2 );
    my $x2;
    if (   $self->king_unrest
        || ( $self->population <= 109 )
        || ( ( 17 * ( $self->land - 400 ) + $self->grain ) <= 10600 ) )
    {
        $x2 = 0;
    }
    else {
        my $msg = "The High King grows uneasy and may\n";
        $msg .= "be subsidizing wars against you\n";
        &{$self->show_msg}($msg);

        $x1 += 2;
        $x2 = $self->year + 5;
    }
    my $x3 = int( $self->randomize('war') );
    return if $x3 > $x1;

    $x2 = int( $x2 + 85 + ( 18 * $self->randomize('first_strike') ) );
    my $x4 = 1.2 - ( $self->_unrest / 16 );
    my $x5 = int( $self->population * $x4 ) + 13;

    my $msg = "A nearby Duke threatens war; Will you attack first [y/N]? ";
    &{$self->show_msg}($msg);

    my $population = $self->_population;

    my $ans = &{$self->get_yn};
    $ans ||= 'N';
    if ( $ans !~ /^N/i ) {
        if ( $x2 >= $x5 ) {
            &{$self->show_msg}("First strike failed - you need professionals\n");
            $population->{casualties} = -$x3 - $x1 - 2;
            $x2 += ( 3 * $population->casualties );
        }
        else {
            &{$self->show_msg}("Pease negotiations were successful\n");
            $population->{casualties} = -$x1 - 1;
            $x2 = 0;
        }
        $self->{population} += $population->casualties;
        if ( $x2 < 1 ) {
            $self->{_unrest} -=
              ( 2 * $population->casualties ) + ( 3 * $population->looted );
            return;
        }
    }

    my $possible = int($self->grain/40);
    $possible = 75 if $possible > 75;

    my $land = $self->_land;

    my $hired;
    my $done = 0;
    while ( !$done ) {
        my $msg = "Hire how many mercenaries at 40 HL each [$possible]? ";
        &{$self->show_msg}($msg);

        next unless defined($hired = &{$self->get_value});
        #$hired ||= 0;
        $hired ||= $possible;

        if ( $hired > 75 ) {
            my $msg = "There are only 75 mercenaries available for hire\n";
            &{$self->show_msg}($msg);

            next;
        }
        else {
            $done = 1;
        }
    }
    $x2 = int( $x2 * $self->war_constant );
    $x5 = int( ( $self->population * $x4 ) + ( 7 * $hired ) + 13 );
    my $x6 = $x2 - ( 4 * $hired ) - int( $x5 / 4 );
    $x2 = $x5 - $x2;
    $land->{spoils} = int( 0.8 * $x2 );
    if ( -$land->spoils > int( 0.67 * $self->land ) ) {
        my $msg = "You have been overrun and have lost the entire Dukedom\n";
        $msg .= "The placement of your head atop the castle gate\n";
        $msg .= "signifies that ";
        $msg .= "the High King has abolished your Ducal right\n\n";
        &{$self->show_msg}($msg);

        return 1;
    }
    $x1 = $land->spoils;

    my $fertility = $self->land_fertility;
    for ( 100, 80, 60 ) {
        $x3 = int( $x1 / ( 3 - ( 5 - ( $_ / 20 ) ) ) );
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

    if ( $land->spoils < 399 ) {
        if ( $x2 >= 0 ) {
            &{$self->show_msg}("You have won the war\n");
            $x4 = 0.67;
            $grain->{spoils} = int( 1.7 * $land->spoils );
            $self->grain += $grain->spoils;
        }
        else {
            &{$self->show_msg}("You have lost the war\n");
            $x4 = $grain->yield / $self->land;
        }
        if ( $x6 <= 9 ) {
            $x6 = 0;
        }
        else {
            $x6 = int( $x6 / 10 );
        }
    }
    else {
        my $msg = "You have overrun the enemy and annexed his entire Dukedom\n";
        &{$self->show_msg}($msg);

        $grain->{spoils} = 3513;
        $self->{grain} += $grain->spoils;
        $x6 = -47;
        $x4 = 0.55;
        if ( $self->king_unrest <= 0 ) {
            $self->{king_unrest} = 1;
            my $msg = "The King fears for his throne and\n";
            $msg .= "may be planning direct action\n";
            &{$self->show_msg}($msg);
        }
    }

    $x6 = $self->population if ( $x6 > $self->population );

    $population->{casualties} -= $x6;
    $self->{population}      -= $x6;
    $grain->{yield} += int( $x4 * $land->spoils );
    $x6 = 40 * $hired;
    if ( $x6 <= $self->grain ) {
        $grain->{wages} = -$x6;

        # what is P[5] (looted) in this case?
    }
    else {
        $grain->{wages} = -$self->grain;
        $population->{looted} = -int( ( $x6 - $self->grain ) / 7 ) - 1;
        my $msg = "There isn't enough grain to pay the mercenaries\n";
        &{$self->show_msg}($msg);
    }
    $self->{grain} += $grain->wages;

    --$self->{population} if ( -$population->looted > $self->population );

    $self->{population} += $population->looted;
    $self->{land} += $land->spoils;
    $self->{_unrest} -=
      ( 2 * $population->casualties ) - ( 3 * $population->looted );

    return;
}

sub population_changes {
    my $self = shift;

    my $x1 = $self->randomize('disease');

    #printf( "X1 = %5.3f, D = %d\n", $x1, $black_D );

    my $population = $self->_population;
    my $x2;
    if ( $x1 <= 3 ) {
        if ( $x1 != 1 ) {
            &{$self->show_msg}("A POX EPIDEMIC has broken out\n");
            $x2 = $x1 * 5;
            $population->{diseased} = -int( $self->population / $x2 );
            $self->{population} += $population->diseased;
        }
        elsif ( $self->black_D <= 0 ) {
            &{$self->show_msg}("The BLACK PLAGUE has struck the area\n");
            $self->{black_D}              = 13;
            $x2                   = 3;
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

    $grain->{yield} = int( $self->yield* $grain->yield );
    $self->{grain} += $grain->yield;
    my $x1 = $grain->yield - 4000;

    $grain->{expense} = -int( 0.1 * $x1 ) if $x1 > 0;

    $grain->{expense} -= 120;
    $self->{grain} += $grain->expense;

    if ( $self->king_unrest < 0 ) {
        return (0);
    }

    $x1 = -int( $self->land / 2 );
    $x1 = ( 2 * $x1 ) if $self->king_unrest >= 2;

    if ( -$x1 > $self->grain ) {
        my $msg = "You have insufficient grain to pay the royal tax\n";
        $msg .= "the High King has abolished your Ducal right\n\n";
        &{$self->show_msg}($msg);

        return 1;
    }
    $grain->{taxes}   += $x1;
    $self->{grain} += $x1;

    return;
}

sub update_unrest {
    my $self = shift;

    $self->{unrest} = int( $self->unrest * 0.85 ) + $self->_unrest;

    return;
}

sub end_of_game {
    my $self = shift;

    return 1 if $self->year >= $self->max_year;

    if ( $self->population < 33 ) {
        print "You have so few peasants left that\n";
        print "the High King has abolished your Ducal right\n\n";
        return 1;
    }
    if ( $self->land < 199 ) {
        print "You have so little land left that\n";
        print "the High King has abolished your Ducal right\n\n";
        return 1;
    }
    if (   ( $self->grain < 429 )
        || ( $self->_unrest > 88 )
        || ( $self->unrest > 99 ) )
    {
        $self->deposed();
        return 1;
    }
    if ( $self->year > 45 && !$self->king_unrest ) {
        print "You have reached the age of mandatory retirement\n";
        return 1;
    }

    if ( $self->king_unrest > 0 ) {
        print "The King demands twice the royal tax in the\n";
        print 'hope of provoking war.  Will you pay? [y/N]: ';
        my $ans = <>;
        chomp($ans);
        $ans ||= 'N';

        $self->_set_king_unrest( ( $ans =~ /^n/i ) ? -1 : 2 );
    }

}

sub notEnoughLand {
    my $self = shift;

    my $msg = "You don't have enough land\n";
    $msg .= sprintf( "You only have %d HA. of land left\n", $self->count );
    &{$self->show_msg}($msg);

    return;
}

sub notEnoughPeasants {
    my $self = shift;

    my $msg = "You don't have enough peasants\n";
    $msg .= sprintf( "Your peasants can only plant %d HA. of land\n",
        4 * $self->population );
    &{$self->show_msg}($msg);

    return;
}

sub insufficientGrain {
    my $self = shift;

    my $msg = "You don't have enough grain\n";
    $msg .= sprintf( "You have %d HL. of grain left,\n", $self->grain);

    $msg .= sprintf( "Enough to buy %d HA. of land\n",
        int( $self->grain / $self->_land->{price} ) )
      if $self->_land->{price} >= 4;

    $msg .= sprintf( "Enough to plant %d HA. of land\n\n", int( $self->grain / 2 ) );

    &{$self->show_msg}($msg);

    return;
}

sub deposed {
    my $self = shift;

    my $msg = "\nThe peasants tire of war and starvation\n";
    $msg .= "You are deposed!\n\n";
    &{$self->show_msg}($msg);

    return;
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
