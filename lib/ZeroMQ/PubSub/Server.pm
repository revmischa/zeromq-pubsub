# Real-time message queue server

package ZeroMQ::PubSub::Server;

use Moose;
extends 'ZeroMQ::PubSub';

use ZeroMQ qw/:all/;
use Clone qw/clone/;
use Carp qw/croak/;
use MooseX::Event;

# socket to listen for client events
# clients publish events to us here
sub _build_publish_sock {
    my ($self) = @_;

    my $pub_sock = $self->context->socket(ZMQ_SUB);

    # by default ZMQ_SUB filters out all events, remove filter
    $pub_sock->setsockopt(ZMQ_SUBSCRIBE, '');
    
    return $pub_sock;
}

# server event socket that broadcasts events to all connected clients
sub _build_subscribe_sock {
    my ($self) = @_;

    my $sub_sock = $self->context->socket(ZMQ_PUB);
    return $sub_sock;
}


=head1 NAME

ZeroMQ::PubSub::Server - Listen for published events and broadcast
them to all connected subscribers

=head1 SYNOPSIS

    use ZeroMQ::PubSub::Server;
    my $server = ZeroMQ::PubSub::Server->new(
        # clients connect here to publish events
        publish_addrs => [ 'tcp://0.0.0.0:4000', 'ipc:///tmp/pub.sock' ],

        # clients connect here to subscribe to events
        subscribe_addrs => [ 'tcp://0.0.0.0:5000', 'ipc:///tmp/sub.sock' ],

        debug => 1,
    );

    # listen for events forever
    {
        # listen for events being published to our server
        my $pub_sock = $self->bind_publish_socket;

        # set up to broadcast events to waiting subscribers
        my $sub_sock = $self->bind_subscribe_socket;

        # main processing loop
        while (1) {
            # block while we get one message
            my $msg = $server->recv;

            # deep clone $msg so that event handlers can't modify it
            my $orig = clone($msg);

            # run event handlers
            $self->dispatch_event($msg);

            # broadcast event to subscribers
            $server->broadcast($orig)
        }
    }

    # exact same as above
    $server->run;


=head1 ATTRIBUTES

=head2 publish_addrs

ArrayRef of socket addresses to receive client event publishing requests

=cut

has 'publish_addrs' => (
    is => 'rw',
    isa => 'ArrayRef[Str]',
    required => 1,
);


=head2 subscribe_addrs

ArrayRef of socket addresses that clients can connect to for receiving events

=cut

has 'subscribe_addrs' => (
    is => 'rw',
    isa => 'ArrayRef[Str]',
    required => 1,
);


=head1 METHODS

=head2 bind_publish_socket

Bind publish socket to publish_addrs

=cut

sub bind_publish_socket {
    my ($self) = @_;
        
    foreach my $addr (@{ $self->publish_addrs }) {
        $self->print_info("Event publishing socket listening on $addr");
        $self->publish_sock->bind($addr);
    }

    return $self->publish_sock;
}


=head2 bind_subscribe_socket

Listen for clients wishing to subscribe to published events

=cut

sub bind_subscribe_socket {
    my ($self) = @_;
    
    foreach my $addr (@{ $self->subscribe_addrs }) {
        $self->print_info("Event subscription socket listening on $addr");
        $self->subscribe_sock->bind($addr);
    }

    return $self->subscribe_sock;
}


=head2 recv

Blocks and receives one event. Returns event.

=cut

sub recv {
    my ($self) = @_;

    return $self->publish_sock->recv_as('json');
}


=head2 broadcast($event)

Sends $event to all connected subscribers.

=cut

sub broadcast {
    my ($self, $event) = @_;

    croak "event is required" unless $event;
    croak "$event is not a valid PubSub event"
        unless $event->{__type};

    return $self->subscribe_sock->send_as(json => $event);
}


=head2 poll_once

Blocks and waits for a publish message, dispatches to event handlers,
then broadcasts it to subscribers.

=cut

sub poll_once {
    my ($self) = @_;
    
    # block while we get one message
    my $msg = $self->recv;
            
    unless ($msg) {
        warn "Failed to parse message, may not have been valid JSON\n";
        next;
    }

    # deep clone $msg so that event handlers can't modify it
    my $orig = clone($msg);

    # run event handlers
    $self->dispatch_event($msg);

    # broadcast event to subscribers
    $self->broadcast($orig)
}


=head2 run

Runs pubsub server forever. See synopsis.

=cut

sub run {
    my ($self) = @_;

    # listen for events being published to our server
    my $pub_sock = $self->bind_publish_socket;

    # set up to broadcast events to waiting subscribers
    my $sub_sock = $self->bind_subscribe_socket;

    # main processing loop
    while (1) {
        $self->poll_once;
    }
}

=head1 SEE ALSO

L<ZeroMQ::PubSub::Client>, L<ZeroMQ::PubSub>

=cut

__PACKAGE__->meta->make_immutable;

