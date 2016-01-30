package BMFLUX;
use strict;
use warnings;

use BMCONF;
use BMSTATUS;
use BMGAUSS;

BEGIN {
	use Exporter   ();
	our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);
	$VERSION     = 1.00;
	@ISA         = qw(Exporter);
	@EXPORT      = qw(&bm_db_flux);
	%EXPORT_TAGS = ( );
	@EXPORT_OK   = ();
}
our @EXPORT_OK;

sub bm_db_flux($) {
# Function to determine the flux and error for each significant peak
# # Peter Hague 2008-Jul-01
  my ($dataname)=@_;
  my ($index, $netflux, $subindex, $start, $end);
  my (@cols, @rawdata, @flux, @sigs);

# Get raw data
  open(BINS,$dataname);
  while (<BINS>) {
    chomp;
    @cols=split /\,/,$_;
    if ($cols[0]=~/^[0-9]/) {
      $rawdata[$cols[0]]=$cols[3];
    }
  }
  close BINS;

# Calculate background flux, and error
  $dataname=~/(.+)\/(.+)/;
  $start=&bm_db_getconf($1,"BinStart")+(&bm_db_getconf($1,"BinSize")/2);
  $end=&bm_db_getconf($1,"BinEnd")+(&bm_db_getconf($1,"BinSize")/2);
  @sigs=&bm_sigma_file($dataname, $start, $end);
  @flux=();
  for ($index=$start;$index<=$end;$index++) {
    $netflux=0;
    for ($subindex=$index-$sigs[$index];$subindex<=$index+$sigs[$index];$subindex++) {
      if ($rawdata[$subindex]) { 
	$netflux+=$rawdata[$subindex];
      }
    }
    push (@flux,($netflux));
  }

# Write to -fl.csv file
  $dataname=~s/\.csv/-fl\.csv/;
  open (OUTPUT,">".$dataname);
  print OUTPUT "peak,flux\n";
  for ($index=$start;$index<=$end;$index++) {
    print OUTPUT $index.",".$flux[$index]."\n";
  }
  close OUTPUT;
}

END { }
1;
