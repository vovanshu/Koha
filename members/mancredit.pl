#!/usr/bin/perl

#written 11/1/2000 by chris@katipo.oc.nz
#script to display borrowers account details

# Copyright 2000-2002 Katipo Communications
# Copyright 2010 BibLibre
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

use C4::Auth qw( get_template_and_user );
use C4::Output qw( output_and_exit_if_error output_and_exit output_html_with_http_headers );
use CGI qw ( -utf8 );

use C4::Members;
use C4::Accounts;

use Koha::Items;
use Koha::Patrons;
use Koha::Patron::Categories;
use Koha::Account::CreditTypes;

use Koha::Token;

my $input = CGI->new;
my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {
        template_name   => "members/mancredit.tt",
        query           => $input,
        type            => "intranet",
        flagsrequired   => {
            borrowers     => 'edit_borrowers',
            updatecharges => 'remaining_permissions'
        }
    }
);

my $logged_in_user = Koha::Patrons->find($loggedinuser);
my $borrowernumber = $input->param('borrowernumber');
my $patron         = Koha::Patrons->find($borrowernumber);

output_and_exit_if_error(
    $input, $cookie,
    $template,
    {
        module         => 'members',
        logged_in_user => $logged_in_user,
        current_patron => $patron
    }
);

my $library_id =
  C4::Context->userenv ? C4::Context->userenv->{'branch'} : undef;

my $add = $input->param('add');
if ($add) {
    output_and_exit( $input, $cookie, $template, 'wrong_csrf_token' )
      unless Koha::Token->new->check_csrf(
        {
            session_id => scalar $input->cookie('CGISESSID'),
            token      => scalar $input->param('csrf_token'),
        }
      );

# Note: If the logged in user is not allowed to see this patron an invoice can be forced
# Here we are trusting librarians not to hack the system
    my $barcode = $input->param('barcode');
    my $item_id;
    if ($barcode) {
        my $item = Koha::Items->find( { barcode => $barcode } );
        $item_id = $item->itemnumber if $item;
    }
    my $description = $input->param('desc');
    my $note        = $input->param('note');
    my $amount      = $input->param('amount') || 0;
    my $type        = $input->param('type');

    $patron->account->add_credit(
        {
            amount      => $amount,
            description => $description,
            item_id     => $item_id,
            library_id  => $library_id,
            note        => $note,
            type        => $type,
            user_id     => $logged_in_user->id,
            interface   => C4::Context->interface
        }
    );

    if ( C4::Context->preference('AccountAutoReconcile') ) {
        $patron->account->reconcile_balance;
    }

    print $input->redirect(
        "/cgi-bin/koha/members/boraccount.pl?borrowernumber=$borrowernumber");
    exit;
}
else {

    my @credit_types = Koha::Account::CreditTypes->search_with_library_limits(
        { can_be_added_manually => 1, archived => 0 },
        {}, $library_id );

    $template->param(
        patron       => $patron,
        credit_types => \@credit_types,
        finesview    => 1,
        csrf_token   => Koha::Token->new->generate_csrf(
            { session_id => scalar $input->cookie('CGISESSID') }
        ),
    );
    output_html_with_http_headers $input, $cookie, $template->output;
}
