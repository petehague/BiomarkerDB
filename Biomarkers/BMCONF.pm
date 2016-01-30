package BMCONF;
use strict;
use warnings;

use BMINIT;

BEGIN {
	use Exporter   ();
	our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);
	$VERSION     = 1.00;
	@ISA         = qw(Exporter);
	@EXPORT      = qw(&bm_db_newconf &bm_db_getconf);
	%EXPORT_TAGS = ( );
	@EXPORT_OK   = ();
}
our @EXPORT_OK;

sub bm_db_newconf($$) {
# Creates a new conf file for a particular data set
# # Peter Hague 2008-Jun-18

  my ($path,$dataset)=@_;

  system("cp -f ".$path."/spec.conf ".$path."/".$dataset."/");
  system("cp -f ".$path."/sigma.conf ".$path."/".$dataset."/");
}

sub bm_db_getconf($$) {
# Gets a specific piece of information from the local conf file
# # Peter Hague 2008-Jun-18

  my ($path,$key)=@_;
  my ($data);

# Checks through the local conf file for all keys matching the argument
  open(CONF, $path."/spec.conf");
  while (<CONF>) {
    chomp;
    if (!($_=~/^#/)) {
      $_=~/$key(.+)/;
      $data=$data.$1;
    }
  }
  close CONF;

# Strips whitespace and returns
  $data=~s/^\s+//g;
  $data=~s/\s+$//g;

  return $data;
}

END { }
1;
