#!/usr/bin/perl
# parsing the nfl feed for score changes and hits and api to blink the links
use strict;
use warnings;
use HTTP::Tiny;
use JSON;
use Storable qw(nstore retrieve);
use Time::HiRes qw(usleep nanosleep);

my $favTeam = 'NE';
my $webHost = 'localhost';
my $debug = 1;
my $nflScoreFeed = 'http://www.nfl.com/liveupdate/scores/scores.json';

# caching stuff
my $often = 30;
my $cacheTime = 50400;

my $storeFile = 'nfl.db';
my $scoreDB = ();
# check for cache file newer CACHETIME seconds ago
if ( -f $storeFile && time - (stat( $storeFile ))[9] < $cacheTime) {
  # use cached data
  if ($debug) { print "loading local database\n"; }
  $scoreDB = retrieve($storeFile);
}


# reset on restart
if ($debug) { print "resetting lights\n"; }
tfOff('red');
tfOff('green');
tfOff('yellow');

my $runCount = 0;

while (1) {
  my $nflGames = fetchGames();

  unless ($nflGames) {
    if ($debug) { print "failed to fetch games. retrying in 10 seconds.\n"};
    sleep 10;
    next;
  }
  my $liveCount = 0;
  my $finishedCount = 0;
  my $notStartedCount = 0;

  foreach my $games (keys %{ $nflGames } ) {
    if ((!$nflGames->{$games}->{'qtr'}) || ($nflGames->{$games}->{'qtr'} =~ /Pregame/)) {
      $nflGames->{$games}->{'home'}->{'score'}->{'T'} = 0;
      $nflGames->{$games}->{'away'}->{'score'}->{'T'} = 0;
      $nflGames->{$games}->{'qtr'} = 'Not Started';
      $nflGames->{$games}->{'posteam'} = 0;
      $notStartedCount++;
    }

    # check for score change on home
    my $homeName = $nflGames->{$games}->{'home'}->{'abbr'};
    my $homeScore = $nflGames->{$games}->{'home'}->{'score'}->{'T'};
    my $awayName = $nflGames->{$games}->{'away'}->{'abbr'};
    my $awayScore = $nflGames->{$games}->{'away'}->{'score'}->{'T'};

    my $hasBall = $nflGames->{$games}->{'posteam'};

    # home
    if ($homeScore ne $scoreDB->{$games}->{'home'}->{'score'}->{'T'}) {
      my $scoreChange = $nflGames->{$games}->{'home'}->{'score'}->{'T'} - $scoreDB->{$games}->{'home'}->{'score'}->{'T'};
      checkScore($scoreChange,$homeName,$hasBall);
    }

    # away
    if ($awayScore ne $scoreDB->{$games}->{'away'}->{'score'}->{'T'}) {
      my $scoreChange = $nflGames->{$games}->{'away'}->{'score'}->{'T'} - $scoreDB->{$games}->{'away'}->{'score'}->{'T'};
      checkScore($scoreChange,$awayName,$hasBall);
    }

    if ($nflGames->{$games}->{'qtr'} =~ /\d+/) {
      $liveCount++;
      print "$homeName $homeScore - $awayScore $awayName  |  pos $hasBall\n";
    } elsif ($nflGames->{$games}->{'qtr'} =~ /Final/) {
      $finishedCount++;
    }
  }

  # store
  $scoreDB = $nflGames;
  if ($runCount > 10) {
    if ($debug) { print "saving database\n"; }
    nstore($scoreDB, $storeFile);
    $runCount = 0;
  } else {
    $runCount++;
  }



  unless ($liveCount) {
    if ($notStartedCount) {
      print "week: live games: $liveCount | finished: $finishedCount | Pregame: $notStartedCount\n";
      sleep 300;
    } else {
      print "no live games, sleeping for an hour\n";
      sleep 3600;
    }

  } else {
    print "week: live games: $liveCount | finished: $finishedCount | not started: $notStartedCount\n";
  }

  print "\n\n";
  sleep $often
}

exit;


sub checkScore {
  my ($score, $name, $hasBall) = @_;
  print "checkScore: $score\n";

  # its pats turn on green
  if ($name eq $favTeam) {
    tfOn('green');
  }

  # 2 point conversion.
  if ($score == 1) {
    print "extra: $name\n";
    pulse2('yellow', 'red');
  }

  # fieldgoal.
  if ($score == 3) {
    print "fieldGoal: $name\n";
    pulse('red');
    pulse('red');
    pulse('red');
  }

  # 2 point conversion.
  if ($score == 2) {
    if ($hasBall ne $name) {
      print "safety: $name\n";
      pulse('red');
      pulse('red');
    } else {
      print "2 point conversion: $name\n";
      pulse2('yellow', 'red');
      pulse2('yellow', 'red');
    }

  }


  # touchdownish
  if ($score == 6 || $score == 7) {
    print "touchdown: $name\n";
    pulse2('yellow', 'red');
    pulse2('yellow', 'red');
    pulse2('yellow', 'red');
    pulse2('yellow', 'red');
    pulse2('yellow', 'red');
    pulse2('yellow', 'red');
  }

  if ($name eq $favTeam) {
    tfOff('green');
  }

}

sub pulse {
  my $color = shift;
  tfOn($color);
  usleep(300000);
  tfOff($color);
}

sub pulse2 {
  my ($color1, $color2) = @_;
  tfOn($color1);
  tfOn($color2);
  usleep(100000);
  tfOff($color1);
  tfOff($color2);
}


sub fetchGames {
  if ($debug) { print "fetching current nfl games\n"};
  my $data = ();

  my $http = HTTP::Tiny->new();
  my $response = $http->get($nflScoreFeed);

  if ( $response->{'success'} ) {
    # we need to validate the json because sometimes it craps out
    if ($response->{'content'} =~ /\{.*\:\{.*\:.*\}\}/) {
      my $decodedResponse  = decode_json $response->{'content'};
      return $decodedResponse;
    }
    return 0;
  } else {
    print "error: $response->{'status'} $response->{'reason'}\n";
    return 0;
  }
}

sub tfOff {
  my $color = shift;
  my $url = "http://$webHost:3000/api/relay/set/$color/off";
  my $http = HTTP::Tiny->new();
  my $response = $http->get($url);
  return;
}

sub tfOn {
  my $color = shift;
  my $url = "http://$webHost:3000/api/relay/set/$color/on";
  my $http = HTTP::Tiny->new();
  my $response = $http->get($url);
  return;
}
