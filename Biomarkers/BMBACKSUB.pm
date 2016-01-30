package BMBACKSUB;

use strict;
use warnings;

use BMCONF;
use BMSTATUS;

BEGIN {
	use Exporter   ();
	our ($VERSION, @ISA, @EXPORT, @EXPORT_OK, %EXPORT_TAGS);
	$VERSION     = 1.00;
	@ISA         = qw(Exporter);
	@EXPORT      = qw(&bm_db_backsubtract);
	%EXPORT_TAGS = ( );
	@EXPORT_OK   = ();
}
our @EXPORT_OK;

sub bm_db_backsubtract($) {
# Background subtraction algrithm
# # Peter Hague 2008-Jun-18

  my ($filename)=@_;
  my ($update,@mz,@bins,@cols,$index,$start,$end,$subindex,@window,@background,@variance);

# Retrieving settings for this dataset
  $filename=~/(.+)\/(.+)/;
  my $path=$1;
  my $shortname=$2;
  my $width=&bm_db_getconf($path,"WindowSize");
  my $threshold=&bm_db_getconf($path,"Threshold");
  my $numbins=&bm_db_getconf($path,"BinEnd")-&bm_db_getconf($path,"BinStart");

# Extracting data from file into array for quicker processing
  open(SOURCE,$filename);
  my $key=0;
  while (<SOURCE>) {
    chomp;
    @cols=split /\s+/,$_;
    if ($cols[1]=~/^[0-9]/) {
      $mz[$key]=$cols[1];
      $bins[$key]=$cols[2];
      $key++;
    }
  }
  close SOURCE;

# Moving window through bins, updating status file periodically
  @variance=();
  for ($index=0;$index<$numbins;$index++) {

# Calculate the background level by sorting all bins in window
    @window=();
    $start=&maximum($index-($width/2)+1,0);
    $end=&minimum($index+($width/2),$numbins);
    for ($subindex=$start;$subindex<$end;$subindex++) {
      $window[$subindex-$start]=$bins[$subindex];
    }
    @window = sort { $a <=> $b } @window;
    $threshold=&minimum($threshold,$end-$start);
    $background[$index]=$window[$threshold-1];
    
# Calculate the variance by taking mean of the square distance from mean
    for ($subindex=0;$subindex<($end-$start)-$threshold;$subindex++) {
      $variance[$index]+=($window[$threshold-1]-$window[$subindex])**2
    }
    $variance[$index]/=($end-$start)-$threshold;
  }

# Saving as CSV file
  $filename=~s/\.dat/\.csv/;
  open (TARGET,">$filename");
  print TARGET "bin,value,background,subtracted,variance\n";
  for ($index=0;$index<$numbins;$index++) {
    print TARGET $mz[$index].",".$bins[$index].",".$background[$index].",".($bins[$index]-$background[$index]).",".$variance[$index]."\n";
  }
  close TARGET;
}

sub by_number() {
  my ($a, $b);
  $a <=> $b;
}

sub minimum($) {
  my ($a, $b)=@_;
  if ($a>$b) { return $b; } else { return $a; }
}

sub maximum($) {
  my ($a, $b)=@_;
  if ($a>$b) { return $a; } else { return $b; }
}

END { }
1;
