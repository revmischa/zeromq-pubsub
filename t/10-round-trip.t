#!perl

use Test::More tests => 5;
use strict;
use warnings;

BEGIN {
    use_ok( 'ZeroMQ::PubSub' ) || print "Bail out!\n";
    use_ok( 'ZeroMQ::PubSub::Client' ) || print "Bail out!\n";
    use_ok( 'ZeroMQ::PubSub::Server' ) || print "Bail out!\n";
}

my $client = ZeroMQ::PubSub::Client->new(
    publish_address   => 'tcp://127.0.0.1:63123',
    subscribe_address => 'tcp://127.0.0.1:63124',
    debug             => 0,
);

my $server = ZeroMQ::PubSub::Server->new(
    publish_addrs   => [ 'tcp://0.0.0.0:63123' ],
    subscribe_addrs => [ 'tcp://0.0.0.0:63124' ],
    debug           => 0,
);

my $pub_sock = $server->bind_publish_socket;
my $sub_sock = $server->bind_subscribe_socket;

my $start_time = time();

# called when server receives ping
$server->subscribe(ping => sub {
    my ($self, $params) = @_;
    is($params->{time}, $start_time, "Publish message received");
});

# called when we receive our ping back
$client->subscribe(ping => sub {
    my ($self, $params) = @_;
    is($params->{time}, $start_time, "Round trip message received");
});

# publish ping event
$client->publish( ping => { 'time' => $start_time } );

# server receive ping
$server->poll_once;

# wait to receive our ping
$client->poll_once;

# done!

done_testing();
