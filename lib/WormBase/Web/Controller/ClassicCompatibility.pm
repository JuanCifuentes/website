package WormBase::Web::Controller::ClassicCompatibility;

use strict;
use warnings;
use parent 'WormBase::Web::Controller';

__PACKAGE__->config->{namespace} = 'db';

=head1 NAME

WormBase::Web::Controller::ClassicCompatibility - Compatibility Controller for WormBase

=head1 DESCRIPTION

Backwards compatability for old-style WormBase URIs.

=head1 METHODS

=cut

=head2 get

  GET report pages
  URL space: /db/get
  Params: name and class

Provided with a class and name via the classic /db/get script,
redirect to the correct report page.

Caveat: currently assumes Ace class is given. Requires
name & class to correspond exactly to an object in AceDB
or the lower case Ace class

=cut

sub get :Local Args(0) {
    my ($self, $c) = @_;

    $c->stash->{template} = 'species/report.tt2';

    my $requested_class = $c->req->param('class');
    my $name            = $c->req->param('name');

    my $api    = $c->model('WormBaseAPI');
    my $ACE2WB = $api->modelmap->ACE2WB_MAP->{class};

    # hack for locus (legacy):
    $requested_class = 'Gene' if lc $requested_class eq 'locus';

    # there may be input (perhaps external, hand-typed input or even automated
    # input from a non-WB tool) which specifies a class in the incorrect casing
    # but is otherwise legitimate (e.g. Go_term, which should be GO_term). this
    # could be a problem in those kinds of input.
    my $class = $ACE2WB->{$requested_class}
             || $ACE2WB->{lc $requested_class} # canonical Ace class
             or $c->detach('/soft_404');

    my $normed_class = lc $class;

    my $url;
    if (exists $c->config->{sections}->{species}->{$normed_class}) { # /species
        # Fetch our external model
        my $api = $c->model('WormBaseAPI');

        my $object;

        # Fetch a WormBase::API::Object::* object
        if ($name eq '*' || $name eq 'all') {
            $object = $api->instantiate_empty($class);
        }
        else {
            $object = $api->fetch({
                class => $class,
                name  => $name,
            }) or die "Couldn't fetch an object: $!";
        }

        my $species = eval { $object->Species } || 'any';
        $url = $c->uri_for('/species', $species, $normed_class, $name);
    }
    else {                      # /report
        $url = $c->uri_for('/resources', $normed_class, $name);
    }

    $c->res->redirect($url);
}

# TODO: POD

# if there are enough of these, a GBrowse controller might be warranted
sub gbrowse_popup :Path('misc/gbrowse_popup') :Args(0) {
    my ($self, $c) = @_;

    my $name  = $c->req->params->{name}  || '';
    my $class = $c->req->params->{class} || '';
    my $type  = $c->req->params->{type}  || '';

    my $description;

    my $api = $c->model('WormBaseAPI');

    # WARNING: quickly hacked together code ahead with View and Model code!
    # consider making a proper model and view for this GBrowse popup data
    if ($type eq 'CG') {
        if (my $ace = $api->fetch({aceclass => $class, name => $name})) {
            $ace = $ace->object;
            my $gene = eval { $ace->Corresponding_CDS->Gene } || eval { $ace->Gene };
            $description = join(' ', eval { $gene->Concise_description }
                                  || eval { $gene->Detailed_description }
                                  || eval { $gene->Provisional_description }
                                  || eval { $gene->Sequence_features }
                                  || eval { $gene->Molecular_function }
                                  || eval { $gene->Biological_process }
                                  || eval { $gene->Functional_pathway }
                                  || eval { $gene->Functional_physical_interaction }
                                  || eval { $gene->Expression }
                                  || eval { $gene->Other_description }
                                  || eval { $gene->Remarks }
                                  || eval { $ace->Corresponding_CDS->DB_Remark }
                              );
        }
    }
    elsif ($type eq 'EXPR_PATTERN') {
        if (my $pattern = $api->fetch({class => 'Expr_pattern', name => $name})) {
            # IMAGE
            # TODO: cartoon image generated by legacy /db/gene/expression if no expr image
            if (my $cimg = $pattern->curated_images->{data}) {
                # arbitrarily select a curated image... maybe we should get rid
                # of this and just use the virtual worm image if possible
                my ($groupname, $imgs) = each %$cimg;
                my $img_data = $imgs->[0]->{draw};
               
                $c->stash(expr_image => $img_data->{class}.'/'.name =>$img_data->{name}.".".$img_data->{format}
			);
            }
            else {
                $c->stash(expr_image => $pattern->expression_image->{data}
				     
			);
            }

            # TEXT
            if ($description = $pattern ~~ 'Pattern') { # nasty
                $description =~ s/;/,/g;
                $description =~ s/,$//;
            }

            my $label = $pattern->name->{data}->{label}; # "Expression pattern for ..."

            if (my $types = eval {$pattern->experimental_details->{data}->{types}}) {
                $label =~ s/Expression pattern //; # "for ..."
                $c->stash(title => "$types->[0]->[0] $label");
            }
            else {
                $c->stash(title => $label);
            }
        }
    }

    $c->stash(
        desc     => $description,
        template => 'gbrowse/gbrowse_popup.tt2',
        noboiler => 1,
    );
}

=head1 AUTHOR

Todd Harris (info@toddharris.net)

=head1 LICENSE

This library is free software, you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
