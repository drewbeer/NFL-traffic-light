#!/usr/bin/perl
# poolBot, a simple perl bot that runs a health check on the pool pump, and controls the relays

use strict;
use warnings;
use Mojolicious::Lite;
use Mojo::JSON qw(decode_json encode_json);


# gpio relay map
my $relays = ();
$relays->{'green'} = 17;
$relays->{'yellow'} = 18;
$relays->{'red'} = 21;

# debug log and
app->log->level('debug');

my $listenWebPort = 'http://*:3000';

# gpio stuff

# get rpi version because the first gen requires mode not export
my $rpiVer = 1;
my $gpioLoc = `which gpio`;
chomp $gpioLoc;
my $gpioCMD = "$gpioLoc -g";
my $gpioVer = `$gpioLoc -v|grep "*-->"`;
chomp $gpioVer;
if($gpioVer =~ /.*Raspberry Pi\s(\d).*Model/) {
  $rpiVer = $1;
}

app->log->info("Raspberry Pi Version $rpiVer");


### FUNCTIONS ###
# Startup function
sub startup {
  my $self = shift;
  app->log->info('gpio-web starting');

  # # GPIO setup
  # # make sure all pins are set to low
  # app->log->info('setting all relays to off');
  # foreach my $pin (keys %{ $relays }) {
  #   `$gpioCMD export $relays->{$pin} low`;
  # }
}

## relay control ##
# toggle relays
sub relayControl {
  my ($relay, $value) = @_;
  if (!$relay || !$value) {
    return 0;
  }
  my $relayStatus;

  # write the gpio value using a shell
  if ($value eq 'on') {
    if ($rpiVer == 1) {
      `$gpioCMD mode $relays->{$relay} out`;
      $relayStatus = getRelayStatus($relay);
    } else {
      `$gpioCMD write $relays->{$relay} 1`;
      $relayStatus = getRelayStatus($relay);
    }
  } elsif ($value eq 'off') {
    if ($rpiVer == 1) {
      `$gpioCMD mode $relays->{$relay} in`;
      $relayStatus = getRelayStatus($relay);
    } else {
      `$gpioCMD write $relays->{$relay} 0`;
      $relayStatus = getRelayStatus($relay);
    }
  }
  return $relayStatus;
}

# get the relay status
sub getRelayStatus {
  my ($relay) = @_;
  if (!$relay) {
    return 0;
  }
  my $relayStatusPretty = "off";
  # get relay status
  my $relayStatus = `$gpioCMD read $relays->{$relay}`;
  chomp $relayStatus;

  # if the relay is true then its "on"
  if ($relayStatus) {
    $relayStatusPretty = "on";
  }
  return $relayStatusPretty;
}

sub terminate {
  # turn off all the relays
  foreach my $pin (keys %{ $relays }) {
    `$gpioCMD write $relays->{$pin} 0`;
  }
}

# relay control
helper toggleRelay => sub {
  my ($self, $relay, $value) = @_;
  my $relayStatus = relayControl($relay, $value);
  return $relayStatus;
};

# relay status
helper relayStatus => sub {
  my ($self, $relay) = @_;
  my $relayStatus = getRelayStatus($relay);
  return $relayStatus ;
};

## relay API code ##
# relay control
get '/api/relay/set/:name/:value' => sub {
    my $self  = shift;
    my $relay  = $self->stash('name');
    my $value  = $self->stash('value');
    if (!$relay && !$value) {
      return $self->render(json => {error => "missing relay and value"});
    }
    my $relayStatus = $self->toggleRelay($relay, $value);
    return $self->render(json => {relay => $relay, value => $relayStatus});
};

# relay control
get '/api/relay/status/:name' => sub {
    my $self  = shift;
    my $relay  = $self->stash('name');
    if (!$relay) {
      return $self->render(json => {error => "missing relay"});
    }
    my $relayStatus = $self->relayStatus($relay);
    return $self->render(json => {relay => $relay, value => $relayStatus});
};

# exit command
get '/quit' => sub {
  my $self = shift;
  $self->redirect_to('http://google.com');

  my $loop = Mojo::IOLoop->singleton;
  $loop->timer( 1 => sub { terminate(); exit } );
  $loop->start unless $loop->is_running; # portability
};

# Start the app
# web server listen
app->log->info('Starting Web Server');
app->config(gpioweb => {listen => [$listenWebPort]});
app->start;

