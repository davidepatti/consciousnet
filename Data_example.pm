# put your keys and rename this file to Data.pm
# Get Customsearch api credentials, see:
# console.developers.google.com
package Data 1.0001;
use parent qw(Exporter);

our @EXPORT = qw($api_key $cx);

our $api_key = '';
our $cx      = '';

