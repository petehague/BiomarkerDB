package BMINIT;
use strict;
use warnings;

BEGIN {
        use Exporter ();
	our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);
	$VERSION=1.00;
	@ISA=qw(Exporter);
	@EXPORT=qw(&bm_db_init &bm_db_dlpath);
	%EXPORT_TAGS=( );
	@EXPORT_OK=();
}

sub bm_db_init() {
# Script to initialise the user path. Must be run in every sub that accesses server files
# # Peter Hague 2008-Jun-16
        my $tmp="/Users/petehague/Sites/Biomarkers"; 

	#open(LOCALDATA,"./local.conf") or die "666 Infernal Server Error";
	#while (<LOCALDATA>) {
  	#  if ($_=~/UserPath (.+)/) { $tmp=$1; }
	#}
	#close LOCALDATA;

	return $tmp;
}

sub bm_db_dlpath() {
  return "http://127.0.0.1/~peterhague/Biomarkers";
}

END { }
1;
