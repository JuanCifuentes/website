package WormBase::Web::Controller::Tools;

use strict;
use warnings;
use parent 'WormBase::Web::Controller';

# TODO: blast_blat requires its own controller..
sub index :Path :Args(0) {
    my ($self, $c) = @_;
    $c->stash->{template} = "tools/report.tt2";
    $c->stash->{section}  = "tools";
    # get static widgets / layout info for this page
    $self->_setup_page($c);
}

sub support :Path('support') :Args(0) {
    my ($self, $c) = @_; 
    $c->stash->{section}  = "tools";
    $c->stash->{template} = "feed/issue.tt2";
    $c->stash->{url} = $c->req->params->{url} || "/";
    return;
}

sub operator :Path("operator") Args {
    my ($self, $c) = @_; 
    $c->stash->{template} = "auth/operator.tt2";
}

sub comment :Path("comments") Args {
    my ( $self, $c) = @_;
    $c->stash->{template} = "feed/comment_list.tt2";
    my @comments = $c->model('Schema::Comment')->search(undef);
    $c->stash->{comments} = \@comments;
    $c->stash->{current_time}=time();
}

sub tools :Path Args {
    my ( $self, $c, @args) = @_;
    #  $c->stash->{noboiler} = 1;
    my $tool = shift @args;
    my $action= shift @args || "index";
    $c->log->debug("using $tool and running $action\n");

    $c->stash->{section} = "tools";
    $c->stash->{template}="tools/$tool/$action.tt2";
    $c->stash->{noboiler} = 1 if($c->req->params->{inline});
    my $api = $c->model('WormBaseAPI');
    my ($data, $cache_server);

    # Does the data already exist in the cache?

    if ($action eq 'run' && $tool =~/aligner/ && !(defined $c->req->params->{Change})) {
        my $cache_id ='tools_'.$tool.'_'.$c->req->params->{sequence};
        ($data, $cache_server) = $c->check_cache($cache_id, 'filecache');

        unless ($data) {
	    $c->log->debug("not in cache, run $tool\n");
            $data = $api->_tools->{$tool}->$action($c, $c->req->params);
            $c->set_cache($cache_id => $data, 'filecache');
        }
        else {
            $c->stash->{cache} = $cache_server if($cache_server);
        }
    }
    elsif ($tool =~/aligner/) {
        $data = $api->_tools->{$tool}->$action($c, $c->req->params);
    }
    else {
        $data = $api->_tools->{$tool}->$action($c->req->params);
    }
 
    # Create different actions for different tools instead of using
    #   this single catch-all action? -AD
    if($data->{redirect}){
	my $url = $c->uri_for('/search',$data->{class},$data->{name})->as_string;
	     $c->res->redirect($url."?from=".$data->{redirect}."&query=".$data->{msg}, 307);
    }

    if ($tool eq 'tree') {
        $c->stash->{data} = $data;
    }
    else {
        for my $key (keys %$data) {
	     $c->log->debug("save in stash key $key\n");
            $c->stash->{$key}=$data->{$key};
        }
    }
}


1;
