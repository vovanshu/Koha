package Koha::News;

# Copyright ByWater Solutions 2015
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# Koha is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Koha; if not, see <http://www.gnu.org/licenses>.

use Modern::Perl;


use Koha::Database;
use Koha::Exceptions;
use Koha::NewsItem;

use base qw(Koha::Objects);

=head1 NAME

Koha::News - Koha News object set class

=head1 API

=head2 Class Methods

=cut

=head3 search_for_display

my $news = Koha::News->search_for_display({
    location => 'slip',
    lang => 'en',
    library_id => $branchcode
})

Return Koha::News set for display to user

You can limit the results by location, language and library by optional params

library_id should be valid branchcode of defined library

type is one of this:
- slip - for ISSUESLIP notice
- koha - for intranet
- opac - for online catalogue
- OpacNavRight - Right column in the online catalogue
- OpacLoginInstructions
- OpacMainUserBlock
- OpacCustomSearch
- opacheader
- opaccredits

lang is language code - it is used only when type is opac or any of OPAC locations

=cut

sub search_for_display {
    my ( $self, $params ) = @_;

    my $search_params;
    if ($params->{location} ) {
        if ( $params->{location} eq 'slip' || $params->{location} eq 'koha') {
            $search_params->{lang} = [ $params->{location}, '' ];
        } elsif ( $params->{location} eq 'opac' && $params->{lang} ) {
            $search_params->{lang} = [ $params->{lang}, '' ];
        } elsif ( $params->{lang} ) {
            $search_params->{lang} = $params->{location} . '_' . $params->{lang};
        } else {
            Koha::Exceptions::BadParameter->throw("The location ($params->{location}) and lang ($params->{lang}) parameters combination is not valid");
        }
    }

    $search_params->{branchcode} = [ $params->{library_id}, undef ] if $params->{library_id};
    $search_params->{published_on} = { '<=' => \'NOW()' };
    $search_params->{-or} = [ expirationdate => { '>=' => \'NOW()' },
                              expirationdate => undef ];

    return $self->SUPER::search($search_params, { order_by => 'number' });
}

=head3 _type

=cut

sub _type {
    return 'OpacNews';
}

=head3 object_class

=cut

sub object_class {
    return 'Koha::NewsItem';
}

=head1 AUTHOR

Kyle M Hall <kyle@bywatersolutions.com>

=cut

1;
